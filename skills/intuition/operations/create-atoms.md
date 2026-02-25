# createAtoms

Create one or more atom vaults from URI data. Follow these steps in order.

**Requires:** `$RPC`, `$MULTIVAULT`, `$ATOM_COST` from session setup (`reference/reading-state.md`).

**Function:** `createAtoms(bytes[] atomDatas, uint256[] assets) payable returns (bytes32[])`

## Step 1: Query Prerequisites

Run these queries before encoding. Use values from session setup if already cached.

```bash
# Get per-atom creation cost (cache this)
ATOM_COST=$(cast call $MULTIVAULT "getAtomCost()(uint256)" --rpc-url $RPC)

# Optional: check if atom already exists (skip creation if true)
ATOM_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" $(cast --from-utf8 "Ethereum") --rpc-url $RPC)
EXISTS=$(cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $ATOM_ID --rpc-url $RPC)
```

If the atom already exists, skip creation and use the existing `ATOM_ID`.

## Step 2: Encode the Calldata

Encode each URI as hex bytes, then build the calldata.

### Using cast

```bash
ATOM_DATA=$(cast --from-utf8 "Ethereum")
CALLDATA=$(cast calldata "createAtoms(bytes[],uint256[])" "[$ATOM_DATA]" "[$ATOM_COST]")
```

### Using viem

```typescript
import { encodeFunctionData, parseAbi, stringToHex } from 'viem'

const atomCost = /* result from step 1 */
const uris = ['Ethereum', 'Bitcoin', 'Solana']
const atomDatas = uris.map(u => stringToHex(u))
const assets = [atomCost, atomCost, atomCost] // each element must be >= atomCost

const data = encodeFunctionData({
  abi: parseAbi(['function createAtoms(bytes[] atomDatas, uint256[] assets) payable returns (bytes32[])']),
  functionName: 'createAtoms',
  args: [atomDatas, assets],
})
```

## Step 3: Calculate msg.value

```
msg.value = sum(assets[])
```

Each `assets[i]` is the full per-item payment and must be >= `atomCost`. The creation cost is deducted from each element; the remainder becomes the initial vault deposit (subject to fees).

```bash
# Single atom, no extra deposit
VALUE=$ATOM_COST  # assets=[$ATOM_COST]

# Three atoms, no extra deposit
VALUE=$((ATOM_COST * 3))  # assets=[$ATOM_COST, $ATOM_COST, $ATOM_COST]

# Single atom with extra 0.01 TRUST deposit into vault
EXTRA=$(cast --to-wei 0.01)
VALUE=$((ATOM_COST + EXTRA))  # assets=[$((ATOM_COST + EXTRA))]
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

- Atom IDs are deterministic. Creating an atom that already exists reverts with `MultiVault_AtomExists`. Always check existence with `calculateAtomId` + `isTermCreated` before creating.
- The function returns `bytes32[]` — the atom IDs for each created atom.
- For batch creation, `atomDatas` and `assets` arrays must be the same length.
