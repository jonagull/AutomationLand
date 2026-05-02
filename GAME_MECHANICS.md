# AutomationLand — Game Mechanics Reference

## Concept

A top-down 2D farmer automation game built in Godot 4. Tasks start manual, then the player unlocks automation bots they can program with a custom scripting language. The progression loop is: do it by hand → understand the work → automate it → optimize the automation.

**Aesthetic: solarpunk.** Hopeful, green, community-oriented. Technology works *with* nature — bots are helpers, not replacements. The farm should feel alive and thriving, not industrial.

---

## Player

- **WASD** movement, **Shift** to sprint
- **E** to interact with nearby objects (bots, PC terminal)
- `CharacterBody2D` with `velocity.move_toward()` for snappy feel, normalized diagonal movement
- Stats: `ACCELERATION=800`, `FRICTION=1200`, `MAX_WALK_SPEED=100`, `MAX_SPRINT_SPEED=200`

**File:** `assets/2d_top_down_character_controller/2d_top_down_character_controller.gd`

---

## Field

A 24×16 grid of cells. Each cell has a **state**, a **pH level**, and a **nutrition level**.

### Cell States

| State | Color | Description |
|-------|-------|-------------|
| `BARE` | Brown | Fresh/harvested dirt |
| `PLOWED` | Dark brown | Ready to seed |
| `SEEDED` | Dark + brown | Seeds planted, growing starts |
| `GROWING` | Green | Crops actively growing |
| `READY` | Gold/yellow | Ready to harvest |

### State Transitions (tools required)

```
BARE  + PLOW      → PLOWED
PLOWED + SEEDER   → SEEDED
READY  + HARVESTER → BARE
```

### Grow Times

- `SEEDED → GROWING`: 90 seconds
- `GROWING → READY`: 150 seconds
- **Total grow time: 4 minutes**

### pH

- Per-cell float, range `0.0–14.0`, default `7.0`
- `PH_UP` tool: +0.5 per application
- `PH_DOWN` tool: −0.5 per application

### Nutrition

- Per-cell float, range `0.0–100.0`, default `50.0`
- `FERTILIZER` tool: +20 per application
- Depletes by **−15** when a crop reaches `READY`
- If nutrition hits 0, crops still grow (no penalty yet — planned)

### Public Field Methods (useful for bots/UI)

```gdscript
field.get_state(cell: Vector2i) -> Field.State
field.get_ph(cell: Vector2i) -> float
field.get_nutrition(cell: Vector2i) -> float
field.apply_tool(cell: Vector2i, tool: Field.Tool) -> bool
field.count_cells_in_state(state) -> int
field.average_nutrition() -> float
field.average_ph() -> float
field.cell_center_world(cell) -> Vector2
field.is_valid_cell(cell) -> bool
```

**File:** `scripts/farm/field.gd`  
**Scene:** `scenes/farm/field.tscn`

---

## FarmRegistry

Global autoload. Fields register themselves by name on `_ready`.

```gdscript
FarmRegistry.get_field("field")   # → Field node or null
FarmRegistry.list()               # → Array of names
```

**File:** `scripts/farm/farm_registry.gd`

---

## FarmBot

An automatable robot the player programs. Press **E** nearby to open its local terminal.

### Properties (upgradeable via @export)

| Property | Default | Description |
|----------|---------|-------------|
| `move_duration` | 0.8s | Time to move one cell |
| `work_duration` | 0.7s | Time to apply a tool |
| `turn_duration` | 0.4s | Time to rotate 90° |
| `active_tool` | SEEDER | Currently equipped tool |
| `home_cell` | (0,0) | Cell the bot returns to with `home()` |
| `field` | null | Field node the bot works on |

### Visual

- **Cyan** square = idle
- **Orange** square = working
- White triangle arrow = facing direction

### State

- `current_script: String` — the last loaded/typed script (synced with local terminal)
- `log_history: Array[String]` — last 200 log lines (shown in network terminal)
- `facing: Vector2i` — current facing direction

**File:** `scripts/farm/farm_bot.gd`  
**Scene:** `scenes/farm/farm_bot.tscn`  
Children: `BotRunner` (Node), `BotTerminal` (CanvasLayer), `InteractionArea` (Area2D)

---

## Bot Scripting Language

A custom Lua-like language. Parsed and executed by `BotRunner`. All commands are async — the bot physically moves/works before the next command runs.

### Movement

```
move_to(x, y)       -- teleport-move to cell (x, y)
move_forward()      -- move one cell in current facing direction
face("up"|"right"|"down"|"left")
turn_right()        -- rotate 90° clockwise
turn_left()         -- rotate 90° counter-clockwise
home()              -- return to home_cell
```

### Tools

```
set_tool("plow"|"seeder"|"harvester"|"ph_up"|"ph_down"|"fertilizer")
use_tool()          -- apply active_tool to current cell
```

### Queries (return values for use in expressions/conditions)

```
get_state()         -- state of current cell: "BARE","PLOWED","SEEDED","GROWING","READY"
get_ph()            -- pH of current cell (float)
get_nutrition()     -- nutrition of current cell (float)
get_posx()          -- bot's current grid X
get_posy()          -- bot's current grid Y
```

### Output / Setup

```
print(value)
check_ph(x, y)       -- logs pH at cell (x,y)
check_nutrition(x,y) -- logs nutrition at cell (x,y)
get_state(x, y)      -- logs state at cell (x,y)  [command form]
wait(seconds)
set_field("name")
set_home(x, y)
```

### Variables

```
var x = 5
var name = "hello"
x = x + 1
```

Arithmetic: `+  -  *  /`  
Supported in any expression or argument.

