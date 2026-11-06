//! Writes a copy of the Bend tree whose in-scope branches report themselves:
//! each leaf expression under a mapped case is wrapped in `br.arm(T, id, e)`
//! per enclosing mapped case, and each `Bool.pick(T, c, a, b)` becomes
//! `br.pick(T, id, c, a, b)`. Both are identities in Bend; the JS build's
//! post-pass (sim/bend-mp/test/bend-trace.mjs) makes them push the ids.
//! `labels.json` lists the label of each id, as `B::label` gives it.

use std::collections::BTreeMap;
use std::path::Path;

use anyhow::{Context, Result};

use crate::bend::{Def, Rules, Site, code, def_sites};

const HELPERS: &str = "
def br.arm(-A: Data, id: Nat, x: A) -> A:
  x

def br.pick(-A: Data, id: Nat, c: Bool, t: A, f: A) -> A:
  Bool.pick(A, c, t, f)
";

pub fn write(bend_dir: &Path, out: &Path, rules: &Rules, sites: &[&Site]) -> Result<()> {
    copy_tree(bend_dir, out)?;
    let ids: BTreeMap<String, usize> = sites.iter().enumerate().map(|(id, s)| (s.label(), id)).collect();
    for module in &rules.modules {
        let mut lines: Vec<String> = module.source.lines().map(str::to_owned).collect();
        for def in &module.defs {
            if rules.reachable.contains(&(module.name.clone(), def.name.clone())) {
                instrument_def(&module.name, def, &ids, &mut lines);
            }
        }
        // Bend reads a def used above its definition as an unfilled law, so
        // the helpers go after the imports.
        let imports = lines
            .iter()
            .rposition(|l| l.starts_with("import ") || l.starts_with("from "))
            .map_or(0, |i| i.saturating_add(1));
        let (head, rest) = lines.split_at(imports.min(lines.len()));
        let text = format!("{}\n{HELPERS}\n{}\n", head.join("\n"), rest.join("\n"));
        let path = out.join(format!("{}.bend", module.name));
        std::fs::write(&path, text).with_context(|| format!("writing {}", path.display()))?;
    }
    let labels: Vec<String> = sites.iter().map(|s| format!("{:?}", s.label())).collect();
    std::fs::write(out.join("labels.json"), format!("[\n{}\n]\n", labels.join(",\n")))?;
    Ok(())
}

fn copy_tree(from: &Path, to: &Path) -> Result<()> {
    std::fs::create_dir_all(to)?;
    for entry in std::fs::read_dir(from)? {
        let entry = entry?;
        let target = to.join(entry.file_name());
        if entry.file_type()?.is_dir() {
            copy_tree(&entry.path(), &target)?;
        } else if entry.path().extension().is_some_and(|x| x == "bend") {
            std::fs::copy(entry.path(), &target)?;
        }
    }
    Ok(())
}

fn indent(line: &str) -> usize {
    line.len().saturating_sub(line.trim_start().len())
}

fn is_binding(statement: &str) -> bool {
    let head = statement.split_once(" = ").map_or("", |(head, _)| head);
    !head.is_empty()
        && head
            .trim_start_matches('+')
            .split(':')
            .next()
            .is_some_and(|name| name.trim().chars().all(|c| c.is_alphanumeric() || c == '_' || c == '.'))
}

fn instrument_def(module: &str, def: &Def, ids: &BTreeMap<String, usize>, lines: &mut [String]) {
    let site_ids: BTreeMap<usize, usize> = def_sites(module, def)
        .iter()
        .filter(|s| !s.pattern.starts_with("pick"))
        .filter_map(|s| ids.get(&s.label()).map(|id| (s.line, *id)))
        .collect();
    let body: Vec<(usize, usize, String)> = def
        .body
        .iter()
        .filter(|(_, l)| !l.trim().is_empty() && !l.trim().starts_with('#'))
        .map(|(n, l)| (*n, indent(l), l.clone()))
        .collect();
    // (case indent, id) of the enclosing mapped cases.
    let mut open: Vec<(usize, Option<usize>)> = Vec::new();
    let mut pick = 0_usize;
    for (index, (number, ind, line)) in body.iter().enumerate() {
        while open.last().is_some_and(|(at, _)| *at >= *ind) {
            open.pop();
        }
        let text = line.trim();
        if text.starts_with("case ") {
            open.push((*ind, site_ids.get(number).copied()));
            continue;
        }
        let Some(slot) = number.checked_sub(1).and_then(|i| lines.get_mut(i)) else {
            continue;
        };
        for _ in code(text).matches("Bool.pick(") {
            pick = pick.saturating_add(1);
            let label = format!(
                "{module}:{}:{}:True",
                def.name,
                if pick == 1 { "pick".to_owned() } else { format!("pick{pick}") }
            );
            if let Some(id) = ids.get(&label) {
                *slot = with_pick_id(slot, *id);
            }
        }
        if text.starts_with("match ") || is_binding(text) {
            continue;
        }
        let last = body.get(index.saturating_add(1)).is_none_or(|(_, next, _)| next < ind);
        let wraps: Vec<usize> = open.iter().filter_map(|(_, id)| *id).collect();
        if last && !wraps.is_empty() {
            let mut expr = slot.trim().to_owned();
            for id in wraps.iter().rev() {
                expr = format!("br.arm({}, {id}n, {expr})", def.returns);
            }
            *slot = format!("{}{expr}", " ".repeat(*ind));
        }
    }
}

/// Rewrites the first remaining `Bool.pick(T, ` to `br.pick(T, idn, `.
fn with_pick_id(line: &str, id: usize) -> String {
    let Some((before, after)) = line.split_once("Bool.pick(") else {
        return line.to_owned();
    };
    let mut depth = 0_i32;
    for (at, c) in after.char_indices() {
        match c {
            '<' | '(' | '[' | '{' => depth = depth.saturating_add(1),
            '>' | ')' | ']' | '}' => depth = depth.saturating_sub(1),
            ',' if depth == 0_i32 => {
                let (ty, rest) = after.split_at(at);
                return format!("{before}br.pick({ty}, {id}n{rest}");
            }
            _ => {}
        }
    }
    line.to_owned()
}
