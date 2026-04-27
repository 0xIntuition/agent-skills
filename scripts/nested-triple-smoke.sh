#!/usr/bin/env bash
set -euo pipefail

export FOUNDRY_DISABLE_NIGHTLY_WARNING="${FOUNDRY_DISABLE_NIGHTLY_WARNING:-1}"

# Nested-triple smoke tests.
# Verifies the protocol + indexer assumptions the skill's nested-triple
# guidance depends on:
#   - the GraphQL terms.type discriminator is three-valued
#   - DiscoverNestedTriple filters out counter-triples
#   - getVaultType on-chain ordinals match the documented 0=ATOM, 1=TRIPLE,
#     2=COUNTER_TRIPLE
#   - isTriple is coarse (returns true for counter-triples)
#   - the polymorphic *_term fragment returns a nested-safe shape
#   - getVaultType is strict on unknown ids (reverts with
#     MultiVaultCore_TermDoesNotExist); isTermCreated is the existence guard;
#     isTriple / isCounterTriple are type-family booleans and are not existence
#     checks by themselves
#
# Defaults to testnet; override with CHAIN=mainnet. Read-only — no signing,
# no broadcast. Fixtures are discovered at runtime via GraphQL rather than
# hardcoded, so this survives chain resets.
#
# Optional fixture controls:
#   NESTED_TRIPLE_ID=0x...       Validate a specific nested triple fixture.
#   STRICT_NESTED_FIXTURE=1      Fail when no live nested triple fixture exists.

INTUITION_CHAIN="${CHAIN:-testnet}"
# CHAIN is reserved by foundry's cast as --chain; unset so it does not leak
# into cast subprocesses (which reject "testnet" as a chain name).
unset CHAIN
NESTED_TRIPLE_ID="${NESTED_TRIPLE_ID:-}"
STRICT_NESTED_FIXTURE="${STRICT_NESTED_FIXTURE:-0}"
if [[ "$INTUITION_CHAIN" == "testnet" ]]; then
  RPC="${RPC:-https://testnet.rpc.intuition.systems/http}"
  MULTIVAULT="${MULTIVAULT:-0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91}"
  GRAPHQL="${GRAPHQL:-https://testnet.intuition.sh/v1/graphql}"
elif [[ "$INTUITION_CHAIN" == "mainnet" ]]; then
  RPC="${RPC:-https://rpc.intuition.systems/http}"
  MULTIVAULT="${MULTIVAULT:-0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e}"
  GRAPHQL="${GRAPHQL:-https://mainnet.intuition.sh/v1/graphql}"
else
  echo "unknown CHAIN=$INTUITION_CHAIN (expected testnet or mainnet)" >&2
  exit 2
fi

PASS=0
FAIL=0
SKIP=0

pass() { echo "PASS: $1"; PASS=$((PASS+1)); }
fail() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }
skip() { echo "SKIP: $1"; SKIP=$((SKIP+1)); }

for dependency in curl jq cast; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    echo "missing dependency: $dependency" >&2
    exit 2
  fi
done

gql() {
  local query="$1"
  curl -sS -X POST "$GRAPHQL" \
    -H "content-type: application/json" \
    -d "$(jq -nc --arg q "$query" '{query:$q}')"
}

trim() { tr -d '[:space:]'; }

query_nested_triple_by_id() {
  local triple_id="$1"
  gql "{ triple(term_id: \"$triple_id\") { term_id subject { term_id } predicate { term_id } object { term_id } subject_term { id type atom { term_id label } triple { term_id } } predicate_term { id type atom { term_id label } triple { term_id } } object_term { id type atom { term_id label } triple { term_id } } } }"
}

