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
the thumbstick and D-pad on a gamepad, Escape or B to go back. Every control
you can click should be reachable, and back should always lead somewhere. See
[Build screens with scenes](scenes.md).

## Let controls size themselves

Players can make text larger in the Roblox menu, and Roblox then draws all text
bigger. Text in a box with a fixed pixel height gets cut off. Size controls
with the density tokens (`$ControlMd` and the rest) or `AutomaticSize`, and let
labels wrap with `TextWrapped`, rather than fixing heights in pixels.

## Animate through Lucy

Move things with `Lucy.tween` and `Lucy.spring` rather than `TweenService`, so
your animations follow the same rules as Lucy's own when a player asks for less
motion. Keep motion short, and never make it the only sign that something
happened.

## Next

- [Accessibility](../reference/accessibility.md): the contrast Lucy promises, focus,
  sizes and the Roblox settings it follows
- [Theming](../reference/theming.md): every colour token and the `Tokens` helpers
