# Network Configuration

Canonical source for all Intuition L3 network metadata. All other docs in this
skill should point here rather than restating chain IDs, contract addresses,
RPC URLs, GraphQL endpoints, explorer URLs, or viem chain definitions.

## Network Table

| Network | Chain ID | MultiVault | RPC | GraphQL | Explorer |
|---|---|---|---|---|---|
| Intuition Mainnet | 1155 | `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e` | `https://rpc.intuition.systems/http` | `https://mainnet.intuition.sh/v1/graphql` | `https://explorer.intuition.systems` |
| Intuition Testnet | 13579 | `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91` | `https://testnet.rpc.intuition.systems/http` | `https://testnet.intuition.sh/v1/graphql` | `https://testnet.explorer.intuition.systems` |

## Native Token and Bridge

- Mainnet native token: `$TRUST`
- Testnet native token: `tTRUST`
- Decimals: `18`
- Bridge: `https://app.intuition.systems/bridge`

## Session Environment Variables

Use these values to pin a session before reads or writes.

### Mainnet

```bash
NETWORK="Intuition Mainnet"
CHAIN_ID=1155
RPC="https://rpc.intuition.systems/http"
MULTIVAULT="0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e"
GRAPHQL="https://mainnet.intuition.sh/v1/graphql"
EXPLORER="https://explorer.intuition.systems"
```

### Testnet

```bash
NETWORK="Intuition Testnet"
CHAIN_ID=13579
RPC="https://testnet.rpc.intuition.systems/http"
MULTIVAULT="0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91"
GRAPHQL="https://testnet.intuition.sh/v1/graphql"
EXPLORER="https://testnet.explorer.intuition.systems"
```

## viem Chain Definitions

```typescript
import { defineChain } from 'viem'

export const intuitionMainnet = defineChain({
  id: 1155,
  name: 'Intuition',
  nativeCurrency: { decimals: 18, name: 'Intuition', symbol: 'TRUST' },
  rpcUrls: { default: { http: ['https://rpc.intuition.systems/http'] } },
  blockExplorers: {
    default: { name: 'Intuition Explorer', url: 'https://explorer.intuition.systems' },
  },
})

export const intuitionTestnet = defineChain({
  id: 13579,
  name: 'Intuition Testnet',
  nativeCurrency: { decimals: 18, name: 'Test Trust', symbol: 'tTRUST' },
  rpcUrls: { default: { http: ['https://testnet.rpc.intuition.systems/http'] } },
  blockExplorers: {
    default: { name: 'Intuition Testnet Explorer', url: 'https://testnet.explorer.intuition.systems' },
  },
})
```

## Governance Note

These values are stable operational defaults, but governance can change them.
Verify here before copying network metadata anywhere else in the skill.
