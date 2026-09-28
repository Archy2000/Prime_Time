extends RefCounted
## Reconstructed shallow water. Evidence: research/sand_water, not recovered C#.
const N:=160
const STEP:=1.0/30.0
var extent:=144.0
var origin:=Vector2(-72,-88)
var cell:=0.9
var level:=1.15
var height:=PackedFloat32Array()
var floor_height:=PackedFloat32Array()
var base_floor:=PackedFloat32Array()
var vx:=PackedFloat32Array()
var vz:=PackedFloat32Array()
var foam:=PackedFloat32Array()
var next_foam:=PackedFloat32Array()
var impact:=PackedFloat32Array()
var solid:=PackedByteArray()
var rgba:=PackedFloat32Array()
var flow_rgba:=PackedFloat32Array()
var texture:ImageTexture
var flow_texture:ImageTexture
var accumulator:=0.0
var clock:=0.0
var swell_amplitude:=0.16
var swell_period:=5.5
var total_impulses:=0
var last_step_ms:=0.0
var max_height:=0.0

func _init()->void:
	height.resize(N*N);floor_height.resize(N*N);base_floor.resize(N*N)
	vx.resize(N*N);vz.resize(N*N);foam.resize(N*N);next_foam.resize(N*N);solid.resize(N*N)
	impact.resize(N*N)
	base_floor.fill(-0.3);floor_height.fill(-0.3)
	rgba.resize(N*N*4);flow_rgba.resize(N*N*4)
	texture=ImageTexture.create_from_image(Image.create_from_data(N,N,false,Image.FORMAT_RGBAF,rgba.to_byte_array()))
	flow_texture=ImageTexture.create_from_image(Image.create_from_data(N,N,false,Image.FORMAT_RGBAF,flow_rgba.to_byte_array()))

func configure(size:float,start:Vector2,water_y:float)->void:
	extent=size;origin=start;cell=extent/float(N);level=water_y

func set_obstacles(boxes:Array,water_y:float)->void:
	level=water_y;solid.fill(0);floor_height=base_floor.duplicate()
	for b:AABB in boxes:
		if b.position.y>level+0.6:continue
		var lo:=Vector2i((Vector2(b.position.x,b.position.z)-origin)/cell)
		var hi:=Vector2i((Vector2(b.end.x,b.end.z)-origin)/cell)
		for z in range(maxi(0,lo.y),mini(N,hi.y+1)):
			for x in range(maxi(0,lo.x),mini(N,hi.x+1)):
				var i:=z*N+x
				floor_height[i]=maxf(floor_height[i],b.end.y)
	for i in N*N:
		if floor_height[i]>level+0.48:
			solid[i]=1;height[i]=0;vx[i]=0;vz[i]=0;foam[i]=0;next_foam[i]=0;impact[i]=0

func seed_swell()->void:
	for z in N:
		for x in N:
			var i:=z*N+x
			if solid[i]>0:continue
			var depth:=clampf(level-floor_height[i],0,3)
			var phase:float=float(z)*cell*TAU/22.0
			height[i]=swell_amplitude*(pow(maxf(0,sin(phase)),3)-0.212)*smoothstep(0,0.5,depth)
			vz[i]=-height[i]*sqrt(7.0/maxf(depth,0.15))

func disturb(pos:Vector3,radius:float,power:float,white:float=0.0,momentum:Vector2=Vector2.ZERO)->void:
	var p:Vector2=(Vector2(pos.x,pos.z)-origin)/cell
	var r:float=maxf(1.15,radius/cell)
	# The numerical footprint must span a cell, but a small swimmer must not
	# displace a metre-wide column at full strength just because the grid is coarse.
	var footprint:float=minf(1.0,pow(maxf(radius,0.0)/(r*cell),2.0))
	for z in range(maxi(1,int(p.y-r-1)),mini(N-1,int(p.y+r+2))):
		for x in range(maxi(1,int(p.x-r-1)),mini(N-1,int(p.x+r+2))):
			var d:float=Vector2(x-p.x,z-p.y).length()/r
			if d>=1:continue
			var i:=z*N+x
			if solid[i]>0:continue
			var w:float=(1-d*d)*(1-d*d)*footprint
			height[i]=clampf(height[i]+w*power,-0.45,0.65)
			foam[i]=minf(1,foam[i]+w*white)
			vx[i]=clampf(vx[i]+momentum.x*w,-3,3);vz[i]=clampf(vz[i]+momentum.y*w,-3,3)
	total_impulses+=1

