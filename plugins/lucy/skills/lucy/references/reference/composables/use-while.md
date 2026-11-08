<!-- Made by scripts/skills.ts from docs/reference/composables/use-while.md. Edit the doc, not this file. -->
# useWhile

`Lucy.useWhile` executes a setup function whenever a condition turns `true`, and
automatically cleans up everything created by that function when the condition
turns `false` or when the enclosing owner stops.

The setup function can return a cleanup function or connection, call
`Lucy.onCleanup`, or create nested effects; all resources are tracked and torn
down cleanly when the condition deactivates.

## Usage

```luau
Lucy.useWhile(condition, callback)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `condition` | `MaybeRef<boolean>` | required | Reactive condition triggering the setup callback |
| `callback` | `() -> (CleanupFn | RBXScriptConnection | void)` | required | Runs when condition flips to true |

### Reactivity rules

`useWhile` triggers only when the condition flips truthiness (from `false` to
`true`, or `true` to `false`). Values read inside the callback body do not
re-trigger the callback while the condition remains true.

## Example: pausing gameplay and hotkeys in Club Lucy

A frequent pattern is disabling gameplay movement and hotkeys while a modal menu
or dialogue is open:

```luau
local UserInputService = game:GetService("UserInputService")

Lucy.useWhile(function()
    return app:modalOpen()
end, function()
    -- Disable the gameplay input context and character movement
    local cleanupActions = app.actions:disable("gameplay", "movement")

    local conn = UserInputService.InputBegan:Connect(function(input)
        -- Consume ambient clicks while modal is active
    end)

    return function()
        cleanupActions()
        conn:Disconnect()
    end
end)
```
