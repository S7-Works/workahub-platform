use rusqlite::{params, Connection, Result};
use std::path::PathBuf;
use std::fs;
use flutter_rust_bridge::frb;

// Helper to get db path
fn get_db_path() -> PathBuf {
    // Mimic the Go logic: simple "goappdata" folder in current working dir or relative
    // For a proper app, we should use ProjectDirs, but let's stick to the Go app's convention for now
    // or improve it to use local data dir.
    // Let's use a "workahub_data" folder in the document dir or similar.
    // But since we are likely running from a bundle, let's look for a standard place.
    // For now, let's use the current directory + "goappdata" to match the migration.
    
    let path = PathBuf::from("goappdata");
    if !path.exists() {
        fs::create_dir_all(&path).unwrap_or_default();
    }
    path.join("workahub.db")
}

pub fn init_db() -> String {
    let path = get_db_path();
    match Connection::open(&path) {
        Ok(conn) => {
            // Create tables
            // Go: CREATE TABLE IF NOT EXISTS users(id INTEGER PRIMARY KEY AUTOINCREMENT,username TEXT,password TEXT,status BOOLEAN)
            let _ = conn.execute(
                "CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT,
                    password TEXT,
                    status BOOLEAN
                )",
                [],
            );
            
            // Go: CREATE TABLE IF NOT EXISTS uuidSchema(id INTEGER PRIMARY KEY AUTOINCREMENT,uuid TEXT)
            let _ = conn.execute(
                "CREATE TABLE IF NOT EXISTS uuidSchema (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    uuid TEXT
                )",
                [],
            );

             // Go: CREATE TABLE IF NOT EXISTS unsenturls(...)
             let _ = conn.execute(
                "CREATE TABLE IF NOT EXISTS unsenturls (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    unsenturl TEXT,
                    status BOOLEAN
                )",
                [],
            );
            
            format!("Database initialized at {:?}", path)
        },
        Err(e) => format!("Failed to init db: {}", e),
    }
}
