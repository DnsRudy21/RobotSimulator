extends Node3D
var command: Callable
var extent := Vector2(0.24,0.16)
var priority := false
func setup(caption: String, action: Callable, color: Color) -> void:
	command = action
	priority = caption == "PARO"
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = extent
	mesh.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = material
	add_child(mesh)
	var label := Label3D.new()
	label.text = caption
	label.font_size = 32
	label.pixel_size = 0.0009
	label.position.z = 0.002
	add_child(label)

func ray_hit(origin: Vector3, direction: Vector3) -> bool:
	var start := to_local(origin)
	var axis := global_basis.inverse()*direction
	if absf(axis.z) < 0.00001: return false
	var t := -start.z/axis.z
	if t < 0 or t > 3: return false
	var p := start+axis*t
	return absf(p.x) <= extent.x/2 and absf(p.y) <= extent.y/2
