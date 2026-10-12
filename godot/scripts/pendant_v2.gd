extends "res://scripts/pendant_components.gd"
# Layout and drafts only; every operation remains authorized by Core.
var details: Dictionary = {}
var sequence: ItemList
var sequence_text := "\u0001"
var draft_label: Label
var alarm_label: Label
var speed_label: Label
var speed_slider: HSlider
var joint_label: Label
var reference_summary: Label
var run_button: Button
var step_button: Button
var pause_button: Button
var verify_button: Button
var reset_button: Button
var movement_buttons: Array[Button] = []
var instruction_arguments: LineEdit
var instruction_help: Label
var compact := false
var expanded := false
var selected_line := 0
var keyboard_armed := false
var output_enable: Button
var permission_label: Label
var point_edit_name: LineEdit
var selection_summary: Label
var last_report := ""
var error_line := -1
var notice := ""
var notice_until := 0
var catalog_choice: OptionButton
var last_op := ""
var next_diagnostic_update := 0
var guarded_buttons: Array[Button] = []
var alarm_row: HBoxContainer

func setup(scene: Node3D, controller: Node) -> void:
	lab = scene
	bridge = controller
	set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	offset_top = 48
	offset_bottom = -10
	offset_right = -10
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17222f")
	style.border_color = Color("647d91")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	add_theme_stylebox_override("panel",style)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,10)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",4)
	margin.add_child(column)
	var modes := row(column)
	mode_choice = OptionButton.new()
	mode_choice.add_item("Manual")
	mode_choice.add_item("Automático")
	mode_choice.item_selected.connect(func(index): cancel_input(); bridge.Mode(index == 1))
	modes.add_child(mode_choice)
	state_label = wrapped(modes,"")
	state_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	button(modes,"Detener",func(): cancel_input(); bridge.StopProgram()).tooltip_text = "Stop: cancela programa; próximo Inicio vuelve al comienzo"
	button(modes,"Ancho",func(): cancel_input(); expanded = not expanded).tooltip_text = "Ampliar o reducir el pendant"
	button(modes,"Panel",func(): cancel_input(); compact = not compact).tooltip_text = "Contraer o mostrar área de trabajo; seguridad sigue visible"
	var tools := row(column)
	emergency_choice = CheckButton.new()
	emergency_choice.text = "Emergencia virtual"
	emergency_choice.toggled.connect(func(value): cancel_input(); bridge.Emergency(value))
	tools.add_child(emergency_choice)
	alarm_row = row(column)
	alarm_label = wrapped(alarm_row,"")
	reset_button = button(alarm_row,"Restablecer",func(): cancel_input(); bridge.ResetAlarm())
	button(tools,"Diagnóstico",func(): show_detail("Diagnóstico"))
	button(tools,"Ayuda",func(): show_detail("Ayuda de operación"))
	var speed_row := row(column)
	speed_label = wrapped(speed_row,"")
	speed_slider = HSlider.new()
	speed_slider.min_value = 5
	speed_slider.max_value = 100
	speed_slider.step = 5
	speed_slider.value = 25
	speed_slider.value_changed.connect(func(value): cancel_input(); bridge.Speed(value))
	speed_slider.custom_minimum_size.x = 130
	speed_row.add_child(speed_slider)
	var execution := row(column)
	verify_button = button(execution,"Verificar",func(): cancel_input(); if apply_draft(): bridge.Verify())
	run_button = button(execution,"Iniciar",func(): cancel_input(); run_program(false))
	step_button = button(execution,"Paso",func(): cancel_input(); run_program(true))
	pause_button = button(execution,"Pausa",pause_or_resume)
	cancel_plan = button(execution,"Cancelar",func(): bridge.CancelVerification())
	planning_label = wrapped(column,"")
	status_label = wrapped(column,"")
	status_label.max_lines_visible = 2
	permission_label = wrapped(column,"")
	reference_summary = wrapped(column,"")
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	tabs.tab_changed.connect(func(_index): cancel_input(); get_viewport().gui_release_focus())
	var moving := VBoxContainer.new()
	moving.name = "Mover y enseñar"
	moving.add_theme_constant_override("separation",4)
	tabs.add_child(moving)
	build_jog(moving)
	build_points(moving)
	var program := VBoxContainer.new()
	program.name = "Programa"
	program.add_theme_constant_override("separation",4)
	tabs.add_child(program)
	build_program(program)
	build_references(make_detail("Referencias"))
	tool_choice.item_selected.connect(func(_index): cancel_input())
	frame_choice.item_selected.connect(func(_index): cancel_input())
	var pose_detail := make_detail("Pose y ejes")
	for reading in readings: reading.reparent(pose_detail); reading.show()
	var full_pose := wrapped(pose_detail,"")
	full_pose.name = "FullPose"
	button(moving,"Pose y ejes…",func(): show_detail("Pose y ejes"))
	build_environment(make_detail("Escenario"))
	build_practice(make_detail("Práctica y guía"))
	build_files(make_detail("Proyecto"))
	var help := make_detail("Ayuda de operación")
	wrapped(help,"Manual: mantener habilitación y sentido para mover. Articular controla J1–J6; cartesiano controla el TCP en la referencia elegida. XYZ en mm; RPY en grados, Rz × Ry × Rx.\n\nMoveJ interpola articulaciones; MoveL busca una línea del TCP y cambia orientación. Extremos válidos no garantizan un recorrido válido. Duración en segundos es mínima y puede alargarse por límites.\n\nVerificar aplica borrador y revisa trayectos. Iniciar requiere Automático y condiciones seguras. Paso pausa al completar una instrucción. Pausa conserva avance; Stop vuelve al comienzo. Emergencia enclava alarma. Retirar causa → Restablecer → nuevo Inicio; restablecer no arranca.\n\nEspacio + ←/→ solo en Mover y enseñar, sin campos con foco ni detalles abiertos. Escape cancela entradas/cierra detalle. Cámara: botón derecho y rueda fuera del panel.\n\nSeguridad educativa: paro instantáneo y colisiones aproximadas; no certifica operación real ni aprendizaje. Sin VR implementado.")
	var external := HBoxContainer.new()
	external.position = Vector2(10,7)
	get_parent().add_child(external)
	external.add_child(text("SIMULADOR",16))
	for title in ["Proyecto","Escenario","Práctica y guía"]: button(external,title,func(): show_detail(title))
	refresh_all()
	get_viewport().gui_focus_changed.connect(func(control):
		if control is LineEdit or control is TextEdit: cancel_input())

