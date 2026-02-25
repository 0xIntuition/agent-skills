# deposit

Deposit $TRUST into an existing atom or triple vault, minting shares to the receiver. Follow these steps in order.

**Requires:** `$RPC`, `$MULTIVAULT`, `$CURVE_ID` from session setup (`reference/reading-state.md`).

**Function:** `deposit(address receiver, bytes32 termId, uint256 curveId, uint256 minShares) payable returns (uint256)`

## Step 1: Query Prerequisites

```bash
# Verify the vault exists
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" 0x<termId> --rpc-url $RPC

# Get default curve ID (use cached value if already queried this session)
CURVE_ID=$(cast call $MULTIVAULT "getBondingCurveConfig()((address,uint256))" --rpc-url $RPC | awk -F', ' '{print $2}' | tr -d ')')

# Preview the deposit to see expected shares and fees
cast call $MULTIVAULT "previewDeposit(bytes32,uint256,uint256)(uint256,uint256)" \
  0x<termId> $CURVE_ID $(cast --to-wei 0.01) --rpc-url $RPC
# Returns (expectedShares, assetsAfterFees)
```

## Step 2: Encode the Calldata

### Using cast

```bash
DEPOSIT_WEI=$(cast --to-wei 0.01)
CALLDATA=$(cast calldata "deposit(address,bytes32,uint256,uint256)" \
  0x<receiver> 0x<termId> $CURVE_ID 0)
```

### Using viem

```typescript
const data = encodeFunctionData({
  abi: parseAbi(['function deposit(address receiver, bytes32 termId, uint256 curveId, uint256 minShares) payable returns (uint256)']),
  functionName: 'deposit',
  args: [
    receiverAddress,   // who gets the shares
    termId,            // bytes32 vault ID
    defaultCurveId,    // from getBondingCurveConfig()
    0n,                // minShares (0 = no slippage protection)
  ],
})
```

## Step 3: Calculate msg.value

```
msg.value = deposit amount in wei-units of $TRUST
```

This is the deposit amount itself — the TRUST going into the vault.

```bash
VALUE=$(cast --to-wei 0.01)
```

## Step 4: Output the Unsigned Transaction

```
Transaction: deposit
  To:       $MULTIVAULT
  Data:     0x<calldata>
  Value:    <wei> (<amount> $TRUST)
  Chain ID: $CHAIN_ID
  Network:  $NETWORK

  Deposits <amount> $TRUST into vault <termId>
  Expected shares: <shares> (after fees: <assetsAfterFees>)
```

## Slippage Protection

For production use, set `minShares` from the preview result with a tolerance:

```typescript
const [expectedShares] = await client.readContract({
  address: MULTIVAULT, abi: readAbi,
  functionName: 'previewDeposit',
  args: [termId, curveId, depositAmount],
})
// 5% slippage tolerance
const minShares = expectedShares * 95n / 100n
```

## Important

- The `curveId` must match a configured bonding curve. Query `getBondingCurveConfig()` once per session — the mainnet default is `1`.
- To signal disagreement on a triple, deposit into the counter-triple instead: get its ID via `getCounterIdFromTripleId(tripleId)`.
- The receiver address is who gets the shares — this can differ from the sender. When receiver differs from sender, the receiver must first call `approve(senderAddress, 1)` (1 = DEPOSIT). Enum: 0=NONE, 1=DEPOSIT, 2=REDEMPTION, 3=BOTH.
