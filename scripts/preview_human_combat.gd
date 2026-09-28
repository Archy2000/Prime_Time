extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
 change_scene_to_file("res://scenes/main.tscn");await create_timer(0.8).timeout
 var game=current_scene;game.set_physics_process(false);game.elapsed=10.0
 var chosen:Node3D
 for actor in game.targets:
  if actor.get_meta("role")=="civilian":continue
  for offset in [Vector3(5,0,0),Vector3(-5,0,0),Vector3(0,0,5),Vector3(0,0,-5)]:
   var p:Vector3=actor.position+offset;p.y=game.water_level-0.52
   var ray:=PhysicsRayQueryParameters3D.create(actor.position+Vector3.UP*0.65,p+Vector3.UP*0.4,1)
   if game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
    game.player.position=p;chosen=actor;break
  if chosen:break
 if not chosen:print("NO SHOOTING POSITION");quit(1);return
 game.camera_target=chosen.position.lerp(game.player.position,0.5);game.zoom=80;game._camera_update(0.0)
 for i in 80:
  chosen.update_civilian(game,1.0/60);game.combat.update(1.0/60)
  await physics_frame
  if i==58:
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://research/human_combat_preview.png")
 print("LIVE_ROOF_SHOTS ",game.combat.shots_fired)
 quit(0 if game.combat.shots_fired>0 else 1)
