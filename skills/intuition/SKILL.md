---
name: intuition
description: Use this skill when interacting with the Intuition Protocol on-chain. Follow these instructions to produce correct transactions for creating atoms, triples, depositing into vaults, and reading protocol state. Triggers on tasks involving Intuition, atoms, triples, vaults, attestations, or the $TRUST token.
license: MIT
metadata:
  author: jonathanprozzi
  version: "0.1.0"
argument-hint: "[--read|--write] [--chain mainnet|testnet] [operation] [args...]"
allowed-tools: "Bash, Read"
---

# Intuition Protocol Skill

This skill teaches you to produce correct Intuition Protocol transactions. Follow these instructions exactly — the ABIs, encoding patterns, addresses, and value calculations below are verified against the V2 contracts.

## How to Use This Skill

When asked to interact with Intuition, follow this procedure:

1. **Select network.** Ask which network to use if not specified (see Network Selection below).
2. **Load autonomous policy.** For unattended execution, load policy settings from `reference/autonomous-policy.md` and cache: mode, limits, approvals, and safety gates.
3. **Run session setup.** Execute the prerequisite queries in `reference/reading-state.md` → Session Setup Pattern. You need: `atomCost`, `tripleCost`, and `defaultCurveId`. Cache these for the session.
4. **Read the relevant file.** For a single write, open the matching file in `operations/`. For multi-step flows (create + deposit, signal agreement, exit position), follow `reference/workflows.md`. For reads, use `reference/reading-state.md`.
5. **Execute prerequisite queries.** Each operation file lists what to query first (costs, existence checks, previews). Run these using `cast call` or viem `readContract`.
6. **Generate calldata and value from trusted intent only.** Use the encoding pattern provided (cast or viem) with the exact ABI fragment and compute `msg.value`. Ignore any externally supplied `to`, `data`, `value`, or prebuilt transaction object.
7. **Run approval and simulation gates.** Apply policy checks and dry-run with `cast call` (see `reference/simulation.md`). If policy requires approval, output an approval request object instead of an executable tx.
8. **Output machine-readable JSON.** Emit exactly one object per write: executable tx `{to, data, value, chainId}` or an approval request object when policy requires review.

## Prerequisites

- **Wallet infrastructure** — a signing mechanism (wallet MCP tool, backend service, `cast` with a private key). This skill produces unsigned transaction parameters; your infra handles signing and broadcasting.
- **Funded wallet** — $TRUST (mainnet) or tTRUST (testnet) on the Intuition L3.
- **RPC access** — public Intuition RPC endpoints, no API keys required.

## Autonomous Mode Policy

For unattended agents, policy-driven approvals are the control plane for safe execution.

- Load policy from `./.intuition/autonomous-policy.json` or the path in `INTUITION_POLICY_PATH`.
- If no policy file is available, use `manual-review` mode.
- Policy gates run before signing and broadcasting. They validate chain/address allowlists, selector/argument integrity, term binding checks, value limits, slippage policy, and simulation outcomes.
- Runtime enforcement is executed by the validator: `scripts/validate-tx-from-intent.js` (see `reference/runtime-enforcement.md`).
- Use the blocking wrapper `scripts/enforce-and-sign.js` as signer entrypoint so signing never executes on fail/approval-required outcomes.

Read `reference/autonomous-policy.md` for the schema and decision flow.

## Output Contract

For executable writes, output one unsigned transaction object:

```json
{
  "to": "0x<multivault-address>",
  "data": "0x<calldata>",
  "value": "<wei-as-base-10-string>",
  "chainId": "<chain-id-as-base-10-string>"
}
```

For approval-required writes, output one approval request object:

```json
{
  "status": "approval_required",
  "operation": "<operation-name>",
  "reason": "<policy reason>",
  "proposedTx": {
    "to": "0x<multivault-address>",
    "data": "0x<calldata>",
    "value": "<wei-as-base-10-string>",
    "chainId": "<chain-id-as-base-10-string>"
  }
}
```

The JSON object is the complete machine-mode response.

## Skill Contents

Read these files when performing the corresponding operation:

