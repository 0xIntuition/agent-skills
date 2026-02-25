# Intuition Skill

Canonical reference for autonomous agents (Claude, Codex, etc.) to correctly interact with the [Intuition Protocol](https://intuition.systems) on-chain. Ensures correct ABIs, encoding patterns, addresses, and value calculations for atoms, triples, and vaults.

## What It Does

This skill teaches agents to produce **correct Intuition transactions** -- the right calldata, the right msg.value, the right chain. Wallet management and signing are the builder's responsibility.

The agent produces unsigned transaction parameters:

```
Transaction: createAtoms
  To:       0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e
  Data:     0x<calldata>
  Value:    <wei> (<amount> $TRUST)
  Chain ID: 1155
```

The builder's signing infrastructure handles the rest.

## Prerequisites

- **Wallet / signing infra** -- the skill produces unsigned tx params. You bring the signing mechanism (wallet MCP tool, backend service, `cast` with a key, etc.)
- **Funded wallet** -- $TRUST (mainnet) or tTRUST (testnet) on the Intuition L3. Acquire on Base, bridge via https://app.intuition.systems/bridge
- **RPC access** -- public endpoints, no API keys needed

## Installation

```bash
npx skills add 0xintuition/agent-skills --skill intuition
```

Or install all Intuition skills:

```bash
npx skills add 0xintuition/agent-skills
```

## Usage

### Write Operations

```
/intuition --write createAtoms "Ethereum"
/intuition --write createTriples <subjectId> <predicateId> <objectId>
/intuition --write deposit <termId> 0.01
```

### Read Operations

```
/intuition --read getAtomCost
/intuition --read getShares <address> <termId>
/intuition --read previewDeposit <termId> 0.01
```

### Network Selection

```
/intuition --chain testnet createAtoms "test-atom"
```

On first invocation the agent will ask which network to use if not specified.

## Supported Networks

| Network | Chain ID | MultiVault |
|---------|----------|------------|
| Intuition Mainnet | 1155 | `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e` |
| Intuition Testnet | 13579 | `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91` |

Both are Intuition L3 chains. The native token is **$TRUST** (mainnet) / **tTRUST** (testnet). Agents must define custom chains for viem -- built-in chain definitions won't work.

## How Writes Work

1. **Query prerequisites** -- cost queries (`getAtomCost`, `getTripleCost`), existence checks
2. **Encode calldata** -- using viem `encodeFunctionData` or `cast calldata`, with inline ABI fragments
3. **Calculate msg.value** -- creation cost per item + any initial deposits (all in $TRUST)
4. **Apply policy gates (autonomous mode)** -- allowlists, spend limits, simulation, approval mode
5. **Output unsigned tx** -- `{to, data, value, chainId}` for external signing

The skill provides both `cast` (foundry) and `viem` (TypeScript) encoding patterns for every operation.

## Autonomous Approvals

For unattended execution, configure policy-driven approvals in [reference/autonomous-policy.md](./reference/autonomous-policy.md).

- Policy file location: `INTUITION_POLICY_PATH` or `./.intuition/autonomous-policy.json`
- Modes: `strict`, `permissive`, `manual-review`
- Guardrails: chain/address allowlists, value limits, mandatory simulation, structured approval requests
- Injection defense: untrusted research cannot supply `to/data/value`; executor recomputes tx fields and verifies calldata selector/args
- Runtime blocking gate: run `scripts/validate-tx-from-intent.js` before every sign/broadcast (see [reference/runtime-enforcement.md](./reference/runtime-enforcement.md))
- End-to-end entrypoint: use `scripts/enforce-and-sign.js` to validate first and sign only on pass

## Key V2 API Details

- Term IDs are `bytes32` (deterministic hashes), not sequential `uint256`
- Creation is batch-only: `createAtoms(bytes[], uint256[])`, `createTriples(bytes32[], bytes32[], bytes32[], uint256[])`
- Deposits/redeems include bonding curve selection (`curveId`) and slippage protection (`minShares`/`minAssets`)
- Counter-triples are created automatically with every triple

## Design Philosophy

- **Canonical correctness** -- verified protocol invariants for Intuition's on-chain API
- **No wallet assumptions** -- outputs tx params, doesn't dictate execution path
- **Write-first priority** -- reads are straightforward; the hard part is getting writes right
- **Inline ABI fragments** -- L3 isn't indexed by Etherscan, so agents can't discover ABIs

## References

- [Intuition V2 Contracts](https://github.com/0xIntuition/intuition-v2/tree/main/contracts/core)
- [Intuition TypeScript SDK](https://github.com/0xIntuition/intuition-ts)
- [ethskills (pattern reference)](https://github.com/austintgriffith/ethskills)
- [Agent Skills Spec](https://agentskills.io/specification)

## License

MIT
