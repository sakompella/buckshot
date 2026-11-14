"""Rule constants the analyses share. Bend owns the rules (sim/bend-mp/domain.bend); test_rules.py checks these against it."""

ROUNDS = (1, 2, 3)
PRIZES = (70_000, 75_000, 80_000)

# The two-seat deck, table.deck(TwoSeats): (live, blank) per load.
DECK = ((1, 2), (2, 1), (2, 2), (3, 2), (1, 1), (2, 3), (3, 3), (3, 1), (4, 2))
# The items dealt at two seats (item.order() without the remote) with their caps per seat and on the table: config.default_items().
ITEMS = ("Saw", "Glass", "Jammer", "Cigarettes", "Beer", "Phone", "Inverter", "Adrenaline")
PER_SEAT = (2, 2, 1, 1, 8, 8, 4, 4)
ON_TABLE = (32, 32, 1, 32, 32, 32, 32, 32)
# The damage of a shot with the saw, damage.amount(Double).
SAW_DAMAGE = 2

# Search scores are in millionths of a round win; a point is a hundredth of one.
WIN = 1_000_000
POINT = WIN // 100
