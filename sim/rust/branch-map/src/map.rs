//! The hand-kept part of the map, `rules/branch-map.toml`: Bend defs with no
//! Rust arms, Bend branches with more than one Rust site, and Rust control
//! flow with no Bend branch of its own. Every entry needs a reason.

use std::collections::BTreeMap;
use std::path::Path;

use anyhow::{Context, Result};
use serde::Deserialize;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Map {
    /// `module:def` -> why its cases have no Rust arm.
    #[serde(default)]
    pub exempt: BTreeMap<String, String>,
    /// Variant -> its Rust sites when not one.
    #[serde(default)]
    pub sites: BTreeMap<String, Sites>,
    /// `file`, `file:fn` or `file:fn:<kind> <expr>` -> why that Rust control flow has no Bend branch.
    #[serde(default)]
    pub rust_only: BTreeMap<String, String>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Sites {
    pub count: usize,
    pub reason: String,
}

pub fn load(path: &Path) -> Result<Map> {
    let text = std::fs::read_to_string(path).with_context(|| format!("reading {}", path.display()))?;
    toml::from_str(&text).with_context(|| format!("parsing {}", path.display()))
}