func sample_surface(pos:Vector3)->Vector3:
	var p:Vector2=(Vector2(pos.x,pos.z)-origin)/cell
	var x:=clampi(int(p.x),1,N-2);var z:=clampi(int(p.y),1,N-2);var i:=z*N+x
	return Vector3(vx[i],height[i],vz[i])

func swimmer(pos:Vector3,velocity:Vector3,size:float,dt:float)->void:
	var speed:=velocity.length()
	if speed<0.15:return
	var d:=velocity.normalized();var side:=d.cross(Vector3.UP)
	var body_scale:=clampf(size,0.0,1.0)
	var force:=minf(speed/9.0,1.6)*dt*14.0*body_scale
	var flow:=Vector2(velocity.x,velocity.z)*0.08*dt*14.0*body_scale
	disturb(pos+d*0.75*size,0.55*size,0.06*force,0.015*force,flow)
	disturb(pos-d*0.85*size,0.55*size,-0.05*force,0.025*force,flow*0.6)
	for sign_value in [-1.0,1.0]:
		var lateral:Vector3=side*sign_value
		disturb(pos-d*0.35*size+lateral*0.6*size,0.5*size,0.025*force,0.02*force,flow+Vector2(lateral.x,lateral.z)*force*0.3)

func update(dt:float)->void:
	accumulator=minf(accumulator+dt,STEP*3)
	if accumulator<STEP:return
	var started:=Time.get_ticks_usec()
	var steps:=mini(1,int(accumulator/STEP))
	for _s in steps:
		accumulator-=STEP;_step()
	for i in N*N:
		rgba[i*4]=height[i];rgba[i*4+1]=floor_height[i];rgba[i*4+2]=foam[i];rgba[i*4+3]=float(solid[i])
		flow_rgba[i*4]=vx[i];flow_rgba[i*4+1]=vz[i]
		flow_rgba[i*4+3]=impact[i]
	texture.update(Image.create_from_data(N,N,false,Image.FORMAT_RGBAF,rgba.to_byte_array()))
	flow_texture.update(Image.create_from_data(N,N,false,Image.FORMAT_RGBAF,flow_rgba.to_byte_array()))
	last_step_ms=float(Time.get_ticks_usec()-started)/1000.0

