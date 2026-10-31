---
title: Known issues
description: Problems Lucy cannot fix on its own, what you will see, why, and what to do instead.
order: 9
---

# Known issues

Things that don't work the way you would expect, because of how Roblox works,
not because of a bug in Lucy. Each one says what you will see, why, and what to
do instead.

## Escape always opens Roblox's menu

**What you see.** Pressing Escape opens Roblox's own menu, every time, even
while a Lucy dialog or menu is open. Lucy does not go back on Escape, so with
a dialog open, Escape leaves the dialog where it is and opens Roblox's menu on
top of it.

**What to do.** Players go back with B on a gamepad and Backspace on a
keyboard; see [Back keys](architecture.md#back-keys). Show Backspace in key
hints, and give menus a visible close or back button. For a pause menu, see the
[pause menu recipe](recipes/pause-menu.md).

**What we wanted.** Escape closes the top thing Lucy has open, and opens
Roblox's menu only when nothing is open. Roblox does not let a game do this.

**Why.** We measured this in Studio:

1. Every Escape opens Roblox's menu, from the first press, whatever the game
   has open. The game's scripts still hear the key, marked as already used by
   Roblox. Lucy used to go back on Escape as well, so the menu opened on top of
   whatever Lucy had just done.
2. Opening the menu clears the selected object (`GuiService.SelectedObject`),
   and closing it does not put it back, so keyboard and gamepad players lost
   their place. Lucy now puts focus back itself when the menu closes.
3. While the menu is open, Escape never reaches the game. It only closes the
   menu.
4. A `ContextActionService` binding on Escape, at the highest priority and
   sinking the key, never runs. Roblox's own scripts take the key first.
5. A game cannot close the menu either: `GuiService.MenuIsOpen` is read only,
   and `GuiService:SetMenuIsOpen` can only be called by Roblox's own scripts.

The Roblox developer forum agrees. A feature request from 2022 asks for exactly
the behaviour above. It has had no reply from Roblox and nothing has shipped.
The only ways people describe to stop the menu are glitches that turn off all
of Roblox's own UI. They break the character's movement and camera, and their
own posters say they may break Roblox's rules. The usual advice is Backspace to
go back and another key to pause.

**If you still want Escape.** Add it to the back keys:

```luau
local app = Lucy.App.new({
    backKeys = { Enum.KeyCode.ButtonB, Enum.KeyCode.Backspace, Enum.KeyCode.Escape },
})
```

Escape then goes back too, and Roblox's menu still opens on top each time.

**When this may change.** If Roblox lets a game take Escape, Lucy will go back
on it again. To check, open a dialog, press Escape and read
`GuiService.MenuIsOpen`.

Sources:

- [Let developers temporarily override the Escape key using ContextActionService](https://devforum.roblox.com/t/let-developers-temporarily-override-the-escape-key-using-contextactionservice/2021335) (feature request, October 2022)
- [Any way of overwriting the Roblox Esc menu?](https://devforum.roblox.com/t/any-way-of-overwriting-the-roblox-esc-menu-menu-that-opens-when-pressing-escape-force-enter-gameplay-paused-state/3247111) (November 2024)
- [Any way to disable escape from opening the roblox menu](https://devforum.roblox.com/t/any-way-to-disable-escape-from-opening-the-roblox-menu/1658874) (February 2022)
- [How do I disable the escape keybind that opens the ROBLOX menu?](https://devforum.roblox.com/t/how-do-i-disable-the-escape-keybind-that-opens-the-roblox-menu/3268243) (November 2024, no answer)
- [New Keybinds for Keyboard Navigation](https://devforum.roblox.com/t/new-keybinds-for-keyboard-navigation/2069353) (Roblox, December 2022): the keys Roblox uses for UI navigation, which do not include Backspace

## Start and Select on a gamepad

A gamepad's Start (menu) button opens Roblox's menu the same way, so a game
cannot use it, for pausing or anything else. Select (View) may be Roblox's on
some platforms too. Lucy goes back on B, so a game screen's `onBack` can open a
pause menu from the gamepad; see the [pause menu recipe](recipes/pause-menu.md).
