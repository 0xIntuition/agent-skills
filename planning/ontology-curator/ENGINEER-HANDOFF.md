# Engineer Handoff: `ontology-curator` skill

**Branch:** `billy/ontology-curation`
**Repo:** `0xIntuition/agent-skills`
**Status:** Ready to implement
**Prepared:** 2026-04-02

---

## What You're Building

A new Claude Code skill called `ontology-curator` — an AI-driven standards committee for the Intuition knowledge graph.

The problem: different developers and agents independently write atoms for the same concepts. "type", "kind", and "category" all become separate predicates with no connection. Once two communities fragment onto incompatible schemas, the damage is hard to undo — existing triples reference the old atoms, and neither community knows the other's exist.

This skill intercepts fragmentation at creation time. A user (human or agent) describes their domain in plain language. The skill queries the live Intuition graph, applies decision rules to each concept (REUSE, ALIAS, BROADER/NARROWER, TEXTOBJECT, or CREATE), normalizes predicate atoms to prevent format-variant fragmentation, detects cross-ontology conflicts, and emits a complete seed manifest with `createAtomsTx` + `createTriplesTx` calldata — ready to submit.

The deeper insight: vault deposits on atoms ARE governance. A predicate becomes canonical not by committee ratification but by the community putting TRUST behind it. This skill makes that signal legible and actionable.

**Ships as Markdown only.** No code, no build step. Same format as `skills/intuition/` and `skills/publish-learning/` in this repo.

---

## Repo Context

The existing `skills/intuition/` skill is the reference implementation. It has:
- IPFS pinning patterns (`reference/schemas.md`)
- ABI fragments for all contract calls (`SKILL.md`)
- GraphQL query patterns (`reference/graphql-queries.md`)
- Encoding patterns, simulation, RPC calls (`reference/`)

**Isolation rule:** No file in `skills/ontology-curator/` may reference or link to paths in `skills/intuition/`. Copy what you need. The skill must be fully self-contained — an agent with zero prior Intuition context loads only `skills/ontology-curator/SKILL.md` and has everything it needs.

The existing `planning/publish-learning/ENGINEER-HANDOFF.md` is the format reference for this document.

---

## The One Blocking Dependency

**Before the skill can generate `createTriplesTx` for any mapping or hierarchy triples, 4 meta-predicate atoms must exist on-chain.**

These are the predicates used in mapping triples:
- `same-as` — two atoms represent the same concept from different communities
- `broader-than` — atom A is a more general concept than atom B
- `narrower-than` — atom A is a more specific concept than atom B
- `conflicts-with` — two atoms claim the same role but with incompatible semantics

**What you need to do before writing any skill files:**

1. Define exact names and descriptions for all 4 (natural language, lowercase, hyphenated — see naming conventions below)
2. Pin each via `pinThing` mutation on testnet (chain 13579)
3. Run `createAtoms` for all 4
4. Call `calculateAtomId(stringToHex(ipfsUri))` for each to get the `bytes32` termId
5. Record all 4 termIds in `reference/decision-rules.md` as named constants
6. Repeat on mainnet (chain 1155) when ready to ship

Until this is done: the skill still works for discovery, decision tree, and `createAtomsTx` — but mapping entries in the manifest will have `"bootstrapped": false` and `createTriplesTx` will be omitted.

This is a 20-30 minute agent-run operation, not a code task. Use the `skills/intuition/` skill to execute it.

---

## File Structure to Create

```
skills/ontology-curator/
  SKILL.md                            Core entry point — phases 1-8, output contract, ABI fragments
  README.md                           Human-facing docs: installation, usage, examples
  reference/
    intuition-primer.md               Cold-user explainer: what atoms and triples are, in 3 sentences
    discovery.md                      GraphQL queries for candidate atom lookup; TRUST signal guidance
    decision-rules.md                 Full decision tree (5 concept rules + 3 predicate rules);
                                      meta-predicate atom IDs as named constants; token-overlap thresholds
    output-contract.md                JSON Schema for seed manifest; field constraints; staging order rule;
                                      value field format (base-10 string wei); _note field behavior
    conflict-patterns.md              Conflict detection bounds; comparison rules; counter-triple semantics
  operations/
    propose-ontology.md               Phases 1-5b: orientation, session setup, intake, discovery, decision tree,
                                      predicate normalization
    resolve-conflicts.md              Phase 6: conflict detection (bounded to top-10 per concept),
                                      unification strategies
    seed-ontology.md                  Phases 7-8: IPFS pinning, isTermCreated check, createAtomsTx,
                                      createTriplesTx calldata, deposit recommendation
  tests/
    prompts/
      b1-discovery.md
      b1b-decision-rules.md
      b2-conflicts.md
      b3-seeding.md
      b3b-edge-cases.md
```

