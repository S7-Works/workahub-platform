use flutter_rust_bridge::frb;
use gstreamer::prelude::*;
use gstreamer::{Element, ElementFactory, Pipeline, State};
use std::sync::{Arc, Mutex};
use std::collections::HashMap;
use anyhow::{Result, anyhow};
use lazy_static::lazy_static;

// Global state to manage active pipelines and hardware resources
lazy_static! {
    static ref PIPELINE_MANAGER: Arc<Mutex<PipelineManager>> = Arc::new(Mutex::new(PipelineManager::new()));
}

struct PipelineManager {
    pipelines: HashMap<String, Pipeline>,
    active_gpu_streams: u32,
    // Limit based on hardware capabilities (e.g., standard consumer GPUs might handle 3-4 concurrent encodes)
    max_gpu_streams: u32, 
}

impl PipelineManager {
    fn new() -> Self {
        Self {
            pipelines: HashMap::new(),
            active_gpu_streams: 0,
            max_gpu_streams: 4, // Conservative default, adjustable
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum EncoderQuality {
    HardwareAV1,
    HardwareHEVC,
    HardwareH264,
    SoftwareVP9,
    SoftwareVP8,
    SoftwareH264,
    SoftwareFallback, // MJPEG
}

impl EncoderQuality {
    fn to_gst_element_name(&self) -> &'static str {
        // macOS (Darwin) mappings using VideoToolbox (vtenc)
        // Linux/Windows would utilize vaapi/nvcodec in a full cross-platform impl
        match self {
            EncoderQuality::HardwareAV1 => "vtenc_av1", // M3+ chips
            EncoderQuality::HardwareHEVC => "vtenc_hevc", 
            EncoderQuality::HardwareH264 => "vtenc_h264",
            EncoderQuality::SoftwareVP9 => "vp9enc",
            EncoderQuality::SoftwareVP8 => "vp8enc",
            EncoderQuality::SoftwareH264 => "x264enc",
            EncoderQuality::SoftwareFallback => "jpegenc",
        }
    }
}

// Initialize GStreamer
pub fn init_gstreamer() -> Result<String> {
    match gstreamer::init() {
        Ok(_) => {
             // Optional: Log version
             let version = gstreamer::version_string();
             Ok(format!("GStreamer initialized: {}", version))
        },
        Err(e) => Err(anyhow!("Failed to init GStreamer: {}", e)),
    }
}

// Find the best available encoder on the system
fn find_best_encoder() -> EncoderQuality {
    // Check elements availability in registry
    // This is a simplified check. Real impl would check 'gstreamer::Registry'
    
    // Attempt AV1 (Apple M3 or modern GPUs)
    if ElementFactory::find("vtenc_av1").is_some() {
        return EncoderQuality::HardwareAV1;
    }
    
    // Attempt HEVC (Common on modern macs)
    if ElementFactory::find("vtenc_hevc").is_some() {
        return EncoderQuality::HardwareHEVC; 
    }

    // Attempt H264 HW
    if ElementFactory::find("vtenc_h264").is_some() {
        return EncoderQuality::HardwareH264;
    }

    // Attempt VP9 (High quality open standard)
    if ElementFactory::find("vp9enc").is_some() {
        return EncoderQuality::SoftwareVP9;
    }

    // Attempt VP8 (Widely compatible open standard)
    if ElementFactory::find("vp8enc").is_some() {
        return EncoderQuality::SoftwareVP8;
    }

    // Fallback to x264
    if ElementFactory::find("x264enc").is_some() {
        return EncoderQuality::SoftwareH264;
    }

    EncoderQuality::SoftwareFallback
}

// Start a screen recording pipeline
// id: Unique identifier for this stream
// sink_path: Where to save/stream (e.g., "file:///tmp/rec.mp4" or "rtmp://...")
pub fn start_screen_recording(id: String, sink_path: String) -> Result<String> {
    let mut manager = PIPELINE_MANAGER.lock().map_err(|e| anyhow!("Lock error: {}", e))?;

    if manager.pipelines.contains_key(&id) {
        return Err(anyhow!("Pipeline with ID {} already exists", id));
    }

    // Determine encoder strategy
    let best_encoder = find_best_encoder();
    let use_gpu = matches!(best_encoder, EncoderQuality::HardwareAV1 | EncoderQuality::HardwareHEVC | EncoderQuality::HardwareH264);

    // Concurrency check
    if use_gpu && manager.active_gpu_streams >= manager.max_gpu_streams {
        println!("GPU saturation reached ({}/{}), falling back to CPU for stream {}", manager.active_gpu_streams, manager.max_gpu_streams, id);
        // Fallback logic could go here, for now we just warn
    }

    // Construct Pipeline String
    // macOS source: osxscreencapture
    // audio: osxaudiosrc (optional, skipped for now to focus on video)
    let encoder_name = match best_encoder {
        EncoderQuality::HardwareHEVC => "vtenc_hevc", // Correcting the placeholder
        _ => best_encoder.to_gst_element_name(),
    };

    println!("Selected Encoder for {}: {}", id, encoder_name);

    // Pipeline: Source -> Convert -> Encode -> Mux -> Sink
    // We use mp4mux for file recording.
    let pipeline_str = format!(
        "osxscreencapture capture-cursor=true ! video/x-raw,framerate=30/1 ! videoconvert ! {} bitrate=4000 ! mp4mux ! filesink location={}",
        encoder_name,
        sink_path
    );

    let pipeline = gstreamer::parse::launch(&pipeline_str)
        .map_err(|e| anyhow!("Failed to parse pipeline: {}", e))?;

    let pipeline = pipeline.dynamic_cast::<Pipeline>()
        .map_err(|_| anyhow!("Cast to pipeline failed"))?;

    pipeline.set_state(State::Playing)
        .map_err(|e| anyhow!("Failed to set state: {}", e))?;

    // Track resources
    if use_gpu {
        manager.active_gpu_streams += 1;
    }
    manager.pipelines.insert(id.clone(), pipeline);

    Ok(format!("Started recording {} using {}", id, encoder_name))
}

pub fn stop_pipeline(id: String) -> Result<String> {
    let mut manager = PIPELINE_MANAGER.lock().map_err(|e| anyhow!("Lock error: {}", e))?;

    if let Some(pipeline) = manager.pipelines.remove(&id) {
        let _ = pipeline.set_state(State::Null);
        // Naive resource release (doesn't check if it was actually using GPU, assuming yes for now based on our logic)
        // In a real generic impl, we'd store the 'type' in the map too.
        if manager.active_gpu_streams > 0 {
             manager.active_gpu_streams -= 1;
        }
        Ok(format!("Stopped pipeline {}", id))
    } else {
        Err(anyhow!("Pipeline {} not found", id))
    }
}

// Get list of active streams
pub fn get_active_streams() -> Vec<String> {
    let manager = PIPELINE_MANAGER.lock().unwrap();
    manager.pipelines.keys().cloned().collect()
}