# Changelog

This changelog tracks user-visible changes to published Intuition skills.

The source of truth for the current published version of a skill is the
`metadata.version` field in that skill's `SKILL.md`. See `RELEASING.md` for the
release policy, semantic versioning rules, and publish checklist.

## Unreleased

Changes merged to `main` but not yet published belong here. Move them into a
versioned section as part of the release PR.

### Added

### Changed

### Fixed

### Removed

## 0.3.0 - 2026-04-22

### Added

- `reference/post-write-verification.md` for receipt checks, deterministic term-ID reconstruction, on-chain state deltas, and indexer-lag handling after writes.
- `operations/approve.md` as the first-class delegated approval flow for deposit and redeem operations.
- `reference/config-fields.md` covering the five protocol config reads and which fields are safety-critical for tx generation.
- `reference/network-config.md` as the canonical source for Intuition network metadata, session env values, and viem chain definitions.
- Shipped runtime-enforcement reference assets with the skill artifact: `reference/runtime-enforcement.md`, `reference/autonomous-policy.example.json`, and the `reference/schemas/*.json` output-contract files.

### Changed

- README now leads with explicit prerequisites, installation guidance, and two executable testnet quickstarts: Discovery -> Deposit and Pin -> Encode -> Create.
- GraphQL guidance now documents the discovery-to-write bridge, cache freshness, and when on-chain reads override indexer results.
- Operation docs now point back to `SKILL.md` Protocol Invariants for the full rule set while keeping only operation-specific reminders in place.
- Autonomous policy and runtime-enforcement docs now describe an executor-owned blocking validation pattern instead of implying bundled signer middleware.

### Fixed

- Batch deposit and batch redeem guidance now requires preview-derived per-item slippage bounds instead of unsafe zero-filled defaults.
- Atom and triple creation docs now follow canonical pinned-atom flows, use aligned preview/value handling, and preserve valid cost-only creation semantics.
- Post-write verification guidance now reflects actual receipt/event behavior and cost-only initialized vault semantics.
- Delegated deposit and redeem flows now clearly require approval to mine before the downstream write broadcasts, including batch operations.
- Config semantics now correctly scope `minDeposit`, `feeThreshold`, and fee-helper behavior.
- The shipped machine-readable contract is now one canonical shape end-to-end: `value` and `chainId` are base-10 strings, approval examples include `checks`, and pin-failure output remains explicit.

### Removed

- Duplicated README sections that restated canonical write semantics already defined in `SKILL.md`.
