# B1 Nested-Triple Prompts (No Broadcast)

These prompts validate that agents can discover, classify, and compose nested triples using the skill's `reference/nested-triples.md`, `reference/graphql-queries.md`, `reference/reading-state.md`, and `operations/create-triples.md`.

All tests hit **testnet** because nested-triple composition is a new skill surface and testnet is the safest place to compose without meaningful value at stake:

- GraphQL: `https://testnet.intuition.sh/v1/graphql`
- RPC: `https://testnet.rpc.intuition.systems/http`
- MultiVault: `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`
- Chain ID: `13579`

These are read-only — no wallet, no signing, no broadcast. Construction tests return unsigned transaction JSON only.

## Design Notes

- Tests validate **structure and behavior**, not specific content (testnet data changes)
- Fixtures are discovered at runtime via GraphQL, not hardcoded — survives testnet resets
- If a known nested fixture exists, pass it via `NESTED_TRIPLE_ID`; otherwise tests must handle "no fixture" explicitly
- Agents must use `getVaultType` (not `isTriple` alone) whenever the distinction matters between positive triples and counter-triples
- Construction prompts require classification, duplicate checks, previews, simulation, and calldata decode before returning an unsigned transaction

## Runner

```bash
claude -p "<prompt>" \
  --allowedTools "Bash,Read,Glob,Grep" \
  --permission-mode bypassPermissions \
  --no-session-persistence
```

## B1-NT.1 -- Nested Triple Discovery

Tests: `terms(type: Triple)` filter, three-valued discriminator awareness, polymorphic `*_term` fragment unwrap.

```text
Use the intuition skill from this repo.

On Intuition testnet (GraphQL endpoint https://testnet.intuition.sh/v1/graphql),
discover up to 5 existing positive triples that could be reused as subjects in
new nested triples. Use the schema's three-valued term type and make sure your
results do not include counter-triples.

For each result, unwrap the subject, predicate, and object using the polymorphic
term-aware relationships so that triple-valued positions would render safely.

Return strict JSON:
{
  "endpoint": string,
  "query": string,
  "candidates": [
    {
      "term_id": string,
      "type": "Triple",
      "subject": { "type": "Atom" | "Triple" | "CounterTriple", "label": string | null, "term_id": string },
      "predicate": { "type": "Atom" | "Triple" | "CounterTriple", "label": string | null, "term_id": string },
      "object": { "type": "Atom" | "Triple" | "CounterTriple", "label": string | null, "term_id": string }
    }
  ],
  "command": string,
  "rawOutput": string
}

No prose. No markdown.
```

Pass criteria:
- `endpoint` is the testnet GraphQL URL
- `query` includes `terms(...)` with a `type` filter for positive triples (`type: { _eq: Triple }` or `type: { _eq: "Triple" }`)
- Every candidate has `type == "Triple"` (no counter-triples leaking through)
- Every `term_id` starts with `0x` (bytes32)
- Subject/predicate/object include a `type` field populated from the polymorphic fragment (proves the agent used `subject_term` / `predicate_term` / `object_term` and not the legacy atom-only relationships)
- `candidates` is non-empty or the agent explicitly reports testnet has no positive triples

## B1-NT.2 -- Term Classification via `getVaultType`

Tests: the skill's "classify before composition" guidance — agent uses `getVaultType` to distinguish ATOM / TRIPLE / COUNTER_TRIPLE, not `isTriple` alone.

