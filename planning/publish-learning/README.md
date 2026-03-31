# publish-learning — Planning Docs

This folder contains the full design and handoff materials for the `publish-learning` skill.

## Start here

**[ENGINEER-HANDOFF.md](./ENGINEER-HANDOFF.md)** — the primary implementation guide. Everything an engineer needs to build the skill: file-by-file specs, implementation order, hard constraints, and the seeding dependency. Read this first.

## Supporting docs

| File | What it is |
|------|-----------|
| [ceo-plan.md](./ceo-plan.md) | Full scope decisions, architecture review, error map, security findings, and success criteria from the CEO/strategy review |
| [design-skill.md](./design-skill.md) | Original skill design (approved) — problem statement, premises, data model, reflection protocol, file structure |
| [design-ontology.md](./design-ontology.md) | Ontology design (approved) — the 35 atoms to seed, naming decisions, seeding process, query patterns |

## What's being built

`publish-learning` is a universal agent learning layer. Any agent, building anything, can publish learnings from a coding session to the Intuition knowledge graph. Future agents bootstrap from those learnings before starting similar tasks. Intuition Protocol is the storage substrate — the domain of learnings is unbounded.

The first seeded domain is Intuition Protocol itself (because agents need to know how to use the publishing layer).

## The one human dependency

Before the skill is usable, the core atoms (predicates + learning types) and the 35 Intuition Protocol domain atoms must be seeded on-chain via `domains/intuition-protocol/SEED.md` (written as part of implementation step 4). Owner: Billy or Jonathan. ~20-30 min operation.
