extends CharacterBody2D
## Player: the machine you control.
##   - Move with A/D, jump with W (a side-view platformer).
##   - 1-9, 0 select a hotbar slot. Whatever is selected is your "active item".
##   - Hold Space to USE the active item:  drill = mine, magnet = pull drops.
##     Items with no function (like a lump of ore) do nothing yet.
##   - Q throws the selected item out into the world.
##
## The heavy lifting lives in other files:
##   miner.gd     - the drill        hotbar.gd    - the on-screen slots
##   inventory.gd - what you carry   dropped_item.gd - drops (they read our magnet_*)
##
## KEYS are NAMED ACTIONS from Project Settings > Input Map (use_item, throw_item,
## hotbar_1..hotbar_10, move_*). This file never mentions a specific key, so a
## future keybinding menu only has to reassign those actions.

# --- Movement settings (adjustable in the Inspector) -------------------------
@export var speed: float = 400.0          # sideways speed, pixels/second
@export var jump_velocity: float = -600.0 # negative = up. Bigger number = higher jump
@export var gravity: float = 1200.0       # downward pull, pixels/second squared

# --- Magnet (pulls nearby drops toward you while it is active) ---------------
# The pull on a drop is:  magnet_strength * (1/d^2 - 1/magnet_range^2)
# where d is its distance from you in pixels. It fades to exactly zero at
# magnet_range. Drops read these numbers from us every tick (see
# dropped_item.gd), so a future magnet/suction upgrade only has to change them.
## Bigger = stronger pull. Units are pixels^3 / second^2 (a pull in px/s^2 times d^2).
## Tier 1 value (raised from 1.5e7, which felt too weak); upgrades raise it.
@export var magnet_strength: float = 25000000.0
## Beyond this many pixels there is no pull at all.
@export var magnet_range: float = 300.0

# --- Throwing ----------------------------------------------------------------
## How fast a thrown item leaves your hand, pixels/second. It arcs under gravity.
@export var throw_speed: float = 600.0
## Spawn the thrown item this far from our centre so it starts outside our body.
@export var throw_start_distance: float = 95.0
## Seconds before a thrown item can be picked up or magnetised again.
@export var throw_pickup_delay: float = 1.5

# --- State -------------------------------------------------------------------
## What we're carrying (data only).
var inventory := Inventory.new()

## True while the magnet is switched on. Drops check this every tick.
var magnet_active: bool = false

# The child nodes made in player.tscn.
@onready var _hotbar: Hotbar = $Hotbar   # the on-screen slot row
@onready var _miner: Miner = $Miner      # the drill behaviour

var _world: Node = null                  # the World node; found on first use


func _ready() -> void:
	# Lets other scripts (like drops) find the player.
	add_to_group("player")

	# Connect the on-screen hotbar and the drill to us.
	_hotbar.setup(inventory)
	_miner.setup(self)

	# Starting kit: the drill and the magnet take the first two slots.
	inventory.add_item("drill")
	inventory.add_item("magnet")


# Runs every physics tick (60 times a second by default). `delta` is the time
# since the last tick, so `something * delta` means "per second" amounts.
func _physics_process(delta: float) -> void:
	# Gravity: pull down whenever we're not standing on something.
	if not is_on_floor():
		velocity.y += gravity * delta

	# Jump, but only from the ground (no mid-air jumps).
	if Input.is_action_just_pressed("move_up") and is_on_floor():
		velocity.y = jump_velocity

	# get_axis returns -1 (left), 0 (none) or +1 (right).
	velocity.x = Input.get_axis("move_left", "move_right") * speed

	# Applies velocity, sliding along walls/floors and handling collisions.
	move_and_slide()

	_update_active_item(delta)


# ---------------------------------------------------------------------------
# Using the selected item
# ---------------------------------------------------------------------------

# Looks at which item is selected and, if the use button is held, does what that
# item does. To give a NEW item a function, add another case here (or, if it gets
# big, its own script like miner.gd).
func _update_active_item(delta: float) -> void:
	var active_item: String = inventory.get_item(inventory.selected)
	var using: bool = Input.is_action_pressed("use_item")

	# Magnet: on only while it's selected AND the use button is held.
	magnet_active = using and active_item == "magnet"

	# Drill: the miner handles aiming and mining (it also clears its outline
	# when the drill isn't selected, so we tell it every tick).
	_miner.tick(delta, active_item == "drill", using)


# ---------------------------------------------------------------------------
# Throwing
# ---------------------------------------------------------------------------

# Called by Godot for input nothing else has used.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("throw_item"):
		_throw_selected_item()


# Removes the selected item from the inventory and tosses it toward the mouse.
func _throw_selected_item() -> void:
	# Find the World if we haven't yet (same reason as in miner.gd).
	if _world == null:
		_world = get_tree().get_first_node_in_group("world")
		if _world == null:
			return

	# Take the item out of the selected slot. Empty slot -> nothing happens.
	var item_id: String = inventory.take_item(inventory.selected)
	if item_id == "":
		return

	# Direction from us toward the mouse. If the mouse is exactly on us, throw right.
	var aim: Vector2 = get_global_mouse_position() - global_position
	var dir: Vector2 = aim.normalized() if not aim.is_zero_approx() else Vector2.RIGHT

	# Start just outside our body. If that spot is inside solid rock (we're
	# pressed against a wall and throwing into it), start at our centre instead,
	# which is always open, so the item can't spawn stuck in the wall.
	var start: Vector2 = global_position + dir * throw_start_distance
	if not _world.is_walkable(_world.world_to_grid(start)):
		start = global_position

	_world.spawn_drop(start, item_id, _world.item_icon(item_id), dir * throw_speed, throw_pickup_delay)


## Tries to pick up one item. Returns true if it fit, false if the inventory is
## full. Drops call this (see dropped_item.gd).
func add_item(item_id: String) -> bool:
	return inventory.add_item(item_id)
