---
name: thoughtproof
description: Use this skill to verify agent reasoning with ThoughtProof before writing attestations to the Intuition knowledge graph. Triggers when an agent needs to verify a claim, decision, or proposal before creating atoms or triples. Produces a structured verification receipt and the canonical triple pattern for recording the result on-chain.
license: MIT
metadata:
  author: ThoughtProof
  version: "0.1.0"
argument-hint: "[claim] [--stake-level low|medium|high|critical] [--domain general|financial|medical|legal|code]"
allowed-tools: "Bash, Read"
---

# ThoughtProof Verification Skill

This skill verifies agent reasoning via the ThoughtProof API before an attestation is written to the Intuition knowledge graph. It produces a structured verification receipt and the canonical triple pattern for recording the result on-chain.

## When to Use This Skill

Use this skill when an agent is about to create an attestation (atom + triple) in Intuition and the reasoning behind that attestation should be verified first. Verification answers: **"Is the reasoning behind this claim sound enough to commit on-chain?"**

This skill does **not** replace the `intuition` skill — it runs **before** it. The output of this skill feeds into the `intuition` skill's write path.

```
Agent reasoning → ThoughtProof verification → Intuition attestation
```

## What ThoughtProof Checks

ThoughtProof runs adversarial multi-model verification. Independent models (Claude, Grok, DeepSeek) challenge the reasoning from different angles:

- **Logical consistency** — does the argument contradict itself?
- **Factual grounding** — are claims supported by evidence?
- **Hidden assumptions** — what unstated premises does the reasoning rely on?
- **Adversarial robustness** — can the argument be dismantled by a critic?

Output: `ALLOW`, `BLOCK`, or `UNCERTAIN` with a confidence score, objections, and model diversity metrics.

## Prerequisites

- **ThoughtProof API access** — payment via x402 (Base USDC). No API key required.
- **A funded x402 wallet** — USDC on Base for verification payments ($0.008–$0.08 per call depending on speed/stake level).
- **The `intuition` skill** — for the subsequent on-chain write. This skill produces the verification receipt; the `intuition` skill handles atom/triple creation.

## Verification Flow

### Step 1: Extract the Claim

Identify the core claim the agent wants to attest. This is the reasoning that needs verification — not the triple structure, but the **why** behind it.

```
Intent: "Create attestation that ProjectX implements best security practices"
Claim: "ProjectX implements best security practices"
```

### Step 2: Call ThoughtProof API

The `/v1/check` endpoint uses x402 payment. A standard HTTP client will receive a `402 Payment Required` response first. You need an x402-compatible client that handles the pay-and-retry flow automatically.

**With an x402-compatible client:**

```typescript
// Using fetch with x402 payment handler (Node 18+)
const response = await fetch('https://api.thoughtproof.ai/v1/check', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    claim: 'ProjectX implements best security practices',
    stakeLevel: 'medium',
    domain: 'code',
  }),
})
```

**Without x402 client (manual payment flow):**

```bash
# Step 1: Get payment intent
RESPONSE=$(curl -s -X POST https://api.thoughtproof.ai/v1/check \
  -H "Content-Type: application/json" \
  -d '{"claim": "ProjectX implements best security practices", "stakeLevel": "medium", "domain": "code"}')

# Response: 402 with payment instructions
# { "intentId": "pi_...", "payment": { "amountUsdc": "0.02", ... } }

# Step 2: Send USDC on Base to the specified wallet
# Step 3: Confirm payment via /v1/payment-intents/{intentId}/confirm
# Step 4: Retry original request with X-Payment-Intent header
```

See `reference/api-reference.md` for full payment flow details.

#### Parameters

