# @goatsoft/lucy-icons

## 0.4.0

### Minor Changes

- 49d17c4: Draws a duotone icon's body at 0.5 opacity (the sets use about 0.15, which reads as an outline once tinted on a dark UI). Set `duotone` in `lucy-icons.json` to choose another opacity. Sheets with duotone icons change on the next build.

## 0.3.0

### Minor Changes

- 9005938: A `name` in `lucy-icons.json` names each uploaded sheet: `{hash}` becomes the first 8 characters of the sheet's hash (`lucy-icons-{hash}` by default).

## 0.2.0

### Minor Changes

- f941233: Draws the icons Lucy's components use (`lucy:close`, `lucy:check` and the rest) into the game's own sheet and writes their names into the module, so a game loads one image instead of two. Set `"lucy": false` in `lucy-icons.json` to leave them out.
