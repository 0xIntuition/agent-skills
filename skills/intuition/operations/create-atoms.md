# createAtoms

Create one or more atom vaults from URI data. Follow these steps in order.

**Requires:** `$RPC`, `$MULTIVAULT`, `$ATOM_COST` from session setup (`reference/reading-state.md`).

**Function:** `createAtoms(bytes[] atomDatas, uint256[] assets) payable returns (bytes32[])`

## Atom Data: Choose Encoding Path

Before encoding, determine how to prepare atom data:

| Atom Content | Preparation | Next Step |
|-------------|-------------|-----------|
| Structured entity (person, org, concept with metadata) | Pin to IPFS first → `reference/schemas.md` | Use returned `ipfs://` URI as atom data |
| Plain string (simple label, tag) | No preparation needed | Use the string directly |
| Ethereum address | No preparation needed | Use the `0x...` address directly |

**Default to the structured path** for any atom representing a real-world entity. The structured path produces rich atoms with name, description, image, and URL metadata in the knowledge graph. Plain strings produce bare atoms with no metadata.

### Structured Atoms (Pin First)

For structured atoms, complete the full pin flow in `reference/schemas.md` before continuing here. The pin flow returns an IPFS URI (`ipfs://bafy...`). Use that URI as the atom data in Step 2 below.

If pinning fails, do not proceed to Step 2. See `reference/schemas.md` → Pin Failure Handling.

## Step 1: Query Prerequisites

Run these queries before encoding. Use values from session setup if already cached.

```bash
# Get per-atom creation cost (cache this)
ATOM_COST=$(cast call $MULTIVAULT "getAtomCost()(uint256)" --rpc-url $RPC)

# Optional: check if atom already exists (skip creation if true)
# Use the exact atom data you will send to createAtoms.
# Structured atom (default): URI returned from reference/schemas.md pin flow
ATOM_DATA=$(cast --from-utf8 "$URI")
# Plain string alternative (use instead of the line above):
# ATOM_DATA=$(cast --from-utf8 "Ethereum")
ATOM_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" "$ATOM_DATA" --rpc-url $RPC)
EXISTS=$(cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $ATOM_ID --rpc-url $RPC)
```

If the atom already exists, skip creation and use the existing `ATOM_ID`.

## Step 2: Encode the Calldata

Encode each URI as hex bytes, then build the calldata.

### Using cast

```bash
# From IPFS URI (structured atom — after pinning via reference/schemas.md)
ATOM_DATA=$(cast --from-utf8 "$URI")  # $URI = "ipfs://bafy..."

# Plain string alternative (simple label; use instead of the line above)
# ATOM_DATA=$(cast --from-utf8 "Ethereum")

CALLDATA=$(cast calldata "createAtoms(bytes[],uint256[])" "[$ATOM_DATA]" "[$ATOM_COST]")
```

### Using viem

```typescript
import { encodeFunctionData, parseAbi, stringToHex } from 'viem'

const atomCost = /* result from step 1 */

// From IPFS URIs (structured atoms — after pinning via reference/schemas.md)
const ipfsUris = ['ipfs://bafy...a', 'ipfs://bafy...b', 'ipfs://bafy...c']
const atomDatas = ipfsUris.map(u => stringToHex(u))

// Or from plain strings (simple labels)
// const labels = ['Ethereum', 'Bitcoin', 'Solana']
// const atomDatas = labels.map(u => stringToHex(u))

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

## Batch Pinning

For batch creation of structured atoms, pin each entity separately, then submit one batched `createAtoms` call. Preserve strict index mapping through the entire flow:

```
entity[0] → pin → uri[0] → atomData[0] → assets[0]
entity[1] → pin → uri[1] → atomData[1] → assets[1]
entity[2] → pin → uri[2] → atomData[2] → assets[2]
```

Before calling `createAtoms`, assert that `atomDatas[]` and `assets[]` are the same length and in the original entity order. If any single pin fails, stop and do not emit a transaction for the batch.

See `reference/schemas.md` → Batch Pinning for the full pattern.

## Important

- Atom IDs are deterministic. Creating an atom that already exists reverts with `MultiVault_AtomExists`. Always check existence with `calculateAtomId` + `isTermCreated` before creating.
- The function returns `bytes32[]` — the atom IDs for each created atom.
- For batch creation, `atomDatas` and `assets` arrays must be the same length.
