extends Node3D
## A shared controller for swimming, roof escape, and procedural limb animation.
var role:="civilian"
var fire_cooldown:=0.0
var aim_time:=0.0
var burst_left:=0
var muzzle_flash:=0.0
var flash:MeshInstance3D
var marker:Label3D
var mesh:MeshInstance3D
var materials:Array[ShaderMaterial]=[]
var phase:=0.0
var panic_left:=0.0
var velocity:=Vector3.ZERO
var escape:=Vector3.FORWARD
var roof_turn:=1.0

func setup(person:MeshInstance3D,index:int,standing:bool)->void:
 mesh=person
 phase=float(index)*2.39996
 roof_turn=1.0 if index%2==0 else -1.0
 var box:=mesh.mesh.get_aabb()
 for surface in mesh.mesh.get_surface_count():
  var original:=mesh.get_active_material(surface) as StandardMaterial3D
  var mat:=ShaderMaterial.new()
  mat.shader=preload("res://shaders/civilian_motion.gdshader")
  mat.set_shader_parameter("bounds_min",Vector3(box.get_center().x,box.position.y,box.get_center().z))
  mat.set_shader_parameter("body_height",box.size.y)
  if original:
   mat.set_shader_parameter("skin_color",original.albedo_color)
   mat.set_shader_parameter("textured",original.albedo_texture!=null)
   if original.albedo_texture:mat.set_shader_parameter("skin_texture",original.albedo_texture)
  mesh.set_surface_override_material(surface,mat)
  materials.append(mat)
 animate(0.0,not standing,0.0)

func animate(dt:float,swimming:bool,speed:float)->void:
 var active:float=clampf(speed/1.6,0.0,1.0)
 phase+=dt*(lerpf(3.2,8.5,active) if swimming else lerpf(2.0,13.0,active))
 mesh.rotation.x=-PI/2.0 if swimming else -0.10*active
 mesh.position.y=0.06 if swimming else absf(sin(phase))*0.045*active
 mesh.position.z=0.45 if swimming else 0.0
 rotation.z=sin(phase)*0.055 if swimming else 0.0
 for mat in materials:
  mat.set_shader_parameter("motion_phase",phase)
  mat.set_shader_parameter("swimming",swimming)
  mat.set_shader_parameter("activity",maxf(0.45,active) if swimming else active)

func update_civilian(game:Node3D,dt:float)->void:
 velocity=Vector3.ZERO
 var on_roof:bool=get_meta("rooftop",false)
 var support:MeshInstance3D=get_meta("roof_support") if has_meta("roof_support") else null
 if on_roof and (not is_instance_valid(support) or support.get_meta("broken",false)):
  if role!="civilian":flash.hide();aim_time=0.0;burst_left=0
  position.y-=dt*5.0
  animate(dt,false,1.5)
  if position.y<=game.water_level:
   set_meta("rooftop",false)
   position.y=game.water_level
  return
 if on_roof and position.y<game.water_level:
  set_meta("rooftop",false);on_roof=false
 var away:Vector3=position-game.player.position;away.y=0
 var distance:=away.length()
 if update_armed(game,dt,on_roof,distance):return
 # Remember danger briefly, so crossing the detection radius does not freeze a person.
 if distance<12.0:
  var eye:=position+Vector3.UP*(0.8 if on_roof else 0.22)
  var fin:Vector3=game.player.position;fin.y=maxf(game.water_level+0.3,fin.y+0.7)
  var sight:=PhysicsRayQueryParameters3D.create(eye,fin,1)
  if game.get_world_3d().direct_space_state.intersect_ray(sight).is_empty():
   panic_left=2.5
   escape=away.normalized() if distance>0.01 else Vector3.RIGHT

 # Also decay when an obstruction hides the shark.
 panic_left=maxf(0.0,panic_left-dt)
 var frightened:=panic_left>0.0
 var direction:=escape if frightened else Vector3(sin(phase*0.08),0,cos(phase*0.08))
 var speed:=2.0 if on_roof else 1.65
 if not frightened:speed=0.0 if on_roof else 0.18
 if on_roof and role!="civilian" and game.elapsed>=6.0 and distance<24.0 and distance>3.0:
  direction=-away.normalized();speed=0.65
 if on_roof:
  direction=direction.rotated(Vector3.UP,sin(phase*0.27)*0.65)
 var moved:=Vector3.ZERO
 # Try forward then tangents. Water alternatives always retain an away component.
 for angle in [0.0,0.65*roof_turn,-0.65*roof_turn,1.25*roof_turn,-1.25*roof_turn,2.2*roof_turn,PI]:
  if not on_roof and absf(angle)>1.4:continue
  var heading:=direction.rotated(Vector3.UP,angle)
  var step:=heading*speed*dt
  var next:=position+step
  if on_roof:
   var valid:=true
   var floor_y:=position.y
   # Probe the actual supporting roof, including sloping / nonrectangular roofs.
   for offset in [Vector3.ZERO,Vector3(0.22,0,0),Vector3(-0.22,0,0),Vector3(0,0,0.22),Vector3(0,0,-0.22)]:
    var top:Vector3=next+offset+Vector3.UP*1.2
    var hit:Dictionary=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*2.5,1))
    if hit.is_empty() or hit.collider.get_meta("visual",null)!=support or hit.normal.y<0.45:
     valid=false;break
    if offset==Vector3.ZERO:floor_y=hit.position.y+0.06
   if not valid:continue
   next.y=floor_y
  else:
   var origin:=position;origin.y=game.water_level+0.12
   var end:=origin+heading*(speed*dt+0.35)
   if not game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,end,1)).is_empty():continue
  moved=next-position;position=next
  break
 velocity=moved/maxf(dt,0.0001);velocity.y=0
 if velocity.length()>0.02:
  rotation.y=lerp_angle(rotation.y,atan2(-velocity.x,-velocity.z),minf(1.0,dt*12.0))
 if not on_roof:position.y=game.water_level+game.wave_sim.sample_surface(position).y+sin(phase)*0.025
 animate(dt,not on_roof,velocity.length())


