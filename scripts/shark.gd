extends Node3D
## Controller Arts PS1 shark. Gameplay owns position, heading, pitch and growth.
const MODEL = preload("res://assets/characters/shark/SK_Great_White_Shark.glb")
const SWIM: StringName = &"SwimmingAction"
const JUMP: StringName = &"JumpAction"
var animation_player: AnimationPlayer
var was_airborne := false

func _ready() -> void:
	var model: Node3D = MODEL.instantiate()
	model.name = "PS1Shark"
	# Source faces +Z and is 6.83 m long; gameplay faces -Z.
	model.rotation.y = PI
	model.scale = Vector3.ONE * 0.48
	model.position.y = 0.08
	add_child(model)
	for mesh in model.find_children("*", "MeshInstance3D"):
		for surface in mesh.mesh.get_surface_count():
			var material = mesh.get_active_material(surface)
			if material is StandardMaterial3D:
				var retro_material: StandardMaterial3D = material.duplicate()
				# The source GLB uses BLEND although the shark is solid. Transparent
				# sorting can draw it over the screen-reading water while submerged.
				retro_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				retro_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
				retro_material.no_depth_test = false
				retro_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				retro_material.metallic = 0.0
				retro_material.roughness = 1.0
				mesh.set_surface_override_material(surface, retro_material)
	animation_player = model.find_child("AnimationPlayer", true, false)
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	# Duplicate clips so these adjustments never mutate the imported source.
	var library := AnimationLibrary.new()
	var swim: Animation = animation_player.get_animation(SWIM).duplicate(true)
	var jump: Animation = animation_player.get_animation(JUMP).duplicate(true)
	swim.loop_mode = Animation.LOOP_LINEAR
	jump.loop_mode = Animation.LOOP_NONE
	# The authored leap translates/rotates the torso. The controller already does
	# that with collision, so retain its swim pose on these two jump tracks.
	for track in jump.get_track_count():
		if String(jump.track_get_path(track)).ends_with(":Torso_2"):
			var source_track := swim.find_track(jump.track_get_path(track), jump.track_get_type(track))
			if source_track >= 0:
				for key in jump.track_get_key_count(track):
					jump.track_set_key_value(track, key, swim.track_get_key_value(source_track, 0))
	library.add_animation(SWIM, swim)
	library.add_animation(JUMP, jump)
	for name in animation_player.get_animation_library_list():
		animation_player.remove_animation_library(name)
	animation_player.add_animation_library("", library)
	animation_player.play(SWIM)
	animation_player.advance(0.0)

func update_motion(delta: float, speed: float, airborne: bool) -> void:
	if airborne != was_airborne:
		animation_player.play(JUMP if airborne else SWIM, 0.12)
		was_airborne = airborne
	# Slow fin motion at rest, stronger swimming while moving/boosting.
	animation_player.speed_scale = 1.0 if airborne else clampf(0.55 + speed * 0.12, 0.55, 2.1)
	animation_player.advance(delta)
