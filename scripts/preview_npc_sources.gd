extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
 var scene:=Node3D.new();root.add_child(scene)
 var source:Node3D=load("res://assets/characters/humans/humans.gltf").instantiate()
 var i:=0
 for child in source.get_children():
  if not "assembled" in child.name:continue
  print(child.name," ",child.mesh.get_aabb())
  var person:MeshInstance3D=child.duplicate()
  var bounds:=person.mesh.get_aabb();var factor:=2.0/bounds.size.y
  person.scale=Vector3.ONE*factor;person.position=Vector3(i*2.5,0,0)-Vector3(bounds.get_center().x,bounds.position.y,bounds.get_center().z)*factor
  scene.add_child(person);i+=1
 var camera:=Camera3D.new();scene.add_child(camera);camera.position=Vector3(7,5,-9);camera.look_at(Vector3(2.5,1,0));camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9
 var light:=DirectionalLight3D.new();scene.add_child(light);light.rotation_degrees=Vector3(-35,-30,0)
 var world:=WorldEnvironment.new();world.environment=Environment.new();world.environment.background_mode=Environment.BG_COLOR;world.environment.background_color=Color(0.12,0.17,0.2);world.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;world.environment.ambient_light_color=Color.WHITE;world.environment.ambient_light_energy=0.7;scene.add_child(world)
 await process_frame;await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("res://research/armed_source_preview.png")
 source.free();quit()

