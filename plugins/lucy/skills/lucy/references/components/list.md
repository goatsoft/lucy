<!-- Made by scripts/skills.ts from docs/components/list.md. Edit the doc, not this file. -->
# List

A vertical list with optional markers (`disc`, `decimal`, `chevron`, `none`). Every item's
content is a [Slot](slot.md), so a row can be a plain string, a [Text](text.md) component,
an [Icon](icon.md), a [Badge](badge.md), or a mix of them. Add `onClick` to any item to turn
that row into a clickable link with hover styling and gamepad focus.

```luau
Lucy.Stack.new({
	direction = "horizontal",
	gap = "Space8",
	children = {
		Lucy.List.new({
			app = app,
			marker = "disc",
			width = UDim.new(0, 240),
			items = {
				"Warm up on the dance floor",
				"Keep your combo climbing",
				Lucy.Text.new({ app = app, text = "Unlock the VIP lounge at 100 pts", variant = "muted" }),
			},
		}),
		Lucy.List.new({
			app = app,
			marker = "decimal",
			width = UDim.new(0, 260),
			items = {
				{
					content = "Any rhythm tips?",
					variant = "primary",
					onClick = function() end,
				},
				{
					content = {
						"Spin the VIP mix",
						Lucy.Badge.new({ app = app, text = "Score 100+", variant = "outline", size = "sm" }),
					},
					disabled = true,
					onClick = function() end,
				},
				{
					content = "Catch you later",
					onClick = function() end,
				},
			},
		}),
	},
	Parent = parent,
})
```

## Markers

- `disc` (default): bullet dot (`•`)
- `decimal`: numbered (`1.`, `2.`, `3.`)
- `chevron`: prompt arrow (`>`)
- `none`: no marker

Any item table can also set `marker = "..."` to override the marker for that row.

## Slot content

Each entry in `items` can be passed directly as any [Slot](slot.md) value (a string, a
`Lucy.Text`, an `Instance`, a builder function, or a table of them), or as an item spec:

```luau
{
	id = "vip_mix",            -- optional Instance name
	content = { "VIP mix", Lucy.Icon.new({ name = "lucide:sparkles", size = "sm" }) },
	variant = "primary",       -- default | primary | destructive | muted
	disabled = false,
	marker = ">",              -- optional per-row marker override
	onClick = function() end,  -- makes the row clickable with hover highlight
}
```

## Props

| Prop | Type | Default | What it does |
|---|---|---|---|
| `items` | table or Ref | `{}` | List of Slot values or item specs (reactive when given a `Ref`) |
| `marker` | string | `"disc"` | `"disc"`, `"decimal"`, `"chevron"`, or `"none"` |
| `size` | string | `"md"` | `"sm"`, `"md"`, or `"lg"` |
| `gap` | number | `2` | Vertical pixel gap between rows |
| `width` | UDim | `UDim.new(1, 0)` | Optional width for the list container |
