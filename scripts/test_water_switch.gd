extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.0).timeout
	change_scene_to_file("res://scenes/water_lab.tscn")
	await create_timer(2.0).timeout
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.0).timeout
	print("WATER_SWITCH_TEST passed=",current_scene.ready_done)
	quit()
