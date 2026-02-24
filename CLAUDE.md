# 0xintuition/agent-skills

Agent skills monorepo for the Intuition Protocol. Skills teach AI agents to correctly interact with Intuition on-chain.

## Structure

```
agent-skills/
├── skills/              # Individual skill directories
│   └── intuition/       # Intuition Protocol skill
│       ├── SKILL.md     # Skill definition (agent-facing)
│       ├── README.md    # Human documentation
│       └── reference/   # Supplementary references
├── .claude-plugin/
│   └── marketplace.json # skills.sh marketplace manifest
├── CLAUDE.md            # This file
├── README.md            # Repo overview
└── LICENSE
```

## Adding a New Skill

1. Create directory: `skills/my-skill/`
2. Add `SKILL.md` with required frontmatter:
   ```yaml
   ---
   name: my-skill
   description: Brief description of what the skill does
   ---
   ```
3. Add `README.md` with installation and usage docs
4. Update `marketplace.json` if the skill belongs to an existing plugin, or add a new plugin entry
5. Update root `README.md` skills table

## Skill Frontmatter

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Skill identifier (used in `/name` command) |
| `description` | Yes | Brief description |
| `license` | No | License identifier |
| `metadata.author` | No | Skill author |
| `metadata.version` | No | Semantic version |
| `argument-hint` | No | Usage hint shown to users |
| `allowed-tools` | No | Tool restrictions for the skill |

## Key Technical Context

- Intuition runs on an L3 chain (mainnet: 1155, testnet: 13579)
- Native token is $TRUST (mainnet) / tTRUST (testnet), NOT ETH
- MultiVault contract: `0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e` (mainnet)
- V2 API uses `bytes32` term IDs, batch-only creation, bonding curves
- Skills produce unsigned tx params -- no wallet/signing management
