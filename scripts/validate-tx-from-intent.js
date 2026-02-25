#!/usr/bin/env node
'use strict'

const fs = require('fs')
const path = require('path')
const { execFileSync } = require('child_process')

function usage() {
  console.log(`validate-tx-from-intent

Usage:
  node scripts/validate-tx-from-intent.js \\
    --intent <intent.json> \\
    --tx <unsigned-tx.json> \\
    [--policy <policy.json>] \\
    [--rpc <rpc-url>] \\
    [--from <sender-address>] \\
    [--spent-today-wei <wei>] \\
    [--pending-count <n>]

Notes:
  - If --policy is omitted, defaults to INTUITION_POLICY_PATH or ./.intuition/autonomous-policy.json
  - If policy.execution.requireSimulation=true, both --rpc and --from are required
  - Exit codes:
      0 = pass (safe to sign)
      1 = validation fail/error
      2 = approval required (do not sign)`)
}

function parseArgs(argv) {
  const args = {}
  for (let i = 0; i < argv.length; i += 1) {
    const a = argv[i]
    if (a === '--help' || a === '-h') {
      args.help = true
      continue
    }
    if (!a.startsWith('--')) {
      throw new Error(`unexpected arg: ${a}`)
    }
    const key = a.slice(2)
    const value = argv[i + 1]
    if (!value || value.startsWith('--')) {
      throw new Error(`missing value for --${key}`)
    }
    args[key] = value
    i += 1
  }
  return args
}

function readJson(file) {
  const raw = fs.readFileSync(file, 'utf8')
  return JSON.parse(raw)
}

function toBigInt(v, field) {
  if (typeof v === 'bigint') return v
  if (typeof v === 'number' && Number.isInteger(v) && v >= 0) return BigInt(v)
  if (typeof v === 'string') {
    if (v.startsWith('0x')) return BigInt(v)
    if (/^\d+$/.test(v)) return BigInt(v)
  }
  throw new Error(`invalid bigint field: ${field}`)
}

function isAddress(v) {
  return typeof v === 'string' && /^0x[0-9a-fA-F]{40}$/.test(v)
}

function isBytes32(v) {
  return typeof v === 'string' && /^0x[0-9a-fA-F]{64}$/.test(v)
}

function isHex(v) {
  return typeof v === 'string' && /^0x[0-9a-fA-F]*$/.test(v) && v.length % 2 === 0
}

function lower(v) {
  return typeof v === 'string' ? v.toLowerCase() : v
}

function arr(values) {
  return `[${values.join(',')}]`
}

function runCast(args) {
  return execFileSync('cast', args, { encoding: 'utf8' }).trim()
}

