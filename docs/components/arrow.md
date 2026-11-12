---
title: Arrow
description: A big arrow that points at something on screen, grows in and bounces.
---

# Arrow

A big arrow that points at one thing: the button a new player should press, a
new item in the shop, a door they can walk through. It grows in when it shows,
then keeps moving so the eye finds it. [Tour](tour.md) points at each step's
target with one.

<!-- preview animate="1.6" fps="12" warmup="0.45" -->
<figure class="example-preview"><img class="example-light" src="/images/examples/components-arrow-light.webp" alt="Arrow example" loading="lazy"><img class="example-dark" src="/images/examples/components-arrow-dark.webp" alt="Arrow example" loading="lazy"></figure>

```luau
local arrow = Lucy.Arrow.new({
    direction = "down",
    Position = UDim2.fromOffset(640, 120), -- where the tip goes
    Parent = hud,
})
```

Its AnchorPoint is its tip, so `Position` is the spot it points at. Keep a few
pixels of gap between the tip and the thing.

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `direction` | string | `"down"` | yes | `down`, `up`, `left` or `right`: the way it points |
| `variant` | string | `"arrow"` | yes | `arrow` (a shaft and a head), `chevron` (a bold head) or `triangle` |
| `motion` | string | `"bounce"` | yes | `bounce` (back from the tip and in again), `pulse` (swells in place) or `none` |
| `size` | string or number | `"md"` | yes | `sm` (24), `md` (40), `lg` (56), or pixels: the arrow's square |
| `color` | string or Color3 | `"Ring"` | yes | A theme token, such as `"Primary"`, or a Color3. It follows the theme |
| `icon` | string | | yes | An icon name: your own art in place of the shape (below) |
| `visible` | boolean | `true` | yes | Shows or hides it. Showing it again grows it in again |

It also takes the [props every component takes](index.md#using-a-component).

## Methods

| Method | What it does |
|---|---|
| `arrow:replay()` | Grows it in again, for when it moves to point at something new |
| `arrow.fade()` | The transparency it is drawn at now (tracked) |

## Your own arrow

Pass any icon name your game registered (see [Icon](icon.md)). Draw it
pointing down; it is turned to `direction` like the built in shapes, and moves
the same way. It keeps the Icon's colours: register it with `tint = false` for
full colour art.

```luau
Lucy.Arrow.new({ icon = "dl:pointer", size = "lg", direction = "left", Parent = hud })
```

## Motion

- It grows in from its tip with a small overshoot (0.45 s), then bounces or
  pulses on a 0.8 s beat. `Arrow.timing`, `Arrow.travel` (how far a bounce goes,
  a share of the size) and `Arrow.swell` (how much a pulse grows) hold these.
- With reduced motion (see [Accessibility](../reference/accessibility.md)) it
  fades in and keeps still; a pulse becomes a gentle fade in and out.

## Look

The shapes are rounded frames in `color`, so they need no upload and stay sharp
at any size. Parts: `arrow.body` (moves), `arrow.scale` (its UIScale),
`arrow.shape` (turned to the direction), `arrow.parts.arrow`,
`arrow.parts.chevron`, `arrow.parts.triangle`, and `arrow.icon` once an icon is
set. Tags: `ui-arrow`, `ui-arrow-variant-<variant>`, `ui-arrow-motion-<motion>`.

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Arrow")`.
