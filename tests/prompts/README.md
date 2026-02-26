# Intuition Prompt Templates

Reusable prompt templates for Layer B testing.

Scope:
- Prompts only (no captured outputs)
- Intended for repeatable local runs with `claude -p`
- Canonical results and analysis stay in Obsidian notes

## Files

- `tests/prompts/b1-validation-prompts.md` -- offline validation-oriented agent consumption prompts
- `tests/prompts/b2-onchain-prompts.md` -- funded-wallet broadcast verification prompts

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
- Keep wallet keys/signing out of prompts; signer setup belongs to the test harness environment.
