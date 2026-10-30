# 0023: Icons: a build tool packs the icons a game uses into uploaded sheets

- Status: accepted (JB, 2026-10-31)
- Date: 2026-10-31

## Context

Icon (0.1.0, ADR 0021) draws a registered name, an asset id or a url, tinted
from the theme. Lucy ships no icons. Games need a large, consistent icon set
without hand drawing and uploading each one: Dance Lab today uses 39 emoji and
symbols in text labels, which cannot follow the theme and look different on
every platform.

Iconify publishes over 200 open icon sets (Lucide, Material Symbols, Tabler,
Phosphor...) as JSON, one package per set (`@iconify-json/<prefix>`), plus an
HTTP API. A Roblox game cannot load an SVG at runtime: every picture must be an
uploaded image asset, and uploads are limited per account per month.

## Decision

1. **A Node CLI, `@goatsoft/lucy-icons`, in `libs/icons`.** Not part of the Wally
   package (libs/ is excluded). Node, not Lune: SVG rendering (resvg) and the
   Iconify utilities exist as npm packages; Lune has neither. A game using it
   needs Node for builds, not at runtime.
2. **Only the icons a game uses.** `lucy-icons build` reads `lucy-icons.json`
   in the game, scans its source for string literals of the form
   `"<set>:<name>"` whose set is a known Iconify prefix, and adds the config's
   `include` list (names built at runtime, which a scan cannot find).
   Unknown names in a known set fail the build.
3. **Icon data:** from the game's installed `@iconify-json/<prefix>` package
   when present; otherwise fetched from the Iconify API once and cached in
   `.lucy-icons/`. The full `@iconify/json` (about 550 MB) is never needed.
4. **Sheets.** Icons are rendered white (one colour sets) or in their own
   colours (sets marked as palette, registered with `tint = false`) at one cell
   size (default 64 px), with padding, into 1024 px PNG sheets: one upload and
   one download for many icons.
5. **Few uploads.** A lock file, `lucy-icons.lock.json`, committed with the
   game, records each icon's slot and each sheet's content hash and asset id.
   New icons take new slots at the end; removed icons keep their slot until
   `--repack`. So adding icons changes only the last sheet, removing changes
   none, and an unchanged sheet is never uploaded again.
6. **Upload** through Open Cloud (`POST /assets/v1/assets`, assetType `Image`),
   with an API key from `LUCY_ICONS_API_KEY` (never in the config) and the
   creator (user or group) from the config. Without a key, `--no-upload`
   writes the sheets for a manual upload, and the ids go in the lock file.
7. **Output:** a generated Luau module mapping name to
   `{ image, rect, tint }`, the shape `Lucy.Icon.register` takes. `--check`
   fails when the module is out of date, for CI.
8. **Licences:** each set's licence is read from its data and listed in the
   generated module's header; sets whose licence requires attribution are
   reported.

## Consequences

- Games get any Iconify icon by name, themed, with no hand work beyond one
  API key.
- The Icon component does not change: the tool only produces its map.
- Builds need network on first use of a set unless the set's package is
  installed. Rendering is deterministic, so the same icons give the same sheet
  hash on any machine.
- Holes left by removed icons waste sheet space until a repack; a repack
  re-uploads every sheet, so it is a deliberate step.
- The tool names Iconify in its own docs; Lucy's component docs refer to it
  as "the icon build".

## Alternatives considered

- **Upload each icon on its own.** Simple ids, but an upload per icon against a
  monthly limit, and a download per icon on join.
- **Lune.** One toolchain for Roblox developers, but no SVG renderer; it would
  need a separate native binary.
- **Ship a fixed icon set with Lucy.** Every game pays for icons it does not
  use, and Lucy would own asset ids and moderation.
- **Sorted sheets.** Simplest packing, but one new icon shifts every slot and
  re-uploads every sheet.
