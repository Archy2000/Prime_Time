extends SceneTree
var result:Dictionary={}
func _init()->void:call_deferred("run")
func snap(label:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png("res://research/expansion_"+label+".png")

func size_shark(game:Node3D,size:float,level:float)->void:
	game.growth=size;game.water_level=level;game.visual.scale=Vector3.ONE*size
	game.eaten=roundi((size-1.0)/0.065)
	game.player.get_child(0).shape.radius=0.55*size;game.player.get_child(0).position.y=0.4*size
	game.airborne=false;game.jump_cooldown=0;game.player.velocity=Vector3.ZERO

func run()->void:
	change_scene_to_file("res://scenes/main.tscn");await create_timer(0.8).timeout
	var game=current_scene
	result["towers"]=game.tower_district.towers.size();result["boats_and_beacons"]=game.floating_world.floats.size()
	var armed:=0
	for target in game.targets:
		if target.get_meta("tower_guard",false) and target.role=="military":armed+=1
	result["tower_guards"]=armed
	var tower:Dictionary=game.tower_district.towers[0]
	print("TOWER_LAYOUT ",game.tower_district.towers.map(func(t):return [t.position,t.height]))
	var terrain:=PackedStringArray(["road","grass","grass_001","snow","plane_003","plane_005"])
	var missing:=0
	for node in game.city.get_children():
		if not node is MeshInstance3D:continue
		var source:String=node.get_meta("source_mesh","")
		if source in terrain or source.contains("shadow") or source.begins_with("valiviiva"):continue
		if not node in game.destructibles or not game.solids.has(node.get_instance_id()):missing+=1
	result["all_discrete_props_registered"]=missing==0
	# Drop directly onto the center of the new roof; no player input should be required.
	size_shark(game,1.0,1.15);game.player.position=tower.position+Vector3(0,tower.height+2,0)
	game.last_swim_safe=Vector3(0,0.7,-35);game.airborne=true;game.air_age=0;game.roof_escape=false;game.jump_velocity=-3;game.air_drift=Vector3.ZERO;game.leap_target=null
	game.camera_target=game.player.position;game.zoom=85;game._camera_update(1)
	await create_timer(0.65).timeout;await snap("roof_escape")
	await create_timer(3.0).timeout
	result["roof_landing_returns_to_water"]=not game.airborne and game._water_column_clear(game.player.position)
	# High guards cannot be reached by small-shark jump assistance.
	var guard:Node3D=tower.guards[0]
	game.player.position=tower.position+Vector3(-8,game._swim_body_y(game.water_level),0)
	game.visual.rotation.y=-PI/2;game.player.velocity=Vector3.RIGHT*8;game.jump_cooldown=0
	game._jump()
	result["small_cannot_lock_high_guard"]=game.leap_target==null or not game.leap_target.get_meta("tower_guard",false)
	result["small_apex_below_tower"]=game.player.position.y+game.jump_velocity*game.jump_velocity/36<tower.height-1
	game.airborne=false;game.jump_velocity=0;game.air_drift=Vector3.ZERO
	game._break_piece(tower.roof);result["small_cannot_destroy_tower"]=not tower.roof.get_meta("broken",false)
	# Guard fire has a real line of sight from the outer roof edge.
	game.player.position=tower.position+Vector3(-10,game._swim_body_y(game.water_level),0);game.player.velocity=Vector3.ZERO
	game.elapsed=10;var shots:int=game.combat.shots_fired
	await create_timer(2.0).timeout
	result["guards_fire"]=game.combat.shots_fired>shots
	# Growth + higher flood now makes the same roof reachable.
	size_shark(game,3.2,game.BASE_WATER_LEVEL+2.2*game.WATER_PER_GROWTH)
	game.health=100;game.defeated=false
	game.player.position=tower.position+Vector3(-8,game._swim_body_y(game.water_level),0)
	game.visual.rotation.y=-PI/2;game.player.velocity=Vector3.RIGHT*8
	var eaten:int=game.roof_eaten
	game._jump();result["grown_locks_high_guard"]=is_instance_valid(game.leap_target) and game.leap_target.get_meta("tower_guard",false)
	Input.action_press("bite")
	await create_timer(1.0).timeout;await snap("tower_hunt")
	await create_timer(2.3).timeout;Input.action_release("bite")
	result["grown_eats_roof_guard"]=game.roof_eaten>eaten
	# Props, boats and the tower all enter the destruction/stone path.
	game.growth=3.2
	var tested:Array=[]
	for family in ["stylizedconifertree","clumps","tolppawired","wires","verkkoaita"]:
		for node in game.destructibles:
			if family in String(node.get_meta("source_mesh","")):
				game._break_piece(node);tested.append(node.get_meta("broken",false));break
	result["prop_families_destroyed"]=tested.size()==5 and not false in tested
	game._break_piece(game.floating_world.floats[0].node)
	result["boat_destroyed"]=game.floating_world.floats[0].node.get_meta("broken",false)
	game._break_piece(tower.roof)
	result["grown_destroys_tower"]=tower.roof.get_meta("broken",false)
	# Hit an actual facade triangle through the same overlap query used by sprinting.
	var facade:MeshInstance3D=game.buildings[tower.key].parts[0]
	var vertices:PackedVector3Array=facade.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var point:Vector3=facade.global_transform*vertices[0]
	for vertex in vertices:
		var world:Vector3=facade.global_transform*vertex
		if absf(world.y-game.water_level)<absf(point.y-game.water_level):point=world
	game.player.position=point+Vector3.RIGHT*game.growth*0.6
	game.player.position.y=game._swim_body_y(game.water_level)
	for attempt in 3:
		game._ram_nearby(Vector3.LEFT*12);await physics_frame
	result["tower_ram_starts_collapse"]=game.buildings[tower.key].collapsing
	await create_timer(6.0).timeout
	result["tower_fully_collapsed"]=true
	for part in game.buildings[tower.key].parts:
		if part.visible:result.tower_fully_collapsed=false
	game.camera_target=tower.position;game.zoom=80;game._camera_update(1)
	await snap("rubble")
	var stones=game.floating_world.stones
	result["stones_spawned"]=game.floating_world.emitted_stones
	result["stones_bounded"]=stones.size()<=game.floating_world.MAX_STONES
	var afloat:=0
	for stone in stones:
		if stone.floating:afloat+=1
	result["stones_float"]=afloat>10
	game.player.position=Vector3(0,game._swim_body_y(game.water_level),-20);game.camera_target=game.player.position;game.zoom=80;game._camera_update(1)
	await snap("boats")
	# Verify horizontal flow response independently from random live wave phase.
	game.set_physics_process(false);game.floating_world.set_process(false)
	var stone:Dictionary=game.floating_world.stones[-1];stone.p=Vector3(0,game.water_level,-30);stone.floating=true;stone.v=Vector3.ZERO
	var start:Vector3=stone.p
	for i in range(0,game.wave_sim.flow_rgba.size(),4):game.wave_sim.flow_rgba[i]=0.6;game.wave_sim.flow_rgba[i+1]=0.0
	for frame in 60:game.floating_world.update(1.0/60)
	result["stones_follow_flow"]=stone.p.x>start.x+0.1
	result["passed"]=result.towers==4 and result.boats_and_beacons==8 and armed==16
	for key in result:
		if result[key] is bool and not result[key]:result.passed=false
	FileAccess.open("res://research/world_expansion_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("WORLD_EXPANSION ",result);quit(0 if result.passed else 1)