func _step()->void:
	clock+=STEP
	var factor:=7.0*STEP/cell
	var impact_decay:=exp(-STEP*5.0)
	var foam_decay:=exp(-STEP*1.05)
	for z in range(1,N-1):
		for x in range(1,N-1):
			var i:=z*N+x
			if solid[i]>0:vx[i]=0;vz[i]=0;continue
			var surface:=maxf(level+height[i],floor_height[i])
			var sx:=maxf(floor_height[i],floor_height[i+1]);var sz:=maxf(floor_height[i],floor_height[i+N])
			var dx:=maxf(0,level+height[i+1]-sx)-maxf(0,surface-sx)
			var dz:=maxf(0,level+height[i+N]-sz)-maxf(0,surface-sz)
			vx[i]=0.0 if solid[i+1]>0 else clampf((vx[i]-factor*dx)*0.995,-3,3)
			vz[i]=0.0 if solid[i+N]>0 else clampf((vz[i]-factor*dz)*0.995,-3,3)
	# Conservative face flux; scratch heights avoid directional update bias.
	for z in range(1,N-1):
		for x in range(1,N-1):
			var i:=z*N+x
			if solid[i]>0:continue
			var h:float=height[i]
			var dr:=clampf(level+(h+height[i+1])*0.5-maxf(floor_height[i],floor_height[i+1]),0,3)
			var dl:=clampf(level+(h+height[i-1])*0.5-maxf(floor_height[i],floor_height[i-1]),0,3)
			var dd:=clampf(level+(h+height[i+N])*0.5-maxf(floor_height[i],floor_height[i+N]),0,3)
			var du:=clampf(level+(h+height[i-N])*0.5-maxf(floor_height[i],floor_height[i-N]),0,3)
			var change:float=-STEP/cell*(vx[i]*dr-vx[i-1]*dl+vz[i]*dd-vz[i-N]*du)
			flow_rgba[i*4+2]=maxf(floor_height[i]-level,clampf(h+change,-0.65,0.85))
			var wet_depth:=maxf(0,level+h-floor_height[i])
			# Use the fluid-side surface at solid neighbours: a wall is not a wave crest.
			var hr:float=h if solid[i+1]>0 else height[i+1]
			var hl:float=h if solid[i-1]>0 else height[i-1]
			var hd:float=h if solid[i+N]>0 else height[i+N]
			var hu:float=h if solid[i-N]>0 else height[i-N]
			var steep:=Vector2(hr-hl,hd-hu).length()/(2.0*cell)
			var speed:=Vector2((vx[i]+vx[i-1])*0.5,(vz[i]+vz[i-N])*0.5).length()
			# Incoming flux piles up against a wall, then the foam lives on in the flow.
			var incoming:=maxf(vx[i-1],0)*float(solid[i+1])+maxf(-vx[i],0)*float(solid[i-1])
			incoming+=maxf(vz[i-N],0)*float(solid[i+N])+maxf(-vz[i],0)*float(solid[i-N])
			var wet:=smoothstep(0.008,0.08,wet_depth)
			var breaking:=smoothstep(0.045,0.20,steep)*smoothstep(0.025,0.20,h)
			var shoaling:=(1.0-smoothstep(0.06,0.32,wet_depth))*smoothstep(0.06,0.42,speed)
			var collision:=incoming*smoothstep(0.001,0.018,maxf(change,0))
			var source:=(breaking*0.16+shoaling*0.65+collision*1.15)*wet
			impact[i]=maxf(impact[i]*impact_decay,clampf(collision*2.0+shoaling*0.4,0,1)*wet)
			var px:=clampf(float(x)-(vx[i]+vx[i-1])*0.5*STEP/cell,1,N-2.001)
			var pz:=clampf(float(z)-(vz[i]+vz[i-N])*0.5*STEP/cell,1,N-2.001)
			var ix:=int(px);var iz:=int(pz);var j:=iz*N+ix
			var advected:float=lerpf(lerpf(foam[j],foam[j+1],px-ix),lerpf(foam[j+N],foam[j+N+1],px-ix),pz-iz)
			next_foam[i]=clampf(advected*foam_decay-STEP*0.008+source*STEP,0,1)*wet
	max_height=0
	for z in range(1,N-1):
		for x in range(1,N-1):
			var i:=z*N+x
			if solid[i]>0:continue
			var edge:=mini(x,N-1-x)
			height[i]=flow_rgba[i*4+2]*lerpf(0.91,0.998,smoothstep(0,8,edge))
			if z<8:height[i]*=lerpf(0.88,1.0,float(z)/8.0)
			foam[i]=next_foam[i];max_height=maxf(max_height,absf(height[i]))
	# Boundary forcing; interior waves travel via flux, not scrolling sine foam.
	var incoming:=swell_amplitude*(pow(maxf(0,sin(clock*TAU/swell_period)),3)-0.212)
	for x in range(1,N-1):
		for z in range(N-3,N-1):
			var i:=z*N+x
			if solid[i]>0:continue
			height[i]=lerpf(height[i],incoming,0.4)
			vz[i]=-incoming*sqrt(7.0/maxf(0.2,level-floor_height[i]))

func energy()->float:
	var sum:=0.0
	for i in N*N:
		if solid[i]==0:sum+=height[i]*height[i]
	return sum
