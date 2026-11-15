<!-- Made by scripts/skills.ts from docs/components/icon-stack.md. Edit the doc, not this file. -->
# IconStack

Several icons drawn as one. Repeat one icon to show how much of something there
is, such as more hearts for a bigger shout out, or place different icons by
hand, such as a small star on the corner of a gem. Each icon takes the theme's
colours, like [Icon](icon.md).

```luau
local function shoutOut(hearts, text)
    return Lucy.Stack.new({
        gap = "Space2",
        align = "center",
        size = UDim2.new(),
        automaticSize = Enum.AutomaticSize.XY,
        children = {
            Lucy.IconStack.new({
                icon = "lucide-extended:heart-filled",
                count = hearts,
                size = "xl",
                variant = "destructive",
                cutout = true,
            }),
            Lucy.Text.new({ text = text, variant = "muted", autoWidth = true }),
        },
    })
end

Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space6",
    align = "end",
    children = {
        shoutOut(1, "Nice set"),
        shoutOut(3, "Floor filler"),
        shoutOut(5, "Legend"),
    },
    Parent = parent,
})
```

## Arrangements

Give it an `icon` and a `count`, and `arrange` lays them out:

- `fan`: the biggest in the middle and on top, each further out smaller, lower and
  tilted away, like a hand of cards.
- `row`: all the same size in a line, each a little over the one before.
- `pile`: rows that get shorter going up, with the bottom row in front.

```luau
local function stars(arrange)
    return Lucy.IconStack.new({
        icon = "lucide-extended:star-filled",
        count = 4,
        arrange = arrange,
        size = "lg",
        variant = "warning",
        cutout = true,
    })
end

Lucy.Stack.new({
    direction = "horizontal",
    gap = "Space6",
    align = "center",
    children = { stars("fan"), stars("row"), stars("pile") },
    Parent = parent,
})
```

The stack is as big as its icons, so a layout around it gives the whole fan or
pile its room.

## Placing icons yourself

`layers` places each icon, and then `count` and `arrange` are not used. A layer
names its own `icon` and `variant`, or takes the stack's.

```luau
Lucy.IconStack.new({
    size = 48,
    layers = {
        { icon = "lucide-extended:gem-filled", variant = "primary" },
        {
            icon = "lucide-extended:star-filled",
            x = 0.4,
            y = 0.35,
            size = 0.45,
            rotation = 15,
            variant = "warning",
        },
    },
    cutout = true,
    Parent = parent,
})
```

Each layer takes:

| Field | Default | What it does |
|---|---|---|
| `icon` | the stack's `icon` | What this layer draws |
| `x`, `y` | `0` | How far it sits from the middle, in icons: `0.5` is half an icon right (or down) |
| `size` | `1` | Its share of the stack's size: `1` is the full size, `0.5` half |
| `rotation` | `0` | How far it is turned, in degrees |
| `variant` | the stack's `variant` | Its colour, as Icon's |
| `z` | `0` | Higher is in front. Layers with the same `z` go in the order listed, the last on top |

## Cutout

Where icons overlap, solid shapes of one colour run together. With `cutout`, each
icon gets a thin ring in the colour under the stack, so it stands apart from the
ones behind it. The ring takes the card colour. On another colour, give the ring
that colour with a rule of your own, for a frame you have tagged `shout-out`:

```luau
app.theme:addRules("shoutOuts", {
    {
        selector = ".shout-out >> .ui-icon-stack-cutout",
        priority = 10,
        properties = { ImageColor3 = "$Primary" },
    },
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `icon` | string or number | `""` | yes | The icon every layer draws unless it names its own: a registered name, an asset id or a url |
| `count` | number | `1` | yes | How many icons to arrange |
| `arrange` | string | `"fan"` | yes | `fan`, `row` or `pile` |
| `layers` | table | none | yes | Places each icon yourself (see above); `count` and `arrange` are then not used |
| `size` | string or number | `"md"` | yes | The biggest icon: `sm` (16 pixels), `md` (20), `lg` (24), `xl` (28), or a number of pixels. A quarter larger on TV |
| `variant` | string | `"default"` | yes | The colour of every layer that names none, as Icon's |
| `cutout` | boolean | `false` | yes | A ring round each icon in the colour under the stack |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes the [props every component takes](index.md#using-a-component).

## Preview

In Studio, from the command bar: `Lucy.Preview.show("IconStack")`.
