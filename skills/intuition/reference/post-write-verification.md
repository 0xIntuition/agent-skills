# Post-Write Verification

After a write transaction is broadcast and mined, verify it landed correctly before treating the new state as real. Post-write verification is distinct from preflight checks (`reference/simulation.md`, `previewAtomCreate`, `previewDeposit`): preflight predicts outcomes, verification confirms them.

**Requires:** `$RPC`, `$MULTIVAULT`, and the tx hash returned by the caller's wallet/broadcast layer.

## Verification Order

Run these in order. Stop at the first failure — downstream checks are meaningless if an earlier one failed.

1. **Receipt status.** Confirm the tx was mined and did not revert.
2. **Term-ID reconstruction (creation ops only).** Confirm the expected `bytes32[]` matches what the caller pre-computed.
3. **On-chain state confirmation.** Confirm the vault is now in the expected state (`isTermCreated`, `getShares`, `getVault`, `convertToAssets`).
4. **Event inspection (optional).** If the caller's infra is event-driven, decode the emitted event against the contract ABI. Events are auxiliary — on-chain reads in step 3 are the source of truth.
5. **Indexer revalidation (optional).** If downstream systems depend on GraphQL, wait for the indexer to catch up. See the Indexer Lag section below.

## Step 1: Receipt Status

Confirm `status = 1` (success) and that the tx was included in a finalized block.

### Using cast

```bash
TX_HASH="0x<txHash>"
cast receipt $TX_HASH --rpc-url $RPC

# Status-only check (exits nonzero if reverted)
STATUS=$(cast receipt $TX_HASH --rpc-url $RPC --json | jq -r '.status')
# "0x1" = success, "0x0" = reverted
```

### Using viem

```typescript
const receipt = await client.waitForTransactionReceipt({ hash: txHash })
if (receipt.status !== 'success') {
  throw new Error(`Tx reverted: ${txHash}`)
}
```

If `status = 0x0`, the tx reverted. Use `cast run $TX_HASH --rpc-url $RPC --quick` or viem's `call` with the same calldata against the pre-tx block to replay and surface the revert reason.

## Step 2: Term-ID Reconstruction (Creation Ops)

For `createAtoms` / `createTriples`, the caller already computed each expected `bytes32` pre-broadcast via `calculateAtomId(data)` or `calculateTripleId(s, p, o)` (see `operations/create-atoms.md` Step 1). These are deterministic hashes of the inputs — after a successful creation, the on-chain IDs must match. No log parsing is needed to identify the created terms.

```bash
# Already computed pre-broadcast:
#   ATOM_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" "$ATOM_DATA" --rpc-url $RPC)
#   TRIPLE_ID=$(cast call $MULTIVAULT "calculateTripleId(bytes32,bytes32,bytes32)(bytes32)" \
#     $SUBJECT_ID $PREDICATE_ID $OBJECT_ID --rpc-url $RPC)

# Post-broadcast: confirm each expected ID now exists on-chain.
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $ATOM_ID --rpc-url $RPC    # must be true
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $TRIPLE_ID --rpc-url $RPC  # must be true
```

If `isTermCreated` returns `false` for an ID the caller expected to create, something went wrong — the tx succeeded but against a different input (a calldata mismatch) or the block reorganized. Stop and re-investigate before treating the term as usable.

For callers that need the return value explicitly (the full `bytes32[]` in broadcast order), parse it from the tx trace or the `AtomCreated` / `TripleCreated` events. Reconstruction via `calculateAtomId` / `calculateTripleId` is preferred — it requires no log decoding and is O(1) per input.

## Step 3: On-Chain State Confirmation

Confirm the write produced the expected vault state. Run these against the block containing the tx (or any later block).

### Creation (createAtoms / createTriples)

```bash
# The term exists.
cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $TERM_ID --rpc-url $RPC

# Vault exists and has the expected initialized totals.
# Cost-only creation yields zero user shares, but the vault itself is seeded
# with the minimum share/assets state.
cast call $MULTIVAULT "getVault(bytes32,uint256)(uint256,uint256)" $TERM_ID $CURVE_ID --rpc-url $RPC

# If a non-zero initial deposit was included, the creator now holds shares.
cast call $MULTIVAULT "getShares(address,bytes32,uint256)(uint256)" $CREATOR $TERM_ID $CURVE_ID --rpc-url $RPC
```