| Parameter | Required | Values | Default | Description |
|-----------|----------|--------|---------|-------------|
| `claim` | Yes | string | — | The reasoning or claim to verify |
| `stakeLevel` | No | `low`, `medium`, `high`, `critical` | `medium` | Signals importance; affects verification depth |
| `domain` | No | `general`, `financial`, `medical`, `legal`, `code` | `general` | Domain context for model selection |
| `speed` | No | `standard`, `deep` | `standard` | `deep` runs additional adversarial passes |

#### Pricing by Speed

| Speed | Cost | Pipeline | Use When |
|-------|------|----------|----------|
| `standard` | **$0.008** | 2-model (Generate + Evaluate) | Default; most attestations |
| `deep` | **$0.08** | 4-model + full reasoning chain | High-value decisions, audit-grade |

Pricing is per-call, paid via x402 (Base USDC). The `maxAmountRequired` in the 402 response reflects the tier: $0.008 for standard, $0.08 for deep.

### Step 3: Interpret the Response

```json
{
  "verdict": "ALLOW",
  "confidence": 0.87,
  "objections": [],
  "durationMs": 2340
}
```

| Field | Type | Description |
|-------|------|-------------|
| `verdict` | `ALLOW` \| `BLOCK` \| `UNCERTAIN` | Verification result |
| `confidence` | `0.0–1.0` | How confident the verification is |
| `objections` | `string[]` | Specific concerns raised by critic models |
| `durationMs` | `integer` | Verification time in milliseconds |

Additional fields may be present (`verificationProfile`, `modelCount`, `mdi`) depending on the verification run. Do not depend on their presence.

### Step 4: Act on the Verdict

| Verdict | Action |
|---------|--------|
| `ALLOW` | Proceed to attestation via the `intuition` skill |
| `BLOCK` | **Do not attest.** Log objections. Report to user. |
| `UNCERTAIN` | **Do not attest.** Escalate to human review. |

**Fail-closed on BLOCK/UNCERTAIN** — ambiguous or unsound reasoning never proceeds to on-chain attestation.

**Fail-open on API unavailability** — if the ThoughtProof API is unreachable (network error, timeout), the agent may proceed with a warning flag. This is a liveness fallback, configurable per policy.

## Output Contract

This skill produces one of two JSON objects:

### Verification Passed

```json
{
  "status": "verification_passed",
  "verdict": "ALLOW",
  "confidence": 0.87,
  "claim": "ProjectX implements best security practices",
  "receiptAtom": {
    "name": "ThoughtProof Verification: ALLOW (87%)",
    "description": "Claim: 'ProjectX implements best security practices'. Verdict: ALLOW. Confidence: 0.87. No objections.",
    "image": "",
    "url": "https://api.thoughtproof.ai"
  },
  "suggestedTriple": {
    "subject": "<claimAtomId or description of claim atom>",
    "predicate": "verifiedBy",
    "object": "<receiptAtomId — pin receiptAtom first>"
  }
}
```

### Verification Failed

```json
{
  "status": "verification_failed",
  "verdict": "BLOCK",
  "confidence": 0.34,
  "claim": "ProjectX implements best security practices",
  "objections": [
    "No evidence of security audit provided",
    "Claim relies on self-reported metrics only"
  ],
  "recommendation": "Do not attest. Address objections before retrying."
}
```

The JSON object is the complete machine-mode response. On `verification_passed`, hand the `receiptAtom` and `suggestedTriple` to the `intuition` skill for on-chain recording.

## Recording Verification on Intuition

When verification passes (`ALLOW`), record the result as a triple in the Intuition knowledge graph. This creates a permanent, stakeable verification record.

### Canonical Triple Pattern

```
[Verified Claim] → [verifiedBy] → [ThoughtProof Verification Receipt]
```

All three components are atoms. The receipt atom contains verification metadata in its description field.

### Step 5: Pin the Verification Receipt

Pin a `Thing` atom with the verification result:

```graphql
mutation pinThing($name: String!, $description: String!, $image: String!, $url: String!) {
  pinThing(thing: {
    name: $name,
    description: $description,
    image: $image,
    url: $url
  }) {
    uri
  }
}
```

