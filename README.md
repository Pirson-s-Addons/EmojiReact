<h1 align="center">Emoji & React</h1>

<p align="center">
  <b>Emojis in chat and speech bubbles, plus a reaction wheel for World of Warcraft: Forever</b>
</p>

<p align="center">
<a href="https://github.com/Pirson-s-Addons/EmojiReact/releases/latest">
<img src="https://img.shields.io/github/v/release/Pirson-s-Addons/EmojiReact?style=for-the-badge&color=A78BFA">
</a>
<img src="https://img.shields.io/badge/WoW_Forever-1.60.1-C4B5FD?style=for-the-badge">
<a href="LICENSE">
<img src="https://img.shields.io/badge/License-MIT-E9D5FF?style=for-the-badge">
</a>
</p>

<p align="center">
<a href="README.es.md">🇪🇸 Español</a>
</p>

---

## What it does

**Emoji & React** brings the emojis you use every day to WoW Forever's chat and speech bubbles, and adds a **reaction wheel**: hold a key, point the mouse towards a reaction, release, and it pops up above your character for nearby players who also have the addon.

| You type | You see |
|---|---|
| `:joy:` `:heart_eyes:` `:thumbsup:` | the emoji, in chat and in the bubble |
| `:)` `:D` `<3` `xD` | the matching emoji |
| a pasted emoji (Win + .) | the emoji instead of a blank box |

## Features

- 39 emojis in chat and in /say, /yell and party speech bubbles.
- Emoji button inside the chat box: a grid with every emoji, click to insert it.
- Classic emoticons (`:)`, `:D`, `<3`...) converted too, without touching links or URLs.
- Reaction wheel that looks and works like the game's own **Ping Wheel**: hold **the key you choose** (keyboard, combination or mouse button), point the mouse towards a reaction and release; release on the center X to cancel. 6 pages of 4 reactions, switched with the mouse wheel, all of them chosen by you.
- Settings live in the game's own **Options → AddOns** panel: sizes, what to convert, the wheel key, the wheel reactions and the height of your own reaction.
- Lightweight, no libraries.

## Installation

1. Download the zip from the [latest release](https://github.com/Pirson-s-Addons/EmojiReact/releases/latest).
2. Extract the `EmojiReact` folder into `World of Warcraft/_classic_beta_/Interface/AddOns/`.
3. Restart WoW and enable the addon.

## Usage

- `/emoji` opens the settings. `/emoji key` chooses the wheel key. `/emoji test` shows a reaction above you.
- **Options → AddOns → Emoji & React → General**: chat, bubbles, sizes, wheel key and wheel reactions.
- To see **other players'** reactions, turn on *Show friendly player names* in the same panel: reactions appear above their nameplate.

## Notes

- Messages are still sent as text (`:joy:`): players without the addon see the text, as with any emoji addon.
- Blizzard does not let addons touch speech bubbles or nameplates **inside dungeons and raids**: there emojis only show in chat and reactions are not shown.
- Your own character has no nameplate, so your reaction is placed above the screen center. Adjust *Height above you* to your camera zoom.

---

**Author**: Pirson · [GitHub](https://github.com/Pirson-s-Addons) · [CurseForge](https://www.curseforge.com/members/pirson/projects) · MIT License · Emoji graphics: [Twemoji](https://github.com/jdecked/twemoji) (CC-BY 4.0)
