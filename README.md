# OmaGravity (`cjkaufman.omagravity`)

Antigravity CLI integration and session manager for Omarchy Linux.

Brings Google DeepMind's Antigravity CLI (`agy`) directly into the Omarchy ecosystem as a first-class agent, complete with quick launch shortcuts, Herdr multi-agent workspace routing, live conversation history extraction from SQLite, default agent registration, and a liquid glass Quickshell top bar widget.

---

## Key Features

- **Interactive Bar Widget:** Top bar icon with ready indicator, active session counter, and default agent badge.
- **Session Explorer:** Directly parses `~/.gemini/antigravity-cli/conversation_summaries.db` to show recent conversation titles, last modified timestamps, and turn counts with one-click resume.
- **Multiple Launch Modes:** Launch directly into interactive terminals (`foot`, `ghostty`), open in Herdr multi-agent workspaces, summon floating scratchpads, or execute inline.
- **Default Agent Integration:** Seamlessly sets and syncs Antigravity as Omarchy's system-wide default coding agent (`omarchy default agent agy` and `omarchy agent`).
- **Security-Hardened Architecture:** Trusted absolute binary path resolution, bounded non-blocking subprocesses with 256KB output ceilings, and race-resistant `0o700` state directories with atomic state writes.

---

## Keybindings Reference

Add these keybindings to `~/.config/hypr/bindings.lua`:

```lua
-- Antigravity CLI & OmaGravity
o.bind("SUPER + A", "Antigravity Quick Launch", "foot -a org.omarchy.agent -T 'Antigravity CLI' -D " .. (os.getenv("HOME") or "") .. "/Work agy --dangerously-skip-permissions")
o.bind("SUPER + SHIFT + A", "Antigravity Continue Session", "foot -a org.omarchy.agent -T 'Antigravity CLI' -D " .. (os.getenv("HOME") or "") .. "/Work agy -c")
o.bind("SUPER + SHIFT + CTRL + A", "OmaGravity Bar Toggle", "omarchy-shell shell toggle cjkaufman.omagravity")
o.bind("SUPER + ALT + A", "Antigravity Desktop IDE", "antigravity")
```

---

## CLI Commands

The `bin/omagravity` helper provides command-line control:

```bash
# Run system and binary diagnostics
omagravity doctor

# Sync SQLite conversation summaries and update state.json
omagravity sync

# Set Antigravity as Omarchy default agent
omagravity set-default

# Launch in preferred terminal
omagravity launch

# Open inside Herdr multi-agent workspace
omagravity launch --mode herdr

# Resume specific session by ID
omagravity resume <conversation-id>

# Launch desktop IDE
omagravity ide
```

---

## Configuration Settings

Configurable via Omarchy's bar settings or `manifest.json`:

| Setting | Type | Default | Description |
|---|---|---|---|
| `launchMode` | enum | `terminal` | Target environment (`terminal`, `herdr`, `floating`, `scratchpad`) |
| `preferredTerminal` | enum | `foot` | Terminal emulator (`foot`, `ghostty`, `default`) |
| `defaultWorkDir` | enum | `work` | Default folder (`work`, `hivemind`, `home`) |
| `skipPermissions` | boolean | `true` | Auto-approve tool execution permissions on quick launch |
| `showBadge` | boolean | `true` | Show status badge when Antigravity is active or default |
| `recentLimit` | integer | `5` | Maximum recent conversations shown in session list |
| `refreshIntervalSec`| integer | `15` | Polling and SQLite state sync interval |

---

## License

MIT License (c) 2026 Carl Kaufman.
