# B1 Pin Prompts (IPFS Pinning & Structured Atoms)

These prompts validate structured atom creation via IPFS pinning — the full flow from schema selection through pin mutation to unsigned `createAtoms` transaction.

All prompts must use the session-pinned GraphQL endpoint from SKILL.md network config. Do not switch endpoints based on prompt content.

## Pin-1 -- Single Structured Atom (pinThing)

```text
Use the intuition skill from this repo.

On Intuition testnet, create a structured atom for a concept called "Decentralized Identity" with description "Self-sovereign identity primitives for web3" and url "https://example.com/did".

Pin the entity to IPFS using the appropriate schema type, then encode the returned URI into a createAtoms unsigned transaction.

Return strict JSON:
{
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
- `schemaType` is `"Thing"` and `pinMutation` is `"pinThing"`.
- `ipfsUri` starts with `ipfs://`.
- `tx.to` is testnet MultiVault `0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91`.
- `tx.chainId` is `"13579"`.
- `commands` include GraphQL pin + createAtoms calldata generation.

## Pin-2 -- Single Structured Atom (pinPerson)

```text
Use the intuition skill from this repo.

On Intuition testnet, create a structured atom for a person named "Vitalik Buterin" with description "Co-founder of Ethereum" and url "https://vitalik.eth.limo".

Pin the entity to IPFS using the appropriate schema type, then encode the returned URI into a createAtoms unsigned transaction.

Return strict JSON:
{
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
- `schemaType` is `"Person"` and `pinMutation` is `"pinPerson"`.
- `ipfsUri` starts with `ipfs://`.
- `tx.to` and `tx.chainId` match Intuition testnet (`0x2Ece...`, `13579`).
- `commands` and `rawOutputs` show pin response plus tx encoding.

## Pin-3 -- Single Structured Atom (pinOrganization)

```text
Use the intuition skill from this repo.

On Intuition testnet, create a structured atom for the organization "Ethereum Foundation" with description "Non-profit supporting Ethereum development" and url "https://ethereum.foundation".

Pin the entity to IPFS using the appropriate schema type, then encode the returned URI into a createAtoms unsigned transaction.

Return strict JSON:
{
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
- `schemaType` is `"Organization"` and `pinMutation` is `"pinOrganization"`.
- `ipfsUri` starts with `ipfs://`.
- `tx.to` and `tx.chainId` match Intuition testnet (`0x2Ece...`, `13579`).
- `commands` and `rawOutputs` show pin response plus tx encoding.

## Pin-4 -- Batch Structured Atoms (Mixed Schema Types)

```text
Use the intuition skill from this repo.

On Intuition testnet, create structured atoms for the following three entities in a single batched createAtoms transaction:
1. Person: "Alan Turing", description "Father of theoretical computer science"
2. Organization: "Bletchley Park", description "WWII codebreaking center"
3. Thing: "Enigma Machine", description "Electro-mechanical cipher device"

Pin each entity to IPFS using the appropriate schema type. Preserve strict index mapping: entity[0] maps to atomData[0], entity[1] to atomData[1], entity[2] to atomData[2].

Return strict JSON:
{
  "entities": [
    {
      "name": string,
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
- `entities` length is 3 and order is preserved: Alan Turing, Bletchley Park, Enigma Machine.
- Schema types are `Person`, `Organization`, `Thing` in the same order.
- All `ipfsUri` values start with `ipfs://`.
- Exactly one createAtoms transaction is emitted.
- `tx.to` and `tx.chainId` match Intuition testnet (`0x2Ece...`, `13579`).

## Pin-N1 -- Pin Failure (HTTP 500 on Pinned Endpoint)

```text
Use the intuition skill from this repo.

On Intuition testnet, attempt to create a structured atom for "Failure Test Entity" with description "This tests pin failure handling".

Use only the session-pinned GraphQL endpoint from SKILL.md network config. Do NOT switch endpoints.

Assume the pin request to that pinned endpoint returns HTTP 500 for this attempt.

Return the correct failure output per the skill's pin failure contract. Do NOT emit an unsigned transaction.

Return strict JSON:
{
  "status": "pin_failed",
  "operation": "createAtoms",
  "reason": string,
  "entity": string
}

No prose. No markdown.
```

Pass criteria:
- `status` is exactly `"pin_failed"`.
- `operation` is exactly `"createAtoms"`.
- `reason` clearly indicates HTTP failure (500 or non-2xx).
- Output contains no transaction fields (`to`, `data`, `value`, `chainId`).

## Pin-N2 -- Pin Failure (Missing Required Field)

```text
Use the intuition skill from this repo.

On Intuition testnet, attempt to create a structured atom using pinThing but with NO name field — only provide description "An entity without a name".

Use only the session-pinned GraphQL endpoint from SKILL.md network config.

If the pin mutation returns a GraphQL error due to the missing required field, return the correct failure output per the skill's pin failure contract. Do NOT emit an unsigned transaction.

Return strict JSON:
{
  "status": "pin_failed",
  "operation": "createAtoms",
  "reason": string,
  "entity": string
}

No prose. No markdown.
```

Pass criteria:
- `status` is exactly `"pin_failed"`.
- `operation` is exactly `"createAtoms"`.
- `reason` indicates GraphQL validation/required-field failure.
- Output contains no transaction fields (`to`, `data`, `value`, `chainId`).

## Pin-N3 -- Batch Pin Failure (One Entity Fails)

```text
Use the intuition skill from this repo.

On Intuition testnet, attempt to create structured atoms for:
1. Thing: "Valid Entity A", description "This should pin successfully"
2. Thing with missing required name field, description "This should fail pin validation"

Use only the session-pinned GraphQL endpoint from SKILL.md network config.

Per the skill's batch pinning rules, if ANY single pin fails the entire batch must be aborted — no transaction emitted.

Return strict JSON:
{
  "status": "pin_failed",
  "operation": "createAtoms",
  "reason": string,
  "entity": string,
  "successfulPins": [string],
  "failedEntity": string
}

No prose. No markdown.
```

Pass criteria:
- `status` is exactly `"pin_failed"`.
- `operation` is exactly `"createAtoms"`.
- `successfulPins` lists only the successful first entity.
- `failedEntity` identifies the second entity.
- Output contains no transaction fields (`to`, `data`, `value`, `chainId`).

## Pin-N4 -- Invalid URI Prefix Rejected

```text
Use the intuition skill from this repo.

On Intuition testnet, validate this raw pin response payload as if it came from the session-pinned GraphQL endpoint:
{"data":{"pinThing":{"uri":"https://gateway.pinata.cloud/ipfs/bafyexample"}}}

Per the skill's pin response contract, a URI without the "ipfs://" prefix must be treated as a pin failure. Do NOT emit an unsigned transaction.

Return strict JSON:
{
  "status": "pin_failed",
  "operation": "createAtoms",
  "reason": string,
  "entity": string
}

No prose. No markdown.
```

Pass criteria:
- `status` is exactly `"pin_failed"`.
- `operation` is exactly `"createAtoms"`.
- `reason` indicates invalid URI prefix / missing `ipfs://`.
- Output contains no transaction fields (`to`, `data`, `value`, `chainId`).
