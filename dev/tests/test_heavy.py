"""The heavy slot: commands run niced, one of two machine-wide slots, waits when full."""

import fcntl
import os
import sys
import tempfile
import threading
import unittest

from buckshot_dev import cli


class HeavyTest(unittest.TestCase):
    def setUp(self):
        self.dir = self.enterContext(tempfile.TemporaryDirectory(prefix="buckshot-heavy-test-"))

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
        self.assertEqual(cli.heavy_cmd([sys.executable, "-c", code], self.dir), 0)
        self.assertEqual(out.read().strip(), str(expected))

    def test_waits_for_a_slot(self):
        hold1, hold2 = self.slot(cli.SLOT_NAMES[0]), self.slot(cli.SLOT_NAMES[1])
        fcntl.flock(hold1, fcntl.LOCK_EX)
        fcntl.flock(hold2, fcntl.LOCK_EX)
        result = {}

        def run():
            result["rc"] = cli.heavy_cmd(["true"], self.dir, poll=0.05)

        t = threading.Thread(target=run)
        t.start()
        t.join(0.5)
        self.assertTrue(t.is_alive(), "heavy ran although both slots were held")
        fcntl.flock(hold2, fcntl.LOCK_UN)
        t.join(10)
        self.assertEqual(result.get("rc"), 0)


if __name__ == "__main__":
    unittest.main()
