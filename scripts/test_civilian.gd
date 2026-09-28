extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
 change_scene_to_file("res://scenes/main.tscn")
 await create_timer(1.0).timeout
 var game=current_scene
 game.set_physics_process(false)
 var swimmer:Node3D=game.targets[0]
 swimmer.position=Vector3(0,game.water_level,-25)
 game.player.position=swimmer.position+Vector3(3,-0.52,0)
 var before:=swimmer.position
 for i in 60:swimmer.update_civilian(game,1.0/60.0)
 var delta:=swimmer.position-before;delta.y=0
 var result:={"swimmer_flees":delta.x < -0.5,"swim_pose":absf(swimmer.mesh.rotation.x+PI/2)<0.01,"roof_moves":false,"roof_supported":true}
 result["roof_senses_shark"]=false
 for target in game.targets:
  if not target.get_meta("rooftop",false):continue
  var roof:MeshInstance3D=target.get_meta("roof_support")
  var bounds:AABB=roof.global_transform*roof.mesh.get_aabb()
  for offset in [Vector3(bounds.size.x/2+2,0,0),Vector3(-bounds.size.x/2-2,0,0),Vector3(0,0,bounds.size.z/2+2),Vector3(0,0,-bounds.size.z/2-2)]:
   game.player.position=bounds.get_center()+offset;game.player.position.y=game.water_level-0.52
   target.panic_left=0.0
   target.update_civilian(game,1.0/60.0)
   if target.panic_left>0.0:result.roof_senses_shark=true;break
  if result.roof_senses_shark:break
 game.player.position=Vector3(75,game.water_level,75)
 var runner:Node3D
 for target in game.targets:
  if not target.get_meta("rooftop",false):continue
  target.panic_left=2.5;target.escape=Vector3.RIGHT
  before=target.position
  for i in 60:target.update_civilian(game,1.0/60.0)
  if target.position.distance_to(before)>0.4:
   runner=target;result.roof_moves=true;break
 if runner:
  var roof=runner.get_meta("roof_support")
  for i in 600:
   runner.panic_left=2.5;runner.update_civilian(game,1.0/60.0)
   var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(runner.position+Vector3.UP,runner.position-Vector3.UP,1))
   if hit.is_empty() or hit.collider.get_meta("visual",null)!=roof:result.roof_supported=false
  roof.set_meta("broken",true)
  for i in 180:runner.update_civilian(game,1.0/60.0)
  result["fall_changes_to_swim"]=not runner.get_meta("rooftop",true) and absf(runner.mesh.rotation.x+PI/2)<0.01
 # Close-up of existing textured models with the new pose, in the game lighting.
 var center:=Vector3(0,game.water_level+8,-25)
 for i in 6:
  var actor:Node3D=game.fx.make_civilian(i,i>=3);game.add_child(actor)
  actor.position=center+Vector3(float(i%3-1)*1.5,0,float(i/3)*2)
  actor.animate(0.15+float(i)*0.12,i<3,1.8)
 game.camera.position=center+Vector3(2,5,6)
 game.camera.projection=Camera3D.PROJECTION_ORTHOGONAL;game.camera.size=6.5
 game.camera.look_at(center+Vector3(0,0,1))
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://research/civilian_motion_preview.png")
 result["passed"]=result.swimmer_flees and result.swim_pose and result.roof_senses_shark and result.roof_moves and result.roof_supported and result.get("fall_changes_to_swim",false)
 print("CIVILIAN_TEST ",result)
 FileAccess.open("res://research/civilian_motion_test.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 quit(0 if result.passed else 1)

