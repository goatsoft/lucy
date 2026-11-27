---
title: Tag binder
description: Lucy.Binder binds behaviour to CollectionService tags with automatic Maid cleanup, optional ancestor scoping, and StreamingEnabled safety.
order: 8
---

# Tag binder

`Lucy.Binder` binds behaviour to every Roblox `Instance` carrying a `CollectionService` tag, on
either the server or the client. Each bound instance gets its own `Lucy.Maid` that cleans up
automatically when the tag is removed, the instance leaves its scoped ancestor (such as streaming
out of `Workspace`), or the binder is destroyed.

## Basic usage

Create a binder in a service's `init` (non-yielding) or a client world module:

```luau
local Lucy = require(ReplicatedStorage.Packages.Lucy)

local doors = Lucy.Binder.new("LockedDoor", function(instance: Instance, maid: Lucy.Maid)
	if not instance:IsA("BasePart") then
		return nil
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Unlock"
	prompt.Parent = instance
	maid:give(prompt)
	maid:give(prompt.Triggered:Connect(function(player)
		-- handle unlock
	end))
	return { door = instance, prompt = prompt }
end, { ancestor = workspace })
```

Pass `{ ancestor = workspace }` whenever tagged templates might live in `ServerStorage` or
`ReplicatedStorage`: the binder ignores them until a clone is parented into `workspace`, and
cleans them up automatically if they are reparented out or streamed out.

## Class form

Instead of a function, you can pass a class table with `.new(instance, maid)`. If the returned
object has a `:destroy()` or `:Destroy()` method, `Binder` gives it to the instance's `Maid`
automatically:

```luau
local Camera = {}
Camera.__index = Camera

function Camera.new(part: Instance, maid: Lucy.Maid)
	local self = setmetatable({ part = part }, Camera)
	return self
end

function Camera:destroy()
	-- tear down camera state
end

local cameras = Lucy.Binder.new("SecurityCamera", Camera, { ancestor = workspace })
```

## Side-effect-only binders

If your callback returns `nil`:
- If you gave at least one task to `maid`, the binding is still tracked and cleaned up when the
  instance leaves.
- If `maid` is empty (for example, an early guard like `if not instance:IsA("BasePart") then return nil end`),
  the instance is skipped and `binder:has(instance)` stays `false`.

## API

| Member | Description |
|---|---|
| `Binder.new(tag, target, options?)` | Starts binding `tag` immediately. `target` is `fn(instance, maid) -> value?` or `{ new = fn }`. `options`: `{ ancestor?: Instance, warn?: (...any) -> () }`. |
| `binder.tag` | The tag string this binder watches. |
| `binder.added` | `Lucy.Signal` fired with `(instance, value)` after an instance is bound. |
| `binder.removed` | `Lucy.Signal` fired with `(instance, value)` right before an instance's `Maid` cleans up. |
| `binder:get(instance)` | Returns the value returned by the constructor for `instance`, or `nil`. |
| `binder:has(instance)` | Returns `true` if `instance` is currently bound. |
| `binder:all()` | Returns a shallow copy table `{ [Instance]: value }` of all currently bound instances. |
| `binder:count()` | Returns the number of currently bound instances. |
| `binder:destroy()` | Disconnects all listeners and cleans up every bound instance's `Maid`. (`Destroy` alias also provided.) |

## Error handling

If a constructor raises an error for one instance, its partial `Maid` is cleaned, a warning is
emitted (`[Lucy] Binder("<tag>"): ...`), and all other tagged instances continue binding normally.
