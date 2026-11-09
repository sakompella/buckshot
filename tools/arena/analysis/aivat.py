"""Luck-adjusted Round Elo: AIVAT corrections at the chance events of every round, rated like Round Elo.

For each chance event the correction is sum_o P(o) V(o) - V(realised outcome), with P the true chance of each outcome and V a
round-win value of the public state after it. The adjusted round result is the round's result plus its corrections, in position
1's view. The corrections have mean zero for any V that depends only on the history before the event and the outcome, so the
adjusted results rate the same strengths with less luck in them. The model seats are unknown policies, so there are no decision
terms. The chance events:

- Shots. The shell order is uniform over the orders that fit both players' clues together, so P(live) is the chamber's live
  chance given every clue either player holds. V: gradient boosting on the state after the shot (both healths, shells and
  expected lives left, who moves, item counts, round); a shot that ends the round has its exact 0 or 1.
- Loads. The two-seat deck of nine compositions is drawn without replacement and refilled when empty, across rounds, so P is the
  count left in the deck over its size. V: a logistic on the health gap and the composition.
- Round 1's first seat, a coin flip. V: the mean round 1 result of each starter.

Every V is fitted out of fold, five folds by seed, so no round is corrected by a model that saw it. The output database holds
per match and player the sum of that player's corrections over the match's rounds; the viewer adds it to the player's round wins
before the Round Elo fit (web/src/arena-viewer/page/ratings.ts). With --doc FILE the method's tables replace the text between the
luck markers of that file (docs/arena/analysis/matchups.md).

    python3 tools/arena/analysis/aivat.py [--db PATH] [--knowledge PATH] [--out derived/luck.sqlite] [--doc FILE]
"""

import argparse
import bisect
import json
import re
import sqlite3
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

import bt
import numpy as np
import pandas as pd
from by_round import public_lines, round_winners
from fmt import table
from load import DB, SKIPPED_MODEL, connect, require_current, round_one_starters
from regret import DERIVED
from scipy import stats
from sklearn.ensemble import HistGradientBoostingClassifier
from sklearn.linear_model import LogisticRegression

from docs import splice_between_markers

# The two-seat deck, table.deck(TwoSeats) in sim/bend-mp: (live, blank) per load.
DECK = ((1, 2), (2, 1), (2, 2), (3, 2), (1, 1), (2, 3), (3, 3), (3, 1), (4, 2))
FOLDS = 5
SHOT = re.compile(r"^Player \w+ shot (?:themselves|Player \w+): (live|blank)")
DRAWS = 200


def shot_outcomes(lines: list[str]) -> list[bool]:
    """Whether each shot of a match's public log was live, in order."""
    return [m[1] == "live" for line in lines if (m := SHOT.match(line))]


def deck_chances(loads: list[tuple[int, int]]) -> list[dict[tuple[int, int], float]]:
    """Before each load of a match, the chance of each composition. Raises when a load is not in the deck."""
    deck, out = Counter(DECK), []
    for comp in loads:
        if not deck.total():
            deck = Counter(DECK)
        if not deck[comp]:
            raise ValueError(f"load {comp} is not left in the deck")
        n = deck.total()
        out.append({c: v / n for c, v in deck.items() if v})
        deck[comp] -= 1
    return out


def folds(seeds, rs: int = 0, k: int = FOLDS) -> np.ndarray:
    u = np.unique(seeds)
    f = dict(zip(u, np.random.default_rng(rs).integers(0, k, len(u))))
    return np.array([f[s] for s in seeds])


@dataclass
class Data:
    matches: pd.DataFrame  # mi, match_id, seed, block, first, second, letter1, letter2, starter
    rounds: pd.DataFrame  # mi, r (0-based), O (position 1 won)
    dec: pd.DataFrame  # knowledge decisions of the rated matches
    consumed: dict  # match_id -> ordinal -> shells consumed before it
    inverters: dict  # match_id -> ordinals of inverter uses
    clues: pd.DataFrame
    outcomes: dict  # match_id -> live per shot, in order


