extends SceneTree
func _init()->void:
	call_deferred("run")

func transmission(blocked:bool)->float:
	var s=load("res://scripts/water_hydro.gd").new();s.configure(48,Vector2(-24,-24),1);s.swell_amplitude=0
	s.set_obstacles([AABB(Vector3(-0.6,-1,-24),Vector3(1.2,4,48))] if blocked else [],1)
	s.disturb(Vector3(-4,1,0),1.3,0.20)
	var transmitted:=0.0
	for step in 90:
		s._step()
		for z in range(65,95):
			for x in range(86,110):transmitted+=s.height[z*s.N+x]*s.height[z*s.N+x]
	return transmitted

func centroid(s:RefCounted)->float:
	var mass:=0.0;var moment:=0.0
	for z in range(20,140):
		for x in range(20,140):
			var f:float=s.foam[z*s.N+x];mass+=f;moment+=f*float(x)*s.cell
	return moment/maxf(mass,0.00001)

func run()->void:
	var s=load("res://scripts/water_hydro.gd").new();s.configure(48,Vector2(-24,-24),1);s.swell_amplitude=0;s.set_obstacles([],1)
	for i in 30:s._step()
	var rest:float=s.energy()
	s.vx.fill(1.0);s.disturb(Vector3(0,1,0),2,0,0.8)
	var start:=centroid(s)
	for i in 30:s._step()
	var travel:=centroid(s)-start
	var free:=transmission(false);var blocked:=transmission(true)
	var results:={"rest_energy":rest,"foam_travel_m":travel,"unobstructed_transmission":free,"wall_transmission":blocked,"passed":rest<0.00001 and travel>0.25 and free>0.001 and blocked<free*0.05}
	FileAccess.open("res://research/v3_solver_tests.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "));print(results);quit(0 if results.passed else 1)
