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
	_load_settings()

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

