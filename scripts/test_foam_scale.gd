extends SceneTree
func _init()->void:call_deferred("run")

func probe(path:String,size:float)->Dictionary:
	var s=load(path).new();s.swell_amplitude=0;s.set_obstacles([],1.15)
	var peak:=0.0
	for frame in 90:
		var t:=float(frame)/30.0
		s.swimmer(Vector3(t*0.8,1.15,-24),Vector3(0.8,0,0),size,1.0/30.0)
		s._step()
		for h in s.height:peak=maxf(peak,absf(h))
	var foam_mass:=0.0
	for f in s.foam:foam_mass+=f
	return {"height_peak":peak,"energy":s.energy(),"foam_mass":foam_mass}

func run()->void:
	var before:=probe("res://research/v10_before/water_hydro.gd",0.35)
	var npc:=probe("res://scripts/water_hydro.gd",0.35)
	var large:=probe("res://scripts/water_hydro.gd",1.0)
	var result:={"before_npc":before,"after_npc":npc,"after_size_1":large}
	result["height_ratio"]=npc.height_peak/before.height_peak
	result["passed"]=npc.height_peak>0 and npc.height_peak<before.height_peak*0.15 and npc.energy<large.energy*0.05 and npc.foam_mass<before.foam_mass*0.1
	FileAccess.open("res://research/v10_scale_tests.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("FOAM_SCALE ",result);quit(0 if result.passed else 1)
