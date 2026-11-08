//! What the oracle tests share: the oracle directory and the CLI.

use std::io::Write as _;
use std::process::{Command, Stdio};

use serde_json::Value;

/// The directory `RUST_SEARCH_ORACLE` names (written by `sim/rust/search-oracle.sh`).
pub fn oracle_dir() -> Result<String, String> {
    let dir = std::env::var("RUST_SEARCH_ORACLE")
        .map_err(|error| format!("RUST_SEARCH_ORACLE names the directory sim/rust/search-oracle.sh writes: {error}"))?;
    if !std::path::Path::new(&dir).is_dir() {
        return Err(format!("RUST_SEARCH_ORACLE={dir} is not a directory"));
    }
    Ok(dir)
}

/// The text and rows of an oracle file, which must have some.
pub fn oracle_rows(dir: &str, name: &str) -> Result<(String, Vec<Value>), String> {
    let text = std::fs::read_to_string(format!("{dir}/{name}")).map_err(|error| format!("{dir}/{name}: {error}"))?;
    let rows = text
        .lines()
        .map(|line| serde_json::from_str(line).map_err(|error| format!("{name}: {error}")))
        .collect::<Result<Vec<Value>, String>>()?;
    if rows.is_empty() {
        return Err(format!("{name}: an empty oracle file"));
    }
    Ok((text, rows))
}

/// The CLI's rows for `input` with `flags`, one per input line.
pub fn cli(flags: &[&str], input: &str) -> Result<Vec<Value>, String> {
    let mut child = Command::new(env!("CARGO_BIN_EXE_buckshot-search"))
        .args(flags)
        .args(["--threads", "2"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|error| error.to_string())?;
    child
        .stdin
        .take()
        .ok_or("no stdin")?
        .write_all(input.as_bytes())
        .map_err(|error| error.to_string())?;
    let out = child.wait_with_output().map_err(|error| error.to_string())?;
    if !out.status.success() {
        return Err(format!("the CLI failed: {}", String::from_utf8_lossy(&out.stderr)));
    }
    let rows = String::from_utf8_lossy(&out.stdout)
        .lines()
        .map(|line| serde_json::from_str(line).map_err(|error| error.to_string()))
        .collect::<Result<Vec<Value>, String>>()?;
    if rows.len() != input.lines().count() {
        return Err(format!("{} rows for {} inputs", rows.len(), input.lines().count()));
    }
    Ok(rows)
}

/// A row's line scores.
pub fn scores(row: &Value) -> Vec<Value> {
    row["lines"]
        .as_array()
        .map(|lines| lines.iter().map(|line| line["score"].clone()).collect())
        .unwrap_or_default()
}
