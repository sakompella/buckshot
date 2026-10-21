# GPT reasoning is asked for as detailed summaries and stored as returned

Every GPT request asks for `reasoning.summary: "detailed"`. The arena stores exactly the summary text that comes back, with its encrypted reasoning item, and adds nothing to it. An audit found that the very short GPT summaries are what the provider sends:
- headings only for gpt-6-luna, gpt-5.6-terra and gpt-6-astra;
- rare prose, or nothing, for gpt-6.1-sol.

A census of saved calls, raw streaming probes and direct requests to the Codex backend without CPA all agree. Claude 5.5 models are asked for `display: "summarized"`, since their default `omitted` returns no text.

## Considered Options

- **`auto`:** the backend echoes it as `detailed` anyway.
- **`concise`:** for sol it sometimes gives headings where `detailed` gives none, but `detailed` sometimes gives sol's only prose.
- **Leaving the summary out:** it returns no text at all.
- **Asking the model to explain its move in the reply,** for example a `reason` field on `play_move`. This does give readable rationales, but it's a self-report that may change play. It belongs to a separately labelled entrant, never to the competitive baseline.

## Consequences

Saved reasoning text is a provider summary, not a chain of thought, and analysis must say so. Raw reasoning can't be recovered; the encrypted items only allow a match to resume. Thinking blocks should be joined with blank lines in the call log (`web/src/arena/runlog.ts`), which is still open.