func setup_armed(kind:String)->void:
 role=kind
 fire_cooldown=0.5+fmod(phase,1.0)
 for mat in materials:mat.set_shader_parameter("posed",true)
 marker=Label3D.new();marker.text="警" if role=="police" else "军"
 marker.font_size=42;marker.pixel_size=0.006;marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
 marker.modulate=Color(0.35,0.65,1) if role=="police" else Color(1,0.6,0.2)
 marker.position.y=1.22;add_child(marker)
 flash=MeshInstance3D.new();var ball:=SphereMesh.new();ball.radius=0.10;ball.height=0.2;flash.mesh=ball
 var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color(1,0.86,0.35)
 flash.material_override=mat;flash.position=Vector3(0.06,0.65,-0.48);flash.visible=false;add_child(flash)

func update_armed(game:Node3D,dt:float,on_roof:bool,distance:float)->bool:
 if role=="civilian":return false
 if get_meta("captured",false):return true
 muzzle_flash=maxf(0.0,muzzle_flash-dt);flash.visible=muzzle_flash>0
 fire_cooldown=maxf(0.0,fire_cooldown-dt)
 marker.text="警" if role=="police" else "军"
 if not on_roof or game.elapsed<6.0 or game.defeated:
  aim_time=0.0;burst_left=0;flash.hide();return false
 var origin:=global_position+Vector3.UP*0.65
 var aim:Vector3=game.player.global_position+Vector3.UP*0.4*game.growth
 var sight:=PhysicsRayQueryParameters3D.create(origin,aim,1)
 var visible_target:bool=distance<(19.0 if role=="police" else 24.0) and game.get_world_3d().direct_space_state.intersect_ray(sight).is_empty()
 if not visible_target or distance<2.8:
  aim_time=0.0;burst_left=0;return false
 aim_time+=dt
 marker.text="!" if aim_time<0.85 else ("警 · 射击" if role=="police" else "军 · 连射")
 var heading:Vector3=aim-global_position
 rotation.y=lerp_angle(rotation.y,atan2(-heading.x,-heading.z),minf(1.0,dt*10))
 animate(dt,false,0.0)
 mesh.rotation.x=sin(phase*2.0)*0.015+muzzle_flash*0.5
 if aim_time>=0.85 and fire_cooldown<=0.0:
  if role=="military" and burst_left<=0:burst_left=3
  var muzzle:Vector3=to_global(Vector3(0.06,0.65,-0.48))
  # Bounded prediction/spread allows moving sharks to dodge visible projectiles.
  aim+=game.player.velocity*minf(distance/25.0,0.35)*0.45
  aim+=Vector3(sin(phase*7.0),0,cos(phase*5.0))*(0.22 if role=="police" else 0.32)
  if game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin,muzzle,1)).is_empty():
   game.combat.fire(self,muzzle,aim,4.0 if role=="police" else 3.0)
  if role=="military":
   burst_left-=1;fire_cooldown=0.22 if burst_left>0 else 2.4
  else:fire_cooldown=1.5
 return true

