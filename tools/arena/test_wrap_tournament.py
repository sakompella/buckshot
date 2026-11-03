import json
import sqlite3
import tempfile
import unittest
from pathlib import Path

import wrap_tournament as w


_DIRS: list[tempfile.TemporaryDirectory] = []


def tmp() -> Path:
    _DIRS.append(tempfile.TemporaryDirectory())
    return Path(_DIRS[-1].name)


def make_regret(path: Path, rows: list[tuple], with_reload: bool = True) -> None:
    db = sqlite3.connect(path)
    extra = ", reload TEXT NOT NULL DEFAULT 'static', samples INTEGER NOT NULL DEFAULT 0" if with_reload else ""
    cols = ", ".join(f"{c} INTEGER" if c in "ordinal max_depth budget best_score chosen_score regret exact depth limited nodes".split() else f"{c} TEXT" for c in w.REGRET_COLUMNS.split(", "))
    pk = "match_id, ordinal, evaluator, max_depth, budget" + (", reload, samples" if with_reload else "")
    db.execute(f"CREATE TABLE regret ({cols}, ms REAL{extra}, PRIMARY KEY ({pk}))".replace("ms INTEGER", "ms REAL").replace("ms TEXT", "ms REAL").replace(", ms REAL, ms REAL", ", ms REAL"))
    for match, ordinal in rows:
        db.execute("INSERT INTO regret (match_id, ordinal, evaluator, max_depth, budget, status) VALUES (?, ?, 'ev', 6, 20000, 'searched')", (match, ordinal))
    db.commit()
    db.close()


class Swap(unittest.TestCase):
    def test_keeps_the_old_file_and_its_wal_as_a_set(self):
        d = tmp()
        for suffix, text in (("", "old"), ("-wal", "oldwal"), ("-shm", "oldshm")):
            (d / f"live.sqlite{suffix}").write_text(text)
        (d / "new.sqlite").write_text("new")
        self.assertTrue(w.swap(d / "live.sqlite", d / "new.sqlite", "t8-x"))
        self.assertEqual((d / "live.sqlite").read_text(), "new")
        self.assertEqual([(d / f"live.sqlite.pre-t8-x{s}").read_text() for s in ("", "-wal", "-shm")], ["old", "oldwal", "oldshm"])
        self.assertFalse((d / "live.sqlite-wal").exists())

    def test_a_second_call_is_a_no_op(self):
        d = tmp()
        (d / "live.sqlite").write_text("old")
        (d / "new.sqlite").write_text("new")
        w.swap(d / "live.sqlite", d / "new.sqlite", "x")
        self.assertFalse(w.swap(d / "live.sqlite", d / "new.sqlite", "x"))
        self.assertEqual((d / "live.sqlite.pre-x").read_text(), "old")

    def test_refuses_to_overwrite_a_pre_copy(self):
        d = tmp()
        for name in ("live.sqlite", "new.sqlite", "live.sqlite.pre-x"):
            (d / name).write_text(name)
        with self.assertRaises(w.Stop):
            w.swap(d / "live.sqlite", d / "new.sqlite", "x")
        self.assertEqual((d / "live.sqlite").read_text(), "live.sqlite")


class Steps(unittest.TestCase):
    def test_a_rerun_skips_finished_steps_and_resumes_at_the_failed_one(self):
        d = tmp()
        calls = []
        broken = [True]

        def step(name, fails=False):
            def run():
                calls.append(name)
                if fails and broken[0]:
                    raise w.Stop("boom")

            return name, run

        steps = [step("a"), step("b", fails=True), step("c")]
        with self.assertRaises(w.Stop):
            w.run_steps(steps, d / "state.json", lambda _: None)
        broken[0] = False
        w.run_steps(steps, d / "state.json", lambda _: None)
        w.run_steps(steps, d / "state.json", lambda _: None)
        self.assertEqual(calls, ["a", "b", "b", "c"])


class Cohort(unittest.TestCase):
    def dirs(self, *cohorts):
        d = tmp()
        out = []
        for i, c in enumerate(cohorts):
            (d / f"p{i}").mkdir()
            config = {"name": f"p{i}"} | ({} if c is None else {"cohort": c})
            (d / f"p{i}" / "tournament.json").write_text(json.dumps({"format": 1, "config": config}))
            out.append(d / f"p{i}")
        return d, out

    def test_stamps_only_files_without_a_cohort_and_is_idempotent(self):
        root, dirs = self.dirs(None, "tournament 8")
        self.assertEqual(w.stamp_cohort(dirs, "tournament 8"), 1)
        self.assertEqual(w.stamp_cohort(dirs, "tournament 8"), 0)
        self.assertEqual(json.loads((dirs[0] / "tournament.json").read_text())["config"]["cohort"], "tournament 8")
        self.assertEqual(w.phase_dirs([root]), dirs)

    def test_a_different_cohort_stops(self):
        _, dirs = self.dirs("tournament 7")
        with self.assertRaises(w.Stop):
            w.stamp_cohort(dirs, "tournament 8")


class Regret(unittest.TestCase):
    def test_new_matches_are_completed_validated_ones_without_regret_rows(self):
        d = tmp()
        snap = sqlite3.connect(d / "snap.sqlite")
        snap.execute("CREATE TABLE matches (id TEXT, name TEXT, status TEXT, replay_status TEXT)")
        snap.executemany("INSERT INTO matches VALUES (?, ?, ?, ?)", [("1", "old", "completed", "validated"), ("2", "new", "completed", "validated"), ("3", "partial", "partial", "validated"), ("4", "unvalidated", "completed", "failed")])
        snap.commit()
        make_regret(d / "regret.sqlite", [("1", 1)])
        self.assertEqual(w.new_match_names(d / "snap.sqlite", d / "regret.sqlite"), ["new"])

    def test_staging_adds_the_new_rows_with_static_reload_and_no_samples(self):
        d = tmp()
        make_regret(d / "live.sqlite", [("1", 1), ("1", 2)])
        make_regret(d / "new.sqlite", [("2", 1)], with_reload=False)
        note = w.stage_regret(d / "live.sqlite", d / "new.sqlite", d / "staged.sqlite")
        self.assertIn("2 + 1 = 3", note)
        rows = sqlite3.connect(d / "staged.sqlite").execute("SELECT match_id, reload, samples FROM regret ORDER BY match_id, ordinal").fetchall()
        self.assertEqual(rows, [("1", "static", 0), ("1", "static", 0), ("2", "static", 0)])

    def test_staging_stops_on_a_second_evaluator(self):
        d = tmp()
        make_regret(d / "live.sqlite", [("1", 1)])
        make_regret(d / "new.sqlite", [("2", 1)], with_reload=False)
        db = sqlite3.connect(d / "new.sqlite")
        db.execute("UPDATE regret SET evaluator = 'other'")
        db.commit()
        db.close()
        with self.assertRaises(w.Stop):
            w.stage_regret(d / "live.sqlite", d / "new.sqlite", d / "staged.sqlite")


class Emails(unittest.TestCase):
    def test_finds_emails_in_any_column_and_ignores_other_at_signs(self):
        d = tmp()
        db = sqlite3.connect(d / "db.sqlite")
        db.execute("CREATE TABLE t (a TEXT, b BLOB)")
        db.executemany("INSERT INTO t VALUES (?, ?)", [("[redacted] @scope/pkg a@b", None), ("x", b"call me someone@example.com")])
        db.commit()
        db.close()
        self.assertEqual(w.email_hits(d / "db.sqlite"), 1)


if __name__ == "__main__":
    unittest.main()
