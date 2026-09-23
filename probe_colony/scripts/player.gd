extends CharacterBody2D
## Player: the machine you control.
##   - Move with A/D. Hold W to fire the jetpack -- there is no jump, and if you
##     are carrying too much the jetpack simply won't lift you.
##   - 1-9, 0 select a hotbar slot. Whatever is selected is your "active item".
##   - Hold Space to USE the active item:  drill = mine, magnet = pull drops.
##     Items with no function do nothing yet.
##   - Q throws the selected item out into the world.
##   - Hold G to pour the cargo hold back out onto the ground, which is how you
##     get out from under a load too heavy to lift.
##
## You carry things in TWO separate places, and they never mix:
##   the hotbar (inventory.gd) - 10 slots, one TOOL or item each
##   the hold   (cargo.gd)     - a tank of gravel, measured by weight, that
##                               mined material is poured into
## That split is why a morning's mining can't bury your drill under pebbles.
##
## The heavy lifting lives in other files:
##   miner.gd     - the drill        hotbar.gd     - the on-screen slots
##   inventory.gd - tools you carry  cargo.gd      - material you have dug up
##   cargo_meter.gd - the on-screen tank
##   dropped_item.gd - drops (they read our magnet_*)
##
## KEYS are NAMED ACTIONS from Project Settings > Input Map (use_item, throw_item,
## hotbar_1..hotbar_10, move_*). This file never mentions a specific key, so a
## future keybinding menu only has to reassign those actions.

# --- Mass ---------------------------------------------------------------------
# Everything below is in REAL units: kilograms, newtons, metres, seconds. The
# conversion to pixels happens in units.gd and nowhere else.
#
# Mass is what ties the cargo hold to how the machine handles. The rover's own
# weight is fixed; what you are carrying is not, so a full hold is felt in the
# controls rather than just read off a meter.

## The machine's own weight with nothing in the hold, in kilograms. A 1.4m
## working robot, so about the weight of a small excavator. Parts will
## contribute to this once the chassis/module system exists.
@export var dry_mass: float = 1200.0

# --- Drive ---------------------------------------------------------------------
## What the motors can push with, in newtons. Acceleration is force / mass, so
## this number stays put while a filling hold makes you slower and slower.
@export var motor_force: float = 10000.0

## Top speed on the flat, metres/second. Not mass-dependent: a heavy rover takes
## much longer to GET here, but it gets here eventually.
@export var max_speed: float = 5.0

## Braking, m/s². Deliberately NOT divided by mass: these are real brakes, not
## friction, so a loaded rover feels sluggish to start and never slippery to
## stop. Skidding around under a full load is the failure mode to avoid.
@export var brake_decel: float = 12.0

## How much of the motor you can use in mid-air, 0 to 1.
@export var air_control: float = 0.3

# --- Jetpack -------------------------------------------------------------------
## Thrust in newtons. THIS IS THE INTERESTING NUMBER: if it can't beat your own
## weight (mass × gravity) you simply do not leave the ground. At 13500N a full
## hold of regolith still just barely lifts, while a full hold of hematite --
## three times denser -- pins you down until you dump some of it.
@export var jetpack_thrust: float = 13500.0

## Climb rate cap, metres/second, so an empty rover doesn't rocket off-screen.
@export var jetpack_max_climb: float = 8.0

## Specific impulse, in seconds: how efficiently the thruster turns propellant
## into thrust. 330 is about right for methalox. Burn rate is thrust divided by
## (Isp x standard gravity), so a bigger thruster drinks proportionally more.
@export var jetpack_isp: float = 330.0

## How much propellant the tank holds, in litres. At Tier 0 this is about 30
## seconds of continuous full thrust -- plenty for hops, nowhere near enough to
## treat flying as free travel.
@export var fuel_capacity: float = 150.0

## Propellant on board, in litres. Starts full; there is no way to make more
## yet, so for now this is a one-way resource.
var fuel: float = 0.0

