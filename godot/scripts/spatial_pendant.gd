extends "res://scripts/pendant_v2.gd"
# Production spatial mounting of the same widgets, model, drafts and bridge commands.
var keyboard: PanelContainer
var keyboard_target: Control
var keyboard_before := ""
var project_name: LineEdit
var project_list: ItemList
var replace_prompt: Button
var overwrite_pending := ""
var source_label: Label
var uppercase := true
var letter_buttons: Array[Button] = []

func button(parent: Node, caption: String, action: Callable) -> Button:
	var result := super.button(parent,caption,action)
	if caption in ["Nuevo proyecto vacío","Guardar / guardar como","Confirmar sustitución","Cargar seleccionado"]:
		result.set_meta("permission","edit")
		guarded_buttons.append(result)
	return result

func setup(scene: Node3D, controller: Node) -> void:
	super.setup(scene,controller)
	for b in find_children("*","Button",true,false):
		if b.text == "Ancho": b.hide() # Surface sizing is metric, not monitor width.
	for label in get_parent().find_children("*","Label",true,false):
		label.text = label.text.replace("Sin VR implementado.","Ruta espacial/OpenXR candidata; validación con visor pendiente.")
	event_log.add_theme_color_override("font_readonly_color",Color("d9e5ef"))
	get_viewport().gui_embed_subwindows = true
	source_label = Label.new()
	source_label.position = Vector2(10,32)
	get_parent().add_child(source_label)
	build_keyboard()
	get_viewport().gui_focus_changed.connect(func(control):
		if control is LineEdit or control is TextEdit:
			if control.editable and not keyboard.is_ancestor_of(control): open_keyboard(control))
	enable_button.text = "Habilitación: control izquierdo"
	enable_button.disabled = true
	output_enable.text = "Habilitación: control izquierdo"
	output_enable.disabled = true
	# Scroll via the same production pointer, no physical mouse required.
	var scroll_row := HBoxContainer.new()
	scroll_row.position = Vector2(600,5)
	get_parent().add_child(scroll_row)
	button(scroll_row,"Desplazar ↑",func(): lab.surface.pointer.scroll(-1))
	button(scroll_row,"Desplazar ↓",func(): lab.surface.pointer.scroll(1))

func cancel_input() -> void:
	super.cancel_input()
	bridge.CancelInput()
	if keyboard != null: keyboard.hide(); keyboard_target = null

func start_jog(sense: int) -> void:
	if keyboard.visible or tabs.current_tab != 0: cancel_input(); return
	for popup in details.values():
		if popup.visible: cancel_input(); return
	lab.jog_held = bridge.CartJog(lab.selected_joint,sense) if cartesian else bridge.Jog(lab.selected_joint,sense)

func mouse_enabled() -> bool:
	return bridge.InputHeld()

func build_files(parent: VBoxContainer) -> void:
	wrapped(parent,"PROYECTOS LOCALES · no necesita rutas ni monitor")
	project_name = field(parent,"Mi práctica")
	project_list = ItemList.new()
	project_list.custom_minimum_size.y = 130
	parent.add_child(project_list)
	project_list.item_selected.connect(func(index): project_name.text = project_list.get_item_text(index))
	button(parent,"Nuevo proyecto vacío",func(): cancel_input(); if bridge.NewProject(): refresh_all(); refresh_repository())
	button(parent,"Guardar / guardar como",save_named)
	replace_prompt = button(parent,"Confirmar sustitución",func():
		if overwrite_pending != project_name.text: overwrite_pending = ""; replace_prompt.hide(); return
		if apply_draft() and bridge.SaveNamedProject(overwrite_pending,true): refresh_repository(); announce("Proyecto guardado")
		overwrite_pending = ""; replace_prompt.hide())
	replace_prompt.hide()
	button(parent,"Cancelar sustitución",func(): overwrite_pending = ""; replace_prompt.hide())
	button(parent,"Cargar seleccionado",func(): cancel_input(); if bridge.LoadNamedProject(project_name.text): refresh_all(); announce("Proyecto cargado detenido"))
	wrapped(parent,"Nombres: letras/números/espacios/guion. Guardar valida el mismo JSON; cargar conserva pose y alarma. Archivos antiguos siguen disponibles por la ruta administrativa del escritorio.")
	refresh_repository()

func refresh_repository() -> void:
	project_list.clear()
	for name in bridge.ProjectNames(): project_list.add_item(name)

