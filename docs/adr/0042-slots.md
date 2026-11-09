# 0042: Slots

- Status: accepted
- Date: 2026-11-10

## Context

A badge, a button and the items of a tab bar, a select or a menu all hold
content, but Lucy built them around text props: `Badge` took `text`, `Button`
`text` and one `icon`, a tab or an option its `text`. Anything else had to be
worked around in each game: a bot icon drawn beside a badge instead of in it, a
price tag built into a card instead of a button, a genre tab styled from the
outside. Web kits (shadcn and the rest) make these components boxes with a slot:
whatever you put in goes inside, and it takes the component's colours.

The reason Lucy did not was styling. With the text on the root, one rule
(`.ui-badge`'s TextColor3) styles it; with a slot the words are a child, and a
child's own rules (Text's variant rules, priority 10) beat a parent's that do
not outrank them. Button already showed the way round it: its hinted label and
icon get twins of the button's text rules (`> .ui-button-label`,
`>> .ui-kbd-image`), one level above the child's own.

## Decision

- **Content components take `children`.** One name everywhere, because
  `content` already means a tab's or section's panel. Badge, Button,
  SortButton and Toggle take `children` (strings, handles, instances or
  builders) laid out in a row with their icon and text; the items of
  ToggleGroup, Tabs, Select, RadioGroup and Accordion take `children` (and
  ToggleGroup, Tabs and Select items an `icon`); Checkbox, Switch and
  Collapsible take `children` after their label. `text`, `label` and `icon`
  stay as shorthand that fill the same slot, so every existing call keeps
  working. With `icon` or `children` and no text, there is no default text.
- **Menu keeps label, icon and hint.** Its items are actions drawn three ways
  (a list, a ring of round buttons, an arc of pills); a free slot has no place
  in a ring button, so a menu item stays a label and an icon.
- **One module fills slots: `Components/Slot`.** `Slot.fill(parent, content)`
  makes a string a Text (tagged `ui-slot-text`), adopts handles and instances and
  runs builders.
- **Colour flows down by generated rules.** `Slot.flow(rules)` takes a
  component's own rules and, for each one that sets text properties, adds
  twins: the slot's own words (`> .ui-slot-text`) get its colour, fade, font
  and size; any Text below (`>> .ui-text`) its colour and fade; any Icon below
  (`>> .ui-icon`) the colour and fade as ImageColor3 and ImageTransparency. The
  twins sit 11 above the rule they come from, so they beat Text and Icon's own
  variants (10) at every level, and a game's own tone rules (40 and up) still
  beat them.
- **Where the slot is a row inside the component** (a toggle's row clears its
  underline, a select option's row clears its tick) `Slot.flow(rules, path)`
  takes the way to it (`" > .ui-toggle-slot > ."`). **A slot beside a
  control** (a checkbox's, switch's or radio's label, a collapsible's header)
  uses `Slot.beside(rootSelector)`: Foreground, medium, TextSm words, faded at
  0.5 when the root is `ui-disabled`. Parts that are not content (a sort
  chevron, a collapsible's chevron) keep their own colour with a rule above
  the twins (priority 50).
- **Games tint a component with `Slot.foreground(selector, colour, priority)`**,
  which writes the rule and its twins, so a rarity badge's words and icon
  change colour together.

## Consequences

- A badge can be a bot icon, a count beside a name, or an avatar with a name;
  a button can carry a price tag or two icons, without a game rebuilding the
  component.
- Every content component follows the same rules, and the colour of what is
  inside comes from the component, hover and disabled included.
- More rules per component (the twins), made once at load.
- A game rule that set TextColor3 on a component's root only reaches the root's
  own text; to colour slot content it uses `Slot.foreground`.
- A ToggleGroup item's or Toggle's children now sit in a `Slot` frame inside
  the button, not directly in it; a select option's label sits in its `Slot`
  frame. Code that looked for them as the button's children looks one level
  down.
- An icon in a slot takes the component's colour. A full-colour picture opts
  out with the `ui-icon-untinted` tag.