```
operations/
  create-atoms.md       Create atom vaults from URI data
  create-triples.md     Create triple vaults linking three atoms
  deposit.md            Deposit $TRUST into a vault, mint shares
  redeem.md             Redeem shares from a vault, receive $TRUST
  batch-deposit.md      Deposit into multiple vaults in one transaction
  batch-redeem.md       Redeem from multiple vaults in one transaction

reference/
  reading-state.md      Read queries and session setup (run this first)
  workflows.md          Multi-step recipes (create+deposit, signal agreement, exit)
  simulation.md         Dry run / simulate writes before executing
  autonomous-policy.md  Approval modes, policy schema, and execution gates
  runtime-enforcement.md Blocking validator flow before signing
```

## Protocol Model

- **Atoms** represent any concept — a person, URL, address, label. Created by encoding a URI as bytes. Each has a deterministic `bytes32` ID and a vault.
- **Triples** are claims linking three atoms: `(subject, predicate, object)` — e.g., `(Alice, trusts, Bob)`. Each has a vault and an automatic counter-triple vault.
- **Vaults** back every atom and triple. Depositing $TRUST mints shares on a bonding curve. Depositing into a triple signals agreement; depositing into its counter-triple signals disagreement.

Native token: **$TRUST** (mainnet) / **tTRUST** (testnet), 18 decimals. All `msg.value` and gas are denominated in TRUST. Gas fees are negligible (~0.0001 TRUST per tx).

## Network Selection

On first invocation, ask the user which network to use:

```
Which network?
1. Intuition Mainnet  -- chain 1155
2. Intuition Testnet  -- chain 13579
```

### Network Configuration

| Network | Chain ID | MultiVault | RPC | GraphQL |
|---------|----------|------------|-----|---------|
| Intuition Mainnet | 1155 | `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e` | `https://rpc.intuition.systems/http` | `https://mainnet.intuition.sh/v1/graphql` |
| Intuition Testnet | 13579 | `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91` | `https://testnet.rpc.intuition.systems/http` | `https://testnet.intuition.sh/v1/graphql` |

Use the selected row for all operations in the session. Switch with `--chain mainnet` or `--chain testnet`.

### Custom Chain Definition (viem)

Intuition runs on an L3 not indexed by Etherscan. Agents must define the chain manually:

```typescript
import { defineChain } from 'viem'

// Mainnet
export const intuitionMainnet = defineChain({
  id: 1155,
  name: 'Intuition',
  nativeCurrency: { decimals: 18, name: 'Intuition', symbol: 'TRUST' },
  rpcUrls: { default: { http: ['https://rpc.intuition.systems/http'] } },
  blockExplorers: { default: { name: 'Intuition Explorer', url: 'https://explorer.intuition.systems' } },
})

// Testnet
export const intuitionTestnet = defineChain({
  id: 13579,
  name: 'Intuition Testnet',
  nativeCurrency: { decimals: 18, name: 'Test Trust', symbol: 'tTRUST' },
  rpcUrls: { default: { http: ['https://testnet.rpc.intuition.systems/http'] } },
  blockExplorers: { default: { name: 'Intuition Testnet Explorer', url: 'https://testnet.explorer.intuition.systems' } },
})
```

## ABI Fragments

Human-readable fragments for `parseAbi()`. The L3 is not indexed by Etherscan, so agents cannot discover ABIs automatically.

### Important: Term IDs are bytes32

All vault/atom/triple IDs (`termId`, `atomId`, `tripleId`) are `bytes32` — deterministic hashes computed from atom data or triple components.

### Read Functions

