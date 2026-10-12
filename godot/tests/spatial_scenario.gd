extends Node
var failures := 0
var checks := 0
var lab: Node3D

func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1
	print("PASS " if value else "FAIL ","I ",message)

func frame() -> void:
	await get_tree().process_frame

func capture(label: String) -> void:
	if not "--capture-spatial" in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://../docs/spatial-%s.png" % label)
	check(lab.surface.viewport.get_texture().get_image().save_png(path) == OK,"capture "+label)

func aim_pixel(pixel: Vector2) -> void:
	var origin: Vector3 = lab.surface.to_global(Vector3(0,0,1))
	var target: Vector3 = lab.surface.pixel_world(pixel)
	lab.surface.pointer.aim(origin,(target-origin).normalized())

func click_control(control: Control) -> void:
	aim_pixel(control.get_global_rect().get_center())
	lab.surface.pointer.select(true)
	await frame()
	lab.surface.pointer.select(false)
	await frame()

func find_button(caption: String) -> Button:
	for node in lab.surface.viewport.find_children("*","Button",true,false):
		if node.text == caption and node.is_visible_in_tree(): return node
	return null

func click(caption: String) -> void:
	var b := find_button(caption)
	check(b != null,"ray target "+caption)
	if b != null: await click_control(b)

func write_field(target: Control, value: String) -> void:
	await click_control(target)
	check(lab.pendant.keyboard.visible,"ray opens virtual keyboard")
	check(not lab.controller.InputHeld(),"keyboard cancels held input")
	if target == lab.pendant.program_editor: await capture("keyboard")
	await click("Seleccionar todo")
	for letter in value:
		if letter.to_lower() != letter.to_upper() and (letter == letter.to_upper()) != lab.pendant.uppercase: await click("Mayús / minús")
		if letter == " ": await click("Espacio")
		elif letter == "\n": await click("Nueva línea")
		else:
			var b := find_button(letter)
			check(b != null,"virtual key "+letter)
			if b != null: await click_control(b)
	await click("Confirmar")

func wait_plan() -> void:
	var deadline := Time.get_ticks_msec()+20000
	while lab.controller.PlanningStatus() == "Verifying" and Time.get_ticks_msec() < deadline: await frame()
	check(lab.controller.PlanningStatus() == "Ready","worker ready")

func choose(option: OptionButton, index: int) -> void:
	await click_control(option)
	var popup := option.get_popup()
	check(popup.visible,"ray opens selector")
	var pixel := Vector2(popup.position)+Vector2(popup.size.x*0.5,popup.size.y*(index+0.5)/option.item_count)
	aim_pixel(pixel); lab.surface.pointer.select(true); await frame(); lab.surface.pointer.select(false); await frame()
	check(option.selected == index,"ray chooses selector")

func wait_execution() -> void:
	var deadline := Time.get_ticks_msec()+35000
	while lab.controller.ReadState() == "Running" and Time.get_ticks_msec() < deadline: await frame()
	check(lab.controller.ReadState() in ["Ready","Paused"],"execution completes or steps "+lab.controller.ReadStatus())
	await frame(); await frame()

