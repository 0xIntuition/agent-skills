#!/usr/bin/env bash
set -euo pipefail

# ENG-9713 / ENG-10304: Schema Alignment Regression Tests
#
# Validates the live pin API contract matches what schemas.md documents.
# Tests all three pin mutations, CAIP-10 bypass, response shape, and
# empty-string field requirement (ENG-9725).
#
# Requires: GRAPHQL endpoint (testnet), jq, curl, cast

GRAPHQL="${GRAPHQL:-https://testnet.intuition.sh/v1/graphql}"
RPC="${RPC:-https://testnet.rpc.intuition.systems/http}"
MULTIVAULT="${MULTIVAULT:-0x2Ece8D4dEdcB9918A398528f3fa4688b1d2CAB91}"

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  echo "PASS: $1"
  PASS_COUNT=$((PASS_COUNT + 1))
}

fail() {
  echo "FAIL: $1"
  FAIL_COUNT=$((FAIL_COUNT + 1))
}

check_ipfs_prefix() {
  local uri="$1"
  local label="$2"

  if [[ "$uri" == ipfs://* ]]; then
    pass "$label starts with ipfs://"
  else
    fail "$label missing ipfs:// prefix (got '$uri')"
  fi
}

# Sends a GraphQL request using jq to build the payload safely.
# Usage: gql_post <query_string> <variables_json>
# Returns the raw JSON response on stdout.
gql_post() {
  local query="$1"
  local variables="$2"

  local payload
  payload=$(jq -n --arg q "$query" --argjson v "$variables" '{query: $q, variables: $v}')

  curl -fsS -X POST "$GRAPHQL" \
    -H "Content-Type: application/json" \
    -d "$payload" 2>&1
}

echo "== ENG-9713: Schema Regression Tests =="
echo "GRAPHQL=$GRAPHQL"
echo "RPC=$RPC"
echo "MULTIVAULT=$MULTIVAULT"
echo

# ---------------------------------------------------------------------------
# 2S-1: pinThing round-trip
# All 4 fields accepted (incl empty strings), returns ipfs:// URI
# ---------------------------------------------------------------------------
echo "--- 2S-1: pinThing round-trip ---"

THING_QUERY='mutation pinThing($name: String!, $description: String!, $image: String!, $url: String!) { pinThing(thing: { name: $name, description: $description, image: $image, url: $url }) { uri } }'
THING_VARS='{"name":"schema-regression-test-thing","description":"Regression test entity","image":"","url":""}'

THING_RESPONSE=""
set +e
THING_RESPONSE=$(gql_post "$THING_QUERY" "$THING_VARS")
THING_EXIT=$?
set -e

if [[ "$THING_EXIT" -ne 0 ]] || [[ -z "$THING_RESPONSE" ]]; then
  fail "2S-1 pinThing HTTP request failed"
else
  THING_ERRORS=$(echo "$THING_RESPONSE" | jq -c '.errors // empty')
  if [[ -n "$THING_ERRORS" ]]; then
    fail "2S-1 pinThing GraphQL errors: $THING_ERRORS"
  else
    THING_URI=$(echo "$THING_RESPONSE" | jq -r '.data.pinThing.uri // empty')
    if [[ -n "$THING_URI" ]]; then
      pass "2S-1 pinThing returned URI"
      check_ipfs_prefix "$THING_URI" "2S-1 pinThing URI"

      # Verify URI hex-encodes for createAtoms
      THING_HEX=$(cast --from-utf8 "$THING_URI" 2>/dev/null) || true
      if [[ -n "$THING_HEX" && "$THING_HEX" == 0x* ]]; then
        pass "2S-1 pinThing URI hex-encodes"
      else
        fail "2S-1 pinThing URI hex-encoding failed"
      fi
    else
      fail "2S-1 pinThing returned empty URI"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 2S-2: pinPerson round-trip
# All 6 Person fields accepted, returns valid URI
# ---------------------------------------------------------------------------
echo
echo "--- 2S-2: pinPerson round-trip ---"

PERSON_QUERY='mutation pinPerson($name: String!, $description: String!, $image: String!, $url: String!, $email: String!, $identifier: String!) { pinPerson(person: { name: $name, description: $description, image: $image, url: $url, email: $email, identifier: $identifier }) { uri } }'
PERSON_VARS='{"name":"schema-regression-test-person","description":"Test person entity","image":"","url":"","email":"","identifier":""}'

PERSON_RESPONSE=""
set +e
PERSON_RESPONSE=$(gql_post "$PERSON_QUERY" "$PERSON_VARS")
PERSON_EXIT=$?
set -e

if [[ "$PERSON_EXIT" -ne 0 ]] || [[ -z "$PERSON_RESPONSE" ]]; then
  fail "2S-2 pinPerson HTTP request failed"
else
  PERSON_ERRORS=$(echo "$PERSON_RESPONSE" | jq -c '.errors // empty')
  if [[ -n "$PERSON_ERRORS" ]]; then
    fail "2S-2 pinPerson GraphQL errors: $PERSON_ERRORS"
  else
    PERSON_URI=$(echo "$PERSON_RESPONSE" | jq -r '.data.pinPerson.uri // empty')
    if [[ -n "$PERSON_URI" ]]; then
      pass "2S-2 pinPerson returned URI"
      check_ipfs_prefix "$PERSON_URI" "2S-2 pinPerson URI"
    else
      fail "2S-2 pinPerson returned empty URI"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 2S-3: pinOrganization round-trip
# All 5 Org fields accepted, returns valid URI
# ---------------------------------------------------------------------------
echo
echo "--- 2S-3: pinOrganization round-trip ---"

ORG_QUERY='mutation pinOrganization($name: String!, $description: String!, $image: String!, $url: String!, $email: String!) { pinOrganization(organization: { name: $name, description: $description, image: $image, url: $url, email: $email }) { uri } }'
ORG_VARS='{"name":"schema-regression-test-org","description":"Test org entity","image":"","url":"","email":""}'

ORG_RESPONSE=""
set +e
ORG_RESPONSE=$(gql_post "$ORG_QUERY" "$ORG_VARS")
ORG_EXIT=$?
set -e

if [[ "$ORG_EXIT" -ne 0 ]] || [[ -z "$ORG_RESPONSE" ]]; then
  fail "2S-3 pinOrganization HTTP request failed"
else
  ORG_ERRORS=$(echo "$ORG_RESPONSE" | jq -c '.errors // empty')
  if [[ -n "$ORG_ERRORS" ]]; then
    fail "2S-3 pinOrganization GraphQL errors: $ORG_ERRORS"
  else
    ORG_URI=$(echo "$ORG_RESPONSE" | jq -r '.data.pinOrganization.uri // empty')
    if [[ -n "$ORG_URI" ]]; then
      pass "2S-3 pinOrganization returned URI"
      check_ipfs_prefix "$ORG_URI" "2S-3 pinOrganization URI"
    else
      fail "2S-3 pinOrganization returned empty URI"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 2S-4: CAIP-10 bypass
# Blockchain address encodes to atom ID without pinning
# ---------------------------------------------------------------------------
echo
echo "--- 2S-4: CAIP-10 bypass ---"

CAIP10_URI="caip10:eip155:1:0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045"
CAIP10_HEX=$(cast --from-utf8 "$CAIP10_URI" 2>/dev/null) || true
if [[ -n "$CAIP10_HEX" && "$CAIP10_HEX" == 0x* ]]; then
  pass "2S-4 CAIP-10 encodes without pin"

  set +e
  CAIP10_ATOM_ID=$(cast call "$MULTIVAULT" "calculateAtomId(bytes)(bytes32)" "$CAIP10_HEX" --rpc-url "$RPC" 2>/dev/null)
  CAIP10_EXIT=$?
  set -e
  if [[ "$CAIP10_EXIT" -eq 0 ]] && [[ -n "$CAIP10_ATOM_ID" && "$CAIP10_ATOM_ID" == 0x* ]]; then
    pass "2S-4 CAIP-10 produces valid atom ID"
  else
    fail "2S-4 CAIP-10 calculateAtomId failed"
  fi
else
  fail "2S-4 CAIP-10 hex encoding failed"
fi

# ---------------------------------------------------------------------------
# 2S-5: Response contract shape
# All 3 mutations return { data: { pin<Type>: { uri } } } shape
# ---------------------------------------------------------------------------
echo
echo "--- 2S-5: Response contract shape ---"

if [[ -n "${THING_RESPONSE:-}" ]]; then
  if echo "$THING_RESPONSE" | jq -e '.data.pinThing.uri' >/dev/null 2>&1; then
    pass "2S-5 pinThing response shape: data.pinThing.uri"
  else
    fail "2S-5 pinThing response shape mismatch"
  fi
else
  fail "2S-5 pinThing no response to check"
fi

if [[ -n "${PERSON_RESPONSE:-}" ]]; then
  if echo "$PERSON_RESPONSE" | jq -e '.data.pinPerson.uri' >/dev/null 2>&1; then
    pass "2S-5 pinPerson response shape: data.pinPerson.uri"
  else
    fail "2S-5 pinPerson response shape mismatch"
  fi
else
  fail "2S-5 pinPerson no response to check"
fi

if [[ -n "${ORG_RESPONSE:-}" ]]; then
  if echo "$ORG_RESPONSE" | jq -e '.data.pinOrganization.uri' >/dev/null 2>&1; then
    pass "2S-5 pinOrganization response shape: data.pinOrganization.uri"
  else
    fail "2S-5 pinOrganization response shape mismatch"
  fi
else
  fail "2S-5 pinOrganization no response to check"
fi

# ---------------------------------------------------------------------------
# 2S-6: Empty string field requirement (ENG-9725)
# Omitting a field causes Request Transformation Failed error
# ---------------------------------------------------------------------------
echo
echo "--- 2S-6: Empty string field requirement ---"

# Attempt pinThing with MISSING url field (only 3 of 4 fields)
MISSING_QUERY='mutation pinThing($name: String!, $description: String!, $image: String!) { pinThing(thing: { name: $name, description: $description, image: $image }) { uri } }'
MISSING_VARS='{"name":"missing-field-test","description":"test","image":""}'

MISSING_RESPONSE=""
set +e
MISSING_RESPONSE=$(gql_post "$MISSING_QUERY" "$MISSING_VARS")
MISSING_EXIT=$?
set -e

if [[ "$MISSING_EXIT" -ne 0 ]] || [[ -z "$MISSING_RESPONSE" ]]; then
  pass "2S-6 omitted field caused HTTP-level failure"
else
  MISSING_ERRORS=$(echo "$MISSING_RESPONSE" | jq -c '.errors // empty')
  MISSING_URI=$(echo "$MISSING_RESPONSE" | jq -r '.data.pinThing.uri // empty' 2>/dev/null || echo "")

  if [[ -n "$MISSING_ERRORS" ]] || [[ -z "$MISSING_URI" ]]; then
    pass "2S-6 omitted field causes error or empty URI"
  else
    fail "2S-6 omitted field unexpectedly succeeded with URI: $MISSING_URI"
  fi
fi

echo
echo "Summary: PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
