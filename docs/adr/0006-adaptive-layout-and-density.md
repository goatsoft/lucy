# 0006: Adaptive scaling, densities and responsive values

- Status: accepted
- Date: 2026-10-30

## Context

Lucy must look right on desktop, console (10-foot), tablet and phone out of the
box. shadcn is authored in CSS pixels; Roblox screens range from ~390x844 points
on a phone to 4K TVs.

## Decision

Three layers, each doing one job:

1. **Scaling** (`Adaptive`): every app ScreenGui gets one UIScale. Components are
   authored in pixels at a base resolution; the scale is `min(viewport / base)`
   clamped. Each device class has a profile (mobile base 640x360, tablet 1024x640,
   desktop 1280x720, console 1280x720 never below 1x).
2. **Density** (`Tokens.densities`): control heights and the type scale per device
   class: `default` (shadcn sizes), `touch` (44px minimum targets), `tv`. A density
   sheet is derived next to the theme (ADR 0003), so sizes switch without code.
3. **Responsive values** (`Responsive.pick / watch`): props such as Stack's
   `direction` or `gap` accept `{ mobile = ..., touch = ..., compact = ...,
   default = ... }`, resolved by device, then input mode, then breakpoint, then
   orientation.

Helpers wrap Roblox constraints: `Adaptive.aspect` (UIAspectRatioConstraint),
`Adaptive.clamp` (UISizeConstraint) and `Adaptive.breakpoints` (StyleQuery
`@Compact / @Regular / @Wide` for rules).

## Consequences

- Most screens need no device code at all; the rest use responsive props.
- Profiles and densities are tables a game can override in `App.new`.
- Breakpoint StyleQuery conditions use screen size after scaling.
