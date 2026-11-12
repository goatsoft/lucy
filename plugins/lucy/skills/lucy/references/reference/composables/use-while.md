<!-- Made by scripts/skills.ts from docs/reference/composables/use-while.md. Edit the doc, not this file. -->
# useWhile

`Lucy.useWhile` runs a setup function whenever a condition becomes `true`, and
cleans up everything it made when the condition becomes `false` or the owner
stops.

The setup function can return a cleanup function or connection, call
`Lucy.onCleanup`, or create child effects; all of them stop together when the
condition turns off.

## Usage

```luau
Lucy.useWhile(condition, callback)
```

| Argument | Type | Default | What it is |
|---|---|---|---|
| `condition` | `MaybeRef<boolean>` | required | Condition that turns the setup on and off |
| `callback` | `() -> (CleanupFn \| RBXScriptConnection \| void)` | required | Runs when the condition turns true |

### Reactivity rules

`useWhile` runs only when the condition flips between falsy and truthy. Other
state read inside `callback` does not run it again while the condition stays
true.

## Example: pausing gameplay while a dialog is open

Turn off gameplay hotkeys while a modal menu is up:

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
