# B1 GraphQL Read Prompts (No Broadcast)

These prompts validate that agents can autonomously discover atoms, triples, and positions via the Intuition GraphQL API using the skill's `reference/graphql-queries.md`.

All tests hit **mainnet** (`https://mainnet.intuition.sh/v1/graphql`) because mainnet has rich data to search against. These are read-only — no wallet, no signing, no broadcast.

## Design Notes

- Tests validate **structure and behavior**, not specific content (live data changes)
- Each prompt requires the agent to use a different capability from the GraphQL reference
- Output contracts require `term_id` on every candidate — the skill's canonical identity rule
- Tests progress from basic search → traversal → composition → safety

## Runner

```bash
claude -p "<prompt>" \
  --allowedTools "Bash,Read,Glob,Grep" \
  --permission-mode bypassPermissions \
  --no-session-persistence
```

## B1-GQL.1 -- Atom Search by Label

Tests: basic `_ilike` search, correct field selection, aggregate count.

```text
Use the intuition skill from this repo.

Search for atoms with "Ethereum" in their label on Intuition mainnet using GraphQL.
Return up to 10 results.

Return strict JSON:
{
  "endpoint": string,
  "query": string,
  "totalCount": number,
  "candidates": [
    {
      "term_id": string,
      "label": string,
      "type": string
    }
  ],
  "command": string,
  "rawOutput": string
}

No prose. No markdown.
```

Pass criteria:
- `endpoint` is `https://mainnet.intuition.sh/v1/graphql`
- `candidates` is non-empty, each has `term_id` starting with `0x`
- `totalCount` >= `candidates.length`
- `command` shows the actual curl command used

## B1-GQL.2 -- search_term Function

Tests: `search_term` database function usage, correct `terms` return type handling (type discrimination between Atom and Triple).

```text
Use the intuition skill from this repo.

Use the search_term database function to search for "trust" on Intuition mainnet.
Return up to 10 results. For each result, include whether it is an Atom or Triple.

Return strict JSON:
{
  "endpoint": string,
  "query": string,
  "candidates": [
    {
      "id": string,
      "resultType": "Atom" | "Triple",
      "label": string,
      "tripleLabel": string | null
    }
  ],
  "command": string,
  "rawOutput": string
}

For Atom results: set label to the atom label, tripleLabel to null.
For Triple results: set label to null, tripleLabel to "subject predicate object" as a readable string.

No prose. No markdown.
```

Pass criteria:
- Uses `search_term(args: { query: "trust" })` in the GraphQL query
- Each candidate has `id` starting with `0x`
- `resultType` is either `"Atom"` or `"Triple"` (not mixed or missing)
- Atom results have `label`, Triple results have `tripleLabel`

## B1-GQL.3 -- Triples by Predicate

Tests: triple querying with nested relationship filters, S/P/O resolution.

```text
Use the intuition skill from this repo.

Find the 10 most recent triples with predicate "is" on Intuition mainnet using GraphQL.
Include vault signal data if available.

Return strict JSON:
{
  "endpoint": string,
  "predicateTermId": string,
  "triples": [
    {
      "term_id": string,
      "subject": { "term_id": string, "label": string },
      "predicate": { "term_id": string, "label": string },
      "object": { "term_id": string, "label": string }
    }
  ],
  "command": string,
  "rawOutput": string
}

No prose. No markdown.
```

Pass criteria:
- All triples have `predicate.label == "is"`
- All `term_id` fields start with `0x` and are bytes32 length (66 chars)
- `predicateTermId` matches `predicate.term_id` on all results
- Subject and object are resolved with labels

## B1-GQL.4 -- Graph Traversal (Atom to Triples)

Tests: multi-hop traversal starting from a discovered atom, using the AtomTriples pattern.

```text
Use the intuition skill from this repo.

On Intuition mainnet:
1. Search for atoms matching "Ethereum" using GraphQL
2. Pick the first result
3. Find all triples where that atom appears as subject OR object (up to 10 each)

Return strict JSON:
{
  "endpoint": string,
  "sourceAtom": { "term_id": string, "label": string },
  "asSubject": [
    {
      "term_id": string,
      "predicate": string,
      "object": { "term_id": string, "label": string }
    }
  ],
  "asObject": [
    {
      "term_id": string,
      "subject": { "term_id": string, "label": string },
      "predicate": string
    }
  ],
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- `sourceAtom.term_id` starts with `0x` and appears in the search results
- `asSubject` and/or `asObject` contain triples involving the source atom
- The agent used two queries: one to search, one to traverse
- `commands` array has at least 2 entries

## B1-GQL.5 -- Compose Novel Query (Filter Composition)

Tests: agent composing a query not directly in the sample set, using the filter operator table.

```text
Use the intuition skill from this repo.