### Deposit

Sample balances before broadcast, then confirm the delta matches the preview after.

```bash
# Before broadcast (save this):
SHARES_BEFORE=$(cast call $MULTIVAULT "getShares(address,bytes32,uint256)(uint256)" \
  $RECEIVER $TERM_ID $CURVE_ID --rpc-url $RPC)

# After broadcast:
SHARES_AFTER=$(cast call $MULTIVAULT "getShares(address,bytes32,uint256)(uint256)" \
  $RECEIVER $TERM_ID $CURVE_ID --rpc-url $RPC)

# Delta must satisfy: SHARES_AFTER - SHARES_BEFORE >= minShares (slippage bound)
# and ideally ≈ the expectedShares returned by previewDeposit.
```

If the delta is zero or below `minShares`, investigate — the tx may have landed against unexpected state. A revert here is only possible if `minShares` was violated, which should have been caught in simulation.

### Redeem

```bash
SHARES_BEFORE=$(cast call $MULTIVAULT "getShares(address,bytes32,uint256)(uint256)" \
  $SENDER $TERM_ID $CURVE_ID --rpc-url $RPC)
# Broadcast...
SHARES_AFTER=$(cast call $MULTIVAULT "getShares(address,bytes32,uint256)(uint256)" \
  $SENDER $TERM_ID $CURVE_ID --rpc-url $RPC)

# Delta must equal the shares argument: SHARES_BEFORE - SHARES_AFTER == shares.
# Assets received are visible in the tx receipt (msg.value is zero; assets come from the vault).
```

For assets-received verification, decode the `Redeemed` event (Step 4) or track receiver balance deltas in the native token.

### Batch Variants

`depositBatch` / `redeemBatch` / `createAtoms` / `createTriples` apply the same per-item checks. Iterate over each term ID:

```bash
for TERM_ID in "${TERM_IDS[@]}"; do
  cast call $MULTIVAULT "isTermCreated(bytes32)(bool)" $TERM_ID --rpc-url $RPC
  cast call $MULTIVAULT "getShares(address,bytes32,uint256)(uint256)" $RECEIVER $TERM_ID $CURVE_ID --rpc-url $RPC
done
```

## Step 4: Event Inspection (Optional)

Write paths often emit multiple events for the same logical action. Event decoding is useful for event-driven consumers (indexers, webhooks) but is not required for on-chain verification — the state reads in Step 3 are authoritative.

Primary event signatures (from `IMultiVault.sol`):

| Event | Signature |
|---|---|
| `AtomCreated` | `AtomCreated(address indexed creator, bytes32 indexed termId, bytes atomData, address atomWallet)` |
| `TripleCreated` | `TripleCreated(address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId)` |
| `Deposited` | `Deposited(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 assets, uint256 assetsAfterFees, uint256 shares, uint256 totalShares, VaultType vaultType)` |
| `Redeemed` | `Redeemed(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 shares, uint256 totalShares, uint256 assets, uint256 fees, VaultType vaultType)` |
| `SharePriceChanged` | `SharePriceChanged(bytes32 indexed termId, uint256 indexed curveId, uint256 sharePrice, uint256 totalAssets, uint256 totalShares, VaultType vaultType)` |

`VaultType` is `enum { ATOM, TRIPLE, COUNTER_TRIPLE }` (uint8: 0 / 1 / 2).

Typical receipts include more than one event:

- `createAtoms` emits `AtomCreated`, `Deposited`, and `SharePriceChanged`.
- `createTriples` emits `TripleCreated`, `Deposited`, and `SharePriceChanged`.
- `deposit` / `depositBatch` emit `Deposited` and `SharePriceChanged` per affected vault, plus fee events when applicable.
- `redeem` / `redeemBatch` emit `Redeemed` and `SharePriceChanged` per affected vault, plus fee events when applicable.

### Decoding with cast

```bash
# Fetch and filter logs from the receipt.
cast receipt $TX_HASH --rpc-url $RPC --json | jq '.logs[] | select(.topics[0] == "0x<eventTopic0>")'

# Topic0 hashes (keccak256 of the event signature):
cast keccak "AtomCreated(address,bytes32,bytes,address)"
cast keccak "TripleCreated(address,bytes32,bytes32,bytes32,bytes32)"
cast keccak "Deposited(address,address,bytes32,uint256,uint256,uint256,uint256,uint256,uint8)"
cast keccak "Redeemed(address,address,bytes32,uint256,uint256,uint256,uint256,uint256,uint8)"
cast keccak "SharePriceChanged(bytes32,uint256,uint256,uint256,uint256,uint8)"
```

