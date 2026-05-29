extends CharacterBody2D

const SLICE_PATHS := [
	"res://Texture/Optimus/Optimus1.png",
	"res://Texture/Optimus/Optimus2.png",
	"res://Texture/Optimus/Optimus3.png",
	"res://Texture/Optimus/Optimus4.png",
	"res://Texture/Optimus/Optimus5.png",
	"res://Texture/Optimus/Optimus6.png",
	"res://Texture/Optimus/Optimus7.png",
	"res://Texture/Optimus/Optimus8.png",
	"res://Texture/Optimus/Optimus9.png",
	"res://Texture/Optimus/Optimus10.png",
	"res://Texture/Optimus/Optimus11.png",
	"res://Texture/Optimus/Optimus12.png",
	"res://Texture/Optimus/Optimus13.png",
	"res://Texture/Optimus/Optimus14.png",
	"res://Texture/Optimus/Optimus15.png",
	"res://Texture/Optimus/Optimus16.png",
]

@export var speed := 160.0
@export var slice_height_px := 1
@export var turn_speed := 18.0
@export var snow_trail_lifetime := 1.6
@export var smoke_lifetime := 0.75
@export var side_trail_y_offset := 6.0
@export var smoke_y_offset := -8.0
@export var touch_joystick_radius := 58.0
@export var touch_deadzone := 10.0

var facing_angle := 0.0
var snow_emitters: Array[GPUParticles2D] = []
var smoke_emitters: Array[GPUParticles2D] = []
var last_move_direction := Vector2.ZERO
var touch_index := -1
var touch_start := Vector2.ZERO
var touch_position := Vector2.ZERO
var touch_direction := Vector2.ZERO
var mouse_touch_active := false

const REAR_WHEEL_DISTANCE := 10.0
const REAR_WHEEL_HALF_WIDTH := 8.0
const SMOKE_DISTANCE := 1.0
const SMOKE_HALF_WIDTH := 10.0

@onready var stack: Node2D = $Stack
@onready var camera: Camera2D = $Camera2D
@onready var touch_controls: Node2D = _find_touch_controls()


func _ready() -> void:
	camera.make_current()
	_build_pixel_stack()
	_build_snow_trails()
	_update_touch_controls(false)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index == -1:
			touch_index = event.index
			touch_start = event.position
			touch_position = event.position
			_update_touch_direction()
		elif not event.pressed and event.index == touch_index:
			_clear_touch_direction()
	elif event is InputEventScreenDrag and event.index == touch_index:
		touch_position = event.position
		_update_touch_direction()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_touch_active = true
			touch_start = event.position
			touch_position = event.position
			_update_touch_direction()
		elif mouse_touch_active:
			_clear_touch_direction()
	elif event is InputEventMouseMotion and mouse_touch_active:
		touch_position = event.position
		_update_touch_direction()


func _physics_process(delta: float) -> void:
	var keyboard_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var using_touch := touch_direction != Vector2.ZERO
	var direction := touch_direction if using_touch else keyboard_direction
	velocity = direction * speed

	if direction != Vector2.ZERO:
		last_move_direction = direction
		var target_angle := direction.angle() + PI if using_touch else _snap_to_eight_directions(direction.angle() + PI)
		facing_angle = lerp_angle(facing_angle, target_angle, minf(turn_speed * delta, 1.0))
		_set_stack_angle(facing_angle)

	move_and_slide()

	_update_snow_trails(direction != Vector2.ZERO)


func _build_pixel_stack() -> void:
	for child in stack.get_children():
		child.queue_free()

	for index in range(SLICE_PATHS.size()):
		var sprite := Sprite2D.new()
		sprite.texture = load(SLICE_PATHS[index])
		sprite.centered = true
		sprite.position = Vector2(0, -index * slice_height_px)
		sprite.rotation = facing_angle
		stack.add_child(sprite)


func _snap_to_eight_directions(angle: float) -> float:
	return roundf(angle / (PI / 4.0)) * (PI / 4.0)


func _set_stack_angle(angle: float) -> void:
	for child in stack.get_children():
		if child is Sprite2D:
			child.rotation = angle


func _find_touch_controls() -> Node2D:
	var tile_layer := get_parent()
	if tile_layer == null:
		return null

	var main_node := tile_layer.get_parent()
	if main_node == null:
		return null

	var controls := main_node.get_node_or_null("TouchCanvasLayer/TouchControls") as Node2D
	if controls != null:
		return controls

	return main_node.get_node_or_null("CanvasLayer/TouchControls") as Node2D


func _update_touch_direction() -> void:
	var offset := touch_position - touch_start
	if offset.length() < touch_deadzone:
		touch_direction = Vector2.ZERO
	else:
		touch_direction = offset.limit_length(touch_joystick_radius) / touch_joystick_radius

	_update_touch_controls(true)


func _clear_touch_direction() -> void:
	touch_index = -1
	mouse_touch_active = false
	touch_direction = Vector2.ZERO
	_update_touch_controls(false)


func _update_touch_controls(is_active: bool) -> void:
	if touch_controls == null:
		return

	touch_controls.visible = is_active
	if not is_active:
		return

	var knob := touch_controls.get_node_or_null("Knob") as Node2D
	touch_controls.global_position = touch_start
	if knob != null:
		knob.position = (touch_position - touch_start).limit_length(touch_joystick_radius)