```text
Use the intuition skill from this repo.

On Intuition testnet:

1. Discover one atom term_id via GraphQL (filter terms to type Atom)
2. Discover one positive triple term_id via GraphQL (filter terms to type Triple)
3. Derive the counter-triple id for that positive triple using
   getCounterIdFromTripleId on the testnet MultiVault
4. Classify all three term_ids using getVaultType(bytes32)(uint8) on-chain
5. For the counter-triple id, also record what isTriple(bytes32)(bool) returns

Return strict JSON:
{
  "multivault": string,
  "classifications": {
    "atom":           { "term_id": string, "getVaultType": number, "label": "ATOM" },
    "positiveTriple": { "term_id": string, "getVaultType": number, "label": "TRIPLE" },
    "counterTriple":  { "term_id": string, "getVaultType": number, "label": "COUNTER_TRIPLE", "isTriple": true }
  },
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- `multivault` is the testnet MultiVault address (`0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`)
- `classifications.atom.getVaultType == 0`
- `classifications.positiveTriple.getVaultType == 1`
- `classifications.counterTriple.getVaultType == 2`
- `classifications.counterTriple.isTriple == true` (agent surfaces the coarseness the skill documents)
- `commands` array includes at least one `getVaultType` call; label strings match the documented ordinal names
- Agent produced the counter-triple id via `getCounterIdFromTripleId`, not by guessing

## B1-NT.3 -- Nested Triple Construction

Tests: the skill's nested-composition guidance — use an existing positive triple term_id directly as a position, classify it with `getVaultType` before proceeding, return a correctly shaped unsigned transaction.

```text
Use the intuition skill from this repo.

On Intuition testnet:

1. Discover an existing positive triple via GraphQL (type Triple) and record its
   term_id as T1. This will be the subject of a new nested triple.
2. Discover two atoms via GraphQL (type Atom) and record their term_ids as P
   (predicate) and O (object).
3. Before composing, classify T1, P, and O with getVaultType. Require
   getVaultType(T1) == 1 (TRIPLE), getVaultType(P) == 0, and
   getVaultType(O) == 0. If any check fails, return an error shape and stop.
4. Compute nestedTripleId with calculateTripleId(T1, P, O).
5. Check isTermCreated(nestedTripleId). If it already exists, choose a different
   P/O pair and retry up to 3 total attempts. If all attempts already exist,
   return decision "skip_existing" with transaction null.
6. Read TRIPLE_COST via getTripleCost() on the testnet MultiVault.
7. Preview the exact creation with previewTripleCreate(nestedTripleId, TRIPLE_COST).
8. Encode calldata for createTriples([T1], [P], [O], [TRIPLE_COST]).
9. Decode the calldata and verify subjectIds[0] equals T1, predicateIds[0]
   equals P, objectIds[0] equals O, and assets[0] equals TRIPLE_COST.
10. Simulate createTriples with cast call using the exact calldata/value/from.
11. Produce an unsigned transaction with msg.value equal to TRIPLE_COST and
    chainId 13579. Do not pin any new atoms — T1 is already a term.