def read(db_path: str, knowledge_path: str) -> Data:
    db, kn = connect(db_path), connect(knowledge_path)
    starters, lines = round_one_starters(db), public_lines(db)
    seats = defaultdict(list)
    for row in db.execute(
        """SELECT s.match_id, s.player, s.cash, e.name, e.model FROM match_seats s JOIN entrants e ON e.id = s.entrant_id
           JOIN matches m ON m.id = s.match_id WHERE m.status = 'completed' ORDER BY s.match_id, s.position"""
    ):
        seats[row[0]].append(row[1:])
    rows, rounds = [], []
    for match, seed, block in db.execute("SELECT id, seed, seed_block_id FROM matches WHERE status = 'completed' ORDER BY id"):
        s = seats[match]
        if len(s) != 2 or any(SKIPPED_MODEL in (model or "") for *_, model in s):
            continue
        (la, ca, a, _), (lb, cb, b, _) = s
        won = round_winners(match, lines.get(match, []), {la: ca, lb: cb})
        mi = len(rows)
        rows.append((mi, match, seed, block, a, b, la, lb, 1 if starters[match] == la else 2))
        rounds += [(mi, n - 1, 1.0 if w == la else 0.0) for n, w in sorted(won.items())]
    matches = pd.DataFrame(rows, columns=["mi", "match_id", "seed", "block", "first", "second", "letter1", "letter2", "starter"])
    ids = set(matches.match_id)
    dec = pd.read_sql(
        "SELECT match_id, ordinal, player, round, remaining, private_known, private_orders, private_live_json, shot, sawed, item,"
        " health_json, own_items_json, opponent_items_json, shown_live, shown_blank FROM decisions",
        kn,
    )
    dec = dec[dec.match_id.isin(ids)].sort_values(["match_id", "ordinal"]).reset_index(drop=True)
    labels = pd.DataFrame(db.execute("SELECT match_id, ordinal, label FROM decisions").fetchall(), columns=["match_id", "ordinal", "label"])
    labels = labels[labels.match_id.isin(ids)].sort_values(["match_id", "ordinal"])
    labels["c"] = (labels.label.str.startswith("Shoot") | labels.label.str.startswith("Steal beer") | (labels.label == "Use beer")).astype(int)
    consumed = {m: dict(zip(g.ordinal, np.concatenate([[0], np.cumsum(g.c.values)[:-1]]))) for m, g in labels.groupby("match_id")}
    inverters = defaultdict(list)
    for t in labels[labels.label.str.contains("inverter")].itertuples():
        inverters[t.match_id].append(t.ordinal)
    clues = pd.read_sql("SELECT match_id, ordinal, player, position, shell FROM clues", kn)
    outcomes = {m: shot_outcomes(lines.get(m, [])) for m in ids}
    return Data(matches, rounds=pd.DataFrame(rounds, columns=["mi", "r", "O"]), dec=dec, consumed=consumed, inverters=inverters, clues=clues, outcomes=outcomes)


def shots_of(d: Data) -> pd.DataFrame:
    """Every shot of a known round, with its outcome, the true live chance, and the mover's view of the state."""
    mi_of = dict(zip(d.matches.match_id, d.matches.mi))
    pos_of = {(m, l): p for m, l1, l2 in zip(d.matches.match_id, d.matches.letter1, d.matches.letter2) for l, p in ((l1, 1), (l2, 2))}
    O = {(mi, r): o for mi, r, o in zip(d.rounds.mi, d.rounds.r, d.rounds.O)}
    sh = d.dec[d.dec.shot.notna()].copy()
    live = []
    for m, g in sh.groupby("match_id", sort=False):
        seen = d.outcomes[m]
        # The last shot of a match ends it, so no log shows it; it was live.
        live += (seen + [True] * (len(g) - len(seen)))[: len(g)] if len(seen) >= len(g) - 1 else [np.nan] * len(g)
    sh["live"] = live
    sh["mi"] = sh.match_id.map(mi_of)
    sh["O1"] = [O.get((a, b), np.nan) for a, b in zip(sh.mi, sh["round"])]
    sh = sh[sh.live.notna() & sh.O1.notna()].reset_index(drop=True)
    sh["live"] = sh.live.astype(float)
    sh["pos"] = [pos_of[(m, p)] for m, p in zip(sh.match_id, sh.player)]
    sh["Om"] = np.where(sh.pos == 1, sh.O1, 1 - sh.O1)
    lives = [json.loads(s) for s in sh.private_live_json]
    sh["p"] = [lv[0] / n for lv, n in zip(lives, sh.private_orders)]
    sh["El"] = [sum(lv) / n for lv, n in zip(lives, sh.private_orders)]
    sh["pt"] = true_live_chances(d, sh)
    hj = [json.loads(h) for h in sh.health_json]
    sh["hm"] = [h[0]["health"] for h in hj]
    sh["jo"] = [h[1]["_tag"] == "Jammed" for h in hj]
    sh["im"] = [len(json.loads(s)) for s in sh.own_items_json]
    sh["io"] = [len(json.loads(s)) for s in sh.opponent_items_json]
    sh["ho"] = opponent_health(d, sh)
    return sh


