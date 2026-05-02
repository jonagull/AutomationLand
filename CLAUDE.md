# AutomationLand — Claude Context

## Project

Godot 4 top-down 2D farmer automation game. GDScript only (no C#). The gameplay loop is manual farming → unlock bots → program bots with a custom scripting language → optimize automation.

**Aesthetic inspiration: solarpunk.** The world should feel hopeful, green, and community-oriented — technology that works *with* nature rather than against it. Visuals, naming, and mechanics should reflect that (e.g. bots are helpers, not replacements; the farm thrives, not just produces).

Full mechanics reference: `GAME_MECHANICS.md`

## Tech Stack

- Godot 4.6, GDScript, Forward Plus renderer
- No external libraries or plugins
- Physics: Jolt (3D only, irrelevant here)

## Key Files

```
scripts/farm/field.gd               Field grid, states, pH, nutrition
scripts/farm/farm_bot.gd            Bot node + all bot_* commands
scripts/farm/bot_runner.gd          Script parser + async executor
scripts/farm/farm_registry.gd       Autoload: named field lookup
scripts/network/network_manager.gd  Autoload: bot + field registry
scripts/network/network_terminal.gd PC interaction node + _draw()
scripts/ui/bot_terminal.gd          Local bot terminal (Script/CLI tabs)
scripts/ui/network_terminal_ui.gd   Network PC UI (Script/CLI tabs)
scenes/main.tscn                    Main scene
scenes/farm/farm_bot.tscn           FarmBot scene
scenes/network/network_terminal.tscn PC scene
assets/.../2d_top_down_character_controller.gd  Player
```

## Architecture Notes

### Async command pattern
Every `bot_*` function in `farm_bot.gd` is a coroutine that emits `command_done` when finished. Synchronous commands do `await get_tree().process_frame` before emitting to avoid race conditions. `BotRunner` awaits `command_done` between commands.

### Scripting language
Parser in `bot_runner.gd` builds an AST of dicts: `{type, name, args, body, branches, ...}`. Executor walks the tree with `await`. Supports: variables, arithmetic, conditionals (if/elseif/else/end), loops (repeat/end), user functions (func/end), and expression queries (`get_state()`, `get_ph()`, `get_nutrition()`, `get_posx()`, `get_posy()`).

### Bot commands dispatch
`BotRunner._execute_block` calls `_bot.callv("bot_" + name, args)`. Adding a new command = add `func bot_mycommand(...)` to `farm_bot.gd` — it's automatically available in scripts.

### Network
`NetworkManager` autoload holds all bots and fields. They self-register in `_ready` / deregister in `_exit_tree`. The wire-gating mechanic is not yet built — everything auto-connects.

### current_script sync
`FarmBot.current_script` is the canonical script store. `BotTerminal` keeps it in sync via `text_changed`. `NetworkTerminalUI` reads and writes it when selecting/running bots. `bot.load_script(code)` updates both `current_script` and the local terminal's CodeEdit.

## Conventions

- All UIs are built programmatically (no .tscn UI scenes) — `_build_ui()` in `_ready()`
- `@tool` on field.gd and farm_bot.gd for editor visibility
- `_` prefix = private by convention (GDScript doesn't enforce it)
- Bot speed stats are `@export` vars — ready for an upgrade system
- Field size is 24×16, cell size is 16px

## Autoloads (project.godot)

```
FarmRegistry  → scripts/farm/farm_registry.gd
NetworkManager → scripts/network/network_manager.gd
```

## Input Actions

| Action | Key |
|--------|-----|
| up/down/left/right | WASD |
| sprint | Shift |
| interact | E |

## What's Planned But Not Built

- Wire mechanic to gate network connections
- pH / nutrition effects on grow speed
- Bot upgrade system (speed stats already exported)
- Manual tractor (3-cell wide early-game tool)
- Multiple bots (networking already supports it)
- A* pathfinding for click-to-move
