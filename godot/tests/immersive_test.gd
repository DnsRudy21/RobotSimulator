extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	ProjectSettings.set_setting("application/config/projects_directory","user://test-projects-%d" % Time.get_ticks_usec())
	var lab = load("res://scripts/spatial_lab.gd").new()
	root.add_child(lab)
	var suite = load("res://tests/spatial_scenario.gd").new()
	root.add_child(suite)
	await suite.run(lab)
	quit(0 if suite.failures == 0 else 1)