def true_live_chances(d: Data, sh: pd.DataFrame) -> list[float]:
    """The chamber's live chance given the clues of both players: uniform over the shell orders they all fit."""
    rows_by, clue_by = defaultdict(list), defaultdict(list)
    for t in d.dec.itertuples():
        rows_by[(t.match_id, t.player)].append((t.ordinal, t.round, t.private_known))
    for t in d.clues.itertuples():
        clue_by[(t.match_id, t.player)].append((t.ordinal, t.position, t.shell == "Live"))
    known_at = {(t.match_id, t.ordinal): t.private_known for t in d.dec.itertuples()}

    def by_index(text, consumed):
        return {consumed + int(tok[:-1]) - 1: tok[-1] == "L" for tok in (text or "").split()}

    def flipped(m, g, lo, hi, v):
        for at in d.inverters[m]:
            if lo <= at < hi and d.consumed[m][at] == g:
                v = not v
        return v

    def chance(row):
        m, C = row.match_id, d.consumed[row.match_id]
        cs, rem = C[row.ordinal], row.remaining
        know = {}
        other = next(k for k in (row.letter1, row.letter2) if k != row.player)
        rs = rows_by[(m, other)]
        i = bisect.bisect_left(rs, (row.ordinal,)) - 1
        if i >= 0 and rs[i][1] == row.round:
            o0 = rs[i][0]
            know.update({g: flipped(m, g, o0, row.ordinal, v) for g, v in by_index(rs[i][2], C[o0]).items()})
            for oc, at, lv in clue_by[(m, other)]:
                if o0 <= oc < row.ordinal:
                    g = C[oc] + at - 1
                    know[g] = flipped(m, g, oc + 1, row.ordinal, lv)
        know = {g: v for g, v in know.items() if cs <= g < cs + rem}
        u = {**know, **by_index(known_at[(m, row.ordinal)], cs)}
        if cs in u:
            return float(u[cs])
        if abs(row.El - round(row.El)) < 1e-9 and rem > len(u):
            return (round(row.El) - sum(u.values())) / (rem - len(u))
        return row.p

    letters = d.matches.set_index("match_id")[["letter1", "letter2"]]
    rows = sh.join(letters, on="match_id")
    return [chance(r) for r in rows.itertuples()]


def opponent_health(d: Data, sh: pd.DataFrame) -> list[float]:
    """The opponent's health at each shot; a jammed opponent's is hidden, so carry the last seen value through shots and cigarettes."""
    shot_at = {(a, b): (s, lv, sw) for a, b, s, lv, sw in zip(sh.match_id, sh.ordinal, sh.shot, sh.live, sh.sawed)}
    letters = {m: (a, b) for m, a, b in zip(d.matches.match_id, d.matches.letter1, d.matches.letter2)}
    at = {}
    for m, g in d.dec[d.dec.match_id.isin(set(sh.match_id))].groupby("match_id"):
        hp, rnd = {}, None
        for t in g.itertuples():
            if t.round != rnd:
                hp, rnd = {}, t.round
            h = json.loads(t.health_json)
            me = t.player
            op = next(k for k in letters[m] if k != me)
            hp[me] = h[0]["health"]
            if "health" in h[1]:
                hp[op] = h[1]["health"]
            if (m, t.ordinal) in shot_at:
                at[(m, t.ordinal)] = hp.get(op, np.nan)
                s, lv, sw = shot_at[(m, t.ordinal)]
                if lv == 1:
                    hp[me if s == "self" else op] -= 2 if sw else 1
            if t.item == "Cigarettes":
                hp[me] += 1
    return [at[(a, b)] for a, b in zip(sh.match_id, sh.ordinal)]


