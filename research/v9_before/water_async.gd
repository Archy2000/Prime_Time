extends "res://scripts/water_hydro.gd"
## Simulation runs off the game thread. Rendering reads only completed snapshots.
var task_id:=-1
var impulses:Array=[]
var pending_obstacles:Array=[]
var pending_level:=1.15
var obstacles_pending:=false
var worker_ms:=0.0
var stopped:=false
var deterministic:=false

func disturb(pos:Vector3,radius:float,power:float,white:float=0.0,momentum:Vector2=Vector2.ZERO)->void:
	impulses.append([pos,radius,power,white,momentum])

func set_obstacles(boxes:Array,water_y:float)->void:
	if task_id<0:super.set_obstacles(boxes,water_y)
	else:pending_obstacles=boxes.duplicate();pending_level=water_y;obstacles_pending=true

func sample_surface(pos:Vector3)->Vector3:
	var p:Vector2=(Vector2(pos.x,pos.z)-origin)/cell
	var x:=clampi(int(p.x),1,N-2);var z:=clampi(int(p.y),1,N-2);var i:=z*N+x
	return Vector3(flow_rgba[i*4],rgba[i*4],flow_rgba[i*4+1])

func update(dt:float)->void:
	if stopped:return
	if deterministic:
		for p in impulses:super.disturb(p[0],p[1],p[2],p[3],p[4])
		impulses.clear();super.update(dt);return
	accumulator=minf(accumulator+dt,STEP*2)
	if task_id>=0:
		if not WorkerThreadPool.is_task_completed(task_id):return
		WorkerThreadPool.wait_for_task_completion(task_id);task_id=-1
		for i in N*N:
			rgba[i*4]=height[i];rgba[i*4+1]=floor_height[i];rgba[i*4+2]=foam[i];rgba[i*4+3]=float(solid[i])
			flow_rgba[i*4]=vx[i];flow_rgba[i*4+1]=vz[i]
		texture.update(Image.create_from_data(N,N,false,Image.FORMAT_RGBAF,rgba.to_byte_array()))
		flow_texture.update(Image.create_from_data(N,N,false,Image.FORMAT_RGBAF,flow_rgba.to_byte_array()))
		last_step_ms=worker_ms
	if accumulator<STEP:return
	accumulator-=STEP
	if obstacles_pending:super.set_obstacles(pending_obstacles,pending_level);obstacles_pending=false
	for p in impulses:super.disturb(p[0],p[1],p[2],p[3],p[4])
	impulses.clear()
	task_id=WorkerThreadPool.add_task(_worker,false,"Shallow water")

func _worker()->void:
	var begin:=Time.get_ticks_usec();_step();worker_ms=float(Time.get_ticks_usec()-begin)/1000.0

func energy()->float:
	var total:=0.0
	for i in N*N:
		if rgba[i*4+3]<0.5:total+=rgba[i*4]*rgba[i*4]
	return total

func shutdown()->void:
	stopped=true
	if task_id>=0:WorkerThreadPool.wait_for_task_completion(task_id);task_id=-1
