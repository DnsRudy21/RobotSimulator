extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var probe = load("res://scripts/OpenXrRuntimeProbe.cs").new()
	var configured: bool = probe.IsConfigured()
	probe.free()
	var map = load("res://robot_action_map.tres")
	var ok: bool = map != null and map.get_action_set_count() == 1 and map.get_interaction_profile_count() == 2
	print("XR PREFLIGHT runtime=",configured," map=",ok)
	var lab = load("res://scripts/spatial_lab.gd").new()
	lab.xr_mode = true
	root.add_child(lab)
	await process_frame
	ok = ok and not lab.controller.InputAvailable() and not lab.controller.Moving()
	print("XR unavailable lockout ","PASS" if ok else "FAIL")
	quit(0 if ok else 1)