validate_nested_fixture_response() {
  local label="$1"
  local response="$2"

  if echo "$response" | jq -e '.errors' >/dev/null 2>&1; then
    fail "$label query errored: $(echo "$response" | jq -c '.errors')"
    return
  fi

  local triple_id
  triple_id=$(echo "$response" | jq -r '.data.triple.term_id // empty')
  if [[ -z "$triple_id" ]]; then
    fail "$label fixture did not resolve to a triple"
    return
  fi

  local nested_slots
  nested_slots=$(echo "$response" | jq -r '
    [
      (if .data.triple.subject_term.type == "Triple" then "subject" else empty end),
      (if .data.triple.predicate_term.type == "Triple" then "predicate" else empty end),
      (if .data.triple.object_term.type == "Triple" then "object" else empty end)
    ] | join(",")
  ')

  if [[ -z "$nested_slots" ]]; then
    fail "$label fixture $triple_id has no Triple-valued component"
    return
  fi

  pass "$label fixture $triple_id has nested Triple component(s): $nested_slots"

  local slot
  for slot in subject predicate object; do
    local term_type
    local legacy_state
    term_type=$(echo "$response" | jq -r ".data.triple.${slot}_term.type // empty")
    legacy_state=$(echo "$response" | jq -r "if .data.triple.${slot} == null then \"null\" else \"present\" end")

    if [[ -z "$term_type" ]]; then
      fail "$label fixture missing ${slot}_term.type"
      continue
    fi

    if [[ "$term_type" == "Triple" ]]; then
      if [[ "$legacy_state" == "null" ]]; then
        pass "$label ${slot}_term.type=Triple and legacy ${slot} relation is null"
      else
        fail "$label ${slot}_term.type=Triple but legacy ${slot} relation is present"
      fi
    else
      pass "$label ${slot}_term.type=$term_type"
    fi
  done
}

echo "== Nested Triple Smoke Tests =="
echo "CHAIN=$INTUITION_CHAIN"
echo "GRAPHQL=$GRAPHQL"
echo "RPC=$RPC"
echo "MULTIVAULT=$MULTIVAULT"
if [[ -n "$NESTED_TRIPLE_ID" ]]; then
  echo "NESTED_TRIPLE_ID=$NESTED_TRIPLE_ID"
fi
echo ""

# ---------------------------------------------------------------------------
# 1. Schema discriminator is three-valued (Atom | Triple | CounterTriple).
#    Probe each enum value by filter. If the schema rejects a value it will
#    surface an error; otherwise the filter is valid even with zero rows.
# ---------------------------------------------------------------------------

for type_val in Atom Triple CounterTriple; do
  RESP=$(gql "{ terms(where:{type:{_eq:$type_val}}, limit:1){ id type } }")
  if echo "$RESP" | jq -e '.errors' >/dev/null 2>&1; then
    fail "schema rejected type=$type_val: $(echo "$RESP" | jq -c '.errors')"
    continue
  fi
  COUNT=$(echo "$RESP" | jq '.data.terms | length')
  if [[ "$COUNT" -gt 0 ]]; then
    RET_TYPE=$(echo "$RESP" | jq -r '.data.terms[0].type')
    if [[ "$RET_TYPE" == "$type_val" ]]; then
      pass "schema accepts type=$type_val (returned $COUNT row)"
    else
      fail "schema accepted type=$type_val but returned type=$RET_TYPE"
    fi
  else
    pass "schema accepts type=$type_val (no rows yet on $INTUITION_CHAIN)"
  fi
done

# ---------------------------------------------------------------------------
# 2. DiscoverNestedTriple filter excludes counter-triples.
# ---------------------------------------------------------------------------

DISCOVER=$(gql '{ terms(where:{type:{_eq:Triple}}, limit:5){ id type triple { term_id } } }')
if echo "$DISCOVER" | jq -e '.errors' >/dev/null 2>&1; then
  fail "DiscoverNestedTriple query errored: $(echo "$DISCOVER" | jq -c '.errors')"
else
  NON_TRIPLE=$(echo "$DISCOVER" | jq '[.data.terms[]? | select(.type != "Triple")] | length')
  TOTAL=$(echo "$DISCOVER" | jq '.data.terms | length')
  if [[ "$NON_TRIPLE" == "0" ]]; then
    pass "DiscoverNestedTriple filter: all $TOTAL results have type=Triple (no leak)"
  else
    fail "DiscoverNestedTriple filter leaked $NON_TRIPLE non-Triple results out of $TOTAL"
  fi
fi

# ---------------------------------------------------------------------------
# 3. Pick a triple; verify getVaultType and isTriple behavior on-chain.
# ---------------------------------------------------------------------------

TRIPLE_ID=$(echo "$DISCOVER" | jq -r '.data.terms[0].id // empty')
if [[ -z "$TRIPLE_ID" ]]; then
  skip "no positive triple available for on-chain classifier checks"
else
  VT_TRIPLE=$(cast call "$MULTIVAULT" "getVaultType(bytes32)(uint8)" "$TRIPLE_ID" --rpc-url "$RPC" | trim)
  if [[ "$VT_TRIPLE" == "1" ]]; then
    pass "getVaultType(positive triple) = 1 (TRIPLE)"
  else
    fail "getVaultType(positive triple) expected 1, got '$VT_TRIPLE' (term $TRIPLE_ID)"
  fi

  COUNTER_ID=$(cast call "$MULTIVAULT" "getCounterIdFromTripleId(bytes32)(bytes32)" "$TRIPLE_ID" --rpc-url "$RPC" | trim)
  VT_COUNTER=$(cast call "$MULTIVAULT" "getVaultType(bytes32)(uint8)" "$COUNTER_ID" --rpc-url "$RPC" | trim)
  if [[ "$VT_COUNTER" == "2" ]]; then
    pass "getVaultType(counter-triple) = 2 (COUNTER_TRIPLE)"
  else
    fail "getVaultType(counter-triple) expected 2, got '$VT_COUNTER'"
  fi

  IS_TRIPLE_COUNTER=$(cast call "$MULTIVAULT" "isTriple(bytes32)(bool)" "$COUNTER_ID" --rpc-url "$RPC" | trim)
  if [[ "$IS_TRIPLE_COUNTER" == "true" ]]; then
    pass "isTriple(counter-triple) = true (coarseness confirmed — spec expectation)"
  else
    fail "isTriple(counter-triple) expected true, got '$IS_TRIPLE_COUNTER'"
  fi

  IS_COUNTER=$(cast call "$MULTIVAULT" "isCounterTriple(bytes32)(bool)" "$COUNTER_ID" --rpc-url "$RPC" | trim)
  if [[ "$IS_COUNTER" == "true" ]]; then
    pass "isCounterTriple(counter-triple) = true (precise helper works)"
  else
    fail "isCounterTriple(counter-triple) expected true, got '$IS_COUNTER'"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Pick an atom; verify getVaultType = 0.
# ---------------------------------------------------------------------------

ATOM_RESP=$(gql '{ terms(where:{type:{_eq:Atom}}, limit:1){ id } }')
ATOM_ID=$(echo "$ATOM_RESP" | jq -r '.data.terms[0].id // empty')
if [[ -z "$ATOM_ID" ]]; then
  skip "no atom available for getVaultType check"
else
  VT_ATOM=$(cast call "$MULTIVAULT" "getVaultType(bytes32)(uint8)" "$ATOM_ID" --rpc-url "$RPC" | trim)
  if [[ "$VT_ATOM" == "0" ]]; then
    pass "getVaultType(atom) = 0 (ATOM)"
  else
    fail "getVaultType(atom) expected 0, got '$VT_ATOM' (term $ATOM_ID)"
  fi
fi

# ---------------------------------------------------------------------------
# 5. Polymorphic *_term fragment returns nested-safe shape.
# ---------------------------------------------------------------------------

if [[ -n "${TRIPLE_ID:-}" ]]; then
  POLY=$(gql "{ triple(term_id: \"$TRIPLE_ID\") { term_id subject_term { id type atom { term_id label } triple { term_id } } predicate_term { id type } object_term { id type } } }")
  if echo "$POLY" | jq -e '.errors' >/dev/null 2>&1; then
    fail "polymorphic fragment query errored: $(echo "$POLY" | jq -c '.errors')"
  else
    for slot in subject_term predicate_term object_term; do
      TYPE_VAL=$(echo "$POLY" | jq -r ".data.triple.$slot.type // empty")
      if [[ -n "$TYPE_VAL" ]]; then
        pass "polymorphic fragment: $slot.type = $TYPE_VAL"
      else
        fail "polymorphic fragment: $slot.type missing"
      fi
    done
  fi
else
  skip "no triple available for polymorphic fragment check"
fi

# ---------------------------------------------------------------------------
# 6. Nested fixture renders through *_term and exposes legacy atom-only nulls.
# ---------------------------------------------------------------------------

if [[ -n "$NESTED_TRIPLE_ID" ]]; then
  NESTED_RESP=$(query_nested_triple_by_id "$NESTED_TRIPLE_ID")
  validate_nested_fixture_response "provided nested" "$NESTED_RESP"
else
  NESTED_DISCOVER=$(gql '{ triples(where:{_or:[{subject_term:{type:{_eq:Triple}}},{predicate_term:{type:{_eq:Triple}}},{object_term:{type:{_eq:Triple}}}]}, limit:1){ term_id } }')
  if echo "$NESTED_DISCOVER" | jq -e '.errors' >/dev/null 2>&1; then
    fail "nested fixture discovery errored: $(echo "$NESTED_DISCOVER" | jq -c '.errors')"
  else
    DISCOVERED_NESTED_ID=$(echo "$NESTED_DISCOVER" | jq -r '.data.triples[0].term_id // empty')
    if [[ -z "$DISCOVERED_NESTED_ID" ]]; then
      if [[ "$STRICT_NESTED_FIXTURE" == "1" ]]; then
        fail "no live nested triple fixture found and STRICT_NESTED_FIXTURE=1"
      else
        skip "no live nested triple fixture found; set NESTED_TRIPLE_ID=0x... to validate one"
      fi
    else
      NESTED_RESP=$(query_nested_triple_by_id "$DISCOVERED_NESTED_ID")
      validate_nested_fixture_response "discovered nested" "$NESTED_RESP"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 7. Unknown-ID guard behavior — existence vs type helpers.
#    getVaultType reverts with MultiVaultCore_TermDoesNotExist (selector
#    0xbdd4a699). isTermCreated distinguishes missing terms from created terms.
#    isTriple / isCounterTriple return false for both unknown ids and atom ids,
#    so they cannot be used as existence checks or positive-triple classifiers.
# ---------------------------------------------------------------------------

FAKE_TERM="${FAKE_TERM:-0xdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef}"
TDNE_SELECTOR="0xbdd4a699"

if RAW=$(cast call "$MULTIVAULT" "getVaultType(bytes32)(uint8)" "$FAKE_TERM" --rpc-url "$RPC" 2>&1); then
  fail "getVaultType(unknown) returned '$(echo "$RAW" | trim)' — expected revert with $TDNE_SELECTOR"
else
  if echo "$RAW" | grep -q "$TDNE_SELECTOR"; then
    pass "getVaultType(unknown) reverts with MultiVaultCore_TermDoesNotExist ($TDNE_SELECTOR)"
  else
    fail "getVaultType(unknown) reverted but selector did not match $TDNE_SELECTOR: $(echo "$RAW" | tr '\n' ' ')"
  fi
fi

UNKNOWN_CREATED=$(cast call "$MULTIVAULT" "isTermCreated(bytes32)(bool)" "$FAKE_TERM" --rpc-url "$RPC" | trim)
if [[ "$UNKNOWN_CREATED" == "false" ]]; then
  pass "isTermCreated(unknown) = false (existence guard)"
else
  fail "isTermCreated(unknown) expected false, got '$UNKNOWN_CREATED'"
fi

if [[ -n "${ATOM_ID:-}" ]]; then
  ATOM_CREATED=$(cast call "$MULTIVAULT" "isTermCreated(bytes32)(bool)" "$ATOM_ID" --rpc-url "$RPC" | trim)
  if [[ "$ATOM_CREATED" == "true" ]]; then
    pass "isTermCreated(atom) = true (existence guard distinguishes known atom from unknown id)"
  else
    fail "isTermCreated(atom) expected true, got '$ATOM_CREATED'"
  fi
fi

if [[ -n "${TRIPLE_ID:-}" ]]; then
  TRIPLE_CREATED=$(cast call "$MULTIVAULT" "isTermCreated(bytes32)(bool)" "$TRIPLE_ID" --rpc-url "$RPC" | trim)
  if [[ "$TRIPLE_CREATED" == "true" ]]; then
    pass "isTermCreated(positive triple) = true"
  else
    fail "isTermCreated(positive triple) expected true, got '$TRIPLE_CREATED'"
  fi
fi

TYPE_HELPERS_AMBIGUOUS=1
for helper in "isTriple(bytes32)(bool)" "isCounterTriple(bytes32)(bool)"; do
  UNKNOWN_RES=$(cast call "$MULTIVAULT" "$helper" "$FAKE_TERM" --rpc-url "$RPC" 2>/dev/null | trim || true)
  if [[ "$UNKNOWN_RES" == "false" ]]; then
    pass "$helper(unknown) = false"
  else
    fail "$helper(unknown) expected false, got '$UNKNOWN_RES'"
    TYPE_HELPERS_AMBIGUOUS=0
  fi

  if [[ -n "${ATOM_ID:-}" ]]; then
    ATOM_RES=$(cast call "$MULTIVAULT" "$helper" "$ATOM_ID" --rpc-url "$RPC" 2>/dev/null | trim || true)
    if [[ "$ATOM_RES" == "false" ]]; then
      pass "$helper(atom) = false"
    else
      fail "$helper(atom) expected false, got '$ATOM_RES'"
      TYPE_HELPERS_AMBIGUOUS=0
    fi
  fi
done

if [[ "$TYPE_HELPERS_AMBIGUOUS" == "1" ]]; then
  pass "type-family booleans alone cannot distinguish unknown ids from atoms; pair existence with getVaultType when type intent matters"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "== Summary =="
echo "PASS=$PASS FAIL=$FAIL SKIP=$SKIP"
if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
