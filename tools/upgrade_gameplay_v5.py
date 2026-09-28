from pathlib import Path
p=Path('scripts/main.gd');s=p.read_text(encoding='utf-8-sig')
s=s.replace('const CITY_SCALE := 0.2','const CITY_SCALE := 0.2\nconst BUILDING_GROWTH:=1.65\nvar airborne:=false\nvar jump_velocity:=0.0\nvar jump_cooldown:=0.0\nvar air_drift:=Vector3.ZERO\nvar roof_targets:=0\nvar roof_eaten:=0')
s=s.replace('\t_make_targets()','\t_make_targets()\n\t_make_roof_targets()')
s=s.replace('"boost":[KEY_SPACE]','"boost":[KEY_SHIFT],"jump":[KEY_SPACE]')
s=s.replace('\tvar mouse:=InputEventMouseButton.new()', '\tvar jump_btn:=InputEventJoypadButton.new();jump_btn.button_index=JOY_BUTTON_X;InputMap.action_add_event("jump",jump_btn)\n\tvar mouse:=InputEventMouseButton.new()')
s=s.replace('if event.is_action_pressed("boost") and not paused:_start_boost()','if event.is_action_pressed("boost") and not paused:_start_boost()\n\tif event.is_action_pressed("jump") and not paused:_jump()')
s=s.replace('player.position=START','player.position=Vector3(START.x,water_level-0.52,START.z)')
s=s.replace('WASD 移动  ·  空格撞击  ·  接触吞噬 / E 吸入','WASD 游动 · 空格跃起 · Shift 冲刺 · E 吞噬')
s=s.replace('空格 / 手柄 B：冲刺（1 秒，冷却 5 秒）','空格 / 手柄 X：跃出水面\\nShift / 手柄 B：冲刺（冷却 5 秒）')
s=s.replace('冲刺撞击车辆和建筑，破坏支撑可触发分段坍塌。','体型达到 1.65× 可撞毁建筑。跃起接近楼顶居民可吞噬。')
s=s.replace('水花优化版本  04','跃起捕食版本  05')
s=s.replace('洪水已进入街区。捕食成长，冲刺撞开车辆。','空格跃起捕食楼顶居民；成长到 1.65× 才能撞毁建筑。')
s=s.replace('bite_window=maxf(0,bite_window-dt)','bite_window=maxf(0,bite_window-dt);jump_cooldown=maxf(0,jump_cooldown-dt)')
a=s.index('\tplayer.velocity=player.velocity.move_toward(dir*speed');b=s.index('\tif boost_time>0:',a)
s=s[:a]+'''\tvar surface:float=water_level+wave_sim.sample_surface(player.position).y
\tif airborne:
\t\tjump_velocity-=18.0*dt
\t\tif dir.length()>0.1:air_drift=air_drift.move_toward(dir*8.0,dt*13.0)
\t\tplayer.velocity=Vector3(air_drift.x,jump_velocity,air_drift.z)
\telse:
\t\tplayer.velocity=player.velocity.move_toward(dir*speed,dt*45.0);player.velocity.y=0
\t\tplayer.position.y=lerpf(player.position.y,surface-0.52*growth,minf(1,dt*12))
\tif dir.length()>0.1:visual.rotation.y=lerp_angle(visual.rotation.y,atan2(-dir.x,-dir.z),minf(1.0,dt*12.0))
\tvisual.rotation.x=lerpf(visual.rotation.x,clampf(atan2(jump_velocity,8.0),-0.65,0.8) if airborne else 0.0,minf(1,dt*10))
\tplayer.move_and_slide()
\tif airborne:
\t\tfor i in player.get_slide_collision_count():
\t\t\tif player.get_slide_collision(i).get_normal().y>0.5 and jump_velocity<0:jump_velocity=0
\t\tif player.position.y<=surface-0.52*growth and jump_velocity<0:
\t\t\tairborne=false;player.position.y=surface-0.52*growth;fx.splash(player.position,1.15);jump_velocity=0
''' + s[b:]
a=s.index('\t\ttarget.position.y=water_level+wave_sim');b=s.index('\t_update_water(dt)',a)
s=s[:a]+'''\t\tif target.get_meta("rooftop",false):
\t\t\tvar support:MeshInstance3D=target.get_meta("roof_support")
\t\t\tif not is_instance_valid(support) or support.get_meta("broken",false):
\t\t\t\ttarget.position.y-=dt*5.0
\t\t\t\tif target.position.y<=water_level:
\t\t\t\t\ttarget.set_meta("rooftop",false);target.position.y=water_level
\t\t\telse:target.rotation.y=atan2(player.position.x-target.position.x,player.position.z-target.position.z)
\t\telse:
\t\t\ttarget.position.y=water_level+wave_sim.sample_surface(target.position).y+sin(elapsed*3+float(target.get_meta("phase")))*0.035
\t\tif _can_eat(target,bite_window>0):_capture_target(i);continue
\t\tif target.get_meta("rooftop",false):continue
\t\tvar away:Vector3=target.position-player.position;away.y=0
\t\tif away.length()<6 and away.length()>0.1:
\t\t\tvar wanted:Vector3=target.position+away.normalized()*dt*0.7
\t\t\tvar query:=PhysicsRayQueryParameters3D.create(target.position,wanted+away.normalized()*0.25,1)
\t\t\tif get_world_3d().direct_space_state.intersect_ray(query).is_empty():target.position=wanted
\t\t\ttarget.rotation.y=atan2(-away.x,-away.z)
\t\ttarget.rotation.z=sin(elapsed*5+float(target.get_meta("phase")))*0.14
''' + s[b:]
s=s.replace('if is_instance_valid(t) and t.position.distance_to(player.position)<3.0*growth:_capture_target(i)','if is_instance_valid(t) and _can_eat(t,true):_capture_target(i)')
s=s.replace('\tfx.splash(player.position,0.65)','\tif not airborne:fx.splash(player.position,0.65)')
s=s.replace('var target:Node3D=targets[i];targets.remove_at(i);fx.swallow(target)','var target:Node3D=targets[i]\n\tif target.get_meta("rooftop",false):roof_eaten+=1\n\ttargets.remove_at(i);fx.swallow(target)')
s=s.replace('notice.text="吞噬 ×%d · 连击成长。冲刺可撞碎建筑。"%combo','notice.text="体型 %.2f× / 1.65× · %s"%[growth,"可撞毁建筑！" if growth>=BUILDING_GROWTH else "继续捕食，解锁建筑破坏"]')
s=s.replace('if m.get_meta("broken",false):return\n\tm.set_meta', 'if m.get_meta("broken",false):return\n\tif not m.get_meta("car",false) and growth<BUILDING_GROWTH:\n\t\tnotice.text="建筑太坚固：需要体型 1.65×（约吞噬 10 人）";return\n\tm.set_meta')
s=s.replace('\twater_fx.swimmer(0,player.position,player.velocity,growth)','\tif not airborne:water_fx.swimmer(0,player.position,player.velocity,growth)')
s=s.replace('\t\twave_sim.swimmer(player.position,player.velocity,growth,wake_timer)','\t\tif not airborne:wave_sim.swimmer(player.position,player.velocity,growth,wake_timer)')
s=s.replace('if not is_instance_valid(target):continue\n\t\t\tvar last','if not is_instance_valid(target) or target.get_meta("rooftop",false):continue\n\t\t\tvar last')
s=s.replace('press.physical_keycode=KEY_SPACE','press.physical_keycode=KEY_SHIFT')
s=s.replace('if not destructibles.is_empty():_break_piece(destructibles[0]);trace["destruction_count"]=wrecked','if not destructibles.is_empty():\n\t\t\tvar old_growth:=growth;growth=BUILDING_GROWTH;_break_piece(destructibles[0]);growth=old_growth;trace["destruction_count"]=wrecked')
p.write_text(s,encoding='utf8')
