# approve

Grant another address permission to deposit into or redeem from your vaults on your behalf. Follow these steps in order.

**Requires:** `$RPC`, `$MULTIVAULT`, `$CHAIN_ID` from session setup (`reference/reading-state.md`).

**Function:** `approve(address sender, uint8 approvalType)`

## Semantics

- **The signer of `approve()` is the receiver** — the account whose vaults will be acted upon.
- The `sender` argument is the address being granted (or revoked) permission to act on the receiver's behalf.
- `approvalType` is a bit-packed enum:

  | Value | Name | Grants |
  |-------|------|--------|
  | `0` | `NONE` | Revokes all prior approval |
  | `1` | `DEPOSIT` | Sender may call `deposit` / `depositBatch` with this receiver as `receiver` |
  | `2` | `REDEMPTION` | Sender may call `redeem` / `redeemBatch` against this receiver's shares |
  | `3` | `BOTH` | Both of the above |

- `BOTH = DEPOSIT | REDEMPTION` — the enum is a bitmask, not a priority order. Passing `3` is the only way to grant both in one call; setting `1` then `2` overwrites, it does not combine.
- When `sender == receiver`, no approval is needed. The protocol short-circuits self-acting calls.

## Step 1: Confirm Direction

No on-chain prerequisite read — the `approvals` storage mapping is internal and has no public getter. Agents establish current approval state by scanning historical `ApprovalTypeUpdated` logs or querying the indexer.

Before encoding, confirm:

- The **signer** of this tx is the receiver who will grant or revoke approval.
- The `sender` argument is the caller address that will act on the signer's behalf in future deposit/redeem txs.
- `approvalType` matches the intended grant (or `0` to revoke).

## Step 2: Encode the Calldata

### Using cast

```bash
SENDER_TO_APPROVE=0x<senderAddr>   # address being granted permission
APPROVAL_TYPE=1                    # 0=NONE, 1=DEPOSIT, 2=REDEMPTION, 3=BOTH

CALLDATA=$(cast calldata "approve(address,uint8)" $SENDER_TO_APPROVE $APPROVAL_TYPE)
```

### Using viem

```typescript
const data = encodeFunctionData({
  abi: parseAbi(['function approve(address sender, uint8 approvalType)']),
  functionName: 'approve',
  args: [
    senderToApprove,   // address being granted permission
    approvalType,      // 0=NONE, 1=DEPOSIT, 2=REDEMPTION, 3=BOTH
  ],
})
```

## Step 3: msg.value

```
msg.value = 0 (non-payable)
```

`approve` does not move funds. Value must be 0.

## Step 4: Output the Unsigned Transaction JSON

Output one unsigned transaction object with resolved values from this session:

```json
{
  "to": "0x<multivault-address>",
  "data": "0x<calldata>",
  "value": "0",
  "chainId": "<chain ID as base-10 string>"
}
```

Set `to` to `$MULTIVAULT` and `chainId` to `$CHAIN_ID`.

## Important

- The signer is always the receiver granting approval — this tx must be broadcast by the account whose vaults will later be acted upon, not by the sender being approved.
- Revoke by calling `approve(sender, 0)`. There is no separate `revoke` function.
- Approval is per-(receiver, sender) pair — it applies to every `termId` and every `curveId`. It is not vault-scoped.
- Last-write-wins: calling `approve(sender, 1)` after `approve(sender, 2)` drops `REDEMPTION`. To hold both, pass `3` explicitly.
- Approvals persist across txs until explicitly changed. Agents delegating short-lived permissions should revoke when done.
- When a downstream `deposit` / `redeem` is to be executed by a non-receiver, the receiver must have granted the appropriate approval **before** the downstream tx broadcasts.

## Post-Broadcast Verification

After the wallet layer broadcasts the tx, verify per `reference/post-write-verification.md`:

- Receipt `status = success`.
- Receipt contains exactly one `ApprovalTypeUpdated(sender, receiver, approvalType)` event with:
  - `sender` = the address that was approved
  - `receiver` = the signer of this tx
  - `approvalType` = the uint8 passed in the call (`0`/`1`/`2`/`3`)
- Event topic0: `0x82a44452b8f9b854115b84acf31076a4deb9edd2530d246cf0d96c97a6ae619b`

A non-reverting tx where the decoded event differs from the intended `(sender, approvalType)` means the intent was encoded against the wrong signer — do not proceed to downstream delegated deposit/redeem without re-issuing approval.
