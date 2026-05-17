# ThoughtProof API Reference

## Base URL

```
https://api.thoughtproof.ai
```

## Authentication

No API key required for verification. Payment is handled via the x402 protocol (Base USDC).

Operators can optionally register for an API key (`X-Operator-Key` header) to track usage across their agents. See `/v1/operators` below.

## Endpoints

### `GET /`

Service info and available endpoints.

```json
{
  "name": "ThoughtProof Attestation Service",
  "version": "0.1.0",
  "docs": "https://thoughtproof.ai/api",
  "health": "/v1/health",
  "jwks": "/.well-known/jwks.json",
  "openapi": "/openapi.json"
}
```

### `GET /v1/health`

Health check. Returns `200` if operational.

### `POST /v1/check`

Verify a claim or reasoning trace. **x402 payment required.**

#### Request

```json
{
  "claim": "string (required) — the reasoning or claim to verify",
  "stakeLevel": "low | medium | high | critical (default: medium)",
  "domain": "general | financial | medical | legal | code (default: general)",
  "speed": "standard | deep (default: standard)"
}
```

#### Response (200)

```json
{
  "verdict": "ALLOW | BLOCK | UNCERTAIN",
  "confidence": 0.87,
  "objections": ["string array — concerns raised by critic models"],
  "durationMs": 2340
}
```

Additional fields (`verificationProfile`, `modelCount`, `mdi`) may be present depending on the verification run but should not be depended on.

#### Payment Flow (x402)

The endpoint returns `402 Payment Required` with payment instructions:

```json
{
  "error": "Payment Required",
  "protocol": "x402",
  "intentId": "pi_...",
  "payment": {
    "amountUsdc": "0.02",
    "recipientWallet": "0xAB9f84864662f980614bD1453dB9950Ef2b82E83",
    "tokenAddress": "0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",
    "network": "base",
    "expiresAt": "2026-03-28T21:30:12.054Z"
  },
  "instructions": [
    "Option A (Circle Nanopayments): Send PAYMENT-SIGNATURE header with base64-encoded EIP-3009 payload",
    "Option B (manual): 1. Send 0.02 USDC to 0xAB9f... on Base",
    "2. POST /v1/payment-intents/{intentId}/confirm with { \"txHash\": \"0x...\" }",
    "3. Retry this request with header X-Payment-Intent: {intentId}"
  ]
}
```

**Pricing by speed tier:**

| Speed | Cost (USDC) | maxAmountRequired |
|-------|-------------|-------------------|
| `standard` | $0.008 | 8000 |
| `deep` | $0.08 | 80000 |

The `maxAmountRequired` field in the 402 response is denominated in USDC micro-units (6 decimals).

**Two payment options:**
- **Option A (recommended):** Circle Nanopayments via EIP-3009 — single-header, no confirmation step.
- **Option B (manual):** Send USDC → confirm tx hash → retry with intent header.

### `GET /v1/signer`

Returns the current signing key for on-chain proof verification.

```json
{
  "signer": "0xAB9f84864662f980614bD1453dB9950Ef2b82E83",
  "algorithm": "secp256k1",
  "usage": "ecrecover-compatible verification signatures"
}
```

### `POST /v1/verify`

Issue a signed verification receipt (EdDSA JWT + blockHash). Requires operator API key.

```json
{
  "agentId": "agent_abc123xyz",
  "claim": "Approve €500 payment to vendor-42 based on invoice analysis",
  "verdict": "ALLOW",
  "domain": "general",
  "metadata": {}
}
```

Response:

```json
{
  "receiptId": "rcpt_xK9mN2pQ4rT8sV",
  "verdict": "ALLOW",
  "score": 0.8234,
  "jwt": "eyJ...",
  "blockHash": "0x...",
  "verifyUrl": "https://api.thoughtproof.ai/v1/receipts/rcpt_xK9mN2pQ4rT8sV"
}
```

### `GET /v1/receipts/{receiptId}`

Retrieve a previously issued receipt. No authentication required — publicly verifiable.

### `POST /v1/operators`

Register as an operator. Returns an API key for the `X-Operator-Key` header.

### `GET /.well-known/jwks.json`

Public signing keys (Ed25519) for verifying receipt JWTs.

## Rate Limits

No explicit rate limits. x402 payment acts as natural rate limiting.

## SDK Alternative

For programmatic access, use the `pot-sdk` npm package:

```bash
npm install pot-sdk
```

```typescript
import { verify } from 'pot-sdk'

const result = await verify({
  claim: 'ProjectX implements best security practices',
  stakeLevel: 'medium',
  domain: 'code',
})

// result.verdict: 'ALLOW' | 'BLOCK' | 'UNCERTAIN'
// result.confidence: 0.87
// result.objections: []
```

**Note:** The SDK handles the x402 payment flow internally. A funded Base USDC wallet is still required.

## OpenAPI Spec

Full machine-readable spec available at:

```
https://api.thoughtproof.ai/openapi.json
```

## Resources

- **npm:** https://www.npmjs.com/package/pot-sdk (v2.0.0, zero dependencies)
- **GitHub:** https://github.com/ThoughtProof
- **OpenAPI spec:** https://api.thoughtproof.ai/openapi.json
- **Patent:** USPTO #63/984,669 (Pending)
