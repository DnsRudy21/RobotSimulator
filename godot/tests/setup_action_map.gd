extends SceneTree
# Reproducible development resource authoring; not used by application runtime.
func _initialize() -> void:
	var map := OpenXRActionMap.new()
	var set := OpenXRActionSet.new()
	set.resource_name = "robot"
	set.localized_name = "RobotSimulator"
	var actions := {}
	for entry in [["enable",0],["select",0],["stop",0],["scroll",2],["grip",3],["aim",3]]:
		var action := OpenXRAction.new()
		action.resource_name = entry[0]
		action.localized_name = entry[0]
		action.action_type = entry[1]
		action.toplevel_paths = PackedStringArray(["/user/hand/left","/user/hand/right"]) if entry[0] in ["aim","grip"] else PackedStringArray(["/user/hand/left" if entry[0] == "enable" else "/user/hand/right"])
		set.add_action(action)
		actions[entry[0]] = action
	map.add_action_set(set)
	for profile_path in ["/interaction_profiles/khr/simple_controller","/interaction_profiles/oculus/touch_controller"]:
		var profile := OpenXRInteractionProfile.new()
		profile.interaction_profile_path = profile_path
		var resources: Array[OpenXRIPBinding] = []
		var simple: bool = profile_path.contains("simple")
		var bindings := {"enable":"/user/hand/left/input/select/click" if simple else "/user/hand/left/input/squeeze/value","select":"/user/hand/right/input/select/click" if simple else "/user/hand/right/input/trigger/value","stop":"/user/hand/right/input/menu/click" if simple else "/user/hand/right/input/a/click"}
		if not simple: bindings["scroll"] = "/user/hand/right/input/thumbstick"
		for name in bindings:
			var binding := OpenXRIPBinding.new()
			binding.action = actions[name]
			binding.binding_path = bindings[name]
			resources.append(binding)
		for hand in ["left","right"]:
			for pose in ["aim","grip"]:
				var binding := OpenXRIPBinding.new()
				binding.action = actions[pose]
				binding.binding_path = "/user/hand/%s/input/%s/pose" % [hand,pose]
				resources.append(binding)
		profile.bindings = resources
		map.add_interaction_profile(profile)
	var result := ResourceSaver.save(map,"res://robot_action_map.tres")
	print("ACTION MAP ",result)
	quit(0 if result == OK else 1)
