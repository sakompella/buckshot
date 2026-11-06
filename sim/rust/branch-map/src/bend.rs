//! Reads the Bend rules: the modules `simple/main.bend` imports, their defs,
//! and every branch site (a case of a match with two or more cases, or an
//! arm of a `Bool.pick`) in the defs reachable from the simple machine's
//! entry points.

use std::collections::{BTreeMap, BTreeSet};
use std::fmt::Write as _;
use std::path::{Path, PathBuf};

use anyhow::{Context, Result, bail};
use sha2::{Digest, Sha256};

/// The simple machine's entry points: what the Rust core's `start`,
/// `request` and `step` mirror.
const ROOT: &str = "simple/main";
const ENTRIES: [&str; 3] = ["start", "request", "answer"];

pub struct Module {
    pub name: String,
    pub source: String,
    aliases: BTreeMap<String, String>,
    pub defs: Vec<Def>,
}

pub struct Def {
    pub name: String,
    /// The def's return type.
    pub returns: String,
    /// (line number, line) of the body, the header excluded.
    pub body: Vec<(usize, String)>,
}

/// One Bend branch: a case of a match or an arm of a `Bool.pick`.
pub struct Site {
    pub module: String,
    pub def: String,
    /// The case pattern as written, or `pick:True` / `pick:False` (`pick2:` for a def's second pick).
    pub pattern: String,
    pub line: usize,
    pub variant: String,
}

impl Site {
    pub fn label(&self) -> String {
        format!("{}:{}:{}", self.module, self.def, self.pattern)
    }

    pub fn def_key(&self) -> String {
        format!("{}:{}", self.module, self.def)
    }
}

pub struct Rules {
    pub modules: Vec<Module>,
    pub reachable: BTreeSet<(String, String)>,
    /// sha256 over every module's path and source, in module order.
    pub hash: String,
}

pub fn load(bend_dir: &Path) -> Result<Rules> {
    let mut modules: Vec<Module> = Vec::new();
    let mut queue = vec![ROOT.to_owned()];
    while let Some(name) = queue.pop() {
        if modules.iter().any(|m| m.name == name) {
            continue;
        }
        let path = bend_dir.join(format!("{name}.bend"));
        let source = std::fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
        let module = parse_module(&name, source)?;
        queue.extend(module.aliases.values().cloned());
        modules.push(module);
    }
    modules.sort_by(|a, b| a.name.cmp(&b.name));
    let mut hasher = Sha256::new();
    for module in &modules {
        hasher.update(module.name.as_bytes());
        hasher.update([0]);
        hasher.update(module.source.as_bytes());
        hasher.update([0]);
    }
    let hash = hasher.finalize().iter().fold(String::new(), |mut hex, byte| {
        let _ = write!(hex, "{byte:02x}");
        hex
    });
    let reachable = reachable(&modules)?;
    Ok(Rules { modules, reachable, hash })
}

fn parse_module(name: &str, source: String) -> Result<Module> {
    let dir = Path::new(name).parent().map(Path::to_path_buf).unwrap_or_default();
    let mut aliases = BTreeMap::new();
    let mut defs: Vec<Def> = Vec::new();
    let mut current: Option<Def> = None;
    for (index, line) in source.lines().enumerate() {
        let number = index.saturating_add(1);
        if let Some(rest) = line.strip_prefix("import ") {
            if let Some((path, alias)) = rest.split_once(" as ") {
                aliases.insert(alias.trim().to_owned(), resolve(&dir, path.trim())?);
            }
            continue;
        }
        if let Some(rest) = line.strip_prefix("def ") {
            defs.extend(current.take());
            let def_name = rest.split('(').next().unwrap_or_default().trim().to_owned();
            let returns = rest
                .rsplit_once("->")
                .map_or("", |(_, r)| r)
                .trim()
                .trim_end_matches(':')
                .trim()
                .to_owned();
            current = Some(Def {
                name: def_name,
                returns,
                body: Vec::new(),
            });
            continue;
        }
        if !line.is_empty() && !line.starts_with(char::is_whitespace) {
            defs.extend(current.take());
            continue;
        }
        if let Some(def) = current.as_mut() {
            def.body.push((number, line.to_owned()));
        }
    }
    defs.extend(current);
    Ok(Module {
        name: name.to_owned(),
        source,
        aliases,
        defs,
    })
}

