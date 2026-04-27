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

## 0.4.0 - 2026-04-27

### Added

- `reference/nested-triples.md` documenting nested-triple discovery, classification, construction, and rendering patterns, including the polymorphic `*_term` GraphQL fragment and the `getVaultType` / `isTermCreated` preflight contract.
- Type-aware term classification reads in `reference/reading-state.md` and `reference/graphql-queries.md` so agents can distinguish atoms, positive triples, and counter-triples from any term position.
- `tests/prompts/b1-nested-triple-prompts.md` covering nested-triple discovery, `getVaultType` classification, construction preflight, counter-triple safety, polymorphic rendering, and unknown-term refusal.
- `scripts/nested-triple-smoke.sh` verifying the three-valued GraphQL discriminator, on-chain classifier ordinals, polymorphic `*_term` shape, nested-fixture rendering, and the existence-guard vs type-family-boolean asymmetry on unknown ids.

### Changed

- `operations/create-triples.md` broadens triple positions to accept any term type (atom or triple) so positive triples can be reused as subject, predicate, or object directly without re-creation.
- `reference/graphql-queries.md` previews now use the polymorphic `subject_term` / `predicate_term` / `object_term` relationships in place of the legacy atom-only `subject` / `predicate` / `object` relations, so triple-valued positions render safely.
- `SKILL.md` error table now distinguishes `MultiVault_TermDoesNotExist` (creation-side revert) from `MultiVaultCore_TermDoesNotExist` (classifier read against an unknown id) and surfaces both selectors.
- `reference/autonomous-policy.md` preflight step 5 now requires `getVaultType(termId) == 1` for positive triple positions and explicitly warns against using `isTriple` alone, which is coarse and returns true for counter-triples.
- `reference/workflows.md`, `reference/simulation.md`, and skill routing docs now use term-aware language for triple components throughout.

### Fixed

- `scripts/pass2-edge-case-tests.sh` switches revert assertions from name-match to selector-match (`0xb4856ebc` for `MultiVault_AtomExists`, `0x4762af7d` for `MultiVault_TermDoesNotExist`) so the suite remains stable across cast version drift; also normalizes newer cast uint output, defaults `SENDER` to the MultiVault address, and silences the foundry nightly warning.

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
