<!-- Made by scripts/skills.ts from docs/stories.md. Edit the doc, not this file. -->
# Stories and preview

A story is a small module that renders one piece of UI, with controls to vary
it. Lucy previews stories in Studio without pressing Play, and the same story
doubles as a smoke test.

## Write a story

Name a ModuleScript `<Name>.story` anywhere in your game and return a table:

```luau
-- Shop/ItemCard.story.luau
return {
    group = "Shop",
    description = "One item in the shop grid.",
    width = 320,
    controls = {
        name = "Rocket boots",
        price = { min = 0, max = 5000, step = 50, default = 750 },
        rarity = { "common", "rare", "legendary" },
        owned = false,
    },
    render = function(ctx)
        local Lucy = ctx.Lucy
        local c = ctx.controls
        return Lucy.Panel.new({
            title = c.name,
            description = function() return `{c.rarity()} · ${c.price()}` end,
            footer = {
                Lucy.Button.new({
                    text = function() return if c.owned() then "Equip" else "Buy" end,
                    variant = function() return if c.owned() then "outline" else "default" end,
                }),
            },
        })
    end,
}
```

| Field | What it does |
|---|---|
| `title` | Name in the list; defaults to the module name without `.story` |
| `group` | Sidebar group (`"Stories"`) |
| `description` | One line shown with the controls |
| `layout` | `"centered"` (default), `"padded"` or `"fullscreen"` (scenes) |
| `width` | Column width for centred stories (360) |
| `controls` | Values to vary, see below |
| `render(ctx)` | Builds the UI and returns what to show |

`ctx` holds `Lucy` (the package, so stories never hardcode a require path),
`app` (the story's own App), `target` (the frame to fill) and `controls`.
Return an instance, a component handle or a list of them; anything returned
without a parent goes into `target`.

## Controls

Each control's kind comes from its value:

| Value | Kind | Default |
|---|---|---|
| `false` | boolean | the value |
| `"text"` | string | the value |
| `3` | number | the value |
| `{ "sm", "md", "lg" }` | choice | the first option |
| `{ options = { ... }, default = "md" }` | choice | `default` |
| `{ min = 0, max = 100, step = 5, default = 40 }` | number | `default` |

`ctx.controls.<name>` is a writable ref. Every component state key accepts a
ref, so `checked = ctx.controls.checked` binds a Switch both ways: flip the
switch and the control follows. For props that are not state keys (Stack's
`direction`, say), read the control inside a getter child so that part is
rebuilt when it changes.

## Preview in edit mode

From the command bar or the Studio MCP, with your stories anywhere under
ReplicatedStorage:

```luau
local Lucy = require(game.ReplicatedStorage.Packages.Lucy)
Lucy.Preview.show("ItemCard", { theme = "light", device = "mobile" })
Lucy.Preview.clear()
```

The story renders into StarterGui, so Studio draws it in the viewport. Gui
input does not work in edit mode; use Play for clicking around.

`Preview.show` options: `root` (where to look for stories), `theme`,
`density`, `device` (`desktop`, `mobile`, `tablet`, `console`), `baseColor`,
`primary` and `controls` (initial values).

## Browse in Play

`examples/Showcase.client.luau` is a story browser built with Lucy: a sidebar
of stories, the canvas, generated controls, a theme switch and a device picker.
Copy it into StarterPlayerScripts and point `root` at your stories folder.

## In code and specs

```luau
local mounted = Lucy.Preview.mount(story, { theme = "dark", device = "console" })
mounted:set("rarity", "legendary")
mounted:values()      --> { name = ..., price = ..., rarity = "legendary", owned = false }
mounted.error         --> nil, or the message if render failed
mounted:destroy()     -- removes everything the story made, and its App
```

`Lucy.Preview.find(root)` lists every story under a folder, and
`Lucy.Preview.controlsOf(story)` lists its controls. A spec that mounts every
story in every theme catches broken stories early; Lucy's own is
`tests/Stories.spec.luau`.