---

## SKILL.md Frontmatter

```yaml
---
name: ontology-curator
description: Use this skill when designing, discovering, or curating ontologies for the Intuition
  knowledge graph. Guides agents and developers through use case intake, live graph discovery,
  decision rules (reuse/alias/fork), conflict detection, and seed manifest generation. Triggers on
  tasks involving Intuition ontology design, atom schema planning, knowledge graph interoperability,
  or cross-ontology conflict resolution.
license: MIT
metadata:
  author: 0xintuition
  version: "0.1.0"
argument-hint: "[--domain <name>] [--chain mainnet|testnet] [--concepts <comma-separated>]"
allowed-tools: "Bash, Read"
---
```

---

## File-by-File Specs

### `SKILL.md`

Entry point. Short and opinionated. When an agent loads this file, it should have everything it needs to start Phase 1 immediately.

Contents:
- **One-line framing:** "Describe your domain in plain language. This skill queries the live Intuition graph, maps your concepts to existing atoms or creates new ones, detects cross-ontology conflicts, and emits a seed manifest with transaction calldata."
- **Pre-flight check:** Before running any phase, verify the 4 meta-predicate atoms are bootstrapped. Query GraphQL for atoms with labels matching `same-as`, `broader-than`, `narrower-than`, `conflicts-with`. If any are missing, point to `reference/decision-rules.md` for the seeding runbook. If all 4 exist, record their termIds in-session.
- **Phase summary table:** 8 phases, one line each, pointing to the relevant operation file
- **Output contract summary:** One sentence. Full spec in `reference/output-contract.md`.
- **All embedded ABI fragments** (copy from `skills/intuition/SKILL.md` — do not link):
  - Read: `getAtomCost`, `getTripleCost`, `calculateAtomId`, `isTermCreated`
  - Write: `createAtoms`, `createTriples`
- **Network config table** (copy from `skills/intuition/SKILL.md`):
  - MultiVault: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e` (both networks)
  - Mainnet chainId: 1155 | Testnet chainId: 13579
  - GraphQL: mainnet `https://mainnet.intuition.sh/v1/graphql` | testnet `https://testnet.intuition.sh/v1/graphql`
- **pinThing mutation** (inline, copy from `skills/intuition/reference/schemas.md`):
  ```graphql
  mutation PinThing($input: PinThingInput!) {
    pinThing(input: $input) { uri }
  }
  ```
  All 4 fields required: `name`, `description`, `image`, `url`. Use `""` for optional fields — never omit.

---

### `reference/intuition-primer.md`

Loaded in Phase 1 for cold users. Must be completable in ~3 sentences of agent output.

Contents:
- What an atom is: a concept node pinned to IPFS, registered on-chain. Example in domain terms.
- What a triple is: a claim connecting three atoms as (subject, predicate, object). Example in domain terms.
- What a vault is: every atom and triple has one. TRUST deposited into a vault = community confidence signal. Higher deposits = more canonical.
- One sentence on why this skill exists: "Before creating atoms, this skill checks what's already on the graph so you don't fragment the knowledge base by duplicating existing canonical concepts."
- Opt-out: "If you already know Intuition, say 'skip primer' and we'll go straight to intake."

---

### `reference/discovery.md`

The authoritative GraphQL query for Phase 4 candidate lookup. Must include:

**Primary discovery query:**
```graphql
atoms(
  where: { label: { _ilike: "%concept%" } }
  order_by: { as_predicate_triples_aggregate: { count: desc } }
  limit: 50
) {
  term_id label type
  term { vaults { total_shares curve_id } }
  as_predicate_triples_aggregate { aggregate { count } }
  as_subject_triples(limit: 10) { predicate { label } }
  as_object_triples(limit: 10) { predicate { label } }
}
```

