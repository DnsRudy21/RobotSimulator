extends Node3D
var controller: Node
var world: Node3D
var surface: Node3D
var pendant: PanelContainer
var adapter: Node3D
var selected_joint := 0
var jog_held := false
var xr_mode := false
var camera: Camera3D
var door: Node3D
var world_bar: VBoxContainer
var world_controls: Array[Node3D] = []

func _ready() -> void:
	if "--spatial-smoke" in OS.get_cmdline_user_args(): ProjectSettings.set_setting("application/config/projects_directory","user://smoke-projects-%d" % Time.get_ticks_usec())
	controller = load("res://scripts/JogBridge.cs").new()
	add_child(controller)
	controller.SelectSource("OpenXR" if xr_mode else "Emulation")
	controller.Enable(false)
	world = load("res://scripts/robot_world.gd").new()
	add_child(world)
	world.setup(controller)
	surface = load("res://scripts/spatial_surface.gd").new()
	surface.position = Vector3(1.15,1.3,1.4)
	add_child(surface)
	surface.setup(self,controller)
	pendant = surface.pendant
	world.readings = pendant.readings
	world.box(self,Vector3(1.3,0.08,0.3),Vector3(1.15,0.72,1.4),Color("45596b"))
	world.box(self,Vector3(0.08,0.72,0.08),Vector3(1.15,0.36,1.4),Color("45596b"))
	build_world_controls()
	adapter = load("res://scripts/openxr_adapter.gd" if xr_mode else "res://scripts/spatial_emulator.gd").new()
	add_child(adapter)
	adapter.setup(self)
	if "--spatial-smoke" in OS.get_cmdline_user_args(): call_deferred("run_smoke")
	if "--probe-spatial" in OS.get_cmdline_user_args(): call_deferred("run_probe")

func build_world_controls() -> void:
	# Production surface owns safety controls; world objects reflect real state and share commands.
	door = world.box(self,Vector3(0.04,1.8,0.6),Vector3(-0.9,0.9,0.1),Color("647d91"))
	for entry in [["Puerta",Vector3(-0.65,1.2,0.7),Color("45596b")],["PARO",Vector3(-0.35,1.2,0.7),Color("d96552")]]:
		var control = load("res://scripts/world_control.gd").new()
		add_child(control)
		control.position = entry[1]
		if entry[0] == "Puerta": control.setup(entry[0],func(): pendant.cancel_input(); controller.Door(not controller.DoorIsClosed()),entry[2])
		else: control.setup(entry[0],func(): pendant.cancel_input(); controller.Emergency(true),entry[2])
		world_controls.append(control)
	surface.pointer.world_controls = world_controls
	world_bar = VBoxContainer.new()
	world_bar.position = Vector2(10,110)
	surface.viewport.get_child(0).add_child(world_bar)
	var row := HBoxContainer.new()
	world_bar.add_child(row)
	pendant.button(row,"Puerta virtual",func(): pendant.cancel_input(); controller.Door(not controller.DoorIsClosed()))
	pendant.button(row,"Paro de celda",func(): pendant.cancel_input(); controller.Emergency(true))
	pendant.button(row,"Docente / escenario",func(): pendant.show_detail("Escenario"))
	row = HBoxContainer.new()
	world_bar.add_child(row)
	pendant.button(row,"Recentrar estación",func(): pendant.cancel_input(); adapter.recenter(false))
	pendant.button(row,"Sentado / de pie",func(): pendant.cancel_input(); adapter.recenter(true))

func _physics_process(_delta: float) -> void:
	if pendant != null: pendant.invalidate_draft()

func _process(_delta: float) -> void:
	if controller != null and door != null:
		door.rotation.y = 0 if controller.DoorIsClosed() else PI/2
		world_bar.visible = not pendant.keyboard.visible
		for popup in pendant.details.values():
			if popup.visible: world_bar.hide()

func _exit_tree() -> void:
	if is_instance_valid(controller): controller.CancelInput(); controller.SessionAvailability(false,false)

func run_smoke() -> void:
	var suite = load("res://tests/spatial_scenario.gd").new()
	add_child(suite)
	await suite.run(self)
	get_tree().quit(0 if suite.failures == 0 else 1)

func run_probe() -> void:
	var probe = load("res://tests/spatial_probe.gd").new()
	add_child(probe)
	await probe.run(self)
