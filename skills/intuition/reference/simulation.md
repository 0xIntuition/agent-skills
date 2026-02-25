# Dry Run / Simulation

Always simulate write transactions before executing. Use `cast call` (which executes as a read) with the exact calldata to verify the transaction would succeed without actually broadcasting.

## Simulating with cast

```bash
# Simulate createAtoms -- returns bytes32[] of atom IDs
cast call $MULTIVAULT $CALLDATA --value $VALUE --from 0x<sender> --rpc-url $RPC

# Simulate deposit -- returns shares minted
cast call $MULTIVAULT "deposit(address,bytes32,uint256,uint256)(uint256)" \
  0x<receiver> 0x<termId> $CURVE_ID 0 \
  --value $DEPOSIT_WEI --from 0x<sender> --rpc-url $RPC

# Simulate createTriples -- returns bytes32[] of triple IDs
cast call $MULTIVAULT "createTriples(bytes32[],bytes32[],bytes32[],uint256[])(bytes32[])" \
  "[0x<subjectId>]" "[0x<predicateId>]" "[0x<objectId>]" "[$TRIPLE_COST]" \
  --value $TRIPLE_COST --from 0x<sender> --rpc-url $RPC

# Simulate redeem -- returns assets received
cast call $MULTIVAULT "redeem(address,bytes32,uint256,uint256,uint256)(uint256)" \
  0x<receiver> 0x<termId> $CURVE_ID <shares> 0 \
  --from 0x<sender> --rpc-url $RPC
```

## Simulating with viem

```typescript
const result = await client.simulateContract({
  address: MULTIVAULT,
  abi: writeAbi,
  functionName: 'createAtoms',
  args: [atomDatas, assets],
  value: totalValue,
  account: senderAddress,
})
// result.result contains the return value (bytes32[])
```

## Common Revert Reasons

If the simulation reverts, it will show the revert reason:

- `MultiVault_InsufficientBalance` -- `msg.value` does not equal `sum(assets[])`
- `MultiVault_InsufficientAssets` -- `assets[i]` less than creation cost
- `MultiVault_TermDoesNotExist` -- referenced atom hasn't been created yet
- `MultiVault_AtomExists` -- atom with that data already created; use existing ID
- `MultiVault_TripleExists` -- triple with those components already created; use existing ID
- `MultiVault_ArraysNotSameLength` -- parallel arrays have different lengths

## Verifying Calldata

Round-trip verify generated calldata:

```bash
# Generate calldata
CALLDATA=$(cast calldata "createAtoms(bytes[],uint256[])" "[$ATOM_DATA]" "[$ATOM_COST]")

# Decode it back to verify
cast calldata-decode "createAtoms(bytes[],uint256[])" $CALLDATA
```

If the decoded output matches the intended inputs, the calldata is correct.
