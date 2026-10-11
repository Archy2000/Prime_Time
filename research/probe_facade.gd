extends SceneTree
func _init():call_deferred("run")
func run():
 change_scene_to_file("res://scenes/main.tscn")
 await create_timer(1).timeout
 var p=current_scene.buildings["JapanStage/JapanHighriser"].parts[0]
 print("TRANSFORM ",p.global_transform," LOCAL ",p.mesh.get_aabb())
 var points={}
 for i in p.mesh.get_surface_count():
  for v in p.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]:
   var w=Vector3(v.x,v.z,v.y)
   points[Vector2(snappedf(w.x,0.01),snappedf(w.z,0.01))]=true
 print("XZ ",points.keys())
 quit()

