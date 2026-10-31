---
name: lucy-icons
description: Add icons to a Roblox game that uses Lucy, with the lucy-icons build or the game's own images. Use when a Lucy game needs an icon (a heart, a coin, a settings cog), when code uses `Lucy.Icon` or a `"set:name"` icon name, when an icon fails with "unknown icon", or when setting up, building or uploading icon sheets (`lucy-icons.json`, `lucy-icons.lock.json`, `LUCY_ICONS_API_KEY`).
---

# Icons in a Lucy game

`Lucy.Icon.new({ icon = name })` draws a small picture in the theme's colours.
The name must be registered first, once, before UI is built, with
`Lucy.Icon.register(map)`. The map comes from one of two places:

- **lucy-icons** (`npx lucy-icons build`): scans the game's source for quoted
  `"set:name"` strings from any Iconify set (`"lucide:heart"`, `"mdi:home"`),
  packs them into sprite sheets, uploads new sheets and writes a Luau module
  of the map. Check for `lucy-icons.json` in the game.
- **The game's own images**: a hand written map of names to asset ids.

Lucy's own components draw a few `lucy:*` names (`lucy:close`, `lucy:check`,
the chevrons, `lucy:minus`, `lucy:plus`) that work with nothing set up.

## Adding an icon with lucy-icons

1. Write the name in code as a whole quoted string: `icon = "lucide:coins"`.
   Names built while the game runs (`"lucide:" .. kind`) are not found by the
   scan; list them in `include` in `lucy-icons.json`.
2. Find real names on the Iconify site; a wrong name fails the build with
   "unknown icon". Prefer the set the game already uses (look in the
   generated module) so icons match.
3. Run `npx lucy-icons build` in the game's folder. With
   `LUCY_ICONS_API_KEY` set it uploads new sheets; without it, it writes them
   to `.lucy-icons/sheets` and says how to finish by hand. Uploads count
   against a monthly limit, so build once after adding a batch of icons, not
   once per icon. If you cannot run it, write the names anyway and tell the
   user to run it: until then, an unknown name draws nothing and warns once.
   If the game has no `lucy-icons.json` yet, setting it up is part of the
   task: install the tool, add the config, and tell the user to build.
   Until the build runs, an icon-only button is blank, so give it `text` too,
   or fall back to text with `Lucy.Icon.has(name)`.
4. Commit the generated module and `lucy-icons.lock.json`. Never edit either
   by hand (except adding a sheet id to the lock after a manual upload).
5. Make sure the module is registered at client start, before any UI:
   `Lucy.Icon.register(require(path.to.Icons))`. The module is the file at
   `output` in `lucy-icons.json`; find where the game's Rojo project puts
   that folder. `Icon.register` needs no App, so it can run before
   `App.new`.

`npx lucy-icons build --check` fails when the module is out of date; use it
before finishing.

## Rules

- **Never draw icons with text glyphs or emoji** in a TextLabel: they cannot
  follow the theme and look different on every platform.
- **Icons used with tint are white on a clear background.** The theme colours
  them; `variant` picks the colour. Logos and colour sets keep their colours
  (`tint = false`).
- **To change one of Lucy's own icons** (the close button's, say), register
  that `lucy:*` name; never edit Lucy's files.

The full guide, the config fields and the commands are in
[Add icons](references/guide/icons.md); the component is
[Icon](references/components/icon.md).