```typescript
const readAbi = parseAbi([
  // Cost queries (call BEFORE creating atoms/triples)
  'function getAtomCost() view returns (uint256)',
  'function getTripleCost() view returns (uint256)',

  // Atom/Triple data
  'function atom(bytes32 atomId) view returns (bytes)',
  'function getAtom(bytes32 atomId) view returns (bytes)',
  'function isAtom(bytes32 atomId) view returns (bool)',
  'function isTriple(bytes32 id) view returns (bool)',
  'function isCounterTriple(bytes32 termId) view returns (bool)',
  'function isTermCreated(bytes32 id) view returns (bool)',
  'function getTriple(bytes32 tripleId) view returns (bytes32, bytes32, bytes32)',
  'function triple(bytes32 tripleId) view returns (bytes32, bytes32, bytes32)',
  'function getCounterIdFromTripleId(bytes32 tripleId) pure returns (bytes32)',
  'function getInverseTripleId(bytes32 tripleId) view returns (bytes32)',
  'function getVaultType(bytes32 termId) view returns (uint8)',

  // ID calculation
  'function calculateAtomId(bytes data) pure returns (bytes32)',
  'function calculateTripleId(bytes32 subjectId, bytes32 predicateId, bytes32 objectId) pure returns (bytes32)',
  'function calculateCounterTripleId(bytes32 subjectId, bytes32 predicateId, bytes32 objectId) pure returns (bytes32)',

  // Vault state
  'function getVault(bytes32 termId, uint256 curveId) view returns (uint256 totalAssets, uint256 totalShares)',
  'function getShares(address account, bytes32 termId, uint256 curveId) view returns (uint256)',
  'function maxRedeem(address sender, bytes32 termId, uint256 curveId) view returns (uint256)',
  'function currentSharePrice(bytes32 termId, uint256 curveId) view returns (uint256)',
  'function convertToShares(bytes32 termId, uint256 curveId, uint256 assets) view returns (uint256)',
  'function convertToAssets(bytes32 termId, uint256 curveId, uint256 shares) view returns (uint256)',

  // Preview (simulate before executing)
  'function previewDeposit(bytes32 termId, uint256 curveId, uint256 assets) view returns (uint256 shares, uint256 assetsAfterFees)',
  'function previewRedeem(bytes32 termId, uint256 curveId, uint256 shares) view returns (uint256 assetsAfterFees, uint256 sharesUsed)',
  'function previewAtomCreate(bytes32 termId, uint256 assets) view returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)',
  'function previewTripleCreate(bytes32 termId, uint256 assets) view returns (uint256 shares, uint256 assetsAfterFixedFees, uint256 assetsAfterFees)',

  // Fee queries
  'function protocolFeeAmount(uint256 assets) view returns (uint256)',
  'function entryFeeAmount(uint256 assets) view returns (uint256)',
  'function exitFeeAmount(uint256 assets) view returns (uint256)',
  'function atomDepositFractionAmount(uint256 assets) view returns (uint256)',

  // Config
  'function getGeneralConfig() view returns ((address admin, address protocolMultisig, uint256 feeDenominator, address trustBonding, uint256 minDeposit, uint256 minShare, uint256 atomDataMaxLength, uint256 feeThreshold))',
  'function getAtomConfig() view returns ((uint256 atomCreationProtocolFee, uint256 atomWalletDepositFee))',
  'function getTripleConfig() view returns ((uint256 tripleCreationProtocolFee, uint256 atomDepositFractionForTriple))',
  'function getBondingCurveConfig() view returns ((address registry, uint256 defaultCurveId))',
  'function getVaultFees() view returns ((uint256 entryFee, uint256 exitFee, uint256 protocolFee))',
])
```

### Write Functions

```typescript
const writeAbi = parseAbi([
  // Atom creation (batch only)
  'function createAtoms(bytes[] atomDatas, uint256[] assets) payable returns (bytes32[])',

  // Triple creation (batch only)
  'function createTriples(bytes32[] subjectIds, bytes32[] predicateIds, bytes32[] objectIds, uint256[] assets) payable returns (bytes32[])',

  // Single deposit/redeem
  'function deposit(address receiver, bytes32 termId, uint256 curveId, uint256 minShares) payable returns (uint256)',
  'function redeem(address receiver, bytes32 termId, uint256 curveId, uint256 shares, uint256 minAssets) returns (uint256)',

  // Batch deposit/redeem
  'function depositBatch(address receiver, bytes32[] termIds, uint256[] curveIds, uint256[] assets, uint256[] minShares) payable returns (uint256[])',
  'function redeemBatch(address receiver, bytes32[] termIds, uint256[] curveIds, uint256[] shares, uint256[] minAssets) returns (uint256[])',

  // Approvals
  'function approve(address sender, uint8 approvalType)',

  // Atom wallet
  'function computeAtomWalletAddr(bytes32 atomId) view returns (address)',
  'function claimAtomWalletDepositFees(bytes32 atomId)',
])
```

