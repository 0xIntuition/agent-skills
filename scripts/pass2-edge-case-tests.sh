#!/usr/bin/env bash
set -euo pipefail

# Edge-case verification aligned to Intuition skill docs.
# Requires RPC access but does not require signing.

export FOUNDRY_DISABLE_NIGHTLY_WARNING="${FOUNDRY_DISABLE_NIGHTLY_WARNING:-1}"

RPC="${RPC:-https://rpc.intuition.systems/http}"
MULTIVAULT="${MULTIVAULT:-0x6E35cF57A41fA15eA0EaE9C33e751b01A784Fe7e}"
SENDER="${SENDER:-$MULTIVAULT}"
MULTIVAULT_ATOM_EXISTS_SELECTOR="0xb4856ebc"
MULTIVAULT_TERM_DOES_NOT_EXIST_SELECTOR="0x4762af7d"

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

expect_contains() {
  local output="$1"
  local needle="$2"
  local label="$3"
  if [[ "$output" == *"$needle"* ]]; then
    pass "$label contains $needle"
  else
    fail "$label missing $needle"
    echo "Output was:"
    echo "$output"
  fi
}

normalize_cast_uint() {
  awk 'NF { print $1; exit }'
}

echo "== Pass 2: Edge Case Tests =="
echo "RPC=$RPC"
echo "MULTIVAULT=$MULTIVAULT"

ATOM_COST=$(cast call "$MULTIVAULT" "getAtomCost()(uint256)" --rpc-url "$RPC" | normalize_cast_uint)
TRIPLE_COST=$(cast call "$MULTIVAULT" "getTripleCost()(uint256)" --rpc-url "$RPC" | normalize_cast_uint)
CURVE_ID=$(cast call "$MULTIVAULT" "getBondingCurveConfig()((address,uint256))" --rpc-url "$RPC" | awk -F', ' '{print $2}' | tr -d ')' | normalize_cast_uint)
pass "queried atom/triple cost and curve id"

# Edge 1: Existing atom should already exist and simulated create should revert
ATOM_IS_HEX=$(cast --from-utf8 "is")
ATOM_IS_ID=$(cast call "$MULTIVAULT" "calculateAtomId(bytes)(bytes32)" "$ATOM_IS_HEX" --rpc-url "$RPC")
ATOM_IS_EXISTS=$(cast call "$MULTIVAULT" "isTermCreated(bytes32)(bool)" "$ATOM_IS_ID" --rpc-url "$RPC")
if [[ "$ATOM_IS_EXISTS" == "true" ]]; then
  pass "known atom 'is' exists"
else
  fail "known atom 'is' does not exist unexpectedly"
fi

set +e
CREATE_ATOM_REVERT=$(cast call "$MULTIVAULT" "createAtoms(bytes[],uint256[])(bytes32[])" "[$ATOM_IS_HEX]" "[$ATOM_COST]" --value "$ATOM_COST" --from "$SENDER" --rpc-url "$RPC" 2>&1)
CREATE_ATOM_CODE=$?
set -e
if [[ "$CREATE_ATOM_CODE" -ne 0 ]]; then
  pass "createAtoms(existing atom) reverted as expected"
else
  fail "createAtoms(existing atom) unexpectedly succeeded"
fi
expect_contains "$CREATE_ATOM_REVERT" "$MULTIVAULT_ATOM_EXISTS_SELECTOR" "createAtoms(existing atom) MultiVault_AtomExists revert"

# Edge 2: Missing triple component term should revert
MISSING_SUBJECT="0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
MISSING_PREDICATE="0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
MISSING_OBJECT="0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

SUBJECT_EXISTS=$(cast call "$MULTIVAULT" "isTermCreated(bytes32)(bool)" "$MISSING_SUBJECT" --rpc-url "$RPC")
PREDICATE_EXISTS=$(cast call "$MULTIVAULT" "isTermCreated(bytes32)(bool)" "$MISSING_PREDICATE" --rpc-url "$RPC")
OBJECT_EXISTS=$(cast call "$MULTIVAULT" "isTermCreated(bytes32)(bool)" "$MISSING_OBJECT" --rpc-url "$RPC")
expect_contains "$SUBJECT_EXISTS$PREDICATE_EXISTS$OBJECT_EXISTS" "false" "missing triple component precheck"

