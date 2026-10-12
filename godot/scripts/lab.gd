extends Node3D

@onready var controller = $Controller
var world: Node3D
var pivots: Array[Node3D] = []
var readings: Array[Label] = []
var camera: Camera3D
var status_label: Label
var enable_button: Button
var jog_held := false
var selected_joint := 0
var yaw := 0.8
var pitch := 0.35
var distance := 2.8
var target := Vector3(0, 0.85, 0)
var pendant: PanelContainer
var part_mesh: MeshInstance3D
var source_station: MeshInstance3D
var destination_station: MeshInstance3D
var obstacle_mesh: MeshInstance3D
var fingers: Array[MeshInstance3D] = []
var belt_marks: Array[MeshInstance3D] = []
var sensor_mesh: MeshInstance3D
var tcp_marker: MeshInstance3D

func _ready() -> void:
	world = load("res://scripts/robot_world.gd").new()
	add_child(world)
	world.setup(controller)
	world.readings = readings
	pivots = world.pivots
	part_mesh = world.part_mesh
	source_station = world.source_station
	destination_station = world.destination_station
	obstacle_mesh = world.obstacle_mesh
	fingers = world.fingers
	belt_marks = world.belt_marks
	sensor_mesh = world.sensor_mesh
	tcp_marker = world.tcp_marker
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 50
	update_camera()
	build_pendant()
	get_window().focus_exited.connect(lose_focus)
	get_window().focus_entered.connect(func(): controller.Focus(true))
	print("Desktop: robot, pendant y celda cargados")
	if "--smoke-demo" in OS.get_cmdline_user_args(): call_deferred("smoke_demo")
	if "--probe-release" in OS.get_cmdline_user_args(): call_deferred("probe_release")