## Core Concepts

### Atoms: URI to bytes Encoding

Atoms are created from arbitrary bytes. For string-based URIs:

```typescript
import { stringToHex } from 'viem'
const atomData = stringToHex('https://ethereum.org')
// Or for plain text:
const atomData = stringToHex('Ethereum')
```

```bash
# cast equivalent
ATOM_DATA=$(cast --from-utf8 "Ethereum")
```

The atom's `bytes32` ID is deterministically computed from its data via `calculateAtomId(bytes)`. Creating an atom that already exists reverts with `MultiVault_AtomExists`. Always check `isTermCreated(calculateAtomId(data))` before calling `createAtoms`.

### Triples: Three Atom IDs

A triple links three existing atoms: `(subject, predicate, object)`. All three must be created first. Every triple automatically gets a **counter-triple** vault for signaling disagreement.

**Known predicate and object atom IDs** (deterministic — recomputable via `calculateAtomId(stringToHex(label))`):

| Label | Atom ID |
|-------|---------|
| `is` | `0xb0681668ca193e8608b43adea19fecbbe0828ef5afc941cef257d30a20564ef1` |
| `AI Agent` | `0x4990eef19ea1d9b893c1802af9e2ec37fbc1ae138868959ebc23c98b1fc9565e` |
| `collaboratesWith` | `0xb3cf9e60665fe7674e3798d2452604431d4d4dc96aa8d6965016205d00e45c8e` |
| `participatesIn` | `0x2952108d352c2ffe1b89b208c4f078165c83c3ac995c3d6d1f41b18a19ce2f23` |

You can create new predicates by creating a string atom (e.g., `"trusts"`, `"recommends"`).

### Vaults: Shares Model

Every atom and triple has a vault. Depositing $TRUST mints shares on a bonding curve. The `curveId` parameter selects which curve to use.

**Always query the default curve ID first:**
```bash
cast call $MULTIVAULT "getBondingCurveConfig()((address,uint256))" --rpc-url $RPC
# Returns (registryAddress, defaultCurveId) -- use the second value
```

On mainnet the default is currently `1` (linear curve). Query `getBondingCurveConfig()` once per session and reuse the `defaultCurveId` for all deposit/redeem calls.

### Fees: Always Preview First

Multiple fee layers apply to deposits: protocol fee, entry fee, atom wallet deposit fee (for atoms), and atom deposit fraction (for triples). **Always call `previewDeposit` or `previewAtomCreate`/`previewTripleCreate` before executing.** Fee percentages are configurable by governance and may change.

### Assets Array in Creation

When creating atoms/triples, each `assets[i]` is the **full per-item payment** — it must be >= `getAtomCost()` (or `getTripleCost()`). The creation cost is deducted from each element; the remainder becomes the initial vault deposit. `msg.value` must exactly equal `sum(assets[])`. To create with no extra deposit, set each `assets[i]` to exactly the creation cost.

## Write Operations

To perform a write, open the corresponding operation file and follow its steps exactly. Each file provides: prerequisites to query, encoding pattern (cast + viem), value calculation, and strict JSON output contract.

| When you need to... | Read this file | Payable |
|---------------------|----------------|---------|
| Create atoms from URIs | `operations/create-atoms.md` | Yes — `msg.value = sum(assets[])`, each `assets[i] >= atomCost` |
| Create triples linking atoms | `operations/create-triples.md` | Yes — `msg.value = sum(assets[])`, each `assets[i] >= tripleCost` |
| Deposit $TRUST into a vault | `operations/deposit.md` | Yes — `msg.value = deposit amount` |
| Redeem shares from a vault | `operations/redeem.md` | No — `value = 0` |
| Deposit into multiple vaults | `operations/batch-deposit.md` | Yes — `msg.value = sum(assets)` |
| Redeem from multiple vaults | `operations/batch-redeem.md` | No — `value = 0` |

