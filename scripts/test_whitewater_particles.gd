extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
	var parent:=Node3D.new();root.add_child(parent)
	var sim=load("res://scripts/water_hydro.gd").new()
	var foam=load("res://scripts/whitewater_particles.gd").new();parent.add_child(foam);foam.setup(sim,1.15)
	for frame in 10:
		foam.emit_swimmer(1,Vector3(frame*0.04,1.15,0),Vector3(0.4,0,0),0.3)
		foam.update(0.1,1.15)
	var alive:int=foam.particles.size();var local:=true
	for p in foam.particles:local=local and absf(p.p.z)<0.3 and p.p.x>-0.3 and p.p.x<0.8
	foam.update(1.2,1.15)
	var cleared:bool=foam.particles.is_empty()
	foam.emit_swimmer(2,Vector3.ZERO,Vector3.ZERO,0.3)
	var stationary:bool=foam.particles.is_empty()
	for i in foam.CAPACITY+20:foam._spawn(Vector3.ZERO,0.5,1,Vector2.ZERO)
	var capped:bool=foam.particles.size()==foam.CAPACITY
	foam.update(3.0,1.8)
	var results:={"moving_npc_particles":alive,"local_footprint":local,"stopped_clears":cleared,"stationary_no_emission":stationary,"capacity_bounded":capped,"cleared_after_lifetime":foam.particles.is_empty(),"water_level_sync":is_equal_approx(foam.material.get_shader_parameter("water_y"),1.8)}
	results["passed"]=alive>0 and local and cleared and stationary and capped and results.cleared_after_lifetime and results.water_level_sync
	FileAccess.open("res://research/v12_particles_tests.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("WHITEWATER_PARTICLES ",results);quit(0 if results.passed else 1)