def after_shot(sh: pd.DataFrame, live: np.ndarray):
    """The state after the shot, if it was live (1) or blank (0), as features, and the round's result when the shot ends it."""
    dmg = np.where(sh.sawed == 1, 2, 1) * live
    selfshot = (sh.shot == "self").values
    hm = sh.hm.values - np.where(selfshot, dmg, 0)
    ho = sh.ho.values - np.where(~selfshot, dmg, 0)
    end = np.where(hm <= 0, 0.0, np.where(ho <= 0, 1.0, np.nan))
    keeps = (selfshot & (live == 0)) | (sh.jo.values & ~(selfshot & (live == 0)))
    n2, l2 = sh.remaining.values - 1, sh.El.values - live
    return np.column_stack([hm, ho, hm - ho, n2, l2, n2 - l2, keeps, n2 == 0, sh.im, sh.io, sh["round"], sh.jo, sh.sawed]), end


def round_sum(values, mi, r, rounds: pd.DataFrame) -> np.ndarray:
    idx = pd.MultiIndex.from_arrays([rounds.mi, rounds.r])
    return pd.Series(np.asarray(values, float)).groupby([np.asarray(mi), np.asarray(r)]).sum().reindex(idx, fill_value=0).values


def shot_corrections(d: Data, sh: pd.DataFrame) -> np.ndarray:
    seeds = d.matches.seed.values
    lv = sh.live.values == 1
    XL, EL = after_shot(sh, np.ones(len(sh)))
    XB, EB = after_shot(sh, np.zeros(len(sh)))
    X, E = np.where(lv[:, None], XL, XB), np.where(lv, EL, EB)
    f = folds(seeds[sh.mi])
    vL, vB = np.empty(len(sh)), np.empty(len(sh))
    for k in range(FOLDS):
        train, test = (f != k) & np.isnan(E), f == k
        model = HistGradientBoostingClassifier(max_iter=200, learning_rate=0.08, max_leaf_nodes=31, min_samples_leaf=50, random_state=0)
        model.fit(X[train], sh.Om.values[train])
        vL[test], vB[test] = model.predict_proba(XL[test])[:, 1], model.predict_proba(XB[test])[:, 1]
    vL, vB = np.where(np.isnan(EL), vL, EL), np.where(np.isnan(EB), vB, EB)
    c = (sh.pt * vL + (1 - sh.pt) * vB - np.where(lv, vL, vB)) * np.where(sh.pos == 1, 1.0, -1.0)
    return round_sum(c.values, sh.mi.values, sh["round"].values, d.rounds)


def load_corrections(d: Data) -> np.ndarray:
    pos_of = {(m, l): p for m, l1, l2 in zip(d.matches.match_id, d.matches.letter1, d.matches.letter2) for l, p in ((l1, 1), (l2, 2))}
    mi_of = dict(zip(d.matches.match_id, d.matches.mi))
    O = {(mi, r): o for mi, r, o in zip(d.rounds.mi, d.rounds.r, d.rounds.O)}
    dec = d.dec.copy()
    dec["C"] = [d.consumed[m][o] for m, o in zip(dec.match_id, dec.ordinal)]
    dec["start"] = dec.C - (dec.shown_live + dec.shown_blank - dec.remaining)
    rows = []
    for m, g in dec.groupby("match_id"):
        firsts = g.groupby("start").first().reset_index()
        comps = [(int(a), int(b)) for a, b in zip(firsts.shown_live, firsts.shown_blank)]
        for t, comp, chances in zip(firsts.itertuples(), comps, deck_chances(comps)):
            if (mi_of[m], t.round) not in O:
                continue
            h = json.loads(t.health_json)
            pos = pos_of[(m, t.player)]
            o1 = O[(mi_of[m], t.round)]
            rows.append((mi_of[m], t.round, pos, comp, chances, h[0]["health"], h[1].get("health", np.nan), o1 if pos == 1 else 1 - o1))
    ld = pd.DataFrame(rows, columns=["mi", "round", "pos", "comp", "chances", "hm", "ho", "Om"])

    def features(df, comps):
        lc = np.array([c[0] for c in comps])
        bk = np.array([c[1] for c in comps])
        n = lc + bk
        hm, ho = df.hm.fillna(df.hm.mean()).values, df.ho.fillna(3).values
        return np.column_stack([hm - ho, lc / n, n, (hm - ho) * lc / n, lc, bk, lc / n / ho, lc / n / hm])

    f = folds(d.matches.seed.values[ld.mi])
    c = np.zeros(len(ld))
    for k in range(FOLDS):
        train, test = f != k, np.where(f == k)[0]
        sub = ld.iloc[test]
        model = LogisticRegression(max_iter=1000).fit(features(ld[train], list(ld.comp[train])), ld.Om.values[train])
        V = np.column_stack([model.predict_proba(features(sub, [comp] * len(sub)))[:, 1] for comp in DECK])
        P = np.array([[p.get(comp, 0) for comp in DECK] for p in sub.chances])
        c[test] = (P * V).sum(1) - V[np.arange(len(sub)), [DECK.index(comp) for comp in sub.comp]]
    return round_sum(c * np.where(ld.pos == 1, 1, -1), ld.mi.values, ld["round"].values, d.rounds)


