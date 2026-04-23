# createTriples

Create one or more triple vaults linking existing terms. Follow these steps in order.

**Requires:** `$RPC`, `$MULTIVAULT`, `$TRIPLE_COST` from session setup (`reference/reading-state.md`).

**Function:** `createTriples(bytes32[] subjectIds, bytes32[] predicateIds, bytes32[] objectIds, uint256[] assets) payable returns (bytes32[])`

## Step 1: Query Prerequisites

Each position must already exist as a term. The common case is a canonical atom
(IPFS-pinned or CAIP-10). An existing triple `term_id` is also valid for nested
composition. The example below shows the common atom path; if a position is
already an existing triple term, use that `term_id` directly and skip the
IPFS/`calculateAtomId` step for that position.

```bash
# $SUBJECT_URI, $PREDICATE_URI, $OBJECT_URI come from the pin flow
# (ipfs://bafy... for pinned atoms, caip10:eip155:... for blockchain addresses).
SUBJECT_DATA=$(cast --from-utf8 "$SUBJECT_URI")
PREDICATE_DATA=$(cast --from-utf8 "$PREDICATE_URI")
OBJECT_DATA=$(cast --from-utf8 "$OBJECT_URI")

# Derive each atom's term ID from the exact bytes that were pinned.
SUBJECT_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" "$SUBJECT_DATA" --rpc-url $RPC)
PREDICATE_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" "$PREDICATE_DATA" --rpc-url $RPC)
OBJECT_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" "$OBJECT_DATA" --rpc-url $RPC)

# All three term IDs must exist before the triple can be created (must return true).
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $SUBJECT_ID --rpc-url $RPC
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $PREDICATE_ID --rpc-url $RPC
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $OBJECT_ID --rpc-url $RPC

# Get per-triple creation cost (cache this).
TRIPLE_COST=$(cast call $MULTIVAULT "getTripleCost()(uint256)" --rpc-url $RPC)

# Compute the triple ID and preview the creation using the exact assets value
# you will encode. Fees are governance-configurable; always preview before
# executing so the caller knows expected shares and post-fee assets.
TRIPLE_ID=$(cast call $MULTIVAULT "calculateTripleId(bytes32,bytes32,bytes32)(bytes32)" \
  $SUBJECT_ID $PREDICATE_ID $OBJECT_ID --rpc-url $RPC)
ASSETS_PER_TRIPLE=$TRIPLE_COST  # cost-only creation; add extra wei for an initial deposit
cast call $MULTIVAULT "previewTripleCreate(bytes32,uint256)(uint256,uint256,uint256)" \
  $TRIPLE_ID $ASSETS_PER_TRIPLE --rpc-url $RPC
# Returns (expectedShares, assetsAfterFixedFees, assetsAfterFees)
```

If any atom-backed position doesn't exist yet, create it first using
`operations/create-atoms.md` (which pins via `reference/schemas.md`). Do not
substitute plain-string atoms — those are legacy duplicates, not canonical
entries. If the triple itself already exists, skip creation; a duplicate
creation reverts with `MultiVault_TripleExists`.

## Nested Positions

Nested triples let you make statements about statements (reification) using the
same `bytes32` term IDs you already use for atoms.

- No special encoding is required. If a position is an existing triple, pass its
  `term_id` directly in the `subjectIds`, `predicateIds`, or `objectIds` array.
- `isTermCreated(termId)` is the existence check. If the caller intends to nest
  a positive triple specifically, classify the term before composition.
- `getVaultType(termId)` is the primary classifier:
  `0 = ATOM`, `1 = TRIPLE`, `2 = COUNTER_TRIPLE`.
- `isTriple(termId)` is a coarse check and returns `true` for counter-triples
  too. Do not use it alone when the distinction matters.
- This skill's happy-path examples use atoms and positive triples. If a term ID
  came from an unfamiliar source, classify it before composing.

```bash
# Classify an already-known term before nesting it intentionally.
cast call $MULTIVAULT "getVaultType(bytes32)(uint8)" $SUBJECT_ID --rpc-url $RPC

# Example:
# T1 = (A, P, B)
# T2 = (T1, Q, C)
# Use T1's term_id directly as the subject of T2.
```

