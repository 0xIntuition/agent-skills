# Intuition Skill

Canonical skill for producing correct Intuition Protocol transaction parameters. The skill emits unsigned `{to,data,value,chainId}` objects; your wallet or backend handles signing and broadcast.

## Prerequisites

- `cast` (Foundry): query costs, previews, and build calldata.
- `curl`: call the public GraphQL API for discovery and pinning.
- `jq`: extract `term_id`, `uri`, and unsigned tx fields.
- `bc`: do uint256-safe 5% tolerance math in shell quickstarts.
- RPC access: public Intuition L3 endpoints, no API keys.
- Funded wallet: tTRUST on testnet or $TRUST on mainnet. Bridge via https://app.intuition.systems/bridge.

## Installation

```bash
npx skills add 0xIntuition/agent-skills --skill intuition
```

To pin a published release instead of tracking `main`, install from a tag or SHA:

```bash
npx skills add 0xIntuition/agent-skills#<tag-or-sha> --skill intuition
```

## Network Selection

Use the session values in [reference/network-config.md](./reference/network-config.md). The quickstarts below pin to testnet.

## Quickstart A: Discovery -> Deposit

```bash
NETWORK="Intuition Testnet"
CHAIN_ID=13579
RPC="https://testnet.rpc.intuition.systems/http"
MULTIVAULT="0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91"
GRAPHQL="https://testnet.intuition.sh/v1/graphql"
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1
RECEIVER="0x<share-recipient>"

SEARCH_BODY=$(jq -cn --arg searchTerm "%ethereum%" '{"query":"query SearchAtoms($searchTerm: String!, $limit: Int!) { atoms(where: { label: { _ilike: $searchTerm } }, limit: $limit, order_by: { created_at: desc }) { term_id label } }","variables":{"searchTerm":$searchTerm,"limit":1}}')
TERM_ID=$(curl -fsS -X POST "$GRAPHQL" -H "Content-Type: application/json" -d "$SEARCH_BODY" | jq -r '.data.atoms[0].term_id // empty')
test -n "$TERM_ID" || { echo "No matching atom found"; exit 1; }

CURVE_ID=$(cast call $MULTIVAULT "getBondingCurveConfig()((address,uint256))" --rpc-url $RPC | awk -F', ' '{print $2}' | tr -d ')')
MIN_DEPOSIT=$(cast call $MULTIVAULT "getGeneralConfig()((address,address,uint256,address,uint256,uint256,uint256,uint256))" --rpc-url $RPC | awk -F', ' '{print $5}' | awk '{print $1}')
DEPOSIT_WEI=$(cast --to-wei 0.002)
test "$DEPOSIT_WEI" -ge "$MIN_DEPOSIT" || { echo "Deposit is below minDeposit"; exit 1; }

EXPECTED_SHARES=$(cast call $MULTIVAULT "previewDeposit(bytes32,uint256,uint256)(uint256,uint256)" "$TERM_ID" "$CURVE_ID" "$DEPOSIT_WEI" --rpc-url $RPC | awk 'NR == 1 { print $1 }')
MIN_SHARES=$(printf '%s * 95 / 100\n' "$EXPECTED_SHARES" | bc)
CALLDATA=$(cast calldata "deposit(address,bytes32,uint256,uint256)" "$RECEIVER" "$TERM_ID" "$CURVE_ID" "$MIN_SHARES")

jq -n --arg to "$MULTIVAULT" --arg data "$CALLDATA" --arg value "$DEPOSIT_WEI" --arg chainId "$CHAIN_ID" '{to:$to,data:$data,value:$value,chainId:$chainId}'
```

## Quickstart B: Pin -> Encode -> Create

```bash
NETWORK="Intuition Testnet"
CHAIN_ID=13579
RPC="https://testnet.rpc.intuition.systems/http"
MULTIVAULT="0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91"
GRAPHQL="https://testnet.intuition.sh/v1/graphql"
export FOUNDRY_DISABLE_NIGHTLY_WARNING=1

PIN_BODY=$(jq -cn --arg name "README quickstart atom" --arg description "Pinned from the Intuition skill README quickstart" '{"query":"mutation pinThing($name: String!, $description: String!, $image: String!, $url: String!) { pinThing(thing: { name: $name, description: $description, image: $image, url: $url }) { uri } }","variables":{"name":$name,"description":$description,"image":"","url":""}}')
PIN_RESPONSE=$(curl -fsS -X POST "$GRAPHQL" -H "Content-Type: application/json" -d "$PIN_BODY")
URI=$(echo "$PIN_RESPONSE" | jq -r '.data.pinThing.uri // empty')
test -n "$URI" && [[ "$URI" == ipfs://* ]] || { echo "Pin failed"; exit 1; }

ATOM_DATA=$(cast --from-utf8 "$URI")
ATOM_ID=$(cast call $MULTIVAULT "calculateAtomId(bytes)(bytes32)" "$ATOM_DATA" --rpc-url $RPC)
ATOM_COST=$(cast call $MULTIVAULT "getAtomCost()(uint256)" --rpc-url $RPC | awk '{print $1}')
cast call $MULTIVAULT "previewAtomCreate(bytes32,uint256)(uint256,uint256,uint256)" "$ATOM_ID" "$ATOM_COST" --rpc-url $RPC >/dev/null
CALLDATA=$(cast calldata "createAtoms(bytes[],uint256[])" "[$ATOM_DATA]" "[$ATOM_COST]")

jq -n --arg to "$MULTIVAULT" --arg data "$CALLDATA" --arg value "$ATOM_COST" --arg chainId "$CHAIN_ID" '{to:$to,data:$data,value:$value,chainId:$chainId}'
```

## What the Skill Installs

- `SKILL.md`: canonical machine-facing contract, invariants, and output shape.
- `operations/`: write-specific encoding flows for create, deposit, redeem, batch, and approvals.
- `reference/`: read queries, network config, GraphQL, pinning, config semantics, and verification.
- `README.md`: operator-facing onboarding and first-success flows.

## Autonomous Mode

For unattended execution, policy guardrails and runtime validation live in [reference/autonomous-policy.md](./reference/autonomous-policy.md).

## Design Philosophy

- Canonical correctness over convenience shortcuts.
- On-chain reads and previews for safety-critical decisions; GraphQL for discovery.
- Wallet-agnostic output so the same skill works with local, hosted, and agentic signers.

## References

- [reference/network-config.md](./reference/network-config.md)
- [reference/schemas.md](./reference/schemas.md)
- [reference/post-write-verification.md](./reference/post-write-verification.md)
- [Intuition V2 Contracts](https://github.com/0xIntuition/intuition-v2/tree/main/contracts/core)

## License

MIT