Variables (from `receiptAtom` in the output contract):

```json
{
  "name": "ThoughtProof Verification: ALLOW (87%)",
  "description": "Claim: 'ProjectX implements best security practices'. Verdict: ALLOW. Confidence: 0.87. No objections.",
  "image": "",
  "url": "https://api.thoughtproof.ai"
}
```

**Receipt naming convention:** `"ThoughtProof Verification: {VERDICT} ({confidence}%)"` — this makes receipts discoverable via graph search.

**Known limitation:** Verification metadata is stored as unstructured text in the `description` field. A future version may introduce a dedicated schema type for machine-parseable verification receipts.

### Step 6: Look Up or Create the Predicate

The canonical predicate is `"verifiedBy"`. A Thing atom with this label already exists on Intuition mainnet (`0xcc934dbc...`). Look it up first:

```graphql
query FindPredicate {
  atoms(
    where: { label: { _eq: "verifiedBy" }, type: { _neq: "TextObject" } }
    order_by: { as_predicate_triples_aggregate: { count: desc } }
  ) {
    term_id label type
    as_predicate_triples_aggregate { aggregate { count } }
  }
}
```

- **Result found** → use the `term_id` from the first result.
- **No result** → create a pinned predicate via `pinThing`:

```json
{
  "name": "verifiedBy",
  "description": "Indicates that the subject's reasoning has been epistemically verified by the object. Used for reasoning verification attestations.",
  "image": "",
  "url": ""
}
```

**Why `verifiedBy` and not `verified-by`:** A Thing-type atom labeled `"verifiedBy"` already exists on Intuition mainnet. Reusing an existing canonical atom avoids fragmenting the graph with near-duplicate predicates. If the existing atom is found, use it directly.

### Step 7: Create the Triple

With all three atom IDs (claim, predicate, receipt), use the `intuition` skill to create the triple:

```
createTriples([claimAtomId], [verifiedByPredicateId], [receiptAtomId], [tripleCost])
```

The triple vault enables staking: others can deposit $TRUST to signal agreement that the verification is meaningful, or deposit into the counter-triple to challenge it.

## BLOCK / UNCERTAIN Patterns

When verification returns `BLOCK` or `UNCERTAIN`, do **not** create the original attestation. Return the `verification_failed` output contract object (see Output Contract above).

Optionally, for audit trails, record the failed verification on-chain:

```
[Claim] → [blockedBy] → [ThoughtProof Verification Receipt]
```

This creates a permanent record that verification was attempted and failed — useful for accountability but not required for v0.1.

## Skill Contents

```
reference/
  api-reference.md          Full API endpoint documentation and payment flow
```

## Integration with Autonomous Policy

If the `intuition` skill's autonomous policy is active, verification can be added as a suggested pre-write gate:

```json
{
  "verification": {
    "enabled": true,
    "provider": "thoughtproof",
    "endpoint": "https://api.thoughtproof.ai/v1/check",
    "requiredForOperations": ["createTriples"],
    "minConfidence": 0.7,
    "failMode": "block"
  }
}
```

This is a **suggested** extension to the `intuition` skill's policy schema — not yet implemented in the canonical skill. It is included here to illustrate how verification could integrate with the existing policy gate architecture.

## Protocol Invariants

1. **Verify before attesting** — never create a triple for an unverified claim when this skill is active.
2. **Fail-closed on BLOCK/UNCERTAIN** — do not proceed with attestation.
3. **Fail-open on API unavailability** — proceed with warning, configurable per policy.
4. **Receipt atoms are Things** — use `pinThing` for all verification receipts.
5. **Predicate is `verifiedBy`** — look up the existing atom before creating a new one.
6. **One receipt per verification** — each verification call produces one receipt atom.
7. **Description is unstructured** — verification metadata is stored as text in the description field (v0.1 limitation).
