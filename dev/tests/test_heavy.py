"""The heavy queue: commands run niced, holding a slot and a share of the memory budget; wait when either is full."""

import fcntl
import json
import os
import subprocess
import sys
import tempfile
import threading
import unittest
import unittest.mock

from buckshot_dev import cli


class HeavyTest(unittest.TestCase):
    def setUp(self):
        self.dir = self.enterContext(
            tempfile.TemporaryDirectory(prefix="buckshot-heavy-test-")
        )
        # No systemd scope in tests (the sandbox has no user manager).
        self.enterContext(unittest.mock.patch("shutil.which", return_value=None))

    def slot(self, name):
        fd = os.open(os.path.join(self.dir, name), os.O_CREAT | os.O_RDWR, 0o666)
        self.addCleanup(os.close, fd)
        return fd

    def test_runs_niced(self):
        out = tempfile.NamedTemporaryFile("r", suffix=".txt", delete=False)
        self.addCleanup(out.close)
        self.addCleanup(os.unlink, out.name)
        # nice -n 10 is relative to this process's niceness and stops at 19, so a niced caller (heavy) still passes.
        expected = min(os.nice(0) + 10, 19)
        code = f"import os; open({out.name!r}, 'w').write(str(os.nice(0)))"
        self.assertEqual(
            cli.heavy_cmd([sys.executable, "-c", code], slot_dir=self.dir), 0
        )
        self.assertEqual(out.read().strip(), str(expected))

    def test_waits_for_a_slot(self):
        with unittest.mock.patch.dict(os.environ, {"BUCKSHOT_HEAVY_SLOTS": "2"}):
            hold1, hold2 = (
                self.slot(cli.slot_names(2)[0]),
                self.slot(cli.slot_names(2)[1]),
            )
            fcntl.flock(hold1, fcntl.LOCK_EX)
            fcntl.flock(hold2, fcntl.LOCK_EX)
            result = {}

            def run():
                result["rc"] = cli.heavy_cmd(["true"], slot_dir=self.dir, poll=0.05)

            t = threading.Thread(target=run)
            t.start()
            t.join(0.5)
            self.assertTrue(t.is_alive(), "heavy ran although both slots were held")
            fcntl.flock(hold2, fcntl.LOCK_UN)
            t.join(10)
            self.assertEqual(result.get("rc"), 0)

    def test_bad_slot_count_refused(self):
        with (
            unittest.mock.patch.dict(os.environ, {"BUCKSHOT_HEAVY_SLOTS": "two"}),
            self.assertRaises(SystemExit),
        ):
            cli.heavy_cmd(["true"], slot_dir=self.dir)

    def test_admission_arithmetic(self):
        gib = 1 << 30
        self.assertEqual(cli.parse_size("6G"), 6 * gib)
        self.assertTrue(
            cli.admits(
                live_mem=6 * gib, size=4 * gib, budget=10 * gib, available=8 * gib
            )
        )
        self.assertFalse(
            cli.admits(
                live_mem=7 * gib, size=4 * gib, budget=10 * gib, available=8 * gib
            ),
            "over budget",
        )
        self.assertFalse(
            cli.admits(live_mem=0, size=4 * gib, budget=10 * gib, available=3 * gib),
            "host is short",
        )

    def test_waits_for_memory_and_dead_pid_frees_its_share(self):
        child = subprocess.Popen(["true"])
        child.wait()  # its pid is dead now
        with open(cli.job_path(self.dir, child.pid), "w") as f:
            json.dump({"pid": child.pid, "mem": 8 << 30, "cmd": ["x"], "start": 0}, f)
        self.assertEqual(cli.live_jobs(self.dir), [])
        self.assertFalse(os.path.exists(cli.job_path(self.dir, child.pid)))
        # A live job holding the whole budget blocks admission; this process stands in for it.
        with open(cli.job_path(self.dir, os.getpid()), "w") as f:
            json.dump({"pid": os.getpid(), "mem": 1 << 30, "cmd": ["x"], "start": 0}, f)
        with unittest.mock.patch.dict(os.environ, {"BUCKSHOT_HEAVY_MEM_BUDGET": "1G"}):
            self.assertIsNone(
                cli.admit(
                    self.dir, cli.slot_names(1), 1 << 20, cli.mem_budget(), ["true"]
                )
            )


if __name__ == "__main__":
    unittest.main()
