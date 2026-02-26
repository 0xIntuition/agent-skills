# Reading State

Run these queries to look up costs, previews, vault state, and existence checks. All reads are free (no gas, no $TRUST).

**Run the Session Setup Pattern first** before any operation — it caches the values you'll need throughout the session.

## Using cast

```bash
RPC="https://rpc.intuition.systems/http"
MULTIVAULT="0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e"

# Get atom creation cost
cast call $MULTIVAULT "getAtomCost()(uint256)" --rpc-url $RPC

# Get triple creation cost
cast call $MULTIVAULT "getTripleCost()(uint256)" --rpc-url $RPC

# Calculate atom ID from data
cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" $(cast --from-utf8 "Ethereum") --rpc-url $RPC

# Check if a term exists
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" 0x<termId> --rpc-url $RPC

# Query default curve ID (do this once per session)
CURVE_ID=$(cast call $MULTIVAULT "getBondingCurveConfig()((address,uint256))" --rpc-url $RPC | awk -F', ' '{print $2}' | tr -d ')')
# On mainnet this returns 1; always query this value

# Get vault state (totalAssets, totalShares)
cast call $MULTIVAULT "getVault(bytes32,uint256)(uint256,uint256)" 0x<termId> $CURVE_ID --rpc-url $RPC

# Get current share price
cast call $MULTIVAULT "currentSharePrice(bytes32,uint256)(uint256)" 0x<termId> $CURVE_ID --rpc-url $RPC

# Preview a deposit
cast call $MULTIVAULT "previewDeposit(bytes32,uint256,uint256)(uint256,uint256)" 0x<termId> $CURVE_ID 1000000000000000 --rpc-url $RPC

# Get user's shares
cast call $MULTIVAULT "getShares(address,bytes32,uint256)(uint256)" 0x<userAddr> 0x<termId> $CURVE_ID --rpc-url $RPC

# Get default bonding curve config
cast call $MULTIVAULT "getBondingCurveConfig()((address,uint256))" --rpc-url $RPC

# Get a triple's components (subject, predicate, object)
cast call $MULTIVAULT "getTriple(bytes32)(bytes32,bytes32,bytes32)" 0x<tripleId> --rpc-url $RPC

# Get counter-triple ID
cast call $MULTIVAULT "getCounterIdFromTripleId(bytes32)(bytes32)" 0x<tripleId> --rpc-url $RPC

# Get atom data (returns raw bytes)
cast call $MULTIVAULT "getAtom(bytes32)(bytes)" 0x<atomId> --rpc-url $RPC
```

## Using viem

```typescript
import { createPublicClient, http } from 'viem'

const client = createPublicClient({
  chain: intuitionMainnet, // defined in SKILL.md
  transport: http(),
})

const MULTIVAULT = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'

// Cost queries
const atomCost = await client.readContract({
  address: MULTIVAULT,
  abi: readAbi,
  functionName: 'getAtomCost',
})

const tripleCost = await client.readContract({
  address: MULTIVAULT,
  abi: readAbi,
  functionName: 'getTripleCost',
})

// Calculate atom ID
const atomId = await client.readContract({
  address: MULTIVAULT,
  abi: readAbi,
  functionName: 'calculateAtomId',
  args: [stringToHex('Ethereum')],
})

// Check existence
const exists = await client.readContract({
  address: MULTIVAULT,
  abi: readAbi,
  functionName: 'isTermCreated',
  args: [atomId],
})

// Get bonding curve config (do once per session)
const [registry, defaultCurveId] = await client.readContract({
  address: MULTIVAULT,
  abi: readAbi,
  functionName: 'getBondingCurveConfig',
})

// Preview a deposit
const [expectedShares, assetsAfterFees] = await client.readContract({
  address: MULTIVAULT,
  abi: readAbi,
  functionName: 'previewDeposit',
  args: [termId, defaultCurveId, depositAmount],
})

// Get user's shares
const shares = await client.readContract({
  address: MULTIVAULT,
  abi: readAbi,
  functionName: 'getShares',
  args: [userAddress, termId, defaultCurveId],
})

// Get vault state
const [totalAssets, totalShares] = await client.readContract({
  address: MULTIVAULT,
  abi: readAbi,
  functionName: 'getVault',
  args: [termId, defaultCurveId],
})
```

## Session Setup Pattern

**Run this at the start of any session involving Intuition operations.** These values are stable within a session — query once and reuse everywhere.

### Using cast

```bash
# Set network constants from SKILL.md Network Configuration table
# Mainnet shown — substitute testnet values if user selected testnet
RPC="https://rpc.intuition.systems/http"
MULTIVAULT="0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e"
GRAPHQL="https://mainnet.intuition.sh/v1/graphql"
CHAIN_ID=1155
NETWORK="Intuition Mainnet"

# 1. Get creation costs
ATOM_COST=$(cast call $MULTIVAULT "getAtomCost()(uint256)" --rpc-url $RPC)
TRIPLE_COST=$(cast call $MULTIVAULT "getTripleCost()(uint256)" --rpc-url $RPC)

# 2. Get default curve ID (always query — value is governance-configurable)
CURVE_ID=$(cast call $MULTIVAULT "getBondingCurveConfig()((address,uint256))" --rpc-url $RPC | awk -F', ' '{print $2}' | tr -d ')')

# 3. Get fee config (optional, for detailed calculations)
cast call $MULTIVAULT "getVaultFees()((uint256,uint256,uint256))" --rpc-url $RPC
```

### Using viem

```typescript
const MULTIVAULT = '0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e'

const atomCost = await client.readContract({ address: MULTIVAULT, abi: readAbi, functionName: 'getAtomCost' })
const tripleCost = await client.readContract({ address: MULTIVAULT, abi: readAbi, functionName: 'getTripleCost' })
const [registry, defaultCurveId] = await client.readContract({ address: MULTIVAULT, abi: readAbi, functionName: 'getBondingCurveConfig' })
```

You now have `atomCost`, `tripleCost`, `defaultCurveId`, `$GRAPHQL`, `$CHAIN_ID`, and `$NETWORK`. Use these in all subsequent operations — including the Step 4 JSON output contract in each operation file and GraphQL queries in `reference/graphql-queries.md`.
