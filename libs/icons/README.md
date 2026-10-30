# lucy-icons

Puts any icon from [Iconify](https://icon-sets.iconify.design) into a Roblox
game, for [Lucy](https://lucy.goatsoft.io)'s Icon component. Only the icons the
game uses are packed, into a few sprite sheets that are uploaded once.

```lua
Lucy.Icon.new({ icon = "lucide:heart" })
Lucy.Icon.new({ icon = "mdi:home", variant = "muted" })
```

Names are `<set>:<icon>`, as on the [Iconify site](https://icon-sets.iconify.design):
`lucide:heart`, `tabler:music`, `material-symbols:settings`. One colour icons
take the theme's colours; colour sets (emoji, logos) keep their own.

## How it works

1. `lucy-icons build` scans your game's source for quoted `"set:name"`
   strings whose set is an Iconify set, plus any names you list in the config.
2. It draws them at one size into 1024 pixel PNG sheets.
3. It uploads any sheet it has not uploaded before, as an image, through
   Roblox Open Cloud.
4. It writes a Luau module that maps each name to its sheet and cell. Register
   that module once:

```lua
local Lucy = require(ReplicatedStorage.Packages.Lucy)
Lucy.Icon.register(require(ReplicatedStorage.Shared.Icons))
```

A lock file, `lucy-icons.lock.json`, remembers where each icon sits and which
sheets are uploaded. New icons go at the end, so adding icons uploads only the
last sheet, and removing icons uploads nothing. Commit the lock file.

## Setup

Node 24 or newer.

```sh
npm install --save-dev @goatsoft/lucy-icons
```

Add `lucy-icons.json` to your game's folder:

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
| `include` | `[]` | Names your code builds at runtime, such as `"lucide:" .. name`, which a scan cannot find |
| `output` | `src/shared/Icons.luau` | The module to write |
| `lock` | `lucy-icons.lock.json` | The lock file |
| `creator` | | Who owns the uploads: `{ "userId": "..." }` or `{ "groupId": "..." }` |
| `size` | `64` | Cell size in pixels |
| `sheet` | `1024` | Sheet size in pixels |
| `padding` | `4` | Space around each cell |
| `cache` | `.lucy-icons` | Downloaded icon data and sheets waiting for upload. Add it to `.gitignore` |

Create an [Open Cloud API key](https://create.roblox.com/dashboard/credentials)
with the **Assets** API's read and write permissions, for the same user or
group as `creator`. Keep it out of the config and out of git:

```sh
LUCY_ICONS_API_KEY=... npx lucy-icons build
```

## Commands

```sh
npx lucy-icons build              # scan, draw, upload new sheets, write the module
npx lucy-icons build --check      # change nothing; fail when out of date (for CI)
npx lucy-icons build --no-upload  # write new sheets for you to upload yourself
npx lucy-icons build --repack     # start the sheets over without gaps (uploads every sheet)
npx lucy-icons build --offline    # use only installed sets and the cache
```

Without an API key the build writes the new sheets to `.lucy-icons/sheets` and
lists them. Upload each one as an image in the Creator Dashboard, put its id in
the lock file's `sheets` next to its hash, and run the build again.

## Icon data

Install a set's package to build without network for that set:

```sh
npm install --save-dev @iconify-json/lucide
```

Any set that is not installed is fetched from the Iconify API the first time,
only the icons you use, and kept in `.lucy-icons/data`.

## Licences

Each set has its own licence. The generated module lists the sets you use and
their licences, and marks those that need attribution (CC BY, for example), so
you can credit them in your game.

## Uploads

Roblox moderates every upload, and limits how many images an account can
upload each month. One sheet holds 196 icons at the default size, and only
changed sheets are uploaded, so most games upload a sheet or two in total.
