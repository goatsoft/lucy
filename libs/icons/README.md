# lucy-icons

Puts any [Iconify](https://icon-sets.iconify.design) icon into a Roblox game,
for [Lucy](https://lucy.goatsoft.io)'s Icon component. Only the icons the game
uses are packed, into a few sprite sheets that are uploaded once.

```lua
Lucy.Icon.new({ icon = "lucide:heart" })
```

```sh
npm install --save-dev @goatsoft/lucy-icons
LUCY_ICONS_API_KEY=... npx lucy-icons build
```

Setup, the config, the commands and the lock file are covered in
[Add icons](https://lucy.goatsoft.io/docs/guide/icons) in Lucy's docs.

## Developing

```sh
pnpm icons:test        # from the repo root: node's test runner, no network
pnpm icons:typecheck
pnpm --filter @goatsoft/lucy-icons icons build --config path/to/lucy-icons.json
```

Node 24 runs `src/*.ts` directly. `pnpm --filter @goatsoft/lucy-icons build`
compiles `dist/` for publishing.
