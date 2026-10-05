@tool
class_name RobotCowboyModel
extends Node3D
## Low-poly robot cowboy built from primitives. Feet are at y = 0, the hat
## tops out around y = 2.25. Used for the player, the main menu and the
## enemy gunslingers / boss (with different colours).
## Visible in the editor thanks to @tool — tweak the colours in the inspector.

@export var metal_color := Color(0.62, 0.64, 0.68):
	set(v):
		metal_color = v
		_queue_rebuild()
@export var dark_metal_color := Color(0.28, 0.29, 0.32):
	set(v):
		dark_metal_color = v
		_queue_rebuild()
@export var hat_color := Color(0.45, 0.28, 0.14):
	set(v):
		hat_color = v
		_queue_rebuild()
@export var poncho_color := Color(0.7, 0.3, 0.16):
	set(v):
		poncho_color = v
		_queue_rebuild()
@export var bandana_color := Color(0.8, 0.12, 0.1):
	set(v):
		bandana_color = v
		_queue_rebuild()
@export var eye_color := Color(0.3, 0.9, 1.0):
	set(v):
		eye_color = v
		_queue_rebuild()
@export var brass_color := Color(0.85, 0.65, 0.3):
	set(v):
		brass_color = v
		_queue_rebuild()
## Visual layers for every mesh (the player uses layer 2 so its own camera
## doesn't see its body).
@export_flags_3d_render var render_layer: int = 1:
	set(v):
		render_layer = v
		_queue_rebuild()
@export var animate := true

## Horizontal speed, set by whoever owns the model. Drives the walk cycle.
var move_speed := 0.0
## Raise the right arm as if aiming.
var aiming := false

var materials: Array[ShaderMaterial] = []
var eye_material: ShaderMaterial

var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _upper: Node3D
var _t := 0.0
var _rebuild_queued := false


func _ready() -> void:
	_build()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_build.call_deferred()


func _process(delta: float) -> void:
	if not animate or _upper == null:
		return
	var moving := clampf(move_speed / 8.0, 0.0, 1.0)
	_t += delta * (2.0 + move_speed * 0.9)
	var swing := sin(_t) * 0.7 * moving
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation.x = -swing * 0.8
	if aiming:
		_right_arm.rotation.x = lerpf(_right_arm.rotation.x, deg_to_rad(80.0), minf(delta * 12.0, 1.0))
	else:
		_right_arm.rotation.x = swing * 0.8
	_upper.position.y = absf(sin(_t)) * 0.05 * moving + sin(_t * 0.5) * 0.01


