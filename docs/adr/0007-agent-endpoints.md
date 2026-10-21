# Agent endpoints

The arena's agents are A to D, and each agent's model is configured on its own, from `PLAYER_A_*` to `PLAYER_D_*`. An agent names either an Anthropic Messages endpoint or an OpenAI Responses endpoint, never both, and setting both is a startup error. Keeping agents separate lets any pair of models meet, including the same model on two endpoints. Requiring the model id to be in pi-ai's catalog gives every agent its real context window and thinking levels with no hand-written model table. The variables are parsed once, with keys kept Redacted, so no error or log shows a key.

## Consequences

An agent is a letter, not a seat. Each match seats the agents by rotation and logs the seating, and an agent plays as the player of its letter wherever it sits. A model behind a proxy with an id that pi-ai does not know, such as CLIProxyAPI's `gpt-6-luna-fast`, names the catalog model it stands for in `PLAYER_X_CATALOG_MODEL` (here `gpt-6-luna`). The arena sends the proxy's id and takes the context window, thinking levels and prices from the catalog model, so an alias costs no hand-written model table either.