# --- Magnet (pulls nearby drops toward you while it is active) ---------------
# The pull on a drop is:  magnet_strength * (1/d^2 - 1/magnet_range^2)
# where d is its distance from you in METRES. It fades to exactly zero at
# magnet_range. Drops read these numbers from us every tick (see
# dropped_item.gd), so a future magnet/suction upgrade only has to change them.
## Bigger = stronger pull. Units are metres^3 / second^2 (a pull in m/s^2 times
## d^2 in metres). Real units, like everything else here, so a future change to
## PIXELS_PER_METER never requires re-tuning this by hand again.
@export var magnet_strength: float = 12.109375
## Beyond this many metres there is no pull at all.
@export var magnet_range: float = 3.75

# --- Throwing ----------------------------------------------------------------
## How fast a thrown item leaves your hand, metres/second. It arcs under gravity.
@export var throw_speed: float = 7.5
## Spawn the thrown item this far from our centre (metres) so it starts outside
## our body.
@export var throw_start_distance: float = 1.1875
## Seconds before a thrown item can be picked up or magnetised again.
@export var throw_pickup_delay: float = 1.5

# --- Dumping the hold ---------------------------------------------------------
# Hold the dump key to pour gravel back out onto the ground. This is the way out
# of the trap the mass system otherwise sets: loaded past liftoff weight at the
# bottom of a hole, with no way to shed anything. It is also the physical half
# of rover-to-rover transfer later -- one machine pours, another sucks it up.

## Litres per second poured out while the key is held. A full hold empties in
## under four seconds: fast enough to be an escape, slow enough to stop early.
@export var dump_rate: float = 400.0

## Gravel leaves the hold in pebbles of roughly this size.
@export var dump_pebble_liters: float = 45.0

## Seconds before dumped gravel can be sucked back up. Without this, dumping
## with the suction running would just pull it all straight back in.
@export var dump_pickup_delay: float = 2.0

# Litres poured so far that haven't yet added up to a whole pebble.
var _dump_pending: float = 0.0

# --- Cargo hold --------------------------------------------------------------
## Litres the hold takes, counting every material together. One mined tile is
## 125 litres of gravel, so 1500 is a dozen tiles: enough to feel productive,
## small enough that the trip home is a real decision. A bigger cargo module
## raises it -- and makes it much easier to load yourself past liftoff weight.
@export var cargo_capacity: float = 1500.0

# --- State -------------------------------------------------------------------
## The tools we're carrying, one per hotbar slot (data only).
var inventory := Inventory.new()

## The gravel we've dug up, by material (data only). Mined pebbles pour in here;
## nothing mined ever reaches the hotbar.
var cargo := Cargo.new()

## True while the magnet is switched on. Drops check this every tick.
var magnet_active: bool = false

# The child nodes made in player.tscn.
@onready var _hotbar: Hotbar = $Hotbar          # the on-screen slot row
@onready var _cargo_meter: CargoMeter = $CargoMeter  # the on-screen hold
@onready var _miner: Miner = $Miner             # the drill behaviour

var _world: Node = null                  # the World node; found on first use


func _ready() -> void:
	# Lets other scripts (like drops) find the player.
	add_to_group("player")

	# The hold's size is an Inspector setting on us, so hand it over before
	# anything can start filling it.
	cargo.capacity = cargo_capacity
	fuel = fuel_capacity

	# Connect the two on-screen displays and the drill to us.
	_hotbar.setup(inventory)
	_cargo_meter.setup(cargo, self)
	_miner.setup(self)

	# Starting kit: the drill and the magnet take the first two slots.
	inventory.add_item("drill")
	inventory.add_item("magnet")


# Runs every physics tick (60 times a second by default). `delta` is the time
# since the last tick, so `something * delta` means "per second" amounts.
func _physics_process(delta: float) -> void:
	# Worked out once and passed down, because every line below divides by it.
	var mass: float = total_mass()

	_apply_vertical(delta, mass)
	_apply_drive(delta, mass)

	# Applies velocity, sliding along walls/floors and handling collisions.
	move_and_slide()

	_update_active_item(delta)
	_pour_out_cargo(delta)


