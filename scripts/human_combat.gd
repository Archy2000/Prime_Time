extends Node3D
## Short-lived, swept projectiles; world geometry blocks both aiming and damage.
var game:Node3D
var bullets:Array[Dictionary]=[]
var shots_fired:=0
var hits:=0
var blocked:=0
var tracer_material:StandardMaterial3D

func setup(owner_game:Node3D)->void:
 game=owner_game
 tracer_material=StandardMaterial3D.new()
 tracer_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 tracer_material.albedo_color=Color(1.0,0.72,0.22)
 tracer_material.emission_enabled=true;tracer_material.emission=Color(1,0.4,0.08)

func fire(shooter:Node3D,origin:Vector3,aim:Vector3,damage:float)->void:
 if bullets.size()>=96:return
 var tracer:=MeshInstance3D.new()
 var shape:=BoxMesh.new();shape.size=Vector3(0.045,0.045,0.65)
 tracer.mesh=shape;tracer.material_override=tracer_material
 tracer.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 add_child(tracer);tracer.position=origin
 var direction:Vector3=(aim-origin).normalized()
 if direction.length_squared()<0.1:tracer.queue_free();return
 tracer.look_at(origin+direction)
 bullets.append({"node":tracer,"velocity":direction*25.0,"age":0.0,"damage":damage})
 shots_fired+=1
 shooter.muzzle_flash=0.08
 game.npc_audio.gunshot(shooter,origin)

func update(dt:float)->void:
 for i in range(bullets.size()-1,-1,-1):
  var b:Dictionary=bullets[i];b.age+=dt
  var start:Vector3=b.node.position
  var end:Vector3=start+b.velocity*dt
  var query:=PhysicsRayQueryParameters3D.create(start,end,3)
  var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(query)
  var remove:bool=b.age>1.8
  if not hit.is_empty():
   end=hit.position;remove=true
   if hit.collider==game.player:
    game.take_damage(b.damage);hits+=1
   else:blocked+=1
  elif end.y<game.water_level-0.65:
   remove=true
   game.water_fx.splash(Vector3(end.x,game.water_level,end.z),0.18)
  if remove:b.node.queue_free();bullets.remove_at(i)
  else:b.node.position=end