func row(parent: Node) -> HBoxContainer:
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation",4)
	parent.add_child(result)
	return result

func button(parent: Node, caption: String, action: Callable) -> Button:
	var result := super.button(parent,caption,func(): notice_until = 0; action.call())
	result.focus_mode = Control.FOCUS_ALL
	if caption in ["Enseñar punto","Eliminar punto","Aplicar edición sin mover","Aplicar ID","Aplicar borrador","Aplicar referencia (no mueve robot)","Seleccionar TCP y frame","Guardar JSON","Cargar JSON","Cargar ejemplo editable","Iniciar práctica guiada (nueva evidencia)","Modo libre","Programa vacío","Cambiar estación destino","Sin pieza","Reponer celda","Insertar instrucción","Reemplazar seleccionada","Borrar","↑","↓"]: result.set_meta("permission","edit")
	if caption in ["Cerrar pinza","Abrir","Banda ON","Banda OFF"]: result.set_meta("permission","output")
	if result.has_meta("permission"): guarded_buttons.append(result)
	return result

func make_detail(title: String) -> VBoxContainer:
	var popup := PanelContainer.new()
	popup.name = title
	get_parent().add_child(popup)
	details[title] = popup
	popup.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color("1d3042")
	style.set_border_width_all(2)
	style.border_color = Color("83a6bb")
	popup.add_theme_stylebox_override("panel",style)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,12)
	popup.add_child(margin)
	var outer := VBoxContainer.new()
	margin.add_child(outer)
	var header := row(outer)
	header.add_child(text(title,19))
	button(header,"Cerrar",func(): popup.hide(); cancel_input())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	return content

