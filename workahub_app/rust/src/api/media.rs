use flutter_rust_bridge::frb;
use gstreamer::prelude::*;
use std::sync::{Arc, Mutex};

// Initialize GStreamer
pub fn init_gstreamer() -> anyhow::Result<String> {
    match gstreamer::init() {
        Ok(_) => Ok("GStreamer initialized successfully".to_string()),
        Err(e) => Err(anyhow::anyhow!("Failed to init GStreamer: {}", e)),
    }
}

// Example: Start a simple pipeline (e.g., videotestsrc)
// This is a placeholder for actual screen/camera recording logic
pub fn start_test_pipeline() -> anyhow::Result<String> {
    let pipeline_str = "videotestsrc ! videoconvert ! fakesink";
    let pipeline = gstreamer::parse::launch(pipeline_str)
        .map_err(|e| anyhow::anyhow!("Failed to parse pipeline: {}", e))?;

    let pipeline = pipeline.dynamic_cast::<gstreamer::Pipeline>()
        .map_err(|_| anyhow::anyhow!("Cast to pipeline failed"))?;

    pipeline.set_state(gstreamer::State::Playing)
        .map_err(|e| anyhow::anyhow!("Failed to set state: {}", e))?;

    // In a real app, we'd keep the pipeline handle to stop it later.
    // For now, we just start it and let it run (it will be dropped and stopped eventually if not stored).
    // To keep it running, we'd need a global state or return a handle.
    
    // Let's stop it immediately for this test function to avoid resource leaks in this example.
    // pipeline.set_state(gstreamer::State::Null)?;

    Ok("Pipeline started".to_string())
}
