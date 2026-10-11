extends Node
## Session state is separate from the existing water/destruction simulation.
const BALANCE=preload("res://scripts/run_balance.gd")
const THRESHOLDS:Array[int]=BALANCE.THRESHOLDS
const FAMILIES:Array[String]=["hydra","kraken","zombie"]
const SUPPORTS:Array[String]=["jaw","tail","dash","heal","frenzy","armor"]
const NAMES:Dictionary={"hydra":"多头畸变","kraken":"深海触腕","zombie":"不死血肉","jaw":"巨颚软骨","tail":"强健尾鳍","dash":"冲刺肌肉","heal":"嗜血消化","frenzy":"饥饿回路","armor":"深海护皮"}
const TITLES:Dictionary={"hydra":["双头鲨","三头鲨","五头鲨","九头巨鲨"],"kraken":["触腕萌芽","四腕猎手","六腕怪鲨","深海八腕"],"zombie":["尸化鲨鱼","再生尸鲨","狂暴死骸","不死巨鲨"]}
const SAVE_PATH:="user://shark_run_records.json"
var game:Node3D
var organs:Node3D
var landmark:Node3D
var ranks:Dictionary={}
var primary:=""
var picks:=0
var choosing:=false
var briefing:=true
var finished:=false
var offers:Array[String]=[]
var rerolls:=1
var seconds:=0.0
var duration:=480.0
var dash_serial:=0
var revivals:=0
var rage_left:=0.0
var grab_cooldown:=0.0
var mouth_cooldown:=0.0
var primary_cooldown:=0.0
var mouth_cursor:=0
var pick_history:Array[Dictionary]=[]
var rng:=RandomNumberGenerator.new()
var records:Dictionary={"best_score":0,"best_eaten":0,"wins":0}
var ui:CanvasLayer
var hud:Label
var goal:Label
var progress:ProgressBar
var shade:ColorRect
var panel:PanelContainer
var content:VBoxContainer
var buttons:Array[Button]=[]
var pending_open:=false
var record_path:=SAVE_PATH

func setup(g:Node3D)->void:
	game=g;process_mode=Node.PROCESS_MODE_ALWAYS;rng.randomize()
	if OS.get_cmdline_user_args().has("--roguelite-test"):record_path="user://roguelite_test_records.json"
	organs=preload("res://scripts/mutation_visual.gd").new();game.visual.add_child(organs);organs.rebuild(ranks)
	landmark=preload("res://scripts/run_landmark.gd").new();game.add_child(landmark);landmark.setup(game,self)
	if FileAccess.file_exists(record_path):
		var parsed=JSON.parse_string(FileAccess.get_file_as_string(record_path))
		if parsed is Dictionary:
			for key in records:
				if parsed.get(key) is float or parsed.get(key) is int:records[key]=maxi(0,int(parsed[key]))
	build_ui();refresh_hud();show_briefing()
	for help_line in game.help.get_children():
		if help_line is Label:help_line.text=help_line.text.replace("吞噬回复 8 点生命","吞噬基础回复 2 点生命")
	game.notice.text="吞食 %d 人，选择第一种身体畸变。长成巨兽后，冲刺摧毁钟塔。"%THRESHOLDS[0]

func show_briefing()->void:
	briefing=true;game.paused=true;get_tree().paused=true;clear_panel()
	heading("洪城：畸变鲨潮",38,Color(1,0.77,0.38))
	heading("第一猎场  /  小城镇",22)
	heading("吞食人类 → 三选一身体变异 → 长成巨兽 → 撞塌钟塔",21)
	heading("多头鲨 · 同时捕食     章鱼鲨 · 卷下高处猎物     尸鲨 · 重伤再生",18)
	heading("8 分钟内吞食 %d 人，长至 3.2×，冲刺命中钟塔三次。\n首次变异需吞食 %d 人；主系高阶在第 3 / 6 / 9 次升级开放。"%[BALANCE.MAX_GROWTH_MEALS,THRESHOLDS[0]],18)
	heading("WASD 游动   /   Shift 冲刺   /   空格跃起   /   E 主动捕食与触手",17)
	heading("最高分 %06d    ·    已通关 %d 次"%[records.best_score,records.wins],17)
	var start:=Button.new();start.text="开始猎食  /  Enter";start.custom_minimum_size.y=56;start.pressed.connect(start_run);content.add_child(start);shade.show();start.grab_focus()

