//! Checks the rules crate's Rust: every `match` arm, `if` branch and loop is
//! either labelled with exactly one leading `branch!(B::X)` or listed as
//! Rust-only control flow, and no `branch!` stands anywhere else.
//!
//! Labelled forms:
//! - a match whose every arm is a block opening with `branch!`;
//! - an `if` chain whose every block, the final `else` included, opens with `branch!`;
//! - an `if` without `else` whose block opens with `branch!` and ends in
//!   `return`, followed directly by a `branch!` statement (the fallthrough);
//! - a loop whose body opens with `branch!` (one Bend `x <> rest` step),
//!   followed directly by a `branch!` statement (the `Nil` case).
//!
//! The check reads the `seats-2-4` build: a match arm under
//! `#[cfg(not(feature = "seats-2-4"))]`, the `seats-2` copy of an arm whose
//! pattern names a wider table, is skipped.

use std::collections::{BTreeMap, BTreeSet};

use proc_macro2::Span;
use quote::ToTokens;
use syn::visit::{self, Visit};
use syn::{Block, Expr, ExprIf, ExprMatch, Macro, Stmt};

/// One use of a variant.
pub struct Use {
    pub variant: String,
    pub file: String,
    pub line: usize,
}

/// Rust control flow with no Bend branch.
pub struct Unlabelled {
    pub key: String,
    pub line: usize,
}

#[derive(Default)]
pub struct Report {
    pub uses: Vec<Use>,
    pub unlabelled: Vec<Unlabelled>,
    pub errors: Vec<String>,
}

pub fn check(file: &str, source: &str, report: &mut Report) -> anyhow::Result<()> {
    let syntax = syn::parse_file(source)?;
    let mut walker = Walker {
        file,
        report,
        names: Vec::new(),
        accepted: BTreeSet::new(),
        seen: Vec::new(),
        handled_ifs: BTreeSet::new(),
        keys: BTreeMap::new(),
    };
    walker.visit_file(&syntax);
    let Walker { accepted, seen, .. } = walker;
    for (at, variant) in seen {
        if !accepted.contains(&at) {
            report.errors.push(format!("{file}:{}: branch!({variant}) opens no arm", at.0));
        }
    }
    Ok(())
}

type At = (usize, usize);

fn at(span: Span) -> At {
    let start = span.start();
    (start.line, start.column)
}

struct Walker<'a> {
    file: &'a str,
    report: &'a mut Report,
    names: Vec<String>,
    /// `branch!` calls in an accepted position.
    accepted: BTreeSet<At>,
    /// Every `branch!` call.
    seen: Vec<(At, String)>,
    /// `if`s already checked as the no-`else` form.
    handled_ifs: BTreeSet<At>,
    keys: BTreeMap<String, usize>,
}

/// The variant a `branch!(B::X)` names.
fn branch_variant(mac: &Macro) -> Option<String> {
    if !mac.path.is_ident("branch") {
        return None;
    }
    let path: syn::Path = mac.parse_body().ok()?;
    let mut segments = path.segments.iter();
    match (segments.next(), segments.next(), segments.next()) {
        (Some(b), Some(variant), None) if b.ident == "B" => Some(variant.ident.to_string()),
        (Some(_) | None, _, _) => Some(format!("<not B::X: {}>", path.to_token_stream())),
    }
}

fn stmt_branch(stmt: &Stmt) -> Option<(At, String)> {
    let mac = match stmt {
        Stmt::Macro(m) => &m.mac,
        Stmt::Expr(Expr::Macro(m), _) => &m.mac,
        Stmt::Local(_) | Stmt::Item(_) | Stmt::Expr(..) => return None,
    };
    branch_variant(mac).map(|v| (at(mac.path.get_ident().map_or_else(Span::call_site, syn::Ident::span)), v))
}

/// The leading `branch!` calls of a block.
fn leading(block: &Block) -> Vec<(At, String)> {
    block.stmts.iter().map_while(stmt_branch).collect()
}

/// The block of an `if` without `else` (true) or of a loop (false), with its line.
fn fallthrough_body(expr: &Expr) -> Option<(&Block, usize, bool)> {
    if let Expr::If(node) = expr {
        return node
            .else_branch
            .is_none()
            .then(|| (&node.then_branch, at(node.if_token.span).0, true));
    }
    if let Expr::ForLoop(node) = expr {
        return Some((&node.body, at(node.for_token.span).0, false));
    }
    if let Expr::While(node) = expr {
        return Some((&node.body, at(node.while_token.span).0, false));
    }
    if let Expr::Loop(node) = expr {
        return Some((&node.body, at(node.loop_token.span).0, false));
    }
    None
}

