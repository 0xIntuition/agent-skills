# Nested Triples

Nested triples are triples whose subject, predicate, or object is itself
another triple's `term_id`. This is reification: making a statement about an
existing statement. The write path is still `createTriples(...)`; see
`operations/create-triples.md` for the exact calldata flow.

## What This Skill Documents

This skill's happy path documents two composition inputs:

- canonical atoms
- existing positive triple terms

Counter-triples are part of the protocol surface and show up in contract and
GraphQL type reads, but this Phase 1 doc does not teach them as a supported
composition example path. If a term came from an unfamiliar source, classify it
before reusing it.

## Classification Rules

Use these reads in order of precision:

- `getVaultType(termId)` is the primary classifier:
  `0 = ATOM`, `1 = TRIPLE`, `2 = COUNTER_TRIPLE`
- `isTriple(termId)` is a coarse check and returns `true` for
  counter-triples too
- `isCounterTriple(termId)` is a direct boolean helper when you only need to
  detect the counter side

If the caller intends to nest a positive statement specifically, require
`getVaultType(termId) == TRIPLE` (`1`).

## Composition Pattern

Nested composition uses the same `bytes32` term IDs as every other skill path:

1. Discover or already know the base triple `term_id`
2. Classify it with `getVaultType` when provenance is unclear
3. Resolve the other positions as usual
4. Call `createTriples([subjectId], [predicateId], [objectId], [assets])`

No special encoding is required for the nested position. If `T1` is already a
triple term, pass `T1` directly into the chosen position array.

## Concrete Example

One canonical pattern is provenance:

```text
T1 = (Alice, trusts, Bob)
T2 = (T1, assertedBy, SourceDoc)
```

In `T2`, the subject is not a new atom. It is the existing `term_id` of `T1`.
That lets the graph represent a statement about a prior statement without
flattening or paraphrasing it into a new string atom.

## Reading and Rendering Implications

GraphQL has two relevant access patterns on triples:

- `subject` / `predicate` / `object`
  These are legacy atom-only relationships. They return `NULL` when that
  position is itself a triple.
- `subject_term` / `predicate_term` / `object_term`
  These are term-aware relationships. Use them for nested-safe rendering.

The `terms` table is also polymorphic. Its `type` surface may be `Atom`,
`Triple`, or `CounterTriple`. When the goal is to discover reusable positive
statement terms, filter explicitly to `type: { _eq: Triple }`.

## Common Pitfalls

- Treating `isTriple(termId)` as a positive-triple-only check.
  It is not. Use `getVaultType` when the distinction matters.
- Using `subject { label }`-style queries in nested contexts.
  They can return `NULL` for triple-valued positions.
- Assuming every useful position needs fresh atom pinning.
  Nested composition reuses an existing triple `term_id` directly.
- Forgetting the GraphQL/on-chain bridge.
  GraphQL is the discovery layer; revalidate selected `term_id`s on-chain before
  building a write.

## Related References

- `operations/create-triples.md`
- `reference/reading-state.md`
- `reference/graphql-queries.md`
- `reference/post-write-verification.md`