func show_detail(title: String) -> void:
	cancel_input()
	expanded = false # Reserve space for the detail without covering persistent safety controls.
	offset_left = -minf(480,get_viewport_rect().size.x-32)
	for popup in details.values(): popup.hide()
	var size := get_viewport_rect().size
	details[title].position = Vector2(10,48)
	details[title].size = Vector2(minf(660,size.x-get_rect().size.x-30),size.y-60)
	details[title].show()

func cancel_input() -> void:
	keyboard_armed = false
	lab.jog_held = false
	bridge.StopJog()
	bridge.Enable(false)
	if enable_button != null: enable_button.set_pressed_no_signal(false)
	if output_enable != null: output_enable.set_pressed_no_signal(false)

func mouse_enabled() -> bool:
	return enable_button.button_pressed or (output_enable != null and output_enable.button_pressed)

func can_keyboard_jog() -> bool:
	if compact or tabs.current_tab != 0: return false
	for popup in details.values():
		if popup.visible: return false
	var focus = get_viewport().gui_get_focus_owner()
	return focus == null or focus == enable_button or (focus is Button and focus in movement_buttons)

func pause_or_resume() -> void:
	cancel_input()
	if bridge.ReadState() == "Paused": bridge.Run(false)
	else: bridge.PauseProgram()

func build_jog(parent: VBoxContainer) -> void:
	var controls := row(parent)
	var type := OptionButton.new()
	type.add_item("Articular")
	type.add_item("Cartesiano")
	type.item_selected.connect(func(index): cancel_input(); cartesian = index == 1; populate_axes(); get_viewport().gui_release_focus())
	controls.add_child(type)
	axis_choice = OptionButton.new()
	controls.add_child(axis_choice)
	populate_axes()
	axis_choice.item_selected.connect(func(index): cancel_input(); lab.selected_joint = index; get_viewport().gui_release_focus())
	button(controls,"Referencias…",func(): show_detail("Referencias"))
	pose_label = wrapped(parent,"")
	joint_label = wrapped(parent,"")
	for i in range(6):
		var reading := text("",14)
		reading.visible = false
		readings.append(reading)
		parent.add_child(reading)
	var jog := row(parent)
	enable_button = Button.new()
	enable_button.text = "Habilitar · mantener"
	enable_button.focus_mode = Control.FOCUS_NONE
	enable_button.button_down.connect(func(): bridge.Enable(true))
	enable_button.button_up.connect(cancel_input)
	jog.add_child(enable_button)
	for sense in [-1,1]:
		var b := Button.new()
		b.text = "− / ←" if sense < 0 else "+ / →"
		b.custom_minimum_size = Vector2(68,36)
		b.focus_mode = Control.FOCUS_NONE
		b.button_down.connect(func(): start_jog(sense))
		b.button_up.connect(func(): lab.jog_held = false; bridge.StopJog())
		jog.add_child(b)
		movement_buttons.append(b)

func start_jog(sense: int) -> void:
	if not can_keyboard_jog(): cancel_input(); return
	super.start_jog(sense)

func build_points(parent: VBoxContainer) -> void:
	var teaching := row(parent)
	point_name = field(teaching,"Punto nuevo")
	point_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	point_type = OptionButton.new()
	point_type.add_item("Articular")
	point_type.add_item("Cartesiano")
	teaching.add_child(point_type)
	button(teaching,"Enseñar punto",func():
		cancel_input()
		if bridge.TeachPoint(point_name.text,point_type.selected == 1):
			refresh_points()
			point_list.select(points.size()-1)
			select_point(points.size()-1)
			instruction_point.select(points.size()-1)
			announce("Enseñado: "+points[-1].Name+" · "+points[-1].Id))
	point_list = ItemList.new()
	point_list.custom_minimum_size.y = 48
	point_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	point_list.item_selected.connect(select_point)
	parent.add_child(point_list)
	var actions := row(parent)
	button(actions,"Detalle / editar punto",func():
		if not point_list.get_selected_items().is_empty(): show_detail("Punto seleccionado"))
	button(actions,"Eliminar punto",func():
		var chosen = point_list.get_selected_items()
		if chosen.size(): cancel_input(); bridge.DeletePoint(points[chosen[0]].Id); refresh_points())
	var detail := make_detail("Punto seleccionado")
	help_label = wrapped(detail,"")
	point_edit_name = field(detail,"")
	wrapped(detail,"Editar nombre/valores no mueve el robot; conserva ID, tipo y referencias. Un valor rechazado conserva el punto previo.")
	numeric_fields(detail,["J1 / X","J2 / Y","J3 / Z","J4 / Roll","J5 / Pitch","J6 / Yaw"],point_values)
	button(detail,"Aplicar edición sin mover",func():
		var chosen = point_list.get_selected_items()
		if chosen.size():
			if bridge.EditPoint(points[chosen[0]].Id,point_edit_name.text,numbers(point_values)): announce("Punto editado sin mover")
			refresh_points())

