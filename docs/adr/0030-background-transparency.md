# 0030: Lucy follows the player's background transparency

- Status: proposed
- Date: 2026-10-31

## Context

ADR 0029 left `GuiService.PreferredTransparency` to do. It is a number from 0 to
1, 1 by default, read only, and changes while the game runs. Roblox's
recommended use is to multiply a background's `BackgroundTransparency` by it,
so backgrounds become solid as it nears 0.

In Lucy the only see-through background is the modal scrim, through the
`OverlayTransparency` theme token. Other transparency in rules (0.5 on disabled
controls, striped table rows, the Skeleton pulse) shows state, not a
see-through panel, and should not change.

## Decision

1. `Preferences.transparency()` returns the setting as a tracked getter, kept
   between 0 and 1. `Preferences.setTransparency(value)` lets a game's own
   settings override it, and `nil` follows Roblox again, the same shape as
   reduced motion. `_setDevice` takes `transparency` for specs.
2. `Theme:setTransparency(scale)` multiplies every number token whose name ends
   in `Transparency`, in every theme, by `scale`, from the designed values kept
   at `Theme.new`. `nil` puts them back. Rules that use the tokens update on
   their own, so no signal fires.
3. The App sets it from `Preferences.transparency()` in the same effect scope
   as text growth.

The naming rule means a game's own token, like `PanelTransparency`, follows the
setting with no code. The guide tells games to keep see-through backgrounds in
tokens for that reason.

## Consequences

- Games get it with no code for the scrim and for any `*Transparency` token.
- A see-through background set in a rule with a literal number does not follow
  it; that is the game's to move into a token.
- Studio reports 1, so the effect is seen only through `_setDevice` or
  `setTransparency` until checked on a device.