func _build() -> void:
	_rebuild_queued = false
	for c in get_children():
		if c.has_meta("_cowboy_part"):
			remove_child(c)
			c.queue_free()
	materials.clear()

	var metal: ShaderMaterial = _mat(metal_color)
	var dark: ShaderMaterial = _mat(dark_metal_color)
	var hat: ShaderMaterial = _mat(hat_color)
	var poncho: ShaderMaterial = _mat(poncho_color)
	var bandana: ShaderMaterial = _mat(bandana_color)
	var brass: ShaderMaterial = _mat(brass_color)
	var leather: ShaderMaterial = _mat(Color(0.3, 0.18, 0.1))
	eye_material = PSX.glow(eye_color)

	var root := Node3D.new()
	root.set_meta("_cowboy_part", true)
	add_child(root)

	# --- Legs (pivot at the hip) ---
	_left_leg = _pivot(root, Vector3(-0.14, 0.95, 0))
	_right_leg = _pivot(root, Vector3(0.14, 0.95, 0))
	for leg in [_left_leg, _right_leg]:
		_part(leg, PSX.box(Vector3(0.17, 0.48, 0.2)), dark, Vector3(0, -0.24, 0))
		_part(leg, PSX.box(Vector3(0.15, 0.38, 0.17)), metal, Vector3(0, -0.65, 0))
		_part(leg, PSX.box(Vector3(0.2, 0.14, 0.32)), leather, Vector3(0, -0.88, -0.05))
		_part(leg, PSX.cyl(0.06, 0.06, 0.02, 6), brass, Vector3(0, -0.86, 0.14), Vector3(0, 0, 90)) # spur

	# --- Upper body (bobs while walking) ---
	_upper = _pivot(root, Vector3.ZERO)
	_part(_upper, PSX.box(Vector3(0.42, 0.18, 0.24)), dark, Vector3(0, 0.98, 0))
	_part(_upper, PSX.box(Vector3(0.46, 0.07, 0.27)), leather, Vector3(0, 1.07, 0))
	_part(_upper, PSX.box(Vector3(0.1, 0.07, 0.02)), brass, Vector3(0, 1.07, -0.14))
	_part(_upper, PSX.box(Vector3(0.08, 0.22, 0.12)), leather, Vector3(0.27, 0.9, 0)) # holster
	_part(_upper, PSX.box(Vector3(0.05, 0.1, 0.05)), dark, Vector3(0.27, 1.04, 0.02)) # gun grip
	_part(_upper, PSX.box(Vector3(0.48, 0.5, 0.28)), metal, Vector3(0, 1.36, 0))
	_part(_upper, PSX.cyl(0.16, 0.46, 0.44, 6), poncho, Vector3(0, 1.42, 0))
	_part(_upper, PSX.prism(Vector3(0.3, 0.18, 0.05)), bandana, Vector3(0, 1.6, -0.18), Vector3(0, 0, 180))
	_part(_upper, PSX.cyl(0.07, 0.07, 0.1, 6), dark, Vector3(0, 1.68, 0))

	# Head
	_part(_upper, PSX.box(Vector3(0.34, 0.3, 0.32)), metal, Vector3(0, 1.84, 0))
	_part(_upper, PSX.box(Vector3(0.28, 0.07, 0.02)), eye_material, Vector3(0, 1.87, -0.165))
	_part(_upper, PSX.box(Vector3(0.2, 0.06, 0.02)), dark, Vector3(0, 1.76, -0.165))
	_part(_upper, PSX.cyl(0.04, 0.04, 0.06, 6), dark, Vector3(-0.19, 1.84, 0), Vector3(0, 0, 90)) # ear bolts
	_part(_upper, PSX.cyl(0.04, 0.04, 0.06, 6), dark, Vector3(0.19, 1.84, 0), Vector3(0, 0, 90))

	# Hat
	var hat_pivot: Node3D = _pivot(_upper, Vector3(0, 2.0, 0))
	hat_pivot.rotation_degrees = Vector3(-6, 0, 3)
	_part(hat_pivot, PSX.cyl(0.42, 0.42, 0.03, 10), hat, Vector3.ZERO)
	_part(hat_pivot, PSX.cyl(0.16, 0.21, 0.24, 8), hat, Vector3(0, 0.13, 0))
	_part(hat_pivot, PSX.cyl(0.215, 0.215, 0.05, 8), leather, Vector3(0, 0.04, 0))

	# --- Arms (pivot at the shoulder) ---
	_left_arm = _pivot(_upper, Vector3(-0.34, 1.55, 0))
	_right_arm = _pivot(_upper, Vector3(0.34, 1.55, 0))
	for arm in [_left_arm, _right_arm]:
		_part(arm, PSX.sphere(0.1, 6), dark, Vector3.ZERO)
		_part(arm, PSX.box(Vector3(0.13, 0.34, 0.14)), metal, Vector3(0, -0.2, 0))
		_part(arm, PSX.box(Vector3(0.12, 0.3, 0.13)), dark, Vector3(0, -0.5, 0))
		_part(arm, PSX.box(Vector3(0.14, 0.12, 0.14)), leather, Vector3(0, -0.71, 0))
	# The right hand holds a little revolver, pointing forward when aiming.
	_part(_right_arm, PSX.box(Vector3(0.05, 0.06, 0.28)), dark, Vector3(0, -0.76, -0.1))

	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).layers = render_layer


func _mat(color: Color) -> ShaderMaterial:
	var m: ShaderMaterial = PSX.material(color, true)
	m.set_shader_parameter("uv_scale", 4.0)
	materials.append(m)
	return m


func _pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return PSX.part(parent, mesh, mat, pos, rot)