func start_run()->void:
	briefing=false;game.paused=false;get_tree().paused=false;shade.hide()

func rank(id:String)->int:return int(ranks.get(id,0))

func description(id:String)->String:
	var next:=rank(id)+1
	match id:
		"hydra":return ["长出第二个头，增加侧面捕食。","第三个头长出，覆盖左右两侧。","长成五头，附属嘴覆盖更宽扇面。","九头巨鲨：八个附属嘴环绕捕猎！"][next-1]+" 附属嘴每 %.1f 秒共吞食最多 %d 人。"%[BALANCE.HYDRA_INTERVAL,BALANCE.HYDRA_BATCH[next]]
		"kraken":return "长出 %d 条触手。按 E / 左键卷入最多 %d 人，冷却 %.1f 秒，范围 %.1f ×体型，可抓高处目标。"%[next*2,next,BALANCE.KRAKEN_INTERVAL[next],2.3+next*0.65]
		"zombie":return ["尸化皮肤与骨刺。受到伤害减少 10%，吞食额外回复 1 点。","伤害减少 20%，吞食额外回复 2 点。","伤害减少 30%，吞食额外回复 3 点；重伤触发 3 秒狂暴，游速提高 25%。","伤害减少 40%，吞食额外回复 4 点；本局首次致命伤复苏，恢复 45 点生命。"][next-1]
		"jaw":return "基础咬合距离累计增加 %d%%。"%(next*18)
		"tail":return "游动速度累计增加 %d%%。"%(next*12)
		"dash":return "冲刺冷却累计缩短 %.1f 秒。"%(next*0.7)
		"heal":return "每次吞食额外回复 %d 点生命。"%(next*BALANCE.HEAL_PER_RANK)
		"frenzy":return "每次吞食使冲刺冷却减少 %.1f 秒。"%(next*0.25)
		"armor":return "受到的伤害额外减少 %d%%。"%(next*8)
	return ""

func legal(id:String)->bool:
	if id in FAMILIES:
		if rank(id)>=(4 if id==primary or primary.is_empty() else 2):return false
		if picks+1<BALANCE.FAMILY_PICK_GATES[rank(id)]:return false
		var count:=0
		for family in FAMILIES:
			if rank(family)>0:count+=1
		return rank(id)>0 or count<2
	return rank(id)<2

func make_offers()->Array[String]:
	if picks==0:return FAMILIES.duplicate()
	var pool:Array[String]=[]
	for id in FAMILIES+SUPPORTS:
		if legal(id):pool.append(id)
	var result:Array[String]=[]
	if legal(primary):result.append(primary);pool.erase(primary)
	while result.size()<3 and not pool.is_empty():
		var index:=rng.randi_range(0,pool.size()-1);result.append(pool[index]);pool.remove_at(index)
	return result

func meal()->void:
	if finished:return
	game.growth=BALANCE.growth_for(game.eaten)
	game.health=minf(100,game.health+rank("heal")*BALANCE.HEAL_PER_RANK+rank("zombie")*BALANCE.ZOMBIE_HEAL_PER_RANK)
	game.cooldown=maxf(0,game.cooldown-rank("frenzy")*0.25)
	queue_choice()

func queue_choice()->void:
	if not finished and not choosing and not pending_open and picks<THRESHOLDS.size() and game.eaten>=THRESHOLDS[picks]:
		pending_open=true;open_choice.call_deferred()

func open_choice()->void:
	pending_open=false
	if finished or game.defeated:return
	choosing=true;game.paused=true;get_tree().paused=true;game.pause_label.hide();offers=make_offers();show_choices()

func choose(index:int)->void:
	if not choosing or index<0 or index>=offers.size():return
	var id:=offers[index]
	if not legal(id):return
	if primary.is_empty():primary=id
	ranks[id]=rank(id)+1;picks+=1;choosing=false
	pick_history.append({"pick":picks,"seconds":seconds,"eaten":game.eaten,"id":id,"rank":rank(id)})
	organs.rebuild(ranks);shade.hide();game.paused=false;get_tree().paused=false
	game.notice.text="进化完成 · "+build_name()+"    E 主动捕食 / Shift 冲撞"
	game.shake=0.3;refresh_hud();queue_choice()

func reroll()->void:
	if not choosing or rerolls<=0 or picks==0:return
	rerolls-=1;offers=make_offers();show_choices()

