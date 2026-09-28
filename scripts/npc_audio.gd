extends Node3D
## Shared, bounded spatial mix for NPC guns, panic voices and movement.
## Uses the existing gameplay listener from water_audio, never the distant camera.
@export_range(-40,6) var volume_db:=0.0
@export_range(-40,6) var guns_db:=-14.0
@export_range(-40,6) var screams_db:=-16.0
@export_range(-40,6) var footsteps_db:=-24.0
@export_range(-40,6) var swimming_db:=-25.0
const CAPACITY:={"gun":8,"scream":3,"step":6,"swim":4}
var game:Node3D
var pools:Dictionary={}
var clips:Dictionary={}
var emitted:Dictionary={"gun":0,"scream":0,"step":0,"swim":0}
var rng:=RandomNumberGenerator.new()
var scream_gate:=0.0

func setup(owner_game:Node3D)->void:
 game=owner_game;process_mode=Node.PROCESS_MODE_PAUSABLE;rng.seed=90417
 for name in ["NPC", "NPC Guns", "NPC Voices", "NPC Movement"]:
  if AudioServer.get_bus_index(name)>=0:continue
  AudioServer.add_bus();var idx:=AudioServer.bus_count-1;AudioServer.set_bus_name(idx,name)
  AudioServer.set_bus_send(idx,"Master" if name=="NPC" else "NPC")
  if name=="NPC":
   var limiter:=AudioEffectLimiter.new();limiter.ceiling_db=-4.0;AudioServer.add_bus_effect(idx,limiter)
 for name in ["gun_1","gun_2","lscream0","lscream1","lscream2","lscream3","lscream4","roof_step_1","roof_step_2","roof_step_3","roof_step_4"]:
  clips[name]=load("res://assets/audio/npc/"+name+".wav")
 for i in range(1,6):clips["swim_%d"%i]=load("res://assets/audio/water/WaterSplashSmall_%02d.wav"%i)
 for category:String in CAPACITY:
  pools[category]=[]
  for i in CAPACITY[category]:
   var voice:=AudioStreamPlayer3D.new()
   voice.bus="NPC Guns" if category=="gun" else "NPC Voices" if category=="scream" else "NPC Movement"
   voice.max_db=-6.0;voice.panning_strength=0.8
   add_child(voice);pools[category].append(voice)

func update(dt:float)->void:
 scream_gate=maxf(0,scream_gate-dt)
 for category:String in pools:
  for voice:AudioStreamPlayer3D in pools[category]:
   if not voice.playing:continue
   var actor:Node3D=instance_from_id(voice.get_meta("actor_id",0)) as Node3D
   if not is_instance_valid(actor) or actor.get_meta("captured",false):voice.stop();continue
   if category=="scream":voice.global_position=actor.global_position+Vector3.UP*0.4

func _emit(category:String,clip:String,actor:Node3D,point:Vector3,pitch:float)->bool:
 if game.paused or game.defeated or get_tree().paused or actor.get_meta("captured",false):return false
 var radius:float=48.0 if category=="gun" else 32.0 if category=="scream" else 17.0
 if point.distance_to(game.player.global_position)>radius:return false
 var selected:AudioStreamPlayer3D
 for voice:AudioStreamPlayer3D in pools[category]:
  if not voice.playing:selected=voice;break
 # Preserve every close gun attack; recycle the oldest tail when the gun pool is full.
 if selected==null and category=="gun":
  for voice:AudioStreamPlayer3D in pools[category]:
   if selected==null or voice.get_playback_position()>selected.get_playback_position():selected=voice
 if selected==null:return false
 selected.stop();selected.stream=clips[clip]
 selected.set_meta("actor_id",actor.get_instance_id());selected.set_meta("clip",clip)
 selected.global_position=point;selected.pitch_scale=pitch;selected.max_distance=radius
 selected.unit_size=12.0 if category=="gun" else 8.0 if category=="scream" else 4.5
 var level:float=guns_db if category=="gun" else screams_db if category=="scream" else footsteps_db if category=="step" else swimming_db
 var ear:Vector3=game.player.global_position;ear.y=maxf(game.water_level+0.4,ear.y+0.4)
 var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.15,ear,1)
 var muffled:=not game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
 selected.volume_db=level+volume_db-(6.0 if muffled else 0.0)
 selected.play();emitted[category]+=1
 return true

func gunshot(actor:Node3D,point:Vector3)->void:
 var military:bool=actor.role=="military"
 _emit("gun","gun_2" if military else "gun_1",actor,point,rng.randf_range(0.93,1.02) if military else rng.randf_range(1.0,1.06))

func update_actor(actor:Node3D,dt:float)->void:
 if actor.get_meta("captured",false):stop_actor(actor);return
 var wait:float=maxf(0,float(actor.get_meta("scream_wait",0.0))-dt)
 actor.set_meta("scream_wait",wait)
 var previous:Vector3=actor.get_meta("audio_position",actor.global_position)
 actor.set_meta("audio_position",actor.global_position)
 var on_roof:bool=actor.get_meta("rooftop",false)
 var falling:=false
 if on_roof:
  var support:Node=actor.get_meta("roof_support") if actor.has_meta("roof_support") else null
  falling=not is_instance_valid(support) or support.get_meta("broken",false)
 var scared:bool=(actor.panic_left>0.0 and actor.aim_time<=0.0) or falling
 if scared and wait<=0.0 and scream_gate<=0.0:
  var last:int=actor.get_meta("scream_variant",-1)
  var variant:=rng.randi_range(0,4)
  if variant==last:variant=(variant+1)%5
  if _emit("scream","lscream%d"%variant,actor,actor.global_position+Vector3.UP*0.5,rng.randf_range(0.95,1.07)):
   actor.set_meta("scream_variant",variant);actor.set_meta("scream_wait",rng.randf_range(6.0,10.0));scream_gate=0.55
 var delta:Vector3=actor.global_position-previous;delta.y=0
 if falling or delta.length()>2.0 or actor.velocity.length()<0.25 or actor.aim_time>0.0:
  actor.set_meta("step_distance",0.0);return
 var distance:float=float(actor.get_meta("step_distance",0.0))+delta.length()
 var stride:float=0.60 if on_roof else 0.95
 if distance>=stride:
  distance=fmod(distance,stride)
  if on_roof:_emit("step","roof_step_%d"%rng.randi_range(1,4),actor,actor.global_position+Vector3.UP*0.08,rng.randf_range(0.92,1.08))
  else:_emit("swim","swim_%d"%rng.randi_range(1,5),actor,actor.global_position,rng.randf_range(0.92,1.08))
 actor.set_meta("step_distance",distance)

func stop_actor(actor:Node3D)->void:
 for category:String in pools:
  for voice:AudioStreamPlayer3D in pools[category]:
   if voice.get_meta("actor_id",0)==actor.get_instance_id():voice.stop()
