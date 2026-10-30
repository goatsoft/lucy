#!/usr/bin/env node
import { parseArgs } from 'node:util'
import { API_KEY_ENV, build } from './build.ts'

const HELP = `lucy-icons: packs the icons a game uses into sheets for Lucy's Icon.

Usage: lucy-icons build [options]

  --config <file>  the config (default: lucy-icons.json)
  --no-upload      write new sheets for a manual upload instead of uploading
  --check          change nothing; fail when the module or lock is out of date
  --repack         start the sheets over, sorted (every sheet is uploaded again)
  --offline        use only installed icon sets and the cache

Uploads need ${API_KEY_ENV}: an Open Cloud API key with the assets permission.
`

async function main(argv: string[]): Promise<number> {
  const { values, positionals } = parseArgs({
    args: argv,
    allowPositionals: true,
    options: {
      config: { type: 'string', default: 'lucy-icons.json' },
      'no-upload': { type: 'boolean', default: false },
      check: { type: 'boolean', default: false },
      repack: { type: 'boolean', default: false },
      offline: { type: 'boolean', default: false },
      help: { type: 'boolean', short: 'h', default: false },
    },
  })
  const command = positionals[0] ?? 'build'
  if (values.help || command === 'help') {
    process.stdout.write(HELP)
    return 0
  }
  if (command !== 'build') {
    process.stderr.write(`unknown command "${command}"\n\n${HELP}`)
    return 1
  }
  const result = await build({
    config: values.config,
    noUpload: values['no-upload'],
    check: values.check,
    repack: values.repack,
    offline: values.offline,
    log: line => process.stdout.write(`${line}\n`),
  })
  const summary = `${result.icons.length} icons on ${result.sheets} sheet${result.sheets === 1 ? '' : 's'}`
  switch (result.status) {
    case 'written':
      process.stdout.write(`wrote ${result.output}: ${summary}, ${result.uploaded} uploaded\n`)
      return 0
    case 'unchanged':
      process.stdout.write(`${result.output} is up to date: ${summary}\n`)
      return 0
    case 'outdated':
      process.stderr.write(`${result.output} is out of date: run lucy-icons build\n`)
      return 1
    case 'needs-upload':
      process.stdout.write(
        `These sheets need uploading. Set ${API_KEY_ENV} and run again, or upload them as images\n` +
          `yourself and add each id to "sheets" in the lock file:\n`,
      )
      for (const p of result.pending) process.stdout.write(`  ${p.file}   "${p.hash}": "<asset id>"\n`)
      return 2
  }
}

main(process.argv.slice(2)).then(
  code => process.exit(code),
  (error: unknown) => {
    process.stderr.write(`lucy-icons: ${error instanceof Error ? error.message : String(error)}\n`)
    process.exit(1)
  },
)
