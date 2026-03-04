# createAtoms

Create one or more atom vaults from URI data. Follow these steps in order.

**Requires:** `$RPC`, `$MULTIVAULT`, `$ATOM_COST` from session setup (`reference/reading-state.md`).

**Function:** `createAtoms(bytes[] atomDatas, uint256[] assets) payable returns (bytes32[])`

## Atom Data: Choose Encoding Path

**All atoms are pinned to IPFS** except blockchain addresses (CAIP-10). This matches the Intuition Portal's creation flow and ensures atoms have rich metadata (name, description, image, URL) in the knowledge graph.

| Atom Content | Preparation | Next Step |
|-------------|-------------|-----------|
| Any entity, concept, predicate, or label (`"Ethereum"`, `"implements"`, `"AI Agent Framework"`, people, orgs, projects) | Pin to IPFS first → `reference/schemas.md` | Use returned `ipfs://` URI in Step 1 |
| Blockchain address (CAIP-10) | Generate URI: `caip10:eip155:{chainId}:{address}` | Step 1 |

Pin everything — including predicates like `"implements"` or `"trusts"`. On-chain data shows canonical predicates are IPFS-pinned atoms (type: Thing), while plain string versions are legacy duplicates with negligible usage (e.g., the pinned `"is"` atom has 429 triples; the plain string `"is"` has 3).

### Pin First (Default Path)

Complete the full pin flow in `reference/schemas.md` before continuing here. The pin flow returns an IPFS URI (`ipfs://bafy...`). Use that URI as the atom data in Step 2 below.

If pinning fails, do not proceed to Step 2. See `reference/schemas.md` → Pin Failure Handling.

### CAIP-10 Addresses (No Pin)

For blockchain addresses, generate a CAIP-10 URI directly — no IPFS pinning needed:

```
caip10:eip155:{chainId}:{address}
```

Example: `caip10:eip155:1:0x1234...abcd`

## Step 1: Query Prerequisites

Run these queries before encoding. Use values from session setup if already cached.

```bash
# Get per-atom creation cost (cache this)
ATOM_COST=$(cast call $MULTIVAULT "getAtomCost()(uint256)" --rpc-url $RPC)

# Optional: check if atom already exists (skip creation if true)
# Use the exact atom data you will send to createAtoms.
# $URI is the IPFS URI from the pin flow, or a CAIP-10 URI for addresses
ATOM_DATA=$(cast --from-utf8 "$URI")
ATOM_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" "$ATOM_DATA" --rpc-url $RPC)
EXISTS=$(cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $ATOM_ID --rpc-url $RPC)
```

If the atom already exists, skip creation and use the existing `ATOM_ID`.

## Step 2: Encode the Calldata

Encode each URI as hex bytes, then build the calldata.

### Using cast

```bash
# $URI = "ipfs://bafy..." (from pin flow) or "caip10:eip155:1:0x..." (address)
ATOM_DATA=$(cast --from-utf8 "$URI")

CALLDATA=$(cast calldata "createAtoms(bytes[],uint256[])" "[$ATOM_DATA]" "[$ATOM_COST]")
```

### Using viem

```typescript
import { encodeFunctionData, parseAbi, stringToHex } from 'viem'

const atomCost = /* result from step 1 */

// From IPFS URIs (after pinning via reference/schemas.md)
// or CAIP-10 URIs for addresses ("caip10:eip155:1:0x...")
const uris = ['ipfs://bafy...a', 'ipfs://bafy...b', 'ipfs://bafy...c']
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
