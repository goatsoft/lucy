<CaseFigure
  note="#screenshot-note"
  src="/images/case-studies/dance-lab/title.webp"
  alt="Dance Lab's title screen: PLAY DANCE LAB, LEADERBOARDS and CREDITS over the club's stage"
  caption="The title screen, with the club running live behind the menu"
  device="console"
/>

## The game

Dance Lab is a dance battle rhythm game on Roblox, for phone, desktop and
console. Players sign up for a show, pick their song & moves then dance it
off on the stage while the crowd cheers and votes. Between shows players can visit the shop, 
check leaderboards, hang out in the club, dance and more.

There is a lot of screens, and every one has to work with mouse, controller
and touch. All of it runs on Lucy.

## Before Lucy

Dance Lab started with its UI built by hand. Each screen made its own frames,
handled its own focus, its own navigation, it used a small dialog manager
to manage state, closing other dialogs, locking input focus etc... 
A state machine then tracked where the player was (the title screen, loading in, in the club), 
and an monolithic client script wired it all together.

It worked, but every new screen meant handling focus, navigation, hotkeys and the styling
all over again.

## What Lucy replaced

### One look, set once

Dance Lab's theme is Lucy's tokens with the club's colours: deep navy cards,
a cyan primary and a hot pink focus ring. Each screen has a colour of its own,
set as a named colour, and everything inside inherits it: outlines, titles, tabs
and buttons. No screen sets a colour or a font itself.

<CaseFigure
  note="#screenshot-note"
  src="/images/case-studies/dance-lab/settings.webp"
  alt="The settings sheet: GAME, SOUND and GRAPHICS tabs with LB and RB hints, and switches for auto drink, key hints, hats and streamer mode"
  caption="Settings: tabs with bumper hints, and switches saved to the player's profile"
  device="console"
/>

### Controller, keyboard and touch

Every control takes focus, and Lucy draws the focus ring in the theme's colour. Key
hints follow the player's input device, so a controller player sees LB and RB on the
tabs and a phone shows none. Hotkeys are named actions in sets, and Dance Lab's
sets switch off on their own while a menu is open:

```luau
Lucy.useWhile(function()
    return sessionState() ~= "InClub" or app:modalOpen()
end, function()
    return app.actions:disable("club")
end)

Lucy.useWhile(function()
    return app:modalOpen()
end, function()
    return app.actions:disable("movement")
end)
```

That replaced the hand made hotkey chain and the movement sink.

<CaseFigure
  note="#screenshot-note"
  src="/images/case-studies/dance-lab/inventory-controller.webp"
  alt="The inventory sheet on a controller: the focus ring on Flat-Top Neon Sunglasses, LB and RB on the tabs, LT on JOIN THE SHOW"
  caption="The inventory, moved through with a controller"
  device="console"
/>

### Dialogs and sheets that only build when they are opened

The game has seventeen panels and seven scenes. A sheet builds its content the
first time it opens, so a player who never opens settings never pays for it upfront:

```luau
local sheet = Lucy.Sheet.new({
    id = "settings",
    title = "SETTINGS",
    width = 560,
    fill = true,
    build = content,
})
```

A switch in it reads and writes the player's settings, which are kept on their
profile and follow them to every device:

```luau
local function switch(key: string): any
    return Lucy.Switch.new({
        id = `settings-{key}`,
        size = CONTROL_SIZE,
        checked = function(): boolean
            return Settings.get(key) == true
        end,
        onCheckedChange = function(checked: boolean)
            Settings.set(key, checked)
        end,
    })
end
```

<CaseFigure
  note="#screenshot-note"
  src="/images/case-studies/dance-lab/dance-menu.webp"
  alt="The dance menu: genre, role and rarity filters, sorting, the focus ring on POWER FLAIR CYCLE, and five slots for a chain of moves"
  caption="The dance menu: filters, sorting and a chain of up to five moves"
  device="console"
/>

### One screen, every device

Each screen is written once and runs on a desktop, a console and a phone. Lucy
sets the density from the device, so controls grow for a thumb, and a row of
tabs with no room left scrolls. The leaderboards and the DJ booth below are the
same code everywhere.

<CaseFigure
  note="#screenshot-note"
  src="/images/case-studies/dance-lab/leaderboards-desktop.webp"
  alt="The leaderboards on MOST WINS: eight board tabs, ALL TIME and THIS WEEK, the top three with crowns and the player's own row pinned at the bottom"
  caption="The leaderboards on Most Wins"
  device="desktop"
/>

<CaseFigure
  note="#screenshot-note"
  src="/images/case-studies/dance-lab/leaderboards-phone.webp"
  alt="The same leaderboards on a phone: larger text and avatars, and the board tabs scrolling sideways"
  caption="The same leaderboards, with tabs that scroll"
  device="phone"
/>

<CaseFigure
  note="#screenshot-note"
  src="/images/case-studies/dance-lab/dj-booth-desktop.webp"
  alt="The DJ booth on VOTE GENRE: HOUSE leading with one vote, then TECHNO, DUBSTEP and ANTHEM, while a banner says the show is starting"
  caption="The DJ booth: voting on the next genre"
  device="desktop"
/>

<CaseFigure
  note="#screenshot-note"
  src="/images/case-studies/dance-lab/dj-booth-phone.webp"
  alt="The DJ booth on a phone: a drawer filling the screen with six genres in a grid of three"
  caption="The DJ booth as a drawer, every genre in view"
  device="phone"
/>

### State the game and the UI share

What scene the player currently is in, their role in a show and the music all live in the App's
store. Screens read it and the game writes it, with nothing in between. The
leaderboards come from Lucy's boards, the server every save goes through
Lucy's data queue, so a busy show never runs past Roblox's limits on saving.

### Built and checked in Studio

Stories show any screen in Studio without pressing Play. Every picture on this
page was taken by a coding agent through lucy-mcp: it opened each screen,
pressed through it, moved the focus and took the picture.

## Numbers

With the move to Lucy the games architecture has grown a lot, 
the numbers below compare some screens before and after moving to Lucy.

| What | Before | Now |
|---|---:|---:|
| Title menu | 620 lines | 339 lines |
| Dance menu | 1,160 lines | 359 lines |
| DJ Booth | 947 lines | 346 lines |

## What we would tell another Roblox developer

- **Put the state in the store first.** Screens should read
  and write from the store; most of the lines saved above came from there.
- **Name your hotkeys.** Actions in sets, can then be switched off while a menu is open,
  this will replace the `if` chains and make key hints free.
- **Give an id for everything a player interacts with.** It makes running tests
  and an AI agent's job much easier.

### Porting to Lucy: Lessons learned

- **Move a screen at a time.** Dance Lab ran its old UI / helpers next to Lucy until
  the last screen moved over to Lucy.
- **Test frequently.** As you move screens to Lucy, write and keep running tests to ensure 
    the new implementation behaves as expected.