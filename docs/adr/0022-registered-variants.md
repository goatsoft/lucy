# 0022: Games add their own variants to Lucy's components

- Status: accepted in principle; the API is still to design
- Date: 2026-10-31

## Context

Components come with fixed variants (Button: default, destructive, outline,
secondary, ghost, link). Games need more: Dance Lab colours almost everything
per item (a genre's card, a move's rarity, a lane's colour). Three ways were
weighed:

- **a) A `tags` prop on every component**, with games writing rules against
  Lucy's tag names. Most flexible, but every internal tag name becomes public
  API, so renaming one breaks games.
- **b) `color` / `accent` props** where needed. Simple, but only covers colour,
  and each bound prop is another effect per mount.
- **c) Registered variants**: a game names a look and gives its rules, then
  passes that name as `variant`. Lucy validates it.

## Decision

Option c. The shape to design, for example:

```lua
Lucy.Button.addVariant("neon", {
    { selector = "", properties = { BackgroundColor3 = "$Neon" } },
    { selector = ":Hover", properties = { BackgroundColor3 = "$NeonHover" } },
})
Lucy.Button.new({ variant = "neon" })
```

- Rules are written relative to the component, so Lucy's tag names stay
  internal.
- An unknown variant still fails the mount, as today.
- The variant used when none is given stays named `default` and uses the
  theme's `Primary` token. Whether Primary is the brand colour is the theme's
  choice, not the component's.
- A structure class escape hatch (option a) may be added later for layout only.

## Consequences

- Each component with variants needs a way to register more, applied through
  the theme like its own rules.
- The design must settle: the selector form, priorities against built in states
  (hover, disabled), per app or global registration, and how stories and docs
  show game variants.

## Alternatives considered

Options a and b above. Option a is kept in mind as a narrow escape hatch.
