---
type: Reference
title: Tabs, Bot Panel, and Mini Mode
description: Overview of every /tbm tab, per-bot panel controls, mini mode, and targeting rules.
tags: [usage, tabs, ui, controls]
status: stable
generated: { by: "antigravity/gemini", at: "2026-11-25T14:55:00Z" }
sources:
  - id: features-doc
    resource: https://github.com/TortoiseBots/TortoiseBotsManager/blob/main/docs/play/features.md
    title: Addon features overview
  - id: controls-doc
    resource: https://github.com/TortoiseBots/TortoiseBotsManager/blob/main/docs/play/controls.md
    title: Mini bar, key bindings, and slash commands
---

# Tabs

| Tab | Purpose |
|---|---|
| **Fight** | Attack, stop, interrupt, flee, pull/pullback, "My pull" hold, focus/CC marks, movement orders, party switches (AoE, auto CC, loot, sap, spread), and tactics. |
| **Camp** | Rest, ready check, repair, sell junk, train, downtime errands for own alts, release/corpse run, rebuff, formations, quests, and grinding. |
| **Party** | Group roster and roles; opens each bot's gear and bags. |
| **Guild** | Claimed raid alts in your guild; farm, buy, and craft orders with live progress. |
| **Roster** | Account characters: log in/out, invite, kick, summon, fill party or raid. |
| **Raid** | Shown in raids: raid tactics and loaded boss tactics. |
| **Dungeon** | Shown when enabled by the server: bot-led or player-led dungeon runs. |
| **Loot** | Shown when enabled by the server: party bot loot and roll history. |
| **Log** | Recent bot messages and server replies. |

# Panels and Targeting

- **Bot panel:** Paper doll, bags with upgrade markers, equip/trade/use/mail/bank items, per-bot switches, shaman totems, paladin auras, hunter aspects, warlock curses, spells, NPC errands, and flights. Open from a Party row, `Gear & bags`, the target-frame button, or `/tbm bags <name>`.[^features-doc]
- **Bots overview:** One row per party bot with fight switches (via **Bots** on the Party tab).
- **Mini mode:** `Mini` (or `/tbm mini`) switches to a compact bar of fight buttons and favourites.[^controls-doc]
- **Quiet targeting:** Button clicks travel over addon messages without chat spam. Targeting one of your bots scopes orders to that bot; otherwise orders apply to the whole party.

Related: [Protocol and Development](../developers/protocol-and-dev.md).

[^features-doc]: Addon features overview
[^controls-doc]: Mini bar, key bindings, and slash commands
