"""Rule constants the analyses share. Bend owns the rules (sim/bend-mp/domain.bend); test_rules.py checks these against it."""

ROUNDS = (1, 2, 3)
PRIZES = (70_000, 75_000, 80_000)

# Search scores are in millionths of a round win; a point is a hundredth of one.
WIN = 1_000_000
POINT = WIN // 100
