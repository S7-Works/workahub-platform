use flutter_rust_bridge::frb;
use aws_sdk_s3::Client;
use aws_config::meta::region::RegionProviderChain;
use aws_sdk_s3::config::Region;
use aws_config::BehaviorVersion;
use std::path::Path;
use aws_sdk_s3::primitives::ByteStream;
use tokio::fs::File;

pub async fn upload_file_to_s3(
    file_path: String,
    bucket: String,
    region_str: String,
    access_key: String,
    secret_key: String,
    s3_key: String, // The path in the bucket
) -> anyhow::Result<String> {
    
    // Configure Credentials
    let credentials = aws_credential_types::Credentials::new(
        access_key,
        secret_key,
        None,
        None,
        "static",
    );

    let region = Region::new(region_str);
    
    let config = aws_config::defaults(BehaviorVersion::latest())
        .region(region)
        .credentials_provider(credentials)
        .load()
        .await;
        
    let client = Client::new(&config);

    let body = ByteStream::from_path(Path::new(&file_path)).await;

    match body {
        Ok(b) => {
            let _resp = client.put_object()
                .bucket(&bucket)
                .key(&s3_key)
                .body(b)
                .send()
                .await?;
            Ok(format!("Successfully uploaded to {}/{}", bucket, s3_key))
        },
        Err(e) => Err(anyhow::anyhow!("Failed to read file: {}", e)),
    }
}