Notes to include:
- `term.vaults` is an array. Use `term.vaults[0].total_shares` for the TRUST signal (one vault per atom by default — curve_id "1").
- `as_subject_triples` and `as_object_triples` as SELECT fields are valid. This is how you fetch neighborhood data inline — no second round-trip needed.
- Do NOT use `vault { total_shares }` directly on atoms — that field does not exist in the atoms GraphQL type. Always go through `term { vaults { ... } }`.
- `term.vaults[0].total_shares` from GraphQL is non-real-time. Acceptable for canonicalization decisions. If the user needs exact real-time vault state before a deposit, use on-chain `getVault(termId, curveId)` — but that's the `intuition` skill's job, not this one.
- **GraphQL error behavior:** If the endpoint is unreachable, surface a `discovery_failed` warning in the manifest and propose all concepts as CREATE. Never block the flow — a user with no internet can still get a manifest, they just can't benefit from graph discovery.
- The `intuition-learning` skill's atoms may not be seeded on testnet yet. Always query first. No hard coupling between skills.

---

### `reference/decision-rules.md`

The decision tree for both concept atoms (Phase 5) and predicate atoms (Phase 5b). This is the most implementation-critical file.

**Meta-predicate atom IDs (fill after seeding):**

```
SAME_AS_TERM_ID        = 0x<bytes32>   # "same-as"
BROADER_THAN_TERM_ID   = 0x<bytes32>   # "broader-than"
NARROWER_THAN_TERM_ID  = 0x<bytes32>   # "narrower-than"
CONFLICTS_WITH_TERM_ID = 0x<bytes32>   # "conflicts-with"
```

These are constants. Update here only. All other files reference them by name.

**Phase 5 — Concept Decision Tree (evaluate rules in order, stop at first match):**

```
Rule 1 — REUSE:
  Condition: exact label match (case-insensitive) AND type != TextObject
  Action: DO NOT auto-select.
  Surface top-3 matching atoms sorted by term.vaults[0].total_shares desc.
  For each, show: label, termId, type, total_shares, description (from IPFS metadata if available).
  Require agent/user to confirm which atom to REUSE, or decline all.
  If confirmed: use that termId, no new atom needed.
  If all declined: proceed to Rule 2.
  REASON: labels are display hints — multiple atoms can share the same label string.
  Never auto-select on label alone.

Rule 2 — ALIAS:
  Condition (all three required):
    (a) >75% word token overlap (lowercase, split on whitespace/hyphens)
    (b) at least 2 shared predicate labels in local neighborhood
        [local neighborhood = union of as_subject_triples + as_object_triples predicate labels]
    (c) term.vaults[0].total_shares > 0
  Action: CREATE new atom + add mapping triple (newAtom, SAME_AS_TERM_ID, existingAtom)
  NOTE: requires SAME_AS_TERM_ID to be bootstrapped. If bootstrapped=false, createTriplesTx is omitted.

Rule 3 — BROADER/NARROWER:
  Condition: (candidate label tokens ⊂ existing atom label tokens) OR (existing tokens ⊂ candidate tokens)
             AND term.vaults[0].total_shares > 0
  [If subset relationship is ambiguous, ask: "Is [candidate] a specific type of [existing]?"]
  Triple direction: (narrower_atom, BROADER_THAN_TERM_ID, broader_atom)
  Action: CREATE new atom + add hierarchy triple

Rule 4 — TEXTOBJECT:
  Condition: match exists (exact or semantic) but type = TextObject
  Action: Surface to user: "Predicate '[label]' (termId: 0x...) exists as a legacy plain-string atom.
          Create a pinned replacement via pinThing + createAtoms. New version becomes canonical."
          CREATE pinned replacement atom.

Rule 5 — CREATE:
  Condition: no match
  Action: CREATE fresh atom.
```

**Phase 5b — Predicate Normalization (evaluate rules in order, stop at first match):**

```
Normalization: lowercase, strip hyphens/underscores, collapse camelCase boundaries.
Examples: "issuedBy" → "issuedby", "issued-by" → "issuedby", "issued_by" → "issuedby"
Use normalized form for all comparisons.

Rule 1 — REUSE:
  Condition: normalized label matches existing non-TextObject atom
  Action: Surface top-3 sorted by term.vaults[0].total_shares desc. Require confirmation.
  If confirmed: use that termId as predicate atom.
  If declined: proceed to Rule 2.

Rule 2 — ALIAS:
  Condition: surface forms differ (camelCase vs kebab-case vs snake_case) but normalize to same root
  Action: Auto-select canonical form (highest total_shares). Log normalization:
          { userLabel, resolvedTermId, normalizedForm, action: "ALIAS" }
  This is safe to auto-apply — forms are demonstrably the same root, no confirmation needed.

Rule 3 — CREATE:
  Condition: no match after normalization
  Action: CREATE fresh predicate atom via pinThing + createAtoms.
          Add to predicates[] in manifest: { userLabel, resolvedTermId, action: "CREATE", normalizedForm }
```

---

### `reference/output-contract.md`

Full JSON Schema for the seed manifest. Required fields and types for every key.

Key constraints to document:
- `status` field: `"proposal_ready"` | `"discovery_failed"` | `"bootstrap_required"`
- `reuse[]`: required fields: `label`, `termId` (bytes32 hex string), `reason` (human-readable)
- `create[]`: required fields: `name`, `schema` (always `"Thing"`), `pinInput` (all 4 fields: `name`, `description`, `image`, `url`), `ipfsUri`, `termId`
- `predicates[]`: required fields: `userLabel`, `resolvedTermId`, `action` (`"REUSE"|"ALIAS"|"CREATE"`), `normalizedForm`
- `mappings[]`: required fields: `subject`, `subjectTermId`, `predicate`, `predicateTermId` (null if not bootstrapped), `object`, `objectTermId`, `bootstrapped` (boolean)
- `conflicts[]`: required fields: `candidateA`, `candidateATermId`, `candidateB`, `candidateBTermId`, `reason`, `resolution`
- `createAtomsTx.value`: base-10 string, wei units (not hex, not float). Example: `"1000000000000000"`.
- `_note` field: non-validated metadata. Document that consumers MUST NOT validate the manifest against a schema that rejects unknown keys — `_note` is informational.
- `staging.step1` / `staging.step2`: always present. step2 tx must never be submitted before step1 is confirmed on-chain.
- When `bootstrapped: false` on any mapping entry: `createTriplesTx` is omitted entirely from the manifest. A `_note` is added: "Bootstrap meta-predicates first. See reference/decision-rules.md."

---

### `reference/conflict-patterns.md`

Documents how conflict detection works and how to interpret the output.

Contents:
- **Detection scope:** bounded to top-10 atoms by `term.vaults[0].total_shares` per concept (from Phase 4 results). With 15 concepts, max 150 atoms → C(150,2) ≈ 11,175 unique pairs — tractable in-context.
- **Three conflict triggers:**
  1. Two atoms in candidate set with >50% token overlap but no linking triple between them
  2. A proposed CREATE atom with >50% token overlap against an existing atom from a different creator address (use `creator` field in GraphQL if available; fall back to no-shared-triples as proxy)
  3. Two atoms appearing as predicates for the same relationship type across different local neighborhoods
- **Resolution strategies:**
  1. Redirect: use the higher `total_shares` atom (both community trust and predicate usage count)
  2. Unification: create a `same-as` triple bridging the two atoms
- **Counter-triple note (inline, do not defer):** "All mapping triples (`same-as`, `broader-than`, `narrower-than`, `conflicts-with`) automatically generate counter-triple vaults per Intuition Protocol Invariant 12. The semantic meaning of counter-triple vault deposits for these meta-predicates is undefined in this skill. Do not interpret a deposit into a counter-triple vault as negation of the mapping relationship. Treat counter-triple vaults as protocol artifacts."

---

### `operations/propose-ontology.md`

Self-contained runbook for Phases 1 through 5b.

**Phase 1 — Orientation (always run):**
Load `reference/intuition-primer.md`. Present ~3 sentences in domain terms. Skip if user says "I know Intuition."

**Phase 2 — Session Setup:**
Fetch and cache via `cast call` or `readContract`:
```
atomCost   = getAtomCost()
tripleCost = getTripleCost()
```
Use as `assets[i]` values in calldata. `msg.value = sum(assets[])`.
Note: Do NOT fetch `getBondingCurveConfig()` — `defaultCurveId` is not needed. This skill does not call `deposit` or `redeem`. For TRUST deposits after seeding, load the `intuition` skill.

**Phase 3 — Use Case Intake:**
Collect:
- Domain name
- 5-15 key concepts (cap at 15 per session; split large domains by sub-domain)
- 3-5 relationships between concepts (these become the predicates for Phase 5b)

**Phase 4 — Live Graph Discovery:**
For each concept, run the query from `reference/discovery.md`. Limit 50 candidates per concept.
If endpoint unreachable: surface `discovery_failed` warning, propose all as CREATE, continue.

**Phase 5 — Concept Decision Tree:**
Apply rules from `reference/decision-rules.md` in order per concept.

**Phase 5b — Predicate Normalization:**
For each predicate label appearing in the user's proposed relationships, apply the predicate rules from `reference/decision-rules.md`.
Predicate atoms created here enter the same `create[]` queue as concept atoms and are seeded first in Phase 7.

---

### `operations/resolve-conflicts.md`

Self-contained runbook for Phase 6.

Follow the detection logic from `reference/conflict-patterns.md`.
Output `conflicts[]` in the manifest. If no conflicts: output `"conflicts": []` (never null, never absent).
Include inline counter-triple note (copy from `reference/conflict-patterns.md` — do not link).

---

### `operations/seed-ontology.md`

Self-contained runbook for Phases 7 and 8. Contains all ABIs and mutations needed — engineer copies from `skills/intuition/` as needed.

**Phase 7 — IPFS Pinning + Existence Check (per atom in `create[]`):**

Step 1 — Pin via `pinThing` mutation (copy mutation inline here):
```graphql
mutation PinThing($input: PinThingInput!) {
  pinThing(input: $input) { uri }
}
```
All 4 fields required. Use `""` for `image` and `url` if not applicable. Never omit.
If pin fails: add to `failed[]` block with error reason. Do NOT proceed to `createAtomsTx` for that atom. Atoms in `failed[]` are never included in calldata.

Step 2 — Existence check:

Viem (preferred):
```typescript
const atomData = toHex(ipfsUri)  // viem stringToHex
const termId = await readContract({
  address: MULTIVAULT, abi, functionName: 'calculateAtomId', args: [atomData]
})
const exists = await readContract({
  address: MULTIVAULT, abi, functionName: 'isTermCreated', args: [termId]
})
```

cast (alternative):
```bash
ATOM_DATA=$(cast --from-utf8 "$IPFS_URI")
TERM_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" "$ATOM_DATA" --rpc-url $RPC)
EXISTS=$(cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" "$TERM_ID" --rpc-url $RPC)
```
Note: `cast --from-utf8` produces raw hex. cast handles the ABI encoding of the bytes argument internally. Do not manually ABI-encode. `calculateAtomId` is a `pure` function — call it via readContract or cast call, never compute locally.

If `isTermCreated` returns `true`: remove atom from `create[]`, add to `reuse[]` with confirmed termId. Do not include in `createAtomsTx`.

If `isTermCreated` RPC call fails: surface a warning. Do NOT silently skip — treat as unknown. Do not generate calldata for that atom.

Step 3 — Record pre-calculated `termId` in each `create[]` entry.

**Phase 8 — Seed Manifest:**

Generate `createAtomsTx`:
```
to:    MultiVault address
data:  createAtoms(bytes[] atomDatas, uint256[] assets) calldata
       atomDatas[i] = stringToHex(ipfsUri) for each atom in create[]
       assets[i]    = atomCost (from Phase 2)
value: sum(assets[]) as base-10 string in wei
```

Generate `createTriplesTx` (only if all mapping entries have `bootstrapped: true`):
```
to:    MultiVault address
data:  createTriples(bytes32[] subjectIds, bytes32[] predicateIds, bytes32[] objectIds, uint256[] assets) calldata
       Use termIds from reuse[] and create[] entries
       assets[i] = tripleCost (from Phase 2)
value: sum(assets[]) as base-10 string in wei
```

Staging note (always included):
```json
"staging": {
  "step1": "Submit createAtomsTx. Wait for confirmation.",
  "step2": "Submit createTriplesTx only after step1 confirms on-chain."
}
```

Deposit recommendation (do not generate calldata for this — just the message):
"To establish vault signals, deposit at least 0.001 TRUST per new atom. Load the `intuition` skill and run a batch deposit after `createAtomsTx` confirms."

