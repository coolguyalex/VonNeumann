extends Area2D
## DroppedItem: the small copy of a tile that pops out when you mine it.
##
## A drop is one of TWO things, and `gravel` is what tells them apart:
##   gravel is EMPTY - a whole item, like a tool you threw. Goes to a hotbar slot.
##   gravel is FILLED - a pebble of mined rock, carrying a mixture of materials
##                      ({ "hematite": 2.1, "regolith": 4.9 }). Goes to the hold.
## Everything else below -- falling, hopping, the magnet -- treats them the same.
##
## It has no real physics. Every tick it:
##   1. gets pulled toward the player IF the player's magnet is switched on
##      (and there is room in the inventory),
##   2. falls under gravity and lands on the first solid tile below,
##   3. if resting, counts down a random timer and then hops,
##   4. is picked up when it touches the player's body (magnet or not).
## Everything here is plain arithmetic, so it is easy to tweak.
## The world creates these and sets item_id and texture (see world.gd).
## The magnet's strength and range belong to the PLAYER (magnet_strength and
## magnet_range in player.gd), so upgrading the player upgrades every drop.

@export var item_id: String = ""
## Set by the world when spawned: a small piece of the mined tile's own image.
var texture: Texture2D = null

## What this pebble is made of ({ material id : units }), or {} if this drop is
## a whole item instead. The world fills it in (see world.mine_tile).
var gravel: Dictionary = {}

## Fake physics: falls under gravity and lands on the first solid tile below.
## (Named fall_gravity because Area2D already has a built-in "gravity".)
## Comes from units.gd so pebbles fall at the same rate the player does.
@export var fall_gravity: float = Units.GRAVITY_PX
@export var drop_scale: float = 0.3    # a ratio of the tile's own size, whatever that is

## Sideways slowdown, in "fraction of speed lost per second". Without it a
## drop that got pulled sideways would slide forever. Higher = stops quicker.
@export var ground_drag: float = 5.0   # while resting on a tile (like friction)
@export var air_drag: float = 1.0      # while in the air

## Idle hops: a resting drop jumps now and then. Each hop picks its own random
## height (px) and each wait picks its own random delay (seconds).
## Metres, not pixels: a real units.gd change never has to touch this again.
@export var hop_height_range: Vector2 = Vector2(0.075, 0.225)
@export var hop_delay_range: Vector2 = Vector2(1.0, 4.0)

## Pickup. A drop is collected when it overlaps the player's body. The magnet only
## helps by pulling drops toward you; you can always pick up by touching.
@export var pickup_enabled: bool = true

## The magnet never treats a drop as closer than this many METRES. 1/d^2 grows
## enormously as d approaches 0, and this stops a drop that is right next to
## the player from getting an absurd kick.
@export var min_pull_distance: float = 0.15

# Current speed in pixels/second (x = sideways, y = down is positive).
# Not private: the world sets it when a drop is thrown (see world.spawn_drop).
var velocity: Vector2 = Vector2.ZERO
# Seconds left before this drop can be picked up or pulled by the magnet.
# Set by the world for thrown items so they don't snap straight back to you.
var pickup_delay: float = 0.0
# How much gravel this pebble started with, so a pebble that was only partly
# swallowed by a full hold can be drawn smaller (see _shrink_to_remaining).
var _full_units: float = 0.0
# True while resting on a tile. Decides whether the hop timer counts down.
var _grounded: bool = false
# Seconds left until the next hop.
var _hop_timer: float = 0.0
var _world: Node = null
# The Player node. Left untyped on purpose so we can read the player's own
# variables (magnet_strength, inventory...) without the editor complaining.
var _player = null

# The picture child node; its texture is set in _ready().
@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	_world = get_tree().get_first_node_in_group("world")
	_player = get_tree().get_first_node_in_group("player")
	_sprite.texture = texture
	_sprite.scale = Vector2.ONE * drop_scale
	_full_units = _gravel_units()
	_reset_hop_timer()

func _physics_process(delta: float) -> void:
	if pickup_delay > 0.0:
		pickup_delay -= delta  # count down the grace period
	_apply_magnet(delta)
	_fall(delta)
	_hop_when_due(delta)
	_try_pickup()


# ---------------------------------------------------------------------------
# Magnet
# ---------------------------------------------------------------------------

# Pulls this drop toward the player. The pull strength (an acceleration, in
# pixels/second per second) is:
#
#       pull = magnet_strength * ( 1/d^2  -  1/range^2 )
#
# d = distance to the player. Close up the 1/d^2 term dominates, so the pull is
# strong. As d grows the pull fades, and at d = range the two terms cancel and
# the pull is exactly ZERO (that's what the "- 1/range^2" is for; it makes the
# force fade out smoothly instead of switching off abruptly). Beyond range
# there is no pull at all.
func _apply_magnet(delta: float) -> void:
	if _player == null or not pickup_enabled or pickup_delay > 0.0:
		return
	# The magnet only works while the player is holding it active.
	if not _player.magnet_active:
		return
	# If there is nowhere to put this drop it couldn't be picked up anyway, so
	# don't drag it to the player just to have it sit there.
	if not _has_room_for_me():
		return

	# The formula (and player.magnet_strength / magnet_range) is defined in
	# METRES, so distance is converted before doing any of the maths and the
	# result converted back to px/s^2 only at the very end. That is what makes
	# this immune to any future PIXELS_PER_METER change.
	var to_player: Vector2 = _player.global_position - global_position
	var dist_m: float = Units.px_to_m(to_player.length())
	var magnet_range: float = _player.magnet_range
	if dist_m >= magnet_range:
		return  # out of range: no pull

	# Don't let the distance get so small that 1/d^2 explodes.
	dist_m = maxf(dist_m, min_pull_distance)

	var pull_ms2: float = _player.magnet_strength * (1.0 / (dist_m * dist_m) - 1.0 / (magnet_range * magnet_range))

	# Speed up in the direction of the player. (acceleration * time = change in speed)
	velocity += to_player.normalized() * Units.accel_to_px(pull_ms2) * delta