# ---------------------------------------------------------------------------
# Movement
# ---------------------------------------------------------------------------

# Gravity pulls down, the jetpack pushes up, and whichever wins decides what
# happens. There is no "can I jump?" check anywhere: if the thrust can't beat
# the weight, the sum simply comes out downward and you stay on the floor.
func _apply_vertical(delta: float, mass: float) -> void:
	var thrust_accel := 0.0
	if Input.is_action_pressed("move_up") and fuel > 0.0:
		# force / mass is an acceleration in m/s²; convert once to pixels.
		thrust_accel = Units.accel_to_px(jetpack_thrust / mass)

		# Burn propellant. Note this happens even when you are too heavy to
		# actually leave the ground: the thruster does not know that, and the
		# meter has already warned you. Holding the button in a hole you cannot
		# climb out of really does waste the tank.
		fuel = maxf(fuel - fuel_burn_rate() * delta, 0.0)

	# Positive = still falling on balance, negative = climbing.
	var net: float = Units.GRAVITY_PX - thrust_accel

	if is_on_floor() and net >= 0.0:
		# Planted: too heavy to lift, or not trying to. Keep ONE frame's worth of
		# weight pressing downward rather than zeroing it. A body with exactly
		# zero vertical speed never collides with the ground it is resting on, so
		# is_on_floor() starts flickering and the rover gets air control (and its
		# reduced acceleration) while standing still.
		velocity.y = net * delta
	else:
		velocity.y += net * delta

	# Cap the climb so an empty rover doesn't disappear upward.
	velocity.y = maxf(velocity.y, -Units.m_to_px(jetpack_max_climb))


# Sideways movement is a FORCE, so acceleration is force / mass. This is where a
# full hold is actually felt: the top speed is the same, getting there is not.
func _apply_drive(delta: float, mass: float) -> void:
	# get_axis returns -1 (left), 0 (none) or +1 (right).
	var dir: float = Input.get_axis("move_left", "move_right")
	var brake_step: float = Units.m_to_px(brake_decel) * delta

	if is_zero_approx(dir):
		velocity.x = move_toward(velocity.x, 0.0, brake_step)
		return

	# Turning around brakes first rather than fighting momentum with the motor,
	# so a heavy rover can still change direction promptly.
	if velocity.x * dir < 0.0:
		velocity.x = move_toward(velocity.x, 0.0, brake_step)

	var accel: float = Units.accel_to_px(motor_force / mass)
	if not is_on_floor():
		accel *= air_control

	var limit: float = Units.m_to_px(max_speed)
	velocity.x = clampf(velocity.x + dir * accel * delta, -limit, limit)


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


# Finds the World the first time it's needed and remembers it. Can't be done in
# _ready() (same reason as in miner.gd): the World joins the "world" group in
# ITS _ready(), which runs after ours. Returns false if it isn't there yet.
func _find_world() -> bool:
	if _world == null:
		_world = get_tree().get_first_node_in_group("world")
	return _world != null


# ---------------------------------------------------------------------------
# Throwing
# ---------------------------------------------------------------------------

# Called by Godot for input nothing else has used.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("throw_item"):
		_throw_selected_item()


# Removes the selected item from the inventory and tosses it toward the mouse.
func _throw_selected_item() -> void:
	if not _find_world():
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
	var start: Vector2 = global_position + dir * Units.m_to_px(throw_start_distance)
	if not _world.is_walkable(_world.world_to_grid(start)):
		start = global_position

	_world.spawn_drop(start, item_id, _world.item_icon(item_id),
		dir * Units.m_to_px(throw_speed), throw_pickup_delay)


# ---------------------------------------------------------------------------
# Dumping the hold
# ---------------------------------------------------------------------------

