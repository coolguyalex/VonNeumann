class_name MiningParticles
extends RefCounted
## MiningParticles: the chips and grit that fly off a tile while you drill it.
##
## Purely decorative. These are NOT drops -- you cannot pick them up and they
## carry no material. The real gravel still comes out of world.mine_tile() as
## dropped_item scenes; this just makes the drilling feel like it is doing
## something to the rock.
##
## Colours are sampled from the tile itself (see world.tile_color), so a new ore
## gets particles that match its art without anyone drawing anything.
##
## Two effects:
##   trickle - a steady spray of grit at the drill's target while you hold it
##   burst   - a one-shot pop of chips when the tile finally breaks

## Chips fall under the world's gravity like everything else.
const GRAVITY := Vector2(0.0, Units.GRAVITY_PX)

# A tiny white square, tinted per-emitter. Built once and shared: without a
# texture CPUParticles2D has nothing to draw.
static var _chip_texture: Texture2D = null


static func chip_texture() -> Texture2D:
	if _chip_texture == null:
		var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color.WHITE)
		_chip_texture = ImageTexture.create_from_image(image)
	return _chip_texture


## The steady grit thrown off while the drill is biting. Returns an emitter you
## keep and switch on and off; the miner owns one of these for its whole life
## rather than making a new one every frame.
static func make_trickle() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.texture = chip_texture()
	p.emitting = false
	p.amount = 34
	p.lifetime = 0.5
	p.local_coords = false  # chips stay where they were thrown, not glued to us

	# Thrown from across the face of the tile, not from a single point.
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 10.0

	# Spray upward and outward from the bite, then fall back down.
	p.direction = Vector2(0.0, -1.0)
	p.spread = 75.0
	p.initial_velocity_min = Units.m_to_px(0.8)
	p.initial_velocity_max = Units.m_to_px(2.6)
	p.gravity = GRAVITY

	p.scale_amount_min = 1.4
	p.scale_amount_max = 3.0
	p.damping_min = 20.0
	p.damping_max = 60.0
	return p


## The pop of chips when a tile breaks. Makes its own emitter, fires once, and
## cleans itself up, so callers can fire and forget.
static func burst(parent: Node, world_pos: Vector2, color: Color, amount: int = 30) -> void:
	var p := CPUParticles2D.new()
	p.texture = chip_texture()
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0  # all at once, not spread over the lifetime
	p.amount = amount
	p.lifetime = 0.7
	p.local_coords = false

	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 14.0  # roughly the tile that just vanished

	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0  # a full fan: the rock goes everywhere
	p.initial_velocity_min = Units.m_to_px(1.2)
	p.initial_velocity_max = Units.m_to_px(4.5)
	p.gravity = GRAVITY

	p.scale_amount_min = 1.6
	p.scale_amount_max = 3.4
	p.damping_min = 10.0
	p.damping_max = 40.0
	tint(p, color)

	parent.add_child(p)
	p.global_position = world_pos

	# Free it once the last chip has faded. A one-shot emitter left in the tree
	# is a small leak that would add up over a long dig.
	parent.get_tree().create_timer(p.lifetime + 0.2).timeout.connect(p.queue_free)


## Colours an emitter from the tile it came out of, then fades it out.
##
## The chips are deliberately drawn much LIGHTER than the rock. Tinting them the
## sampled colour exactly is the obvious thing to do and it makes them invisible:
## dark brown grit against dark brown stone reads as nothing at all. Freshly
## broken rock catching the light is both truer and legible. The hue still comes
## from the tile, so ore types stay distinguishable.
static func tint(p: CPUParticles2D, color: Color) -> void:
	var bright: Color = color.lightened(0.6)
	var settled: Color = color.lightened(0.2)
	var gone := Color(settled.r, settled.g, settled.b, 0.0)

	# White here, because color_ramp is MULTIPLIED by color: leaving the tile's
	# colour in both would darken everything back down again.
	p.color = Color.WHITE

	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	ramp.colors = PackedColorArray([bright, settled, gone])
	p.color_ramp = ramp
