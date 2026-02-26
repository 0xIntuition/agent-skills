# Intuition Agent Skills

Agent skills for [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Codex](https://openai.com/codex), and compatible AI agents. Teaches agents to correctly interact with the [Intuition Protocol](https://intuition.systems) on-chain.

## Skills

| Skill | Description | Install |
|-------|-------------|---------|
| [intuition](skills/intuition/) | Canonical reference for producing correct Intuition Protocol transactions -- ABIs, encoding, addresses, value calculations | `npx skills add 0xintuition/agent-skills --skill intuition` |

## Quick Start

```bash
# Install all skills
npx skills add 0xintuition/agent-skills

# Install a specific skill
npx skills add 0xintuition/agent-skills --skill intuition
```

Once installed, skills are available in your agent's session. Use `/intuition` to invoke the Intuition skill.

## What These Skills Do

Intuition runs on an L3 chain that isn't indexed by Etherscan. LLMs can't discover the ABIs, and they make consistent mistakes with the V2 contract interface (bytes32 IDs, batch-only creation, bonding curves). These skills fill those blind spots with verified, canonical knowledge.

**Skills produce unsigned transaction parameters.** Wallet infrastructure and signing are the builder's responsibility.

## Structure

```
agent-skills/
├── skills/
│   └── intuition/        # Intuition Protocol skill
│       ├── SKILL.md      # Skill definition (agent-facing)
│       ├── README.md     # Human documentation
│       └── reference/    # Supplementary references
├── .claude-plugin/
│   └── marketplace.json  # skills.sh marketplace manifest
├── CLAUDE.md             # Repo-level agent instructions
├── README.md             # This file
└── LICENSE
```

## Adding Skills

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on adding new skills to this repo.

## Testing

Testing is documented in [TESTING.md](TESTING.md), including:
- Layer A deterministic calldata checks (`scripts/pass2-calldata-verification.sh`)
- Layer A.5 edge-case RPC checks (`scripts/pass2-edge-case-tests.sh`)
- Layer B prompt suites for autonomous consumption and on-chain integration (`tests/prompts/`)

## References

- [Intuition Protocol](https://intuition.systems)
- [Agent Skills Specification](https://agentskills.io/specification)
- [skills.sh](https://skills.sh) -- skill discovery and leaderboard
- [Intuition V2 Contracts](https://github.com/0xIntuition/intuition-v2/tree/main/contracts/core)

## License

MIT
