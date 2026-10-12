extends Node3D
# The only spatial component that reads physical desktop input. No robot rules or UI here.
var lab: Node3D
var camera: Camera3D
var held := false
var seated := false
var session_active := true
var tracking := true
var looking := false

func setup(target: Node3D) -> void:
	lab = target
	camera = Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.fov = 65
	lab.camera = camera
	recenter(false)
	lab.controller.SessionAvailability(true,true)
	get_window().focus_exited.connect(func(): held = false; lab.surface.pointer.cancel(); lab.controller.Focus(false))
	get_window().focus_entered.connect(func(): lab.controller.Focus(true))
	var layer := CanvasLayer.new()
	add_child(layer)
	var message := Label.new()
	message.text = "INTERACCIÓN ESPACIAL SIMULADA · VR NO VALIDADA\nMouse: rayo/clic · Espacio: habilitación sostenida · rueda: desplazar\nF8 sesión · F9 seguimiento · F10 cambiar fuente (volver exige soltar/pulsar)"
	message.position = Vector2(10,10)
	layer.add_child(message)

func recenter(toggle: bool) -> void:
	if toggle: seated = not seated
	camera.position = Vector3(1.15,1.3 if seated else 1.6,2.55)
	camera.look_at(Vector3(0.8,1.15,0.9))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if looking:
			camera.rotate_y(-event.relative.x*0.004)
			camera.rotate_object_local(Vector3.RIGHT,-event.relative.y*0.004)
		lab.surface.pointer.aim(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT: looking = event.pressed; lab.surface.pointer.cancel()
		lab.surface.pointer.aim(camera.project_ray_origin(event.position),camera.project_ray_normal(event.position))
		if event.button_index == MOUSE_BUTTON_LEFT: lab.surface.pointer.select(event.pressed)
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: lab.surface.pointer.scroll(-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1)
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_SPACE:
			if event.pressed and lab.pendant.keyboard.visible: return
			held = event.pressed
			lab.controller.Enable(held)
		if event.pressed and event.keycode == KEY_ESCAPE: lab.surface.pointer.cancel(); lab.pendant.cancel_input()
		if event.pressed and event.keycode == KEY_F8:
			session_active = not session_active
			lab.surface.pointer.cancel()
			lab.controller.SessionAvailability(session_active,session_active)
		if event.pressed and event.keycode == KEY_F9:
			tracking = not tracking
			lab.surface.pointer.cancel()
			lab.controller.DeviceAvailability(tracking,tracking)
		if event.pressed and event.keycode == KEY_F10:
			lab.surface.pointer.cancel()
			lab.controller.SelectSource("TestUnavailable" if lab.controller.InputSource() == "Emulation" else "Emulation")
			lab.controller.DeviceAvailability(lab.controller.InputSource() == "Emulation",true)

func _process(_delta: float) -> void:
	# Device-specific observation of a released enabling input; never in common authority.
	if not Input.is_physical_key_pressed(KEY_SPACE): lab.controller.Enable(false)
