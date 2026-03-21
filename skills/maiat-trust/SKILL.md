---
name: maiat-trust
description: Use this skill to check AI agent trust scores and token safety before transactions. Query Maiat Protocol's free API to get trust verdicts, completion rates, risk assessments, and token forensics. Triggers on tasks involving agent trust, agent reputation, token safety, rug pull detection, honeypot checks, or pre-transaction risk assessment.
license: MIT
metadata:
  author: JhiNResH
  version: "1.0.0"
argument-hint: "[agent-trust|token-check|token-forensics] [address]"
allowed-tools: "Bash, Read"
---

# Maiat Trust Skill

Check AI agent trustworthiness and token safety before transacting. All endpoints are **free** — no API key required.

## When to Use This Skill

- Before sending funds to an AI agent → check trust score
- Before swapping a token → check if it's a honeypot/rug pull
- When evaluating an agent's track record → check completion rate and history
- When building agent-to-agent commerce → verify counterparty reputation

## API Reference

**Base URL:** `https://app.maiat.io/api/v1`

### 1. Agent Trust Score

Check if an AI agent is trustworthy.

```bash
curl -s "https://app.maiat.io/api/v1/trust?address=0xAGENT_ADDRESS"
```

**Response:**
```json
{
  "address": "0x...",
  "name": "Luna",
  "trustScore": 60,
  "verdict": "caution",
  "completionRate": 0.51,
  "totalJobs": 40000,
  "uniqueBuyers": 8,
  "riskFactors": ["low completion rate"],
  "recommendation": "Verify agent's track record before large transactions"
}
```

**Verdicts:** `trusted` (70+) · `caution` (40-69) · `avoid` (<40)

### 2. Token Safety Check

Check if a token is safe to swap.

```bash
curl -s "https://app.maiat.io/api/v1/token-check?address=0xTOKEN_ADDRESS&chainId=8453"
```

**Response:**
```json
{
  "address": "0x...",
  "safe": true,
  "verdict": "safe",
  "checks": {
    "honeypot": false,
    "highTax": false,
    "unverified": false
  }
}
```

### 3. Token Forensics (Deep Analysis)

Deep rug pull analysis with ML + heuristic scoring.

```bash
curl -s "https://app.maiat.io/api/v1/token-forensics?address=0xTOKEN_ADDRESS&chainId=8453"
```

### 4. Agent Reputation (Community Sentiment)

Get community sentiment and endorsement data.

```bash
curl -s "https://app.maiat.io/api/v1/agent-reputation?address=0xAGENT_ADDRESS"
```

## Decision Framework

```
Agent trust score ≥ 70 + token verdict = safe  → Proceed
Agent trust score 40-69 OR token verdict = caution → Proceed with limits
Agent trust score < 40 OR token verdict = avoid → Do not transact
```

## On-Chain Contracts (Base Mainnet)

For direct smart contract reads (no API needed):

| Contract | Address | Purpose |
|----------|---------|---------|
| MaiatOracle | `0xc6cf...c6da` | Read trust scores on-chain |
| ERC-8004 Identity | `0x8004A169...9432` | Agent identity registry |
| ERC-8004 Reputation | `0x8004BAa1...9b63` | Agent reputation registry |
| TrustGateHook | `0xf980...daFf` | Uniswap V4 dynamic fees based on trust |

```solidity
// Read trust score from MaiatOracle (free, no gas)
uint256 score = MaiatOracle.getTrustScore(agentAddress);
```

## Integration with Intuition

Maiat trust scores can be combined with Intuition attestations for multi-layered trust:

1. **Maiat** → algorithmic trust score (completion rate, volume, diversity)
2. **Intuition** → human consensus (stake-weighted community opinion)

Query Maiat first for the algorithmic baseline, then check Intuition for community sentiment.

## Links

- **Dashboard:** https://app.maiat.io
- **Agent Passport:** https://passport.maiat.io
- **Documentation:** https://app.maiat.io/docs
- **GitHub:** https://github.com/JhiNResH/maiat-protocol
- **npm packages:** `@jhinresh/maiat-sdk`, `@jhinresh/viem-guard`, `@jhinresh/mcp-server`
