extends Node
# Device-neutral pointer. A held press cannot transfer to another target.
var surface: Node3D
var bridge: Node
var position := Vector2(-1,-1)
var pressed := false
var blocked := false
var capture := Vector2.ZERO
var world_controls: Array[Node3D] = []
var world_target: Node3D
var world_capture: Node3D
var reticle: ColorRect
var scroll_position := Vector2(-1,-1)

func setup(target: Node3D, controller: Node) -> void:
	surface = target
	bridge = controller
	reticle = ColorRect.new()
	reticle.color = Color("43dac5")
	reticle.size = Vector2(8,8)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.viewport.get_child(0).add_child(reticle)

func aim(origin: Vector3, direction: Vector3) -> void:
	var next: Vector2 = surface.ray_uv(origin,direction)
	world_target = null
	if next.x < 0:
		for control in world_controls:
			if control.ray_hit(origin,direction): world_target = control; break
	if world_capture != null and world_target != world_capture: world_capture = null; blocked = true; bridge.CancelInput()
	# Cancel when leaving the surface or dragging far enough to cross a control.
	if pressed and (next.x < 0 or next.distance_to(capture) > 18): cancel(); blocked = true
	position = next
	if next.y > 100: scroll_position = next
	reticle.visible = position.x >= 0
	reticle.position = position-Vector2(4,4)
	if position.x >= 0:
		var event := InputEventMouseMotion.new()
		event.position = position
		event.global_position = position
		surface.viewport.push_input(event,true)

func select(value: bool) -> void:
	if not value:
		if world_capture != null and world_capture == world_target and (bridge.InputAvailable() or world_capture.priority): world_capture.command.call()
		world_capture = null
		if pressed: send_button(false)
		pressed = false
		blocked = false
		bridge.StopJog()
		return
	if blocked or pressed: return
	if not bridge.InputAvailable() and not priority_target(): return
	if world_target != null: world_capture = world_target; return
	if position.x < 0: return
	pressed = true
	capture = position
	send_button(true)

func priority_target() -> bool:
	if world_target != null: return world_target.priority
	var pendant = surface.pendant
	if pendant.emergency_choice.get_global_rect().has_point(position): return true
	for b in surface.viewport.find_children("*","Button",true,false):
		if b.text in ["Detener","Paro de celda"] and b.is_visible_in_tree() and b.get_global_rect().has_point(position): return true
	return false

func send_button(value: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = value
	event.position = capture if not value else position
	event.global_position = event.position
	surface.viewport.push_input(event,true)

func cancel() -> void:
	world_capture = null
	if pressed:
		var saved := capture
		capture = Vector2(-10,-10) # Cancel does not activate the captured click target.
		send_button(false)
		capture = saved
	pressed = false
	bridge.CancelInput()

func scroll(direction: int) -> void:
	var target := scroll_position if position.y < 100 else position
	if target.x < 0: return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_UP if direction < 0 else MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.position = target
	event.global_position = target
	surface.viewport.push_input(event,true)
	event.pressed = false
	surface.viewport.push_input(event,true)
