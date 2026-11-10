//! What the oracle tests share: the oracle directory and the CLI.

use std::io::Write as _;
use std::process::{Command, Stdio};

use anyhow::{Context as _, Result, ensure};
use serde_json::Value;

/// The directory `RUST_SEARCH_ORACLE` names (written by `sim/rust/search-oracle.sh`).
pub fn oracle_dir() -> Result<String> {
    let dir = std::env::var("RUST_SEARCH_ORACLE").context("RUST_SEARCH_ORACLE names the directory sim/rust/search-oracle.sh writes")?;
    ensure!(std::path::Path::new(&dir).is_dir(), "RUST_SEARCH_ORACLE={dir} is not a directory");
    Ok(dir)
}

/// The text and rows of an oracle file, which must have some.
pub fn oracle_rows(dir: &str, name: &str) -> Result<(String, Vec<Value>)> {
    let path = format!("{dir}/{name}");
    let text = std::fs::read_to_string(&path).with_context(|| path.clone())?;
    let rows = text
        .lines()
        .map(serde_json::from_str)
        .collect::<Result<Vec<Value>, _>>()
        .with_context(|| path.clone())?;
    ensure!(!rows.is_empty(), "{path}: an empty oracle file");
    Ok((text, rows))
}

/// The CLI's rows for `input` with `flags`, one per input line.
pub fn cli(flags: &[&str], input: &str) -> Result<Vec<Value>> {
    let mut child = Command::new(env!("CARGO_BIN_EXE_buckshot-search"))
        .args(flags)
        .args(["--threads", "2"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;
    child.stdin.take().context("no stdin")?.write_all(input.as_bytes())?;
    let out = child.wait_with_output()?;
    ensure!(out.status.success(), "the CLI failed: {}", String::from_utf8_lossy(&out.stderr));
    let rows = String::from_utf8_lossy(&out.stdout)
        .lines()
        .map(serde_json::from_str)
        .collect::<Result<Vec<Value>, _>>()?;
    ensure!(
        rows.len() == input.lines().count(),
        "{} rows for {} inputs",
        rows.len(),
        input.lines().count()
    );
    Ok(rows)
}

/// A row's line scores.
pub fn scores(row: &Value) -> Vec<Value> {
    row["lines"]
        .as_array()
        .map(|lines| lines.iter().map(|line| line["score"].clone()).collect())
        .unwrap_or_default()
}