fn resolve(dir: &Path, import: &str) -> Result<String> {
    let mut path = PathBuf::new();
    for part in dir.join(import.trim_end_matches(".bend")).components() {
        match part {
            std::path::Component::ParentDir => {
                if !path.pop() {
                    bail!("import {import} leaves the Bend tree");
                }
            }
            std::path::Component::Normal(part) => path.push(part),
            std::path::Component::CurDir | std::path::Component::RootDir | std::path::Component::Prefix(_) => {}
        }
    }
    Ok(path.to_string_lossy().into_owned())
}

/// The code of a line without its comment.
pub fn code(line: &str) -> &str {
    line.split('#').next().unwrap_or_default()
}

/// The defs a def names: calls and bare references, local or through an import alias.
fn references(modules: &[Module], module: &Module, def: &Def) -> Vec<(String, String)> {
    let mut out = Vec::new();
    let has = |module: &str, name: &str| modules.iter().any(|m| m.name == module && m.defs.iter().any(|d| d.name == name));
    for (_, line) in &def.body {
        for word in words(code(line)) {
            let target = match word.split_once('.') {
                Some((alias, rest)) if module.aliases.contains_key(alias) => {
                    module.aliases.get(alias).map(|m| (m.clone(), rest.to_owned()))
                }
                _ => Some((module.name.clone(), word.to_owned())),
            };
            if let Some((m, name)) = target
                && has(&m, &name)
            {
                out.push((m, name));
            }
        }
    }
    out
}

/// Dotted identifiers in a line of code.
fn words(code: &str) -> impl Iterator<Item = &str> {
    code.split(|c: char| !(c.is_alphanumeric() || c == '_' || c == '.'))
        .map(|w| w.trim_matches('.'))
        .filter(|w| w.starts_with(|c: char| c.is_alphabetic() || c == '_'))
}

fn reachable(modules: &[Module]) -> Result<BTreeSet<(String, String)>> {
    let mut seen = BTreeSet::new();
    let mut queue: Vec<(String, String)> = ENTRIES.iter().map(|e| (ROOT.to_owned(), (*e).to_owned())).collect();
    while let Some((module_name, def_name)) = queue.pop() {
        if !seen.insert((module_name.clone(), def_name.clone())) {
            continue;
        }
        let module = modules.iter().find(|m| m.name == module_name).context("module")?;
        let def = module
            .defs
            .iter()
            .find(|d| d.name == def_name)
            .with_context(|| format!("no def {module_name}:{def_name}"))?;
        queue.extend(references(modules, module, def));
    }
    Ok(seen)
}

struct Match {
    indent: usize,
    cases: Vec<(String, usize)>,
}

/// Every branch site of the reachable defs, in source order.
pub fn sites(rules: &Rules) -> Vec<Site> {
    let mut out = Vec::new();
    for module in &rules.modules {
        for def in &module.defs {
            if !rules.reachable.contains(&(module.name.clone(), def.name.clone())) {
                continue;
            }
            out.extend(def_sites(&module.name, def));
        }
    }
    out
}

pub fn def_sites(module: &str, def: &Def) -> Vec<Site> {
    let prefix = format!("{}{}", camel(module), camel(&def.name));
    let mut matches: Vec<Match> = Vec::new();
    let mut open: Vec<usize> = Vec::new();
    let mut picks: Vec<(usize, usize)> = Vec::new();
    for (number, line) in &def.body {
        let text = line.trim();
        if text.is_empty() || text.starts_with('#') {
            continue;
        }
        let indent = line.len().saturating_sub(line.trim_start().len());
        while open.last().is_some_and(|&m| matches.get(m).is_some_and(|m| m.indent >= indent)) {
            open.pop();
        }
        if let Some(pattern) = text.strip_prefix("case ").and_then(|t| t.strip_suffix(':')) {
            if let Some(m) = open.last().and_then(|&m| matches.get_mut(m)) {
                m.cases.push((pattern.to_owned(), *number));
            }
        } else if text.starts_with("match ") && text.ends_with(':') {
            open.push(matches.len());
            matches.push(Match { indent, cases: Vec::new() });
        }
        for _ in code(line).matches("Bool.pick(") {
            picks.push((*number, picks.len().saturating_add(1)));
        }
    }
    let mut out = Vec::new();
    for m in matches.iter().filter(|m| m.cases.len() > 1) {
        let names = case_names(&m.cases.iter().map(|(p, _)| p.as_str()).collect::<Vec<_>>());
        for ((pattern, line), name) in m.cases.iter().zip(names) {
            out.push(Site {
                module: module.to_owned(),
                def: def.name.clone(),
                pattern: pattern.clone(),
                line: *line,
                variant: format!("{prefix}{name}"),
            });
        }
    }
    for (line, k) in picks {
        let pick = if k == 1 { "pick".to_owned() } else { format!("pick{k}") };
        for arm in ["True", "False"] {
            out.push(Site {
                module: module.to_owned(),
                def: def.name.clone(),
                pattern: format!("{pick}:{arm}"),
                line,
                variant: format!("{prefix}{}{arm}", camel(&pick)),
            });
        }
    }
    out
}

