"""Story-mode dealer vs Double-or-Nothing dealer under 2-player multiplayer rules.

Both policies are ports of DealerChoice, CoinFlip and FigureOutShell from the
game's dealer AI (v2.2.0.6). Double or Nothing is the story policy plus
three upgrades, which can be removed one at a time:

- count_flip: when the shell is unknown, shoot the opponent if lives outnumber
  blanks and yourself if blanks do, instead of a fair coin.
- deduce: know the chamber when the remaining unknown shells are all one kind.
- beer_reset: forget the known chamber after beer ejects it.

The rules are the 2-player multiplayer defaults: 3 rounds, health 3 to 4, the
9-load shell deck, and 2 to 4 items per reload. The jammer follows the dealer's
handcuff rule, since neither policy knows the jammer.

Usage: python3 dealer_vs_dealer.py [matches per matchup, default 100000]
"""

import random
import sys
from dataclasses import dataclass, field

LOADS_2P = [(1, 2), (2, 1), (2, 2), (3, 2), (1, 1), (2, 3), (3, 3), (3, 1), (4, 2)]
PER_PLAYER_CAP = {
    "handsaw": 2,
    "magnifying glass": 2,
    "jammer": 1,
    "cigarettes": 1,
    "beer": 8,
    "burner phone": 8,
    "adrenaline": 4,
    "inverter": 4,
}
GLOBAL_CAP = {"jammer": 1}
INVENTORY_SLOTS = 8

DON = frozenset({"count_flip", "deduce", "beer_reset"})
STORY = frozenset()


@dataclass
class Player:
    upgrades: frozenset
    health: int = 0
    items: list = field(default_factory=list)
    jammed: bool = False
    jam_checked: bool = False
    phone_memory: list = field(default_factory=list)


