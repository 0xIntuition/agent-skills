# Contributing to Intuition Agent Skills

Thank you for your interest in contributing to the Intuition agent skills ecosystem. This repo teaches AI agents to interact correctly with the Intuition Protocol on-chain, so contributions carry real weight -- a bad skill can produce incorrect transactions.

This guide covers the contribution process, skill structure requirements, and review criteria.

## Contribution Process

We follow an **issue-first** workflow. Open an issue before writing code.

### 1. Open an Issue

Every contribution starts with an issue, whether it's a bug fix, a new ecosystem skill, or an improvement to an existing one.

- **Bug reports**: Describe the incorrect behavior, expected behavior, and steps to reproduce. Include the agent platform (Claude Code, Codex, etc.) and any relevant transaction output.
- **New skills**: Use the issue to pitch your skill. Explain what it does, how it relates to the Intuition knowledge graph, and why it belongs in this repo versus a standalone install. Include a rough scope of what the SKILL.md would cover.
- **Improvements**: Describe the change and the problem it solves. Reference specific lines or sections if possible.

### 2. Discussion Before Code

Wait for maintainer feedback on your issue before starting implementation. This is where we align on:

- Whether the contribution fits the repo's scope
- How the skill composes with existing skills (especially the core `intuition` skill)
- Architecture and design decisions
- Any constraints or requirements specific to the Intuition Protocol

We ask that all PRs link to an existing issue. PRs without prior discussion may be closed so we can redirect the conversation to an issue first. This isn't about gatekeeping -- it's about making sure no one invests effort on work that doesn't align with the project's direction.

### 3. Submit a Pull Request

Once the approach is agreed upon in the issue:

1. Fork the repo and create a branch from `main`
2. Implement the skill following the structure requirements below
3. Open a PR linking to the issue
4. Fill in the PR description: what changed, why, and how to test it

## Skill Types

Not everything needs to be a new skill. Consider what you're building:

| Type | When to Use | Example |
|------|-------------|---------|
| **Core skill improvement** | Fix or enhance the existing `intuition` skill | Schema corrections, new transaction patterns, edge case handling |
| **Ecosystem skill** | A complementary skill that works alongside the core skill | Verification, analysis, or enrichment that feeds into or reads from the knowledge graph |
| **Reference update** | New or corrected reference material | ABI updates, API changes, new contract deployments |

Ecosystem skills should **compose with** the core Intuition skill, not replace or duplicate it. A good ecosystem skill has a clear boundary: it does one thing, documents how it interacts with the knowledge graph, and specifies whether it runs before or after the core skill.

## Composing with the Intuition Skill

If your skill feeds data into or reads from the Intuition knowledge graph, your SKILL.md should document three things:

### Execution Order

State whether your skill runs **before** or **after** the core `intuition` skill, and what data flows between them.

```
Agent reasoning → [your skill] → Intuition attestation    # before
Intuition query → [your skill] → enriched result          # after
```

### Output Contract

Define a structured JSON output so agents (and other skills) know exactly what your skill produces. Include both success and failure shapes.

```json
{
  "status": "success | failure",
  "data": { "...your skill's output..." },
  "suggestedTriple": {
    "subject": "<description or atom ID>",
    "predicate": "<predicate label>",
    "object": "<description or atom ID>"
  }
}
```

If your skill doesn't produce data that becomes atoms or triples, that's fine — but say so explicitly.

### Knowledge Graph Patterns

If your skill creates atoms or triples, document:

- **What atoms it creates** — what type (Thing/Person/Organization), what fields are populated, naming conventions
- **What predicates it uses** — name the predicate, check if it already exists on-chain before creating a new one, explain what the relationship means
- **The canonical triple pattern** — e.g., `[Claim] → [verifiedBy] → [Receipt]`

Reuse existing predicates and atoms where possible. Fragmenting the graph with near-duplicates makes it harder for everyone.

## Skill Structure Requirements

Every skill lives in its own directory under `skills/`. The directory name must match the `name` field in your SKILL.md frontmatter.

