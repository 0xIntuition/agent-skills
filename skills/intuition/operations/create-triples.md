# createTriples

Create one or more triple vaults linking existing atoms. Follow these steps in order.

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
  "[$SUBJECT_ID]" "[$PREDICATE_ID]" "[$OBJECT_ID]" "[0]")
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
msg.value = (tripleCost * count) + sum(assets[])
```

```bash
# Single triple, no extra deposit
VALUE=$TRIPLE_COST
```

## Step 4: Output the Unsigned Transaction

```
Transaction: createTriples
  To:       0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e
  Data:     0x<calldata>
  Value:    <wei> (<amount> $TRUST)
  Chain ID: 1155
  Network:  Intuition Mainnet

  Creates 1 triple(s): (Alice, trusts, Bob)
  Cost breakdown: tripleCost=<wei> per triple, extra deposits=[0]
```

## Important

- All four arrays (subjectIds, predicateIds, objectIds, assets) must be the same length.
- Every triple automatically creates a **counter-triple** vault. Deposit into the counter-triple to signal disagreement.
- Use `getCounterIdFromTripleId(tripleId)` to get the counter-triple's ID for disagreement signaling.
- Triple IDs are deterministic: use `calculateTripleId(subjectId, predicateId, objectId)` to check existence.
- If any referenced atom doesn't exist, the transaction reverts with `AtomDoesNotExist`.
