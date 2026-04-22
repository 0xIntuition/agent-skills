# Config Fields

Practical semantics for the five protocol config reads. Use this to decide which fields constrain tx generation (safety-critical) and which are informational.

All five reads are free and stable within a session. Cache them with the other session setup values in `reference/reading-state.md`.

## The five reads

| Getter | Struct | Safety-critical fields |
|---|---|---|
| `getGeneralConfig()` | `GeneralConfig` | `minDeposit`, `atomDataMaxLength`, `feeThreshold`, `feeDenominator` |
| `getAtomConfig()` | `AtomConfig` | — (informational; effects are captured in previews) |
| `getTripleConfig()` | `TripleConfig` | — (informational; effects are captured in previews) |
| `getVaultFees()` | `VaultFees` | — (informational; effects are captured in previews) |
| `getBondingCurveConfig()` | `BondingCurveConfig` | `defaultCurveId` |

"Safety-critical" = tx will revert or produce an incorrect slippage bound if the field is ignored. "Informational" = the field shapes fee math, but `previewDeposit` / `previewRedeem` / `previewAtomCreate` / `previewTripleCreate` already incorporate it — agents should read the preview, not recompute.

## GeneralConfig

```solidity
struct GeneralConfig {
    address admin;
    address protocolMultisig;
    uint256 feeDenominator;
    address trustBonding;
    uint256 minDeposit;
    uint256 minShare;
    uint256 atomDataMaxLength;
    uint256 feeThreshold;
}
```

### Safety-critical

- **`minDeposit`** — Every direct deposit (`deposit`, `depositBatch`) must send `>= minDeposit` assets. Below that, the tx reverts with `MultiVault_DepositBelowMinimumDeposit`. Check the caller's requested amount against this before building calldata. This does **not** apply to `createAtoms` / `createTriples`; create paths are bounded by `getAtomCost()` / `getTripleCost()` instead.
- **`atomDataMaxLength`** — Maximum length in bytes of the `data` passed to `createAtoms`. Exceeding it reverts with `MultiVault_AtomDataTooLong`. Applies to the hex-encoded atom URI, not the pre-encoded string. Always pin structured payloads so the on-chain bytes stay short (an IPFS URI is ~60 bytes).
- **`feeThreshold`** — Entry/exit fees on a term's vault only apply once `totalShares` in that term's **default curve vault** reaches `feeThreshold`. Below the threshold, `previewDeposit` / `previewRedeem` and the actual execution paths charge zero entry/exit fees on that vault. The public `entryFeeAmount` / `exitFeeAmount` helpers are raw fee calculators and do **not** apply this threshold gate. Relevant when interpreting why a preview returned no fee on a low-activity vault — previews are still authoritative, this just explains the shape.
- **`feeDenominator`** — All fee percentages are stored as numerators against this denominator (`amount.mulDivUp(fee, feeDenominator)`). Required only if you need to convert a raw fee value (e.g., `vaultFees.entryFee = 500`) into a percentage (`500 / feeDenominator`). Agents usually do not need this — previews already return absolute values.

### Informational

- **`admin`**, **`protocolMultisig`**, **`trustBonding`** — Protocol roles and related contract addresses. Useful for interpreting event recipients; never used in tx generation.
- **`minShare`** — Shares minted to `address(0)` when a vault is first initialized (prevents share-price manipulation). Surfaces in `getVault(...)` totalShares for newly created vaults; the user never receives these shares.

## AtomConfig

```solidity
struct AtomConfig {
    uint256 atomCreationProtocolFee;
    uint256 atomWalletDepositFee;
}
```

Both fields are informational. Their effects are already folded into `getAtomCost()` and `previewAtomCreate` / `previewDeposit`.

- **`atomCreationProtocolFee`** — Fixed protocol fee included in `getAtomCost()`. Sent to `protocolMultisig`.
- **`atomWalletDepositFee`** — Fee applied on every deposit into an **atom** vault. Accrues as claimable balance for the atom wallet owner (`claimAtomWalletDepositFees(atomId)`), not the protocol. Does not apply to triple vaults or counter-triple vaults.

## TripleConfig

```solidity
struct TripleConfig {
    uint256 tripleCreationProtocolFee;
    uint256 atomDepositFractionForTriple;
}
```