class Game:
    def __init__(self, rng, upgrades_a, upgrades_b):
        self.rng = rng
        self.p = [Player(upgrades_a), Player(upgrades_b)]
        self.deck = []

    def draw_load(self):
        if not self.deck:
            self.deck = LOADS_2P.copy()
        live, blank = self.deck.pop(self.rng.randrange(len(self.deck)))
        seq = ["live"] * live + ["blank"] * blank
        self.rng.shuffle(seq)
        self.seq = seq
        for pl in self.p:
            pl.phone_memory = [False] * len(seq)

    def eject(self):
        self.seq.pop(0)
        for pl in self.p:
            pl.phone_memory.pop(0)

    def grab_items(self):
        n = self.rng.randint(2, 4)
        for _ in range(n):
            for i in self.rng.sample([0, 1], 2):
                pl = self.p[i]
                if pl.health == 0 or len(pl.items) >= INVENTORY_SLOTS:
                    continue
                on_table = [x for q in self.p for x in q.items]
                pool = [
                    k
                    for k, c in PER_PLAYER_CAP.items()
                    if pl.items.count(k) < c
                    and on_table.count(k) < GLOBAL_CAP.get(k, 99)
                ]
                if pool:
                    pl.items.append(self.rng.choice(pool))

    def coin_flip(self, me):
        if "count_flip" not in me.upgrades:
            return self.rng.randint(0, 1)
        lives, blanks = self.seq.count("live"), self.seq.count("blank")
        if lives == blanks:
            return self.rng.randint(0, 1)
        return 1 if lives > blanks else 0

    def figure_out_shell(self, me):
        if me.phone_memory[0]:
            return True
        lives, blanks = self.seq.count("live"), self.seq.count("blank")
        if lives == 0 or blanks == 0:
            return True
        for known, shell in zip(me.phone_memory, self.seq):
            if known:
                if shell == "live":
                    lives -= 1
                else:
                    blanks -= 1
        return lives == 0 or blanks == 0

    def dealer_turn(self, me, opp):
        """One shot. Returns (target, damage). Ported from the game's DealerChoice."""
        known, knows, target = "", False, ""
        sawed = False
        while True:
            if len(self.seq) == 1:
                known = self.seq[0]
                knows = True
                target = "opp" if known == "live" else "self"
            if "deduce" in me.upgrades and not knows and self.figure_out_shell(me):
                knows = True
                known = self.seq[0]
                target = "opp" if known == "live" else "self"
            candidates = [(x, "own") for x in me.items]
            if "adrenaline" in me.items:
                candidates += [(x, "opp") for x in opp.items if x != "adrenaline"]
            choice = None
            for item, side in candidates:
                if item == "magnifying glass" and not knows and len(self.seq) != 1:
                    known = self.seq[0]
                    knows = True
                    target = "opp" if known == "live" else "self"
                    choice = (item, side)
                    break
                if item == "cigarettes" and me.health < self.max_health:
                    choice = (item, side)
                    break
                if item == "beer" and known != "live" and len(self.seq) != 1:
                    choice = (item, side)
                    break
                if item == "jammer" and not opp.jammed and len(self.seq) != 1:
                    choice = (item, side)
                    break
                if item == "handsaw" and not sawed and known == "live":
                    choice = (item, side)
                    break
                if item == "burner phone" and len(self.seq) > 2:
                    choice = (item, side)
                    break
                if item == "inverter" and knows and known == "blank":
                    choice = (item, side)
                    break
            if choice is None:
                handsaw_from_opp = (
                    "handsaw" not in me.items
                    and "adrenaline" in me.items
                    and "handsaw" in opp.items
                )
                if (
                    ("handsaw" in me.items or handsaw_from_opp)
                    and not sawed
                    and known != "blank"
                ):
                    if self.coin_flip(me) == 0:
                        target = "self"
                    else:
                        if handsaw_from_opp:
                            me.items.remove("adrenaline")
                            opp.items.remove("handsaw")
                        else:
                            me.items.remove("handsaw")
                        sawed = True
                        target = "opp"
                break
            item, side = choice
            own_copy = item in me.items
            if side == "opp" and not own_copy:
                me.items.remove("adrenaline")
                opp.items.remove(item)
            else:
                me.items.remove(item)
            if item == "cigarettes":
                me.health = min(self.max_health, me.health + 1)
            elif item == "beer":
                self.eject()
                if "beer_reset" in me.upgrades:
                    knows, known = False, ""
                if not self.seq:
                    return None
            elif item == "jammer":
                opp.jammed = True
                opp.jam_checked = False
            elif item == "handsaw":
                sawed = True
            elif item == "burner phone":
                me.phone_memory[self.rng.randint(1, len(self.seq) - 1)] = True
            elif item == "inverter":
                self.seq[0] = "live"
                known = "live"
                knows = True
                target = "opp"
        if target == "":
            target = "self" if self.coin_flip(me) == 0 else "opp"
        return target, 2 if sawed else 1

    def play_round(self, first):
        self.max_health = self.rng.randint(3, 4)
        for pl in self.p:
            pl.health = self.max_health
            pl.items = []
            pl.jammed = False
        turn = first
        while True:
            self.draw_load()
            self.grab_items()
            while self.seq:
                me, opp = self.p[turn], self.p[1 - turn]
                if me.jammed:
                    if not me.jam_checked:
                        me.jam_checked = True
                        turn = 1 - turn
                        continue
                    me.jammed = False
                result = self.dealer_turn(me, opp)
                if result is None:
                    break
                target, damage = result
                shell = self.seq[0]
                self.eject()
                victim = me if target == "self" else opp
                if shell == "live":
                    victim.health = max(0, victim.health - damage)
                    if victim.health == 0:
                        return self.p.index(victim) ^ 1, self.p.index(victim)
                if not (target == "self" and shell == "blank"):
                    turn = 1 - turn


def run(upgrades_a, upgrades_b, matches, seed):
    rng = random.Random(seed)
    wins = [0, 0]
    rounds = [0, 0]
    for _ in range(matches):
        g = Game(rng, upgrades_a, upgrades_b)
        cash = [0, 0]
        first = rng.randint(0, 1)
        for prize in (70000, 75000, 80000):
            winner, loser = g.play_round(first)
            rounds[winner] += 1
            cash[winner] += prize
            first = loser
        wins[0 if cash[0] > cash[1] else 1] += 1
    return wins, rounds


if __name__ == "__main__":
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 100000
    matchups = [
        ("story vs story", STORY, STORY),
        ("DoN vs DoN", DON, DON),
        ("DoN vs story", DON, STORY),
        ("DoN minus count_flip vs story", DON - {"count_flip"}, STORY),
        ("DoN minus deduce vs story", DON - {"deduce"}, STORY),
        ("DoN minus beer_reset vs story", DON - {"beer_reset"}, STORY),
        ("count_flip only vs story", frozenset({"count_flip"}), STORY),
    ]
    for seed, (label, a, b) in enumerate(matchups):
        wins, rounds = run(a, b, n, seed)
        print(
            f"{label:32s} match A {wins[0] / n:6.2%}  round A {rounds[0] / sum(rounds):6.2%}"
        )
