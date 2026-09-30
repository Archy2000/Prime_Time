extends Node3D
## Water mix shared by city and laboratory. Listener follows gameplay, not the high camera.
const ROOT := "res://assets/audio/water/"
const MAX_VOICES := 16
@export_range(-40, 6) var water_volume_db := 0.0
@export_range(0, 1) var ambient_gain := 0.035
@export_range(0, 1) var motion_gain := 0.10
@export_range(0, 1) var agitation_gain := 0.32
var muted := false
var focus := Vector3.ZERO
var camera: Camera3D
var enabled := true
var clock := 0.0
var moving := 0.0
var intensity := 0.0
var freshness := 0.0
var surge := 0.0
var size := 1.0
var emitted := 0
var rejected := 0
var loops: Array[AudioStreamPlayer] = []
var voices: Array[AudioStreamPlayer3D] = []
var clips: Dictionary = {}
var last_variant: Dictionary = {}
var cooldowns: Dictionary = {}
var rng := RandomNumberGenerator.new()
var listener: AudioListener3D
var last_entry: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	for bus in ["Water", "Water Ambient", "Water Motion", "Water Impacts"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master" if bus == "Water" else "Water")
			if bus == "Water":
				var limiter := AudioEffectLimiter.new()
				limiter.ceiling_db = -2.0
				AudioServer.add_bus_effect(idx, limiter)
	listener = AudioListener3D.new()
	add_child(listener)
	listener.make_current()
	for spec in [["WaterCalm_02", "Water Ambient"], ["SharkGlide", "Water Motion"], ["WaterAgitated_01", "Water Motion"]]:
		var p := AudioStreamPlayer.new()
		var stream := _clip(spec[0]).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		p.stream = stream
		p.bus = spec[1]
		p.volume_db = -80
		add_child(p)
		p.play(rng.randf_range(0, stream.get_length() * 0.8))
		loops.append(p)
	for i in MAX_VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = "Water Impacts"
		p.unit_size = 9.0
		p.max_distance = 65.0
		p.max_db = -3.0
		p.panning_strength = 0.75
		add_child(p)
		voices.append(p)
	for prefix in ["WaterSplashSmall", "WaterSplashMedium", "WaterDrop", "Bubble"]:
		var count := 5 if prefix == "WaterSplashSmall" else (4 if prefix == "WaterSplashMedium" else (5 if prefix == "WaterDrop" else 3))
		for i in range(1, count + 1): _clip("%s_%02d" % [prefix, i])
	for i in range(1, 4): _clip("WaterHeavyEntry_%02d" % i)

func _clip(key: String) -> AudioStream:
	if not clips.has(key): clips[key] = load(ROOT + key + ".wav")
	return clips[key]

func follow(pos: Vector3, view: Camera3D, active: bool = true) -> void:
	focus = pos
	camera = view
	enabled = active
	listener.global_position = pos + Vector3.UP * 1.5
	if is_instance_valid(camera): listener.global_basis = camera.global_basis

func swim(pos: Vector3, velocity: Vector3, body_size: float) -> void:
	focus = pos
	size = body_size
	freshness = 0.12
	moving = clampf(Vector2(velocity.x, velocity.z).length() / 12.0, 0, 1.5)

func _process(dt: float) -> void:
	clock += dt
	freshness -= dt
	surge = move_toward(surge, 0, dt * 0.7)
	var target := moving if freshness > 0 and enabled else 0.0
	intensity = lerpf(intensity, target, 1.0 - exp(-dt * 7.0))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Water"), water_volume_db)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Water"), muted or not enabled)
	_mix(loops[0], ambient_gain if enabled else 0.0, dt, 1.2)
	# Submerged swimming has a soft continuous displacement texture, no repeated slaps.
	_mix(loops[1], minf(intensity, 1.2) * motion_gain, dt, 3.5)
	# Agitated surface water belongs to landings and waves, never ordinary movement.
	_mix(loops[2], surge * agitation_gain if enabled else 0.0, dt, 5.0)
	loops[1].pitch_scale = lerpf(0.96, 1.04, minf(intensity / 1.5, 1.0))

func _mix(p: AudioStreamPlayer, target: float, dt: float, response: float) -> void:
	p.volume_linear = lerpf(p.volume_linear, target, 1.0 - exp(-dt * response))

func shot(prefix: String, count: int, pos: Vector3, db: float, pitch: float, category: String, gap: float) -> void:
	if not enabled or pos.distance_to(focus) > 65 or clock < float(cooldowns.get(category, -1)):
		rejected += 1
		return
	var voice: AudioStreamPlayer3D
	for p in voices:
		if not p.playing:
			voice = p
			break
	if voice == null:
		# Reserve important leap/landing feedback even during a debris shower.
		if category == "breach": voice = voices[0]; voice.stop()
		else: rejected += 1; return
	var variant := rng.randi_range(1, count)
	if variant == int(last_variant.get(prefix, 0)): variant = variant % count + 1
	last_variant[prefix] = variant
	cooldowns[category] = clock + gap
	voice.stream = _clip("%s_%02d" % [prefix, variant])
	voice.global_position = pos
	voice.volume_db = db
	voice.pitch_scale = clampf(pitch * rng.randf_range(0.94, 1.06), 0.60, 1.35)
	voice.play()
	emitted += 1

func splash(pos: Vector3, strength: float) -> void:
	var medium := strength >= 0.85
	shot("WaterSplashMedium" if medium else "WaterSplashSmall", 4 if medium else 5, pos, -17 + clampf(strength, 0, 2) * 3, 1.0 / pow(maxf(strength, 1), 0.15), "splash", 0.065)

func breach(pos: Vector3, body_size: float, vertical_speed: float, landing: bool) -> void:
	var power := clampf(absf(vertical_speed) / 14.0, 0.65, 1.4)
	if landing:
		# Dedicated mass / cavity / collapsing-water composite, separate from takeoff.
		var weight := clampf((body_size - 1.0) / 3.0, 0, 1)
		var pitch := lerpf(1.02, 0.73, weight) * lerpf(1.04, 0.96, (power - 0.65) / 0.75)
		var gain := -5.5 + weight * 2.0 + linear_to_db(power)
		last_entry = {"size": body_size, "speed": absf(vertical_speed), "pitch": pitch, "gain_db": gain}
		shot("WaterHeavyEntry", 3, pos, gain, pitch, "breach", 0.08)
		surge = minf(1.0, power * body_size * 0.45)
		# Leave space for the low impact and collapsing sheet before discrete drops.
		_drips(pos)
	else:
		shot("WaterSplashMedium", 4, pos, -13.0 + minf(body_size - 1, 3) * 1.1 + linear_to_db(power), 1.0 / pow(maxf(body_size, 1), 0.19), "breach", 0.08)

func _drips(pos: Vector3) -> void:
	await get_tree().create_timer(0.38, false).timeout
	for i in 3:
		await get_tree().create_timer(0.16 + i * 0.09, false).timeout
		shot("WaterDrop", 5, pos, -25.0 - i * 2, 0.9, "drips", 0.10)

func wave() -> void:
	surge = 1.0
	splash(focus, 1.3)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F7:
		muted = not muted
		get_viewport().set_input_as_handled()
