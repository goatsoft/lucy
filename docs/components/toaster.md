---
title: Toaster
description: Toast notifications through app.toast.
---

# Toaster

Short notifications that slide in above every scene and dialog, then go away on
their own. Every App has one, so you never create it yourself: call
`app.toast`.

```lua
app.toast.success("Round won", { description = "+$250" })
```

Toasts sit in the bottom right corner on desktop and across the bottom on
touch devices. They never take keyboard or gamepad focus.

## Showing a toast

| Call | What it does |
|---|---|
| `app.toast(title, options?)` | Shows a toast and returns its id |
| `app.toast.success(title, options?)` | A toast with a success colour |
| `app.toast.error(title, options?)` | A toast with an error colour |
| `app.toast.warning(title, options?)` | A toast with a warning colour |
| `app.toast.info(title, options?)` | A toast with an info colour |
| `app.toast.dismiss(id?)` | Closes one toast, or all of them without an id |

## Options

| Option | Type | Default | What it does |
|---|---|---|---|
| `description` | string | | A second line under the title |
| `kind` | string | `"default"` | `default`, `success`, `error`, `warning` or `info` |
| `duration` | number | `4` | Seconds before it closes. `math.huge` keeps it until dismissed |
| `action` | table | | A button: `{ label = "Join", onClick = join }` |
| `id` | string | made up for you | Pass the id of a toast that is showing to update it in place |

## Settings

Change these before the first toast shows:

| Setting | Default | What it does |
|---|---|---|
| `Lucy.Toaster.defaults.duration` | `4` | Seconds a toast stays when no `duration` is given |
| `Lucy.Toaster.defaults.visibleToasts` | `3` | How many show at once; the newest win |
| `Lucy.Toaster.defaults.width` | `356` | Width in pixels on desktop |

## Examples

A toast that updates as work finishes:

```lua
local id = app.toast("Uploading...", { duration = math.huge })
upload()
app.toast.success("Uploaded", { id = id }) -- replaces it and starts its timer
```

A toast with a button:

```lua
app.toast("Party invite", {
    action = { label = "Join", onClick = joinParty },
})
```

Toasts are kept in app state at `toasts`, newest last, so you can read or
clear them like any other state:

```lua
local count = #app.state:get("toasts")
app.state:set("toasts", {}) -- clear every toast
```

## Preview

In Studio, from the command bar: `Lucy.Preview.show("Toaster")`.
