# Intuition Prompt Templates

Reusable prompt templates for Layer B testing.

Scope:
- Prompts only (no captured outputs)
- Intended for repeatable local runs with `claude -p`
- Canonical results and analysis stay in Obsidian notes

## Files

- `tests/prompts/b1-validation-prompts.md` -- offline validation-oriented agent consumption prompts
- `tests/prompts/b1-graphql-prompts.md` -- GraphQL discovery prompts (search, traverse, compose, safety)
- `tests/prompts/b1-pin-prompts.md` -- IPFS pinning & structured atom prompts (Pin-1..4 positive, Pin-N1..N4 negative)
- `tests/prompts/b2-onchain-prompts.md` -- unsigned-transaction templates plus explicit post-broadcast checks
- `tests/prompts/b2-onchain-integration-prompts.md` -- full integration prompts (simulate, broadcast, verify)

## Modes

1. Template mode
- Use when validating skill behavior in any environment.
- Agent returns unsigned transaction JSON only.
- Broadcast and checks run in the harness outside the prompt.

2. Full integration mode
- Use when validating autonomous end-to-end behavior with a funded testnet signer.
- Agent performs full lifecycle: build, simulate, broadcast, verify.
- Prompt assumes environment variables are pre-provisioned by the local harness.

## Suggested Runner

```bash
claude -p "<prompt>" \
  --allowedTools "Bash,Read,Glob,Grep" \
  --permission-mode bypassPermissions \
  --no-session-persistence
```

## Notes

- Prefer testnet (`chainId=13579`) for repeatable integration testing.
- Enforce strict JSON output in prompts for deterministic parsing.
- Never place private keys directly in prompts.
- In full integration mode, signer material remains in `.env` / harness environment and is only referenced by variable name.