Both informational; captured in `getTripleCost()` and `previewTripleCreate` / `previewDeposit` for triple vaults.

- **`tripleCreationProtocolFee`** — Fixed protocol fee included in `getTripleCost()`. Sent to `protocolMultisig`.
- **`atomDepositFractionForTriple`** — Fraction of a deposit into a triple vault that is distributed pro rata into the triple's three underlying atom vaults. Expressed as a numerator against `feeDenominator`. Only charged when every underlying atom's default curve vault is above `feeThreshold`.

## VaultFees

```solidity
struct VaultFees {
    uint256 entryFee;
    uint256 exitFee;
    uint256 protocolFee;
}
```

All three informational; `previewDeposit` / `previewRedeem` / `previewAtomCreate` / `previewTripleCreate` already incorporate them. Semantics matter when interpreting `Deposited` / `Redeemed` events.

- **`entryFee`** — Charged on deposits. Stays in the vault as assets (benefits existing shareholders rather than minting new shares for the depositor). Gated by the `feeThreshold` rule above: the charged entry fee is zero when the default curve vault's `totalShares < feeThreshold`.
- **`exitFee`** — Charged on redemptions. Stays in the vault as assets. Gated by the same threshold rule, evaluated against shares **remaining** after the redemption; fully draining a vault skips charged exit fees.
- **`protocolFee`** — Charged on both deposits and redemptions. Sent to `protocolMultisig`. Not gated by `feeThreshold`.

All three fees are stored as numerators against `generalConfig.feeDenominator`. Do not derive actual charged amounts from these fields yourself — the preview output is the authoritative threshold-aware result. The public fee helpers (`protocolFeeAmount` / `entryFeeAmount` / `exitFeeAmount`) are raw calculators against an input amount.

## BondingCurveConfig

```solidity
struct BondingCurveConfig {
    address registry;
    uint256 defaultCurveId;
}
```

- **`registry`** — Address of the `BondingCurveRegistry` contract that resolves `curveId` values to curve implementations. Informational.
- **`defaultCurveId`** — Safety-critical. Required by `deposit`, `redeem`, `depositBatch`, `redeemBatch`. Mainnet default is `1` (linear curve). Always query per session; governance-configurable. Cached as `$CURVE_ID` in the session setup.

## Revert conditions summary

Safety-critical fields map directly to revert errors. Check these client-side before building calldata:

| Field | Revert | Affected ops |
|---|---|---|
| `minDeposit` | `MultiVault_DepositBelowMinimumDeposit` | `deposit`, `depositBatch` |
| `atomDataMaxLength` | `MultiVault_AtomDataTooLong` | `createAtoms` |
| `defaultCurveId` (missing/invalid curve) | Curve-registry revert | `deposit`, `redeem`, `depositBatch`, `redeemBatch` |

`feeThreshold` and `feeDenominator` do not drive reverts directly; they drive preview output.

## Querying

```bash
cast call $MULTIVAULT "getGeneralConfig()((address,address,uint256,address,uint256,uint256,uint256,uint256))" --rpc-url $RPC
cast call $MULTIVAULT "getAtomConfig()((uint256,uint256))" --rpc-url $RPC
cast call $MULTIVAULT "getTripleConfig()((uint256,uint256))" --rpc-url $RPC
cast call $MULTIVAULT "getVaultFees()((uint256,uint256,uint256))" --rpc-url $RPC
cast call $MULTIVAULT "getBondingCurveConfig()((address,uint256))" --rpc-url $RPC
```

```typescript
const general = await client.readContract({ address: MULTIVAULT, abi: readAbi, functionName: 'getGeneralConfig' })
const atom = await client.readContract({ address: MULTIVAULT, abi: readAbi, functionName: 'getAtomConfig' })
const triple = await client.readContract({ address: MULTIVAULT, abi: readAbi, functionName: 'getTripleConfig' })
const vaultFees = await client.readContract({ address: MULTIVAULT, abi: readAbi, functionName: 'getVaultFees' })
const bondingCurve = await client.readContract({ address: MULTIVAULT, abi: readAbi, functionName: 'getBondingCurveConfig' })
```

Cache all five at session start if you expect to touch multiple operation types; query on demand otherwise. All values are governance-configurable via timelocked admin calls, so do not hardcode them across sessions.