func select_point(index: int) -> void:
	cancel_input()
	super.select_point(index)
	point_edit_name.text = points[index].Name
	var captions := ["J1 °","J2 °","J3 °","J4 °","J5 °","J6 °"] if points[index].Kind == "Joint" else ["X mm","Y mm","Z mm","Roll °","Pitch °","Yaw °"]
	for i in range(point_values.size()): point_values[i].get_parent().get_child(0).text = captions[i]

func refresh_points() -> void:
	var instruction_id := ""
	if instruction_point.selected >= 0 and instruction_point.selected < points.size(): instruction_id = points[instruction_point.selected].Id
	super.refresh_points()
	for i in range(points.size()):
		if points[i].Id == instruction_id: instruction_point.select(i)

func build_program(parent: VBoxContainer) -> void:
	var identity := row(parent)
	program_choice = OptionButton.new()
	program_choice.item_selected.connect(func(_index):
		if bridge.ReadState() in ["Running","Paused"]: return
		cancel_input()
		program_name.text = program_choice.get_item_text(program_choice.selected)
		program_editor.text = bridge.ProgramText(program_name.text))
	identity.add_child(program_choice)
	program_name = field(identity,"main")
	program_name.tooltip_text = "ID para crear/guardar copia; Aplicar ID no renombra el original"
	program_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(identity,"Aplicar ID",func(): if bridge.EditProgram(program_name.text,program_editor.text): refresh_programs(program_name.text))
	draft_label = wrapped(parent,"")
	selection_summary = wrapped(parent,"Selección de edición independiente de instrucción activa")
	sequence = ItemList.new()
	sequence.custom_minimum_size.y = 75
	sequence.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sequence.item_selected.connect(func(index): selected_line = index; program_editor.set_caret_line(index); load_instruction(index))
	parent.add_child(sequence)
	var editing := row(parent)
	button(editing,"Añadir…",func(): show_detail("Instrucción"))
	button(editing,"Editar…",func(): load_instruction(selected_line); show_detail("Instrucción"))
	button(editing,"Borrar",func(): edit_line(0))
	button(editing,"↑",func(): edit_line(-1))
	button(editing,"↓",func(): edit_line(1))
	button(editing,"Texto…",func(): show_detail("Texto del programa"))
	var text_panel := make_detail("Texto del programa")
	program_editor = TextEdit.new()
	program_editor.custom_minimum_size.y = 220
	program_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	program_editor.text_changed.connect(invalidate_draft)
	program_editor.caret_changed.connect(func(): selected_line = program_editor.get_caret_line())
	text_panel.add_child(program_editor)
	button(text_panel,"Aplicar borrador",apply_draft)
	wrapped(text_panel,"Lenguaje propio. Decimales con punto; # comentario. Borrador pendiente invalida la verificación; editar requiere Stop.")
	var parameters := make_detail("Instrucción")
	catalog_choice = OptionButton.new()
	for category in ["Movimiento","Señales","Lógica"]: catalog_choice.add_item(category)
	parameters.add_child(catalog_choice)
	catalog_choice.item_selected.connect(func(index):
		instruction_choice.select([0,2,4][index])
		instruction_context())
	instruction_choice = OptionButton.new()
	for op in ["MOVEJ","MOVEL","SET_OUTPUT","WAIT_INPUT","WAIT","IF/ELSE","REPEAT","CALL","ELSE","ENDIF","ENDREPEAT"]: instruction_choice.add_item(op)
	parameters.add_child(instruction_choice)
	instruction_choice.item_selected.connect(func(_index): instruction_context())
	instruction_point = OptionButton.new()
	parameters.add_child(instruction_point)
	button(parameters,"Detalle del punto",func():
		if instruction_point.selected >= 0: point_list.select(instruction_point.selected); select_point(instruction_point.selected); show_detail("Punto seleccionado"))
	instruction_help = wrapped(parameters,"")
	duration = SpinBox.new()
	duration.min_value = 0.01
	duration.max_value = 120
	duration.step = 0.01
	duration.value = 3
	duration.suffix = "s"
	parameters.add_child(duration)
	instruction_arguments = field(parameters,"")
	button(parameters,"Insertar instrucción",insert_instruction)
	button(parameters,"Reemplazar seleccionada",replace_instruction)
	wrapped(parameters,"Movimiento: MOVEJ/MOVEL. Señales: SET_OUTPUT/WAIT_INPUT. Lógica: WAIT, IF/ELSE/ENDIF, REPEAT/ENDREPEAT, CALL. Cierres y anidamiento visibles en secuencia.")
	instruction_context()

func instruction_context() -> void:
	var op := instruction_choice.get_item_text(instruction_choice.selected)
	catalog_choice.select(0 if op in ["MOVEJ","MOVEL"] else (1 if op in ["SET_OUTPUT","WAIT_INPUT"] else 2))
	for i in range(instruction_choice.item_count):
		var candidate := instruction_choice.get_item_text(i)
		instruction_choice.set_item_disabled(i,not ((catalog_choice.selected == 0 and candidate in ["MOVEJ","MOVEL"]) or (catalog_choice.selected == 1 and candidate in ["SET_OUTPUT","WAIT_INPUT"]) or (catalog_choice.selected == 2 and not candidate in ["MOVEJ","MOVEL","SET_OUTPUT","WAIT_INPUT"])))
	instruction_point.visible = op in ["MOVEJ","MOVEL"]
	duration.visible = op in ["MOVEJ","MOVEL","WAIT"]
	instruction_arguments.visible = not op in ["MOVEJ","MOVEL","WAIT","ELSE","ENDIF","ENDREPEAT"]
	var hints := {"MOVEJ":"MoveJ · recorrido articular. Duración mínima (s).","MOVEL":"MoveL · línea del TCP y orientación. Duración mínima (s).","SET_OUTPUT":"Salida y valor: grip|belt 0|1","WAIT_INPUT":"Señal, valor y timeout (s): present 1 3","IF/ELSE":"Condición: present 1. Inserta bloque IF/ELSE/ENDIF.","REPEAT":"Número de repeticiones (ej. 2)","CALL":"ID del subprograma (debe existir)","WAIT":"Espera en segundos."}
	instruction_help.text = hints.get(op,"Cierre de estructura; compilador verifica alcance.")
	instruction_arguments.placeholder_text = {"SET_OUTPUT":"grip 1","WAIT_INPUT":"present 1 3","IF/ELSE":"present 1","REPEAT":"2","CALL":"pickup"}.get(op,"")
	if op != last_op: instruction_arguments.text = instruction_arguments.placeholder_text
	last_op = op

func instruction_value(block := true) -> String:
	var op := instruction_choice.get_item_text(instruction_choice.selected)
	if op in ["MOVEJ","MOVEL"]:
		if instruction_point.selected < 0 or points.is_empty(): return ""
		return "%s %s %.2f" % [op,points[instruction_point.selected].Id,duration.value]
	if op == "WAIT": return "WAIT %.2f" % duration.value
	if op in ["ELSE","ENDIF","ENDREPEAT"]: return op
	var args := instruction_arguments.text.strip_edges()
	if args.is_empty(): args = instruction_arguments.placeholder_text
	if op == "IF/ELSE": return "IF %s\nWAIT 0.1\nELSE\nWAIT 0.1\nENDIF" % args if block else "IF "+args
	if op == "REPEAT": return "REPEAT %s\nWAIT 0.1\nENDREPEAT" % args if block else "REPEAT "+args
	return op+" "+args