set +e
CREATE_TRIPLE_REVERT=$(cast call "$MULTIVAULT" "createTriples(bytes32[],bytes32[],bytes32[],uint256[])(bytes32[])" "[$MISSING_SUBJECT]" "[$MISSING_PREDICATE]" "[$MISSING_OBJECT]" "[$TRIPLE_COST]" --value "$TRIPLE_COST" --from "$SENDER" --rpc-url "$RPC" 2>&1)
CREATE_TRIPLE_CODE=$?
set -e
if [[ "$CREATE_TRIPLE_CODE" -ne 0 ]]; then
  pass "createTriples(missing terms) reverted as expected"
else
  fail "createTriples(missing terms) unexpectedly succeeded"
fi
expect_contains "$CREATE_TRIPLE_REVERT" "$MULTIVAULT_TERM_DOES_NOT_EXIST_SELECTOR" "createTriples(missing terms) MultiVault_TermDoesNotExist revert"

# Edge 3: Counter-triple computation flow consistency
ALICE_ID=$(cast call "$MULTIVAULT" "calculateAtomId(bytes)(bytes32)" "$(cast --from-utf8 "Alice")" --rpc-url "$RPC")
TRUSTS_ID=$(cast call "$MULTIVAULT" "calculateAtomId(bytes)(bytes32)" "$(cast --from-utf8 "trusts")" --rpc-url "$RPC")
BOB_ID=$(cast call "$MULTIVAULT" "calculateAtomId(bytes)(bytes32)" "$(cast --from-utf8 "Bob")" --rpc-url "$RPC")

TRIPLE_ID=$(cast call "$MULTIVAULT" "calculateTripleId(bytes32,bytes32,bytes32)(bytes32)" "$ALICE_ID" "$TRUSTS_ID" "$BOB_ID" --rpc-url "$RPC")
COUNTER_A=$(cast call "$MULTIVAULT" "getCounterIdFromTripleId(bytes32)(bytes32)" "$TRIPLE_ID" --rpc-url "$RPC")
COUNTER_B=$(cast call "$MULTIVAULT" "calculateCounterTripleId(bytes32,bytes32,bytes32)(bytes32)" "$ALICE_ID" "$TRUSTS_ID" "$BOB_ID" --rpc-url "$RPC")
if [[ "$COUNTER_A" == "$COUNTER_B" ]]; then
  pass "counter-triple derivation is consistent"
else
  fail "counter-triple derivation mismatch"
  echo "getCounterIdFromTripleId: $COUNTER_A"
  echo "calculateCounterTripleId: $COUNTER_B"
fi

# Edge 4: redeemBatch calldata encoding/decode sanity
RECEIVER="0x1111111111111111111111111111111111111111"
TERM_1="0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
TERM_2="0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
REDEEM_BATCH_SIG="redeemBatch(address,bytes32[],uint256[],uint256[],uint256[])"
REDEEM_BATCH_DATA=$(cast calldata "$REDEEM_BATCH_SIG" "$RECEIVER" "[$TERM_1,$TERM_2]" "[$CURVE_ID,$CURVE_ID]" "[111,222]" "[0,0]")
REDEEM_BATCH_DECODED=$(cast calldata-decode "$REDEEM_BATCH_SIG" "$REDEEM_BATCH_DATA")
expect_contains "$REDEEM_BATCH_DECODED" "$TERM_1" "redeemBatch decode"
expect_contains "$REDEEM_BATCH_DECODED" "$TERM_2" "redeemBatch decode"

# Edge 5: batch createAtoms calldata encoding/decode sanity
BATCH_CREATE_SIG="createAtoms(bytes[],uint256[])"
ATOM_A=$(cast --from-utf8 "Alice")
ATOM_B=$(cast --from-utf8 "trusts")
ATOM_C=$(cast --from-utf8 "Bob")
BATCH_CREATE_DATA=$(cast calldata "$BATCH_CREATE_SIG" "[$ATOM_A,$ATOM_B,$ATOM_C]" "[$ATOM_COST,$ATOM_COST,$ATOM_COST]")
BATCH_CREATE_DECODED=$(cast calldata-decode "$BATCH_CREATE_SIG" "$BATCH_CREATE_DATA")
expect_contains "$BATCH_CREATE_DECODED" "$ATOM_A" "batch createAtoms decode"
expect_contains "$BATCH_CREATE_DECODED" "$ATOM_B" "batch createAtoms decode"
expect_contains "$BATCH_CREATE_DECODED" "$ATOM_C" "batch createAtoms decode"

echo
echo "Summary: PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
