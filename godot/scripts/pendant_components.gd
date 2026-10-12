extends PanelContainer

var lab: Node3D
var bridge: Node
var tabs: TabContainer
var enable_button: Button
var readings: Array[Label] = []
var pose_label: Label
var status_label: Label
var state_label: Label
var axis_choice: OptionButton
var cartesian := false
var point_list: ItemList
var point_name: LineEdit
var point_type: OptionButton
var point_values: Array[SpinBox] = []
var points: Array = []
var tool_choice: OptionButton
var frame_choice: OptionButton
var reference_type: OptionButton
var reference_id: LineEdit
var reference_values: Array[SpinBox] = []
var program_editor: TextEdit
var program_choice: OptionButton
var program_name: LineEdit
var instruction_choice: OptionButton
var instruction_point: OptionButton
var duration: SpinBox
var io_label: Label
var event_log: TextEdit
var practice_label: Label
var file_path: LineEdit
var destination_values: Array[SpinBox] = []
var help_label: Label
var mode_choice: OptionButton
var gate_choice: CheckButton
var emergency_choice: CheckButton
var interlock_choice: CheckButton
var sensor_choice: CheckButton
var help_sections: Array[Control] = []
var planning_label: Label
var cancel_plan: Button

func text(value: String, size := 15) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size",size)
	return l

func wrapped(parent: Node, value: String) -> Label:
	var l := text(value,14)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l

func optional_help(parent: Node, value: String) -> Label:
	var l := wrapped(parent,value)
	help_sections.append(l)
	return l

func button(parent: Node, caption: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func field(parent: Node, value: String) -> LineEdit:
	var edit := LineEdit.new()
	edit.text = value
	parent.add_child(edit)
	return edit

func numeric_fields(parent: Node, captions: Array, values: Array[SpinBox], limit := 5000.0) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	parent.add_child(grid)
	for caption in captions:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(box)
		box.add_child(text(caption,13))
		var spin := SpinBox.new()
		spin.min_value = -limit
		spin.max_value = limit
		spin.step = 0.1
		spin.custom_minimum_size.x = 132
		box.add_child(spin)
		values.append(spin)

func numbers(fields: Array[SpinBox]) -> PackedFloat64Array:
	var values := PackedFloat64Array()
	for spin in fields: values.append(spin.value)
	return values

func fill(fields: Array[SpinBox], values) -> void:
	for i in range(mini(fields.size(),values.size())): fields[i].value = values[i]

func populate_axes() -> void:
	axis_choice.clear()
	for caption in (["X","Y","Z","Rx","Ry","Rz"] if cartesian else ["J1 · Base","J2 · Hombro","J3 · Codo","J4 · Muñeca","J5 · Inclinación","J6 · Brida"]): axis_choice.add_item(caption)
	lab.selected_joint = 0

func start_jog(sense: int) -> void:
	lab.jog_held = bridge.CartJog(lab.selected_joint,sense) if cartesian else bridge.Jog(lab.selected_joint,sense)

func build_references(parent: VBoxContainer) -> void:
	optional_help(parent,"Pose expresada en el frame activo. Orientación RPY: Rz(yaw) × Ry(pitch) × Rx(roll). mm y grados; ejes del núcleo Z arriba.")
	tool_choice = OptionButton.new()
	frame_choice = OptionButton.new()
	parent.add_child(tool_choice)
	parent.add_child(frame_choice)
	button(parent,"Seleccionar TCP y frame",func(): bridge.SelectReference(tool_choice.get_item_text(tool_choice.selected),frame_choice.get_item_text(frame_choice.selected)))
	reference_type = OptionButton.new()
	reference_type.add_item("Editar/crear TCP respecto a brida")
	reference_type.add_item("Editar/crear frame respecto a base")
	reference_type.item_selected.connect(func(index):
		reference_id.text = "tool" if index == 0 else "piece"
		fill(reference_values,bridge.ReferenceValues(index == 0,reference_id.text)))
	parent.add_child(reference_type)
	reference_id = field(parent,"tool")
	button(parent,"Leer referencia por ID",func():
		var ids = bridge.ToolIds() if reference_type.selected == 0 else bridge.FrameIds()
		if reference_id.text in ids: fill(reference_values,bridge.ReferenceValues(reference_type.selected == 0,reference_id.text)))
	numeric_fields(parent,["X mm","Y mm","Z mm","Roll °","Pitch °","Yaw °"],reference_values)
	button(parent,"Aplicar referencia (no mueve robot)",func(): bridge.EditReference(reference_type.selected == 0,reference_id.text,numbers(reference_values)); refresh_references())
	optional_help(parent,"La brida está en el origen J6. TCP inicial: +120 mm X de brida. Una referencia usada por puntos no se modifica: cree otro ID o reenseñe puntos. La base es fija.")

func refresh_references() -> void:
	tool_choice.clear()
	frame_choice.clear()
	for id in bridge.ToolIds(): tool_choice.add_item(id)
	for id in bridge.FrameIds(): frame_choice.add_item(id)
	for i in range(tool_choice.item_count):
		if tool_choice.get_item_text(i) == bridge.ActiveTool(): tool_choice.select(i)
	for i in range(frame_choice.item_count):
		if frame_choice.get_item_text(i) == bridge.ActiveFrame(): frame_choice.select(i)
	var ids = bridge.ToolIds() if reference_type.selected == 0 else bridge.FrameIds()
	if reference_id.text in ids: fill(reference_values,bridge.ReferenceValues(reference_type.selected == 0,reference_id.text))

func refresh_points() -> void:
	var selected_id := ""
	var selected = point_list.get_selected_items()
	if selected.size() and selected[0] < points.size(): selected_id = points[selected[0]].Id
	points = JSON.parse_string(bridge.PointsJson())
	point_list.clear()
	instruction_point.clear()
	help_label.text = "Seleccione un punto para editar; enseñar crea un punto nuevo."
	for p in points:
		point_list.add_item(p.Name + " · " + ("Articular" if p.Kind == "Joint" else "Cartesiano"))
		instruction_point.add_item(p.Name)
	for i in range(points.size()):
		if points[i].Id == selected_id:
			point_list.select(i)
			select_point(i)

func select_point(index: int) -> void:
	var p = points[index]
	point_name.text = p.Name
	point_type.select(0 if p.Kind == "Joint" else 1)
	fill(point_values,p.Values)
	help_label.text = "%s\nTCP: %s · Frame: %s\nValores: %s" % [p.Id,p.ToolId,p.FrameId,"grados articulares" if p.Kind == "Joint" else "XYZ mm · RPY grados"]

func refresh_programs(selected := "main") -> void:
	program_choice.clear()
	for id in bridge.ProgramIds(): program_choice.add_item(id)
	for i in range(program_choice.item_count):
		if program_choice.get_item_text(i) == selected: program_choice.select(i)
	program_name.text = selected
	program_editor.text = bridge.ProgramText(selected)

func apply_draft() -> bool:
	return bridge.EditProgram(program_choice.get_item_text(program_choice.selected),program_editor.text)

func invalidate_draft() -> void:
	if program_choice.selected >= 0 and program_editor.text != bridge.ProgramText(program_choice.get_item_text(program_choice.selected)) and bridge.PlanningStatus() in ["Verifying","Ready"] and not bridge.ReadState() in ["Running","Paused"]:
		bridge.CancelVerification()

func run_program(single_step: bool) -> void:
	if bridge.ReadState() == "Paused": bridge.Run(single_step)
	elif apply_draft(): bridge.Run(single_step)

func edit_line(direction: int) -> void:
	var lines := program_editor.text.split("\n")
	var index := program_editor.get_caret_line()
	if direction == 0: lines.remove_at(index)
	elif index + direction >= 0 and index + direction < lines.size():
		var saved := lines[index]
		lines[index] = lines[index + direction]
		lines[index + direction] = saved
	program_editor.text = "\n".join(lines)
	program_editor.set_caret_line(clampi(index + direction,0,maxi(0,lines.size()-1)))

func build_cell(parent: VBoxContainer) -> void:
	io_label = wrapped(parent,"")
	var gate := CheckButton.new()
	gate_choice = gate
	gate.text = "Puerta cerrada"
	gate.button_pressed = true
	gate.toggled.connect(func(value): bridge.Door(value))
	parent.add_child(gate)
	var emergency := CheckButton.new()
	emergency_choice = emergency
	emergency.text = "Paro de emergencia virtual"
	emergency.toggled.connect(func(value): bridge.Emergency(value))
	parent.add_child(emergency)
	var interlock := CheckButton.new()
	interlock_choice = interlock
	interlock.text = "Enclavamiento activo (retirar = práctica de riesgo)"
	interlock.button_pressed = true
	interlock.toggled.connect(func(value): if not bridge.Interlock(value): interlock.set_pressed_no_signal(not value))
	parent.add_child(interlock)
	var sensor := CheckButton.new()
	sensor_choice = sensor
	sensor.text = "Introducir falla de sensor de presencia"
	sensor.toggled.connect(func(value): bridge.SensorFault(value))
	parent.add_child(sensor)
	var row := HBoxContainer.new()
	parent.add_child(row)
	button(row,"Sin pieza",func(): bridge.RemovePart())
	button(row,"Reponer celda",func(): bridge.ResetCell())
	button(row,"Cerrar pinza",func(): bridge.Output("grip",true))
	button(row,"Abrir",func(): bridge.Output("grip",false))
	var belt_row := HBoxContainer.new()
	parent.add_child(belt_row)
	button(belt_row,"Banda ON",func(): bridge.Output("belt",true))
	button(belt_row,"Banda OFF",func(): bridge.Output("belt",false))
	wrapped(parent,"Destino físico XYZ en base (mm); cambie también el punto de entrega para una solución correcta.")
	numeric_fields(parent,["X mm","Y mm","Z mm"],destination_values)
	button(parent,"Cambiar estación destino",func(): bridge.EditDestination(numbers(destination_values)))
	event_log = TextEdit.new()
	event_log.editable = false
	event_log.custom_minimum_size.y = 150
	event_log.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	parent.add_child(event_log)
	wrapped(parent,"Seguridad educativa: paro instantáneo, sin distancia de frenado ni certificación. Agarre: proximidad/orientación, sin fuerzas. Colisiones por volúmenes aproximados; no malla exacta.")

func build_practice(parent: VBoxContainer) -> void:
	practice_label = wrapped(parent,"Libre: configure, enseñe puntos y escriba main.\n\nGuía de preparación y recuperación disponible al cargar el ejemplo. No hay validación docente ni VR en esta demo.")
	button(parent,"Cargar ejemplo editable",func(): if bridge.LoadExample(): refresh_all())
	button(parent,"Iniciar práctica guiada (nueva evidencia)",func(): if bridge.PracticeMode(true): practice_label.text = bridge.PracticeReport())
	button(parent,"Modo libre",func(): if bridge.PracticeMode(false): practice_label.text = bridge.PracticeReport())
	button(parent,"Programa vacío",func(): if bridge.EditProgram("main",""): refresh_programs())
	button(parent,"Evaluar hechos observables",func(): practice_label.text = bridge.PracticeReport())
	optional_help(parent,"1. Preparar TCP tool y frame base.\n2. Leer/enseñar puntos; comprobar XYZ/RPY.\n3. Revisar programa y verificar trayectos.\n4. Automático + Paso; luego Iniciar.\n5. Observar present/holding/delivered.\n6. Abrir puerta o fallar sensor; leer alarma.\n7. Retirar causa, Reset, verificar e iniciar aparte.\n8. Guardar/cargar sin rearranque.\n9. Cambiar destino y reenseñar el punto correspondiente.")

func refresh_all() -> void:
	refresh_references()
	refresh_points()
	refresh_programs()
	var destination: Vector3 = bridge.DestinationPosition()
	fill(destination_values,[destination.x*1000,-destination.z*1000,destination.y*1000])
