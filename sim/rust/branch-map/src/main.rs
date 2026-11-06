//! The static map between the Bend rules and the Rust rules crate.
//!
//! `write` regenerates `rules/src/branch/ids.rs`, the enum `B` with one
//! variant per Bend branch site. `check` fails when that file is stale (any
//! change to a Bend source in scope changes its hash), when a variant does
//! not have its number of Rust sites (one unless `branch-map.toml` says
//! otherwise), when Rust control flow is neither labelled nor listed as
//! Rust-only, or when a map entry is stale. `list` prints the map. `instrument <dir>` writes a traced copy of the
//! Bend tree for the trace comparison.

mod bend;
mod gen_ids;
mod instrument;
mod map;
mod rust;

use std::collections::BTreeMap;
use std::io::Write as _;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode, Stdio};

use anyhow::{Context, Result, bail};

struct Paths {
    bend: PathBuf,
    rules: PathBuf,
}

impl Paths {
    fn new() -> Self {
        let root = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
        Self {
            bend: root.join("../bend-mp"),
            rules: root.join("rules"),
        }
    }

    fn ids(&self) -> PathBuf {
        self.rules.join("src/branch/ids.rs")
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(true) => ExitCode::SUCCESS,
        Ok(false) => ExitCode::FAILURE,
        Err(error) => {
            eprintln!("branch-map: {error:#}");
            ExitCode::FAILURE
        }
    }
}

fn run() -> Result<bool> {
    let command = std::env::args().nth(1).unwrap_or_default();
    let paths = Paths::new();
    let rules = bend::load(&paths.bend)?;
    let map = map::load(&paths.rules.join("branch-map.toml"))?;
    let all = bend::sites(&rules);
    let mut errors = map_errors(&map, &all);
    let sites: Vec<&bend::Site> = all.iter().filter(|s| !map.exempt.contains_key(&s.def_key())).collect();
    // A branch mapped to no Rust site gets no variant: B has deny(dead_code).
    let variants: Vec<&bend::Site> = sites
        .iter()
        .copied()
        .filter(|s| map.sites.get(&s.variant).is_none_or(|e| e.count > 0))
        .collect();
    let ids = rustfmt(&gen_ids::ids(&rules, &variants)?)?;
    match command.as_str() {
        "write" => {
            std::fs::write(paths.ids(), &ids).with_context(|| format!("writing {}", paths.ids().display()))?;
            println!("wrote {} ({} variants)", paths.ids().display(), variants.len());
            return Ok(true);
        }
        "instrument" => {
            let out = std::env::args().nth(2).context("usage: branch-map instrument <out dir>")?;
            let untimed: Vec<String> = sites
                .iter()
                .filter(|s| map.untimed.contains_key(&s.def_key()))
                .map(|s| s.label())
                .collect();
            instrument::write(&paths.bend, Path::new(&out), &rules, &sites, &untimed)?;
            println!("wrote the traced Bend tree to {out} ({} labels)", sites.len());
            return Ok(true);
        }
        "check" | "list" => {}
        other => bail!("usage: branch-map write|check|list|instrument <dir> (got {other:?})"),
    }
    if std::fs::read_to_string(paths.ids()).ok().as_deref() != Some(ids.as_str()) {
        errors.push(
            "rules/src/branch/ids.rs is stale: the Bend rules changed; run `cargo run -p branch-map -- write`, then make Rust match"
                .to_owned(),
        );
    }
    let report = check_rust(&paths.rules.join("src"))?;
    errors.extend(report.errors.iter().cloned());
    let mut rust_sites: BTreeMap<&str, Vec<String>> = sites.iter().map(|s| (s.variant.as_str(), Vec::new())).collect();
    for u in &report.uses {
        match rust_sites.get_mut(u.variant.as_str()) {
            Some(at) => at.push(format!("{}:{}", u.file, u.line)),
            None => errors.push(format!("{}:{}: branch!({}) is not a Bend branch", u.file, u.line, u.variant)),
        }
    }
    for site in &sites {
        let expected = map.sites.get(&site.variant).map_or(1, |s| s.count);
        let found = rust_sites.get(site.variant.as_str()).map_or(0, Vec::len);
        if found != expected {
            let at = rust_sites.get(site.variant.as_str()).map(|a| a.join(", ")).unwrap_or_default();
            errors.push(format!(
                "{} (`{}`, {}.bend:{}): {found} Rust sites, expected {expected} [{at}]",
                site.variant,
                site.label(),
                site.module,
                site.line
            ));
        }
    }
    for (variant, entry) in &map.sites {
        if !sites.iter().any(|s| s.variant == *variant) {
            errors.push(format!("branch-map.toml: sites {variant} is not a variant"));
        }
        if entry.reason.trim().is_empty() {
            errors.push(format!("branch-map.toml: sites {variant} has no reason"));
        }
    }
    rust_only_errors(&map, &report, &mut errors);
    if command == "list" {
        print_list(&sites, &rust_sites, &map);
    }
    let exempt_sites = all.len().saturating_sub(sites.len());
    println!(
        "branch-map: {} Bend modules (sha256 {}), {} reachable defs, {} branch sites: {} mapped, {} in {} exempt defs; {} Rust labels, {} Rust-only control flow sites",
        rules.modules.len(),
        rules.hash.get(..12).unwrap_or_default(),
        rules.reachable.len(),
        all.len(),
        sites.len(),
        exempt_sites,
        map.exempt.len(),
        report.uses.len(),
        report.unlabelled.len(),
    );
    for error in &errors {
        eprintln!("  {error}");
    }
    if errors.is_empty() {
        println!("branch-map: ok");
    } else {
        eprintln!("branch-map: {} errors", errors.len());
    }
    Ok(errors.is_empty())
}