### Decoding with viem

```typescript
const receipt = await client.waitForTransactionReceipt({ hash: txHash })

const createdEvents = parseEventLogs({
  abi: parseAbi([
    'event AtomCreated(address indexed creator, bytes32 indexed termId, bytes atomData, address atomWallet)',
    'event TripleCreated(address indexed creator, bytes32 indexed termId, bytes32 subjectId, bytes32 predicateId, bytes32 objectId)',
    'event Deposited(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 assets, uint256 assetsAfterFees, uint256 shares, uint256 totalShares, uint8 vaultType)',
    'event Redeemed(address indexed sender, address indexed receiver, bytes32 indexed termId, uint256 curveId, uint256 shares, uint256 totalShares, uint256 assets, uint256 fees, uint8 vaultType)',
    'event SharePriceChanged(bytes32 indexed termId, uint256 indexed curveId, uint256 sharePrice, uint256 totalAssets, uint256 totalShares, uint8 vaultType)',
  ]),
  logs: receipt.logs,
})
```

Cross-check decoded `termId`, `shares`, and `assets` against the preview values from preflight. Large divergence between preview and emitted values indicates fee config drift or a race against another caller mutating the vault in the same block.

## Step 5: Indexer Revalidation (Optional)

GraphQL indexes chain state asynchronously and lags after a successful write. On-chain reads in Steps 2 and 3 are finalized the moment the tx is mined; GraphQL may need seconds to minutes to catch up.

- Until the indexer has ingested the write, **prefer on-chain reads** for anything safety-critical (downstream writes, user balance displays that must be accurate).
- To detect indexer catch-up, poll the same term via GraphQL and compare `term_id` presence or `total_shares` against the on-chain value. When GraphQL matches on-chain, the indexer is caught up.
- Treat GraphQL-derived session caches (labels, predicate vocab, graph-wide stats) as stale after any write that could affect them. Re-query or drop to on-chain reads.

See `reference/graphql-queries.md` → Post-Write Indexer Lag for the full pattern.

## Preflight vs Post-Write: Where Checks Belong

| Check | Preflight | Post-Write |
|---|---|---|
| Existence (`isTermCreated`) | Before `createAtoms` / `createTriples` — skip creation if true | After creation — confirm the expected ID exists |
| `calculateAtomId` / `calculateTripleId` | Derive expected ID from inputs | Reconstruct the expected return to compare against state |
| `previewAtomCreate` / `previewTripleCreate` | Size expected shares and post-fee assets | Compare emitted/state values against the preview |
| `previewDeposit` / `previewRedeem` | Derive `minShares` / `minAssets` for slippage | Compare the share/asset delta against preview |
| Simulation (`cast call` with value) | Catch revert reasons pre-broadcast | Never — simulation is pre-broadcast only |
| Receipt status | Never — the tx hasn't happened | Always — first post-broadcast check |
| `getShares` / `getVault` delta | Optional (see current state) | Primary confirmation of write effect |
| Event decoding | N/A | Optional; for event-driven consumers |
| GraphQL revalidation | Pre-write: revalidate discovered data on-chain first | Post-write: only after indexer catches up |

## Important

- On-chain reads in Step 3 are the source of truth. Events and GraphQL are derived views of the same state and may lag or decode incorrectly if the ABI is out of sync.
- Never treat a successful receipt alone as proof that a write had the intended effect — a non-reverting tx can still land against different state than expected (front-running, reorg, fee config change between preview and execution). Always pair receipt success with a state delta check.
- `AtomCreated.atomData` and `TripleCreated.subjectId/predicateId/objectId` echo inputs the caller already knows. Use them for audit trails, not for identifying which term was created — `calculateAtomId` / `calculateTripleId` is deterministic and available pre-broadcast.
- Verification is per-term, not per-tx. A batch tx may succeed as a whole while one entry lands against unexpected state (e.g., a race on the same vault). Iterate every term ID.
- For contract source, ABIs, and event definitions: https://github.com/0xIntuition/intuition-v2/tree/main/contracts/core/src/interfaces/IMultiVault.sol