func probe_release() -> void:
	var args := OS.get_cmdline_user_args()
	var size_label := "1080" if "--1080" in args else ("600" if "--600" in args else "720")
	var dimensions := Vector2i(1920,1080) if size_label == "1080" else (Vector2i(1024,600) if size_label == "600" else Vector2i(1280,720))
	get_window().size = dimensions
	get_window().content_scale_size = dimensions
	var output_directory := "user://"
	for arg in args:
		if arg.begins_with("--metrics-dir="): output_directory = arg.trim_prefix("--metrics-dir=")
	await get_tree().create_timer(1).timeout # Render warmup, VSync remains the project default.
	controller.LoadExample()
	pendant.refresh_all()
	controller.Mode(true)
	controller.Speed(100)
	var request_started := Time.get_ticks_usec()
	var accepted: bool = controller.Run(false)
	var request_ms := (Time.get_ticks_usec()-request_started)/1000.0
	var planning_frames: Array[float] = []
	var previous := Time.get_ticks_usec()
	var deadline := previous + 15_000_000
	while controller.PlanningStatus() == "Verifying" and Time.get_ticks_usec() < deadline:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		planning_frames.append((now-previous)/1000.0)
		previous = now
		controller.PollVerification()
	var planning_ms: float = controller.PlanningMilliseconds()
	var samples: Array[float] = []
	var started := Time.get_ticks_usec()
	previous = started
	while Time.get_ticks_usec()-started < 30_000_000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		previous = now
	var elapsed := (Time.get_ticks_usec()-started)/1_000_000.0
	var metrics := {"resolution":str(dimensions),"cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"godot":Engine.get_version_info().string,"renderer":"gl_compatibility","release":not OS.is_debug_build(),"request_main_thread_ms":request_ms,"planning_wall_ms":planning_ms,"planning_frames":frame_statistics(planning_frames),"duration_seconds":elapsed,"mean_fps":samples.size()/elapsed,"frames":frame_statistics(samples),"end_state":controller.ReadState(),"delivered":controller.Signal("delivered"),"alarm":controller.AlarmText(),"conditions":"Standalone release; 1s warmup; default VSync/cap; planning interval separate; 30s cycle+idle. No editor, no XR."}
	var output := FileAccess.open(output_directory.path_join("release-performance-%s.json" % size_label),FileAccess.WRITE)
	if output == null: push_error("Cannot write metrics"); get_tree().quit(1); return
	output.store_string(JSON.stringify(metrics,"  "))
	output.close()
	print("RELEASE PERFORMANCE ",JSON.stringify(metrics))
	for tab in range(2):
		pendant.tabs.current_tab = tab
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var result := get_viewport().get_texture().get_image().save_png(output_directory.path_join("release-%s-%s.png" % [size_label,["move","program"][tab]]))
		if result != OK: push_error("Screenshot error " + str(result))
	get_tree().quit(0 if accepted and controller.ReadState() == "Ready" and controller.Signal("delivered") else 1)

func frame_statistics(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"count":0}
	values.sort()
	return {"count":values.size(),"p50_ms":values[int(values.size()*0.5)],"p95_ms":values[int(values.size()*0.95)],"p99_ms":values[int(values.size()*0.99)],"max_ms":values[-1]}

func smoke_demo() -> void:
	var ok: bool = controller.LoadExample() and controller.Mode(true)
	pendant.refresh_all()
	controller.Speed(100)
	ok = ok and controller.Run(false)
	await await_planning()
	ok = ok and controller.PlanningStatus() == "Ready"
	for tick in range(3000):
		controller._PhysicsProcess(1.0/60.0)
		if controller.ReadState() != "Running": break
	ok = ok and controller.ReadState() == "Ready" and controller.Signal("delivered")
	var temporary := ProjectSettings.globalize_path("user://standalone-smoke-%d.json" % Time.get_ticks_usec())
	ok = ok and controller.SaveProject(temporary) and controller.LoadProject(temporary)
	ok = ok and controller.ReadMode() == "Manual" and not controller.Moving()
	if FileAccess.file_exists(temporary): DirAccess.remove_absolute(temporary)
	controller.EditProgram("main","WAIT_INPUT present 1 0.1")
	pendant.refresh_programs()
	controller.SensorFault(true)
	controller.Mode(true)
	ok = ok and controller.Run(false)
	await await_planning()
	controller._PhysicsProcess(0.1)
	ok = ok and controller.ReadState() == "Faulted" and controller.AlarmText().contains("timeout")
	controller.SensorFault(false)
	ok = ok and controller.ResetAlarm() and not controller.Moving()
	print("STANDALONE SMOKE ","PASS" if ok else "FAIL", " · ciclo, persistencia y recuperación · ",controller.ReadStatus())
	get_tree().quit(0 if ok else 1)

func await_planning() -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while controller.PlanningStatus() == "Verifying" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		controller.PollVerification()

func label(text_value: String, size := 16) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size",size)
	return result

func build_pendant() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	pendant = load("res://scripts/pendant_v2.gd").new()
	canvas.add_child(pendant)
	pendant.setup(self,controller)
	enable_button = pendant.enable_button
	readings = pendant.readings
	world.readings = readings
	status_label = pendant.status_label

func lose_focus() -> void:
	pendant.cancel_input()
	jog_held = false
	controller.Focus(false)
	enable_button.set_pressed_no_signal(false)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_ESCAPE and event.pressed:
			pendant.cancel_input()
			for detail in pendant.details.values(): detail.hide()
			return
		var focus = get_viewport().gui_get_focus_owner()
		if event.pressed and (focus is LineEdit or focus is TextEdit): return
		if event.keycode == KEY_SPACE:
			pendant.keyboard_armed = event.pressed and pendant.can_keyboard_jog()
			controller.Enable(pendant.keyboard_armed)
			if not event.pressed: jog_held = false
		if event.keycode in [KEY_LEFT,KEY_RIGHT]:
			if event.pressed:
				if pendant.keyboard_armed and pendant.can_keyboard_jog(): pendant.start_jog(-1 if event.keycode == KEY_LEFT else 1)
			else:
				jog_held = false
				controller.StopJog()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		jog_held = false
		controller.StopJog()
		if not Input.is_physical_key_pressed(KEY_SPACE): controller.Enable(false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pendant.cancel_input()
		get_viewport().gui_release_focus() # Click on the scene returns keyboard control deliberately.
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.006, -0.2, 1.2)
		update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(2.0,distance-0.2)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(7.0,distance+0.2)
		update_camera()

func update_camera() -> void:
	camera.position = target + Vector3(cos(yaw)*cos(pitch),sin(pitch),sin(yaw)*cos(pitch))*distance
	camera.look_at(target)
	camera.h_offset = 0.8

func _physics_process(_delta: float) -> void:
	pendant.invalidate_draft()
func _process(_delta: float) -> void:
	for i in range(6):
		readings[i].text = "J%d %.2f ?" % [i+1,rad_to_deg(controller.Angle(i))]
