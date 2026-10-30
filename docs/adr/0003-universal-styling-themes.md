# 0003: Universal Styling for themes and component visuals

- Status: accepted
- Date: 2026-10-30

## Context

shadcn styles with Tailwind classes and CSS variables. Roblox now has Universal
Styling: StyleSheets with StyleRules (selectors over class, tag, name, state and
pseudo-instances such as `::UICorner`), token attributes referenced as `$Name`,
StyleDerive for inheritance and StyleLink to attach a sheet to a ScreenGui.

## Decision

- **Tags are classes.** Components tag instances (`ui-button`,
  `ui-button-variant-outline`, `ui-disabled`) and declare rules against them.
- **One sheet graph per App**, built by `Theme`:
  `Tokens` (primitives) ← `Theme_<name>` (semantic colours) and `Density_<name>`
  (control heights, type scale) ← `Design` (derives the active theme and density,
  holds every rule). Every app ScreenGui links to `Design`.
- **Switching** theme or density re-points one StyleDerive; all guis restyle.
- **Priority bands**: reset -100, base 0, variant/size 10, state (`:Hover`) 20,
  disabled 30, focus ring 100. Higher wins.
- **Base rules** take over Roblox defaults inside linked guis (no borders, no
  AutoButtonColor, themed text) and draw Lucy's focus ring (ADR 0007).
- **Code never sets a styled property.** Instance properties set from code win
  over rules, so components set only behaviour and layout.

## Consequences

- Themes are data. A game can add a theme by passing another table.
- Reading a styled property returns the unstyled value by design; use
  `instance:GetStyled(prop)`. Styles apply a few frames after a change (measured
  4 heartbeats in Studio), so tests wait (`Harness.flush`).
- Derived tokens (Oklab mixes, alpha composites) are computed when the theme is
  built (ADR 0010), so changing a primitive at runtime does not update them.

## Alternatives considered

- Setting properties from a theme table in code: simple, but every component
  must listen for theme changes and it fights Studio's Style Editor.
