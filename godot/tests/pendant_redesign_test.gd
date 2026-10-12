extends SceneTree
var failures := 0
var checks := 0
var ui
var bridge
var scene

func check(value: bool, message: String) -> void:
	checks += 1
	if value: print("PASS U6 ",message)
	else: failures += 1; push_error(message)

func press(caption: String) -> void:
	for n in scene.find_children("*","Button",true,false):
		if n.text == caption: n.pressed.emit(); return
	check(false,"missing button "+caption)

func settle() -> void:
	var deadline := Time.get_ticks_msec()+15000
	while bridge.PlanningStatus() == "Verifying" and Time.get_ticks_msec() < deadline:
		await process_frame
		bridge.PollVerification()
	check(bridge.PlanningStatus() == "Ready",bridge.ReadStatus())

func key(code: int, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = down
	scene._input(event)

func capture(label: String) -> void:
	if not "--capture-pendant" in OS.get_cmdline_user_args(): return
	await process_frame
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../docs/pendant-%s.png" % label)
	check(root.get_texture().get_image().save_png(path) == OK,"capture "+label)

func _initialize() -> void: call_deferred("run")

func run() -> void:
	scene = load("res://scenes/Lab.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	bridge = scene.controller
	bridge.set_physics_process(false)
	ui = scene.pendant
	check(ui.tabs.get_tab_count() == 2,"two spaces default")
	ui.point_name.text = "Inicio propio"
	press("Enseñar punto")
	var id: String = ui.points[0].Id
	get_root().gui_release_focus()
	key(KEY_SPACE,true)
	key(KEY_RIGHT,true)
	bridge._PhysicsProcess(0.1)
	check(bridge.Moving(),"keyboard jog starts only after fresh enable")
	ui.axis_choice.select(1)
	ui.axis_choice.item_selected.emit(1)
	var before: float = bridge.Angle(1)
	key(KEY_RIGHT,true)
	bridge._PhysicsProcess(0.1)
	check(not bridge.Moving() and bridge.Angle(1) == before,"axis change cancels, held enable does not rearm")
	key(KEY_SPACE,false)
	key(KEY_SPACE,true)
	key(KEY_RIGHT,true)
	bridge._PhysicsProcess(0.1)
	ui.tabs.current_tab = 1
	check(not bridge.Moving() and not ui.keyboard_armed and bridge.ReadMode() == "Manual","navigation cancels without changing mode")
	ui.tabs.current_tab = 0
	key(KEY_RIGHT,true)
	check(not bridge.Moving(),"return does not rearm")
	ui.point_name.text = "Segundo propio"
	press("Enseñar punto")
	check(ui.points.size() == 2 and ui.point_list.get_selected_items()[0] == 1,"capture selects second own point")
	ui.show_detail("Punto seleccionado")
	ui.point_edit_name.text = "Segundo editado"
	ui.point_values[0].value += 1
	before = bridge.Angle(0)
	press("Aplicar edición sin mover")
	check(ui.points[1].Name == "Segundo editado" and bridge.Angle(0) == before,"detail rename/offline edit does not move")
	key(KEY_ESCAPE,true)
	check(not ui.details["Punto seleccionado"].visible and not ui.keyboard_armed,"Escape closes detail and cancels")
	ui.point_name.grab_focus()
	key(KEY_SPACE,true)
	key(KEY_RIGHT,true)
	check(not bridge.Moving(),"typing focus rejects movement keys")
	ui.point_list.grab_focus()
	key(KEY_SPACE,true)
	key(KEY_RIGHT,true)
	check(not bridge.Moving() and not ui.keyboard_armed,"list navigation cannot jog")
	ui.axis_choice.grab_focus()
	key(KEY_SPACE,true)
	key(KEY_RIGHT,true)
	check(not bridge.Moving() and not ui.keyboard_armed,"selector focus cannot jog")
	root.gui_release_focus()
	key(KEY_SPACE,true)
	key(KEY_RIGHT,true)
	ui.show_detail("Referencias")
	check(not bridge.Moving() and not ui.can_keyboard_jog(),"reference detail cancels input")
	ui.reference_type.select(0)
	ui.reference_id.text = "newtool"
	ui.fill(ui.reference_values,[125,0,0,0,0,0])
	press("Aplicar referencia (no mueve robot)")
	ui.reference_type.select(1)
	ui.reference_id.text = "piece"
	ui.fill(ui.reference_values,[10,20,0,0,0,10])
	press("Aplicar referencia (no mueve robot)")
	ui.refresh_references()
	for i in range(ui.tool_choice.item_count):
		if ui.tool_choice.get_item_text(i) == "newtool": ui.tool_choice.select(i)
	ui.frame_choice.select(1)
	press("Seleccionar TCP y frame")
	check(bridge.ActiveTool() == "newtool" and bridge.ActiveFrame() == "piece" and bridge.Angle(0) == before,"explicit tool/frame selection without motion")
	ui.reference_type.select(0)
	ui.reference_id.text = "tool"
	press("Aplicar referencia (no mueve robot)")
	check(bridge.ReadStatus().contains("usad"),"used reference rejection actionable")
	key(KEY_ESCAPE,true)
	ui.tabs.current_tab = 1
	ui.program_name.text = "sub"
	ui.program_editor.text = "WAIT 0.01"
	press("Aplicar ID")
	ui.refresh_programs("main")
	ui.program_editor.text = "MOVEJ %s 1\nWAIT 0.01\nCALL sub" % id
	press("Verificar")
	ui.tabs.current_tab = 0
	check(bridge.PlanningStatus() == "Verifying","navigation preserves worker")
	press("Cancelar")
	check(bridge.PlanningStatus() == "Cancelled" and not bridge.Moving(),"persistent cancel works from movement space")
	press("Verificar")
	await settle()
	ui.mode_choice.item_selected.emit(1)
	press("Paso")
	await settle()
	for tick in range(500):
		bridge._PhysicsProcess(0.05)
		if bridge.ReadState() != "Running": break
	check(bridge.ReadState() == "Paused","own MOVEJ step pauses")
	ui._process(0)
	press("Reanudar")
	for tick in range(500):
		bridge._PhysicsProcess(0.05)
		if bridge.ReadState() != "Running": break
	check(bridge.ReadState() == "Ready","own WAIT/CALL completes after explicit resume")
	bridge.Mode(false)
	# Generate every instruction through contextual controls, then compile a nested program.
	ui.program_editor.text = ""
	var catalog := {"SET_OUTPUT":"belt 0","WAIT_INPUT":"present 1 0.1","IF/ELSE":"present 1","REPEAT":"2","CALL":"sub"}
	for op in catalog:
		for i in range(ui.instruction_choice.item_count):
			if ui.instruction_choice.get_item_text(i) == op: ui.instruction_choice.select(i)
		ui.instruction_context()
		ui.instruction_arguments.text = catalog[op]
		ui.program_editor.set_caret_line(ui.program_editor.get_line_count()-1)
		ui.insert_instruction()
	check(ui.program_editor.text.contains("ENDIF") and ui.program_editor.text.contains("ENDREPEAT") and ui.program_editor.text.contains("CALL sub"),"signals/logic/catalog operable")
	ui.program_editor.text = "REPEAT 2\nIF present 1\nSET_OUTPUT belt 0\nWAIT_INPUT present 1 0.1\nCALL sub\nELSE\nWAIT 0.01\nENDIF\nENDREPEAT"
	press("Verificar")
	await settle()
	ui._process(0)
	check(ui.sequence.get_item_text(2).contains("    SET_OUTPUT"),"nested scope visible in sequence")
	ui.selected_line = 0
	ui.load_instruction(0)
	ui.instruction_arguments.text = "3"
	ui.replace_instruction()
	check(ui.program_editor.text.begins_with("REPEAT 3\nIF") and ui.program_editor.text.count("ENDREPEAT") == 1,"editing block header preserves nested scope")
	bridge.Mode(true)
	press("Iniciar")
	await settle()
	for tick in range(100): bridge._PhysicsProcess(0.05)
	check(bridge.ReadState() == "Ready","nested signals/IF/REPEAT/CALL executes")
	bridge.Mode(false)
	ui.program_editor.text = "WAIT -1"
	press("Verificar")
	var deadline := Time.get_ticks_msec()+15000
	while bridge.PlanningStatus() == "Verifying" and Time.get_ticks_msec() < deadline:
		await process_frame
		bridge.PollVerification()
	ui._process(0)
	check(bridge.PlanningStatus() == "Failed" and ui.error_line == 0,"invalid parameter reports/selects source line")
	press("Cargar ejemplo editable")
	ui.show_detail("Escenario")
	ui.output_enable.button_down.emit()
	press("Banda ON")
	check(bridge.Signal("belt"),"external manual output uses held permission")
	press("Banda OFF")
	ui.output_enable.button_up.emit()
	check(not bridge.Signal("belt") and not bridge.Moving(),"manual output release does not start jog")
	ui.show_detail("Diagnóstico")
	ui.next_diagnostic_update = 0
	ui._process(0)
	check(ui.io_label.text.contains("present=") and ui.event_log.text.contains("Salida manual"),"operational IO and event history accessible")
	ui.show_detail("Práctica y guía")
	press("Iniciar práctica guiada (nueva evidencia)")
	check(ui.practice_label != null,"external guided practice available")
	key(KEY_ESCAPE,true)
	press("Cargar ejemplo editable")
	ui.program_editor.text = "WAIT_INPUT present 1 0.1"
	press("Verificar")
	ui.program_editor.text += "\nWAIT 0.1"
	ui.invalidate_draft()
	check(bridge.PlanningStatus() == "Cancelled","editing invalidates old worker")
	press("Verificar")
	scene.lose_focus()
	check(bridge.PlanningStatus() == "Cancelled" and not bridge.Moving(),"synthetic focus cancels without restart")
	bridge.Focus(true)
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1024,600)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		for tab in range(2):
			ui.tabs.current_tab = tab
			await process_frame
			await process_frame
			check(ui.get_global_rect().end.y <= dimensions.y and ui.tabs.get_global_rect().size.y >= 120,"bounded pendant %s tab%d" % [dimensions,tab])
			for control in [ui.emergency_choice,ui.run_button,ui.enable_button,ui.point_name,ui.joint_label]:
				if control.is_visible_in_tree(): check(control.get_global_rect().end.y < dimensions.y and control.get_global_rect().end.x < dimensions.x,"critical control visible "+str(dimensions))
			await capture("%d-%s" % [dimensions.y,"move" if tab == 0 else "program"])
		ui.show_detail("Referencias")
		await process_frame
		check(ui.details["Referencias"].get_global_rect().end.x <= ui.get_global_rect().position.x and ui.details["Referencias"].get_global_rect().end.y < dimensions.y,"detail preserves emergency access")
		await capture("%d-detail" % dimensions.y)
		key(KEY_ESCAPE,true)
		bridge.Emergency(true)
		await process_frame
		ui._process(0)
		check(ui.alarm_label.visible and ui.reset_button.disabled,"alarm persistent, active emergency blocks reset")
		await process_frame
		check(ui.emergency_choice.get_global_rect().end.x <= dimensions.x and ui.get_global_rect().end.x <= dimensions.x and ui.get_global_rect().end.y <= dimensions.y,"alarm keeps controls within viewport")
		await capture("%d-alarm" % dimensions.y)
		bridge.Emergency(false)
		press("Restablecer")
		check(not bridge.Moving() and bridge.ReadState() == "Ready","reset no restart")
		press("Cargar ejemplo editable")
		press("Verificar")
		await process_frame
		await capture("%d-planning" % dimensions.y)
		press("Cancelar")
	ui.compact = true
	ui._process(0)
	check(not ui.tabs.visible and ui.emergency_choice.visible and not ui.can_keyboard_jog(),"collapsed retains safety and prohibits jog")
	ui.compact = false
	ui.expanded = true
	ui._process(0)
	await process_frame
	check(ui.get_rect().size.x > 600,"expanded desktop pendant")
	print("REDESIGN checks=",checks," failures=",failures)
	quit(0 if failures == 0 else 1)
