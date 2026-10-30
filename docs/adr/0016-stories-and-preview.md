# 0016: Stories and preview in Studio

- Status: accepted
- Date: 2026-10-30

## Context

Seeing a component meant writing a throwaway LocalScript, pressing Play and
clicking to the right screen. There was no quick way to look at one component
in each variant, theme and density, and no way for a game to do the same for
its own UI. Web frameworks solve this with Storybook-style "stories": small
modules that render one piece of UI, with controls to vary its props.

Two Roblox facts shape the design:

- Universal Styling resolves in edit mode for a linked ScreenGui under
  StarterGui, and Studio draws it in the viewport. So a story can be rendered
  and screenshotted without Play, from the command bar or the Studio MCP.
- Gui input does not work in edit mode. Clicking through controls needs Play.

## Decision

- **A story is a ModuleScript named `<Name>.story`** returning a table:
  `title`, `group`, `description`, `layout` (`"centered"`, `"padded"` or
  `"fullscreen"`), `width`, `controls` and `render(ctx)`.
- **Controls are refs.** Each control's default is inferred from its value
  (boolean, string, number, a list of choices, `{ min, max, step, default }` or
  `{ options, default }`). `ctx.controls.<name>` is a writable ref, and since
  every component state key accepts a ref, `checked = ctx.controls.checked`
  just works, two-way.
- **`Lucy.Preview`** (`Core/Preview`) finds stories under a root, mounts one
  into its own App (theme, density and device chosen per mount) and tears it
  down completely: `render` runs inside an effect scope, so components and
  `Lucy.new` elements it creates are destroyed with the mount, then the App is
  destroyed. A render error is caught and shown in the canvas instead of
  leaking half-built UI. `Preview.show(name)` and `Preview.clear()` are the
  edit-mode shortcuts.
- **Preview ships with the package.** It is small, costs nothing unless used,
  and a game previews its own UI the same way Lucy does.
- **Lucy's own stories live in `examples/stories`**, which never ships. A spec
  mounts every story and checks that it renders and cleans up.
- **The showcase is a story browser** written with `Lucy.new`: a sidebar of
  stories, a canvas and generated controls bound to the story's refs. It runs
  in Play.

## Consequences

- Every component has a living example that doubles as a smoke test.
- Agents and the planned Lucy MCP server can render any story in edit mode and
  capture it, with no Play session.
- Controls are typed by inference only. Exotic props (callbacks, children)
  stay in the story's code.
- A story app becomes the current App while mounted, so story code need not
  pass `app`. The previous current App is restored on unmount.

## Alternatives considered

- **A Studio plugin with a dock widget.** Interactive in edit mode, but needs
  installing, and Universal Styling inside plugin widgets is unproven. The
  Preview module is what a plugin would call anyway, so it can come later.
- **Stories next to components (`Button.story.luau` in `src/`).** Convenient,
  but they would ship unless every guard learned a new pattern. Keeping them
  in `examples/` keeps the package rule simple.
- **Controls as plain values passed to `render` again on change.** Re-rendering
  defeats fine-grained updates and loses focus and animation state.
