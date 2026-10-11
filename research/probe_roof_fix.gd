extends SceneTree
func _init():call_deferred("run")
func run():
 change_scene_to_file("res://scenes/main.tscn")
 await create_timer(1).timeout
 var g=current_scene
 g.set_process(false);g.set_physics_process(false)
 var pos:Vector3=g.tower_district.towers[0].position
 g.camera.position=pos+Vector3(18,23,18);g.camera.look_at(pos+Vector3(0,7,0));g.camera.size=24
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://research/roof_fixed.png")
 quit()


