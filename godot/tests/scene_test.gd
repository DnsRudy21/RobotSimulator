extends SceneTree

var failures := 0
func check(condition: bool, message: String) -> void:
	if condition: print("PASS ",message)
	else:
		failures += 1
		push_error(message)


func settle(bridge: Node) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while bridge.PlanningStatus() == "Verifying" and Time.get_ticks_msec() < deadline:
		await process_frame
		bridge.PollVerification()
	check(bridge.PlanningStatus() == "Ready","asynchronous planning completed: " + bridge.ReadStatus())

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/Lab.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var bridge = scene.get_node("Controller")
	# Disable adapter polling only for direct bridge tests.
	scene.set_process(false)
	scene.set_physics_process(false)
	bridge.set_physics_process(false)
	check(scene.pivots.size() == 6 and scene.readings.size() == 6,"six joints and six pendant readings")
	check(not bridge.Jog(0,1),"bridge rejects unenabled jog")
	bridge.Focus(true)
	bridge.Enable(true)
	bridge.Speed(100)
	check(bridge.Jog(1,1),"bridge accepts manual jog")
	bridge._PhysicsProcess(0.1)
	check(abs(bridge.Angle(1)-deg_to_rad(3)) < 1e-10,"C# bridge advances 3 degrees")
	scene.world._process(0.0) # Shared world applies current Core pose.
	check(scene.pivots[0].basis.is_equal_approx(Basis.IDENTITY),"ancestor J1 unchanged")
	check(not scene.pivots[1].basis.is_equal_approx(Basis.IDENTITY),"J2 reads core angle")
	check(scene.pivots[2].basis.is_equal_approx(Basis.IDENTITY),"J3 local angle unchanged")
	check(scene.pivots[2].global_position.distance_to(Vector3(0,1.13,0)) > 0.01,"J2 transforms its descendant")
	check(scene.pivots[2].global_position.distance_to(Vector3(0.028784776,1.129246244,0)) < 0.000001,"descendant agrees with independent sin/cos reference")
	check(scene.pivots[5].global_position.distance_to(bridge.FlangePosition()) < 0.0001,"Core and scene flange position agree")
	check(scene.pivots[5].global_basis.is_equal_approx(bridge.FlangeBasis()),"Core and scene flange orientation agree")
	bridge.Enable(true)
	bridge.Jog(2,1)
	scene.lose_focus()
	var before: float = bridge.Angle(2)
	bridge._PhysicsProcess(0.1)
	check(bridge.Angle(2) == before and not bridge.Moving(),"scene focus handler stops core")
	bridge.Focus(true)
	check(not bridge.Jog(2,1),"focus restoration requires enabling again")
	bridge.Enable(true)
	bridge.Jog(2,1)
	var release := InputEventKey.new()
	release.keycode = KEY_RIGHT
	release.pressed = false
	scene._input(release)
	check(not bridge.Moving(),"key release routed to core")
	bridge.Jog(2,1)
	var mouse_release := InputEventMouseButton.new()
	mouse_release.button_index = MOUSE_BUTTON_LEFT
	mouse_release.pressed = false
	scene._input(mouse_release)
	check(not bridge.Moving(),"mouse release routed to core")
	var buttons: Array[Node] = scene.find_children("*", "Button", true, false)
	var positive_button: Button
	for button in buttons:
		if button.text == "+ / →": positive_button = button
	check(positive_button != null,"positive jog button exists")
	bridge.Enable(true)
	positive_button.button_down.emit()
	check(bridge.Moving(),"pendant button signal starts jog")
	positive_button.button_up.emit()
	check(not bridge.Moving(),"pendant button signal releases jog")
	scene.enable_button.button_down.emit()
	bridge.Jog(0,1)
	scene.enable_button.button_up.emit()
	check(not bridge.Moving(),"pendant enabling button release stops jog")
	bridge.Focus(true)
	bridge.Enable(true)
	for axis in [0,2,3,4,5]:
		bridge.Jog(axis,1)
		bridge._PhysicsProcess(0.1)
		bridge.StopJog()
	scene.world._process(0.0)
	check(scene.pivots[5].global_position.distance_to(bridge.FlangePosition()) < 0.0001,"combined axes scene/Core position")
	check(scene.pivots[5].global_basis.is_equal_approx(bridge.FlangeBasis()),"combined axes scene/Core orientation")
	check(bridge.TeachPoint("Punto de prueba",false),"teach from bridge")
	var points: Array = JSON.parse_string(bridge.PointsJson())
	check(points.size() == 1 and points[0].Name == "Punto de prueba","taught point visible to pendant")
	check(not bridge.EditReference(true,"tool",PackedFloat64Array([120,0,0,0,0,0])),"reference used by point cannot mutate")
	check(bridge.LoadExample(),"editable demo loaded via adapter")
	scene.pendant.refresh_all()
	check(scene.pendant.point_list.item_count == 7,"demo point list refreshed")
	check(bridge.Mode(true) and bridge.Verify(),"automatic demo verification")
	await settle(bridge)
	check(bridge.Run(false),"demo starts through adapter")
	await settle(bridge)
	bridge.Speed(100)
	for tick in range(3000):
		bridge._PhysicsProcess(1.0/60.0)
		if bridge.ReadState() != "Running": break
	check(bridge.ReadState() == "Ready" and bridge.Signal("delivered"),"full demo executes via Godot C# Core")
	check(not bridge.Signal("holding"),"part released rather than attached permanently")
	scene.pendant.tabs.current_tab = 1
	scene.pendant._process(0)
	scene._process(0.0)
	# Optional actual rendered artifact; never claim visual review from headless output.
	if "--capture" in OS.get_cmdline_user_args():
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var path := ProjectSettings.globalize_path("res://../docs/demo-program-720.png")
		check(root.get_texture().get_image().save_png(path) == OK,"rendered preview saved")
	print("Scene failures: ",failures)
	quit(0 if failures == 0 else 1)