func build_name()->String:
	var names:PackedStringArray=[]
	for id in FAMILIES:
		if rank(id)>0:names.append(TITLES[id][rank(id)-1])
	return "原生鲨鱼" if names.is_empty() else " × ".join(names)

func speed_multiplier()->float:return (1+rank("tail")*0.12)*(1.25 if rage_left>0 else 1.0)
func jaw_multiplier()->float:return 1+rank("jaw")*0.18
func boost_rest()->float:return 4.0-rank("dash")*0.7

func claim_capture(channel:String)->bool:
	if finished or choosing or briefing:return false
	if channel=="primary":
		if primary_cooldown>0:return false
		primary_cooldown=BALANCE.PRIMARY_BITE_INTERVAL
	return true

func modify_damage(amount:float)->float:
	if rank("zombie")>=3 and game.health<40:rage_left=3.0
	return amount*(1.0-minf(0.65,rank("zombie")*0.10+rank("armor")*0.08))

func revive()->bool:
	if rank("zombie")<4 or revivals>0:return false
	revivals+=1;game.health=45;rage_left=4;game.notice.text="不死复苏！本局唯一复苏已使用";return true

func visible_target(origin:Vector3,target:Node3D,reach:float)->bool:
	if not is_instance_valid(target) or target.get_meta("captured",false):return false
	var aim:=target.global_position+Vector3.UP*0.15
	if origin.distance_squared_to(aim)>reach*reach:return false
	var ray:=PhysicsRayQueryParameters3D.create(origin,aim,1)
	return game.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func active_bite()->void:
	organs.bite()
	if rank("kraken")==0 or grab_cooldown>0 or choosing or finished:return
	grab_cooldown=BALANCE.KRAKEN_INTERVAL[rank("kraken")]
	var origin:Vector3=game.visual.global_position+Vector3.UP*0.25*game.growth
	var reach:float=(2.3+rank("kraken")*0.65)*game.growth
	var caught:=0
	for i in range(game.targets.size()-1,-1,-1):
		var target:Node3D=game.targets[i]
		if visible_target(origin,target,reach):
			organs.grab(target.global_position)
			if game._capture_target(i,"kraken"):caught+=1
			if caught>=rank("kraken"):break

func update(dt:float)->void:
	if finished or choosing or briefing or game.paused:return
	seconds+=dt;rage_left=maxf(0,rage_left-dt);grab_cooldown=maxf(0,grab_cooldown-dt);mouth_cooldown-=dt;primary_cooldown=maxf(0,primary_cooldown-dt)
	organs.animate(dt)
	if seconds>=duration and landmark.collapse_age<0:finish(false,"撤离完成 · 捕猎时间耗尽");return
	if mouth_cooldown<=0 and rank("hydra")>0:
		mouth_cooldown=0.10
		var caught:=0
		for offset in organs.heads.size():
			var socket:Node3D=organs.heads[(mouth_cursor+offset)%organs.heads.size()]
			var mouth:Vector3=socket.global_position
			for i in range(game.targets.size()-1,-1,-1):
				if visible_target(mouth,game.targets[i],game.growth*0.95):
					game.targets[i].set_meta("mutation_socket",weakref(socket))
					organs.bite()
					if game._capture_target(i,"hydra"):caught+=1
					break
			if caught>=BALANCE.HYDRA_BATCH[rank("hydra")]:break
		if caught>0:
			mouth_cooldown=BALANCE.HYDRA_INTERVAL
			mouth_cursor=(mouth_cursor+1)%organs.heads.size()
	landmark.update(dt);refresh_hud()

