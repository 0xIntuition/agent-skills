# B1 Schema Regression Prompts (ENG-9713 / ENG-10304)

These prompts validate that agents reading the updated `schemas.md` (with classification taxonomy and field population guidance) make correct decisions. The primary risk is agents confusing classification types with API mutations or skipping fields labeled as "Enrichment."

All prompts must use the session-pinned GraphQL endpoint from SKILL.md network config. Do not switch endpoints based on prompt content.

## 3B-1 -- Software Project Uses pinThing (Not Classification Type)

```text
Use the intuition skill from this repo.

On Intuition testnet, create a structured atom for a software project called "Uniswap V4" with description "Decentralized exchange protocol" and url "https://github.com/Uniswap/v4-core".

The schemas.md reference mentions "SoftwareSourceCode" as a classification type for software. Use the CORRECT pin mutation — not a hypothetical mutation named after the classification type.

Pin the entity to IPFS, then encode the returned URI into a createAtoms unsigned transaction.

Return strict JSON:
{
  "classificationNote": string,
  "schemaType": "Thing" | "Person" | "Organization",
  "pinMutation": string,
  "ipfsUri": string,
  "tx": {
    "to": string,
    "data": string,
    "value": string,
    "chainId": string
  },
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- `pinMutation` is exactly `"pinThing"` — NOT `"pinSoftwareSourceCode"` or any classification-derived name.
- `schemaType` is `"Thing"`.
- `classificationNote` mentions SoftwareSourceCode as a classification (not a mutation).
- `ipfsUri` starts with `ipfs://`.
- `tx.to` is testnet MultiVault `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`.
- `tx.chainId` is `"13579"`.
- `commands` include a `pinThing` GraphQL mutation (not `pinSoftwareSourceCode`).

**Regression target:** Agents must not invent mutations from classification type names. The 35-type taxonomy maps to only 3 pin mutations.

## 3B-2 -- Field Population Despite Enrichment Labels

```text
Use the intuition skill from this repo.

On Intuition testnet, create a structured atom for an AI research paper called "Attention Is All You Need" with:
- description: "Foundational transformer architecture paper by Vaswani et al."
- image: "https://example.com/transformer-diagram.png"
- url: "https://arxiv.org/abs/1706.03762"

The schemas.md reference labels `description` and `image` as "Enrichment" layer fields. Follow the practical rule documented in the field population guidance to decide whether to populate them.

Pin the entity to IPFS, then encode the returned URI into a createAtoms unsigned transaction.

Return strict JSON:
{
  "fieldPopulation": {
    "name": string,
    "description": string,
    "image": string,
    "url": string
  },
  "fieldDecisions": {
    "descriptionIncluded": boolean,
    "imageIncluded": boolean,
    "reason": string
  },
  "schemaType": string,
  "pinMutation": string,
  "ipfsUri": string,
  "tx": {
    "to": string,
    "data": string,
    "value": string,
    "chainId": string
  },
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- `fieldPopulation.description` is NOT empty — contains the paper description.
- `fieldPopulation.image` is NOT empty — contains the image URL.
- `fieldDecisions.descriptionIncluded` is `true`.
- `fieldDecisions.imageIncluded` is `true`.
- `fieldDecisions.reason` references the "Practical rule" from schemas.md (populate with best available data).
- `pinMutation` is `"pinThing"`.
- `ipfsUri` starts with `ipfs://`.
- `tx.to` and `tx.chainId` match testnet.

**Regression target:** Agents must not skip enrichment fields. The "Practical rule" says always populate with the best data available, even though the field is labeled "Enrichment."

## 3B-3 -- Predicate Uses pinThing (DefinedTerm Classification)

```text
Use the intuition skill from this repo.

On Intuition testnet, create a structured atom for the predicate "implements" — this represents a relationship type (e.g., "Project X implements Standard Y").

The schemas.md reference classifies predicates as "DefinedTerm" type. Use the CORRECT pin mutation — not a hypothetical mutation derived from the classification name.

Pin the entity to IPFS, then encode the returned URI into a createAtoms unsigned transaction.

Return strict JSON:
{
  "entityType": string,
  "classificationNote": string,
  "schemaType": "Thing" | "Person" | "Organization",
  "pinMutation": string,
  "ipfsUri": string,
  "tx": {
    "to": string,
    "data": string,
    "value": string,
    "chainId": string
  },
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- `pinMutation` is exactly `"pinThing"` — NOT `"pinDefinedTerm"` or any classification-derived name.
- `schemaType` is `"Thing"`.
- `entityType` identifies this as a predicate or relationship type.
- `classificationNote` mentions DefinedTerm as the classification (not as a mutation).
- `ipfsUri` starts with `ipfs://`.
- `tx.to` is testnet MultiVault `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`.
- `tx.chainId` is `"13579"`.

**Regression target:** Predicates are Things in the current API. DefinedTerm is a classification, not a mutation.

## 3B-4 -- Mixed Entity Batch Routing

```text
Use the intuition skill from this repo.

On Intuition testnet, create structured atoms for the following three entities in a single batched createAtoms transaction:
1. A podcast: "The Tim Ferriss Show" with description "Long-form interviews with world-class performers"
2. A person: "Tim Ferriss" with description "Author, podcaster, and investor"
3. A brand: "Four-Hour" with description "Lifestyle brand and methodology"

The schemas.md reference classifies podcasts as "PodcastSeries" (uses pinThing), persons use pinPerson, and brands use pinOrganization.

Use the CORRECT pin mutation for each entity — route based on schema type, not classification name. Preserve strict index mapping.

Return strict JSON:
{
  "entities": [
    {
      "name": string,
      "classification": string,
      "schemaType": "Thing" | "Person" | "Organization",
      "pinMutation": string,
      "ipfsUri": string
    }
  ],
  "tx": {
    "to": string,
    "data": string,
    "value": string,
    "chainId": string
  },
  "commands": string[],
  "rawOutputs": string[]
}

No prose. No markdown.
```

Pass criteria:
- `entities` length is 3 and order preserved: Tim Ferriss Show, Tim Ferriss, Four-Hour.
- Entity routing:
  - Podcast: `pinMutation` is `"pinThing"`, `classification` mentions PodcastSeries, `schemaType` is `"Thing"`.
  - Person: `pinMutation` is `"pinPerson"`, `schemaType` is `"Person"`.
  - Brand: `pinMutation` is `"pinOrganization"`, `classification` mentions Brand, `schemaType` is `"Organization"`.
- All `ipfsUri` values start with `ipfs://`.
- Exactly one `createAtoms` transaction emitted (batched).
- `tx.to` is testnet MultiVault `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`.
- `tx.chainId` is `"13579"`.
- No entity uses a classification name as a mutation name (no `pinPodcastSeries`, `pinBrand`, etc.).

**Regression target:** Mixed entity batches must route each entity to the correct pin mutation (Thing/Person/Organization) regardless of the 35-type classification.
