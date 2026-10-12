extends Control
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--desktop" in args or "--smoke-demo" in args or "--probe-release" in args: get_tree().change_scene_to_file.call_deferred("res://scenes/Lab.tscn"); return
	if "--emulate" in args or "--spatial-smoke" in args or "--probe-spatial" in args: start_spatial(false); return
	if "--xr" in args: start_spatial(true); return
	var panel := VBoxContainer.new()
	panel.position = Vector2(60,80)
	add_child(panel)
	var title := Label.new()
	title.text = "RobotSimulator · experiencia de capacitación\nElija modo de entrada. VR requiere runtime y visor."
	panel.add_child(title)
	for pair in [["Interacción espacial simulada · VR no validada",0],["Escritorio",1],["OpenXR · visor conectado a PC",2]]:
		var button := Button.new()
		button.text = pair[0]
		button.custom_minimum_size = Vector2(600,65)
		button.pressed.connect(func():
			if pair[1] == 0: start_spatial(false)
			elif pair[1] == 1: get_tree().change_scene_to_file("res://scenes/Lab.tscn")
			else:
				var probe = load("res://scripts/OpenXrRuntimeProbe.cs").new()
				var configured: bool = probe.IsConfigured()
				probe.free()
				if not configured:
					title.text = "OpenXR no disponible: no hay runtime activo registrado en Windows.\nMovimiento deshabilitado. Elija emulación o escritorio explícitamente."
					return
				var arguments := PackedStringArray(["--xr-mode","on"])
				if not OS.has_feature("standalone"): arguments.append_array(["--path",ProjectSettings.globalize_path("res://")])
				arguments.append_array(["--","--xr"])
				if OS.create_process(OS.get_executable_path(),arguments) > 0: get_tree().quit())
		panel.add_child(button)

func start_spatial(xr: bool) -> void:
	var lab = load("res://scripts/spatial_lab.gd").new()
	lab.xr_mode = xr
	get_tree().root.add_child.call_deferred(lab)
	queue_free()