### Conditionals

```
if condition
  ...
elseif condition
  ...
else
  ...
end
```

**Condition operators:** `==  !=  >  <  >=  <=`  
**Examples:**
```
if get_state() == "READY"
if get_nutrition() < 30
if get_posx() >= 12
if x != 0
```

String comparisons are case-insensitive.

### Loops

```
repeat(n)     -- repeat n times
  ...
end

repeat        -- loop forever
  ...
end

repeat()      -- also loops forever
  ...
end
```

### Functions

```
func harvest_row()
  repeat(23)
    move_forward()
    use_tool()
  end
end

harvest_row()   -- call it
```

### Comments

```
-- this is a comment
move_forward()  -- inline comment
```

### Full Example — Lawnmower Pattern

```
set_field("field")
set_home(0, 0)

func do_row()
  use_tool()
  repeat(23)
    move_forward()
    use_tool()
  end
end

repeat
  set_tool("plow")
  face("right")
  repeat(8)
    do_row()
    turn_right()
    move_forward()
    turn_right()
    do_row()
    turn_left()
    move_forward()
    turn_left()
  end
  home()

  if get_nutrition() < 30
    set_tool("fertilizer")
    face("right")
    repeat(8)
      do_row()
      turn_right()
      move_forward()
      turn_right()
      do_row()
      turn_left()
      move_forward()
      turn_left()
    end
    home()
  end

  set_tool("seeder")
  face("right")
  repeat(8)
    do_row()
    turn_right()
    move_forward()
    turn_right()
    do_row()
    turn_left()
    move_forward()
    turn_left()
  end
  home()

  wait(240)

  set_tool("harvester")
  face("right")
  repeat(8)
    do_row()
    turn_right()
    move_forward()
    turn_right()
    do_row()
    turn_left()
    move_forward()
    turn_left()
  end
  home()
end
```

**File:** `scripts/farm/bot_runner.gd`

---

## Bot Terminal (Local)

Opens when player presses **E** near a FarmBot.

- **Script tab** — full multi-line code editor
  - Syntax highlighting, line numbers, auto-indent
  - `Ctrl+Enter` to run, `Escape` to close
  - Error lines highlighted red
  - Status bar shows cursor line/col
- **CLI tab** — single-command prompt
  - Type one command, press Enter or ↵
  - `↑ / ↓` for command history
  - Command echoed in green, bot output follows inline
  - Same scripting language — supports full syntax including if/repeat/func

**File:** `scripts/ui/bot_terminal.gd`

---

## Network System

### NetworkManager

Global autoload. Bots and fields register automatically on `_ready`.

```gdscript
NetworkManager.get_bots()    # → Array of FarmBot nodes
NetworkManager.get_fields()  # → Array of Field nodes
```

**Future:** wire-based connection mechanic — bots/fields will only appear on the network after being physically wired to the PC. Currently everything auto-registers.

**File:** `scripts/network/network_manager.gd`

### Network Terminal (PC)

A PC the player can interact with (press **E**). Shows all networked bots and fields.

**Left panel:**
- Live bot list — `●` green = running, `○` grey = idle, gold highlight = selected
- Field stats — name, size, ready cell count, average nutrition, average pH
- Refreshes every 1 second

**Right panel — Script tab:**
- Loads the selected bot's current script for remote editing
- **Run** / **Stop** controls the selected bot
- **Copy to All** — pushes the current code to every bot's local terminal (does not auto-run)
- `Ctrl+Enter` to run

**Right panel — CLI tab:**
- Same as local bot terminal CLI, but targets the selected bot
- Switching bots clears the CLI output and loads the new bot's log history in the Script tab

**File:** `scripts/network/network_terminal.gd`  
**UI:** `scripts/ui/network_terminal_ui.gd`  
**Scene:** `scenes/network/network_terminal.tscn`

---

## Project Structure

```
scripts/
  farm/
    field.gd              # Field grid, states, pH, nutrition, grow timers
    farm_bot.gd           # Bot node, commands, log history
    bot_runner.gd         # Script parser + async executor
    farm_registry.gd      # Autoload — named field lookup
  network/
    network_manager.gd    # Autoload — bot + field registry
    network_terminal.gd   # PC node (interaction + draw)
  ui/
    bot_terminal.gd       # Local bot terminal UI (Script + CLI tabs)
    network_terminal_ui.gd # Network PC UI (Script + CLI tabs)

scenes/
  main.tscn               # Main scene (World, Field, FarmBot, NetworkTerminal, Player)
  farm/
    farm_bot.tscn         # FarmBot + BotRunner + BotTerminal + InteractionArea
    field.tscn            # Field node
  network/
    network_terminal.tscn # NetworkTerminal + NetworkTerminalUI + InteractionArea

assets/
  2d_top_down_character_controller/
    2d_top_down_character_controller.gd  # Player movement
```

---

## Planned / Not Yet Built

- **Wire mechanic** — physical wire item to connect bots/fields to network (NetworkManager already has register/unregister, just needs the gate)
- **pH effects on growth** — faster/slower grow times based on pH (infrastructure exists)
- **Nutrition effects on growth** — low nutrition slows crops or reduces yield
- **Multiple bots** — networking and Copy-to-All already support it
- **Bot upgrade system** — `move_duration`, `work_duration`, `turn_duration` are `@export` vars, ready to be modified by an upgrade system
- **Manual tractor** — wider (3-cell) tool for early-game manual farming before bots
- **A* pathfinding** — for click-to-move navigation
- **Larger world / multiple fields** — FarmRegistry and NetworkManager already support named multi-field setups
