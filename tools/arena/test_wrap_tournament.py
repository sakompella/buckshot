import json
import os
import sqlite3
import tempfile
import unittest
import unittest.mock
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


class SpliceBetweenMarkers(unittest.TestCase):
    def test_replaces_only_the_marked_block_and_is_idempotent(self):
        doc = "intro\n<!-- beliefs:start -->\nold\n<!-- beliefs:end -->\noutro\n"
        once = w.splice_between_markers(doc, "beliefs", "new\n")
        self.assertEqual(once, "intro\n<!-- beliefs:start -->\nnew\n<!-- beliefs:end -->\noutro\n")
        self.assertEqual(w.splice_between_markers(once, "beliefs", "new\n"), once)

    def test_stops_without_markers(self):
        with self.assertRaises(w.Stop):
            w.splice_between_markers("no markers", "beliefs", "x")


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


def make_wrap(deploy: bool) -> w.Wrap:
    d = tmp()
    (d / "run").mkdir()
    (d / "analysis").mkdir()
    return w.Wrap([d / "run"], d, d / "analysis", d / "docs", "t9", None, None, d, d, None, "", 1, deploy)


class Environment(unittest.TestCase):
    def test_worktree_commands_do_not_inherit_this_checkouts_bend(self):
        with unittest.mock.patch.dict(os.environ, {"BEND": "/nix/store/x-bend-new/bin/bend"}):
            self.assertNotIn("BEND", make_wrap(False).env)


class Deploy(unittest.TestCase):
    PASSED = '$ bun scripts/deploy-online.ts\n{"versionId": "v-1", "url": "https://p.example", "problems": []}\n'
    FAILED = '{"versionId": "v-2", "url": "https://p.example", "problems": ["/arena: status 404"]}\n'

    def test_dotenv_reads_pairs_and_skips_comments(self):
        self.assertEqual(w.dotenv("# c\nA=1\n\nB = x=y \n"), {"A": "1", "B": "x=y"})

    def test_a_preview_gives_its_version_only_when_it_passed(self):
        self.assertEqual(w.preview_version(self.PASSED), "v-1")
        for output in (self.FAILED, "no result here\n"):
            with self.assertRaises(w.Stop):
                w.preview_version(output)

    def test_the_deploy_step_is_off_unless_asked_for_and_follows_the_export(self):
        names = lambda wrap: [n for n, _ in wrap.steps()]
        self.assertNotIn("deploy", names(make_wrap(False)))
        on = names(make_wrap(True))
        self.assertEqual(on[on.index("export") + 1], "deploy")

    def run_deploy(self, preview_output: str) -> list[str]:
        wrap = make_wrap(True)
        env_file = tmp() / "deploy.env"
        env_file.write_text("CLOUDFLARE_API_TOKEN=t\n")
        ran = []

        def fake_run(step, cmd, cwd=w.REPO, stdout=None, env=None):
            ran.append(cmd[-1] if step == "deploy-promote" else step)
            self.assertEqual(env["CLOUDFLARE_API_TOKEN"], "t")
            if stdout:
                stdout.write_text(preview_output)

        wrap.run = fake_run
        with unittest.mock.patch.object(w, "CLOUDFLARE_ENV", env_file):
            wrap.deploy_()
        return ran

    def test_a_passing_preview_is_promoted_by_its_version_id(self):
        self.assertEqual(self.run_deploy(self.PASSED), ["deploy-preview", "v-1"])

    def test_a_failing_preview_is_never_promoted(self):
        ran = []
        with self.assertRaises(w.Stop):
            ran = self.run_deploy(self.FAILED)
        self.assertEqual(ran, [])

    def test_without_the_credentials_file_the_step_stops(self):
        with unittest.mock.patch.object(w, "CLOUDFLARE_ENV", tmp() / "missing.env"), self.assertRaises(w.Stop):
            make_wrap(True).deploy_()


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

    def test_rescored_rows_that_equal_the_live_ones_are_not_added_again(self):
        d = tmp()
        make_regret(d / "live.sqlite", [("1", 1), ("1", 2)])
        make_regret(d / "new.sqlite", [("1", 2), ("2", 1)], with_reload=False)
        note = w.stage_regret(d / "live.sqlite", d / "new.sqlite", d / "staged.sqlite")
        self.assertIn("2 + 1 = 3", note)

    def test_rescored_rows_that_differ_from_the_live_ones_stop(self):
        d = tmp()
        make_regret(d / "live.sqlite", [("1", 1)])
        make_regret(d / "new.sqlite", [("1", 1)], with_reload=False)
        db = sqlite3.connect(d / "new.sqlite")
        db.execute("UPDATE regret SET regret = 5")
        db.commit()
        db.close()
        with self.assertRaises(w.Stop):
            w.stage_regret(d / "live.sqlite", d / "new.sqlite", d / "staged.sqlite")

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