# ---------------------------------------------------------------------------
# Falling, landing, hopping
# ---------------------------------------------------------------------------

func _fall(delta: float) -> void:
	if _world == null:
		return
	var cell_size: float = _world.cell_size()
	var half: float = cell_size * drop_scale / 2.0  # distance from centre to feet

	# Gravity pulls down; drag slows sideways motion (more drag on the ground).
	velocity.y += fall_gravity * delta
	var drag: float = ground_drag if _grounded else air_drag
	velocity.x *= 1.0 - minf(drag * delta, 1.0)

	var new_pos: Vector2 = global_position + velocity * delta
	var landed := false

	# Walls: if moving sideways would put our leading edge inside a solid tile,
	# cancel the sideways motion and stay put on that axis.
	if velocity.x != 0.0:
		var side_probe := Vector2(new_pos.x + signf(velocity.x) * half, global_position.y)
		if not _world.is_walkable(_world.world_to_grid(side_probe)):
			velocity.x = 0.0
			new_pos.x = global_position.x

	# Ceilings: same idea for the top edge while moving up (hops, throws).
	if velocity.y < 0.0:
		var head_probe := Vector2(new_pos.x, new_pos.y - half)
		if not _world.is_walkable(_world.world_to_grid(head_probe)):
			velocity.y = 0.0
			new_pos.y = global_position.y

	# Only a falling drop can land. Check the tile under its feet.
	if velocity.y > 0.0:
		var feet: Vector2 = new_pos + Vector2(0.0, half)
		var cell: Vector2i = _world.world_to_grid(feet)
		if not _world.is_walkable(cell):
			# Sit on the top edge of that tile and stop falling.
			var cell_top: float = _world.grid_to_world(cell).y - cell_size / 2.0
			new_pos.y = cell_top - half
			velocity.y = 0.0
			landed = true

	_grounded = landed  # if the floor gets mined out, this goes false and it falls
	global_position = new_pos

func _hop_when_due(delta: float) -> void:
	if not _grounded:
		return  # only count down while resting
	_hop_timer -= delta
	if _hop_timer <= 0.0:
		# v = sqrt(2 * g * h): the launch speed that peaks at exactly height h.
		# Worked out in real metres/seconds, then converted once to px/s, so it
		# does not care what PIXELS_PER_METER happens to be.
		var height_m: float = randf_range(hop_height_range.x, hop_height_range.y)
		velocity.y = -Units.m_to_px(sqrt(2.0 * Units.GRAVITY_MS2 * height_m))
		_reset_hop_timer()

func _reset_hop_timer() -> void:
	_hop_timer = randf_range(hop_delay_range.x, hop_delay_range.y)


# ---------------------------------------------------------------------------
# Pickup
# ---------------------------------------------------------------------------

# Collect the drop once it touches the player's body. get_overlapping_bodies()
# lists every physics body currently overlapping this Area2D (the player, and also
# any tiles it is touching); we just check whether the player is among them.
# Checking every tick (instead of using a "body entered" signal) means the
# pickup_delay still works: a thrown item that starts out overlapping you gets
# picked up the moment its delay runs out.
func _try_pickup() -> void:
	if _player == null or not pickup_enabled or pickup_delay > 0.0:
		return
	if not (_player in get_overlapping_bodies()):
		return

	if gravel.is_empty():
		# A whole item: add_item returns false when the hotbar is full, and then
		# the drop stays in the world instead of vanishing.
		if _player.add_item(item_id):
			queue_free()
		return

	# A pebble: the hold takes what it has room for and hands back the rest. A
	# hold with a little space left swallows part of the pebble, so the leftover
	# stays lying there as a smaller piece rather than all or nothing.
	gravel = _player.add_gravel(gravel)
	if gravel.is_empty():
		queue_free()
	else:
		_shrink_to_remaining()


## Units of gravel this drop is carrying (0.0 for a whole item).
func _gravel_units() -> float:
	var sum := 0.0
	for material_id in gravel:
		sum += gravel[material_id]
	return sum


# Is there anywhere for this drop to go? Whole items need a free hotbar slot,
# pebbles need room in the hold.
func _has_room_for_me() -> bool:
	if gravel.is_empty():
		return _player.inventory.has_room()
	return _player.cargo.has_room()


# Redraws a partly-collected pebble smaller. Area (not width) tracks how much
# is left, hence the square root, and it never shrinks away to nothing.
func _shrink_to_remaining() -> void:
	if _full_units <= 0.0:
		return
	var fraction: float = clampf(_gravel_units() / _full_units, 0.0, 1.0)
	_sprite.scale = Vector2.ONE * drop_scale * maxf(sqrt(fraction), 0.4)
