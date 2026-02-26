# B2 On-Chain Full Integration Prompts

These prompts are wallet-backed end-to-end tests on Intuition testnet.

Prerequisites:
- `.env` exists locally with signer + network variables (for example: `RPC`, `MULTIVAULT`, `CHAIN_ID`, `PRIVATE_KEY`, `SENDER`)
- funded testnet wallet (tTRUST)
- `cast` installed and available in `PATH`

## B2I.1 -- Create Atom End-to-End

```text
Use the intuition skill from this repo.

Run a full create-atom flow on Intuition testnet:
1) Load `.env` into shell context.
2) Query atom cost from `getAtomCost()`.
3) Create an unsigned transaction for atom label `b2i-atom-<timestamp>`.
4) Simulate the exact calldata and value with `cast call`.
5) Broadcast the same calldata with `cast send` using `PRIVATE_KEY`.
6) Verify `isTermCreated(atomId) == true`.

Return strict JSON:
{
  "mode": "full-integration",
  "operation": "createAtoms",
  "to": string,
  "data": string,
  "value": string,
  "chainId": number,
  "txHash": string,
  "atomLabel": string,
  "atomId": string,
  "verification": {
    "isTermCreated": boolean
  }
}

No prose. No markdown.
```

## B2I.2 -- Deposit End-to-End

```text
Use the intuition skill from this repo.

Run a full deposit flow on Intuition testnet for termId <atomId>:
1) Load `.env` into shell context.
2) Build unsigned calldata for deposit of 0.001 tTRUST into <atomId>.
3) If receiver is omitted, set receiver to `SENDER`.
4) Simulate exact calldata and value.
5) Broadcast with `cast send`.
6) Verify `getShares(SENDER, termId, curveId) > 0`.

Return strict JSON:
{
  "mode": "full-integration",
  "operation": "deposit",
  "to": string,
  "data": string,
  "value": string,
  "chainId": number,
  "txHash": string,
  "termId": string,
  "receiver": string,
  "verification": {
    "sharesAfter": string,
    "sharesPositive": boolean
  }
}

No prose. No markdown.
```

## B2I.3 -- Redeem End-to-End

```text
Use the intuition skill from this repo.

Run a full redeem flow on Intuition testnet for termId <atomId>:
1) Load `.env` into shell context.
2) Query current shares for `SENDER`.
3) Build unsigned calldata to redeem all shares from <atomId>.
4) If receiver is omitted, set receiver to `SENDER`.
5) Simulate exact calldata and value.
6) Broadcast with `cast send`.
7) Verify `getShares(SENDER, termId, curveId) == 0`.

Return strict JSON:
{
  "mode": "full-integration",
  "operation": "redeem",
  "to": string,
  "data": string,
  "value": string,
  "chainId": number,
  "txHash": string,
  "termId": string,
  "receiver": string,
  "sharesBefore": string,
  "verification": {
    "sharesAfter": string,
    "fullyRedeemed": boolean
  }
}

No prose. No markdown.
```

## B2I.4 -- Triple Flow End-to-End

```text
Use the intuition skill from this repo.

Run a full triple creation flow for ("Alice", "trusts", "Bob") on Intuition testnet:
1) Load `.env` into shell context.
2) Resolve atom IDs and existence for all 3 terms.
3) Create missing atoms first (simulate + broadcast + verify each).
4) Create triple (simulate + broadcast).
5) Verify the resulting triple ID exists via `isTermCreated(tripleId)`.

Return strict JSON:
{
  "mode": "full-integration",
  "operation": "createTriples",
  "steps": [
    {
      "name": string,
      "txHash": string | null,
      "status": "skipped" | "broadcast",
      "verified": boolean
    }
  ],
  "tripleId": string,
  "verification": {
    "isTermCreated": boolean
  }
}

No prose. No markdown.
```
