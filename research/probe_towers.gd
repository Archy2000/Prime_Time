extends SceneTree
func _init():call_deferred("run")
func run():
 change_scene_to_file("res://scenes/main.tscn");await process_frame
 var game=current_scene
 for key in game.buildings:
  if "Highriser" in key or key.ends_with("2floor lowrise"):
   var box:AABB=game.buildings[key].parts[0].global_transform*game.buildings[key].parts[0].mesh.get_aabb()
   for p in game.buildings[key].parts:box=box.merge(p.global_transform*p.mesh.get_aabb())
   print(key," ",box)
 quit()