fn seats_2_only(attrs: &[syn::Attribute]) -> bool {
    attrs.iter().any(|attr| text(&attr.meta) == "cfg(not(feature = \"seats-2-4\"))")
}

fn diverges(block: &Block) -> bool {
    matches!(block.stmts.last(), Some(Stmt::Expr(Expr::Return(_), _)))
}

fn text(tokens: &impl ToTokens) -> String {
    let raw = tokens.to_token_stream().to_string();
    let mut out = raw;
    for (from, to) in [
        (" (", "("),
        ("( ", "("),
        (" )", ")"),
        (" .", "."),
        (". ", "."),
        (" ,", ","),
        ("! ", "!"),
        (" :: ", "::"),
        ("& ", "&"),
    ] {
        out = out.replace(from, to);
    }
    out
}

impl Walker<'_> {
    fn error(&mut self, line: usize, message: &str) {
        self.report.errors.push(format!("{}:{line}: {message}", self.file));
    }

    /// Accepts a block's leading `branch!`; false when it has none. Two or more is an error.
    fn label(&mut self, block: &Block, line: usize) -> bool {
        let lead = leading(block);
        match lead.as_slice() {
            [] => false,
            [(at, variant)] => {
                self.accepted.insert(*at);
                self.report.uses.push(Use {
                    variant: variant.clone(),
                    file: self.file.to_owned(),
                    line: at.0,
                });
                true
            }
            [_, _, ..] => {
                self.error(line, "a block opens with more than one branch!");
                for (at, _) in &lead {
                    self.accepted.insert(*at);
                }
                true
            }
        }
    }

    fn unlabelled(&mut self, kind: &str, expr: &str, line: usize) {
        let base = format!("{}:{}:{kind} {expr}", self.file, self.names.join("::"));
        let n = self.keys.entry(base.clone()).or_insert(0);
        *n = n.saturating_add(1);
        let key = if *n == 1 { base } else { format!("{base} #{n}") };
        self.report.unlabelled.push(Unlabelled { key, line });
    }

    fn if_chain(node: &ExprIf) -> (Vec<&Block>, Option<&Block>) {
        let mut blocks = vec![&node.then_branch];
        let mut current = node;
        while let Some((_, rest)) = current.else_branch.as_ref() {
            if let Expr::If(next) = rest.as_ref() {
                blocks.push(&next.then_branch);
                current = next;
            } else if let Expr::Block(last) = rest.as_ref() {
                return (blocks, Some(&last.block));
            } else {
                break;
            }
        }
        (blocks, None)
    }

    /// Handles the no-`else` `if` and loop forms, whose fallthrough label is the next statement.
    fn sequence(&mut self, stmts: &[Stmt]) {
        for (index, stmt) in stmts.iter().enumerate() {
            let next = stmts.get(index.saturating_add(1)).and_then(stmt_branch);
            let Stmt::Expr(expr, _) = stmt else { continue };
            let Some((body, line, is_if)) = fallthrough_body(expr) else {
                continue;
            };
            if leading(body).is_empty() {
                continue;
            }
            if let Expr::If(node) = expr {
                self.handled_ifs.insert(at(node.if_token.span));
            }
            self.label(body, line);
            if is_if && !diverges(body) {
                self.error(line, "a labelled if without else must end in return");
            }
            match next {
                Some((at, variant)) => {
                    self.accepted.insert(at);
                    self.report.uses.push(Use {
                        variant,
                        file: self.file.to_owned(),
                        line: at.0,
                    });
                }
                None => self.error(line, "a labelled if without else or loop must be followed by a branch!"),
            }
        }
    }

    fn loop_body(&mut self, kind: &str, head: &str, body: &Block, line: usize) {
        if leading(body).is_empty() {
            self.unlabelled(kind, head, line);
        }
    }
}

