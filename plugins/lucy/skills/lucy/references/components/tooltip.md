<!-- Made by scripts/skills.ts from docs/components/tooltip.md. Edit the doc, not this file. -->
# Tooltip

A floating label or small card attached to a screen control or to a part in the
world.

```luau
local buy = Lucy.Button.new({
    text = "Moonwalk",
    icon = "lucide-extended:sparkles-filled",
    Parent = shopRow,
})

local tip = Lucy.Tooltip.new({
    target = buy,
    text = "<b>100</b> coins in the Emote Shop",
    textProps = { richText = true },
    side = "top",
})
```

On mouse, hovering the button waits a short delay and opens the tooltip; moving
off closes it. On gamepad and keyboard, selecting the button opens it. On touch,
a long press opens it. Only one hover tooltip opens at a time, and moving onto
another button opens the next one right away while the tip group is warm.

## Triggers

Choose how the tooltip opens with `trigger` (a single name or a list, such as
`{ "hover", "focus" }`):

| Trigger | Shows | Hides |
|---|---|---|
| `"hover"` | Pointer rests on `target` (plus gamepad focus and touch long press) | Pointer leaves (after `closeDelay`) |
| `"focus"` | Gamepad or keyboard selection lands on `target` | Selection leaves |
| `"press"` / `"hold"` | Press down on `target` | Release |
| `"click"` / `"toggle"` | Click or tap on `target` | Next click, press outside, or Back |
| `"proximity"` | Character enters `distance` studs of a world `target` | Character leaves `distance + hysteresis` studs |
| `"always"` | Starts open | Only if hidden in code or `open` is set to `false` |
| `"manual"` | Only via `:show()` or `open` | Only via `:hide()` or `open` |

A hold-to-peek tooltip on a locked emote:

```luau
local locked = Lucy.Button.new({ text = "Moonwalk", variant = "outline", Parent = shopRow })

local lockedTip = Lucy.Tooltip.new({
    target = locked,
    trigger = "press",
    text = "Reach level 15 in Club Lucy to unlock",
})
```

An interactive card on a track's info button that stays open while the pointer
crosses onto it and includes a button:

```luau
local info = Lucy.Button.new({
    icon = "lucide-extended:disc-3-filled",
    size = "icon",
    variant = "ghost",
    Parent = shopRow,
})

local infoTip = Lucy.Tooltip.new({
    target = info,
    trigger = "click",
    interactive = true,
    content = function(tip)
        return Lucy.Stack.new({
            gap = "Space2",
            children = {
                Lucy.Text.new({ text = "Neon Nights by DJ Lucy (124 BPM)", autoWidth = true }),
                Lucy.Button.new({
                    text = "Queue track",
                    size = "sm",
                    onClick = function()
                        queueTrack("neon-nights")
                        tip:hide()
                    end,
                }),
            },
        })
    end,
})
```

## Placement and arrow

- `side`: `"top"`, `"bottom"`, `"left"`, `"right"` or `"auto"`.
- `align`: `"start"`, `"center"` or `"end"`.
- `placement`: shorthand such as `"top-start"` or `"bottom-end"`.
- `sideOffset` / `offset`: gap in pixels from a screen `target` (default `8`), or `studsOffset` in studs for a world `target`.
- `alignOffset`: offset in pixels along the alignment edge (default `0`).
- `avoidCollisions`: flips or shifts the tooltip to keep it inside the screen (default `true`; set `false` to keep its placement fixed).
- `collisionPadding`: screen edge margin in pixels (default `8`).
- `flip`: flips to the opposite side when there is not enough room on screen (default `true`).
- `arrow`: draws the directional notch centred on `target` (default `true`). Read `tip.arrowDirection()` for `"down"`, `"up"`, `"left"` or `"right"`.
- `arrowPadding`: minimum room in pixels kept between the arrow and rounded corners (default `6`).

## Variants, border, fill and transparency

`variant` picks a look from the theme: `default`, `inverse`, `primary`,
`secondary`, `outline`, `destructive` or `overlay`.

```luau
Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space2",
    wrap = true,
    children = {
        Lucy.Tooltip.new({ text = "default", variant = "default" }),
        Lucy.Tooltip.new({ text = "inverse", variant = "inverse" }),
        Lucy.Tooltip.new({ text = "primary", variant = "primary" }),
        Lucy.Tooltip.new({ text = "secondary", variant = "secondary" }),
        Lucy.Tooltip.new({ text = "outline", variant = "outline" }),
        Lucy.Tooltip.new({ text = "destructive", variant = "destructive" }),
        Lucy.Tooltip.new({ text = "overlay", variant = "overlay" }),
    },
    Parent = parent,
})
```

- `size`: `"sm"`, `"md"` or `"lg"`.
- `border`: `true` or `false` to force or remove the border, or a token/colour such as `"$Ring"`.
- `fill`: override the body and arrow fill with a token (`"$Card"`) or `Color3`.
- `transparency`: background transparency (`0` to `1`) for both body and arrow.
- `radius`: corner radius override (token, `UDim`, or pixels).

