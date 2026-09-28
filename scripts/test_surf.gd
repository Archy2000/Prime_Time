extends SceneTree
## Behaviour checks: wave impacts generate foam, still walls don't; foam clears on dry ground.
func _init()->void:call_deferred("run")

func make_sim(wall:bool)->RefCounted:
	var s=load("res://scripts/water_hydro.gd").new()
	s.configure(48,Vector2(-24,-24),1);s.swell_amplitude=0
	s.set_obstacles([AABB(Vector3(-8,-1,-0.6),Vector3(16,4,1.2))] if wall else [],1)
	return s

func run()->void:
	var s=make_sim(true)
	for frame in 30:s._step()
	var quiet:=0.0
	for value in s.foam:quiet=maxf(quiet,value)
	s.disturb(Vector3(0,1,3),2.4,0.30,0,Vector2(0,-0.6))
	var peak:=0.0;var white:=0.0;var finite:=true
	for frame in 150:
		s._step()
		for z in range(82,89):
			for x in range(65,95):
				var i:int=z*s.N+x
				peak=maxf(peak,s.impact[i]);white=maxf(white,s.foam[i])
		for value in s.height:finite=finite and is_finite(value)
	var drift=make_sim(false)
	drift.disturb(Vector3(0,1,0),2,0,0.8)
	var initial:float=drift.foam[80*drift.N+80]
	for frame in 150:drift._step()
	var faded:float=drift.foam[80*drift.N+80]
	drift.base_floor.fill(3.0);drift.set_obstacles([],1);drift._step()
	var dry:=0.0
	for value in drift.foam:dry=maxf(dry,value)
	var results:={"still_wall_foam":quiet,"impact_peak":peak,"impact_foam":white,"initial_foam":initial,"foam_after_5s":faded,"dry_foam":dry,"finite":finite}
	results.passed=quiet<0.00001 and peak>0.05 and white>0.04 and faded<initial*0.15 and dry==0 and finite
	FileAccess.open("res://research/v9_surf_tests.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("SURF_TEST ",results);quit(0 if results.passed else 1)
