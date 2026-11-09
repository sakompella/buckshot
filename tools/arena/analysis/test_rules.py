"""Checks rules.py against Bend: python3 -m unittest discover -s tools/arena/analysis (needs bend and node, as in nix develop)"""

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

import rules

DOMAIN = Path(__file__).resolve().parents[3] / "sim/bend-mp/domain.bend"

READ = """const D = (await import(process.argv[1])).default;
const rounds = D["plan.length"](D["config.default"]({ $: "TwoSeats" }).plan);
console.log(JSON.stringify({ rounds, prizes: Array.from({ length: rounds }, (_, round) => D.prize(round)) }));"""


class Rules(unittest.TestCase):
    def test_rounds_and_prizes_are_bends(self):
        with tempfile.TemporaryDirectory() as directory:
            module = Path(directory) / "domain.mjs"
            subprocess.run([os.environ.get("BEND", "bend"), str(DOMAIN), "-o", str(module)], check=True, capture_output=True)
            bend = json.loads(subprocess.run(["node", "--input-type=module", "-e", READ, module.as_uri()], check=True, capture_output=True, text=True).stdout)
        self.assertEqual(bend, {"rounds": len(rules.ROUNDS), "prizes": list(rules.PRIZES)})


if __name__ == "__main__":
    unittest.main()
