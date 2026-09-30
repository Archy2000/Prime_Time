extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	change_scene_to_file("res://scenes/main.tscn");await create_timer(0.6).timeout
	var game=current_scene
	game.growth=3.2;game.eaten=34;game.water_level=game._growth_water_target();game.visual.scale=Vector3.ONE*3.2
	game.player.get_child(0).shape.radius=0.55*3.2;game.player.get_child(0).position.y=0.4*3.2
	var heading:Vector3=game.camera.global_basis.x;heading.y=0;heading=heading.normalized()
	var cases:Array=[]
	for f in game.floating_world.floats:
		var mesh:MeshInstance3D=f.node
		var start:=Vector3(0,game._swim_body_y(game.water_level),-35)
		game.player.position=start;game.player.velocity=Vector3.ZERO;game.airborne=false;game.boost_time=0
		mesh.position=start+heading*3.5;mesh.position.y=game.water_level;f.anchor=mesh.position;f.velocity=Vector3.ZERO
		Input.action_press("right")
		await create_timer(0.85).timeout
		Input.action_release("right")
		cases.append({"name":str(mesh.name),"broken":mesh.get_meta("broken",false),"travel":game.player.position.distance_to(start),"boost":game.boost_time})
	# Verify progression and that tiny facade pieces cannot bypass building gates.
	var building:MeshInstance3D=game.tower_district.towers[0].roof
	var structural:bool=is_inf(game._passive_break_growth(building))
	var crate:=MeshInstance3D.new();var cube:=BoxMesh.new();cube.size=Vector3.ONE*4;crate.mesh=cube;game.add_child(crate)
	var crate_threshold:float=game._passive_break_growth(crate)
	var result:Dictionary={"cases":cases,"structures_require_sprint":structural,"large_prop_has_growth_gate":crate_threshold>1.2 and crate_threshold<=3.2,"passed":structural}
	for c in cases:
		if not c.broken or c.travel<3 or c.boost>0:result.passed=false
	result.passed=result.passed and result.large_prop_has_growth_gate
	FileAccess.open("res://research/passive_movement_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("PASSIVE_MOVEMENT ",result);quit(0 if result.passed else 1)