func refresh_hud()->void:
	if not is_instance_valid(hud):return
	var left:=maxi(0,ceili(duration-seconds))
	hud.text="畸变鲨潮  /  小城镇\n%02d:%02d  ·  生命 %03d  ·  %06d 分\n%s  ·  体型 %.2f×"%[left/60,left%60,ceili(game.health),game.score,build_name(),game.growth]
	var next:int=THRESHOLDS[picks] if picks<THRESHOLDS.size() else THRESHOLDS[-1]
	var previous:int=THRESHOLDS[picks-1] if picks>0 else 0
	progress.max_value=maxi(1,next-previous);progress.value=game.eaten-previous
	var delta:Vector3=landmark.global_position-game.player.position;delta.y=0
	var direction:=Vector2(delta.dot(game.camera.global_basis.x),delta.dot(game.camera.global_basis.z)).normalized()
	var arrow:="↓" if absf(direction.y)>absf(direction.x) and direction.y>0 else "↑" if absf(direction.y)>absf(direction.x) else "→" if direction.x>0 else "←"
	var evolution_text:="进化 %d / 10  ·  吞食 %d / %d"%[picks,game.eaten,next] if picks<THRESHOLDS.size() else "进化已满  ·  吞食 %d"%game.eaten
	goal.text="终局目标  %s  钟塔 %dm\n%s\n%s"%[arrow,int(delta.length()),"Shift 冲刺命中 %d / 3"%landmark.hits if game.growth>=3.199 else "吞食 %d 人，长成 3.2× 巨兽"%BALANCE.MAX_GROWTH_MEALS,evolution_text]

func finish(won:bool,reason:String)->void:
	if finished:return
	finished=true;choosing=false;game.paused=true;get_tree().paused=true;game.pause_label.hide()
	if won:game.score+=maxi(0,int(duration-seconds))*20
	records.best_score=maxi(int(records.best_score),game.score);records.best_eaten=maxi(int(records.best_eaten),game.eaten)
	if won:records.wins=int(records.wins)+1
	var file:=FileAccess.open(record_path,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify(records))
	var report_path:="user://shark_last_run.json" if record_path==SAVE_PATH else "user://roguelite_test_last_run.json"
	var report:=FileAccess.open(report_path,FileAccess.WRITE)
	if report:report.store_string(JSON.stringify({"balance":BALANCE.VERSION,"won":won,"reason":reason,"seconds":seconds,"eaten":game.eaten,"growth":game.growth,"ranks":ranks,"choices":pick_history},"  "))
	clear_panel();heading("城市沦陷" if won else "捕猎结束",36,Color(1,0.76,0.35));heading(reason,20)
	heading("%06d 分    ·    吞食 %d 人    ·    破坏 %d 件"%[game.score,game.eaten,game.wrecked],23)
	heading("存活 %02d:%02d    /    %s"%[int(seconds)/60,int(seconds)%60,build_name()],19)
	var upgrades:PackedStringArray=[]
	for id in SUPPORTS:
		if rank(id)>0:upgrades.append("%s %d"%[NAMES[id],rank(id)])
	if not upgrades.is_empty():heading(" · ".join(upgrades),16)
	heading("最高纪录 %06d    ·    城市通关 %d 次"%[records.best_score,records.wins],18)
	var retry:=Button.new();retry.text="再次变异  /  R";retry.custom_minimum_size.y=54;content.add_child(retry);retry.pressed.connect(restart);retry.grab_focus();shade.show();refresh_hud()

func restart()->void:
	get_tree().paused=false;get_tree().reload_current_scene()

func tint(id:String)->Color:
	if id=="hydra":return Color(1,0.73,0.30)
	if id=="kraken":return Color(0.76,0.60,1)
	if id=="zombie":return Color(0.63,0.88,0.37)
	return Color(0.39,0.83,0.87)

func style(color:Color)->StyleBoxFlat:
	var s:=StyleBoxFlat.new();s.bg_color=Color(0.035,0.075,0.10,0.97);s.border_color=color
	s.set_border_width_all(2);s.set_corner_radius_all(12);s.content_margin_left=22;s.content_margin_right=22;s.content_margin_top=20;s.content_margin_bottom=20
	return s

func heading(text:String,size:int,color:Color=Color(0.85,0.94,0.94))->Label:
	var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",size);label.modulate=color;label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER;content.add_child(label);return label

func clear_panel()->void:
	buttons.clear()
	for child in content.get_children():content.remove_child(child);child.queue_free()

