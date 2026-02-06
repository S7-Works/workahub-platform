use flutter_rust_bridge::frb;
use std::sync::{Arc, Mutex};
use std::thread;
use screenshots::Screen;
use sysinfo::System;
use rdev::{listen, Event, EventType};
use image::ImageFormat;
use std::io::Cursor;

// Global state for monitoring
lazy_static::lazy_static! {
    static ref INPUT_STATS: Arc<Mutex<InputStats>> = Arc::new(Mutex::new(InputStats::default()));
    static ref SYSTEM: Arc<Mutex<System>> = Arc::new(Mutex::new(System::new_all()));
}

#[derive(Default, Clone, Debug)]
pub struct InputStats {
    pub mouse_clicks: u64,
    pub key_presses: u64,
    pub mouse_moves: u64,
}

// Start Input Monitoring (run once)
pub fn start_input_monitoring() {
    thread::spawn(|| {
        if let Err(error) = listen(callback) {
            println!("Error: {:?}", error);
        }
    });
}

fn callback(event: Event) {
    let mut stats = INPUT_STATS.lock().unwrap();
    match event.event_type {
        EventType::KeyPress(_) => stats.key_presses += 1,
        EventType::ButtonPress(_) => stats.mouse_clicks += 1,
        EventType::MouseMove { .. } => stats.mouse_moves += 1,
        _ => (),
    }
}

// Get and Reset Stats
pub fn get_and_reset_input_stats() -> InputStats {
    let mut stats = INPUT_STATS.lock().unwrap();
    let current = stats.clone();
    *stats = InputStats::default(); // Reset
    current
}

// Capture Screenshots
pub fn capture_screens() -> Vec<Vec<u8>> {
    let screens = Screen::all().unwrap_or_default();
    let mut images = Vec::new();

    for screen in screens {
        match screen.capture() {
            Ok(image) => {
                // image is ImageBuffer<Rgba<u8>, Vec<u8>>
                let dynamic_image = image::DynamicImage::ImageRgba8(image);
                let mut buffer = Vec::new();
                if let Ok(_) = dynamic_image.write_to(&mut Cursor::new(&mut buffer), ImageFormat::Png) {
                    images.push(buffer);
                }
            },
            Err(e) => println!("Failed to capture screen: {}", e),
        }
    }
    images
}

// System Stats
pub struct SystemStats {
    pub cpu_usage: f32,
    pub memory_used: u64,
    pub memory_total: u64,
}

pub fn get_system_stats() -> SystemStats {
    let mut sys = SYSTEM.lock().unwrap();
    sys.refresh_cpu();
    sys.refresh_memory();
    
    SystemStats {
        cpu_usage: sys.global_cpu_info().cpu_usage(),
        memory_used: sys.used_memory(),
        memory_total: sys.total_memory(),
    }
}
