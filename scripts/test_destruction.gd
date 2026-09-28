extends SceneTree
var checks:Dictionary={}
func _init()->void:call_deferred("run")

func snap(name:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://research/v6_"+name+".png")

func area(mesh:Mesh)->float:
	var total:=0.0
	for s in mesh.get_surface_count():
		var a:=mesh.surface_get_arrays(s);var v:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ix:PackedInt32Array=a[Mesh.ARRAY_INDEX] if a[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if ix.is_empty():
			for i in v.size():ix.append(i)
		for i in range(0,ix.size(),3):total+=(v[ix[i+1]]-v[ix[i]]).cross(v[ix[i+2]]-v[ix[i]]).length()*0.5
	return total

func run()->void:
	change_scene_to_file("res://scenes/main.tscn");await create_timer(0.7).timeout
	var game=current_scene;var fx=game.fx
	game.zoom=80
	# An actual bite and movement input produce the trail, including a turn.
	game.targets[0].position=game.player.position+Vector3(0,0,-0.8);game._bite()
	await create_timer(0.55).timeout
	checks["meal_started_blood"]=fx.blood_left>0 and fx.swallow_count>0
	Input.action_press("back");await create_timer(0.9).timeout
	Input.action_release("back");Input.action_press("left");await create_timer(0.8).timeout
	Input.action_release("left");await create_timer(0.4).timeout
	checks["trail_stamps"]=fx.blood_stamps
	await snap("blood_trail")
	# Once droplets settle, a stationary player must not continuously pile up decals.
	await create_timer(0.8).timeout
	var stationary_count:int=fx.blood_stamps
	await create_timer(0.35).timeout
	checks["stationary_no_stamp_spam"]=fx.blood_stamps==stationary_count
	var selected:MeshInstance3D;var nearest:=INF
	for m:MeshInstance3D in game.destructibles:
		if not game.node_building.has(m.get_instance_id()):continue
		var box:AABB=m.global_transform*m.mesh.get_aabb()
		var distance:float=box.get_center().distance_to(game.player.position)
		if box.position.y<game.water_level and box.end.y>game.water_level+1 and distance<nearest:selected=m;nearest=distance
	checks["found_building"]=selected!=null
	if selected==null:quit(1);return
	game.growth=1;game._break_piece(selected)
	checks["growth_gate"]=not selected.get_meta("broken",false)
	var bounds:AABB=selected.global_transform*selected.mesh.get_aabb()
	game.camera_target=bounds.get_center();game.player.position=Vector3(bounds.get_center().x+4,game.water_level-0.52,bounds.get_center().z-4);game._camera_update(1)
	game.growth=game.BUILDING_GROWTH
	var started:=Time.get_ticks_usec();game._break_piece(selected)
	checks["first_fracture_ms"]=(Time.get_ticks_usec()-started)/1000.0
	checks["collision_removed"]=not game.solids.has(selected.get_instance_id()) or game.solids[selected.get_instance_id()].collision_layer==0
	var pieces:Array=fx.fracture_cache[selected.mesh.get_instance_id()]
	var sum:=0.0
	for mesh:Mesh in pieces:sum+=area(mesh)
	checks["source_surface_preserved"]=absf(sum-area(selected.mesh))/maxf(0.001,area(selected.mesh))<0.01
	checks["multiple_original_chunks"]=pieces.size()>1
	game.paused=true;paused=true
	var count:int=game.wrecked
	await create_timer(0.3,true).timeout
	checks["collapse_pauses"]=game.wrecked==count
	paused=false;game.paused=false
	await create_timer(0.3).timeout;await snap("fracture")
	await create_timer(1.8).timeout;await snap("rubble")
	checks["chain_collapse"]=game.wrecked>1
	checks["spawned_chunks"]=fx.chunks_released
	checks["bounded_fragments"]=fx.fragments.size()<=fx.MAX_FRAGMENTS
	# A surviving roof receives a surface stain instead of a stain below it.
	for target:Node3D in game.targets:
		if not target.get_meta("rooftop",false):continue
		var support:MeshInstance3D=target.get_meta("roof_support")
		if support.get_meta("broken",false):continue
		fx._stamp_blood(target.position+Vector3.UP*0.2,0.6,0.0)
		checks["roof_stain"]=not fx.splats[-1].water and absf(fx.splats[-1].node.position.y-target.position.y)<0.2
		break
	checks["stains_persist"]=not fx.splats.is_empty() and fx.splats[-1].life>=5
	for i in 260:fx._stamp_blood(Vector3(0,game.water_level,-24),0.2,0)
	checks["bounded_stains"]=fx.splats.size()==fx.MAX_SPLATS
	# Expiration must free transient references, including offscreen effects.
	fx.blood_left=0;fx.update(100)
	checks["stains_expire"]=fx.splats.is_empty()
	checks["passed"]=true
	for key in checks:
		if checks[key] is bool and not checks[key]:checks.passed=false
	FileAccess.open("res://research/v6_effects_tests.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("EFFECTS_TEST ",checks);quit(0 if checks.passed else 1)
