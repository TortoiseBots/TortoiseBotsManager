---
type: Reference
title: Protocol and Development
description: Addon-to-module communication protocol, testing, and release workflow.
tags: [developers, protocol, testing, releases]
status: stable
generated: { by: "antigravity/gemini", at: "2026-11-25T14:55:00Z" }
sources:
  - id: protocol-doc
    resource: https://github.com/TortoiseBots/TortoiseBotsManager/blob/main/docs/developers/protocol.md
    title: Addon-to-module protocol specification
  - id: dev-doc
    resource: https://github.com/TortoiseBots/TortoiseBotsManager/blob/main/docs/developers/development.md
    title: Development, tests, and releases
---

# Protocol and Development

- **Addon protocol:** Clicks and state refreshes travel over the silent addon message channel defined in `docs/developers/protocol.md` (compatible with TortoiseBots on Tortoise WoW 1.18.1).[^protocol-doc]
- **Development and releases:** Test scripts, packaging, and release checklist are documented in `docs/developers/development.md`.[^dev-doc]
- **Attribution:** Keep the in-addon credit (window header, load message, `/tbm help`) intact in modified builds.

Related: [Tabs, Bot Panel, and Mini Mode](../usage/tabs-and-panels.md).

[^protocol-doc]: Addon-to-module protocol specification
[^dev-doc]: Development, tests, and releases
