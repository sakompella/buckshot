"""The heavy slot: commands run niced, one of two machine-wide slots, waits when full."""

import fcntl
import os
import sys
import tempfile
import threading
import unittest
import unittest.mock

from buckshot_dev import cli


class HeavyTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix="buckshot-heavy-test-")
        os.environ["BUCKSHOT_HEAVY_DIR"] = self.dir
        self.addCleanup(os.environ.pop, "BUCKSHOT_HEAVY_DIR", None)

    def slot(self, name):
        fd = os.open(os.path.join(self.dir, name), os.O_CREAT | os.O_RDWR, 0o666)
        self.addCleanup(os.close, fd)
        return fd

    def test_runs_niced(self):
        out = tempfile.NamedTemporaryFile("r", suffix=".txt", delete=False)
        self.addCleanup(out.close)
        self.addCleanup(os.unlink, out.name)
        # nice -n 10 is relative to this process's nicety.
        expected = os.nice(0) + 10
        code = f"import os; open({out.name!r}, 'w').write(str(os.nice(0)))"
        self.assertEqual(cli.heavy_cmd([sys.executable, "-c", code]), 0)
        self.assertEqual(out.read().strip(), str(expected))

    def test_default_slot_dir_ignores_tmpdir(self):
        os.environ.pop("BUCKSHOT_HEAVY_DIR")
        self.addCleanup(os.environ.__setitem__, "BUCKSHOT_HEAVY_DIR", self.dir)
        with unittest.mock.patch.dict(os.environ, {"TMPDIR": self.dir}), unittest.mock.patch.object(cli.os, "open", side_effect=RuntimeError) as opened, self.assertRaises(RuntimeError):
            cli.heavy_cmd(["true"])
        self.assertEqual(opened.call_args.args[0], os.path.join("/tmp", cli.SLOT_NAMES[0]))

    def test_waits_for_a_slot(self):
        hold1, hold2 = self.slot(cli.SLOT_NAMES[0]), self.slot(cli.SLOT_NAMES[1])
        fcntl.flock(hold1, fcntl.LOCK_EX)
        fcntl.flock(hold2, fcntl.LOCK_EX)
        result = {}

        def run():
            result["rc"] = cli.heavy_cmd(["true"])

        t = threading.Thread(target=run)
        t.start()
        t.join(0.5)
        self.assertTrue(t.is_alive(), "heavy ran although both slots were held")
        fcntl.flock(hold2, fcntl.LOCK_UN)
        t.join(10)
        self.assertEqual(result.get("rc"), 0)


if __name__ == "__main__":
    unittest.main()
