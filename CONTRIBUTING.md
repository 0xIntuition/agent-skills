# Contributing to Intuition Agent Skills

Thank you for your interest in contributing to the Intuition agent skills ecosystem. This repo is for skills that enable agents to interact correctly with the Intuition Protocol onchain, so contributions carry real weight.

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

## Where Should Your Skill Live?

This repo is best for skills the Intuition team is prepared to maintain long-term: the core Intuition protocol skill ([`intuition`](skills/intuition/)), first-party extensions, and canonical reference material.

For most community integrations -- especially skills that depend on third-party APIs, project-specific logic, or fast-moving external services -- we recommend publishing from your own repo. Users install them the same way, and you keep control over releases, maintenance, and reputation:

- **You own your release cycle.** Ship updates without waiting on our review queue.
- **You get your own skills.sh listing.** Your skill is discoverable under your name, building your project's reputation directly.
- **You control your dependencies.** If your skill calls an external API, you're the right team to maintain that integration.
- **Users install it the same way.** `npx skills add your-org/your-repo --skill your-skill` works identically to installing from this repo.

The [Composing with the Intuition Skill](#composing-with-the-intuition-skill) section below applies whether your skill lives here or in your own repo -- use it as a guide for building a great integration. If you'd like us to link to your community skill from our README, open an issue and we can link to it.

If you think a skill should live in this repo instead, open an issue first and explain why it should be maintained as a first-party Intuition skill.

### What belongs in this repo

| Type | Example |
|------|---------|
| **Core skill fixes and improvements** | Schema corrections, new transaction patterns, edge case handling |
| **First-party ecosystem skills** | Skills built and maintained by the Intuition team |
| **Reference updates** | ABI updates, API changes, new contract deployments |

### Usually better as its own repo

| Type | Example |
|------|---------|
| **Third-party integrations** | A skill that calls your project's API and feeds results into the knowledge graph |
| **Standalone tools** | Trust scoring, verification, analysis, or enrichment services |
| **Experimental skills** | Early-stage ideas that need room to iterate quickly |

## Composing with the Intuition Skill

If your skill feeds data into or reads from the Intuition knowledge graph, your `SKILL.md` should document three things:

### Execution Order

State whether your skill runs **before** or **after** the core `intuition` skill, and what data flows between them.

```
Agent reasoning → [your skill] → Intuition attestation    # before
Intuition query → [your skill] → enriched result          # after
```

### Structured JSON Output Contract

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

The body of `SKILL.md` should be written **for agents**, not humans. Be precise, explicit, and structured. Agents will follow these instructions literally.

## Versioning and Releases

The `metadata.version` field is release metadata, not PR metadata.

- Do **not** bump `metadata.version` in ordinary feature or fix PRs.
- Bump it only in a dedicated release PR that also updates `CHANGELOG.md`.
- Version by agent-visible behavior, not by whether the diff is "just docs."
  If a documentation change alters tx generation, safety gates, or verification
  behavior, it is an externally visible change.

See [RELEASING.md](RELEASING.md) for the semantic versioning rules and release
checklist used in this repo.

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
- `SKILL.md` is written for agent consumption: structured, unambiguous, no prose-heavy explanations
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

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE). All skills in this repo use MIT licensing -- set `license: MIT` in your `SKILL.md` frontmatter.
