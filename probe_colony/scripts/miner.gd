class_name Miner
extends Node2D
## Miner: the DRILL's behaviour. A child node of the Player.
##
## Every tick the player tells us (see tick()) whether the drill is the selected
## item and whether the "use" button is held. While the drill is selected we aim
## at the tile the mouse is pointing at and outline it. While the button is also
## held, we build up progress on that tile and break it when the timer runs out.
##
## The settings below are exported, so you can tweak them in the Inspector (click
## the Miner node under Player). A future drill upgrade would change them.

## How far you can reach, in pixels.
@export var mine_reach: float = 480.0
## Seconds of holding the button to break one tile.
@export var mine_time: float = 1.0

var _player: Node2D = null          # who we belong to (set in setup)
var _world: Node = null             # the World node; found on first use
var _target: Vector2i = Vector2i.ZERO   # grid cell currently aimed at
var _has_target: bool = false           # is _target valid this tick?
var _progress: float = 0.0              # seconds spent on the current target


## The player calls this once at startup.
func setup(player: Node2D) -> void:
	_player = player


## Called by the player every physics tick.
##   drill_selected - true if the drill is the selected hotbar item
##   using          - true while the "use item" button is held
func tick(delta: float, drill_selected: bool, using: bool) -> void:
	# Find the World lazily. It can't be done in _ready() because the World joins
	# the "world" group in ITS _ready(), which runs AFTER ours (children finish
	# _ready() before their parent does).
	if _world == null:
		_world = get_tree().get_first_node_in_group("world")
		if _world == null:
			return  # world not there yet; try again next tick

	# Remember last tick's target so we can tell whether the aim changed.
	var had_target := _has_target
	var old_target := _target

	if drill_selected:
		# Shoot a line from the player toward the mouse; the first tile it hits
		# is the target.
		var cell: Vector2i = _world.raycast_tile(_player.global_position, get_global_mouse_position(), mine_reach)
		_has_target = cell != _world.NO_TARGET
		_target = cell if _has_target else Vector2i.ZERO
	else:
		# Drill not selected: no target, no outline.
		_has_target = false
		_target = Vector2i.ZERO

	# Progress is lost if you let go, aim at nothing, or switch to another tile.
	if not using or not _has_target or _target != old_target or not had_target:
		_progress = 0.0

	# Keep mining: add time, and break the tile once we've held long enough.
	# (Unminable tiles, like bedrock, never accumulate progress.)
	if using and _has_target and _world.is_minable(_target):
		_progress += delta
		if _progress >= mine_time:
			_world.mine_tile(_target)
			_progress = 0.0

	# Only redraw the outline when the target actually changed.
	if _has_target != had_target or _target != old_target:
		queue_redraw()


# Draws the outline around the targeted tile. Godot calls this when we request it
# with queue_redraw(). White = minable, red = can't be mined.
func _draw() -> void:
	if not _has_target or _world == null:
		return

	var size: float = _world.cell_size()

	# _draw() works in this node's own coordinates, so convert the tile's world
	# position into those.
	var center: Vector2 = to_local(_world.grid_to_world(_target))
	var color := Color.WHITE if _world.is_minable(_target) else Color.RED

	# Rect2(top-left corner, size). `false` = outline only, 2.0 = line width.
	draw_rect(Rect2(center - Vector2(size, size) / 2.0, Vector2(size, size)), color, false, 2.0)