def seat_corrections(d: Data) -> np.ndarray:
    R = d.rounds
    starter = d.matches.starter.values[R.mi]
    first = (R.r == 0).values
    f = folds(d.matches.seed.values[R.mi])
    c = np.zeros(len(R))
    for k in range(FOLDS):
        train, test = (f != k) & first, (f == k) & first
        v1, v2 = R.O[train & (starter == 1)].mean(), R.O[train & (starter == 2)].mean()
        c[test] = 0.5 * (v1 + v2) - np.where(starter[test] == 1, v1, v2)
    return c


def corrections(d: Data) -> np.ndarray:
    """Per round of d.rounds, the sum of its corrections in position 1's view."""
    return shot_corrections(d, shots_of(d)) + load_corrections(d) + seat_corrections(d)


# RATINGS AND THE BIAS TEST


@dataclass
class Rated:
    names: list[str]
    i: np.ndarray  # per match, the first config's index
    j: np.ndarray
    n: np.ndarray  # rounds
    raw: np.ndarray  # position 1's round wins
    luck: np.ndarray  # position 1's corrections, summed over the match's rounds
    seed: np.ndarray
    block: np.ndarray


def rated(d: Data, c: np.ndarray) -> Rated:
    names = sorted(set(d.matches["first"]) | set(d.matches.second))
    ix = {n: k for k, n in enumerate(names)}
    nm = len(d.matches)
    return Rated(
        names,
        np.array([ix[a] for a in d.matches["first"]]),
        np.array([ix[b] for b in d.matches.second]),
        np.bincount(d.rounds.mi, minlength=nm).astype(float),
        np.bincount(d.rounds.mi, d.rounds.O, nm),
        np.bincount(d.rounds.mi, c, nm),
        d.matches.seed.values,
        pd.factorize(d.matches.block)[0],
    )


def fit(t: Rated, wins: np.ndarray, w: np.ndarray | None = None) -> np.ndarray:
    """Round Elo (bt.round_elo) per config of `wins`, with each match counted `w` times (bootstrap weights)."""
    w = np.ones(len(t.i)) if w is None else w
    elo = bt.round_elo(((t.names[i], t.names[j], k * n, k * y) for i, j, n, y, k in zip(t.i, t.j, t.n, wins, w) if k), t.names)
    return np.array([elo[name] for name in t.names])


def intervals(t: Rated, wins: np.ndarray) -> np.ndarray:
    """2.5% and 97.5% quantiles over seed-block resamples, per config."""
    rng = np.random.default_rng(1)
    U = t.block.max() + 1
    draws = np.array([fit(t, wins, np.bincount(rng.integers(0, U, U), minlength=U)[t.block].astype(float)) for _ in range(DRAWS)])
    return np.percentile(draws, [2.5, 97.5], axis=0).T


