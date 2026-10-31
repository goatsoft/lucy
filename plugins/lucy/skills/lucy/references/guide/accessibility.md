<!-- Made by scripts/skills.ts from docs/guide/accessibility.md. Edit the doc, not this file. -->
# Make your UI accessible

Lucy's components are readable and reachable out of the box. This guide covers
the parts that depend on your own UI: the colours you pick, where focus starts,
and how you size and animate things. What Lucy does by itself is in
[Accessibility](../reference/accessibility.md).

## Use the text tokens

Text on a fill uses the fill's matching `*Foreground` token, never `$White` or
`$Black`. The foreground is worked out to read on its fill in every theme, so
your rule stays right when the theme changes.

```luau
local rules = {
    {
        selector = ".shop-badge",
        properties = {
            BackgroundColor3 = "$Primary",
            TextColor3 = "$PrimaryForeground",
        },
    },
    {
        selector = ".shop-sold-out",
        properties = {
            BackgroundColor3 = "$DestructiveSubtle",
            TextColor3 = "$DestructiveSubtleForeground",
        },
    },
}
```

For a pale wash behind a message, like an alert, use the `*Subtle` pair:
`DestructiveSubtle` with `DestructiveSubtleForeground`, and the same for
`Success`, `Warning` and `Info`.

## Check colours of your own

If you add a colour token, give it a foreground with `Lucy.Tokens.onColor`
rather than picking one by eye:

```luau
local themes = Lucy.Tokens.themesFor("slate", { primary = "lime" })
themes.dark.Primary = "$Lime300"
themes.dark.PrimaryForeground = Lucy.Tokens.onColor("$Primary")
```

To check any two colours, `Lucy.Oklab.contrast(a, b)` gives their contrast ratio.
Body text needs at least 4.5:1, large text and icons at least 3:1:

```luau
print(Lucy.Oklab.contrast(Color3.fromRGB(255, 200, 0), Color3.new(1, 1, 1))) -- 1.6, too low
```

Do this for both themes: a colour that reads on light can fail on dark.

## Don't rely on colour alone

Some players can't tell red from green. Say what happened in words as well: a
toast or alert has a title, and a status icon gets a label next to it.

## Start focus somewhere useful

Keyboard and gamepad players start each screen on its `defaultFocus`. Point it at
the thing they most likely want, such as Play on a title screen:

```luau
app.scenes:register("Title", {
    build = function(scene)
        scene.play = Lucy.Button.new({ text = "Play", Parent = scene.gui })
        -- ...
    end,
    defaultFocus = function(scene)
        return scene.play
    end,
})
```

Then try every screen without a mouse: Tab and the arrow keys on a keyboard,
the thumbstick and D-pad on a gamepad, Backspace or B to go back. Every control
you can click should be reachable, and back should always lead somewhere. See
[Build screens with scenes](scenes.md).

## Let controls size themselves

Players can make text larger in the Roblox menu, and Roblox then draws all text
bigger. Lucy's controls grow to fit it, but text in a box with a fixed pixel
height gets cut off. Size your own controls with the density tokens
(`$ControlMd` and the rest) or `AutomaticSize`, and let labels wrap with
`TextWrapped`, rather than fixing heights in pixels:

```luau
local rules = {
    {
        selector = ".shop-buy",
        properties = { Size = "$ControlMd", AutomaticSize = Enum.AutomaticSize.X },
    },
}
```

If code needs a control's height in pixels, `Lucy.useMetric(app, "ControlMd")`
follows both the density and the player's text size.

## Keep see-through backgrounds in tokens

Players can ask for solid backgrounds in the Roblox menu. Lucy makes every
theme token whose name ends in `Transparency` more solid to match, so put the
transparency of a see-through panel in a token rather than in the rule:

```luau
local themes = Lucy.Tokens.themesFor("slate")
themes.light.PanelTransparency = 0.2
themes.dark.PanelTransparency = 0.2

local app = Lucy.App.new({ themes = themes })

local rules = {
    {
        selector = ".hud-panel",
        properties = { BackgroundColor3 = "$Card", BackgroundTransparency = "$PanelTransparency" },
    },
}
```

Text over a see-through panel has to stay readable over whatever the game shows
behind it, so check it against the busiest scene, not the panel colour.

## Animate through Lucy

Move things with `Lucy.spring` and `Lucy.tween` rather than `TweenService`.
When a player turns on Reduce motion in the Roblox menu, Lucy's springs, and
tweens of positions and sizes, jump to where they end, so yours do too. Tweens
of colours and numbers still fade.

A number that moves something, like a rotation, needs one more step: give it a
`TweenInfo` that takes no time when motion is reduced.

```luau
local Preferences = Lucy.Preferences
local turn = Lucy.tween(function()
    return if open() then 180 else 0
end, function()
    return if Preferences.reducedMotion() then TweenInfo.new(0) else TweenInfo.new(0.2)
end)
```

If your game has its own settings menu, a Reduce motion switch can drive the
same setting:

```luau
Lucy.Switch.new({
    label = "Reduce motion",
    checked = Lucy.Preferences.reducedMotion(),
    onCheckedChange = function(on)
        Lucy.Preferences.setReducedMotion(on)
    end,
    Parent = settingsPanel,
})
```

Keep motion short, and never make it the only sign that something happened.

## Next

- [Accessibility](../reference/accessibility.md): the contrast Lucy promises, focus,
  sizes, the Roblox settings it follows and `Lucy.Preferences`
- [Theming](../reference/theming.md): every colour token and the `Tokens` helpers
