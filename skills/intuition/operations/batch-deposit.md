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
# Derive <minShares1>, <minShares2> from per-item previewDeposit calls with a
# tolerance — see Slippage Protection below. Do NOT default to [0,0] outside
# of isolated debug runs.
CALLDATA=$(cast calldata "depositBatch(address,bytes32[],uint256[],uint256[],uint256[])" \
  $RECEIVER "[0x<termId1>,0x<termId2>]" "[$CURVE_ID,$CURVE_ID]" "[1000000000000000,2000000000000000]" "[<minShares1>,<minShares2>]")
```

### Using viem

```typescript
// Default receiver to signer when not explicitly provided.
const receiver = providedReceiver ?? account.address

// `minShares` MUST be derived per-item from previewDeposit with a tolerance —
// see Slippage Protection below. A zero-filled array provides no protection
// on any item in the batch.
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

## Slippage Protection

Batch deposits have per-item slippage risk: each `minShares[i]` bounds only the `i`-th vault in the batch. A zero-filled `minShares` accepts any output — including zero — on every item, which is unsafe in production.

Always derive per-item bounds from `previewDeposit` with a tolerance:

```bash
# Preview each vault separately — curves and state differ per term.
EXPECTED_1=$(cast call $MULTIVAULT "previewDeposit(bytes32,uint256,uint256)(uint256,uint256)" \
  0x<termId1> $CURVE_ID 1000000000000000 --rpc-url $RPC | awk 'NR == 1 { print $1 }')
EXPECTED_2=$(cast call $MULTIVAULT "previewDeposit(bytes32,uint256,uint256)(uint256,uint256)" \
  0x<termId2> $CURVE_ID 2000000000000000 --rpc-url $RPC | awk 'NR == 1 { print $1 }')

# 5% slippage tolerance per item.
# Use bc for uint256-sized integer arithmetic; shell arithmetic can overflow.
MIN_1=$(printf '%s * 95 / 100\n' "$EXPECTED_1" | bc)
MIN_2=$(printf '%s * 95 / 100\n' "$EXPECTED_2" | bc)
# Use "[$MIN_1,$MIN_2]" as the minShares[] argument.
```

```typescript
const previews = await Promise.all(termIds.map((termId, i) =>
  client.readContract({
    address: MULTIVAULT, abi: readAbi,
    functionName: 'previewDeposit',
    args: [termId, curveIds[i], assets[i]],
  })
))
// 5% slippage tolerance per item.
const minShares = previews.map(([expectedShares]) => expectedShares * 95n / 100n)
```

Tolerance (5% here) is an example — pick per deployment based on expected fee variance and indexer staleness. Fees are governance-configurable and can shift between preview and execution.

**Debug-only exception:** `minShares: [0, 0, ...]` is acceptable when intentionally exercising the batch path in isolated test runs where loss of funds is not a concern. Do not ship this pattern to production callers or reuse it in copy-paste templates.

## Important

- For receiver defaults, payable semantics, and the output contract, see [Protocol Invariants](../SKILL.md#protocol-invariants).
- All arrays must stay index-aligned and the same length, and `msg.value` must equal `sum(assets[])` exactly.
- Check `getGeneralConfig().minDeposit` for each item, then derive every `minShares[i]` from `previewDeposit` with a tolerance. A zero-filled `minShares[]` is debug-only. See [reference/config-fields.md](../reference/config-fields.md).
- When receiver differs from sender, the receiver must first grant the sender `DEPOSIT` approval via `operations/approve.md` (`approve(senderAddress, 1)`; enum: 0=NONE, 1=DEPOSIT, 2=REDEMPTION, 3=BOTH). One approval covers every `termId` in the batch, but that approval tx must mine before this batch deposit broadcasts.

## Post-Broadcast Verification

After the wallet layer broadcasts the tx, verify per `reference/post-write-verification.md`. For each `termIds[i]`:

- Receipt `status = success`.
- `getShares(receiver, termIds[i], curveIds[i])` delta satisfies `delta >= minShares[i]`.
- One `Deposited` event is emitted per term for event-driven consumers.

A non-reverting batch can still land against unexpected state on a subset of terms — iterate every term ID, do not rely on batch-level receipt alone.
