# B2 On-Chain Prompts (Broadcast Verification)

These prompts are for funded-wallet execution tests on Intuition testnet.

Prerequisites:
- funded testnet wallet (tTRUST)
- signer path configured outside the prompt (e.g., `cast send` harness)

## B2.1 -- Create Atom + Verify Exists

```text
Use the intuition skill from this repo.

On Intuition testnet, produce an unsigned transaction to create atom "b2-atom-<timestamp>".
Return strict JSON:
{
  "to": string,
  "data": string,
  "value": string,
  "chainId": number,
  "atomLabel": string,
  "atomId": string
}

No prose. No markdown.
```

Post-broadcast check:
- `calculateAtomId(bytes)` + `isTermCreated(bytes32)` returns `true`

## B2.2 -- Deposit + Verify Shares

```text
Use the intuition skill from this repo.

On Intuition testnet, produce an unsigned deposit transaction for 0.001 tTRUST into atomId <atomId>.
If receiver is not provided, set receiver to signer address.
Return strict JSON:
{
  "to": string,
  "data": string,
  "value": string,
  "chainId": number,
  "termId": string,
  "amountWei": string
}

No prose. No markdown.
```

Post-broadcast check:
- `getShares(signer, termId, curveId) > 0`

## B2.3 -- Redeem + Verify Shares Drop

```text
Use the intuition skill from this repo.

On Intuition testnet, produce an unsigned redeem transaction to redeem all shares for termId <atomId> owned by signer <address>.
If receiver is not provided, set receiver to signer address.
Return strict JSON:
{
  "to": string,
  "data": string,
  "value": string,
  "chainId": number,
  "termId": string,
  "shares": string
}

No prose. No markdown.
```

Post-broadcast check:
- `getShares(signer, termId, curveId) == 0`

## B2.4 -- Triple Flow + Verify Triple Exists

```text
Use the intuition skill from this repo.

On Intuition testnet, produce unsigned transactions to create triple ("Alice", "trusts", "Bob").
Create missing atoms first if required.
Return strict JSON array:
[
  {
    "operation": string,
    "to": string,
    "data": string,
    "value": string,
    "chainId": number,
    "dependsOn": string | null
  }
]

No prose. No markdown.
```

Post-broadcast check:
- computed `tripleId` exists via `isTermCreated(tripleId) == true`
