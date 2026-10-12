extends Node3D
# Production metric UI surface, reused by emulation and OpenXR.
@export var physical_size := Vector2(1.28,1.0)
var viewport: SubViewport
var pendant: PanelContainer
var pointer: Node
var mesh: MeshInstance3D

func setup(lab: Node3D, bridge: Node) -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280,1000)
	viewport.transparent_bg = true
	viewport.gui_disable_input = false
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	add_child(viewport)
	var canvas := CanvasLayer.new()
	viewport.add_child(canvas)
	pendant = load("res://scripts/spatial_pendant.gd").new()
	canvas.add_child(pendant)
	pointer = load("res://scripts/spatial_pointer.gd").new()
	add_child(pointer)
	pointer.setup(self,bridge)
	pendant.setup(lab,bridge)
	mesh = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = physical_size
	mesh.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport.get_texture()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material_override = material
	add_child(mesh)

func ray_uv(origin: Vector3, direction: Vector3) -> Vector2:
	var local_origin := to_local(origin)
	var local_direction := global_basis.inverse()*direction
	if absf(local_direction.z) < 0.00001: return Vector2(-1,-1)
	var t := -local_origin.z/local_direction.z
	if t < 0 or t > 3.0: return Vector2(-1,-1)
	var hit := local_origin+local_direction*t
	var uv := Vector2(hit.x/physical_size.x+0.5,0.5-hit.y/physical_size.y)
	if uv.x < 0 or uv.y < 0 or uv.x > 1 or uv.y > 1: return Vector2(-1,-1)
	return uv*Vector2(viewport.size)

func pixel_world(pixel: Vector2) -> Vector3:
	return to_global(Vector3((pixel.x/viewport.size.x-0.5)*physical_size.x,(0.5-pixel.y/viewport.size.y)*physical_size.y,0))