func run(scene: Node3D) -> void:
	lab = scene
	lab.adapter.set_process(false)
	lab.adapter.set_process_input(false)
	# Fixture owns synthetic availability. OS focus is a separate human test, not inferred here.
	for event_signal in [get_window().focus_entered,get_window().focus_exited]:
		for connection in event_signal.get_connections():
			if connection.callable.get_object() == lab.adapter: event_signal.disconnect(connection.callable)
	lab.controller.SessionAvailability(true,true)
	await frame(); await frame()
	check(lab.surface.ray_uv(lab.surface.to_global(Vector3(0,0,1)), -lab.surface.global_basis.z).distance_to(Vector2(640,500)) < 0.01,"ray metric center")
	check(lab.surface.ray_uv(lab.surface.to_global(Vector3(2,0,1)), -lab.surface.global_basis.z).x < 0,"ray out of bounds")
	var door_control: Node3D = lab.world_controls[0]
	var ray_origin: Vector3 = door_control.global_position+Vector3(0,0,1)
	lab.surface.pointer.aim(ray_origin,Vector3(0,0,-1))
	lab.surface.pointer.select(true); lab.surface.pointer.select(false)
	check(not lab.controller.DoorIsClosed(),"world door ray changes real interlock")
	lab.surface.pointer.aim(ray_origin,Vector3(0,0,-1)); lab.surface.pointer.select(true); lab.surface.pointer.select(false)
	check(lab.controller.DoorIsClosed(),"world door ray closes")
	await frame(); await click("Restablecer")
	await click("Proyecto")
	await click("Nuevo proyecto vacío")
	check(lab.controller.ProgramText("main") == "","empty project by spatial UI")
	await click("Cerrar")
	await click("Referencias…")
	check(lab.pendant.details["Referencias"].visible,"references surface")
	var before: float = lab.controller.Angle(0)
	await choose(lab.pendant.tool_choice,1)
	await choose(lab.pendant.frame_choice,0)
	await click("Seleccionar TCP y frame")
	check(lab.controller.ActiveTool() == "tool" and lab.controller.Angle(0) == before,"references selected without movement")
	await click("Cerrar")
	lab.controller.Enable(false); lab.controller.Enable(true)
	var jog: Button = lab.pendant.movement_buttons[1]
	aim_pixel(jog.get_global_rect().get_center()); lab.surface.pointer.select(true)
	await get_tree().create_timer(0.15).timeout
	check(lab.controller.Moving(),"ray jog with separate enabling")
	aim_pixel(Vector2(-30,-30))
	check(not lab.controller.Moving(),"capture exit cancels jog")
	lab.surface.pointer.select(false)
	lab.controller.Enable(false)
	await write_field(lab.pendant.point_name,"A")
	await click("Enseñar punto")
	check(JSON.parse_string(lab.controller.PointsJson()).size() == 1,"point A taught")
	lab.controller.Enable(false); lab.controller.Enable(true)
	aim_pixel(jog.get_global_rect().get_center()); lab.surface.pointer.select(true)
	await get_tree().create_timer(0.12).timeout
	lab.surface.pointer.select(false); lab.controller.Enable(false)
	await write_field(lab.pendant.point_name,"B")
	await click("Enseñar punto")
	check(JSON.parse_string(lab.controller.PointsJson()).size() == 2,"point B taught")
	# Select the production tab via ray, not a view-model command.
	var bar: TabBar = lab.pendant.tabs.get_tab_bar()
	await click_control_rect(bar,bar.get_tab_rect(1))
	await click("Texto…")
	var points = JSON.parse_string(lab.controller.PointsJson())
	var text := "MOVEJ %s 1\nMOVEJ %s 1\nWAIT 0.01\nCALL SUB\nREPEAT 2\nIF present 1\nSET_OUTPUT belt 0\nELSE\nWAIT 0.02\nENDIF\nENDREPEAT" % [points[0].Id,points[1].Id]
	await write_field(lab.pendant.program_editor,"WAIT 0.01")
	check(lab.pendant.program_editor.text == "WAIT 0.01","virtual text draft")
	await click("Cerrar")
	await write_field(lab.pendant.program_name,"SUB")
	await click("Aplicar ID")
	check(lab.controller.ProgramText("SUB") == "WAIT 0.01","subprogram via spatial UI")
	await choose(lab.pendant.program_choice,0)
	await click("Texto…")
	await write_field(lab.pendant.program_editor,text)
	check(lab.pendant.program_editor.text == text,"full virtual language preserves IDs/case/newlines")
	await click("Cerrar")
	await click("Verificar"); await wait_plan()
	check(lab.controller.ProgramText("main") == text,"shared applied draft")
	await capture("program")
	await choose(lab.pendant.mode_choice,1)
	await click_control_rect(lab.pendant.speed_slider,Rect2(Vector2(lab.pendant.speed_slider.size.x-4,0),Vector2(2,lab.pendant.speed_slider.size.y)))
	await click("Paso"); await wait_plan(); await wait_execution()
	check(lab.controller.ReadState() == "Paused","step pauses")
	await click("Reanudar"); await wait_execution()
	check(lab.controller.ReadState() == "Ready","own nested CALL program completes")
	# Exercise source/session gates against actual bridge/worker; synthetic events are not hardware.
	lab.controller.Enable(false); lab.controller.Enable(true)
	lab.controller.DeviceAvailability(false,false)
	check(not lab.controller.InputHeld() and not lab.controller.Moving(),"tracking loss")
	await click("Detener")
	check(lab.controller.ReadState() == "Ready","stop priority without controlling device")
	lab.controller.DeviceAvailability(true,true); lab.controller.Enable(true)
	check(not lab.controller.InputHeld(),"tracking restoration no rearm")
	lab.controller.SessionAvailability(false,false)
	check(lab.controller.PlanningStatus() != "Verifying" and not lab.controller.Moving(),"session cancels pending motion")
	lab.controller.SessionAvailability(true,true)
	lab.controller.SelectSource("Test"); lab.controller.SelectSource("Emulation")
	check(not lab.controller.InputHeld(),"source switch no rearm")
	await click("Proyecto")
	await write_field(lab.pendant.project_name,"PRUEBA ESPACIAL %d" % Time.get_ticks_msec())
	var saved_name: String = lab.pendant.project_name.text
	await click("Guardar / guardar como")
	check(lab.controller.ProjectExists(saved_name),"managed save")
	await click("Guardar / guardar como")
	check(lab.pendant.replace_prompt.visible,"overwrite requires confirmation")
	await click("Cancelar sustitución")
	check(not lab.pendant.replace_prompt.visible,"cancel overwrite retains existing project")
	await click("Nuevo proyecto vacío")
	await click("Cargar seleccionado")
	check(lab.controller.ProgramText("main") == text and lab.controller.ReadMode() == "Manual" and not lab.controller.Moving(),"managed load without movement")
	await click("Cerrar")
	await click("Paro de celda")
	check(lab.controller.EmergencyActive(),"world safety action")
	await capture("alarm")
	await click("Diagnóstico")
	check(lab.pendant.details["Diagnóstico"].visible,"diagnosis spatial")
	await capture("diagnosis")
	await click("Cerrar")
	await click_control(lab.pendant.emergency_choice)
	await click("Restablecer")
	check(lab.controller.ReadState() == "Ready" and not lab.controller.Moving(),"reset no restart")
	await click("Práctica y guía")
	check(lab.pendant.details["Práctica y guía"].visible,"guide spatial")
	await click("Cargar ejemplo editable")
	await click("Cerrar")
	await choose(lab.pendant.mode_choice,1)
	await click("Iniciar"); await wait_plan(); await wait_execution()
	check(lab.controller.Signal("delivered"),"spatial full cell cycle delivered")
	await click("Escenario")
	await write_field(lab.pendant.destination_values[0].get_line_edit(),"500")
	await click("Cambiar estación destino")
	check(absf(lab.controller.DestinationPosition().x-0.5) < 0.0001,"destination changed through virtual numeric field")
	await click("Reponer celda")
	await click_control(lab.pendant.sensor_choice)
	check(lab.controller.SensorFaultActive(),"teacher sensor fault")
	await click("Cerrar")
	await click("Iniciar"); await wait_plan()
	var fault_deadline := Time.get_ticks_msec()+15000
	while lab.controller.ReadState() == "Running" and Time.get_ticks_msec() < fault_deadline: await frame()
	check(lab.controller.ReadState() == "Faulted" and lab.controller.AlarmText().contains("timeout"),"spatial real sensor timeout")
	await frame(); await frame()
	await click("Diagnóstico")
	check(lab.pendant.io_label.text.contains("present=0"),"fault signal visible")
	await click("Cerrar")
	await click("Escenario")
	await click_control(lab.pendant.sensor_choice)
	await click("Cerrar")
	await click("Restablecer")
	check(lab.controller.ReadState() == "Ready" and not lab.controller.Moving(),"sensor recovery no restart")
	if "--capture-spatial" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/spatial-world.png"))
		lab.surface.viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../docs/spatial-surface.png"))
	print("SPATIAL checks=",checks," failures=",failures)

func click_control_rect(control: Control, rect: Rect2) -> void:
	aim_pixel(control.global_position+rect.get_center())
	lab.surface.pointer.select(true); await frame(); lab.surface.pointer.select(false); await frame()
