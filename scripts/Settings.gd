extends Control

signal settings_closed
signal brightness_changed(value: float)

@onready var music_slider = $MainPanel/VBoxContainer/SettingsMargin/Settings/MusicControl/MusicSlider
@onready var sound_slider = $MainPanel/VBoxContainer/SettingsMargin/Settings/SoundControl/SoundSlider
@onready var brightness_slider = $MainPanel/VBoxContainer/SettingsMargin/Settings/BrightnessControl/BrightnessSlider
@onready var fullscreen_checkbox = $MainPanel/VBoxContainer/SettingsMargin/Settings/FullscreenControl/FullscreenCheckbox
@onready var theme_option = $MainPanel/VBoxContainer/SettingsMargin/Settings/ThemeControl/ThemeOptionButton

const SETTINGS_PATH = "user://settings.json"

func _ready():
	# 应用像素风格
	_apply_pixel_style()

	# 应用响应式布局
	_setup_responsive_layout()

	_load_settings()

func _apply_pixel_style():
	"""应用像素艺术风格到设置场景"""
	if not has_node("/root/PixelStyleManager"):
		push_warning("PixelStyleManager 未加载，跳过像素风格应用")
		return

	var pixel_style = get_node("/root/PixelStyleManager")

	# 应用主面板像素风格
	var main_panel = $MainPanel
	pixel_style.apply_pixel_panel_style(main_panel, "DARK_GREY")

	# 应用标签像素风格
	var title_label = $MainPanel/VBoxContainer/TitleMargin/Title
	if title_label:
		pixel_style.apply_pixel_label_style(title_label, "YELLOW", true, 32)

	# 音乐音量标签
	var music_label = $MainPanel/VBoxContainer/SettingsMargin/Settings/MusicControl/MusicLabel
	if music_label:
		pixel_style.apply_pixel_label_style(music_label, "WHITE", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)

	# 音效音量标签
	var sound_label = $MainPanel/VBoxContainer/SettingsMargin/Settings/SoundControl/SoundLabel
	if sound_label:
		pixel_style.apply_pixel_label_style(sound_label, "WHITE", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)

	# 亮度标签
	var brightness_label = $MainPanel/VBoxContainer/SettingsMargin/Settings/BrightnessControl/BrightnessLabel
	if brightness_label:
		pixel_style.apply_pixel_label_style(brightness_label, "WHITE", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)

	# 全屏标签
	var fullscreen_label = $MainPanel/VBoxContainer/SettingsMargin/Settings/FullscreenControl/FullscreenLabel
	if fullscreen_label:
		pixel_style.apply_pixel_label_style(fullscreen_label, "WHITE", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)

	# 主题标签
	var theme_label = $MainPanel/VBoxContainer/SettingsMargin/Settings/ThemeControl/ThemeLabel
	if theme_label:
		pixel_style.apply_pixel_label_style(theme_label, "WHITE", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)

	# 应用滑块像素风格
	if music_slider:
		pixel_style.apply_pixel_slider_style(music_slider)
	if sound_slider:
		pixel_style.apply_pixel_slider_style(sound_slider)
	if brightness_slider:
		pixel_style.apply_pixel_slider_style(brightness_slider)

	# 应用关闭按钮像素风格
	var close_button = $MainPanel/VBoxContainer/SettingsMargin/Settings/CloseButton
	if close_button:
		pixel_style.apply_pixel_button_style(close_button, "RED", pixel_style.PIXEL_FONT_SIZE_NORMAL)

	# 应用复选框像素风格（如果有）
	if fullscreen_checkbox:
		_apply_checkbox_pixel_style(fullscreen_checkbox, pixel_style)

	# 应用选项按钮像素风格（如果有）
	if theme_option:
		_apply_option_button_pixel_style(theme_option, pixel_style)

