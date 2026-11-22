# 0055: Toast holders belong to the app

- Status: accepted
- Date: 2026-11-22
- Amends: the Toaster's install (`app.toast`)

## Context

The Toaster was built lazily: the first `app.toast(...)` made it, in the app's toast portal.
Built that way it belonged to whatever was running at the time, and in a game the first toast is
often sent from inside an effect (Dance Lab's show HUD sends its event cards from a watcher). A
component built inside an effect belongs to it, so the toaster was taken down the next time that
effect ran again. Toasts stayed in the list and nothing drew them, until the game restarted. A
quick fix built the toaster in a scope of its own, but the shape was still wrong:

- There was only ever one toaster, so every toast in a game shared one position.
- Its position was an app setting (`toastPosition`) with nowhere to say "this toast goes there".
- Code that sent a toast was the code that made the UI, which is backwards.

JB (2026-11-22): there should be holders the app owns, as many as a game wants, each with its
position; toasts are told which one to use; a holder is never destroyed unless that is wanted.

## Decision

- **Holders are the app's.** `Toaster.install` builds them when the app is made, in a scope of
  their own that stops with the app. Sending a toast never builds anything.
- **There is always a `default` holder**, from `toastPosition` and `toastWidth` as before, so
  games that set those keep working unchanged.
- **More holders** come from `App.new({ toasters = { events = { position = "top-center" } } })`
  or `app.toast.holder("events", { position = "top-center", width = 480, visibleToasts = 2 })`
  at any time. Calling `holder` again for an id changes it.
- **A toast names its holder**: `app.toast("Bonus XP", { holder = "events" })`, `default` when left
  out. A holder that was never declared is an error, so a typo shows at once.
- **Removing one is deliberate**: `app.toast.removeHolder(id)` takes it down and drops its toasts.
  `default` cannot be removed.
- The list stays one list in AppState at `toasts`; each toast carries its holder, and each
  holder draws only its own. Dismissing, quiet mode and the update in place by id are unchanged.
- A holder whose portal is taken off the screen is put back in the live portal the next time a
  toast is sent to it.

## Consequences

- Toasts show however and wherever they are sent from, and a game can put the show's cards and
  small notices in different places.
- Every app has its toast portal and its default holder from the start, even one that never
  toasts: a ScreenGui and an empty frame.
- The default holder keeps the id `toaster`, so `ui.toaster.position` still moves it. Another
  holder's state is at `ui.toaster-<id>`.