func _build_snow_trails() -> void:
	var tile_layer := get_parent()
	if tile_layer == null:
		return

	var parent_node := tile_layer.get_parent()
	if parent_node == null:
		return

	var track_root := parent_node.get_node_or_null("GroundMarks")
	if track_root == null:
		return

	var tracks := track_root.get_node_or_null("OptimusSnowTracks")
	if tracks == null:
		return

	snow_emitters.clear()
	for child in tracks.get_children():
		if child is GPUParticles2D:
			child.emitting = false
			child.visible = false

	for index in range(2):
		var emitter_name := "WheelTrail%d" % (index + 1)
		var emitter := tracks.get_node_or_null(emitter_name) as GPUParticles2D
		if emitter == null:
			emitter = GPUParticles2D.new()
			emitter.name = emitter_name
			tracks.add_child(emitter)

		_configure_snow_emitter(emitter)
		snow_emitters.append(emitter)

	smoke_emitters.clear()
	for index in range(2):
		var emitter_name := "SideSmoke%d" % (index + 1)
		var emitter := tracks.get_node_or_null(emitter_name) as GPUParticles2D
		if emitter == null:
			emitter = GPUParticles2D.new()
			emitter.name = emitter_name
			tracks.add_child(emitter)

		_configure_smoke_emitter(emitter)
		smoke_emitters.append(emitter)


func _configure_snow_emitter(emitter: GPUParticles2D) -> void:
	emitter.visible = true
	emitter.emitting = false
	emitter.top_level = true
	emitter.amount = 500
	emitter.lifetime = snow_trail_lifetime
	emitter.explosiveness = 0.0
	emitter.randomness = 0.0
	emitter.fixed_fps = 60
	emitter.interpolate = true
	emitter.local_coords = false
	emitter.visibility_rect = Rect2(-1024, -1024, 2048, 2048)
	emitter.texture = load("res://partical_circle.png")
	emitter.process_material = _create_snow_particle_material()


func _configure_smoke_emitter(emitter: GPUParticles2D) -> void:
	emitter.visible = true
	emitter.emitting = false
	emitter.amount = 220
	emitter.lifetime = smoke_lifetime
	emitter.explosiveness = 0.0
	emitter.randomness = 0.35
	emitter.fixed_fps = 60
	emitter.interpolate = true
	emitter.local_coords = false
	emitter.visibility_rect = Rect2(-1024, -1024, 2048, 2048)
	emitter.texture = load("res://smoke.png")
	emitter.process_material = _create_smoke_particle_material()


func _update_snow_trails(is_moving: bool) -> void:
	if snow_emitters.is_empty():
		return

	var move_direction := last_move_direction.normalized()
	if move_direction == Vector2.ZERO:
		move_direction = Vector2.RIGHT

	var rear_center := global_position - move_direction * REAR_WHEEL_DISTANCE
	var axle_direction := Vector2(-move_direction.y, move_direction.x)
	var side_offset := Vector2(0, side_trail_y_offset) if absf(last_move_direction.x) > 0.01 else Vector2.ZERO
	for index in range(snow_emitters.size()):
		var emitter := snow_emitters[index]
		var wheel_side := -1.0 if index == 0 else 1.0
		emitter.global_position = rear_center + axle_direction * REAR_WHEEL_HALF_WIDTH * wheel_side + side_offset
		emitter.emitting = is_moving

	var smoke_center := global_position - move_direction * SMOKE_DISTANCE
	for index in range(smoke_emitters.size()):
		var emitter := smoke_emitters[index]
		var smoke_side := -1.0 if index == 0 else 1.0
		emitter.global_position = smoke_center + axle_direction * SMOKE_HALF_WIDTH * smoke_side + side_offset + Vector2(0, smoke_y_offset)
		emitter.rotation = move_direction.angle() + PI
		emitter.emitting = is_moving


func _create_snow_particle_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0, 1, 0)
	material.spread = 180.0
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 0.0
	material.initial_velocity_max = 0.5
	material.damping_min = 30.0
	material.damping_max = 45.0
	material.scale_min = 0.34
	material.scale_max = 0.62
	material.color = Color(0.48, 0.64, 0.68, 0.3)
	material.color_ramp = _create_snow_trail_gradient_texture()
	return material


func _create_smoke_particle_material() -> ParticleProcessMaterial:
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(-1, 0, 0)
	material.spread = 28.0
	material.gravity = Vector3.ZERO
	material.initial_velocity_min = 18.0
	material.initial_velocity_max = 42.0
	material.damping_min = 18.0
	material.damping_max = 32.0
	material.scale_min = 0.07
	material.scale_max = 0.16
	material.scale_curve = _create_smoke_scale_texture()
	material.color = Color(0.55, 0.66, 0.7, 0.2)
	material.color_ramp = _create_smoke_gradient_texture()
	return material


func _create_smoke_scale_texture() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.18))
	curve.add_point(Vector2(0.35, 0.42))
	curve.add_point(Vector2(1.0, 0.7))
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _create_smoke_gradient_texture() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.7, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.55, 0.66, 0.7, 0.0),
		Color(0.55, 0.66, 0.7, 0.2),
		Color(0.55, 0.66, 0.7, 0.07),
		Color(0.55, 0.66, 0.7, 0.0),
	])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _create_snow_trail_gradient_texture() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.48, 0.64, 0.68, 0.1),
		Color(0.48, 0.64, 0.68, 0.04),
		Color(0.48, 0.64, 0.68, 0.0),
	])
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture
