extends CanvasLayer
## Scene-only filter; HUD remains above this layer.
const SETTINGS := "user://retro_filter.cfg"
const PARAMETERS := [
	["pixel_size", "像素尺寸", 1.0, 4.0, 0.25, 2.0],
	["contrast", "对比度", 0.8, 1.8, 0.01, 1.32],
	["exposure", "曝光", 0.6, 1.4, 0.01, 0.94],
	["saturation", "饱和度", 0.0, 1.5, 0.01, 0.84],
	["grade_strength", "冷青 / 暖白调色", 0.0, 1.0, 0.01, 0.65],
	["color_levels", "颜色阶数", 8.0, 64.0, 1.0, 32.0],
	["dither_strength", "有序抖色", 0.0, 1.0, 0.01, 0.55],
	["scanline_strength", "扫描线", 0.0, 0.4, 0.01, 0.12],
	["chromatic_strength", "边缘色差", 0.0, 1.5, 0.01, 0.35],
	["bloom_strength", "亮部扩散", 0.0, 0.5, 0.01, 0.12],
	["grain_strength", "静态颗粒", 0.0, 0.05, 0.001, 0.008],
	["vignette_strength", "暗角", 0.0, 0.6, 0.01, 0.18],
]
var material: ShaderMaterial
var rect: ColorRect
var panel: PanelContainer
var values: Dictionary = {}
var sliders: Dictionary = {}
var enabled := true
var toggle: CheckButton

func _ready() -> void:
	layer = 2
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/retro.gdshader")
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	add_child(rect)
	var config := ConfigFile.new()
	config.load(SETTINGS)
	for spec in PARAMETERS:
		var saved = config.get_value("filter", spec[0], spec[5])
		var value := float(saved) if saved is float or saved is int else float(spec[5])
		set_value(spec[0], clampf(value, spec[2], spec[3]))
	enabled = config.get_value("filter", "enabled", true) == true
	if OS.get_cmdline_user_args().has("--clean"): enabled = false
	rect.visible = enabled

func set_value(key: String, value: float) -> void:
	values[key] = value
	material.set_shader_parameter(key, value)

func set_enabled(value: bool) -> void:
	enabled = value
	rect.visible = value
	if is_instance_valid(toggle): toggle.set_pressed_no_signal(value)

func save() -> void:
	var config := ConfigFile.new()
	for key in values: config.set_value("filter", key, values[key])
	config.set_value("filter", "enabled", enabled)
	config.save(SETTINGS)

func reset() -> void:
	for spec in PARAMETERS:
		set_value(spec[0], spec[5])
		if sliders.has(spec[0]): sliders[spec[0]].value = spec[5]
	set_enabled(true)
	save()

func build_panel(parent: Control) -> void:
	panel = PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -388; panel.offset_right = -24
	panel.offset_top = -280; panel.offset_bottom = 280
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.055, 0.97)
	style.content_margin_left = 16; style.content_margin_right = 16
	style.content_margin_top = 12; style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new(); panel.add_child(column)
	var title := Label.new(); title.text = "ROLLA 参考滤镜  /  F3 收起"; column.add_child(title)
	toggle = CheckButton.new(); toggle.text = "启用全部滤镜（Tab）"; toggle.button_pressed = enabled
	toggle.toggled.connect(func(value: bool): set_enabled(value); save())
	column.add_child(toggle)
	for spec in PARAMETERS:
		var row := HBoxContainer.new(); column.add_child(row)
		var label := Label.new(); label.text = spec[1]; label.custom_minimum_size.x = 142; row.add_child(label)
		var slider := HSlider.new(); slider.min_value = spec[2]; slider.max_value = spec[3]; slider.step = spec[4]
		slider.value = values[spec[0]]; slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(slider)
		var number := Label.new(); number.custom_minimum_size.x = 46; number.text = "%.3f" % slider.value; row.add_child(number)
		sliders[spec[0]] = slider
		slider.value_changed.connect(func(value: float): set_value(spec[0], value); number.text = "%.3f" % value)
		slider.drag_ended.connect(func(_changed: bool): save())
	var reset_button := Button.new(); reset_button.text = "恢复参考预设"; reset_button.pressed.connect(reset); column.add_child(reset_button)
	var foot := Label.new(); foot.text = "实时预览 · 收起时自动保存 · UI 保持清晰"; foot.add_theme_font_size_override("font_size", 12); column.add_child(foot)
	panel.visible = false

func toggle_panel() -> void:
	panel.visible = not panel.visible
	if not panel.visible: save()

func _input(event: InputEvent) -> void:
	# Handle shortcuts before focused sliders/buttons consume Tab for navigation.
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_TAB:
			set_enabled(not enabled)
			save()
			get_viewport().set_input_as_handled()
		elif event.physical_keycode == KEY_F3:
			toggle_panel()
			get_viewport().set_input_as_handled()
