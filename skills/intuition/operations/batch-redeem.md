# redeemBatch

Redeem shares from multiple vaults in a single transaction. Follow these steps in order.

**Requires:** `$RPC`, `$MULTIVAULT`, `$CURVE_ID` from session setup (`reference/reading-state.md`).

**Function:** `redeemBatch(address receiver, bytes32[] termIds, uint256[] curveIds, uint256[] shares, uint256[] minAssets) returns (uint256[])`

## Step 1: Query Prerequisites

```bash
# Get share balances for each vault
cast call $MULTIVAULT "getShares(address,bytes32,uint256)(uint256)" 0x<userAddr> 0x<termId1> $CURVE_ID --rpc-url $RPC
cast call $MULTIVAULT "getShares(address,bytes32,uint256)(uint256)" 0x<userAddr> 0x<termId2> $CURVE_ID --rpc-url $RPC

# Preview each redemption
cast call $MULTIVAULT "previewRedeem(bytes32,uint256,uint256)(uint256,uint256)" 0x<termId1> $CURVE_ID <shares1> --rpc-url $RPC
cast call $MULTIVAULT "previewRedeem(bytes32,uint256,uint256)(uint256,uint256)" 0x<termId2> $CURVE_ID <shares2> --rpc-url $RPC
```

## Step 2: Encode the Calldata

### Using cast

```bash
SENDER=0x<signer>
RECEIVER=${RECEIVER:-$SENDER}
CALLDATA=$(cast calldata "redeemBatch(address,bytes32[],uint256[],uint256[],uint256[])" \
  $RECEIVER "[0x<termId1>,0x<termId2>]" "[$CURVE_ID,$CURVE_ID]" "[<shares1>,<shares2>]" "[0,0]")
```

### Using viem

```typescript
// Default receiver to signer when not explicitly provided.
const receiver = providedReceiver ?? account.address

const data = encodeFunctionData({
  abi: parseAbi(['function redeemBatch(address receiver, bytes32[] termIds, uint256[] curveIds, uint256[] shares, uint256[] minAssets) returns (uint256[])']),
  functionName: 'redeemBatch',
  args: [receiver, termIds, curveIds, shares, minAssets],
})
```

## Step 3: msg.value

```
msg.value = 0 (non-payable)
```

Redeem returns TRUST to the receiver; it accepts none. Value must be 0.

## Step 4: Output the Unsigned Transaction JSON

Output one unsigned transaction object with resolved values from this session:

```json
{
  "to": "0x<multivault-address>",
  "data": "0x<calldata>",
  "value": "0",
  "chainId": "<chain ID as base-10 string>"
}
```

Set `to` to `$MULTIVAULT` and `chainId` to `$CHAIN_ID`.

## Important

- Receiver defaults to the signer address when not explicitly provided.
- Receiver is always a non-zero EVM address.
- Redeem is non-payable. Value must be 0.
- All arrays (termIds, curveIds, shares, minAssets) must be the same length.
- Exit fees apply to each redemption. Preview each one before executing.
- When the caller redeems on behalf of another account, the share owner must first call `approve(callerAddress, 2)` (2 = REDEMPTION). Enum: 0=NONE, 1=DEPOSIT, 2=REDEMPTION, 3=BOTH.
