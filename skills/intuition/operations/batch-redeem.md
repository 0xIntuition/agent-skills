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
CALLDATA=$(cast calldata "redeemBatch(address,bytes32[],uint256[],uint256[],uint256[])" \
  0x<receiver> "[0x<termId1>,0x<termId2>]" "[$CURVE_ID,$CURVE_ID]" "[<shares1>,<shares2>]" "[0,0]")
```

### Using viem

```typescript
const data = encodeFunctionData({
  abi: parseAbi(['function redeemBatch(address receiver, bytes32[] termIds, uint256[] curveIds, uint256[] shares, uint256[] minAssets) returns (uint256[])']),
  functionName: 'redeemBatch',
  args: [receiverAddress, termIds, curveIds, shares, minAssets],
})
```

## Step 3: msg.value

```
msg.value = 0 (non-payable)
```

Redeem returns TRUST to the receiver; it accepts none. Value must be 0.

## Step 4: Output the Unsigned Transaction

```
Transaction: redeemBatch
  To:       0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e
  Data:     0x<calldata>
  Value:    0
  Chain ID: 1155
  Network:  Intuition Mainnet

  Redeems from <count> vaults: [<termId1>, <termId2>]
  Shares: [<shares1>, <shares2>]
```

## Important

- Redeem is non-payable. Value must be 0.
- All arrays (termIds, curveIds, shares, minAssets) must be the same length.
- Exit fees apply to each redemption. Preview each one before executing.
