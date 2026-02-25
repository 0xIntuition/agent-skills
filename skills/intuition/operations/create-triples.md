# createTriples

Create one or more triple vaults linking existing atoms. Follow these steps in order.

**Requires:** `$RPC`, `$MULTIVAULT`, `$TRIPLE_COST` from session setup (`reference/reading-state.md`).

**Function:** `createTriples(bytes32[] subjectIds, bytes32[] predicateIds, bytes32[] objectIds, uint256[] assets) payable returns (bytes32[])`

## Step 1: Query Prerequisites

All three atoms (subject, predicate, object) must already exist. Verify each one.

```bash
# Get the bytes32 IDs for each atom
SUBJECT_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" $(cast --from-utf8 "Alice") --rpc-url $RPC)
PREDICATE_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" $(cast --from-utf8 "trusts") --rpc-url $RPC)
OBJECT_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" $(cast --from-utf8 "Bob") --rpc-url $RPC)

# Verify all three exist (must return true)
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $SUBJECT_ID --rpc-url $RPC
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $PREDICATE_ID --rpc-url $RPC
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $OBJECT_ID --rpc-url $RPC

# Get per-triple creation cost (cache this)
TRIPLE_COST=$(cast call $MULTIVAULT "getTripleCost()(uint256)" --rpc-url $RPC)
```

If any atom doesn't exist, create it first using `operations/create-atoms.md`.

## Step 2: Encode the Calldata

### Using cast

```bash
CALLDATA=$(cast calldata "createTriples(bytes32[],bytes32[],bytes32[],uint256[])" \
  "[$SUBJECT_ID]" "[$PREDICATE_ID]" "[$OBJECT_ID]" "[$TRIPLE_COST]")
```

### Using viem

```typescript
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
# Single triple, no extra deposit
VALUE=$TRIPLE_COST  # assets=[$TRIPLE_COST]
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

- All four arrays (subjectIds, predicateIds, objectIds, assets) must be the same length.
- Every triple automatically creates a **counter-triple** vault. Deposit into the counter-triple to signal disagreement.
- Use `getCounterIdFromTripleId(tripleId)` to get the counter-triple's ID for disagreement signaling.
- Triple IDs are deterministic: use `calculateTripleId(subjectId, predicateId, objectId)` to check existence.
- If any referenced atom doesn't exist, the transaction reverts with `MultiVault_TermDoesNotExist(termId)`.
