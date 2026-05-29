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
@export var track_point_spacing := 3.0
@export var max_track_points := 240

var facing_angle := 0.0
var last_track_position := Vector2.INF
var track_lines: Array[Line2D] = []
var track_root: Node2D

const WHEEL_OFFSETS := [
	Vector2(-8, -7),
	Vector2(8, -7),
	Vector2(-8, 8),
	Vector2(8, 8),
]

@onready var stack: Node2D = $Stack
@onready var camera: Camera2D = $Camera2D


func _ready() -> void:
	camera.make_current()
	_build_pixel_stack()
	_build_snow_tracks()


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed

	if direction != Vector2.ZERO:
		var target_angle := _snap_to_eight_directions(direction.angle() + PI)
		facing_angle = lerp_angle(facing_angle, target_angle, minf(turn_speed * delta, 1.0))
		_set_stack_angle(facing_angle)

	move_and_slide()

	if direction != Vector2.ZERO:
		_update_snow_tracks()


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


func _build_snow_tracks() -> void:
	var tile_layer := get_parent()
	if tile_layer == null:
		return

	var parent_node := tile_layer.get_parent()
	if parent_node == null:
		return

	track_root = parent_node.get_node_or_null("GroundMarks")
	if track_root == null:
		track_root = Node2D.new()
		track_root.name = "GroundMarks"
		track_root.y_sort_enabled = false
		parent_node.add_child(track_root)
		parent_node.move_child(track_root, 0)

	var tracks := track_root.get_node_or_null("OptimusSnowTracks")
	if tracks == null:
		tracks = Node2D.new()
		tracks.name = "OptimusSnowTracks"
		track_root.add_child(tracks)

	track_lines.clear()
	for index in range(WHEEL_OFFSETS.size()):
		var line_name := "WheelTrack%d" % (index + 1)
		var line := tracks.get_node_or_null(line_name) as Line2D
		if line == null:
			line = Line2D.new()
			line.name = line_name
			tracks.add_child(line)

		line.clear_points()
		line.width = 3.0
		line.default_color = Color(0.38, 0.55, 0.61, 0.78)
		line.texture_mode = Line2D.LINE_TEXTURE_NONE
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		track_lines.append(line)


func _update_snow_tracks() -> void:
	if track_lines.is_empty():
		return

	if last_track_position != Vector2.INF and global_position.distance_to(last_track_position) < track_point_spacing:
		return

	last_track_position = global_position
	var local_to_track := track_root.get_global_transform().affine_inverse() * Transform2D(facing_angle, global_position)

	for index in range(track_lines.size()):
		var line := track_lines[index]
		line.add_point(local_to_track * WHEEL_OFFSETS[index])
		if line.get_point_count() > max_track_points:
			line.remove_point(0)