Partial failure behavior: if some atoms pinned and some failed, generate `createAtomsTx` for the successfully pinned atoms only. Failed atoms go in `failed[]`. Re-running the skill after fixing the failures will: (a) skip already-created atoms via `isTermCreated`, (b) attempt to pin and create only the failed ones.

---

### `README.md`

Human-facing docs.

Contents:
- 2-3 sentences on what the skill does and why it exists
- Installation: `npx skills add 0xintuition/agent-skills --skill ontology-curator`
- How to use it: describe your domain, run the phases, submit the manifest
- What "TRUST as governance" means for ontology design (one short paragraph)
- Bootstrap requirement: the 4 meta-predicate atoms must be seeded before mapping triples work
- Link to `planning/ontology-curator/ENGINEER-HANDOFF.md` for implementation context

---

### Test Prompts

Each file is a prompt to run against a real agent session to validate the behavior.

**`b1-discovery.md` — Phase 4 live graph discovery**

Prompt: "I'm building a verifiable credential system. My domain concepts are: Credential Issuer, Verification Result, Schema Registry, Proof Format."

Pass criteria:
- At least one `reuse[]` candidate returned for a common concept (e.g., "Issuer" — the Intuition graph has ~170K atoms)
- Every `termId` in `reuse[]` is a valid bytes32 hex string
- `term.vaults[0].total_shares` present and nonzero for reuse candidates
- GraphQL query used `term { vaults { total_shares curve_id } }` (not `vault { total_shares }` — that field doesn't exist on atoms)

---

**`b1b-decision-rules.md` — Phase 5 + 5b all branches**

IMPORTANT: Provide fixture atoms in the prompt body — do not rely on live graph for decision rule testing. Live graph is mutable and test results would be non-deterministic.

Fixture format (embed directly in the prompt):
```json
{
  "fixture_atoms": [
    { "label": "Issuer", "term_id": "0x...", "type": "Thing", "total_shares": 500,
      "predicate_labels": ["about", "type", "version"] },
    { "label": "Organization", "term_id": "0x...", "type": "Thing", "total_shares": 1200,
      "predicate_labels": ["about", "type", "name"] },
    { "label": "credential_issuer", "term_id": "0x...", "type": "TextObject", "total_shares": 10,
      "predicate_labels": [] }
  ]
}
```

Required concept branches to cover (one concept per branch):
| Branch | Input concept | Expected rule |
|--------|--------------|---------------|
| REUSE | "Issuer" | Surface top-3 candidates, require confirmation |
| ALIAS | "Credential Issuer" (>75% overlap with "Issuer", 2+ shared predicates) | CREATE + same-as triple |
| BROADER | "Org" (subset of "Organization" tokens) | CREATE + broader-than triple |
| TEXTOBJECT | "credential_issuer" (TextObject match) | Surface warning, CREATE pinned replacement |
| CREATE | "ZK Proof Circuit" (no match) | Fresh atom |

Required predicate branches to cover:
| Branch | Input predicate | Expected rule |
|--------|----------------|---------------|
| REUSE | "issued-by" (exact normalized match) | Surface top-3, require confirmation |
| ALIAS | "issuedBy" (same root as "issued-by") | Auto-select canonical, log normalization |
| CREATE | "attestation-purpose" (no match) | Fresh predicate atom |

Pass criteria:
- Each branch fires exactly once for its input
- REUSE never auto-selects without confirmation (concept or predicate)
- ALIAS for predicates auto-selects (safe — demonstrably same root)
- Predicate output appears in `predicates[]`, not `create[]`
- All 8 branches covered in a single prompt run

---

**`b2-conflicts.md` — Phase 6 conflict detection**

Three sub-prompts:

Prompt 1 — Semantic overlap:
Provide fixture with two concepts sharing >50% token overlap but no linking triple. Expect: one entry in `conflicts[]` with `candidateA`, `candidateB`, `reason`, `resolution`.

Prompt 2 — Predicate collision:
Provide fixture with two atoms appearing as predicates for the same relationship type in different local neighborhoods. Expect: `conflicts[]` entry flagging predicate collision.

Prompt 3 — No conflicts:
Provide fixture with fully distinct concepts. Expect: `"conflicts": []` (not null, not missing).

Pass criteria:
- `conflicts` key always present in manifest output
- Resolution field always populated (never null)
- Counter-triple note present somewhere in the output

---

**`b3-seeding.md` — Phases 7-8 happy path**

Run against testnet (chain 13579) with a funded signer.

Flow to validate:
1. `pinThing` mutation runs → `ipfsUri` returned
2. `calculateAtomId(stringToHex(ipfsUri))` called → `termId` returned
3. `isTermCreated(termId)` returns false on first run
4. `createAtomsTx` generated with correct `assets[]` = atomCost per atom, `value` as base-10 wei string
5. `createAtomsTx` submitted → confirmed on-chain
6. `createTriplesTx` generated with correct `subjectIds[]`, `predicateIds[]`, `objectIds[]`
7. `createTriplesTx` submitted → confirmed on-chain

Pass criteria:
- No `MultiVault_AtomExists` reverts (isTermCreated pre-check worked)
- No `MultiVault_TermDoesNotExist` reverts (atom seeding before triple seeding worked)
- `staging.step1` / `staging.step2` present
- GraphQL confirms atoms and triples visible after confirmation

---

**`b3b-edge-cases.md` — Phases 7-8 edge cases**

Four sub-prompts:

Edge case 1 — `pin_failed`:
Mock `pinThing` to return an error. Expect: skill halts for that atom, adds it to `failed[]`, does NOT generate `createAtomsTx` with a placeholder URI.

Edge case 2 — `isTermCreated=true`:
Run skill on a domain where some atoms already exist on-chain. Expect: those atoms demoted from `create[]` to `reuse[]`, `createAtomsTx` omits them, no `MultiVault_AtomExists` revert.

Edge case 3 — Bootstrap disabled:
Run skill before meta-predicates are seeded. Expect: all mapping entries have `bootstrapped: false`, `createTriplesTx` omitted, manifest `_note` says "Bootstrap meta-predicates first."

Edge case 4 — Partial failure:
3 of 5 atoms pin successfully, 2 fail. Expect: `create[]` contains only 3 atoms, `failed[]` contains 2 with error reasons, `createAtomsTx` covers only the 3.

Pass criteria for all edge cases:
- Skill never silently drops an atom (failed atoms always appear in `failed[]`)
- Skill never generates calldata for an atom without a valid `ipfsUri`
- Re-running after partial failure only attempts the failed atoms (isTermCreated=true for the rest)

---

## Hard Constraints

1. **No references to `skills/intuition/` paths.** Copy ABI fragments, mutation schemas, and encoding patterns directly into this skill's files. Zero cross-skill dependencies.

2. **Never auto-select on label match.** Labels are display hints — multiple atoms can share the same label string. Phase 5 Rule 1 and Phase 5b Rule 1 must always surface candidates and require confirmation before REUSE.

3. **ALIAS for predicate format variants is the exception.** This is the one place auto-selection is safe, because camelCase vs kebab-case vs snake_case of the same root is demonstrably equivalent — no semantic ambiguity. Only Rule 2 of Phase 5b qualifies for this.

4. **`createTriplesTx` must never be submitted before `createAtomsTx` confirms.** Triples reference atoms that don't exist on-chain until after creation. Staging order is mandatory. Staging note must be present in every manifest.

5. **All `pinThing` fields are required.** Use `""` for optional fields. Never omit `image` or `url`. Omitting any field causes `Request Transformation Failed` (known edge case from the `intuition` skill's commit history).

6. **Meta-predicate IDs live in one place:** `reference/decision-rules.md`. All other files reference them by name, not by value.

7. **`value` in tx objects is a base-10 string in wei.** Not hex. Not float. Example: `"1000000000000000"`. Match the existing `intuition` skill's output contract format.

8. **`conflicts` is always an array.** Never null, never absent. An empty `conflicts: []` is a valid and required output for domains with no detected conflicts.

9. **Skill is self-contained.** An agent loading only `SKILL.md` has everything — ABI fragments, network config, mutation schemas, decision tree pointer. No external skill loads required.

---

## Failure Modes to Handle

Address each of these during implementation. Most are handled in the operations files.

| Phase | Failure | Visible/Silent | Where to Handle |
|-------|---------|----------------|-----------------|
| Phase 4 | GraphQL unreachable | Must be visible | `operations/propose-ontology.md` |
| Phase 5 Rule 1 | Auto-REUSE on label match | Silent corruption — FIXED in design | `reference/decision-rules.md` |
| Phase 5b Rule 2 | Wrong canonical selected for ALIAS | Silent wrong termId | Sort by total_shares desc before selecting |
| Phase 6 | `conflicts: null` instead of `[]` | Silent consumer break | Explicitly set to `[]` if no conflicts |
| Phase 7 | `pinThing` fails | Must be visible | `failed[]` block in manifest |
| Phase 7 | `isTermCreated` RPC fails | Silent if not handled | Surface warning, don't skip |
| Phase 7 | Partial pin failure | Silent if not handled | `failed[]` block required |
| Phase 8 | Triple tx before atom confirms | Visible revert | Staging note enforces order |
| Phase 8 | `bootstrapped=false` missing | Silent (wrong manifest shape) | Always include `bootstrapped` on every mapping |

---

## Implementation Order

Dependencies flow in two parallel groups.

**Do first (can run in parallel — no interdependencies):**
1. **Resolve Open Question #1** — define and seed the 4 meta-predicate atoms on testnet. Record bytes32 IDs. This unblocks everything downstream.
2. **Write `reference/intuition-primer.md`** — standalone, no deps
3. **Write `reference/decision-rules.md`** — requires meta-predicate IDs from Step 1
4. **Write `reference/output-contract.md`** — JSON Schema, no deps beyond the design doc

**Then (can run in parallel after group 1):**
5. **Write `SKILL.md`** — requires meta-predicate IDs (Step 1) + ABI fragments (copy from `skills/intuition/`)
6. **Write `reference/discovery.md`** — requires final query shape (confirmed against live schema)
7. **Write `operations/propose-ontology.md`** — requires decision-rules.md
8. **Write `operations/resolve-conflicts.md`** — requires conflict-patterns.md
9. **Write `operations/seed-ontology.md`** — requires output-contract.md
10. **Write `reference/conflict-patterns.md`** — requires finalized conflict detection logic

**Then (sequential — depends on all above):**
11. **Write `README.md`**
12. **Write all 5 test prompts** — requires all operations + output contract
13. **Run test prompts against testnet** — requires seeded meta-predicates (Step 1)

**Worktree parallelization:** Steps 1-4 can run in parallel worktrees. Steps 5-10 can run in a second wave of parallel worktrees. Total: ~3 parallel runs instead of 13 sequential.

---

## Testing

Follow the layer structure in `TESTING.md`:

**Layer A (offline, no signing):** After writing `operations/seed-ontology.md`, add calldata test cases to `scripts/pass2-calldata-verification.sh`:
- `createAtoms(bytes[], uint256[])` with N atoms at correct `assets[]` values
- `createTriples(bytes32[], bytes32[], bytes32[], uint256[])` with M triples
- Verify selectors with `cast sig "createAtoms(bytes[],uint256[])"` etc.

**Layer B1/B1b/B2 (no broadcast):** Run prompt files against testnet with `--permission-mode bypassPermissions`. Validate manifest shape and decision rule branches.

**Layer B3/B3b (broadcast):** Fund a testnet wallet with tTRUST. Submit `createAtomsTx` and `createTriplesTx`. Verify atoms and triples appear in the GraphQL API.

---

## What's NOT In Scope

Do not build any of this:
- Wallet/signing management — produces unsigned tx params only (same as `skills/intuition/`)
- Deposit/redeem operations — defer to `intuition` skill after seeding
- Full-graph semantic scan — conflict detection is bounded to Phase 4 candidate set only (~150 atoms max)
- Semantic embedding-based matching — Phase 5/5b uses token-overlap heuristics only
- Ontology versioning or migration of existing triples
- A shared canonical atom registry — the live graph IS the registry
- Background daemon or auto-publish behavior
- Real-time vault state for deposit decisions — GraphQL `total_shares` is sufficient for canonicalization

---

## Reference Documents

Full design history, decision rationale, and eng review findings (not required reading — this handoff is authoritative):

- **Approved design doc:** `planning/ontology-curator/design.md`
- **Eng review test plan (consumed by `/qa`):** `planning/ontology-curator/test-plan.md`
- **Reference skill (copy ABIs from here):** `skills/intuition/SKILL.md`
- **Reference GraphQL patterns (confirmed against live schema):** `skills/intuition/reference/graphql-queries.md`
- **Prior handoff doc (format reference):** `planning/publish-learning/ENGINEER-HANDOFF.md`