# While the dump key is held, pour gravel out onto the ground a pebble at a
# time. Volume is taken proportionally from every material (see
# cargo.take_mixture), so what lands is a scoop of what you were carrying
# rather than whichever material happened to be listed first.
func _pour_out_cargo(delta: float) -> void:
	if not Input.is_action_pressed("dump_cargo") or cargo.total() <= 0.0:
		_dump_pending = 0.0
		return
	if not _find_world():
		return

	_dump_pending += dump_rate * delta
	while _dump_pending >= dump_pebble_liters and cargo.total() > 0.0:
		_dump_pending -= dump_pebble_liters
		_spill_one_pebble()


# Takes one pebble's worth out of the hold and tosses it clear of our tracks.
func _spill_one_pebble() -> void:
	var mixture: Dictionary = cargo.take_mixture(dump_pebble_liters)
	if mixture.is_empty():
		return

	# The pebble wears the colour of whatever it is mostly made of. Material out
	# of a tank has no tile to borrow a picture from, so one is generated.
	var main_material := ""
	var most := 0.0
	for material_id in mixture:
		if mixture[material_id] > most:
			most = mixture[material_id]
			main_material = material_id

	# Throw it out to one side so a dumped load doesn't pile up underneath us
	# (and immediately get driven over). Sideways if we're moving, else right.
	var side: float = signf(velocity.x) if not is_zero_approx(velocity.x) else 1.0
	var start: Vector2 = global_position + Vector2(side * Units.m_to_px(0.7), Units.m_to_px(0.3))
	var toss := Vector2(side * randf_range(Units.m_to_px(0.5), Units.m_to_px(1.6)),
		-randf_range(0.0, Units.m_to_px(1.0)))

	_world.spawn_drop(start, "", MaterialTable.gravel_texture(main_material),
		toss, dump_pickup_delay, mixture)


# ---------------------------------------------------------------------------
# Mass
# ---------------------------------------------------------------------------

## What this machine weighs right now, in kilograms: itself, its propellant and
## its load. Propellant counts, which is why a full tank is worst at liftoff and
## the machine gets lighter the longer it flies -- exactly like a real rocket,
## and it falls out of the arithmetic rather than being special-cased.
func total_mass() -> float:
	return dry_mass + fuel_mass() + cargo.mass()


## What the propellant aboard weighs, in kilograms.
func fuel_mass() -> float:
	return fuel * MaterialTable.density(MaterialTable.PROPELLANT)


## Propellant used per second at full thrust, in LITRES (the tank's unit).
## Thrust / (Isp x g0) gives kilograms per second; dividing by density gives
## litres. A thirstier or more powerful thruster empties the tank faster.
func fuel_burn_rate() -> float:
	var kg_per_sec: float = jetpack_thrust / (jetpack_isp * Units.STANDARD_GRAVITY)
	return kg_per_sec / MaterialTable.density(MaterialTable.PROPELLANT)


## Seconds of continuous full thrust left in the tank.
func fuel_seconds() -> float:
	return fuel / fuel_burn_rate()


## Can the jetpack beat our own weight at the moment? The movement code doesn't
## consult this -- the physics works it out by itself -- but the cargo meter
## warns the player with it, which beats finding out at the bottom of a pit.
func can_lift() -> bool:
	return jetpack_thrust > total_mass() * Units.GRAVITY_MS2


## The heaviest we could be and still take off, in kilograms.
func lift_limit() -> float:
	return jetpack_thrust / Units.GRAVITY_MS2


## Tries to pick up one whole item into a hotbar slot. Returns true if it fit,
## false if the hotbar is full. Drops call this (see dropped_item.gd).
func add_item(item_id: String) -> bool:
	return inventory.add_item(item_id)


## Pours a pebble's worth of gravel ({ material id : units }) into the hold and
## returns whatever DIDN'T fit, in the same form. Drops call this; an empty
## return means the pebble was swallowed whole.
func add_gravel(mixture: Dictionary) -> Dictionary:
	return cargo.add_mixture(mixture)
