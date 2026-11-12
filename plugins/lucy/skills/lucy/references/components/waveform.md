<!-- Made by scripts/skills.ts from docs/components/waveform.md. Edit the doc, not this file. -->
# Waveform

A row of columns drawn from a list of levels: a song's loudness to preview and scrub, an
equaliser, a meter. Columns before `progress` are lit and the rest are dimmed, so the same
waveform shows how far a song has played. Give it `onSeek` and pressing or dragging across it
moves the song.

It draws as `bars`, `blocks` or `dots`, from the bottom or mirrored about the middle, in one
colour, a colour per column, a gradient up its height, or colours blended along its width.
Every colour is a theme token by default and follows a change of theme.

```luau
-- A song's loudness, one value per column (baked from the audio, or heard as it plays)
local levels = {}
for i = 1, 64 do
    levels[i] = 0.5 + 0.35 * math.sin(i / 5) + 0.15 * math.sin(i * 1.3)
end
local played = Lucy.ref(0.4)

Lucy.Waveform.new({
    levels = levels,
    progress = played,
    variant = "dots",
    cells = 16,
    gradient = { "$Purple500", "$Pink500" },
    track = true,
    gap = 1,
    height = 96,
    size = UDim2.fromOffset(420, 96),
    onSeek = function(fraction)
        played(fraction)
    end,
    Parent = parent,
})
```

## Props

| Prop | Type | Default | State key | What it does |
|---|---|---|---|---|
| `levels` | array, ref or getter | `{}` | | One value per column, from 0 up. Columns are drawn against the loudest |
| `progress` | number | `1` | yes | From 0 to 1. Columns before it are lit, the rest dimmed |
| `variant` | string | `"bars"` | yes | `bars`, `blocks` (stacked cells, like an equaliser) or `dots` |
| `align` | string | `"bottom"` | | `bottom`, or `center` to mirror the columns about the middle |
| `cells` | number | `12` | | Cells in a full column, for `blocks` and `dots` |
| `color` | token, Color3 or function | `"$Primary"` | | The colour of every column, or a function given the column's number that returns one |
| `gradient` | table | | | `{ bottom, top }` tokens or Color3s: colour by height in place of `color`. Centred, it runs from the middle out |
| `stops` | table | | | Colours along the width, `{ { 0, "$Sky400" }, { 0.5, "$Pink500" } }`: each column takes the blend at its middle, and before the first stop or after the last it keeps that stop's colour. In place of `color`; `gradient` wins over it |
| `fade` | number | `0` | | From 0 to 1: how far cells fade out towards the top, or towards both edges when centred. `0.6` leaves the top cells 40% solid, so loud moments trail off like a glow |
| `trail` | number | `0` | | From 0 to 1: a glow over the columns just behind `progress`, this share of the width, brightest at the play position. It moves as the song plays, so playing reads as smooth movement even where columns and gaps would make the edge look like it steps (try `0.1`) |
| `track` | boolean | `false` | | Shows the unlit cells too, faintly, for `blocks` and `dots` |
| `peaks` | boolean | `false` | | A thin cap above each column |
| `stretch` | boolean | `false` | | Heights run from just under the quietest level to the loudest, curved, so loud music that never goes quiet still shows its shape |
| `gap` | number | `2` | | Pixels between columns and between cells |
| `height` | number | fills the parent | | Its height in pixels, at the parent's full width |
| `size` | UDim2 | | | Its size, in place of `height` |
| `renderer` | string | `"auto"` | | `auto`, `canvas` or `frames`, see [Drawing](#drawing) |
| `onSeek` | function | | | Called with a fraction from 0 to 1 when the player presses or drags across it. Without it, clicks go through to what is under it |
| `visible` | boolean | `true` | yes | Shows or hides it |

It also takes the [props every component takes](index.md#using-a-component).

## Drawing

A waveform draws on a canvas (`EditableImage`) when the device can make one: two pictures, the
dimmed columns and the lit ones, the lit one cut off at the progress. It draws again only when
the levels, a colour, the theme or its size change, so a playing song only moves the cut.

A device can refuse a canvas: each has a memory budget for them, and a live game needs **Allow
Mesh / Image APIs** turned on (Experience Settings, Security, in Studio; or Configure, Settings
on the Creator Dashboard). Studio always allows it. Refused, the waveform draws with Frames
instead, with at most 64 columns and 12 cells, averaged down. `renderer = "frames"` always
draws with Frames; `renderer = "canvas"` never falls back.

With `trail`, a third canvas holds a lighter copy of the lit columns, and a gradient that playing moves shows it only over the trail, so the glow costs no drawing while it plays. With Frames, the columns in the trail are lightened instead.

`handle.mode` says which it is using: `"canvas"` or `"frames"`.

## Examples

An equaliser in stacked blocks, orange to yellow, with a cap on each column:

```luau
Lucy.Waveform.new({
    levels = { 0.4, 0.7, 0.55, 0.9, 1, 0.8, 0.6, 0.85, 0.5, 0.3 },
    variant = "blocks",
    cells = 12,
    gradient = { "$Rose500", "$Amber400" },
    peaks = true,
    size = UDim2.fromOffset(320, 100),
    Parent = parent,
})
```

A song's loudness for a timeline, each section's colour blending into the next along the width,
the stops at the sections' starts:

```luau
local stops = {}
for _, section in song.sections do
    table.insert(stops, { section.start / song.length, sectionColour[section.kind] })
end

Lucy.Waveform.new({
    levels = songLevels,
    progress = function()
        return playhead() / song.length
    end,
    stretch = true,
    stops = stops,
    trail = 0.1,
    size = UDim2.fromOffset(420, 56),
    Parent = timeline,
})
```

A song's loudness, mirrored, each column in its section's colour with no blending:

```luau
Lucy.Waveform.new({
    levels = function()
        return songLevels()
    end,
    progress = function()
        return playhead() / songLength()
    end,
    align = "center",
    stretch = true,
    color = function(column)
        return sectionColour[sectionAt(column)]
    end,
    height = 64,
    Parent = timeline,
})
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Waveform")`.
