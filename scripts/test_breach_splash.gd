extends SceneTree
var results:Dictionary={}
func _init()->void:call_deferred("run")

func capture(label:String)->void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://research/v8_"+label+".png")

func run()->void:
	change_scene_to_file("res://scenes/main.tscn");await create_timer(0.8).timeout
	var game=current_scene;var water_fx=game.water_fx
	for target:Node3D in game.targets:target.position=Vector3(-55,game.water_level,-70)
	var cases:Array=[]
	for size in [1.0,3.2]:
		game.growth=size;game.visual.scale=Vector3.ONE*size
		game.player.get_child(0).shape.radius=0.55*size;game.player.get_child(0).position.y=0.4*size
		game.player.position=Vector3(0,game.water_level-0.52*size,-35);game.player.velocity=Vector3.ZERO;game.visual.rotation=Vector3.ZERO
		game.camera_target=game.player.position;game.zoom=80-(size-1)*22;game._camera_update(1)
		game.jump_cooldown=0
		var count:int=water_fx.breach_count
		var impulses:int=game.wave_sim.total_impulses
		game._jump();game.leap_target=null;game.air_drift=Vector3.ZERO
		var takeoff:Dictionary=water_fx.last_breach.duplicate()
		await create_timer(0.18).timeout
		var visual_airborne:bool=game.visual.global_position.y>game.water_level
		await capture("takeoff_"+str(size))
		var landed:=false
		for frame in 360:
			await physics_frame
			if not game.airborne:landed=true;break
		var landing:Dictionary=water_fx.last_breach.duplicate()
		await create_timer(0.20).timeout
		await capture("landing_"+str(size))
		var item:={"size":size,"takeoff":takeoff,"landing":landing,"landed":landed,"exactly_two_events":water_fx.breach_count==count+2,"solver_impulses":game.wave_sim.total_impulses-impulses,"bounded_droplets":water_fx.droplets.size()<=water_fx.MAX_DROPS}
		item["visual_leaves_water"]=visual_airborne
		item["visual_returns_underwater"]=game.visual.global_position.y<game.water_level
		item["passed"]=landed and item.exactly_two_events and not takeoff.landing and landing.landing and item.solver_impulses>=26 and item.bounded_droplets and visual_airborne and item.visual_returns_underwater
		cases.append(item)
		await create_timer(0.4).timeout;await capture("waves_"+str(size))
		game.paused=true;paused=true
		var before:float=water_fx.clock
		await create_timer(0.2,true).timeout
		results["pause_freezes_effects"]=is_equal_approx(before,water_fx.clock)
		paused=false;game.paused=false
		await create_timer(3.0).timeout
	results["cases"]=cases
	results["growth_increases_radius"]=cases[1].landing.radius>cases[0].landing.radius*3
	results["growth_increases_wave"]=cases[1].landing.amplitude>cases[0].landing.amplitude
	results["growth_increases_spray"]=cases[1].landing.drops>cases[0].landing.drops
	results["crown_cleans_up"]=water_fx.breaches.is_empty()
	results["wave_finite"]=is_finite(game.wave_sim.energy())
	results["passed"]=cases[0].passed and cases[1].passed
	for key in results:
		if results[key] is bool and not results[key]:results.passed=false
	FileAccess.open("res://research/v8_breach_tests.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("BREACH_TEST ",results);quit(0 if results.passed else 1)
