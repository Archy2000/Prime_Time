extends SceneTree
func _init()->void:call_deferred("run")

func run()->void:
	var parent:=Node3D.new();root.add_child(parent)
	var sim=load("res://scripts/water_hydro.gd").new()
	var fx=load("res://scripts/wake_fx.gd").new();parent.add_child(fx);fx.setup(sim,1.15);fx.set_process(false)
	# Slow human swimming must produce visible, physically small geometry.
	for i in 18:
		fx.swimmer(10,Vector3(float(i)*0.035,1.15,0),Vector3(0.35,0,0),0.30)
		fx._process(0.1)
	var track:Dictionary=fx.tracks[10]
	var mesh:Mesh=track.mesh.mesh
	var colors:PackedColorArray=mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var visible_alpha:=0.0
	for color in colors:visible_alpha=maxf(visible_alpha,color.a)
	var bounds:Vector3=mesh.get_aabb().size
	var results:={"slow_npc_has_mesh":mesh.get_surface_count()>0,"peak_opacity":visible_alpha,"footprint":str(bounds),"bounded_footprint":bounds.x<1.2 and bounds.z<1.2}
	fx._process(0.85)
	results["stopped_foam_clears"]=not fx.tracks.has(10)
	fx.swimmer(11,Vector3.ZERO,Vector3.ZERO,0.30)
	results["stationary_no_new_wake"]=not fx.tracks.has(11)
	# A crowded wake upload budget must serve every swimmer, and idle paths
	# must keep their mesh resource while the shader continues aging them.
	for id in 16:
		var pos:=Vector3(id*2.0,1.15,0)
		fx.swimmer(100+id,pos,Vector3(0.4,0,0),0.3)
		fx.swimmer(100+id,pos+Vector3(0.1,0,0),Vector3(0.4,0,0),0.3)
	for frame in 5:fx._process(0.01)
	var all_built:=true
	for id in 16:all_built=all_built and fx.tracks[100+id].mesh.mesh!=null
	results["crowded_paths_all_served"]=all_built
	var stable_mesh:Mesh=fx.tracks[100].mesh.mesh
	fx._process(0.001)
	results["unchanged_path_reuses_mesh"]=fx.tracks[100].mesh.mesh==stable_mesh
	results["passed"]=results.slow_npc_has_mesh and visible_alpha>0.15 and results.bounded_footprint and results.stopped_foam_clears and results.stationary_no_new_wake
	results.passed=results.passed and all_built and results.unchanged_path_reuses_mesh
	FileAccess.open("res://research/v11_local_foam_tests.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("LOCAL_FOAM ",results);quit(0 if results.passed else 1)
