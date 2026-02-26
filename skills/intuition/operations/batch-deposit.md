# depositBatch

Deposit into multiple vaults in a single transaction. Follow these steps in order.

**Requires:** `$RPC`, `$MULTIVAULT`, `$CURVE_ID` from session setup (`reference/reading-state.md`).

**Function:** `depositBatch(address receiver, bytes32[] termIds, uint256[] curveIds, uint256[] assets, uint256[] minShares) payable returns (uint256[])`

## Step 1: Query Prerequisites

```bash
# Verify all vaults exist
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" 0x<termId1> --rpc-url $RPC
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" 0x<termId2> --rpc-url $RPC

# Get default curve ID (use cached value if already queried)
CURVE_ID=$(cast call $MULTIVAULT "getBondingCurveConfig()((address,uint256))" --rpc-url $RPC | awk -F', ' '{print $2}' | tr -d ')')

# Preview each deposit
cast call $MULTIVAULT "previewDeposit(bytes32,uint256,uint256)(uint256,uint256)" 0x<termId1> $CURVE_ID <amount1> --rpc-url $RPC
cast call $MULTIVAULT "previewDeposit(bytes32,uint256,uint256)(uint256,uint256)" 0x<termId2> $CURVE_ID <amount2> --rpc-url $RPC
```

## Step 2: Encode the Calldata

### Using cast

```bash
SENDER=0x<signer>
RECEIVER=${RECEIVER:-$SENDER}
CALLDATA=$(cast calldata "depositBatch(address,bytes32[],uint256[],uint256[],uint256[])" \
  $RECEIVER "[0x<termId1>,0x<termId2>]" "[$CURVE_ID,$CURVE_ID]" "[1000000000000000,2000000000000000]" "[0,0]")
```

### Using viem

```typescript
// Default receiver to signer when not explicitly provided.
const receiver = providedReceiver ?? account.address

const data = encodeFunctionData({
  abi: parseAbi(['function depositBatch(address receiver, bytes32[] termIds, uint256[] curveIds, uint256[] assets, uint256[] minShares) payable returns (uint256[])']),
  functionName: 'depositBatch',
  args: [receiver, termIds, curveIds, assets, minShares],
})
```

## Step 3: Calculate msg.value

```
msg.value = sum(assets[])
```

```bash
TOTAL_VALUE=$((1000000000000000 + 2000000000000000))
```

```typescript
const value = assets.reduce((sum, a) => sum + a, 0n)
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

- Receiver defaults to the signer address when not explicitly provided.
- Receiver is always a non-zero EVM address.
- All arrays (termIds, curveIds, assets, minShares) must be the same length.
- Each `curveIds` element can differ, but typically they're all the same `defaultCurveId`.
- Total `msg.value` must equal the sum of the `assets` array exactly.
- When receiver differs from sender, the receiver must first call `approve(senderAddress, 1)` (1 = DEPOSIT). Enum: 0=NONE, 1=DEPOSIT, 2=REDEMPTION, 3=BOTH.
