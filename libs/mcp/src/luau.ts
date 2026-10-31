/**
 * The Luau the server runs in Studio, through Studio's `execute_luau`, to call
 * `Lucy.Devtools` (ADR 0028). Each call is one snippet: it finds Lucy, calls one
 * Devtools function and answers with JSON.
 */

/** Studio's data models: edit mode, and the client of a Play session. */
export type DataModel = 'Edit' | 'Client'

/** A Devtools call: the function's name and its arguments, by name. */
export interface DevtoolsRequest {
  method: 'apps' | 'tree' | 'state' | 'set' | 'focus' | 'press' | 'overlays' | 'actions' | 'preview'
  [arg: string]: unknown
}

/** The copy of Lucy a preview runs from, kept so later edit-mode calls reach its app. */
const KEPT = 'LucyMcp_Lucy'

/**
 * `text` as a Luau long string (`[==[...]==]`), at a level the text cannot close.
 * A long string drops a newline right after its opening bracket, so one is added
 * when the text starts with a newline.
 */
export function longString(text: string): string {
  let eq = ''
  // The first closing bracket must be the one added at the end.
  while ((text + `]${eq}]`).indexOf(`]${eq}]`) !== text.length) eq += '='
  const lead = text.startsWith('\n') || text.startsWith('\r') ? '\n' : ''
  return `[${eq}[${lead}${text}]${eq}]`
}

/** The request inside a snippet made by `devtoolsCall` (for tests and debugging). */
export function readRequest(code: string): Record<string, unknown> {
  const open = /JSONDecode\(\[(=*)\[/.exec(code)
  if (!open) throw new Error('no request in this code')
  const start = open.index + open[0].length
  const end = code.indexOf(`]${open[1]}]`, start)
  let body = code.slice(start, end)
  if (body.startsWith('\n')) body = body.slice(1)
  return JSON.parse(body) as Record<string, unknown>
}

/**
 * The snippet for one Devtools call. In Play it runs on the client, where the
 * game's apps are; in edit mode it reaches a story shown with `preview`.
 * `settle` waits that many seconds before answering, so a screenshot taken
 * next shows the result (styles apply a few frames late, tweens take time).
 */
export function devtoolsCall(request: DevtoolsRequest, dataModel: DataModel, options: { settle?: number } = {}): string {
  const fresh = request.method === 'preview'
  const edit = dataModel === 'Edit'
  const settle = options.settle ? `\ntask.wait(${options.settle})` : ''
  return `local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local request = HttpService:JSONDecode(${longString(JSON.stringify(request))})
local fresh = ${fresh}
local edit = ${edit}
local KEPT = "${KEPT}"

-- Lucy in ReplicatedStorage: the shallowest ModuleScript named Lucy with Core.Devtools.
local function findLucy()
	local best, bestDepth = nil, math.huge
	for _, d in ReplicatedStorage:GetDescendants() do
		if d:IsA("ModuleScript") and string.lower(d.Name) == "lucy" then
			local core = d:FindFirstChild("Core")
			if core and core:FindFirstChild("Devtools") then
				local depth, node = 0, d
				while node and node ~= ReplicatedStorage do
					depth += 1
					node = node.Parent
				end
				if depth < bestDepth then
					best, bestDepth = d, depth
				end
			end
		end
	end
	return best
end

local ok, result = pcall(function()
	local module = findLucy()
	if not module then
		error("Lucy is not in ReplicatedStorage. Is Rojo serving the game?", 0)
	end
	-- Edit-mode require is cached and can hand back old code, so edit-mode calls
	-- use a copy, kept for the next call (a shown story's app requires from it).
	local function copyOf(source)
		local copy = source:Clone()
		copy.Name = KEPT
		copy.Archivable = false
		copy.Parent = ReplicatedStorage
		return copy
	end
	local kept = ReplicatedStorage:FindFirstChild(KEPT)
	local m = request.method
	if fresh then
		-- A preview starts over, so it picks up changed code.
		if kept then
			pcall(function()
				require(kept).Preview.clear()
			end)
			kept:Destroy()
		end
		if m == "preview" and request.story == nil then
			return { ok = true, cleared = kept ~= nil }
		end
		module = copyOf(module)
	elseif edit then
		module = kept or copyOf(module)
	end
	local Devtools = require(module).Devtools
	local options = { app = request.app }
	if m == "apps" then
		return Devtools.apps()
	elseif m == "tree" then
		return Devtools.tree({ app = request.app, root = request.root, shownOnly = request.shownOnly })
	elseif m == "state" then
		return Devtools.state(request.path, options)
	elseif m == "set" then
		return Devtools.set(request.path, request.value, options)
	elseif m == "focus" then
		return Devtools.focus(request.id, options)
	elseif m == "press" then
		return Devtools.press(request.id, request.value, options)
	elseif m == "overlays" then
		return Devtools.overlays(options)
	elseif m == "actions" then
		return Devtools.actions(options)
	elseif m == "preview" then
		return Devtools.preview(request.story, { theme = request.theme, device = request.device, density = request.density })
	end
	error("unknown call " .. tostring(m), 0)
end)${settle}

local reply = { ok = ok }
if ok then
	reply.result = result
else
	reply.error = tostring(result)
end
local encoded, json = pcall(HttpService.JSONEncode, HttpService, reply)
if not encoded then
	return HttpService:JSONEncode({ ok = false, error = "the answer could not be sent as JSON: " .. tostring(json) })
end
return json
`
}

/** The result of a snippet's JSON answer, or its error thrown. */
export function parseReply(text: string): unknown {
  let reply: { ok?: boolean, result?: unknown, error?: string }
  try {
    reply = JSON.parse(text) as typeof reply
  }
  catch {
    throw new Error(`Studio answered with something else: ${text}`)
  }
  if (!reply.ok) throw new Error(reply.error ?? 'Devtools failed without saying why')
  return reply.result ?? null
}

/**
 * The message in Studio's error text. `execute_luau` puts its own call chain in
 * front (`...ExecuteLuauTool:125: ...AssistantCommand:1: boom`).
 */
export function studioError(raw: string): string {
  const marks = [...raw.matchAll(/AssistantCommand:\d+: /g)]
  const last = marks.at(-1)
  return last ? raw.slice(last.index + last[0].length) : raw
}
