#!/usr/bin/env node
'use strict'

const { spawnSync } = require('child_process')
const path = require('path')

function usage() {
  console.log(`enforce-and-sign

Runs validate-tx-from-intent as a hard blocking gate, then executes signer command only if validation passes.

Usage:
  node scripts/enforce-and-sign.js \\
    --intent <intent.json> \\
    --tx <unsigned-tx.json> \\
    [--policy <policy.json>] \\
    [--rpc <rpc-url>] \\
    [--from <sender-address>] \\
    [--spent-today-wei <wei>] \\
    [--pending-count <n>] \\
    -- <signer command...>

Exit codes:
  0  signed/executed successfully
  1  validation failed or signer command failed
  2  approval required (blocked, no signer execution)`)
}

function splitArgs(argv) {
  const idx = argv.indexOf('--')
  if (idx === -1) {
    return { validatorArgs: argv, signerCmd: [] }
  }
  return {
    validatorArgs: argv.slice(0, idx),
    signerCmd: argv.slice(idx + 1),
  }
}

function getArgValue(args, name) {
  const key = `--${name}`
  const i = args.indexOf(key)
  if (i === -1) return undefined
  return args[i + 1]
}

function main() {
  const argv = process.argv.slice(2)
  if (argv.includes('--help') || argv.includes('-h')) {
    usage()
    return
  }

  const { validatorArgs, signerCmd } = splitArgs(argv)
  const intentPath = getArgValue(validatorArgs, 'intent')
  const txPath = getArgValue(validatorArgs, 'tx')
  if (!intentPath || !txPath) {
    usage()
    throw new Error('--intent and --tx are required')
  }
  if (signerCmd.length === 0) {
    usage()
    throw new Error('signer command is required after --')
  }

  const validatorScript = path.resolve(__dirname, 'validate-tx-from-intent.js')
  const validation = spawnSync(
    'node',
    [validatorScript, ...validatorArgs],
    { encoding: 'utf8' }
  )

  if (validation.stdout) process.stdout.write(validation.stdout)
  if (validation.stderr) process.stderr.write(validation.stderr)

  // validate-tx-from-intent exits:
  // 0 pass, 1 fail/error, 2 approval_required
  if (validation.status !== 0) {
    process.exit(validation.status === 2 ? 2 : 1)
  }

  const signer = spawnSync(
    signerCmd[0],
    signerCmd.slice(1),
    {
      stdio: 'inherit',
      env: {
        ...process.env,
        INTUITION_INTENT_FILE: intentPath,
        INTUITION_TX_FILE: txPath,
      },
    }
  )

  if (typeof signer.status === 'number') {
    process.exit(signer.status === 0 ? 0 : 1)
  }
  process.exit(1)
}

try {
  main()
} catch (err) {
  console.error(err.message)
  process.exit(1)
}
