# Testing Strategy

This repo uses a layered test strategy so skills stay portable (no SDK required) while still validating autonomous behavior.

## Layers

### Layer A: Deterministic Calldata Encoding (Offline)

Goal:
- Prove each write operation encodes correct selector, argument types, and argument ordering.

Artifact:
- `scripts/pass2-calldata-verification.sh`

Run:
```bash
./scripts/pass2-calldata-verification.sh
```

Expected:
- `PASS=25 FAIL=0`

### Layer A.5: RPC Edge Cases (Read-Only, No Signing)

Goal:
- Probe state-dependent edge cases without broadcasting transactions.

Artifact:
- `scripts/pass2-edge-case-tests.sh`

Run:
```bash
./scripts/pass2-edge-case-tests.sh
```

### Layer B1: Autonomous Consumption (No Broadcast)

Goal:
- Validate that an autonomous agent can read the skill and produce strict JSON outputs and correct unsigned txs.

Artifacts:
- `tests/prompts/b1-validation-prompts.md`
- `tests/prompts/b1-graphql-prompts.md`

### Layer B2: On-Chain Integration (Broadcast)

Goal:
- Validate full build -> simulate -> broadcast -> verify flows with a funded testnet signer.

Artifacts:
- `tests/prompts/b2-onchain-prompts.md`
- `tests/prompts/b2-onchain-integration-prompts.md`

## What Lives In Repo vs Obsidian

In repo:
- Reusable scripts
- Reusable prompt templates
- Pass/fail criteria and runner instructions

In Obsidian:
- Full raw input/output transcripts
- Timestamped run logs
- Analysis and cross-run comparisons
- Wallet/context-sensitive execution traces

## Local Working Artifacts

Use a gitignored local folder for temporary run output that is useful during review or a merge train but should not become part of the repo history.

Recommended location:
- `.artifacts/test-runs/<YYYY-MM-DD-short-name>/`

Store here:
- temporary run summaries
- stdout/stderr captures from scripts
- one-off prompt variants
- local notes used to drive a review or merge sequence

Do not commit `.artifacts/` or `.local/`. If a local artifact becomes reusable, promote it into a tracked prompt, script, or doc.

Use `tests/templates/local-run-summary-template.md` as the starting point for run summaries.

## Readiness Guidance

Suitable for early external use when:
- Layer A is green
- Core B1 prompts pass (including injection resistance)
- GraphQL guardrails pass (`endpoint pinning`, `revalidation bridge`)
- At least create/deposit B2 integration flows pass on testnet

Recommended before broad unattended rollout:
- Complete and maintain B2 redeem/triple integration coverage
- Keep ambiguity handling (`term_id` over label) validated in B1-GQL.8
- Re-run Layer A on every skill operation change

## Runner Example

```bash
claude -p "<prompt>" \
  --allowedTools "Bash,Read,Glob,Grep" \
  --permission-mode bypassPermissions \
  --no-session-persistence
```