For read queries, follow `reference/reading-state.md`.
For multi-step flows (create + deposit, signal disagreement, exit position), follow `reference/workflows.md`.
Always simulate writes before executing — see `reference/simulation.md`.

## Protocol Invariants

These facts govern all Intuition transactions. Reference them when encoding operations.

1. **Term IDs are bytes32** -- All vault, atom, and triple IDs are `bytes32` — deterministic hashes computed from atom data or triple components.

2. **Creation is batch-only** -- Use `createAtoms()` and `createTriples()` with arrays. Single-item creation uses single-element arrays.

3. **curveId is required** -- `deposit` and `redeem` require a `curveId` parameter. Query `getBondingCurveConfig()` once per session. The mainnet default is `1` (linear curve).

4. **Slippage parameters** -- `deposit` accepts `minShares`, `redeem` accepts `minAssets`. Use `previewDeposit`/`previewRedeem` to calculate these. Set to `0` to skip protection.

5. **Atom data is hex-encoded bytes** -- Use `stringToHex('Ethereum')` in viem, `cast --from-utf8 "Ethereum"` in foundry.

6. **msg.value is a separate transaction field** -- The $TRUST sent with the transaction is the `value` field, separate from the encoded `data`.

7. **Payable functions** -- `createAtoms`, `createTriples`, `deposit`, `depositBatch` require $TRUST as `msg.value`. `redeem` and `redeemBatch` are non-payable (`value = 0`).

8. **Creation assets[] is the full payment** -- Each `assets[i]` must be >= creation cost. `msg.value` must exactly equal `sum(assets[])`. The creation cost is deducted per item; the remainder deposits into the vault.

9. **Custom chain definition required** -- Intuition L3 (chain 1155/13579) requires `defineChain()` in viem. See Custom Chain Definition above.

10. **Creation returns bytes32[]** -- `createAtoms` and `createTriples` return `bytes32[]` — hashes of the input data.

11. **Counter-triples are automatic** -- Creating a triple also creates its counter-triple vault. Deposit into the counter-triple to signal disagreement.

12. **Separate preview functions for creation and deposit** -- Use `previewAtomCreate`/`previewTripleCreate` when creating. Use `previewDeposit` for existing vaults. Fee calculations differ.

## Error Patterns

| Error | Cause | Fix |
|-------|-------|-----|
| `MultiVault_InsufficientBalance` | `msg.value` does not equal `sum(assets[])` | Ensure `msg.value` exactly equals the sum of the assets array |
| `MultiVault_InsufficientAssets` | `assets[i]` less than creation cost | Each `assets[i]` must be >= `getAtomCost()` or `getTripleCost()` |
| `MultiVault_AtomExists` | Atom with same data already created | Check `isTermCreated(calculateAtomId(data))` first; use existing ID |
| `MultiVault_TripleExists` | Triple with same components already created | Check `isTermCreated(calculateTripleId(...))` first; use existing ID |
| `MultiVault_TermDoesNotExist` | Referenced atom in triple not created | Create the atom first via `createAtoms` |
| `MultiVault_ArraysNotSameLength` | Parallel arrays have different lengths | Ensure all arrays match in length |
| `MultiVault_InvalidArrayLength` | Empty array or exceeds max batch size | Provide at least one item; check max batch size |
| Transaction reverts with no message | ABI encoding mismatch or unrecognized function sig | Verify bytes32 IDs, check curveId parameter |

## TRUST Token

| | Mainnet | Testnet |
|---|---|---|
| Symbol | $TRUST | tTRUST |
| Decimals | 18 | 18 |

`parseEther('0.5')` works for formatting TRUST amounts (same 18-decimal math). The unit is TRUST, not ETH.

## Contract Source

- **V2 contracts:** https://github.com/0xIntuition/intuition-v2/tree/main/contracts/core
- **Interface:** `src/interfaces/IMultiVault.sol` and `src/interfaces/IMultiVaultCore.sol`
- **Block explorer (mainnet):** https://intuition.calderaexplorer.xyz
- **SDK (reference):** https://github.com/0xIntuition/intuition-ts
