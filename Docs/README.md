# Mordial Shell — Contributor Documentation

Architecture and how-to guides for working on the shell. For build/test commands
and project conventions, see [`../AGENTS.md`](../AGENTS.md).

## Contents

| Document                                                   | What it covers                                                                                                       |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| [`bar-widgets.md`](bar-widgets.md)                         | How bar widgets work: what defines a widget, the registry, the render pipeline, settings storage, and interactivity. |
| [`adding-a-bar-widget.md`](adding-a-bar-widget.md)         | Step-by-step guide to adding a new bar widget, with a full template and checklist.                                   |
| [`desktop-widgets.md`](desktop-widgets.md)                 | How floating desktop widgets work, including the desktop-vs-bar comparison.                                          |
| [`adding-a-desktop-widget.md`](adding-a-desktop-widget.md) | Step-by-step guide to adding a new desktop widget, with a full template and checklist.                               |

## Other references in the repo

- [`IPC.md`](IPC.md) — source of truth for all `qs ipc call` commands (keep in sync when adding handlers).
- [`../CREDITS.md`](../CREDITS.md) — fork status vs upstream Noctalia, config migration notes.
