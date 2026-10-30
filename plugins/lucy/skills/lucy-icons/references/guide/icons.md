<!-- Made by scripts/skills.ts from docs/guide/icons.md. Edit the doc, not this file. -->
# Add icons

[Icon](../components/icon.md) draws small pictures that take the theme's
colours. Lucy draws a few icons of its own in its components (see
[Icons Lucy draws](#icons-lucy-draws)). Every other icon comes from your game,
in one of two ways:

- **Your own images.** Upload them yourself and register them by name, or pass
  an asset id straight to `icon`. Nothing else to install.
- **Iconify icons.** Name any of the open icons on
  [Iconify](https://icon-sets.iconify.design), such as `"lucide:heart"`, and
  the lucy-icons build packs the ones you use, uploads them and registers them
  for you. It needs Node.

Both end the same way: a map from names to images, passed to
`Lucy.Icon.register` once, before you build any UI. You can use both in one
game.

## Icons Lucy draws

Lucy's components draw these names, and Lucy fills them with its own icons, so
they work with nothing set up:

| Name | Where |
|---|---|
| `lucy:close` | The close button of dialogs and sheets |
| `lucy:chevron-down` | The arrow on a select |
| `lucy:check` | The ticked options in a check select |
| `lucy:minus`, `lucy:plus` | The buttons either side of a number field |
| `lucy:chevron-up`, `lucy:chevron-left`, `lucy:chevron-right` | Kept for components to come |

To use your own, register the name, and every component that draws it changes:

```lua
Lucy.Icon.register({
    ["lucy:close"] = { image = 1234567 },
})
```

Removing your registration brings Lucy's icon back. Lucy's icons are from the
Lucide set (ISC licence), on one image owned by GOATsoft.

If you use [lucy-icons](#iconify-icons-with-lucy-icons), the build draws these
icons into your own sheet too and adds their names to your module, so your game
loads one image instead of two. To change one, register your own after the
module. To leave them out, set `"lucy": false` in `lucy-icons.json`.

## Your own images

Pass an asset id or url to use an image once:

```lua
Lucy.Icon.new({ icon = 1234567, Parent = row })
```

To use names, register a map:

```lua
Lucy.Icon.register({
    ["game:coin"] = { image = 1234567 },
    ["game:trophy"] = { image = 2345678 },
    ["game:logo"] = { image = 3456789, tint = false },
})

Lucy.Icon.new({ icon = "game:coin", variant = "warning", Parent = hud })
```

Each name maps to:

| Field | What it is |
|---|---|
| `image` | The asset id or url of the picture, or of a sheet holding many icons |
| `rect` | Optional: `{ x, y, width, height }` of the icon's cell in a sheet, in pixels |
| `tint` | Optional: `false` keeps the picture's own colours, for a logo. Otherwise the theme colours it |

Draw icons that the theme colours in **white on a clear background**: the
theme multiplies their colour in. To save uploads and downloads, put many icons
in one sheet and give each its `rect`.

`register` returns a function that removes those names again. Names are global
to the game, so register each once.

## Iconify icons with lucy-icons

lucy-icons is a command line tool, run while you build your game, not in it.

1. It scans your game's source for quoted `"set:name"` strings whose set is an
   Iconify set, such as `"lucide:heart"` or `"mdi:home"`.
2. It draws those icons into 1024 pixel sheets: one colour icons in white,
   colour sets (emoji, logos) in their own colours.
3. It uploads any new sheet to Roblox through Open Cloud.
4. It writes a Luau module with the map, ready to register.

Names come from the [Iconify site](https://icon-sets.iconify.design): find an
icon, and its name is the set and the icon joined by a colon, such as
`tabler:music` or `material-symbols:settings`.

### Set up

You need Node 24 or newer. Install the tool in your game's folder:

```sh
npm install --save-dev @goatsoft/lucy-icons
```

Add `lucy-icons.json` beside it:

```json
{
  "src": ["src"],
  "output": "src/shared/Icons.luau",
  "creator": { "userId": "123456" }
}
```

| Field | Default | What it is |
|---|---|---|
| `src` | `["src"]` | Folders to scan |
| `extensions` | `[".luau", ".lua"]` | Files to scan |
| `include` | `[]` | Names your code builds while it runs, which a scan cannot find. See below |
| `output` | `src/shared/Icons.luau` | The module to write |
| `lock` | `lucy-icons.lock.json` | The lock file. Commit it |
| `creator` | | Who owns the uploads: `{ "userId": "..." }` or `{ "groupId": "..." }` |
| `size` | `64` | Each icon's size in the sheet, in pixels |
| `sheet` | `1024` | Sheet size in pixels |
| `padding` | `4` | Space around each icon in the sheet |
| `cache` | `.lucy-icons` | Downloaded icon data and sheets waiting for upload. Add it to `.gitignore` |
| `lucy` | `true` | Draws the [icons Lucy draws](#icons-lucy-draws) into your sheet and adds their names to the module. `false` leaves them out |

For uploads, create an
[Open Cloud API key](https://create.roblox.com/dashboard/credentials) with the
Assets API's read and write permissions, for the same user or group as
`creator`. Keep it out of the config and out of git, in an environment
variable:

```sh
export LUCY_ICONS_API_KEY=...
```

### Build

```sh
npx lucy-icons build
```

Then register the module where your client starts, before building UI:

```lua
local Lucy = require(ReplicatedStorage.Packages.Lucy)
Lucy.Icon.register(require(ReplicatedStorage.Shared.Icons))
```

Run the build again whenever you use a new icon. The lock file remembers where
each icon sits and which sheets are uploaded: new icons go at the end, so adding
icons uploads only the last sheet, and removing icons uploads nothing. One sheet
holds 196 icons at the default size.

### Names built while the game runs

The scan only finds names written out in full. A name your code puts together,
such as `"lucide:" .. genre`, needs listing in `include`:

```json
{
  "include": ["lucide:music", "lucide:disc", "lucide:mic"]
}
```

### Without an API key

The build writes each new sheet to `.lucy-icons/sheets` and lists them. Upload
each one as an image in the Creator Dashboard, add its id to the lock file's
`sheets` next to the hash it printed, and run the build again:

```json
"sheets": {
  "7ece95a4f4786f94f031e7666ab8afcc": "123456789"
}
```

### Commands

| Command | What it does |
|---|---|
| `npx lucy-icons build` | Scans, draws, uploads new sheets and writes the module |
| `npx lucy-icons build --check` | Changes nothing; fails when the module is out of date. Use it in CI |
| `npx lucy-icons build --no-upload` | Writes new sheets for you to upload yourself |
| `npx lucy-icons build --repack` | Starts the sheets over without gaps. Uploads every sheet again |
| `npx lucy-icons build --offline` | Uses only installed sets and the cache |

### Icon data

Each set the tool has not seen is fetched from the Iconify API the first time,
only the icons you use, and kept in `.lucy-icons/data`. To build without
network, install the set's package:

```sh
npm install --save-dev @iconify-json/lucide
```

### Licences

Each icon set has its own licence. The generated module lists the sets you use
and their licences, and marks the ones that ask for credit (CC BY, for example)
so you can credit them in your game.

### Uploads and moderation

Roblox moderates every upload and limits how many images an account can upload
each month. Since only changed sheets are uploaded, most games upload a sheet or
two in total.