func _apply_checkbox_pixel_style(checkbox: CheckButton, pixel_style):
	"""为复选框应用像素风格"""
	# 使用 PixelStyleManager 的内置函数
	pixel_style.apply_pixel_checkbox_style(checkbox)

func _apply_option_button_pixel_style(option_button: OptionButton, pixel_style):
	"""为选项按钮应用像素风格"""
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = pixel_style.PIXEL_PALETTE["DARK_GREY"]
	style_normal.set_border_width_all(2)
	style_normal.border_color = pixel_style.PIXEL_PALETTE["GREY"]
	style_normal.set_corner_radius_all(0)
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	style_normal.content_margin_top = 6
	style_normal.content_margin_bottom = 6
	option_button.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = pixel_style.PIXEL_PALETTE["GREY"]
	style_hover.set_border_width_all(2)
	style_hover.border_color = pixel_style.PIXEL_PALETTE["WHITE"]
	style_hover.set_corner_radius_all(0)
	style_hover.content_margin_left = 8
	style_hover.content_margin_right = 8
	style_hover.content_margin_top = 6
	style_hover.content_margin_bottom = 6
	option_button.add_theme_stylebox_override("hover", style_hover)

	# 文字颜色
	option_button.add_theme_color_override("font_color", pixel_style.PIXEL_PALETTE["WHITE"])
	option_button.add_theme_color_override("font_hover_color", pixel_style.PIXEL_PALETTE["YELLOW"])

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		
		# 连接屏幕类型变化信号
		responsive_manager.screen_type_changed.connect(_on_screen_type_changed)
		
		# 应用响应式布局
		responsive_manager.apply_responsive_layout(self)
		
		# 为移动端优化触摸
		responsive_manager.optimize_for_touch(self)
		
		print("设置界面已启用响应式布局，屏幕类型：", responsive_manager.get_screen_type_name())

func _on_screen_type_changed(_new_type):
	# 屏幕类型变化时重新应用布局
	_setup_responsive_layout()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_close_button_pressed()
			get_viewport().set_input_as_handled()

func _load_settings():
	var settings = {
		"music_volume": 80.0,
		"sound_volume": 80.0,
		"brightness": 100.0,
		"fullscreen": false,
		"theme": 0
	}
	
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(json_string) == OK:
				settings = json.get_data()
	
	# 应用设置
	music_slider.value = settings.get("music_volume", 80.0)
	sound_slider.value = settings.get("sound_volume", 80.0)
	brightness_slider.value = settings.get("brightness", 100.0)
	fullscreen_checkbox.button_pressed = settings.get("fullscreen", false)
	theme_option.selected = settings.get("theme", 0)
	
	# 立即应用音频和亮度设置（但不保存）
	_apply_music_volume(music_slider.value)
	_apply_sound_volume(sound_slider.value)
	_apply_brightness(brightness_slider.value)

func _save_settings():
	var theme_value = 0
	if has_node("/root/ThemeManager"):
		theme_value = get_node("/root/ThemeManager").current_theme
	
	var settings = {
		"music_volume": music_slider.value,
		"sound_volume": sound_slider.value,
		"brightness": brightness_slider.value,
		"fullscreen": fullscreen_checkbox.button_pressed,
		"theme": theme_value
	}
	
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

func _apply_music_volume(value: float):
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx == -1:
		bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func _apply_sound_volume(value: float):
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))

func _apply_brightness(value: float):
	brightness_changed.emit(value)

func _on_music_slider_changed(value: float):
	_apply_music_volume(value)
	_save_settings()

func _on_sound_slider_changed(value: float):
	_apply_sound_volume(value)
	_save_settings()

func _on_brightness_slider_changed(value: float):
	_apply_brightness(value)
	_save_settings()

func _on_fullscreen_toggled(button_pressed: bool):
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()

func _on_theme_option_selected(index: int):
	if has_node("/root/ThemeManager"):
		get_node("/root/ThemeManager").set_theme(index)
	_save_settings()

func _on_close_button_pressed():
	settings_closed.emit()
