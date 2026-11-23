"""The generated doc sections: python3 -m unittest discover -s tools/arena/analysis"""

import tempfile
import unittest
from pathlib import Path

from docs import splice_between_markers


class SpliceBetweenMarkers(unittest.TestCase):
    def tmp(self) -> Path:
        return Path(self.enterContext(tempfile.TemporaryDirectory()))

    def test_replaces_only_the_marked_block_and_is_idempotent(self):
        doc = self.tmp() / "doc.md"
        doc.write_text(
            "intro\n<!-- beliefs:start -->\nold\n<!-- beliefs:end -->\noutro\n"
        )
        splice_between_markers(doc, "beliefs", "new\n")
        once = doc.read_text()
        self.assertEqual(
            once, "intro\n<!-- beliefs:start -->\nnew\n<!-- beliefs:end -->\noutro\n"
        )
        splice_between_markers(doc, "beliefs", "new")
        self.assertEqual(doc.read_text(), once)

    def test_rejects_a_file_without_markers(self):
        doc = self.tmp() / "doc.md"
        doc.write_text("no markers")
        with self.assertRaises(ValueError):
            splice_between_markers(doc, "beliefs", "x")


if __name__ == "__main__":
    unittest.main()