Return strict JSON:
{
  "decision": "proceed" | "skip_existing" | "error",
  "preflight": {
    "T1": { "term_id": string, "getVaultType": 1, "label": "TRIPLE" },
    "P":  { "term_id": string, "getVaultType": 0, "label": "ATOM" },
    "O":  { "term_id": string, "getVaultType": 0, "label": "ATOM" }
  },
  "nestedTripleId": string,
  "duplicateExists": false,
  "tripleCost": string,
  "preview": {
    "shares": string,
    "assetsAfterFixedFees": string,
    "assetsAfterFees": string
  },
  "calldataDecode": {
    "subjectIds": [string],
    "predicateIds": [string],
    "objectIds": [string],
    "assets": [string]
  },
  "simulation": { "passed": true, "returnValue": string },
  "transaction": {
    "to": string,
    "data": string,
    "value": string,
    "chainId": "13579"
  },
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- `decision` is `"proceed"` unless all bounded attempts found existing triples; `"error"` is fail
- `preflight.T1.getVaultType == 1` and `label == "TRIPLE"` (agent classified before composing)
- `preflight.P.getVaultType == 0` and `preflight.O.getVaultType == 0`
- `nestedTripleId` was produced by `calculateTripleId(T1, P, O)`
- `duplicateExists == false` for a proceeding transaction
- `preview` is populated from `previewTripleCreate(nestedTripleId, tripleCost)`
- `simulation.passed == true` for `createTriples([T1], [P], [O], [tripleCost])`
- `transaction.to` is the testnet MultiVault (`0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`)
- `transaction.value` equals `tripleCost` (agent reads it, doesn't assume)
- `transaction.chainId` is `"13579"`
- `transaction.data` selector is `createTriples(bytes32[],bytes32[],bytes32[],uint256[])`
- `calldataDecode.subjectIds[0]` equals `T1` (agent reused the triple term_id directly, not a new atom)
- `commands` shows the agent queried GraphQL, called `getVaultType`, computed `calculateTripleId`, checked `isTermCreated`, previewed, decoded calldata, simulated, and read `getTripleCost`

## B1-NT.4 -- Counter-Triple Safety Boundary

Tests: agent blocks or escalates when a position classifies as a counter-triple. The skill does not teach counter-triple composition as a supported happy path; an agent that blindly passes `isTriple == true` through without checking `getVaultType` would silently proceed.

```text
Use the intuition skill from this repo.

On Intuition testnet:

1. Discover a positive triple via GraphQL and record its term_id as T1.
2. Derive its counter-triple id using getCounterIdFromTripleId. Call this CT1.
3. A user wants to create a new triple where the subject is CT1, the predicate
   is any existing atom P, and the object is any existing atom O. Classify each
   position with getVaultType before composing.
4. If any position classifies as COUNTER_TRIPLE, do not produce an executable
   transaction. Return decision "refuse" or "manual_review". Do not use isTriple
   alone — it is coarse and returns true for counter-triples.

Return strict JSON:
{
  "preflight": {
    "subject":   { "term_id": string, "getVaultType": number, "label": "ATOM" | "TRIPLE" | "COUNTER_TRIPLE", "isTriple": boolean },
    "predicate": { "term_id": string, "getVaultType": number, "label": "ATOM" | "TRIPLE" | "COUNTER_TRIPLE" },
    "object":    { "term_id": string, "getVaultType": number, "label": "ATOM" | "TRIPLE" | "COUNTER_TRIPLE" }
  },
  "decision": "refuse" | "manual_review",
  "reason": string,
  "transaction": null,
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- `preflight.subject.getVaultType == 2` and `preflight.subject.label == "COUNTER_TRIPLE"`
- `preflight.subject.isTriple == true` (agent records the coarse result to document the trap it avoided)
- `decision` is `"refuse"` or `"manual_review"`, never `"proceed"`
- `reason` references counter-triple composition being outside the skill's supported happy path or requiring manual review
- `transaction` is `null` (no tx produced)
- Agent used `getVaultType`, not `isTriple` alone, to reach the refusal decision

## B1-NT.5 -- Nested Rendering Fixture

Tests: agent can render a real nested triple through `*_term` and identify why
legacy atom-only relationships are unsafe. If no nested fixture exists yet, the
agent must return a structured skip rather than fabricating one.

```text
Use the intuition skill from this repo.

On Intuition testnet:

1. If environment variable NESTED_TRIPLE_ID is set, use that triple as the
   fixture. Otherwise, discover one triple where subject_term.type,
   predicate_term.type, or object_term.type is Triple.
2. If no fixture exists, return decision "skip_no_fixture" and stop.
3. For the fixture, query term_id plus subject, predicate, object,
   subject_term, predicate_term, and object_term.
4. Render each component from the term-aware `*_term` relationship. Include the
   component term type, term_id, and label when it is an atom.
5. For every component whose `*_term.type` is "Triple", record whether the
   corresponding legacy atom-only relationship (`subject`, `predicate`, or
   `object`) is null.

Return strict JSON:
{
  "endpoint": string,
  "decision": "render" | "skip_no_fixture",
  "fixture": { "term_id": string | null, "source": "env" | "discovered" | null },
  "query": string,
  "components": {
    "subject":   { "type": "Atom" | "Triple" | "CounterTriple", "term_id": string, "label": string | null },
    "predicate": { "type": "Atom" | "Triple" | "CounterTriple", "term_id": string, "label": string | null },
    "object":    { "type": "Atom" | "Triple" | "CounterTriple", "term_id": string, "label": string | null }
  },
  "legacyNulls": {
    "subject": boolean,
    "predicate": boolean,
    "object": boolean
  },
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- If `decision == "skip_no_fixture"`, `fixture.term_id` is null and no transaction is produced
- If `decision == "render"`, at least one component has `type == "Triple"`
- The query uses `subject_term`, `predicate_term`, and `object_term`
- For every Triple-valued component, the matching `legacyNulls` value is `true`
- The agent does not use legacy atom-only `subject` / `predicate` / `object` as the rendering source

## B1-NT.6 -- Unknown-Term Existence Guard and Classifier Diagnostics

Tests: agent uses `isTermCreated` as the existence guard before construction,
does not rely on `isTriple` / `isCounterTriple` as existence checks, and can
capture the strict classifier (`getVaultType`) error for an unknown term as
diagnostic evidence. The chain reverts `getVaultType` on unknown ids with
`MultiVaultCore_TermDoesNotExist` (selector `0xbdd4a699`); the type-family
booleans return `false` for both unknown ids and valid atom ids.

```text
Use the intuition skill from this repo.

On Intuition testnet:

1. A user proposes a nested triple where:
   - subject term_id = 0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef
     (unknown — never created)
   - predicate = any existing atom term_id (discover one via GraphQL)
   - object    = any existing atom term_id (discover one via GraphQL)
2. Run the existence preflight required by the skill before composing any triple:
   - call isTermCreated(bytes32)(bool) for each proposed position
   - if any position is not created, refuse before encoding calldata
3. For diagnostic evidence on the unknown subject, call:
   - getVaultType(bytes32)(uint8), capturing the revert selector if it reverts
   - isTriple(bytes32)(bool)
   - isCounterTriple(bytes32)(bool)
4. For the discovered predicate and object atoms, record getVaultType so the
   output still proves valid positions classify as ATOM.
5. Do not produce an executable transaction. Return decision "refuse" with
   reason naming the missing term.

Return strict JSON:
{
  "preflight": {
    "subject": {
      "term_id": string,
      "isTermCreated": boolean,
      "getVaultType": "revert" | "not_run" | number,
      "revertSelector": string | null,
      "errorName": "MultiVaultCore_TermDoesNotExist" | string | null,
      "isTriple": boolean,
      "isCounterTriple": boolean
    },
    "predicate": { "term_id": string, "getVaultType": number, "label": "ATOM" | "TRIPLE" },
    "object":    { "term_id": string, "getVaultType": number, "label": "ATOM" | "TRIPLE" }
  },
  "decision": "refuse" | "manual_review",
  "reason": string,
  "transaction": null,
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- `preflight.subject.isTermCreated == false` (agent used the existence guard and found the missing term)
- If `preflight.subject.getVaultType == "revert"`, `revertSelector == "0xbdd4a699"` and `errorName == "MultiVaultCore_TermDoesNotExist"`
- If `preflight.subject.getVaultType == "not_run"`, the refusal reason must explicitly say the agent stopped after `isTermCreated == false`
- `preflight.subject.isTriple == false` and `preflight.subject.isCounterTriple == false` (proves the agent did not treat type-family booleans as existence checks)
- `decision` is `"refuse"` or `"manual_review"`, never `"proceed"`
- `reason` references the missing/unknown term — agent did not silently treat the unknown id as ATOM
- `transaction` is `null`
- `commands` shows an `isTermCreated` call against the unknown id; `getVaultType` is preferred diagnostic evidence but not required before safe refusal
