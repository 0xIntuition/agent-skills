# Maiat Trust Skill

AI agent trust verification and token safety checks for autonomous agents.

## What It Does

This skill teaches AI agents to check trust scores and token safety before making on-chain transactions. It queries Maiat Protocol's free REST API — no API key, no authentication, no cost.

## Use Cases

- **Pre-transaction trust check** — Before an agent sends funds to another agent, verify the recipient's trust score and completion rate
- **Token safety** — Before swapping a token, check for honeypot, high tax, or unverified contract red flags
- **Rug pull detection** — Deep forensic analysis combining ML models and heuristic scoring
- **Agent discovery** — Find and evaluate agents by reputation before engaging in commerce

## Install

```bash
# Install this skill
npx skills add 0xintuition/agent-skills --skill maiat-trust

# Or install all skills in this repo
npx skills add 0xintuition/agent-skills
```

## Quick Example

```bash
# Check agent trust
curl -s "https://app.maiat.io/api/v1/trust?address=0x..." | jq '.verdict'

# Check token safety
curl -s "https://app.maiat.io/api/v1/token-check?address=0x...&chainId=8453" | jq '.safe'
```

## How It Complements Intuition

Maiat provides the **algorithmic trust layer** — automated scoring based on on-chain behavior (completion rate, transaction volume, buyer diversity). Intuition provides the **human consensus layer** — stake-weighted community opinions.

Together they create a complete trust picture:
- Maiat score = "what has this agent actually done?"
- Intuition attestation = "what do people think about this agent?"

## Links

- [Maiat Protocol](https://app.maiat.io)
- [GitHub](https://github.com/JhiNResH/maiat-protocol)
- [Documentation](https://app.maiat.io/docs)
- [npm SDK](https://www.npmjs.com/package/@jhinresh/maiat-sdk)
