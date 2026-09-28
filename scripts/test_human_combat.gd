extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
 change_scene_to_file("res://scenes/main.tscn");await create_timer(0.8).timeout
 var game=current_scene;game.set_physics_process(false);game.elapsed=10.0
 var variants:={};var roles:={}
 for actor in game.targets:
  variants[actor.get_meta("appearance")]=true
  var role:String=actor.get_meta("role");roles[role]=roles.get(role,0)+1
 var result:={"variants":variants.size(),"roles":roles}
 var platform:=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(2,0.3,2);platform.mesh=box;game.add_child(platform);platform.position=Vector3(100,3,100)
 var body:=StaticBody3D.new();body.set_meta("visual",platform);platform.add_child(body)
 var shape:=CollisionShape3D.new();var bs:=BoxShape3D.new();bs.size=box.size;shape.shape=bs;body.add_child(shape)
 var cop:Node3D=game.fx.make_civilian(0,true,"police");game.add_child(cop);cop.position=Vector3(100,3.21,99.3);cop.set_meta("rooftop",true);cop.set_meta("roof_support",platform)
 game.player.position=Vector3(100,game.water_level-0.52,94);game.player.velocity=Vector3.ZERO
 await physics_frame;await physics_frame
 var first:int=game.combat.shots_fired
 for i in 30:cop.update_civilian(game,1.0/60)
 result["warning_before_fire"]=game.combat.shots_fired==first
 for i in 210:
  cop.update_civilian(game,1.0/60);game.combat.update(1.0/60)
 result["police_shots"]=game.combat.shots_fired-first
 result["damage_applied"]=game.health<100
 cop.role="military";cop.aim_time=0;cop.fire_cooldown=0;first=game.combat.shots_fired
 for i in 240:
  cop.update_civilian(game,1.0/60);game.combat.update(1.0/60)
 result["military_shots"]=game.combat.shots_fired-first
 # A tall wall blocks both acquisition and a projectile already in flight.
 var wall:=StaticBody3D.new();game.add_child(wall);wall.position=Vector3(100,2,97)
 var wc:=CollisionShape3D.new();var wb:=BoxShape3D.new();wb.size=Vector3(5,6,0.4);wc.shape=wb;wall.add_child(wc)
 await physics_frame;await physics_frame
 first=game.combat.shots_fired
 for i in 120:cop.update_civilian(game,1.0/60)
 result["wall_blocks_aim"]=game.combat.shots_fired==first
 var hp:float=game.health
 game.combat.fire(cop,Vector3(100,3.8,99),game.player.position+Vector3.UP*0.4,9)
 for i in 120:game.combat.update(1.0/60)
 result["wall_blocks_damage"]=game.health==hp and game.combat.blocked>0
 cop.set_meta("rooftop",false);cop.position=Vector3(100,game.water_level,99);first=game.combat.shots_fired
 for i in 180:cop.update_civilian(game,1.0/60)
 result["no_underwater_shooting"]=game.combat.shots_fired==first
 cop.set_meta("captured",true);cop.set_meta("rooftop",true);cop.position=Vector3(100,3.21,99.3)
 first=game.combat.shots_fired
 for i in 120:cop.update_civilian(game,1.0/60)
 result["captured_stops_attacking"]=game.combat.shots_fired==first
 game.health=50;game._finish_meal(game.player.position);result["feeding_heals"]=game.health==58
 game.take_damage(200);result["defeat"]=game.defeated and paused
 paused=false
 result["passed"]=result.variants>=12 and roles.get("police",0)>0 and roles.get("military",0)>0 and result.warning_before_fire and result.police_shots>=2 and result.military_shots>result.police_shots and result.damage_applied and result.wall_blocks_aim and result.wall_blocks_damage and result.no_underwater_shooting and result.captured_stops_attacking and result.feeding_heals and result.defeat
 print("HUMAN_COMBAT_TEST ",result)
 FileAccess.open("res://research/human_combat_test.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 quit(0 if result.passed else 1)




