# One endpoint per agent: Anthropic Messages or OpenAI Responses

The arena's agents are A to D, and each agent's model is configured on its own, from `PLAYER_A_*` to `PLAYER_D_*`. An agent names either an Anthropic Messages endpoint or an OpenAI Responses endpoint, never both, and setting both is a startup error. Keeping agents separate lets any pair of models meet, including the same model on two endpoints. Requiring the model id to be in pi-ai's catalog gives every agent its real context window and thinking levels with no hand-written model table. The variables are parsed once, with keys kept Redacted, so no error or log shows a key.

## Consequences

An agent is a letter, not a seat. Each match seats the agents by rotation and logs the seating, and an agent plays as the player of its letter wherever it sits. A model behind CLIProxyAPI with an id that pi-ai does not know, such as `claude-haiku-5-5-long`, cannot be used until pi-ai lists it or the arena gains an explicit model definition.