function operationSpec(intent) {
  const op = intent.operation
  const inputs = intent.inputs || {}

  switch (op) {
    case 'createAtoms': {
      const atomDatasHex = inputs.atomDatasHex
      const assetsWei = inputs.assetsWei
      if (!Array.isArray(atomDatasHex) || atomDatasHex.length === 0) throw new Error('createAtoms requires non-empty inputs.atomDatasHex[]')
      if (!Array.isArray(assetsWei) || assetsWei.length !== atomDatasHex.length) throw new Error('createAtoms requires inputs.assetsWei[] same length as atomDatasHex[]')
      atomDatasHex.forEach((v, i) => {
        if (!isHex(v)) throw new Error(`createAtoms atomDatasHex[${i}] must be hex bytes`)
      })
      const assets = assetsWei.map((v, i) => toBigInt(v, `inputs.assetsWei[${i}]`))
      const value = assets.reduce((sum, v) => sum + v, 0n)
      return {
        op,
        signature: 'createAtoms(bytes[],uint256[])',
        calldataArgs: [arr(atomDatasHex), arr(assets.map(String))],
        expectedValue: value,
        termIdsToCheck: [],
        tripleAtomsToCheck: [],
      }
    }
    case 'createTriples': {
      const subjectIds = inputs.subjectIds
      const predicateIds = inputs.predicateIds
      const objectIds = inputs.objectIds
      const assetsWei = inputs.assetsWei
      if (!Array.isArray(subjectIds) || subjectIds.length === 0) throw new Error('createTriples requires non-empty inputs.subjectIds[]')
      if (!Array.isArray(predicateIds) || predicateIds.length !== subjectIds.length) throw new Error('createTriples requires inputs.predicateIds[] same length as subjectIds[]')
      if (!Array.isArray(objectIds) || objectIds.length !== subjectIds.length) throw new Error('createTriples requires inputs.objectIds[] same length as subjectIds[]')
      if (!Array.isArray(assetsWei) || assetsWei.length !== subjectIds.length) throw new Error('createTriples requires inputs.assetsWei[] same length as subjectIds[]')
      subjectIds.forEach((v, i) => { if (!isBytes32(v)) throw new Error(`subjectIds[${i}] must be bytes32`) })
      predicateIds.forEach((v, i) => { if (!isBytes32(v)) throw new Error(`predicateIds[${i}] must be bytes32`) })
      objectIds.forEach((v, i) => { if (!isBytes32(v)) throw new Error(`objectIds[${i}] must be bytes32`) })
      const assets = assetsWei.map((v, i) => toBigInt(v, `inputs.assetsWei[${i}]`))
      const value = assets.reduce((sum, v) => sum + v, 0n)
      const tripleAtomsToCheck = []
      for (let i = 0; i < subjectIds.length; i += 1) {
        tripleAtomsToCheck.push(subjectIds[i], predicateIds[i], objectIds[i])
      }
      return {
        op,
        signature: 'createTriples(bytes32[],bytes32[],bytes32[],uint256[])',
        calldataArgs: [arr(subjectIds), arr(predicateIds), arr(objectIds), arr(assets.map(String))],
        expectedValue: value,
        termIdsToCheck: [],
        tripleAtomsToCheck,
      }
    }
    case 'deposit': {
      const receiver = inputs.receiver
      const termId = inputs.termId
      const curveId = toBigInt(inputs.curveId, 'inputs.curveId')
      const minShares = toBigInt(inputs.minShares ?? '0', 'inputs.minShares')
      const amountWei = toBigInt(inputs.amountWei, 'inputs.amountWei')
      if (!isAddress(receiver)) throw new Error('deposit inputs.receiver must be address')
      if (!isBytes32(termId)) throw new Error('deposit inputs.termId must be bytes32')
      return {
        op,
        signature: 'deposit(address,bytes32,uint256,uint256)',
        calldataArgs: [receiver, termId, String(curveId), String(minShares)],
        expectedValue: amountWei,
        termIdsToCheck: [termId],
        tripleAtomsToCheck: [],
      }
    }
    case 'redeem': {
      const receiver = inputs.receiver
      const termId = inputs.termId
      const curveId = toBigInt(inputs.curveId, 'inputs.curveId')
      const shares = toBigInt(inputs.shares, 'inputs.shares')
      const minAssets = toBigInt(inputs.minAssets ?? '0', 'inputs.minAssets')
      if (!isAddress(receiver)) throw new Error('redeem inputs.receiver must be address')
      if (!isBytes32(termId)) throw new Error('redeem inputs.termId must be bytes32')
      return {
        op,
        signature: 'redeem(address,bytes32,uint256,uint256,uint256)',
        calldataArgs: [receiver, termId, String(curveId), String(shares), String(minAssets)],
        expectedValue: 0n,
        termIdsToCheck: [termId],
        tripleAtomsToCheck: [],
      }
    }
    case 'depositBatch': {
      const receiver = inputs.receiver
      const termIds = inputs.termIds
      const curveIds = inputs.curveIds
      const assetsWei = inputs.assetsWei
      const minShares = inputs.minShares ?? []
      if (!isAddress(receiver)) throw new Error('depositBatch inputs.receiver must be address')
      if (!Array.isArray(termIds) || termIds.length === 0) throw new Error('depositBatch requires non-empty inputs.termIds[]')
      if (!Array.isArray(curveIds) || curveIds.length !== termIds.length) throw new Error('depositBatch requires curveIds[] same length as termIds[]')
      if (!Array.isArray(assetsWei) || assetsWei.length !== termIds.length) throw new Error('depositBatch requires assetsWei[] same length as termIds[]')
      if (!Array.isArray(minShares) || minShares.length !== termIds.length) throw new Error('depositBatch requires minShares[] same length as termIds[]')
      termIds.forEach((v, i) => { if (!isBytes32(v)) throw new Error(`termIds[${i}] must be bytes32`) })
      const curveIdBig = curveIds.map((v, i) => toBigInt(v, `inputs.curveIds[${i}]`))
      const assets = assetsWei.map((v, i) => toBigInt(v, `inputs.assetsWei[${i}]`))
      const mins = minShares.map((v, i) => toBigInt(v, `inputs.minShares[${i}]`))
      const value = assets.reduce((sum, v) => sum + v, 0n)
      return {
        op,
        signature: 'depositBatch(address,bytes32[],uint256[],uint256[],uint256[])',
        calldataArgs: [receiver, arr(termIds), arr(curveIdBig.map(String)), arr(assets.map(String)), arr(mins.map(String))],
        expectedValue: value,
        termIdsToCheck: termIds,
        tripleAtomsToCheck: [],
      }
    }
    case 'redeemBatch': {
      const receiver = inputs.receiver
      const termIds = inputs.termIds
      const curveIds = inputs.curveIds
      const shares = inputs.shares
      const minAssets = inputs.minAssets ?? []
      if (!isAddress(receiver)) throw new Error('redeemBatch inputs.receiver must be address')
      if (!Array.isArray(termIds) || termIds.length === 0) throw new Error('redeemBatch requires non-empty inputs.termIds[]')
      if (!Array.isArray(curveIds) || curveIds.length !== termIds.length) throw new Error('redeemBatch requires curveIds[] same length as termIds[]')
      if (!Array.isArray(shares) || shares.length !== termIds.length) throw new Error('redeemBatch requires shares[] same length as termIds[]')
      if (!Array.isArray(minAssets) || minAssets.length !== termIds.length) throw new Error('redeemBatch requires minAssets[] same length as termIds[]')
      termIds.forEach((v, i) => { if (!isBytes32(v)) throw new Error(`termIds[${i}] must be bytes32`) })
      const curveIdBig = curveIds.map((v, i) => toBigInt(v, `inputs.curveIds[${i}]`))
      const sharesBig = shares.map((v, i) => toBigInt(v, `inputs.shares[${i}]`))
      const mins = minAssets.map((v, i) => toBigInt(v, `inputs.minAssets[${i}]`))
      return {
        op,
        signature: 'redeemBatch(address,bytes32[],uint256[],uint256[],uint256[])',
        calldataArgs: [receiver, arr(termIds), arr(curveIdBig.map(String)), arr(sharesBig.map(String)), arr(mins.map(String))],
        expectedValue: 0n,
        termIdsToCheck: termIds,
        tripleAtomsToCheck: [],
      }
    }
    default:
      throw new Error(`unsupported operation: ${op}`)
  }
}