impl<'ast> Visit<'ast> for Walker<'_> {
    fn visit_item_fn(&mut self, node: &'ast syn::ItemFn) {
        self.names.push(node.sig.ident.to_string());
        visit::visit_item_fn(self, node);
        self.names.pop();
    }

    fn visit_item_impl(&mut self, node: &'ast syn::ItemImpl) {
        let name = if let syn::Type::Path(path) = node.self_ty.as_ref() {
            path.path.segments.last().map_or_else(String::new, |s| s.ident.to_string())
        } else {
            text(&node.self_ty)
        };
        self.names.push(name);
        visit::visit_item_impl(self, node);
        self.names.pop();
    }

    fn visit_impl_item_fn(&mut self, node: &'ast syn::ImplItemFn) {
        self.names.push(node.sig.ident.to_string());
        visit::visit_impl_item_fn(self, node);
        self.names.pop();
    }

    fn visit_item_macro(&mut self, node: &'ast syn::ItemMacro) {
        // The `branch!` definition itself.
        if node.mac.path.is_ident("macro_rules") {
            return;
        }
        visit::visit_item_macro(self, node);
    }

    fn visit_macro(&mut self, node: &'ast Macro) {
        if let Some(variant) = branch_variant(node) {
            self.seen
                .push((at(node.path.get_ident().map_or_else(Span::call_site, syn::Ident::span)), variant));
        }
        visit::visit_macro(self, node);
    }

    fn visit_block(&mut self, node: &'ast Block) {
        self.sequence(&node.stmts);
        visit::visit_block(self, node);
    }

    fn visit_expr_match(&mut self, node: &'ast ExprMatch) {
        let line = at(node.match_token.span).0;
        let mut labelled = 0_usize;
        let mut bare = Vec::new();
        for arm in &node.arms {
            if seats_2_only(&arm.attrs) {
                if let Expr::Block(block) = arm.body.as_ref() {
                    self.accepted.extend(leading(&block.block).into_iter().map(|(at, _)| at));
                }
                continue;
            }
            let arm_line = at(arm.fat_arrow_token.spans[0]).0;
            let is_labelled = if let Expr::Block(block) = arm.body.as_ref() {
                self.label(&block.block, arm_line)
            } else {
                false
            };
            if is_labelled {
                labelled = labelled.saturating_add(1);
            } else {
                bare.push(arm_line);
            }
        }
        if labelled == 0 {
            self.unlabelled("match", &text(&node.expr), line);
        } else if !bare.is_empty() {
            self.error(line, &format!("match arms without branch! at lines {bare:?}"));
        }
        visit::visit_expr_match(self, node);
    }

    fn visit_expr_if(&mut self, node: &'ast ExprIf) {
        let line = at(node.if_token.span).0;
        if !self.handled_ifs.contains(&at(node.if_token.span)) {
            let (blocks, last) = Self::if_chain(node);
            let labels: Vec<bool> = blocks.iter().chain(last.iter()).map(|b| !leading(b).is_empty()).collect();
            if labels.iter().all(|l| !l) {
                self.unlabelled("if", &text(&node.cond), line);
            } else if labels.iter().any(|l| !l) || last.is_none() {
                self.error(line, "an if chain with branch! needs it in every block, a final else included");
            } else {
                for block in blocks.into_iter().chain(last) {
                    self.label(block, line);
                }
            }
        }
        // Visit the chain's parts without re-checking its `else if`s as new chains.
        self.visit_expr(&node.cond);
        self.visit_block(&node.then_branch);
        let mut rest = node.else_branch.as_ref().map(|(_, e)| e.as_ref());
        while let Some(expr) = rest {
            if let Expr::If(next) = expr {
                self.visit_expr(&next.cond);
                self.visit_block(&next.then_branch);
                rest = next.else_branch.as_ref().map(|(_, e)| e.as_ref());
            } else {
                self.visit_expr(expr);
                rest = None;
            }
        }
    }

    fn visit_expr_for_loop(&mut self, node: &'ast syn::ExprForLoop) {
        let head = format!("{} in {}", text(&node.pat), text(&node.expr));
        self.loop_body("for", &head, &node.body, at(node.for_token.span).0);
        visit::visit_expr_for_loop(self, node);
    }

    fn visit_expr_while(&mut self, node: &'ast syn::ExprWhile) {
        self.loop_body("while", &text(&node.cond), &node.body, at(node.while_token.span).0);
        visit::visit_expr_while(self, node);
    }

    fn visit_expr_loop(&mut self, node: &'ast syn::ExprLoop) {
        self.loop_body("loop", "", &node.body, at(node.loop_token.span).0);
        visit::visit_expr_loop(self, node);
    }
}