fn camel(path: &str) -> String {
    path.split(['.', '_', '/'])
        .flat_map(|part| {
            let mut chars = part.chars();
            chars.next().map(|first| first.to_uppercase().chain(chars)).into_iter().flatten()
        })
        .collect()
}

/// A case's name: the constructors and literals of its pattern in order,
/// `Cons` per `<>`, `Any` for a pattern of only variables. When two cases
/// of one match get the same name, variables there become `Any`.
fn case_names(patterns: &[&str]) -> Vec<String> {
    let plain: Vec<String> = patterns.iter().map(|p| name(p, false)).collect();
    plain
        .iter()
        .zip(patterns)
        .map(|(n, p)| {
            if plain.iter().filter(|other| *other == n).count() > 1 {
                name(p, true)
            } else {
                n.clone()
            }
        })
        .collect()
}

fn name(pattern: &str, any_vars: bool) -> String {
    let words: Vec<String> = split_top(&pattern.replace(" <> ", "\u{0}"), ' ')
        .iter()
        .flat_map(|scrutinee| {
            let words = cons_words(&scrutinee.replace('\u{0}', " <> "));
            if words.is_empty() && any_vars {
                vec!["Any".to_owned()]
            } else {
                words
            }
        })
        .collect();
    if words.is_empty() { "Any".to_owned() } else { words.concat() }
}

fn cons_words(pattern: &str) -> Vec<String> {
    let parts = split_top_str(pattern.trim(), " <> ");
    let Some((last, heads)) = parts.split_last() else {
        return Vec::new();
    };
    if heads.is_empty() {
        return words_of(last);
    }
    let mut out: Vec<String> = heads.iter().flat_map(|h| words_of(h)).collect();
    out.extend(heads.iter().map(|_| "Cons".to_owned()));
    if last.trim() == "Nil{}" {
        out.push("Nil".to_owned());
    }
    out
}

fn words_of(pattern: &str) -> Vec<String> {
    let p = pattern.trim().trim_start_matches('+');
    if let Some((ctor, fields)) = p.strip_suffix('}').and_then(|p| p.split_once('{')) {
        let mut out = vec![ctor.rsplit('.').next().unwrap_or(ctor).to_owned()];
        out.extend(split_top(fields, ',').iter().flat_map(|f| words_of(f)));
        return out;
    }
    if let Some(n) = p.strip_suffix('n').and_then(|n| n.parse::<usize>().ok()) {
        let numbers = ["Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"];
        return vec![numbers.get(n).map_or_else(|| format!("N{n}"), |w| (*w).to_owned())];
    }
    if p.starts_with("1n+") {
        return p.matches("1n+").map(|_| "Succ".to_owned()).collect();
    }
    Vec::new()
}

fn split_top(s: &str, sep: char) -> Vec<String> {
    split_top_str(s, &sep.to_string())
}

/// Splits at `sep` outside braces and parentheses.
fn split_top_str(s: &str, sep: &str) -> Vec<String> {
    let mut out = Vec::new();
    let mut depth = 0_i32;
    let mut current = String::new();
    let mut rest = s;
    while let Some(c) = rest.chars().next() {
        if depth == 0 && rest.starts_with(sep) {
            out.push(std::mem::take(&mut current));
            rest = rest.get(sep.len()..).unwrap_or_default();
            continue;
        }
        match c {
            '{' | '(' => depth = depth.saturating_add(1),
            '}' | ')' => depth = depth.saturating_sub(1),
            _ => {}
        }
        current.push(c);
        rest = rest.get(c.len_utf8()..).unwrap_or_default();
    }
    out.push(current);
    out.retain(|part| !part.trim().is_empty());
    out
}
