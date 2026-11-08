"""Tool resolution: env override wins, then PATH; a clear error names the env var."""

import os
import unittest
from unittest import mock

from buckshot_dev.tools import ToolMissing, resolve


class ResolveTest(unittest.TestCase):
    def test_env_var_wins(self):
        with mock.patch.dict(os.environ, {"BEND": "/opt/bend/bin/bend"}, clear=True):
            self.assertEqual(resolve("BEND", "bend"), "/opt/bend/bin/bend")

    def test_path_fallback(self):
        with mock.patch.dict(os.environ, {"BEND": ""}):
            found = resolve("BEND", "sh")
        self.assertTrue(found.endswith("/sh"))
        self.assertTrue(os.access(found, os.X_OK))

    def test_missing_names_the_env_var(self):
        with mock.patch.dict(os.environ, {"BEND": ""}, clear=True):
            with self.assertRaisesRegex(ToolMissing, "BEND"):
                resolve("BEND", "definitely-not-a-tool-42")


if __name__ == "__main__":
    unittest.main()
