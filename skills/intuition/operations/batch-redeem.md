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
# Derive <minAssets1>, <minAssets2> from per-item previewRedeem calls with a
# tolerance — see Slippage Protection below. Do NOT default to [0,0] outside
# of isolated debug runs.
CALLDATA=$(cast calldata "redeemBatch(address,bytes32[],uint256[],uint256[],uint256[])" \
  $RECEIVER "[0x<termId1>,0x<termId2>]" "[$CURVE_ID,$CURVE_ID]" "[<shares1>,<shares2>]" "[<minAssets1>,<minAssets2>]")
```

### Using viem

```typescript
// Default receiver to signer when not explicitly provided.
const receiver = providedReceiver ?? account.address

// `minAssets` MUST be derived per-item from previewRedeem with a tolerance —
// see Slippage Protection below. A zero-filled array provides no protection
// on any item in the batch.
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

## Slippage Protection

Batch redemptions have per-item slippage risk: each `minAssets[i]` bounds only the `i`-th vault in the batch. A zero-filled `minAssets` accepts any output — including zero — on every item, which is unsafe in production.

Always derive per-item bounds from `previewRedeem` with a tolerance:

```bash
# Preview each redemption separately — curves and state differ per term.
EXPECTED_1=$(cast call $MULTIVAULT "previewRedeem(bytes32,uint256,uint256)(uint256,uint256)" \
  0x<termId1> $CURVE_ID <shares1> --rpc-url $RPC | awk 'NR == 1 { print $1 }')
EXPECTED_2=$(cast call $MULTIVAULT "previewRedeem(bytes32,uint256,uint256)(uint256,uint256)" \
  0x<termId2> $CURVE_ID <shares2> --rpc-url $RPC | awk 'NR == 1 { print $1 }')

# 5% slippage tolerance per item.
# Use bc for uint256-sized integer arithmetic; shell arithmetic can overflow.
MIN_1=$(printf '%s * 95 / 100\n' "$EXPECTED_1" | bc)
MIN_2=$(printf '%s * 95 / 100\n' "$EXPECTED_2" | bc)
# Use "[$MIN_1,$MIN_2]" as the minAssets[] argument.
```

```typescript
const previews = await Promise.all(termIds.map((termId, i) =>
  client.readContract({
    address: MULTIVAULT, abi: readAbi,
    functionName: 'previewRedeem',
    args: [termId, curveIds[i], shares[i]],
  })
))
// 5% slippage tolerance per item.
const minAssets = previews.map(([expectedAssets]) => expectedAssets * 95n / 100n)
```

Tolerance (5% here) is an example — pick per deployment based on expected exit-fee variance and indexer staleness. Fees are governance-configurable and can shift between preview and execution.

**Debug-only exception:** `minAssets: [0, 0, ...]` is acceptable when intentionally exercising the batch path in isolated test runs where loss of funds is not a concern. Do not ship this pattern to production callers or reuse it in copy-paste templates.

## Important

- Receiver defaults to the signer address when not explicitly provided.
- Receiver is always a non-zero EVM address.
- Redeem is non-payable. Value must be 0.
- All arrays (termIds, curveIds, shares, minAssets) must be the same length.
- Exit fees apply to each redemption. Always preview each item and derive `minAssets[]` with a tolerance before executing — see Slippage Protection.
- When the caller redeems on behalf of another account, the share owner must first call `approve(callerAddress, 2)` (2 = REDEMPTION). Enum: 0=NONE, 1=DEPOSIT, 2=REDEMPTION, 3=BOTH.

## Post-Broadcast Verification

After the wallet layer broadcasts the tx, verify per `reference/post-write-verification.md`. For each `termIds[i]`:

- Receipt `status = success`.
- `getShares(sender, termIds[i], curveIds[i])` delta equals `shares[i]` (burned amount).
- Per-term assets received satisfy `>= minAssets[i]`; decode each `Redeemed` event for the exact amount.

A non-reverting batch can still land against unexpected state on a subset of terms — iterate every term ID, do not rely on batch-level receipt alone.
