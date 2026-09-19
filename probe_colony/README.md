# Probe Colony — mining/gathering vertical slice

What's here in code (safe, hand-written): all 6 `.gd` scripts, and 3 `.tscn`
scenes that only use primitive shapes (no imported art, so they're safe to
hand-author as text). What's NOT safe to hand-author as text: Input Map
actions and TileSet resources — both involve editor-generated resource
IDs that are easy to get subtly wrong outside the GUI. Do those two things
in the editor, ~5 minutes total, steps below.

## 1. Open the project
Open Godot 4.3+, "Import", point it at this folder's `project.godot`.

## 2. Add Input Map actions
Project > Project Settings > Input Map tab. Add these actions (name must
match exactly) and assign a key to each:

| Action name    | Key       |
|----------------|-----------|
| `move_up`      | W (or Up) |
| `move_down`    | S (or Down)|
| `move_left`    | A (or Left)|
| `move_right`   | D (or Right)|
| `mine`         | Space     |

## 3. Build the TileMap
Open `scenes/world.tscn`. Select the `TileMap` node, create a new `TileSet`
in the Inspector, and add a source using any placeholder tile image (even
a single solid-color 16x16 PNG works fine for now — swap art later, code
doesn't care).

Then, on the TileSet (bottom panel, "TileSet" tab > "Custom Data Layers"),
add three custom data layers:

- `solid` — type **bool**
- `minable` — type **bool**
- `drop_item_id` — type **String**

Select your ore-ish tile(s) in the TileSet editor and set their custom
data: e.g. `minable = true`, `drop_item_id = "raw_ore"`. Set any wall/solid
tiles to `solid = true`.

Paint some tiles onto the TileMap's Layer 0 in the 2D view.

## 4. Add the player
In `world.tscn`, drag `scenes/player.tscn` in as a child of `World`, and
position it somewhere over open ground.

## 5. Run it
F5 (or F6 to run `world.tscn` directly). WASD to move, Space to mine
whatever tile you're facing — it'll channel for `mine_duration` (0.5s by
default, tweak on the Player node), then drop an item that flies to you
once you're close enough.

## What's deliberately not built yet
- No inventory UI (items are tracked in `Player.inventory`, printed to
  console on pickup)
- No crafting
- No charge/power stat
- Movement is grid-snapped with a short slide animation, not free pixel
  movement — easiest to get facing/collision right; swappable later since
  it's isolated inside `MoveCommand`