Register custom variants once with `Lucy.Tooltip.addVariant`:

```luau
Lucy.Tooltip.addVariant("vip", {
    { selector = "", properties = { BackgroundColor3 = "$Warning", TextColor3 = "$WarningForeground" } },
    { selector = "::UIStroke", properties = { Color = "$Warning" } },
})
```

## Text options and custom content

`text` renders with [Text](text.md) (`tip.label`). Any Text option (`richText`,
`variant`, `align`, `value`, `count`, `reveal`, `fit`, `reserve`) can be passed
through `textProps`:

```luau
Lucy.Tooltip.new({
    target = payoutBadge,
    textProps = {
        value = function() return coins() end,
        count = 0.5,
        format = function(n) return `{Lucy.Format.number(n)} coins` end,
    },
})
```

Pass `children` or `content` to place any Lucy component inside the tooltip. By
default a tooltip's `variant` colours its label and any child `Text` to match;
setting `textProps = { variant = ... }` or giving a child `Text` its own
colour variant (such as `"muted"` or `"warning"`) overrides the tooltip's text
colour.

## In the world

Set `target` to a `BasePart`, `Attachment` or `Model` to hang the tooltip in a
billboard over that object:

```luau
-- Crew name tag always shown above Kai
Lucy.Tooltip.new({
    target = workspace.Crew.Kai.Head,
    trigger = "always",
    side = "top",
    arrow = false,
    variant = "overlay",
    children = {
        Lucy.Stack.new({
            direction = "horizontal",
            gap = "Space2",
            align = "center",
            children = {
                Lucy.Avatar.new({ name = "Kai", size = "sm" }),
                Lucy.Text.new({ text = "Kai", autoWidth = true }),
                Lucy.Badge.new({ text = "VIP", variant = "secondary" }),
            },
        }),
    },
})

-- Wardrobe mirror hint shown when walking close
Lucy.Tooltip.new({
    target = workspace.Wardrobe.Mirror,
    trigger = "proximity",
    distance = 10,
    text = "Try on outfits in the Wardrobe",
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `target` | GuiObject, BasePart, Attachment, Model, handle or id | | | What the tooltip attaches to |
| `text` | string | `""` | yes | Text rendered with `Lucy.Text` |
| `textProps` | table | | | Options forwarded to `Lucy.Text` |
| `children` | table | | | Components placed inside the body |
| `content` | any | | | Builder `function(tip)` or component placed inside |
| `trigger` | string or table | `"hover"` | | `hover`, `focus`, `press`, `hold`, `click`, `toggle`, `proximity`, `always`, `manual` |
| `distance` | number | `12` | yes | Proximity range in studs |
| `hysteresis` | number | `1` | | Extra studs needed to leave proximity |
| `lineOfSight` | boolean | `false` | | Require an unobstructed raycast for proximity |
| `side` | string | `"top"` | yes | `top`, `bottom`, `left`, `right` or `auto` |
| `align` | string | `"center"` | yes | `start`, `center` or `end` |
| `placement` | string | | | Combined `side-align` shorthand such as `"top-start"` |
| `sideOffset` / `offset` | number | `8` | yes | Pixel gap from a screen target |
| `alignOffset` | number | `0` | yes | Pixel offset along the alignment edge |
| `studsOffset` | number | `0.5` | | Stud gap from a world target |
| `avoidCollisions` | boolean | `true` | | Flip and shift automatically to stay inside the screen |
| `collisionPadding` | number | `8` | | Screen edge margin in pixels |
| `flip` | boolean | `true` | | Flip side when there is more room opposite |
| `arrow` | boolean | `true` | yes | Show the directional arrow |
| `arrowPadding` | number | `6` | | Room kept between the arrow and rounded corners |
| `variant` | string | `"default"` | yes | `default`, `inverse`, `primary`, `secondary`, `outline`, `destructive`, `overlay` or registered |
| `size` | string | `"md"` | yes | `sm`, `md` or `lg` |
| `border` | boolean, string or Color3 | | | Force/hide border or set border colour |
| `fill` | string or Color3 | | | Override background fill |
| `transparency` | number | | | Override background transparency (`0` to `1`) |
| `radius` | string, UDim or number | | | Override corner radius |
| `interactive` | boolean | `false` | | Allow moving pointer onto the tooltip |
| `open` | boolean | `false` | yes | Whether it is open (`true` when `trigger = "always"`) |
| `visible` | boolean | `true` | yes | Master visibility toggle |
| `onOpenChange` | function | | | Called with `(open, tip)` when open changes |

It also takes the [props every component takes](index.md#using-a-component).

## Methods and parts

- `tip:show()`, `tip:hide()`, `tip:toggle()`
- `tip.open()`: tracked boolean getter
- `tip.side()`: tracked side after flipping
- `tip.arrowDirection()`: tracked direction (`"down"`, `"up"`, `"left"`, `"right"`)
- `tip.body`, `tip.arrow`, `tip.stroke`, `tip.arrowStroke`, `tip.label`

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Tooltip")`.
