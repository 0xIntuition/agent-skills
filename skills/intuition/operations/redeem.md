# redeem

Redeem shares from a vault, receiving $TRUST back. Follow these steps in order.

**Requires:** `$RPC`, `$MULTIVAULT`, `$CURVE_ID` from session setup (`reference/reading-state.md`).

**Function:** `redeem(address receiver, bytes32 termId, uint256 curveId, uint256 shares, uint256 minAssets) returns (uint256)`

## Step 1: Query Prerequisites

```bash
# Get user's share balance
SHARES=$(cast call $MULTIVAULT "getShares(address,bytes32,uint256)(uint256)" \
  0x<userAddr> 0x<termId> $CURVE_ID --rpc-url $RPC)

# Or get maximum redeemable shares
MAX_SHARES=$(cast call $MULTIVAULT "maxRedeem(address,bytes32,uint256)(uint256)" \
  0x<userAddr> 0x<termId> $CURVE_ID --rpc-url $RPC)

# Preview the redemption
cast call $MULTIVAULT "previewRedeem(bytes32,uint256,uint256)(uint256,uint256)" \
  0x<termId> $CURVE_ID $SHARES --rpc-url $RPC
# Returns (assetsAfterFees, sharesUsed)
```

## Step 2: Encode the Calldata

### Using cast

```bash
CALLDATA=$(cast calldata "redeem(address,bytes32,uint256,uint256,uint256)" \
  0x<receiver> 0x<termId> $CURVE_ID $SHARES 0)
```

### Using viem

```typescript
const data = encodeFunctionData({
  abi: parseAbi(['function redeem(address receiver, bytes32 termId, uint256 curveId, uint256 shares, uint256 minAssets) returns (uint256)']),
  functionName: 'redeem',
  args: [
    receiverAddress,   // who gets the $TRUST
    termId,            // bytes32 vault ID
    defaultCurveId,    // from getBondingCurveConfig()
    sharesToRedeem,    // number of shares to burn
    0n,                // minAssets (0 = no slippage protection)
  ],
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

## Slippage Protection

```typescript
const [expectedAssets] = await client.readContract({
  address: MULTIVAULT, abi: readAbi,
  functionName: 'previewRedeem',
  args: [termId, curveId, sharesToRedeem],
})
// 5% slippage tolerance
const minAssets = expectedAssets * 95n / 100n
```

## Important

- Redeem is non-payable. Value must be 0.
- Use `maxRedeem(address, termId, curveId)` to get the maximum redeemable shares.
- Exit fees apply. Always preview before executing.
- When the caller redeems on behalf of another account, the share owner must first call `approve(callerAddress, 2)` (2 = REDEMPTION). Enum: 0=NONE, 1=DEPOSIT, 2=REDEMPTION, 3=BOTH.
