extends XROrigin3D
# Windows OpenXR production adapter. Device poses never edit robot TCP/frame.
var lab: Node3D
var xr: OpenXRInterface
var left: XRController3D
var right: XRController3D
var camera: XRCamera3D
var was_enable := false
var was_select := false
var seated := false
var focused := false

func setup(target: Node3D) -> void:
	lab = target
	lab.controller.SessionAvailability(false,false)
	xr = XRServer.find_interface("OpenXR") as OpenXRInterface
	camera = XRCamera3D.new()
	add_child(camera)
	camera.current = true
	lab.camera = camera
	left = XRController3D.new()
	left.tracker = &"left_hand"
	left.pose = &"grip"
	add_child(left)
	right = XRController3D.new()
	right.tracker = &"right_hand"
	right.pose = &"aim"
	add_child(right)
	recenter(false)
	if xr == null or not xr.is_initialized():
		show_failure("OpenXR no disponible. Se requiere runtime activo y visor conectado. No se habilita movimiento. Cierre y elija explícitamente emulación o escritorio.")
		return
	get_viewport().use_xr = true
	xr.session_focussed.connect(func(): focused = true; lab.controller.SessionAvailability(true,true))
	for signal_name in ["session_visible","session_synchronized","session_stopping","session_loss_pending","instance_exiting"]:
		xr.connect(signal_name,func(): focused = false; lab.surface.pointer.cancel(); lab.controller.SessionAvailability(false,false))
	xr.pose_recentered.connect(func(): lab.surface.pointer.cancel(); lab.controller.CancelInput())
	focused = xr.get_session_state() == OpenXRInterface.SESSION_STATE_FOCUSED
	lab.controller.SessionAvailability(focused,focused)

func show_failure(message: String) -> void:
	print("XR UNAVAILABLE: ",message)
	var layer := CanvasLayer.new()
	add_child(layer)
	var label := Label.new()
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(30,30)
	label.size = Vector2(700,150)
	layer.add_child(label)
	if "--xr-smoke" in OS.get_cmdline_user_args(): get_tree().quit(0 if not lab.controller.InputAvailable() and not lab.controller.Moving() else 1)

func recenter(toggle: bool) -> void:
	if toggle: seated = not seated
	position = Vector3(1.15,0.45 if seated else 0,2.55)
	if xr != null and xr.is_initialized(): XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT,true)

func _process(_delta: float) -> void:
	if xr == null or not xr.is_initialized(): return
	if focused and right.get_has_tracking_data() and right.is_button_pressed(&"stop"):
		lab.surface.pointer.cancel(); lab.controller.StopProgram()
	var head = XRServer.get_tracker(&"head")
	var head_pose = head.get_pose(&"default") if head != null else null
	var head_valid: bool = head_pose != null and head_pose.has_tracking_data
	lab.controller.SessionAvailability(focused and head_valid,focused and head_valid)
	var valid: bool = focused and left.get_has_tracking_data() and right.get_has_tracking_data() and head_valid
	lab.controller.DeviceAvailability(valid,left.get_is_active() and right.get_is_active())
	if not valid:
		lab.surface.pointer.cancel()
		if focused and head_valid and right.get_has_tracking_data():
			lab.surface.pointer.aim(right.global_position,-right.global_basis.z)
			var safety_select := right.is_button_pressed(&"select")
			if safety_select != was_select: lab.surface.pointer.select(safety_select); was_select = safety_select
		return
	lab.surface.pointer.aim(right.global_position,-right.global_basis.z)
	var enabling := left.is_button_pressed(&"enable")
	var selecting := right.is_button_pressed(&"select")
	if not enabling or enabling != was_enable: lab.controller.Enable(enabling); was_enable = enabling
	if selecting != was_select: lab.surface.pointer.select(selecting); was_select = selecting
	if right.is_button_pressed(&"stop"): lab.surface.pointer.cancel(); lab.controller.StopProgram()
	var scroll_value := right.get_vector2(&"scroll")
	if absf(scroll_value.y) > 0.7: lab.surface.pointer.scroll(-1 if scroll_value.y > 0 else 1)
