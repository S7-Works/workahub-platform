use flutter_rust_bridge::frb;
use reqwest::blocking::Client;
use serde::{Deserialize, Serialize};
use serde_json::json;

#[derive(Serialize, Deserialize, Debug)]
pub struct OrganizationList {
    #[serde(rename = "List")]
    pub list: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ServerResponse {
    #[serde(rename = "User_id")]
    pub user_id: String,
    #[serde(rename = "Username")]
    pub username: String,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct AuthState {
    pub is_logged_in: bool,
    pub username: Option<String>,
    pub user_id: Option<String>,
    pub organization: Option<String>,
}

// Check email and get organizations
pub fn require_organization(email: String) -> anyhow::Result<Vec<String>> {
    let client = Client::new();
    let res = client.post("https://api.trypadlock.com/users/organization_require")
        .json(&json!({"email": email}))
        .send()?;

    if res.status().is_success() {
        let org_list: OrganizationList = res.json()?;
        Ok(org_list.list)
    } else {
        Err(anyhow::anyhow!("Failed to fetch organizations"))
    }
}

// Select Org
pub fn sign_org(email: String, org: String) -> anyhow::Result<ServerResponse> {
    let client = Client::new();
    let res = client.post("https://api.trypadlock.com/users/org_sign")
        .json(&json!({"email": email, "org": org}))
        .send()?;

    if res.status().is_success() {
        let server_response: ServerResponse = res.json()?;
        Ok(server_response)
    } else {
        Err(anyhow::anyhow!("Failed to sign org"))
    }
}

// Login
pub fn login(username: String, password: String, org: String) -> anyhow::Result<ServerResponse> {
    let client = Client::new();
    let res = client.post("https://api.trypadlock.com/users/login_client")
        .json(&json!({
            "username": username,
            "password": password,
            "organization": org
        }))
        .send()?;

    if res.status().is_success() {
        let server_response: ServerResponse = res.json()?;
        Ok(server_response)
    } else {
        Err(anyhow::anyhow!("Login failed"))
    }
}
