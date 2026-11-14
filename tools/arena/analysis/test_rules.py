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
const list = (xs) => (xs.$ === "Con" ? [xs.head, ...list(xs.tail)] : []);
const rounds = D["plan.length"](D["config.default"]({ $: "TwoSeats" }).plan);
const { $, ...caps } = D["config.default_items"]();
console.log(JSON.stringify({
  rounds,
  prizes: Array.from({ length: rounds }, (_, round) => D.prize(round)),
  deck: list(D["table.deck"]({ $: "TwoSeats" })).map(({ live, blank }) => [live, blank]),
  order: list(D["item.order"]()).map((item) => item.$),
  caps: Object.fromEntries(Object.entries(caps).map(([item, { per_player, on_table }]) => [item, [per_player, on_table]])),
  sawDamage: D["damage.amount"]({ $: "Double" }),
}));"""


class Rules(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with tempfile.TemporaryDirectory() as directory:
            module = Path(directory) / "domain.mjs"
            subprocess.run([os.environ.get("BEND", "bend"), str(DOMAIN), "-o", str(module)], check=True, capture_output=True)
            cls.bend = json.loads(subprocess.run(["node", "--input-type=module", "-e", READ, module.as_uri()], check=True, capture_output=True, text=True).stdout)

    def test_rounds_and_prizes_are_bends(self):
        self.assertEqual((self.bend["rounds"], self.bend["prizes"]), (len(rules.ROUNDS), list(rules.PRIZES)))

    def test_the_two_seat_deck_is_bends(self):
        self.assertEqual(self.bend["deck"], [list(load) for load in rules.DECK])

    def test_the_dealt_items_and_their_caps_are_bends(self):
        # The remote is last in Bend's order and is not dealt at two seats.
        self.assertEqual(self.bend["order"][:-1], list(rules.ITEMS))
        caps = [self.bend["caps"][item.lower()] for item in rules.ITEMS]
        self.assertEqual(caps, [list(pair) for pair in zip(rules.PER_SEAT, rules.ON_TABLE)])

    def test_a_sawed_shot_does_bends_damage(self):
        self.assertEqual(self.bend["sawDamage"], rules.SAW_DAMAGE)


if __name__ == "__main__":
    unittest.main()
