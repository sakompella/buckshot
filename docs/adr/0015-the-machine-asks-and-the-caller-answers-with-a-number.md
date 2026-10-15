# The machine asks and the caller answers with a number

The machine never rolls dice and never waits. At each request point it returns a draw with a range, a choice among the legal moves of the seats that may act, Finished, or Stuck. The caller answers with one number, and every number is valid: a draw clamps into its range, and a choice indexes the flat list of offered moves. So any list of numbers is a game, and the laws can quantify over all of them. A driver owns what the models never see: the game's randomness, each controller's own randomness, and the order in which seats that may act at once do act.

A draw is in the model only if its value can affect play. Draws that only decorate, such as sound picks and shake, are gone, and so is a draw whose value is never read. The model matches the real game's distributions, not its random generator, so no seed reproduces a real game. Claiming seed parity after dropping those calls would be false.
