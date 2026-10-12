extends SceneTree

var failures := 0
func check(condition: bool, message: String) -> void:
	if condition: print("PASS ",message)
	else: failures += 1; push_error(message)

func press(scene: Node3D, caption: String) -> void:
	for node in scene.find_children("*","Button",true,false):
		if node.text == caption: node.pressed.emit(); return
	check(false,"button missing: " + caption)


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
	scene.set_process(false)
	scene.set_physics_process(false)
	var bridge = scene.controller
	bridge.set_physics_process(false)
	var ui = scene.pendant
	press(scene,"Cargar ejemplo editable")
	press(scene,"Iniciar práctica guiada (nueva evidencia)")
	press(scene,"Seleccionar TCP y frame")
	ui.point_name.text = "Mi punto propio"
	press(scene,"Enseñar punto")
	var points: Array = JSON.parse_string(bridge.PointsJson())
	check(points.size() == 8,"teach button creates learner point")
	var id: String = points[-1].Id
	ui.point_list.select(7)
	ui.select_point(7)
	ui.point_name.text = "Punto editado"
	ui.point_edit_name.text = "Punto editado"
	ui.point_values[0].value = 10
	press(scene,"Aplicar edición sin mover")
	points = JSON.parse_string(bridge.PointsJson())
	check(points[-1].Name == "Punto editado" and abs(points[-1].Values[0]-10) < 1e-9,"point editor stores degrees and name")
	check(abs(bridge.Angle(0)) < 1e-9,"offline point edit does not move robot")
	check(bridge.EditProgram("main","MOVEJ %s 3" % id),"custom point used by program")
	check(not bridge.DeletePoint(id),"cannot delete referenced point")
	check(bridge.EditProgram("main",""),"clear program")
	check(bridge.DeletePoint(id),"delete unreferenced point")
	ui.refresh_points()
	ui.refresh_programs()
	ui.program_editor.text = "WAIT 0.01"
	ui.program_editor.set_caret_line(0)
	ui.instruction_choice.select(4)
	ui.insert_instruction()
	check(ui.program_editor.text.contains("WAIT 3"),"instruction inserted into editor")
	ui.program_editor.text = "WAIT 0.01\nWAIT 0.02"
	ui.program_editor.set_caret_line(1)
	press(scene,"↑")
	check(ui.program_editor.text.begins_with("WAIT 0.02"),"reorder instruction upward")
	press(scene,"Borrar")
	check(ui.program_editor.text == "WAIT 0.01","delete instruction line")
	press(scene,"Verificar")
	await settle(bridge)
	check(bridge.ReadStatus().contains("verificados"),"draft verification visible")
	ui.mode_choice.item_selected.emit(1)
	press(scene,"Paso")
	await settle(bridge)
	bridge._PhysicsProcess(0.02)
	check(bridge.ReadState() == "Paused","step control pauses after instruction")
	check(not bridge.EditProgram("main","WAIT 0.3"),"active program edits blocked")
	press(scene,"Iniciar")
	bridge._PhysicsProcess(0.02)
	check(bridge.ReadState() == "Ready","start resumes by explicit action")
	ui.file_path.text = "user://pendant-test-%d.json" % Time.get_ticks_usec()
	press(scene,"Guardar JSON")
	var path: String = ProjectSettings.globalize_path(ui.file_path.text)
	check(FileAccess.file_exists(path),"save button writes versioned project")
	press(scene,"Cargar JSON")
	check(bridge.ReadState() == "Ready" and bridge.ReadMode() == "Manual" and not bridge.Moving(),"load button leaves manual stopped")
	DirAccess.remove_absolute(path) # Only the unique temporary file created by this test.
	var bad_path: String = ProjectSettings.globalize_path("user://pendant-bad-%d.json" % Time.get_ticks_usec())
	var file := FileAccess.open(bad_path,FileAccess.WRITE)
	file.store_string("{bad json")
	file.close()
	ui.file_path.text = bad_path
	press(scene,"Cargar JSON")
	check(bridge.ReadStatus() != "Proyecto cargado detenido; postura actual conservada" and bridge.ReadMode() == "Manual","corrupt file rejected through external Project controls")
	check(JSON.parse_string(bridge.PointsJson()).size() == 7,"corrupt load preserves project")
	DirAccess.remove_absolute(bad_path)
	bridge.Mode(true)
	bridge.EditProgram("main","WAIT_INPUT present 1 0.1")
	ui.refresh_programs()
	bridge.SensorFault(true)
	bridge.Run(false)
	await settle(bridge)
	bridge._PhysicsProcess(0.1)
	check(bridge.ReadState() == "Faulted" and bridge.AlarmText().contains("timeout"),"sensor timeout visible in pendant alarm")
	bridge.Door(false)
	check(not bridge.ResetAlarm(),"reset rejects active safety cause")
	bridge.Door(true)
	bridge.SensorFault(false)
	press(scene,"Restablecer")
	check(bridge.ReadState() == "Ready" and not bridge.Moving(),"reset does not restart")
	var report: String = bridge.PracticeReport()
	check(report.contains("✓ Enseñar") and report.contains("✓ Crear") and report.contains("✓ Verificar") and report.contains("✓ Completar") and report.contains("✓ Retirar") and report.contains("✓ Guardar") and report.contains("✓ Cargar"),"guided facts reflect successful UI actions")
	bridge.EditProgram("main","WAIT 0.01")
	check(abs(bridge.TcpReadout()[2]-1130) < 0.0001,"pose display preserves 1130 mm zero height")
	print("Pendant failures: ",failures)
	quit(0 if failures == 0 else 1)