def bias(t: Rated, splits: int = 20) -> dict:
    """The per-config mean correction per round: seed-clustered chi2 against zero, and its correlation with Elo fitted on the other seeds."""
    K = len(t.names)
    mu, se = np.zeros(K), np.zeros(K)
    for c in range(K):
        a, b = t.i == c, t.j == c
        v, n, s = np.concatenate([t.luck[a], -t.luck[b]]), np.concatenate([t.n[a], t.n[b]]), np.concatenate([t.seed[a], t.seed[b]])
        mu[c] = v.sum() / n.sum()
        se[c] = np.sqrt((pd.Series(v - mu[c] * n).groupby(s).sum() ** 2).sum()) / n.sum()
    chi2 = float(((mu / se) ** 2).sum())
    corr = []
    for s in range(splits):
        f = folds(t.seed, 200 + s, 2)
        for k in (0, 1):
            elo = fit(t, t.raw, (f != k).astype(float))
            w = f == k
            m = np.array([np.concatenate([t.luck[(t.i == c) & w], -t.luck[(t.j == c) & w]]).sum() / max(1.0, np.concatenate([t.n[(t.i == c) & w], t.n[(t.j == c) & w]]).sum()) for c in range(K)])
            corr.append(np.corrcoef(elo, m)[0, 1])
    return {"chi2": chi2, "k": K, "p": float(stats.chi2.sf(chi2, K)), "corr": float(np.mean(corr))}


def report(t: Rated) -> str:
    raw, adj = fit(t, t.raw), fit(t, t.raw + t.luck)
    ri, ai = intervals(t, t.raw), intervals(t, t.raw + t.luck)
    b = bias(t)
    counts = np.bincount(t.i, t.n, len(t.names)) + np.bincount(t.j, t.n, len(t.names))
    matches = np.bincount(t.i, minlength=len(t.names)) + np.bincount(t.j, minlength=len(t.names))
    order = np.argsort(-adj)
    rows = [[t.names[k], f"{matches[k]}", f"{counts[k]:.0f}", f"{raw[k]:+.0f} [{ri[k][0]:+.0f}, {ri[k][1]:+.0f}]", f"{adj[k]:+.0f} [{ai[k][0]:+.0f}, {ai[k][1]:+.0f}]"] for k in order]
    widths = (ri[:, 1] - ri[:, 0]) / 2, (ai[:, 1] - ai[:, 0]) / 2
    rank_raw, rank_adj = stats.rankdata(-raw), stats.rankdata(-adj)
    summary = (
        f"{len(t.i):,} matches, {int(t.n.sum()):,} rounds. The median 95% half-width falls from ±{np.median(widths[0]):.0f} to ±{np.median(widths[1]):.0f} Elo"
        f" (variance of a match's round share {np.var(t.raw / t.n):.3f} → {np.var((t.raw + t.luck) / t.n):.3f}). Spearman rank correlation with the raw"
        f" ratings {stats.spearmanr(raw, adj)[0]:.3f}, largest rank change {int(abs(rank_raw - rank_adj).max())}.\n\n"
        f"Bias test: the mean correction per round of each config, seed-clustered, gives chi2 {b['chi2']:.1f} on {b['k']} configs (p {b['p']:.2f})."
        f" Its correlation with Round Elo fitted on the other half of the seeds (20 random halvings) is {b['corr']:+.2f}."
    )
    return summary + "\n\n" + table(["config", "matches", "rounds", "Round Elo [95%]", "luck-adjusted [95%]"], rows)


def write(path: Path, d: Data, c: np.ndarray) -> None:
    luck = np.bincount(d.rounds.mi, c, len(d.matches))
    tmp = path.with_suffix(".tmp")
    tmp.unlink(missing_ok=True)
    out = sqlite3.connect(tmp)
    out.execute("CREATE TABLE luck (match_id TEXT, player TEXT, correction REAL, PRIMARY KEY (match_id, player))")
    out.executemany("INSERT INTO luck VALUES (?, ?, ?)", [row for m, a, b, x in zip(d.matches.match_id, d.matches.letter1, d.matches.letter2, luck) for row in ((m, a, float(x)), (m, b, -float(x)))])
    out.commit()
    out.close()
    tmp.replace(path)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--db", default=DB)
    parser.add_argument("--knowledge", default=str(DERIVED / "knowledge.sqlite"))
    parser.add_argument("--out", type=Path)
    parser.add_argument("--doc", type=Path)
    args = parser.parse_args()
    require_current(args.db)
    d = read(args.db, args.knowledge)
    c = corrections(d)
    if args.out:
        write(args.out, d, c)
    text = report(rated(d, c))
    if args.doc:
        splice_between_markers(args.doc, "luck", text)
    else:
        print(text)


if __name__ == "__main__":
    main()