func insert_instruction() -> void:
	if bridge.ReadState() in ["Running","Paused"]: return
	var value := instruction_value()
	if value.is_empty(): return
	var lines := program_editor.text.split("\n")
	var index := clampi(program_editor.get_caret_line(),0,lines.size()-1)
	if lines[index].strip_edges().is_empty(): lines[index] = value
	else: lines.insert(index+1,value)
	program_editor.text = "\n".join(lines)
	program_editor.set_caret_line(mini(index+1,program_editor.get_line_count()-1))
	invalidate_draft()

func replace_instruction() -> void:
	if bridge.ReadState() in ["Running","Paused"]: return
	var lines := program_editor.text.split("\n")
	lines[selected_line] = instruction_value(false)
	program_editor.text = "\n".join(lines)
	invalidate_draft()

func load_instruction(index: int) -> void:
	var lines := program_editor.text.split("\n")
	if index >= lines.size(): return
	var tokens := lines[index].strip_edges().split(" ",false)
	if tokens.is_empty(): return
	var op := "IF/ELSE" if tokens[0] == "IF" else tokens[0]
	for i in range(instruction_choice.item_count):
		if instruction_choice.get_item_text(i) == op: instruction_choice.select(i)
	instruction_context()
	if tokens[0] in ["MOVEJ","MOVEL"] and tokens.size() >= 3:
		for i in range(points.size()):
			if points[i].Id == tokens[1]: instruction_point.select(i)
		duration.value = tokens[2].to_float()
	elif tokens[0] == "WAIT" and tokens.size() > 1: duration.value = tokens[1].to_float()
	else: instruction_arguments.text = " ".join(tokens.slice(1))

func edit_line(direction: int) -> void:
	if bridge.ReadState() in ["Running","Paused"]: return
	# Both text caret and sequence selection address the same draft line.
	selected_line = program_editor.get_caret_line()
	super.edit_line(direction)
	selected_line = program_editor.get_caret_line()
	invalidate_draft()

func build_files(parent: VBoxContainer) -> void:
	file_path = field(parent,"user://robot-demo.json")
	button(parent,"Guardar JSON",func(): if apply_draft(): bridge.SaveProject(ProjectSettings.globalize_path(file_path.text)))
	button(parent,"Cargar JSON",func(): cancel_input(); if bridge.LoadProject(ProjectSettings.globalize_path(file_path.text)): refresh_all())
	wrapped(parent,"Guardar aplica y compila borrador. Cargar valida y queda detenido en Manual; conserva alarmas enclavadas. Archivo inválido no reemplaza proyecto.")

func build_environment(parent: VBoxContainer) -> void:
	var persistent_emergency := emergency_choice
	super.build_cell(parent)
	var diagnosis := make_detail("Diagnóstico")
	io_label.reparent(diagnosis)
	event_log.reparent(diagnosis)
	emergency_choice.queue_free()
	emergency_choice = persistent_emergency
	output_enable = Button.new()
	output_enable.text = "Habilitar salidas · mantener"
	output_enable.focus_mode = Control.FOCUS_NONE
	output_enable.button_down.connect(func(): bridge.Enable(true))
	output_enable.button_up.connect(cancel_input)
	parent.add_child(output_enable)
	wrapped(diagnosis,"Retirar causa → Restablecer → nuevo Inicio. Cerrar detalle no oculta alarma. Salidas manuales requieren habilitación.")

func refresh_all() -> void:
	super.refresh_all()
	notice_until = 0
	if point_list.get_selected_items().is_empty(): point_name.text = "Punto %d" % (points.size()+1)
	sequence_text = "\u0001"
	error_line = -1

func announce(message: String) -> void:
	notice = message
	notice_until = Time.get_ticks_msec()+3500

