# Eng Review Test Plan — intuition-ontology-curator
Branch: billy/ontology-curation | Date: 2026-04-02 | Reviewer: /plan-eng-review

## What This Plan Is For

Consumed by `/qa` to validate the ontology-curator skill implementation against all 5 decision tree branches, all 3 seeding edge cases, and conflict detection. Run against testnet (chain 13579) with a funded signer for B2/B3 layers.

---

## Test Prompt Files

```
tests/prompts/
  b1-discovery.md       Phase 4: concept → candidate list, correct term_id, reuse[] shape
  b1b-decision-rules.md Phase 5 + 5b: ALL 5 concept branches + ALL 3 predicate branches
  b2-conflicts.md       Phase 6: overlap + predicate collision + empty case
  b3-seeding.md         Phases 7-8 happy path: pin → isTermCreated → createAtomsTx → staging
  b3b-edge-cases.md     Phases 7-8 edge cases: pin_failed / isTermCreated=true / bootstrap-disabled / partial failure
```

---

## Layer A: Calldata Verification (Offline)

Run: `./scripts/pass2-calldata-verification.sh`
Expected: `PASS=25 FAIL=0` (baseline). After ontology-curator is implemented, add:
- `createAtoms(bytes[], uint256[])` with N atoms at correct assets[] values
- `createTriples(bytes32[], bytes32[], bytes32[], uint256[])` with M triples
- Selector: `0x[selector]` for both — confirm against `cast sig`

---

## Layer B1: b1-discovery

**Prompt:** "I'm building a verifiable credential system. My concepts are: Credential Issuer, Verification Result, Schema Registry."

**Expected output shape:**
```json
{
  "reuse": [{ "label": "...", "termId": "0x...", "reason": "..." }],
  "create": [{ "name": "...", "schema": "Thing", "pinInput": {...} }],
  "conflicts": []
}
```

**Pass criteria:**
- `termId` fields are valid `bytes32` hex strings
- Labels are display hints — multiple atoms can share same label. If REUSE candidate surfaces, top-3 shown, confirmation required (NOT auto-selected).
- Each `reuse` entry has `reason` citing `total_shares`
- GraphQL query uses `term { vaults { total_shares curve_id } }` NOT `vault { total_shares }`

---

## Layer B1b: b1b-decision-rules

**Purpose:** Verify all 5 concept branches and all 3 predicate branches with fixture data (deterministic, not live graph).

**IMPORTANT:** Decision rule tests must use fixture atoms, not live graph queries. Live graph is mutable — a test that passes today can fail tomorrow if an atom's `total_shares` changes. Supply fixture JSON in the prompt.

### Concept Branch Coverage

| Branch | Input | Expected action |
|--------|-------|----------------|
| REUSE | Concept with exact label match, multiple candidates, >0 total_shares | Surface top-3, require confirmation |
| ALIAS | Concept with >75% token overlap + ≥2 shared predicate labels | CREATE new + mapping triple (same-as) |
| BROADER | Concept whose tokens are strict superset of existing | CREATE + hierarchy triple (broader-than) |
| TEXTOBJECT | Match exists but type = TextObject | Surface warning, CREATE pinned replacement |
| CREATE | No match | Fresh atom, no mapping |

### Predicate Branch Coverage (Phase 5b)

| Branch | Input | Expected action |
|--------|-------|----------------|
| REUSE | Predicate label matches existing non-TextObject | Surface top-3, require confirmation |
| ALIAS | "issuedBy" vs "issued-by" (same normalized root) | Auto-select canonical, log normalization |
| CREATE | No normalized match | Fresh predicate atom |

**Pass criteria:**
- Each branch fires exactly once for the test input
- REUSE never auto-selects without confirmation
- ALIAS auto-selects (format variant only — safe)
- Predicate output appears in `predicates[]` block, not `create[]`
- All 5 concept + all 3 predicate branches covered in single prompt run

---

## Layer B2: b2-conflicts

**Test 1: Semantic overlap**
Input: two concepts with >50% token overlap, no linking triple in fixture.
Expected: `conflicts[]` entry with `candidateA`, `candidateB`, `reason`, `resolution` (redirect to higher total_shares).

**Test 2: Predicate collision**
Input: two atoms appearing as predicates for the same relationship type in different local neighborhoods.
Expected: `conflicts[]` entry flagging predicate collision.

**Test 3: Empty case**
Input: concepts with no overlap.
Expected: `conflicts: []` (not null, not missing).

**Pass criteria:**
- `conflicts` always present (never missing from output)
- Counter-triple note present in output: "Do not interpret counter-triple vault deposits as semantic negation"
- Resolution field always populated

---

## Layer B3: b3-seeding (Happy Path)

Run against testnet (chain 13579) with funded signer.

**Flow:**
1. Phase 7: `pinThing` mutation → `ipfsUri` returned
2. `calculateAtomId(stringToHex(ipfsUri))` → `termId`
3. `isTermCreated(termId)` → false (first run)
4. `createAtomsTx` generated with correct `assets[]` = atomCost per atom
5. Submit `createAtomsTx` → confirm
6. Phase 8: `createTriplesTx` generated with correct `subjectIds[]`, `predicateIds[]`, `objectIds[]`
7. Submit `createTriplesTx` → confirm

**Pass criteria:**
- `createAtomsTx` submitted BEFORE `createTriplesTx`
- `staging.step1` / `staging.step2` present in manifest
- No `MultiVault_AtomExists` reverts (isTermCreated pre-check worked)
- No `MultiVault_TermDoesNotExist` reverts (atom seeding before triple seeding worked)
- GraphQL confirms atoms and triples visible after confirmation

---

## Layer B3b: b3b-edge-cases

**Edge case 1: pin_failed**
`pinThing` returns error. Expected: skill halts Phase 7 for that atom, surfaces error message, does NOT generate `createAtomsTx` with placeholder URI.

**Edge case 2: isTermCreated=true**
Atom already exists on-chain. Expected: atom demoted from `create[]` to `reuse[]` in manifest, `createAtomsTx` omits it. No `MultiVault_AtomExists` revert.

**Edge case 3: bootstrap-disabled**
Meta-predicates not yet seeded. Expected: `bootstrapped: false` on all mapping entries, `createTriplesTx` omitted from manifest, staging note present: "Bootstrap meta-predicates first."

**Edge case 4: partial failure**
3 of 5 atoms pin successfully, 2 fail. Expected: manifest contains `create[]` with only the 3 successful atoms, `failed[]` block with 2 atoms + error reasons, `createAtomsTx` covers only the 3.

**Pass criteria for all edge cases:**
- Skill never silently drops an atom (failed atoms appear in `failed[]`)
- Skill never generates calldata for an atom with no valid IPFS URI
- Bootstrap flag always set correctly — no triple tx when not bootstrapped
- Re-run after partial failure produces correct incremental manifest

---

## Failure Modes Table

| Phase | Failure | Visible or Silent? | Test Coverage | Notes |
|-------|---------|-------------------|---------------|-------|
| Phase 4 | GraphQL endpoint unreachable | Visible (must halt or warn) | b1 | Define behavior in `reference/discovery.md`: propose all as CREATE with warning, or halt |
| Phase 4 | `term { vaults }` field missing in response | Visible (GraphQL error) | b1 | Fixed: wrong path was `vault { total_shares }` |
| Phase 5 | Auto-REUSE on label match | Silent data corruption | b1b | Fixed: require confirmation. Never auto-select. |
| Phase 5b | Format variant ALIAS picks wrong canonical | Silent (wrong termId in triples) | b1b | Guard: sort candidates by total_shares desc before selecting |
| Phase 6 | `conflicts: null` instead of `[]` | Silent (consumer breaks) | b2 | Empty case test validates this |
| Phase 7 | `pinThing` fails | Visible (must surface error) | b3b edge case 1 | Never generate calldata with missing URI |
| Phase 7 | `isTermCreated` RPC call fails | Silent (could generate duplicate createAtomsTx) | b3b | Treat RPC failure as unknown — surface warning, don't skip |
| Phase 7 | Partial pin failure | Silent if not handled | b3b edge case 4 | Failed atoms must appear in `failed[]` block |
| Phase 8 | Triple tx submitted before atom tx confirms | Visible revert | b3 | Staging note enforces order. Test out-of-order submission. |
| Phase 8 | Bootstrap not checked before triple generation | Silent (bootstrapped=false omitted) | b3b edge case 3 | `bootstrapped` flag must be present on every mapping entry |
| Phase 5 REUSE | top-3 candidates not fetched (only 1 returned) | Silent (user sees false certainty) | b1b | Query must use `limit: 3` on the confirmation surface |
| Phase 5b ALIAS | Non-format variant treated as ALIAS | Silent (wrong unification) | b1b | Rule 2 applies ONLY to format variants (camelCase/kebab/snake of same root) |

---

## Worktree Parallelization

The 10 implementation steps can be parallelized as follows:

**Parallel Group 1 (no dependencies):**
- Step 1: Resolve meta-predicate names/descriptions → seed on testnet → record bytes32 IDs
- Step 3: Write `reference/intuition-primer.md` (standalone, no code deps)
- Step 5: Write `reference/decision-rules.md` (based on finalized design doc)
- Step 6: Write `reference/output-contract.md` (JSON Schema, based on finalized design doc)

**Parallel Group 2 (depends on Group 1):**
- Step 2: Write `skills/ontology-curator/SKILL.md` (depends on meta-predicate IDs from Step 1)
- Step 4: Write `reference/discovery.md` (depends on GraphQL query shape from Step 5)
- Step 7: Write `operations/propose-ontology.md` + `resolve-conflicts.md` + `seed-ontology.md` (depends on output contract from Step 6)

**Sequential (depends on Group 2):**
- Step 8: Write `reference/conflict-patterns.md` (depends on conflict detection design from Step 7)
- Step 9: Write test prompts (depends on all operations + output contract)
- Step 10: Run test prompts against testnet (depends on seeded meta-predicates from Step 1)

**Estimated parallel speedup:** Group 1 runs 4 tasks in parallel. Group 2 runs 3. Total wall-clock: ~3 worktree runs instead of 10 sequential.

---

## What Already Exists

- `skills/intuition/SKILL.md` — all ABI fragments, network config, GraphQL patterns to adapt
- `skills/intuition/reference/graphql-queries.md` — confirmed working query patterns including `term { vaults { total_shares } }`, `_ilike`, `as_subject_triples`, `as_object_triples`
- `skills/intuition-learning/` — 35 atoms ontology to cross-reference during testnet validation
- `TESTING.md` — Layer A/B test runner framework already established
- `scripts/pass2-calldata-verification.sh` — offline calldata test runner (Layer A)

---

## NOT In Scope

- Wallet/signing management (produces unsigned txs only — same as existing skills)
- Deposit/redeem operations (defer to `intuition` skill after seeding)
- Full-graph semantic scan (conflict detection bounded to Phase 4 candidate set — ~100 atoms max)
- Real-time vault state for deposit decisions (GraphQL `total_shares` is acceptable for canonicalization; on-chain `getVault` is deferred to the `intuition` skill)
- Semantic embedding-based matching (Phase 5/5b uses token-overlap heuristics only — no vector similarity)
- Ontology versioning / migration of existing triples
- Cross-skill registry or shared canonical atom list (the live graph IS the registry)
- Background daemon or auto-publish behavior

---

## Review Summary

### Architecture Issues (3)
1. **`vault { total_shares }` wrong field path** — FIXED. Changed to `term { vaults { total_shares curve_id } }` throughout.
2. **Dead `defaultCurveId` in Phase 2** — FIXED. Removed (curveId only needed for deposit/redeem, not this skill).
3. **Phase 5b missing (predicate curation gap)** — FIXED. Added explicit Phase 5b: Predicate Normalization step.

### Code Quality Issues (2)
4. **REUSE auto-selects on label alone** — FIXED. Phase 5 Rule 1 now requires top-3 surface + confirmation.
5. **ALIAS bootstrap gap undocumented** — FIXED. Added NOTE in Phase 5 Rule 2.

### Test Gaps (13 → addressed)
- All 5 decision tree branches: b1b covers REUSE/ALIAS/BROADER/TEXTOBJECT/CREATE
- All 3 predicate branches: b1b covers predicate REUSE/ALIAS/CREATE
- Edge cases: b3b covers pin_failed/isTermCreated=true/bootstrap-disabled/partial failure
- Conflict empty case: b2 validates `conflicts: []`
- Fixture data: decision rule tests use fixture atoms, not live graph
- Failure modes: 12 failure modes documented with test coverage and silent/visible classification

### Performance (0 issues)
- Phase 4 query inline neighborhood data (no N+1)
- Conflict detection bounded to top-10 atoms per concept (max ~4,950 pairs — manageable in-context)
- Phase 5b normalization is in-context string ops (no additional RPC calls)

---

## Open Items Before Implementation

1. **Resolve Open Question #1:** Define exact names and descriptions for the 4 meta-predicate atoms (`same-as`, `broader-than`, `narrower-than`, `conflicts-with`). Seed on testnet. Record `bytes32` IDs in `reference/decision-rules.md` as constants.

2. **Address Reviewer Concerns #1-8** during implementation (not design blockers — see design doc section "Reviewer Concerns").

3. **Decide fixture strategy:** b1b tests reference live graph for Phase 4 discovery but must use fixture data for Phase 5 decision rule testing. Define fixture format and whether fixtures live inline in the prompt or in a separate `tests/fixtures/` file.
