extends Node3D
## Three readable ram hits, then a short controlled collapse.
var game:Node3D
var run:Node
var tower:Node3D
var marker:Label3D
var body:StaticBody3D
var hits:=0
var last_dash:=-1
var collapse_age:=-1.0
var origin:=Vector3(0,0,27)

func box(parent:Node3D,pos:Vector3,size:Vector3,color:Color)->void:
	var n:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=size;n.mesh=shape
	var mat:=StandardMaterial3D.new();mat.albedo_color=color;mat.roughness=0.9;n.material_override=mat;n.position=pos;parent.add_child(n)

func setup(g:Node3D,r:Node)->void:
	game=g;run=r;position=origin;tower=Node3D.new();add_child(tower)
	body=StaticBody3D.new();body.collision_layer=1;add_child(body)
	var collider:=CollisionShape3D.new();var bounds:=BoxShape3D.new();bounds.size=Vector3(2.8,15,2.8);collider.shape=bounds;collider.position.y=7.5;body.add_child(collider)
	box(tower,Vector3(0,0.5,0),Vector3(5.2,1,5.2),Color(0.26,0.3,0.32))
	box(tower,Vector3(0,6,0),Vector3(2.8,11,2.8),Color(0.61,0.49,0.34))
	for y in [3.0,6.0,9.0,11.5]:box(tower,Vector3(0,y,0),Vector3(3.2,0.3,3.2),Color(0.86,0.76,0.53))
	box(tower,Vector3(0,13,0),Vector3(3.6,2.8,3.6),Color(0.2,0.3,0.31))
	var roof:=MeshInstance3D.new();var cone:=CylinderMesh.new();cone.top_radius=0;cone.bottom_radius=3;cone.height=2;cone.radial_segments=4;roof.mesh=cone;roof.position.y=15.4;roof.rotation.y=PI/4;tower.add_child(roof)
	for side in 4:
		var face:=Node3D.new();tower.add_child(face);face.rotation.y=side*PI/2
		box(face,Vector3(0,13,-1.83),Vector3(2.05,2.05,0.08),Color(0.98,0.84,0.43))
		box(face,Vector3(0,13.35,-1.9),Vector3(0.09,0.76,0.09),Color(0.06,0.12,0.15))
		box(face,Vector3(0.3,13,-1.9),Vector3(0.67,0.09,0.09),Color(0.06,0.12,0.15))
	marker=Label3D.new();marker.position.y=18;marker.font_size=64;marker.pixel_size=0.012;marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;marker.no_depth_test=true;add_child(marker)
	var font:=SystemFont.new();font.font_names=PackedStringArray(["Microsoft YaHei UI"]);marker.font=font

func update(dt:float)->void:
	if collapse_age>=0:
		collapse_age+=dt;tower.rotation.z=pow(clampf(collapse_age/2.3,0,1),2)*1.5
		tower.position.y=-maxf(0,collapse_age-1.2)*3
		marker.text="钟塔正在崩塌"
		if collapse_age>=2.7:run.finish(true,"钟塔已毁 · 小城镇沦陷")
		return
	var unlocked:bool=game.growth>=3.199
	marker.text=("冲刺摧毁钟塔  %d / 3"%hits) if unlocked else "终局钟塔 · 体型 3.2× 解锁"
	marker.modulate=Color(1,0.7,0.25) if unlocked else Color(0.65,0.83,0.86)
	var offset:Vector3=game.player.position-global_position;offset.y=0
	if game.boost_time>0 and offset.length()<3.0+game.growth:try_hit()

func try_hit()->bool:
	var distance:Vector3=game.player.position-global_position;distance.y=0
	if distance.length()>3.0+game.growth or game.player.velocity.length()<2.0:return false
	if collapse_age>=0 or game.growth<3.199 or game.boost_time<=0 or last_dash==run.dash_serial:return false
	last_dash=run.dash_serial;hits+=1;game.score+=1500;game.shake=0.75
	game.fx.splash(Vector3(global_position.x,game.water_level,global_position.z),2.0)
	game.notice.text="钟塔结构断裂！%d / 3"%hits
	tower.rotation.z=0.035*hits
	if hits>=3:collapse_age=0;body.collision_layer=0
	return true
