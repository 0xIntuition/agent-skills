# Releasing Intuition Skills

This repo has published users. Treat release metadata as part of the product,
not as decoration.

## Policy

1. `main` is the integration branch, not the stable release channel.
2. Published releases are explicit Git tags plus GitHub Releases.
3. `metadata.version` in each skill's `SKILL.md` is the published version for
   that skill.
4. Normal feature or fix PRs do **not** bump `metadata.version`.
5. Version bumps happen only in a dedicated release PR that also updates
   `CHANGELOG.md`.

For production use, consumers should pin to a release tag or commit SHA rather
than tracking `main`.

## What Counts As a Release

Create a release whenever merged changes alter any of the following:

- Agent-visible transaction generation
- Required preflight or post-broadcast checks
- Safety gates, slippage handling, or approval behavior
- Supported operations, references, or output expectations
- Human install or operating guidance that downstream teams rely on

Pure typo fixes or internal cleanup do not require an immediate release unless
they correct a published statement that users could reasonably follow.

## Versioning Rules

Version by **agent-visible behavior**, not by whether a diff is "just docs."
These skills are executable instructions for agents. A doc change that changes
what an agent emits or verifies is a real behavior change.

### Patch (`x.y.Z`)

Use a patch release for changes that do **not** alter the skill's machine- or
operator-visible contract:

- Typos, copy edits, broken links
- Clarifications that do not change tx construction or verification behavior
- Test-only changes
- Changelog or release-note corrections

### Minor (`x.Y.z`)

Use a minor release for backward-compatible, externally visible skill changes:

- New operation docs or reference material
- New safety checks or verification steps
- Correctness fixes that change recommended calldata, `msg.value`, slippage
  bounds, or post-write handling while preserving the same top-level output
  shapes
- Additive workflow guidance that makes agents do more reads, previews, or
  validation without changing the response schema

This is the default bucket for most protocol-correctness fixes in `SKILL.md`
and `reference/` / `operations/` docs.

### Major (`X.y.z`)

Use a major release for changes likely to break downstream automation:

- Output JSON shape changes
- Renamed or removed operations that callers depend on
- Changed install surface or marketplace structure
- New required external dependencies or environment prerequisites
- Behavioral changes that invalidate previously supported automation flows

Urgency does not change version semantics. A critical correctness fix can be
released quickly, but it should still use the correct version bump.

## Release PR Checklist

Every release should ship in a dedicated PR that does all of the following:

1. Decide the next version from the highest-impact merged change.
2. Update `metadata.version` in the released skill's `SKILL.md`.
3. Move `CHANGELOG.md` entries from `Unreleased` into a dated version section.
4. Summarize operator-facing impact:
   - what changed
   - whether generated txs or follow-up verification behavior changed
   - whether consumers need to update pinned versions
5. Run validation for the changed surface:
   - deterministic calldata checks
   - edge-case checks when relevant
   - prompt suites for the touched workflows
6. Merge the release PR.
7. Tag the merge commit.
8. Publish a GitHub Release from that tag.

## Tag Format

Use skill-scoped tags so the repo can grow beyond one skill without ambiguity:

- `intuition-v0.2.1`

If additional first-party skills are added later, use the same pattern:

- `<skill-name>-vX.Y.Z`

## Release Notes Format

Every GitHub Release should include:

- **Version**
- **Impact**: patch / minor / major
- **Why it matters**
- **Behavior changes**: tx generation, previews, verification, approvals
- **Operator action**: whether pinned consumers should upgrade now

If a release changes generated transaction fields or required verification
steps, say that explicitly in the first paragraph.
