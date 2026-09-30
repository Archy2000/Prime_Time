extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	change_scene_to_file("res://scenes/main.tscn");await create_timer(0.5).timeout
	var game=current_scene
	for body in game.solids.values():body.collision_layer=0
	var heading:Vector3=game.camera.global_basis.x;heading.y=0;heading=heading.normalized()
	var tangent:=Vector3(-heading.z,0,heading.x)
	var start:=Vector3(0,game._swim_body_y(game.water_level),-35)
	var wall:=StaticBody3D.new();game.add_child(wall)
	wall.position=start+heading*4;wall.position.y=3
	wall.basis=Basis.looking_at(heading,Vector3.UP)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(80,8,0.4);shape.shape=box;wall.add_child(shape)
	game.player.position=start;game.player.velocity=Vector3.ZERO;game.airborne=false
	Input.action_press("right");await create_timer(2.0).timeout;Input.action_release("right")
	var delta:Vector3=game.player.position-start
	var side:float=absf(delta.dot(tangent))
	var before:Vector3=game.player.position
	Input.action_press("left");await create_timer(0.6).timeout;Input.action_release("left")
	var reverse:float=(game.player.position-before).dot(-heading)
	var result:Dictionary={"wall_slide_distance":side,"did_not_cross_wall":delta.dot(heading)<3.8,"reverse_distance":reverse,"passed":side>1 and delta.dot(heading)<3.8 and reverse>2}
	FileAccess.open("res://research/wall_steering_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("WALL_STEERING ",result);quit(0 if result.passed else 1)
