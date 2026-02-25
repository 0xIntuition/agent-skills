#!/usr/bin/env bash
set -euo pipefail

# Pass 2 manual calldata verification:
# - encode calldata with cast
# - verify selector prefix
# - decode calldata back with cast calldata-decode
# - verify decoded output contains expected arguments
#
# This script is local-only and does not require RPC.

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

check_contains() {
  local haystack="$1"
  local needle="$2"
  local label="$3"

  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$label contains $needle"
  else
    fail "$label missing $needle"
  fi
}

check_selector() {
  local calldata="$1"
  local signature="$2"
  local label="$3"

  local selector
  selector=$(cast sig "$signature")
  local prefix
  prefix="${calldata:0:10}"

  if [[ "$prefix" == "$selector" ]]; then
    pass "$label selector $selector"
  else
    fail "$label selector mismatch (got $prefix expected $selector)"
  fi
}

echo "== Pass 2: Manual Calldata Verification =="

# Stable test constants
RECEIVER="0x1111111111111111111111111111111111111111"
TERM_ID_1="0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
TERM_ID_2="0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
CURVE_ID="1"
SHARES="123456789000000000"
ASSET_1="1000000000000000"
ASSET_2="2000000000000000"
ATOM_COST="100000000001000000"
TRIPLE_COST="100000000001000000"

SUBJECT_ID="0x0101010101010101010101010101010101010101010101010101010101010101"
PREDICATE_ID="0x0202020202020202020202020202020202020202020202020202020202020202"
OBJECT_ID="0x0303030303030303030303030303030303030303030303030303030303030303"

# 1) createAtoms
SIG_CREATE_ATOMS="createAtoms(bytes[],uint256[])"
CALLDATA_CREATE_ATOMS=$(cast calldata "$SIG_CREATE_ATOMS" "[0x457468657265756d]" "[$ATOM_COST]")
DECODED_CREATE_ATOMS=$(cast calldata-decode "$SIG_CREATE_ATOMS" "$CALLDATA_CREATE_ATOMS")
check_selector "$CALLDATA_CREATE_ATOMS" "$SIG_CREATE_ATOMS" "createAtoms"
check_contains "$DECODED_CREATE_ATOMS" "0x457468657265756d" "createAtoms decoded"
check_contains "$DECODED_CREATE_ATOMS" "$ATOM_COST" "createAtoms decoded"

# 2) createTriples
SIG_CREATE_TRIPLES="createTriples(bytes32[],bytes32[],bytes32[],uint256[])"
CALLDATA_CREATE_TRIPLES=$(cast calldata "$SIG_CREATE_TRIPLES" "[$SUBJECT_ID]" "[$PREDICATE_ID]" "[$OBJECT_ID]" "[$TRIPLE_COST]")
DECODED_CREATE_TRIPLES=$(cast calldata-decode "$SIG_CREATE_TRIPLES" "$CALLDATA_CREATE_TRIPLES")
check_selector "$CALLDATA_CREATE_TRIPLES" "$SIG_CREATE_TRIPLES" "createTriples"
check_contains "$DECODED_CREATE_TRIPLES" "$SUBJECT_ID" "createTriples decoded"
check_contains "$DECODED_CREATE_TRIPLES" "$PREDICATE_ID" "createTriples decoded"
check_contains "$DECODED_CREATE_TRIPLES" "$OBJECT_ID" "createTriples decoded"
check_contains "$DECODED_CREATE_TRIPLES" "$TRIPLE_COST" "createTriples decoded"

# 3) deposit
SIG_DEPOSIT="deposit(address,bytes32,uint256,uint256)"
CALLDATA_DEPOSIT=$(cast calldata "$SIG_DEPOSIT" "$RECEIVER" "$TERM_ID_1" "$CURVE_ID" "0")
DECODED_DEPOSIT=$(cast calldata-decode "$SIG_DEPOSIT" "$CALLDATA_DEPOSIT")
check_selector "$CALLDATA_DEPOSIT" "$SIG_DEPOSIT" "deposit"
check_contains "$DECODED_DEPOSIT" "$RECEIVER" "deposit decoded"
check_contains "$DECODED_DEPOSIT" "$TERM_ID_1" "deposit decoded"

# 4) redeem
SIG_REDEEM="redeem(address,bytes32,uint256,uint256,uint256)"
CALLDATA_REDEEM=$(cast calldata "$SIG_REDEEM" "$RECEIVER" "$TERM_ID_1" "$CURVE_ID" "$SHARES" "0")
DECODED_REDEEM=$(cast calldata-decode "$SIG_REDEEM" "$CALLDATA_REDEEM")
check_selector "$CALLDATA_REDEEM" "$SIG_REDEEM" "redeem"
check_contains "$DECODED_REDEEM" "$RECEIVER" "redeem decoded"
check_contains "$DECODED_REDEEM" "$TERM_ID_1" "redeem decoded"
check_contains "$DECODED_REDEEM" "$SHARES" "redeem decoded"

# 5) depositBatch
SIG_DEPOSIT_BATCH="depositBatch(address,bytes32[],uint256[],uint256[],uint256[])"
CALLDATA_DEPOSIT_BATCH=$(cast calldata "$SIG_DEPOSIT_BATCH" "$RECEIVER" "[$TERM_ID_1,$TERM_ID_2]" "[$CURVE_ID,$CURVE_ID]" "[$ASSET_1,$ASSET_2]" "[0,0]")
DECODED_DEPOSIT_BATCH=$(cast calldata-decode "$SIG_DEPOSIT_BATCH" "$CALLDATA_DEPOSIT_BATCH")
check_selector "$CALLDATA_DEPOSIT_BATCH" "$SIG_DEPOSIT_BATCH" "depositBatch"
check_contains "$DECODED_DEPOSIT_BATCH" "$TERM_ID_1" "depositBatch decoded"
check_contains "$DECODED_DEPOSIT_BATCH" "$TERM_ID_2" "depositBatch decoded"
check_contains "$DECODED_DEPOSIT_BATCH" "$ASSET_1" "depositBatch decoded"
check_contains "$DECODED_DEPOSIT_BATCH" "$ASSET_2" "depositBatch decoded"

# 6) redeemBatch
SIG_REDEEM_BATCH="redeemBatch(address,bytes32[],uint256[],uint256[],uint256[])"
CALLDATA_REDEEM_BATCH=$(cast calldata "$SIG_REDEEM_BATCH" "$RECEIVER" "[$TERM_ID_1,$TERM_ID_2]" "[$CURVE_ID,$CURVE_ID]" "[111,222]" "[0,0]")
DECODED_REDEEM_BATCH=$(cast calldata-decode "$SIG_REDEEM_BATCH" "$CALLDATA_REDEEM_BATCH")
check_selector "$CALLDATA_REDEEM_BATCH" "$SIG_REDEEM_BATCH" "redeemBatch"
check_contains "$DECODED_REDEEM_BATCH" "$TERM_ID_1" "redeemBatch decoded"
check_contains "$DECODED_REDEEM_BATCH" "$TERM_ID_2" "redeemBatch decoded"
check_contains "$DECODED_REDEEM_BATCH" "111" "redeemBatch decoded"
check_contains "$DECODED_REDEEM_BATCH" "222" "redeemBatch decoded"

echo
echo "Summary: PASS=$PASS_COUNT FAIL=$FAIL_COUNT"
if [[ "$FAIL_COUNT" -gt 0 ]]; then
  exit 1
fi
