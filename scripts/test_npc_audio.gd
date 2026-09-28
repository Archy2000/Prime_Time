extends SceneTree
func _init()->void:call_deferred("run")
func run()->void:
 change_scene_to_file("res://scenes/main.tscn");await create_timer(0.8).timeout
 var game=current_scene;game.set_physics_process(false)
 var mix:Node3D=game.npc_audio
 for actor in game.targets:mix.stop_actor(actor)
 var npc:Node3D=game.targets[0]
 npc.position=game.player.position+Vector3(3,0,0);npc.velocity=Vector3(1.65,0,0);npc.panic_left=2.5
 npc.set_meta("scream_wait",0.0);mix.scream_gate=0
 var start:int=mix.emitted.scream;mix.update_actor(npc,1.0/60)
 var result:={"panic_voice":mix.emitted.scream==start+1}
 for i in 120:mix.update_actor(npc,1.0/60)
 result["voice_cooldown"]=mix.emitted.scream==start+1
 mix.stop_actor(npc)
 var floor:=MeshInstance3D.new();game.add_child(floor)
 npc.set_meta("rooftop",true);npc.set_meta("roof_support",floor);npc.panic_left=0
 start=mix.emitted.step
 for i in 40:
  npc.position.x+=0.035;mix.update_actor(npc,1.0/60)
 result["running_steps"]=mix.emitted.step>start
 start=mix.emitted.step;npc.velocity=Vector3.ZERO
 for i in 60:mix.update_actor(npc,1.0/60)
 result["stationary_silent"]=mix.emitted.step==start
 npc.set_meta("rooftop",false);npc.velocity=Vector3(1.65,0,0)
 start=mix.emitted.swim
 for i in 50:
  npc.position.x+=0.033;mix.update_actor(npc,1.0/60)
 result["swimming_sound"]=mix.emitted.swim>start
 var police:Node3D=game.fx.make_civilian(0,true,"police");game.add_child(police);police.position=game.player.position+Vector3(3,1,0)
 var soldier:Node3D=game.fx.make_civilian(0,true,"military");game.add_child(soldier);soldier.position=police.position
 start=mix.emitted.gun
 game.combat.fire(police,police.position,game.player.position,4)
 game.combat.fire(soldier,soldier.position,game.player.position,3)
 var variants:={}
 for voice:AudioStreamPlayer3D in mix.pools.gun:
  if voice.playing:variants[voice.get_meta("clip")]=true
 result["distinct_guns"]=mix.emitted.gun==start+2 and variants.has("gun_1") and variants.has("gun_2")
 start=mix.emitted.gun;police.position=game.player.position+Vector3(100,0,0);mix.gunshot(police,police.position)
 result["distant_culled"]=mix.emitted.gun==start
 police.position=soldier.position;game.paused=true;mix.gunshot(police,police.position)
 result["paused_no_new_sound"]=mix.emitted.gun==start;game.paused=false
 mix.stop_actor(npc);npc.set_meta("captured",true);mix.update_actor(npc,1.0/60)
 var stopped:=true
 for category in mix.pools:
  for voice:AudioStreamPlayer3D in mix.pools[category]:
   if voice.get_meta("actor_id",0)==npc.get_instance_id() and voice.playing:stopped=false
 result["captured_silent"]=stopped
 var total:=0
 for category in mix.pools:total+=mix.pools[category].size()
 result["bounded_pool"]=total==21
 # Capture the actual NPC bus to verify the game emits non-silent audio, with no water bed.
 var record:=AudioEffectRecord.new();var bus:=AudioServer.get_bus_index("NPC");AudioServer.add_bus_effect(bus,record);record.set_recording_active(true)
 npc.set_meta("captured",false);npc.position=game.player.position+Vector3(3,0,0);npc.set_meta("scream_wait",0.0);mix.scream_gate=0
 for i in 180:
  mix.update(1.0/60)
  npc.panic_left=2.5;npc.velocity=Vector3(1.65,0,0);npc.position.z+=0.028
  mix.update_actor(npc,1.0/60)
  if i in [10,80,94,108]:mix.gunshot(police if i==10 else soldier,soldier.position)
  await physics_frame
 record.set_recording_active(false)
 var recording:AudioStreamWAV=record.get_recording();recording.save_to_wav("res://research/npc_audio_preview.wav")
 var peak:=0.0
 for i in range(0,recording.data.size()-1,2):peak=maxf(peak,absf(float(recording.data.decode_s16(i))/32768.0))
 result["recorded_audio"] = recording.data.size()>10000 and peak>0.001 and peak<0.99
 result["passed"]=true
 for key in result:
  if key!="passed" and not result[key]:result.passed=false
 print("NPC_AUDIO_TEST ",result)
 FileAccess.open("res://research/npc_audio_test.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 quit(0 if result.passed else 1)

