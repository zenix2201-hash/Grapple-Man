@tool
class_name PSX
extends RefCounted
## Helpers for the PS1 look: vertex-snapping materials, low-poly primitive
## meshes, and converting existing level materials to the PSX shader.

const WORLD_SHADER: Shader = preload("res://shaders/psx_world.gdshader")

static var _grime: ImageTexture
static var _converted: Dictionary = {}
static var _default_mat: ShaderMaterial


## Small procedural "dirty metal panel" texture shared by all textured materials.
static func grime_texture() -> Texture2D:
	if _grime == null:
		var img := Image.create_empty(32, 32, false, Image.FORMAT_RGB8)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1337
		for y in 32:
			for x in 32:
				var v := 0.55 + rng.randf() * 0.3
				if x % 16 == 0 or y % 16 == 0:
					v *= 0.55 # panel seams
				elif x % 16 == 2 and y % 16 == 2:
					v *= 0.4 # rivets
				img.set_pixel(x, y, Color(v, v * 0.97, v * 0.92))
		_grime = ImageTexture.create_from_image(img)
	return _grime


static func material(color: Color, textured: bool = false, emission: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter("albedo", color)
	if textured:
		m.set_shader_parameter("use_texture", true)
		m.set_shader_parameter("albedo_texture", grime_texture())
	if emission > 0.0:
		m.set_shader_parameter("emission_color", color)
		m.set_shader_parameter("emission_energy", emission)
	return m


## Fullbright material for eyes, lamps, projectiles.
static func glow(color: Color) -> ShaderMaterial:
	var m := material(color)
	m.set_shader_parameter("unshaded", true)
	return m


## Adds a mesh to `parent`. `look` is a Material or a Color.
static func part(parent: Node, mesh: Mesh, look: Variant, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if look is Material:
		mi.material_override = look
	else:
		mi.material_override = material(look)
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cyl(top: float, bottom: float, height: float, sides: int = 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	return m


static func sphere(radius: float, segments: int = 8) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 2)
	return m


static func prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m


static func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 12
	m.ring_segments = 6
	return m


## Swaps StandardMaterial3D on every mesh/CSG node under `root` for a PSX
## version of the same colour, so hand-built levels get the PS1 look for free.
## Add a node to the "no_psx" group to skip it.
static func convert_tree(root: Node) -> void:
	if root == null:
		return
	for node in root.find_children("*", "GeometryInstance3D", true, false):
		if node.is_in_group("no_psx"):
			continue
		if node is CSGShape3D:
			if not ("material" in node):
				continue
			var mat: Material = node.get("material")
			if mat == null:
				node.set("material", _default_material())
			else:
				node.set("material", _convert(mat))
		elif node is MeshInstance3D:
			var mi: MeshInstance3D = node
			if mi.material_override != null:
				mi.material_override = _convert(mi.material_override)
			elif mi.mesh != null:
				for i in mi.mesh.get_surface_count():
					if mi.get_surface_override_material(i) != null:
						mi.set_surface_override_material(i, _convert(mi.get_surface_override_material(i)))
					else:
						var surf := mi.mesh.surface_get_material(i)
						mi.set_surface_override_material(i, _default_material() if surf == null else _convert(surf))


static func _default_material() -> ShaderMaterial:
	if _default_mat == null:
		_default_mat = material(Color(0.6, 0.58, 0.55), true)
	return _default_mat


static func _convert(mat: Material) -> Material:
	if not (mat is StandardMaterial3D):
		return mat
	if _converted.has(mat):
		return _converted[mat]
	var sm: StandardMaterial3D = mat
	if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		return mat
	var m := material(sm.albedo_color, true)
	if sm.albedo_texture != null:
		m.set_shader_parameter("albedo_texture", sm.albedo_texture)
		m.set_shader_parameter("world_uv", false)
		m.set_shader_parameter("uv_scale", 1.0)
		m.set_shader_parameter("texture_strength", 1.0)
	if sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
		m.set_shader_parameter("unshaded", true)
	if sm.emission_enabled:
		m.set_shader_parameter("emission_color", sm.emission)
		m.set_shader_parameter("emission_energy", sm.emission_energy_multiplier)
	_converted[mat] = m
	return m
