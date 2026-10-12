extends Node
# Bounded performance fixture only. It consumes production world/surface/adapters.
func run(lab: Node3D) -> void:
	await get_tree().create_timer(1).timeout
	lab.controller.LoadExample()
	lab.pendant.refresh_all()
	lab.controller.Mode(true)
	lab.controller.Speed(100)
	var before := Time.get_ticks_usec()
	var accepted: bool = lab.controller.Run(false)
	var request_ms := (Time.get_ticks_usec()-before)/1000.0
	var planning_frames: Array[float] = []
	var previous := Time.get_ticks_usec()
	var deadline := previous+20_000_000
	while lab.controller.PlanningStatus() == "Verifying" and Time.get_ticks_usec() < deadline:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		planning_frames.append((now-previous)/1000.0)
		previous = now
	var samples: Array[float] = []
	var started := Time.get_ticks_usec()
	previous = started
	while Time.get_ticks_usec()-started < 30_000_000:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		samples.append((now-previous)/1000.0)
		previous = now
	var elapsed := (Time.get_ticks_usec()-started)/1_000_000.0
	var data := {"mode":"spatial_emulation_not_VR","cpu":OS.get_processor_name(),"gpu":RenderingServer.get_video_adapter_name(),"renderer":"gl_compatibility","release":not OS.is_debug_build(),"request_main_thread_ms":request_ms,"planning_wall_ms":lab.controller.PlanningMilliseconds(),"planning_frames":stats(planning_frames),"duration_seconds":elapsed,"mean_fps":samples.size()/elapsed,"frames":stats(samples),"end_state":lab.controller.ReadState(),"delivered":lab.controller.Signal("delivered"),"alarm":lab.controller.AlarmText(),"conditions":"Production surface and world, emulator, 30s cycle+idle, VSync; not stereo nor VR"}
	var directory := "user://"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--metrics-dir="): directory = arg.trim_prefix("--metrics-dir=")
	var output := FileAccess.open(directory.path_join("spatial-performance.json"),FileAccess.WRITE)
	if output == null: get_tree().quit(1); return
	output.store_string(JSON.stringify(data,"  ")); output.close()
	print("SPATIAL PERFORMANCE ",JSON.stringify(data))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("spatial-release.png"))
	get_tree().quit(0 if accepted and data.delivered and data.end_state == "Ready" else 1)

func stats(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"count":0}
	values.sort()
	return {"count":values.size(),"p50_ms":values[int(values.size()*0.5)],"p95_ms":values[int(values.size()*0.95)],"p99_ms":values[int(values.size()*0.99)],"max_ms":values[-1]}
