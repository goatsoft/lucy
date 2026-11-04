# 0037: Shared props and variants live in the spec

- Status: proposed
- Date: 2026-11-04

## Context

Every component is mounted by `Component.mount(spec, props)` (ADR 0018, 0019),
and the handle it returns is shared through one metatable. That base owns the
id, state at `ui.<id>`, `name`, `layoutOrder`, `Parent`, reactive props, scope
ownership, the focus ring takeover and rule registration. It does not own the
props most components have in common, so each component declares and binds them
by hand. Of the 39 components:

- 37 declare `visible = true` and bind it themselves (all but Dialog and Sheet).
- 17 declare `disabled = false`; 13 bind it the same way (`Interactable`,
  `Selectable` and the `ui-disabled` tag on the root), 4 differently
  (Accordion, Menu, NumberField, Tabs).
- 16 write their own `check()` for variant, size or shape values, each with its
  own copy of the "unknown variant" error, and 13 keep a `variants` list and a
  tag getter built from it (`ui-<kind>-<key>-<value>`).

Nothing has drifted yet: every one of them binds what it declares. It holds by
convention and per component specs, so a new component, or a game's own one
written from `docs/guide/components.md`, can forget `Selectable` on disabled and
only a gamepad would notice. `Component.mount` and the spec shape are public, so
the pattern the guide teaches should be the one Lucy uses.

A base class with subclasses was considered and rejected: `render` returns an
Instance tree, so a subclass that changes it has to call the parent's render and
patch the result; Instances cannot be subclassed; and Lucy already shares
behaviour by composition (composables, shared rules and tags, `Component.clickable`).

## Decision

Two optional spec fields, handled by `mount`:

- **`common`**, a list of shared props the component takes as they are:
  - `"visible"`: default `true`; binds the root's `Visible`.
  - `"disabled"`: default `false`; binds the root's `Interactable` and
    `Selectable` to its opposite and the `ui-disabled` tag. `Component.clickable`
    already ignores clicks while disabled.

  A key in `defaults` overrides the default value. Render may still read the key
  with `h:ref` for its own behaviour (a Spinner stops turning while hidden), but
  does not bind those root properties again. A component that binds them
  somewhere other than the root (DataGrid passes `visible` to its table,
  Accordion and Tabs disable parts) leaves the key out of `common` and keeps
  doing it by hand.

  ```luau
  local spec = {
      kind = "toggle",
      common = { "visible", "disabled" },
      variants = {
          variant = { "default", "outline", "line" },
          size = { "sm", "md", "lg" },
      },
      defaults = { text = "", pressed = false, variant = "default", size = "md" },
      render = function(h) ... end,
  }
  ```

- **`variants`**, a map from state key to its allowed values. For each key
  `mount`:
  - checks the value at mount and on every change, failing with one message for
    all components: `[Lucy] unknown Toggle size "xl" (expected sm, md, lg)`. The
    name is `spec.name`, or `kind` with a capital first letter.
  - keeps the tag `ui-<kind>-<key>-<value>` on the root in step with the value
    (`spec.tagBase` overrides `ui-<kind>`).

  Defaults stay in `defaults`. Module lists (`Toggle.variants`, `Toggle.sizes`)
  point at the spec's lists, so stories and docs read the same values.

- **`Component.checkVariant(name, key, list, value)` and
  `Component.variantTags(base, variants, values)`** are the two helpers `mount`
  uses, public for parts that are not mounted on their own (ToggleGroup's items
  use Toggle's tags; Collapsible's check is used by Accordion). `Toggle.check`,
  `Toggle.tags` and `Collapsible.check` become thin calls to them.

- Error messages keep their current wording, so specs that match on them keep
  passing.

## Consequences

- About 16 `check` functions and 13 tag getters go, and around 30 hand bindings
  of `visible` and `disabled` become one line each in the spec.
- "A disabled component cannot be clicked, selected or reached by the gamepad"
  is specced once in `Component.spec.luau` for every component that lists it,
  instead of per component.
- A game's own components get the same behaviour from the documented pattern.
  `docs/guide/components.md` shows `common` and `variants`.
- The change is additive: specs without the new fields mount as before, and no
  component's props, state keys, tags or events change.
- Two ways to bind `visible` and `disabled` remain (the spec, or by hand for the
  few that need it). The by-hand ones say why in a comment.
- `mount` grows by one effect per listed key; a component that lists nothing
  pays nothing.