func save_named() -> void:
	cancel_input()
	if not apply_draft(): return
	if bridge.ProjectExists(project_name.text):
		overwrite_pending = project_name.text
		replace_prompt.text = "Sustituir «%s»" % overwrite_pending
		replace_prompt.show()
	elif bridge.SaveNamedProject(project_name.text,false): refresh_repository(); announce("Proyecto guardado")

func build_keyboard() -> void:
	keyboard = PanelContainer.new()
	keyboard.position = Vector2(10,530)
	keyboard.size = Vector2(760,430)
	keyboard.hide()
	get_parent().add_child(keyboard)
	var column := VBoxContainer.new()
	keyboard.add_child(column)
	wrapped(column,"TECLADO VIRTUAL · edición en el campo enfocado · habilitación cancelada")
	for keys in ["1234567890", "QWERTYUIOP", "ASDFGHJKLÑ", "ZXCVBNM", "áéíóúü_.,-+():/=#"]:
		var line := HBoxContainer.new()
		column.add_child(line)
		for key in keys:
			var b := Button.new()
			b.text = key
			b.custom_minimum_size = Vector2(38,42)
			b.focus_mode = Control.FOCUS_NONE
			b.pressed.connect(func(): type_text(b.text))
			if key.to_lower() != key.to_upper(): letter_buttons.append(b)
			line.add_child(b)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	for pair in [["Espacio"," "],["Nueva línea","\n"]]:
		var b := button(actions,pair[0],func(): type_text(pair[1]))
		b.focus_mode = Control.FOCUS_NONE
	for pair in [["←",KEY_LEFT],["→",KEY_RIGHT],["↑",KEY_UP],["↓",KEY_DOWN],["Inicio",KEY_HOME],["Fin",KEY_END],["Borrar",KEY_BACKSPACE],["Suprimir",KEY_DELETE]]:
		var b := button(actions,pair[0],func(): edit_key(pair[1]))
		b.focus_mode = Control.FOCUS_NONE
	var footer := HBoxContainer.new()
	column.add_child(footer)
	var shift := button(footer,"Mayús / minús",func():
		uppercase = not uppercase
		for b in letter_buttons: b.text = b.text.to_upper() if uppercase else b.text.to_lower())
	shift.focus_mode = Control.FOCUS_NONE
	for pair in [["Seleccionar todo",0],["Confirmar",1],["Cancelar edición",2]]:
		var b := button(footer,pair[0],func(): keyboard_action(pair[1]))
		b.focus_mode = Control.FOCUS_NONE

func open_keyboard(target: Control) -> void:
	if keyboard_target == target and keyboard.visible: return
	cancel_input()
	keyboard_target = target
	keyboard_before = target.text
	keyboard.show()
	for popup in details.values():
		if popup.visible: popup.size.y = 470

func type_text(value: String) -> void:
	if not is_instance_valid(keyboard_target): return
	keyboard_target.grab_focus()
	if keyboard_target is LineEdit:
		if keyboard_target.has_selection():
			var from: int = keyboard_target.get_selection_from_column()
			var to: int = keyboard_target.get_selection_to_column()
			keyboard_target.deselect()
			keyboard_target.delete_text(from,to)
		keyboard_target.insert_text_at_caret(value.replace("\n",""))
		keyboard_target.text_changed.emit(keyboard_target.text)
	else: keyboard_target.insert_text_at_caret(value)

func edit_key(code: int) -> void:
	if not is_instance_valid(keyboard_target): return
	keyboard_target.grab_focus()
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	get_viewport().push_input(event,true)
	event.pressed = false
	get_viewport().push_input(event,true)

func keyboard_action(action: int) -> void:
	if not is_instance_valid(keyboard_target): return
	if action == 0: keyboard_target.select_all(); return
	if action == 2: keyboard_target.text = keyboard_before
	if keyboard_target is LineEdit:
		keyboard_target.text_changed.emit(keyboard_target.text)
		keyboard_target.text_submitted.emit(keyboard_target.text)
	keyboard.hide()
	get_viewport().gui_release_focus()
	keyboard_target = null
	cancel_input()
	for popup in details.values():
		if popup.visible: popup.size.y = get_viewport_rect().size.y-60

func show_detail(title: String) -> void:
	if keyboard != null: keyboard.hide(); keyboard_target = null
	super.show_detail(title)

func _process(delta: float) -> void:
	super._process(delta)
	expanded = false
	enable_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	output_enable.mouse_filter = Control.MOUSE_FILTER_IGNORE
	source_label.text = "Fuente: %s · %s" % [bridge.InputSource(),"disponible" if bridge.InputAvailable() else "sin disponibilidad · movimiento bloqueado"]
