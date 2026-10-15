# Raw usage in the logs, costs computed offline

`calls.jsonl` records, for every model reply, the provider, the exact model id and the usage as the provider reported it: input, output, cache read and write, and reasoning tokens. It never stores a dollar figure. `scripts/arena-cost.ts` prices one run or a whole tournament from `src/arena/prices.json`, which an operator edits. A cost stored at run time would be frozen at that day's prices, and through CLIProxyAPI it would be invented anyway, since the proxy does not report what a call cost.
