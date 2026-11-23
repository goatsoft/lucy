# Changelog

What changed in each version of Lucy on Wally (`goatsoft/lucy`). The npm
packages keep their own: `libs/icons/CHANGELOG.md` and `libs/mcp/CHANGELOG.md`.

## 0.1.0

The first release on Wally.

- Lucy's components, the App (scenes, app state, overlays, actions, and input
  for mouse, keyboard, gamepad and touch), themes on Universal Styling,
  reactivity, icons and Devtools. The docs at https://lucy.goatsoft.io cover
  each one.
- For games that used Lucy from source before this release, one change to the
  look: an App that picks no colours now starts in mauve greys with a violet
  primary, as on the website. `primary = "none"` gives the old black and white
  look. `Lucy.Tokens.spectrum` holds the mascot's magenta, orchid and sky to
  use as named colours.