/// Accounts each unlabelled Rust site to its `[rust_only]` key, and flags unused keys.
fn rust_only_errors(map: &map::Map, report: &rust::Report, errors: &mut Vec<String>) {
    let mut used = BTreeMap::new();
    for u in &report.unlabelled {
        let in_fn = u
            .key
            .split_once(' ')
            .map_or(u.key.as_str(), |(head, _)| head)
            .rsplit_once(':')
            .map_or("", |(f, _)| f);
        let in_file = u.key.split(':').next().unwrap_or_default();
        match [u.key.as_str(), in_fn, in_file]
            .into_iter()
            .find(|k| map.rust_only.contains_key(*k))
        {
            Some(k) => {
                let n = used.entry(k.to_owned()).or_insert(0_usize);
                *n = n.saturating_add(1);
            }
            None => errors.push(format!(
                "{} (line {}): Rust control flow with no branch! and no rust_only entry",
                u.key, u.line
            )),
        }
    }
    for key in map.rust_only.keys() {
        if !used.contains_key(key) {
            errors.push(format!("branch-map.toml: rust_only {key} matches nothing"));
        }
    }
}

fn print_list(sites: &[&bend::Site], rust_sites: &BTreeMap<&str, Vec<String>>, map: &map::Map) {
    for site in sites {
        let at = rust_sites.get(site.variant.as_str()).map(|a| a.join(" ")).unwrap_or_default();
        println!("{}\t{}.bend:{}\t{}\t{at}", site.label(), site.module, site.line, site.variant);
    }
    for (def, reason) in &map.exempt {
        println!("{def}\texempt\t{reason}");
    }
}

/// Entries of `[exempt]` and `[untimed]` that name no def with branches, or
/// have no reason.
fn map_errors(map: &map::Map, all: &[bend::Site]) -> Vec<String> {
    let mut errors = Vec::new();
    for (section, entries) in [("exempt", &map.exempt), ("untimed", &map.untimed)] {
        for (def, reason) in entries {
            if !all.iter().any(|s| s.def_key() == *def) {
                errors.push(format!(
                    "branch-map.toml: {section} {def} is not a reachable Bend def with branches"
                ));
            }
            if reason.trim().is_empty() {
                errors.push(format!("branch-map.toml: {section} {def} has no reason"));
            }
        }
    }
    for def in map.untimed.keys() {
        if map.exempt.contains_key(def) {
            errors.push(format!("branch-map.toml: untimed {def} is exempt, so it has no labels"));
        }
    }
    errors
}

/// Formats generated Rust with the workspace's rustfmt.toml, as `cargo fmt` would.
fn rustfmt(source: &str) -> Result<String> {
    let config = Path::new(env!("CARGO_MANIFEST_DIR")).join("..");
    let mut child = Command::new("rustfmt")
        .args(["--edition", "2024", "--emit", "stdout", "--quiet", "--config-path"])
        .arg(&config)
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .spawn()
        .context("running rustfmt")?;
    child.stdin.take().context("rustfmt stdin")?.write_all(source.as_bytes())?;
    let output = child.wait_with_output()?;
    if !output.status.success() {
        bail!("rustfmt failed on the generated ids.rs");
    }
    String::from_utf8(output.stdout).context("rustfmt output")
}

fn check_rust(src: &Path) -> Result<rust::Report> {
    let mut report = rust::Report::default();
    let mut files = Vec::new();
    for entry in std::fs::read_dir(src)? {
        let path = entry?.path();
        if path.extension().is_some_and(|x| x == "rs") && !path.ends_with("branch.rs") {
            files.push(path);
        }
    }
    files.sort();
    for path in files {
        let source = std::fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
        let name = path.file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
        rust::check(&name, &source, &mut report).with_context(|| format!("parsing {}", path.display()))?;
    }
    Ok(report)
}