On Intuition mainnet, use GraphQL to find atoms that:
- Have type "Person"
- Were created after 2025-01-01
- Have a non-null image

Return up to 10 results, ordered by most recent first.

Return strict JSON:
{
  "endpoint": string,
  "query": string,
  "candidates": [
    {
      "term_id": string,
      "label": string,
      "type": string,
      "image": string,
      "created_at": string
    }
  ],
  "filterUsed": string,
  "command": string,
  "rawOutput": string
}

No prose. No markdown.
```

Pass criteria:
- All candidates have `type == "Person"`
- All candidates have non-null `image`
- All `created_at` dates are after 2025-01-01
- `filterUsed` describes the composed filter (should mention `_and`, `_eq`, `_gt`, `_is_null`)
- Query is NOT a direct copy-paste from the sample queries (agent had to compose)

## B1-GQL.6 -- Introspection Escape Hatch

Tests: agent using schema introspection to discover fields not in the sample queries.

```text
Use the intuition skill from this repo.

On Intuition mainnet:
1. Use GraphQL introspection to list all fields available on the "atoms" type
2. Identify at least 3 fields NOT shown in the skill's sample queries
3. Run a query using one of those discovered fields

Return strict JSON:
{
  "endpoint": string,
  "allFields": string[],
  "discoveredFields": string[],
  "exampleQuery": string,
  "exampleResult": object,
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- `allFields` contains the known fields (`term_id`, `label`, `type`, `image`, etc.)
- `discoveredFields` has at least 3 entries NOT in the skill's sample queries
- `exampleQuery` is a valid GraphQL query using one of the discovered fields
- `exampleResult` contains actual data from the API
- Agent used introspection (not guessing)

## B1-GQL.7 -- Discovery to Write Bridge

Tests: the revalidation bridge — discovering an atom via GraphQL, verifying on-chain, then producing an unsigned deposit tx.

```text
Use the intuition skill from this repo.

On Intuition mainnet:
1. Search for atoms with "Ethereum" in their label using GraphQL
2. Pick the first result and extract its term_id
3. Verify the term exists on-chain using isTermCreated(bytes32)
4. Query the default curve ID via getBondingCurveConfig()
5. Preview a deposit of 0.001 TRUST using previewDeposit
6. Produce an unsigned deposit transaction for 0.001 TRUST

Return strict JSON:
{
  "discovery": {
    "source": "graphql",
    "endpoint": string,
    "term_id": string,
    "label": string
  },
  "onChainValidation": {
    "isTermCreated": boolean,
    "curveId": string,
    "previewShares": string
  },
  "transaction": {
    "to": string,
    "data": string,
    "value": string,
    "chainId": string
  },
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- `discovery.source` is `"graphql"`
- `discovery.term_id` starts with `0x` and is bytes32 length
- `onChainValidation.isTermCreated` is `true`
- `onChainValidation.curveId` matches the queried default
- `transaction.to` is the mainnet MultiVault address (`0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e`)
- `transaction.value` equals `1000000000000000` (0.001 TRUST in wei)
- `transaction.chainId` is `"1155"`
- Agent performed both GraphQL query AND on-chain cast calls (bridge)

## B1-GQL.8 -- Safety Invariant (Label Ambiguity)

Tests: term_id canonical identity — multiple atoms can share the same label.

```text
Use the intuition skill from this repo.

On Intuition mainnet, search for all atoms with label containing "Ethereum" using GraphQL.

Demonstrate that label is NOT a unique identifier by finding at least 2 atoms with similar labels but different term_ids.

Return strict JSON:
{
  "endpoint": string,
  "searchTerm": string,
  "totalResults": number,
  "examples": [
    {
      "term_id": string,
      "label": string,
      "type": string
    }
  ],
  "uniqueTermIds": number,
  "uniqueLabels": number,
  "labelIsUnique": boolean,
  "command": string,
  "rawOutput": string
}

No prose. No markdown.
```

Pass criteria:
- `examples` has at least 2 entries with different `term_id` values
- `labelIsUnique` is `false` (or at least `uniqueTermIds > uniqueLabels` showing label collision)
- Agent explicitly acknowledges that `term_id` is the canonical identifier, not label
- All `term_id` values are bytes32 (66 chars starting with `0x`)