## Step 2: Encode the Calldata

### Using cast

```bash
# Use the same assets value previewed in Step 1.
CALLDATA=$(cast calldata "createTriples(bytes32[],bytes32[],bytes32[],uint256[])" \
  "[$SUBJECT_ID]" "[$PREDICATE_ID]" "[$OBJECT_ID]" "[$ASSETS_PER_TRIPLE]")
```

### Using viem

```typescript
// subjectIds, predicateIds, objectIds are bytes32 term IDs. The common case is
// atom IDs derived from pinned metadata, but an existing triple term_id can also
// be reused directly for nested composition.
// Each `assets[i]` must be >= tripleCost.

// Preview each triple creation before encoding — fees are governance-configurable.
const tripleIds = await Promise.all(subjectIds.map((_, i) =>
  client.readContract({
    address: MULTIVAULT, abi: readAbi,
    functionName: 'calculateTripleId',
    args: [subjectIds[i], predicateIds[i], objectIds[i]],
  })
))
const previews = await Promise.all(tripleIds.map((tripleId, i) =>
  client.readContract({
    address: MULTIVAULT, abi: readAbi,
    functionName: 'previewTripleCreate',
    args: [tripleId, assets[i]],
  })
))
// Each preview returns [shares, assetsAfterFixedFees, assetsAfterFees].
// Stop if any preview reverts. Zero shares are expected for cost-only creation;
// stop only when a non-zero initial deposit would still mint zero user shares.
for (const [i, [shares, assetsAfterFixedFees]] of previews.entries()) {
  if (assetsAfterFixedFees > 0n && shares === 0n) {
    throw new Error(`Triple creation preview ${i} mints zero shares from a non-zero initial deposit`)
  }
}

const data = encodeFunctionData({
  abi: parseAbi(['function createTriples(bytes32[] subjectIds, bytes32[] predicateIds, bytes32[] objectIds, uint256[] assets) payable returns (bytes32[])']),
  functionName: 'createTriples',
  args: [subjectIds, predicateIds, objectIds, assets],
})
```

## Step 3: Calculate msg.value

```
msg.value = sum(assets[])
```

Each `assets[i]` is the full per-item payment and must be >= `tripleCost`. The creation cost is deducted from each element; the remainder becomes the initial vault deposit (subject to fees).

```bash
# Single triple, using the same assets value previewed and encoded above
VALUE=$ASSETS_PER_TRIPLE  # assets=[$ASSETS_PER_TRIPLE]
```

## Step 4: Output the Unsigned Transaction JSON

Output one unsigned transaction object with resolved values from this session:

```json
{
  "to": "0x<multivault-address>",
  "data": "0x<calldata>",
  "value": "<msg.value in wei as base-10 string>",
  "chainId": "<chain ID as base-10 string>"
}
```

Set `to` to `$MULTIVAULT`, `value` to the Step 3 result, and `chainId` to `$CHAIN_ID`.

## Important

- For payable semantics, `msg.value` rules, and the output contract, see [Protocol Invariants](../SKILL.md#protocol-invariants).
- Each position must be an existing term. The common case is a canonical atom;
  nested composition may also reuse an existing positive triple term_id.
- Use `getVaultType(termId)` when the caller intends to nest a positive triple
  specifically. `isTriple(termId)` is not enough to distinguish positive
  triples from counter-triples.
- Always call `previewTripleCreate(tripleId, assets[i])` before executing. Cost-only creation can return zero user shares; stop only when a non-zero initial deposit would still mint zero shares.
- All four arrays must stay index-aligned and the same length. Every created triple also creates its counter-triple; use `getCounterIdFromTripleId(tripleId)` when the caller intends to stake against the claim.

## Post-Broadcast Verification

After the wallet layer broadcasts the tx, verify per `reference/post-write-verification.md`:

- Receipt `status = success`.
- Each pre-computed `TRIPLE_ID` returns `true` for `isTermCreated` — the created IDs match the caller's expected `bytes32[]` without parsing logs.
- If a non-zero initial deposit was included, `getShares(creator, tripleId, curveId)` reflects it.
- Event `TripleCreated(creator, termId, subjectId, predicateId, objectId)` is emitted for event-driven consumers (optional).
