#!/usr/bin/env node
/**
 * lucy-mcp: Lucy's MCP server, on stdio. An agent's MCP config runs it; it
 * talks to Roblox Studio through Studio's own MCP server.
 */
import { readFileSync } from 'node:fs'
import { serve } from './server.ts'
import { connectStudio } from './studio.ts'
import { createTools } from './tools.ts'

const { version } = JSON.parse(readFileSync(new URL('../package.json', import.meta.url), 'utf8')) as { version: string }

const HELP = `lucy-mcp ${version}: Lucy's MCP server, for coding agents.

Run by an agent's MCP config, on stdio. It reaches Roblox Studio through
Studio's own MCP server, which must be on. Set LUCY_STUDIO_MCP to that
server's path if it is not where Studio installs it.

Docs: https://lucy.goatsoft.io/docs/guide/agents
`

const arg = process.argv[2]
if (arg === '--help' || arg === '-h') {
  process.stdout.write(HELP)
}
else if (arg === '--version' || arg === '-v') {
  process.stdout.write(`${version}\n`)
}
else {
  const studio = connectStudio()
  await serve(process.stdin, process.stdout, createTools(studio), { name: 'lucy', version })
  studio.close()
}