function validateUnsignedTxSchema(tx) {
  const keys = Object.keys(tx).sort()
  const expected = ['chainId', 'data', 'to', 'value']
  if (JSON.stringify(keys) !== JSON.stringify(expected)) {
    throw new Error(`tx must contain exactly keys ${expected.join(',')}`)
  }
  if (!isAddress(tx.to)) throw new Error('tx.to must be address')
  if (!isHex(tx.data)) throw new Error('tx.data must be hex')
  if (tx.data.length < 10) throw new Error('tx.data must include a selector')
  toBigInt(tx.value, 'tx.value')
  toBigInt(tx.chainId, 'tx.chainId')
}

function getPolicyPath(cliPolicy) {
  if (cliPolicy) return cliPolicy
  if (process.env.INTUITION_POLICY_PATH) return process.env.INTUITION_POLICY_PATH
  return path.resolve('.intuition', 'autonomous-policy.json')
}

function approvalDecision(policy, intent, txValue) {
  const mode = typeof policy.mode === 'string' ? policy.mode : 'manual-review'
  const reasons = []

  if (!['strict', 'permissive', 'manual-review'].includes(mode)) {
    reasons.push(`unsupported policy mode: ${mode}`)
  }

  if (mode === 'manual-review') {
    reasons.push('policy mode requires manual review for all writes')
  }

  const requireReviewOps = Array.isArray(policy.approval?.requireReviewForOperations)
    ? policy.approval.requireReviewForOperations
    : []
  if (requireReviewOps.includes(intent.operation)) {
    reasons.push(`operation ${intent.operation} requires review by policy`)
  }

  if (policy.approval?.autoApproveUpToWei !== undefined) {
    const autoApproveUpToWei = toBigInt(policy.approval.autoApproveUpToWei, 'policy.approval.autoApproveUpToWei')
    if (txValue > autoApproveUpToWei) {
      reasons.push(`tx value ${txValue} exceeds auto-approve threshold ${autoApproveUpToWei}`)
    }
  }

  return {
    mode,
    requiresApproval: reasons.length > 0,
    reasons,
  }
}