```
skills/my-skill/
├── SKILL.md              # Required: skill definition (agent-facing)
├── README.md             # Required: human documentation
└── reference/            # Optional: supplementary references
    └── api-reference.md
```

> **Note:** This repo uses the singular `reference/` directory name. The [Agent Skills spec](https://agentskills.io/specification) uses `references/`. This is an Intuition-specific convention -- follow what you see in this repo.

### SKILL.md

The skill definition is what agents read. It must include frontmatter:

```yaml
---
name: my-skill
description: Brief description of what the skill does
license: MIT
metadata:
  author: Your Name or Org
  version: 0.1.0
---
```

Required frontmatter fields:

| Field | Description |
|-------|-------------|
| `name` | Skill identifier, used in `/name` invocation. Must be lowercase, hyphen-separated, and match the parent directory name. No consecutive hyphens. |
| `description` | Describes what the skill does **and** when it should trigger. Include both capability and activation context (see the [intuition skill](skills/intuition/SKILL.md) for an example). |

Optional but recommended:

| Field | Description |
|-------|-------------|
| `license` | Must be `MIT` (see [License](#license)) |
| `metadata.author` | Author name or organization |
| `metadata.version` | Semantic version |
| `argument-hint` | Usage hint shown to users |
| `allowed-tools` | Tool restrictions for the skill (see the [Agent Skills spec](https://agentskills.io/specification) for format details) |

The body of SKILL.md should be written **for agents**, not humans. Be precise, explicit, and structured. Agents will follow these instructions literally.

### README.md

Human-facing documentation. Should cover:

- What the skill does and why it exists
- Installation instructions
- Usage examples
- How it relates to the core Intuition skill (if applicable)
- Any external dependencies or API requirements

### Reference Files

Put supplementary material in a `reference/` subdirectory. This includes API docs, schema definitions, ABI excerpts, or detailed protocol documentation that the skill references.

## Marketplace Registration

If your skill is accepted, it needs to be registered in `.claude-plugin/marketplace.json`. You can either:

- Add your skill to an existing plugin entry (if it's tightly coupled to that plugin)
- Create a new plugin entry for your skill

```json
{
  "plugins": [
    {
      "name": "my-plugin",
      "description": "What this plugin provides",
      "skills": [
        "./skills/my-skill"
      ]
    }
  ]
}
```

Update the root `README.md` skills table as well.

## Review Criteria

PRs are reviewed against these criteria:

### Correctness
- Transaction parameters, contract addresses, and chain IDs must be accurate
- ABIs and encoding patterns must match deployed contracts
- No hallucinated or fabricated protocol details

### Composability
- Ecosystem skills must not conflict with the core `intuition` skill
- Clear documentation of when the skill runs relative to others
- Explicit output contracts so downstream skills know what to expect

### Agent Readability
- SKILL.md is written for agent consumption: structured, unambiguous, no prose-heavy explanations
- Instructions are testable -- an agent following them produces correct output

### Scope
- The skill does one thing well
- No unnecessary dependencies or external service requirements that aren't documented
- Reference material is relevant and not duplicated from the core skill

## Testing

We use a layered testing approach (see [TESTING.md](TESTING.md) for full details):

- **Layer A**: Deterministic tests (shell scripts in `scripts/`) that validate calldata, API contracts, and encoding
- **Layer A.5**: RPC edge-case tests (read-only, no signing) for state-dependent behavior
- **Layer B1**: Agent consumption prompts (in `tests/prompts/`) that validate agents interpret the skill correctly
- **Layer B2**: On-chain integration prompts that validate full broadcast flows on testnet

### Minimum to open a PR

- At least one Layer A test if the skill produces transaction parameters
- At least one Layer B1 prompt that validates the core happy path

### Expected before merge

- Layer A green for all write operations
- B1 coverage for the skill's primary workflows
- B2 integration coverage if the skill produces transactions that go on-chain
- Edge cases covered in A.5 where applicable

See existing tests in `scripts/` and `tests/prompts/` for format and coverage examples.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE). All skills in this repo use MIT licensing -- set `license: MIT` in your SKILL.md frontmatter.
