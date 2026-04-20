# createTriples

Create one or more triple vaults linking existing atoms. Follow these steps in order.

**Requires:** `$RPC`, `$MULTIVAULT`, `$TRIPLE_COST` from session setup (`reference/reading-state.md`).

**Function:** `createTriples(bytes32[] subjectIds, bytes32[] predicateIds, bytes32[] objectIds, uint256[] assets) payable returns (bytes32[])`

## Step 1: Query Prerequisites

Subject, predicate, and object atoms must already exist as canonical (IPFS-pinned or CAIP-10) atoms. Plain-string atoms are legacy duplicates — do not reference them when encoding new triples. If any of the three atoms does not yet exist, pin and create it first via `reference/schemas.md` and `operations/create-atoms.md`.

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

# All three atoms must exist before the triple can be created (must return true).
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

If any of the three atoms doesn't exist, create it first using `operations/create-atoms.md` (which pins via `reference/schemas.md`). Do not substitute plain-string atoms — those are legacy duplicates, not canonical entries. If the triple itself already exists, skip creation; a duplicate creation reverts with `MultiVault_TripleExists`.

## Step 2: Encode the Calldata

### Using cast

```bash
# Use the same assets value previewed in Step 1.
CALLDATA=$(cast calldata "createTriples(bytes32[],bytes32[],bytes32[],uint256[])" \
  "[$SUBJECT_ID]" "[$PREDICATE_ID]" "[$OBJECT_ID]" "[$ASSETS_PER_TRIPLE]")
```

### Using viem

```typescript
// subjectIds, predicateIds, objectIds are bytes32 IDs derived from pinned atoms
// (via `calculateAtomId` on the hex-encoded IPFS or CAIP-10 URI).
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

- Subject, predicate, and object must be canonical atoms — IPFS-pinned (type `Thing`) or CAIP-10 addresses. Plain-string atoms are legacy duplicates with negligible usage; do not reference them here. If an atom is not yet canonical, pin and create it first via `reference/schemas.md` and `operations/create-atoms.md`.
- Always call `previewTripleCreate(tripleId, assets[i])` before executing. Fees are governance-configurable and may shift between sessions; the preview is the only reliable way to size expected shares and post-fee assets.
- All four arrays (subjectIds, predicateIds, objectIds, assets) must be the same length.
- Every triple automatically creates a **counter-triple** vault. Deposit into the counter-triple to signal disagreement.
- Use `getCounterIdFromTripleId(tripleId)` to get the counter-triple's ID for disagreement signaling.
- Triple IDs are deterministic: use `calculateTripleId(subjectId, predicateId, objectId)` to check existence.
- If any referenced atom doesn't exist, the transaction reverts with `MultiVault_TermDoesNotExist(termId)`.