function main() {
  const args = parseArgs(process.argv.slice(2))
  if (args.help) {
    usage()
    return
  }
  if (!args.intent || !args.tx) {
    usage()
    throw new Error('--intent and --tx are required')
  }

  const policyPath = getPolicyPath(args.policy)
  const intent = readJson(args.intent)
  const tx = readJson(args.tx)
  const policy = readJson(policyPath)

  const checks = {}
  const failures = []

  try {
    validateUnsignedTxSchema(tx)
    checks.txSchema = 'pass'
  } catch (err) {
    failures.push(`tx schema: ${err.message}`)
    checks.txSchema = 'fail'
  }

  if (!intent || typeof intent !== 'object') {
    failures.push('intent must be an object')
  }
  if (typeof intent.operation !== 'string') {
    failures.push('intent.operation must be string')
  }
  if (!intent.inputs || typeof intent.inputs !== 'object') {
    failures.push('intent.inputs must be object')
  }

  const chainId = (() => {
    try {
      return toBigInt(intent.chainId, 'intent.chainId')
    } catch (_e) {
      failures.push('intent.chainId missing/invalid')
      return null
    }
  })()

  const txChainId = (() => {
    try {
      return toBigInt(tx.chainId, 'tx.chainId')
    } catch (_e) {
      failures.push('tx.chainId missing/invalid')
      return null
    }
  })()

  if (chainId !== null && txChainId !== null) {
    if (chainId !== txChainId) {
      failures.push(`chainId mismatch: intent=${chainId} tx=${txChainId}`)
      checks.chainMatch = 'fail'
    } else {
      checks.chainMatch = 'pass'
    }
  }

  if (policy.integrity && policy.integrity.rejectExternallyProvidedTxFields) {
    const forbidden = ['to', 'data', 'value']
    const present = forbidden.filter((k) => Object.prototype.hasOwnProperty.call(intent, k))
    if (present.length > 0) {
      failures.push(`intent contains forbidden tx fields: ${present.join(',')}`)
      checks.intentBoundary = 'fail'
    } else {
      checks.intentBoundary = 'pass'
    }
  }

  let spec = null
  try {
    spec = operationSpec(intent)
    checks.intentSchema = 'pass'
  } catch (err) {
    failures.push(`intent schema: ${err.message}`)
    checks.intentSchema = 'fail'
  }

  const policyChains = Array.isArray(policy.allow?.chains) ? policy.allow.chains.map((v) => BigInt(v)) : []
  const chainIdStr = chainId === null ? null : String(chainId)
  const expectedTo = chainIdStr ? policy.allow?.multivaultByChain?.[chainIdStr] : null

  if (chainId !== null && policyChains.length > 0) {
    if (!policyChains.includes(chainId)) {
      failures.push(`chainId ${chainId} not in allow.chains`)
      checks.allowlistChain = 'fail'
    } else {
      checks.allowlistChain = 'pass'
    }
  }

  if (!expectedTo || !isAddress(expectedTo)) {
    failures.push(`missing valid allow.multivaultByChain entry for chain ${chainIdStr}`)
    checks.allowlistTo = 'fail'
  } else if (lower(expectedTo) !== lower(tx.to)) {
    failures.push(`tx.to mismatch: tx=${tx.to} expected=${expectedTo}`)
    checks.allowlistTo = 'fail'
  } else {
    checks.allowlistTo = 'pass'
  }

  if (spec) {
    let expectedCalldata = null
    let expectedSelector = null
    try {
      expectedCalldata = runCast(['calldata', spec.signature, ...spec.calldataArgs])
      expectedSelector = lower(runCast(['sig', spec.signature]))
      checks.expectedEncoding = 'pass'
    } catch (err) {
      failures.push(`failed to encode expected calldata via cast: ${err.message}`)
      checks.expectedEncoding = 'fail'
    }

    if (expectedSelector) {
      const txSelector = lower(tx.data.slice(0, 10))
      if (policy.integrity?.requireSelectorMatch && txSelector !== expectedSelector) {
        failures.push(`selector mismatch: tx=${txSelector} expected=${expectedSelector}`)
        checks.selector = 'fail'
      } else {
        checks.selector = 'pass'
      }
    }

    if (expectedCalldata) {
      if (policy.integrity?.requireIntentArgBinding && lower(tx.data) !== lower(expectedCalldata)) {
        failures.push('tx.data does not match calldata re-encoded from intent')
        checks.intentBinding = 'fail'
      } else {
        checks.intentBinding = 'pass'
      }
    }

    try {
      const txValue = toBigInt(tx.value, 'tx.value')
      if (txValue !== spec.expectedValue) {
        failures.push(`value mismatch: tx=${txValue} expected=${spec.expectedValue}`)
        checks.valueMatch = 'fail'
      } else {
        checks.valueMatch = 'pass'
      }
    } catch (err) {
      failures.push(`value check failed: ${err.message}`)
      checks.valueMatch = 'fail'
    }

    if (policy.limits?.maxValuePerTxWei !== undefined) {
      const maxValuePerTxWei = toBigInt(policy.limits.maxValuePerTxWei, 'policy.limits.maxValuePerTxWei')
      const txValue = toBigInt(tx.value, 'tx.value')
      if (txValue > maxValuePerTxWei) {
        failures.push(`tx.value exceeds maxValuePerTxWei (${txValue} > ${maxValuePerTxWei})`)
        checks.maxValuePerTx = 'fail'
      } else {
        checks.maxValuePerTx = 'pass'
      }
    }

    if (policy.limits?.maxDailyValueWei !== undefined && args['spent-today-wei'] !== undefined) {
      const maxDaily = toBigInt(policy.limits.maxDailyValueWei, 'policy.limits.maxDailyValueWei')
      const spent = toBigInt(args['spent-today-wei'], '--spent-today-wei')
      const txValue = toBigInt(tx.value, 'tx.value')
      if (spent + txValue > maxDaily) {
        failures.push(`daily value limit exceeded (${spent + txValue} > ${maxDaily})`)
        checks.dailyLimit = 'fail'
      } else {
        checks.dailyLimit = 'pass'
      }
    }

    if (policy.limits?.maxPendingTx !== undefined && args['pending-count'] !== undefined) {
      const maxPending = Number(policy.limits.maxPendingTx)
      const pendingCount = Number(args['pending-count'])
      if (!Number.isFinite(maxPending) || !Number.isFinite(pendingCount)) {
        failures.push('invalid pending-count or policy maxPendingTx')
        checks.pendingLimit = 'fail'
      } else if (pendingCount >= maxPending) {
        failures.push(`pending tx limit reached (${pendingCount} >= ${maxPending})`)
        checks.pendingLimit = 'fail'
      } else {
        checks.pendingLimit = 'pass'
      }
    }

    const requireRpcChecks =
      policy.integrity?.requireStakeTermExists ||
      policy.integrity?.requireTripleAtomsExist ||
      policy.execution?.requireSimulation

    const rpc = args.rpc
    const from = args.from
    if (requireRpcChecks && !rpc) {
      failures.push('rpc checks required by policy but --rpc was not provided')
      checks.rpcInputs = 'fail'
    } else if (requireRpcChecks && !from && policy.execution?.requireSimulation) {
      failures.push('simulation required by policy but --from was not provided')
      checks.rpcInputs = 'fail'
    } else if (requireRpcChecks) {
      checks.rpcInputs = 'pass'
    }

    if (rpc && expectedTo && policy.integrity?.requireStakeTermExists && ['deposit', 'redeem', 'depositBatch', 'redeemBatch'].includes(spec.op)) {
      for (const termId of spec.termIdsToCheck) {
        try {
          const exists = runCast(['call', expectedTo, 'isTermCreated(bytes32)(bool)', termId, '--rpc-url', rpc])
          if (exists !== 'true') {
            failures.push(`term does not exist on-chain: ${termId}`)
            checks.termBinding = 'fail'
            break
          }
        } catch (err) {
          failures.push(`failed term existence check for ${termId}: ${err.message}`)
          checks.termBinding = 'fail'
          break
        }
      }
      if (!checks.termBinding) checks.termBinding = 'pass'
    }

    if (rpc && expectedTo && policy.integrity?.requireTripleAtomsExist && spec.op === 'createTriples') {
      for (const atomId of spec.tripleAtomsToCheck) {
        try {
          const exists = runCast(['call', expectedTo, 'isTermCreated(bytes32)(bool)', atomId, '--rpc-url', rpc])
          if (exists !== 'true') {
            failures.push(`triple atom does not exist on-chain: ${atomId}`)
            checks.tripleAtomBinding = 'fail'
            break
          }
        } catch (err) {
          failures.push(`failed triple atom existence check for ${atomId}: ${err.message}`)
          checks.tripleAtomBinding = 'fail'
          break
        }
      }
      if (!checks.tripleAtomBinding) checks.tripleAtomBinding = 'pass'
    }

    if (policy.execution?.requireSimulation) {
      if (!rpc || !from || !expectedTo) {
        failures.push('cannot run required simulation (missing --rpc, --from, or expectedTo)')
        checks.simulation = 'fail'
      } else {
        try {
          runCast(['call', expectedTo, tx.data, '--value', String(toBigInt(tx.value, 'tx.value')), '--from', from, '--rpc-url', rpc])
          checks.simulation = 'pass'
        } catch (err) {
          failures.push(`simulation failed: ${err.message}`)
          checks.simulation = 'fail'
        }
      }
    }
  }

  if (failures.length > 0) {
    console.error(JSON.stringify({ status: 'fail', failures, checks }, null, 2))
    process.exit(1)
  }

  const txValue = toBigInt(tx.value, 'tx.value')
  const decision = approvalDecision(policy, intent, txValue)
  if (decision.requiresApproval) {
    console.log(JSON.stringify({
      status: 'approval_required',
      operation: intent.operation,
      reason: decision.reasons.join('; '),
      reasons: decision.reasons,
      mode: decision.mode,
      proposedTx: tx,
      checks,
    }, null, 2))
    process.exit(2)
  }

  console.log(JSON.stringify({
    status: 'pass',
    checks,
    mode: decision.mode,
    operation: intent.operation,
    chainId: Number(chainId),
    to: tx.to,
    value: String(txValue),
  }, null, 2))
}

try {
  main()
} catch (err) {
  console.error(JSON.stringify({ status: 'error', message: err.message }, null, 2))
  process.exit(1)
}
