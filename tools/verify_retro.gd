extends SceneTree
var game: Node

func _initialize() -> void:
	call_deferred("run")

func capture(path: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	result.save_png(path)
	return result

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await create_timer(2.0).timeout
	game.paused = true
	paused = true
	var filter = game.retro_filter
	for spec in filter.PARAMETERS: filter.set_value(spec[0], spec[5])
	filter.set_enabled(false)
	var clean := await capture("res://research/v6_filter_off.png")
	filter.set_enabled(true)
	var graded := await capture("res://research/v6_filter_on.png")
	filter.toggle_panel()
	filter.sliders["contrast"].value = 1.4
	var controls_work: bool = is_equal_approx(filter.material.get_shader_parameter("contrast"), 1.4)
	filter.sliders["contrast"].value = 1.32
	await capture("res://research/v6_filter_panel.png")
	# Compare the same frozen scene, excluding the HUD.
	var difference := 0.0
	for y in range(210, 620, 4):
		for x in range(20, 850, 4):
			var a := clean.get_pixel(x,y)
			var b := graded.get_pixel(x,y)
			difference += absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b)
	var report := {"scene_difference": difference, "slider_updates_shader": controls_work,
		"panel_visible": filter.panel.visible, "passed": difference > 1.0 and controls_work and filter.panel.visible}
	FileAccess.open("res://research/v6_filter_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FILTER_TEST ", report)
	quit(0 if report.passed else 1)