func show_choices()->void:
	clear_panel();heading("选择你的畸变",34,Color(0.95,0.85,0.63));heading("进化 %02d / 10   ·   %s"%[picks+1,build_name()],18)
	heading("主系四阶 / 副系二阶 · 二/三/四阶在第 3/6/9 次升级开放 · 战斗已暂停",15)
	var row:=HBoxContainer.new();row.add_theme_constant_override("separation",16);content.add_child(row)
	for i in offers.size():
		var id:=offers[i];var button:=Button.new();button.custom_minimum_size=Vector2(250,275);button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		button.add_theme_stylebox_override("normal",style(tint(id)*Color(0.6,0.6,0.6,1)))
		button.add_theme_stylebox_override("hover",style(tint(id)));button.add_theme_stylebox_override("focus",style(tint(id)))
		var text:=Label.new();text.mouse_filter=Control.MOUSE_FILTER_IGNORE;text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);text.offset_left=18;text.offset_right=-18;text.offset_top=14;text.offset_bottom=-14;text.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		var name_text:String=TITLES[id][rank(id)] if id in FAMILIES else NAMES[id]
		text.text="0%d  /  %s\n\n%s  %s\n\n%s"%[i+1,"身体变异" if id in FAMILIES else "辅助器官",name_text,"ⅠⅡⅢⅣ"[rank(id)],description(id)]
		text.add_theme_font_size_override("font_size",18);text.modulate=tint(id);button.add_child(text);row.add_child(button);button.pressed.connect(choose.bind(i));buttons.append(button)
	var reroll_button:=Button.new();reroll_button.text="重选一次  ·  剩余 %d"%rerolls;reroll_button.disabled=rerolls==0 or picks==0;reroll_button.pressed.connect(reroll);content.add_child(reroll_button)
	heading("点击卡片 / 1 · 2 · 3 选择    |    方向键与 Enter 亦可",15)
	shade.show();buttons[0].grab_focus()

func build_ui()->void:
	game.status.get_parent().get_parent().hide();game.feed_label.get_parent().hide();game.combo_label.hide()
	for old in game.status.get_parent().get_parent().get_parent().get_children():
		if old is Label and old!=game.notice and old!=game.pause_label:old.hide()
	game.notice.position=Vector2(24,158)
	ui=CanvasLayer.new();ui.layer=8;add_child(ui)
	var root:=Control.new();root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.mouse_filter=Control.MOUSE_FILTER_IGNORE;ui.add_child(root)
	var theme:=Theme.new();var font:=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI","Microsoft YaHei","Arial"]);theme.default_font=font;theme.default_font_size=18;root.theme=theme
	var top:=PanelContainer.new();top.position=Vector2(20,18);top.custom_minimum_size=Vector2(490,130);top.add_theme_stylebox_override("panel",style(Color(0.19,0.48,0.51)));top.mouse_filter=Control.MOUSE_FILTER_IGNORE;root.add_child(top)
	var stack:=VBoxContainer.new();top.add_child(stack);hud=Label.new();stack.add_child(hud);progress=ProgressBar.new();progress.custom_minimum_size.y=7;progress.show_percentage=false;stack.add_child(progress)
	var objective:=PanelContainer.new();root.add_child(objective);objective.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);objective.offset_left=-430;objective.offset_right=-20;objective.offset_top=18;objective.add_theme_stylebox_override("panel",style(Color(0.59,0.42,0.17)));objective.mouse_filter=Control.MOUSE_FILTER_IGNORE
	goal=Label.new();goal.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;objective.add_child(goal)
	var controls:=Label.new();root.add_child(controls);controls.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE);controls.offset_left=24;controls.offset_top=-42;controls.text="WASD 游动   /   Shift 冲撞   /   空格跃起   /   E 捕食与触手   /   Esc 暂停   /   F1 帮助";controls.add_theme_font_size_override("font_size",16)
	shade=ColorRect.new();shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.color=Color(0.01,0.025,0.04,0.91);root.add_child(shade)
	var center:=CenterContainer.new();center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);shade.add_child(center)
	panel=PanelContainer.new();panel.custom_minimum_size=Vector2(870,0);panel.add_theme_stylebox_override("panel",style(Color(0.21,0.42,0.46)));center.add_child(panel)
	content=VBoxContainer.new();content.add_theme_constant_override("separation",16);panel.add_child(content);shade.hide()

func _input(event:InputEvent)->void:
	if not (choosing or finished or briefing):return
	if event is InputEventKey and event.pressed and not event.echo:
		if briefing and event.physical_keycode==KEY_ENTER:start_run();get_viewport().set_input_as_handled();return
		if finished and event.physical_keycode==KEY_R:restart();get_viewport().set_input_as_handled();return
		if choosing and event.physical_keycode in [KEY_1,KEY_2,KEY_3]:choose(event.physical_keycode-KEY_1);get_viewport().set_input_as_handled();return
		if event.physical_keycode in [KEY_ESCAPE,KEY_R,KEY_F2]:get_viewport().set_input_as_handled()