func _process(_delta: float) -> void:
	if bridge == null: return
	invalidate_draft()
	offset_left = -minf(720 if expanded else 480,get_viewport_rect().size.x-32)
	tabs.visible = not compact
	anchor_bottom = 0 if compact else 1
	offset_bottom = 290 if compact else -10
	var state: String = bridge.ReadState()
	var planning: String = bridge.PlanningStatus()
	var editable: bool = not state in ["Running","Paused"] and not bridge.Moving()
	var permission_hints := {"edit":bridge.ActionHint("edit"),"output":bridge.ActionHint("output")}
	for b in guarded_buttons:
		var reason: String = permission_hints[b.get_meta("permission")]
		b.disabled = not reason.is_empty()
		b.tooltip_text = reason
	var safe: bool = not bridge.EmergencyActive() and (bridge.DoorIsClosed() or not bridge.InterlockActive())
	state_label.text = {"Ready":"Listo","Running":"Ejecutando","Paused":"Pausa","Faulted":"Falla","EmergencyStopped":"Emergencia"}.get(state,state)
	mode_choice.select(1 if bridge.ReadMode() == "Automático" else 0)
	emergency_choice.set_pressed_no_signal(bridge.EmergencyActive())
	gate_choice.set_pressed_no_signal(bridge.DoorIsClosed())
	interlock_choice.set_pressed_no_signal(bridge.InterlockActive())
	sensor_choice.set_pressed_no_signal(bridge.SensorFaultActive())
	var fault: String = bridge.AlarmText()
	alarm_label.visible = not fault.is_empty()
	alarm_row.visible = not fault.is_empty()
	alarm_label.text = "Alarma: "+fault+" · retire causa y restablezca"
	reset_button.visible = not fault.is_empty()
	reset_button.disabled = not safe
	reset_button.tooltip_text = "Retire causa activa" if not safe else "Restablecer no inicia movimiento"
	var ready: bool = safe and state == "Ready" and planning != "Verifying"
	run_button.disabled = not bridge.ActionHint("start").is_empty()
	step_button.disabled = not bridge.ActionHint("step").is_empty()
	verify_button.disabled = not bridge.ActionHint("verify").is_empty()
	pause_button.text = "Reanudar" if state == "Paused" else "Pausa"
	pause_button.disabled = not bridge.ActionHint("pause").is_empty()
	run_button.tooltip_text = bridge.ActionHint("start")
	step_button.tooltip_text = bridge.ActionHint("step")
	verify_button.tooltip_text = bridge.ActionHint("verify")
	permission_label.text = bridge.ActionHint("jog") if tabs.current_tab == 0 else bridge.ActionHint("start")
	permission_label.visible = not permission_label.text.is_empty()
	cancel_plan.visible = planning == "Verifying"
	planning_label.visible = planning in ["Verifying","Failed"]
	planning_label.text = bridge.PlanningActivity()
	status_label.text = bridge.ExecutionContext() if state in ["Running","Paused"] else bridge.ReadStatus()
	if planning == "Cancelled" and status_label.text.begins_with("Verificando"): status_label.text = "Planificación cancelada · nueva acción requerida"
	if Time.get_ticks_msec() < notice_until and state == "Ready" and planning != "Verifying" and bridge.PlanningError().is_empty(): status_label.text = notice
	reference_summary.text = "TCP: %s · Referencia: %s" % [bridge.ActiveTool(),bridge.ActiveFrame()]
	speed_slider.set_value_no_signal(bridge.SpeedPercent())
	var fraction: float = speed_slider.value/100.0
	if bridge.ReadMode() == "Automático": speed_label.text = "Override de programa: %d %%" % speed_slider.value
	elif cartesian: speed_label.text = "Velocidad manual: %.1f %s (%d %%)" % [fraction*(50 if lab.selected_joint < 3 else 15),"mm/s" if lab.selected_joint < 3 else "°/s",speed_slider.value]
	else: speed_label.text = "Velocidad manual: %.1f °/s (%d %%)" % [fraction*30,speed_slider.value]
	var pose = bridge.TcpReadout()
	pose_label.text = "XYZ mm: %.1f  %.1f  %.1f\nRPY °: %.1f  %.1f  %.1f" % [pose[0],pose[1],pose[2],pose[3],pose[4],pose[5]]
	details["Pose y ejes"].find_child("FullPose",true,false).text = pose_label.text+"\nTCP "+bridge.ActiveTool()+" · referencia "+bridge.ActiveFrame()
	pose_label.visible = cartesian
	joint_label.visible = not cartesian
	joint_label.text = "J%d: %.2f ° · límite [%.0f, %.0f] °" % [lab.selected_joint+1,rad_to_deg(bridge.Angle(lab.selected_joint)),rad_to_deg(bridge.LowerLimit(lab.selected_joint)),rad_to_deg(bridge.UpperLimit(lab.selected_joint))]
	var jog_allowed: bool = bridge.ActionHint("jog").is_empty()
	enable_button.disabled = not jog_allowed
	for b in movement_buttons: b.disabled = not jog_allowed
	program_editor.editable = editable
	var dirty: bool = program_choice.selected >= 0 and program_editor.text != bridge.ProgramText(program_choice.get_item_text(program_choice.selected))
	program_choice.disabled = not editable or dirty
	program_choice.tooltip_text = "Aplique el borrador antes de cambiar programa" if dirty else bridge.ActionHint("edit")
	program_name.editable = editable
	draft_label.text = "Borrador pendiente · Verificar aplica cambios" if dirty else ("Aplicado · "+("verificado" if planning == "Ready" else "sin verificación vigente"))
	if sequence_text != program_editor.text:
		error_line = -1
		sequence_text = program_editor.text
		sequence.clear()
		var depth := 0
		for line in sequence_text.split("\n"):
			var op := line.strip_edges().get_slice(" ",0)
			if op in ["ELSE","ENDIF","ENDREPEAT"]: depth = maxi(0,depth-1)
			sequence.add_item("%02d  %s%s" % [sequence.item_count+1,"  ".repeat(depth),line.strip_edges()])
			if op in ["IF","ELSE","REPEAT"]: depth += 1
		selected_line = clampi(selected_line,0,maxi(0,sequence.item_count-1))
		sequence.select(selected_line)
	var edit_id := program_choice.get_item_text(program_choice.selected)
	selection_summary.text = "Editando %s · línea %d" % [edit_id,selected_line+1]
	for i in range(sequence.item_count): sequence.set_item_custom_fg_color(i,Color("d9e5ef"))
	var active: String = bridge.Instruction()
	if active.begins_with(edit_id+":"):
		var line := active.get_slice(" · ",0).get_slice(":",1).to_int()-1
		if line >= 0 and line < sequence.item_count: sequence.set_item_custom_fg_color(line,Color("65f0cb")); selection_summary.text += " · ▶ activa %d" % (line+1)
	var report: String = bridge.ReadStatus()
	if report != last_report:
		last_report = report
		var regex := RegEx.new()
		regex.compile("(?:^|\\s)([A-Za-z0-9_]+):(\\d+):")
		var found := regex.search(report)
		if found != null and found.get_string(1) == edit_id:
			var line := found.get_string(2).to_int()-1
			if line >= 0 and line < sequence.item_count: sequence.set_item_custom_fg_color(line,Color("ffb9a2")); selected_line = line; sequence.select(line)
			if line >= 0 and line < sequence.item_count: error_line = line
	if error_line >= 0 and error_line < sequence.item_count:
		sequence.set_item_custom_fg_color(error_line,Color("ffb9a2"))
		selection_summary.text += " · Error línea %d" % (error_line+1)
	var signals := ""
	for id in ["present","holding","delivered","grip","belt"]: signals += "%s=%d  " % [id,int(bridge.Signal(id))]
	io_label.text = signals
	if details["Diagnóstico"].visible and Time.get_ticks_msec() >= next_diagnostic_update:
		next_diagnostic_update = Time.get_ticks_msec()+250
		var log: String = bridge.EventLog()
		if not bridge.PlanningError().is_empty(): log += "\nDetalle del planificador:\n"+bridge.PlanningError()
		if event_log.text != log: event_log.text = log
	practice_label.text = bridge.PracticeReport()
