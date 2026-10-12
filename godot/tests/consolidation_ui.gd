extends SceneTree

var failures := 0
func check(value: bool, message: String) -> void:
	if value: print("PASS C4 ",message)
	else: failures += 1; push_error(message)

func press(scene: Node, caption: String) -> void:
	for node in scene.find_children("*","Button",true,false):
		if node.text == caption: node.pressed.emit(); return
	check(false,"missing " + caption)

func settle(bridge: Node) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while bridge.PlanningStatus() == "Verifying" and Time.get_ticks_msec() < deadline:
		await process_frame
		bridge.PollVerification()
	check(bridge.PlanningStatus() == "Ready",bridge.ReadStatus())

func cycle(bridge: Node) -> void:
	await settle(bridge)
	for tick in range(4000):
		if bridge.PlanningStatus() == "Verifying": await settle(bridge)
		bridge._PhysicsProcess(1.0/60)
		if bridge.ReadState() != "Running": break
	check(bridge.ReadState() == "Ready",bridge.ReadStatus())

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var scene = load("res://scenes/Lab.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.set_physics_process(false)
	var bridge = scene.controller
	bridge.set_physics_process(false)
	var ui = scene.pendant
	check(bridge.ProgramText("main").is_empty(),"initial program empty")
	ui.point_name.text = "Inicio propio"
	press(scene,"Enseñar punto")
	var own: Array = JSON.parse_string(bridge.PointsJson())
	var home_id: String = own[0].Id
	bridge.Speed(100)
	bridge.Enable(true)
	for axis in [1,2,4]:
		bridge.Jog(axis,1)
		for tick in range(4 if axis == 4 else 10): bridge._PhysicsProcess(0.1)
		bridge.StopJog()
	ui.point_name.text = "Aproximación propia"
	press(scene,"Enseñar punto")
	own = JSON.parse_string(bridge.PointsJson())
	var approach_id: String = own[-1].Id
	bridge.Enable(true)
	bridge.Jog(0,1)
	bridge._PhysicsProcess(0.1)
	bridge.StopJog()
	ui.point_type.select(1)
	ui.point_name.text = "Línea propia"
	press(scene,"Enseñar punto")
	own = JSON.parse_string(bridge.PointsJson())
	var line_id: String = own[-1].Id
	ui.point_list.select(2)
	ui.select_point(2)
	ui.point_name.text = "Línea renombrada"
	ui.point_edit_name.text = "Línea renombrada"
	press(scene,"Aplicar edición sin mover")
	check(ui.point_list.get_selected_items().size() == 1 and ui.point_name.text == "Línea renombrada","selection preserved on offline edit")
	ui.program_editor.text = "MOVEJ %s 2\nMOVEJ %s 2\nMOVEL %s 2\nWAIT 0.01" % [home_id,approach_id,line_id]
	press(scene,"Verificar")
	await settle(bridge)
	ui.mode_choice.item_selected.emit(1)
	press(scene,"Iniciar")
	await cycle(bridge)
	check(bridge.AlarmText().is_empty(),"own taught program MoveJ/MoveL executes from empty")
	bridge.Mode(false)
	press(scene,"Cargar ejemplo editable")
	ui.program_editor.text += "\nWAIT 0.01"
	press(scene,"Verificar")
	press(scene,"Cancelar")
	check(bridge.PlanningStatus() == "Cancelled" and bridge.ReadState() == "Ready","cancel button prevents pending execution")
	press(scene,"Verificar")
	ui.program_editor.text += "\n# nueva edición"
	ui.invalidate_draft()
	check(bridge.PlanningStatus() == "Cancelled","draft change invalidates worker immediately")
	press(scene,"Verificar")
	scene.lose_focus()
	check(bridge.PlanningStatus() == "Cancelled" and not bridge.Moving(),"synthetic focus cancels planning")
	bridge.Focus(true)
	bridge.Mode(true)
	press(scene,"Iniciar")
	await cycle(bridge)
	check(bridge.Signal("delivered"),"editable example complete")
	bridge.StopProgram()
	bridge.Mode(false)
	press(scene,"Cargar ejemplo editable")
	var delta := 0.15
	for id in ["transfer","place","withdraw"]:
		ui.refresh_points()
		for i in range(ui.points.size()):
			if ui.points[i].Id != id: continue
			ui.point_list.select(i)
			ui.select_point(i)
			if ui.points[i].Kind == "Joint": ui.point_values[0].value += rad_to_deg(delta)
			else:
				var x: float = ui.point_values[0].value
				var y: float = ui.point_values[1].value
				ui.point_values[0].value = cos(delta)*x-sin(delta)*y
				ui.point_values[1].value = sin(delta)*x+cos(delta)*y
				ui.point_values[5].value += rad_to_deg(delta)
			press(scene,"Aplicar edición sin mover")
	var destination: Vector3 = bridge.DestinationPosition()
	ui.destination_values[0].value = (cos(delta)*destination.x+sin(delta)*destination.z)*1000
	ui.destination_values[1].value = (sin(delta)*destination.x-cos(delta)*destination.z)*1000
	ui.destination_values[2].value = destination.y*1000
	press(scene,"Cambiar estación destino")
	bridge.Mode(true)
	press(scene,"Iniciar")
	await cycle(bridge)
	check(bridge.Signal("delivered"),"edited destination and points delivered through pendant")
	for emergency in [false,true]:
		bridge.StopProgram()
		bridge.EditProgram("main","WAIT 2")
		ui.refresh_programs()
		bridge.Run(false)
		await settle(bridge)
		if emergency: bridge.Emergency(true)
		else: bridge.Door(false)
		check(not bridge.ResetAlarm(),"active safety cause blocks reset")
		if emergency: bridge.Emergency(false)
		else: bridge.Door(true)
		check(bridge.ResetAlarm() and not bridge.Moving(),"cause removed/reset no restart")
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1024,600)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for tab in range(2):
			ui.tabs.current_tab = tab
			await process_frame
			await process_frame
			var page: Control = ui.tabs.get_child(tab)
			check(page.get_global_rect().size.y > 80 and ui.get_global_rect().end.x <= dimensions.x and ui.get_global_rect().end.y <= dimensions.y,"layout reachable %s tab%d" % [dimensions,tab])
			check(ui.enable_button.get_global_rect().end.y < dimensions.y and ui.emergency_choice.get_global_rect().end.y < dimensions.y,"critical controls without scroll")
	print("Consolidation UI failures: ",failures)
	quit(0 if failures == 0 else 1)
