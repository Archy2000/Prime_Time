extends SceneTree
func _init():call_deferred("run")
func run():
 change_scene_to_file("res://scenes/main.tscn")
 await process_frame
 var game=current_scene
 for m in game.city.get_children():
  if m.get_meta("source_mesh","") in ["road","grass","grass_001"]:print("TERRAIN ",m.get_meta("source_mesh")," ",m.global_transform*m.mesh.get_aabb())
 for m in game.visual.find_children("*","MeshInstance3D",true,false):
  print("MODEL ",m.name," ",game.visual.global_transform.affine_inverse()*m.global_transform*m.get_aabb())
 quit()
