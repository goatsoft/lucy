# 0031: Escape is not a back key, because Roblox's menu owns it

- Status: accepted (JB, 2026-10-31)
- Date: 2026-10-31

## Context

ADR 0007 made Escape and ButtonB the back keys: the newest back handler runs,
else the top modal scene pops, else the screen's `onBack`. The pause test in
the second skill test run (ADR 0027) found that Escape did not behave.

What we want is the usual desktop behaviour: Escape closes the top thing Lucy
has open, and only opens Roblox's menu when nothing is open.

Measured in Studio on 2026-10-31 (LucyTests, the pause test's script, a probe
logging every Escape, `GuiService.MenuOpened` / `MenuClosed` and
`SelectedObject`):

1. Every Escape opens Roblox's menu, from the first press, whatever Lucy has
   open. `UserInputService.InputBegan` still fires for it, with
   `gameProcessedEvent = true`, so Lucy acted on it as well: it pushed Pause (or
   popped a scene) and the menu opened on top.
2. Opening the menu sets `GuiService.SelectedObject` to nil. Closing it does
   not set it back, so keyboard and gamepad players were left with no focus.
3. While the menu is open, Escape never reaches game scripts. It only closes
   the menu, so the second Escape closed the menu and Lucy did not go back.
4. A `ContextActionService:BindActionAtPriority` binding on Escape at priority
   100000 that returns `Sink` never ran, and the menu still opened.
5. A game cannot close the menu: `GuiService.MenuIsOpen` is read only, and
   `GuiService:SetMenuIsOpen` and writing `GuiService.SelectedCoreObject` fail
   with "lacking capability RobloxScript".

The developer forum agrees. A feature request from October 2022 asks for
exactly the behaviour we want (a sinking ContextActionService binding takes
Escape, holding it still opens the menu). It has no staff reply and nothing
shipped; it was bumped again in November 2024. A reply there explains point 4:
ContextActionService ignores inputs that CoreScripts register. The only ways
described to stop the menu are glitches (destroying PlayerScripts from
ReplicatedFirst and turning off all CoreGui), which break movement and the
camera and which their own posters call possible terms of service breaches.
The usual advice is Backspace for back and another key for pause. Roblox's
keyboard navigation keys (backslash, arrows, WASD, Enter, PageUp/PageDown,
Home/End) do not include Backspace.

Sources:

- Let developers temporarily override the Escape key using
  ContextActionService (feature request, 2022-10-13):
  https://devforum.roblox.com/t/let-developers-temporarily-override-the-escape-key-using-contextactionservice/2021335
- Any way of overwriting the Roblox Esc menu? (2024-11):
  https://devforum.roblox.com/t/any-way-of-overwriting-the-roblox-esc-menu-menu-that-opens-when-pressing-escape-force-enter-gameplay-paused-state/3247111
- Any way to disable escape from opening the roblox menu (2022-02, reply 2026-03):
  https://devforum.roblox.com/t/any-way-to-disable-escape-from-opening-the-roblox-menu/1658874
- How do I disable the escape keybind that opens the ROBLOX menu? (2024-11-21, unanswered):
  https://devforum.roblox.com/t/how-do-i-disable-the-escape-keybind-that-opens-the-roblox-menu/3268243
- Somehow, this game managed to entirely disable the CoreGui escape menu (2021-01):
  https://devforum.roblox.com/t/somehow-this-game-managed-to-entirely-disable-the-coregui-escape-menu-and-button/1003118
- New Keybinds for Keyboard Navigation (Roblox announcement, 2022-12-02):
  https://devforum.roblox.com/t/new-keybinds-for-keyboard-navigation/2069353

## Decision

1. The back keys are ButtonB and Backspace (`InputManager.backKeys`).
   Backspace is ignored while a TextBox has focus. Escape is not a default.
2. `App.new({ backKeys = { ... } })` sets an App's back keys. A game may add
   Escape, knowing Roblox's menu still opens each time.
3. `InputManager:keyBack(key)` decides whether a key goes back, so specs can
   drive it without the engine.
4. When Roblox's menu closes, `InputManager:restoreFocus()` puts focus back on
   what had it (if it can still take focus inside the top scope), else on the
   top scope's default focus. Only while navigating with keys or a gamepad.
   This also covers the gamepad's menu button.
5. The docs say plainly that Escape and Start belong to Roblox, and show a pause
   menu opened from `onBack` plus a visible pause button.

## Consequences

- Escape on its own now only opens Roblox's menu; Lucy leaves its scenes alone.
- Keyboard players go back with Backspace, which is less familiar than Escape.
  Kbd hints and the docs show Backspace.
- Focus survives Roblox's menu.

## Revisit

If Roblox ships a way for games to take Escape (a sinking ContextActionService
binding, an Input Action System option, or a menu that opens only when the game
lets it go), make Escape a default back key again and keep Backspace. Check the
feature request above, and re-run the measurements: press Escape with a modal
open and read `GuiService.MenuIsOpen`.
