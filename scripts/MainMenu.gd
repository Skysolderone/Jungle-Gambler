extends Control

# 引用UI元素
@onready var login_panel = $LoginPanel
@onready var register_panel = $RegisterPanel
@onready var settings_panel = $SettingsPanel
@onready var message_dialog = $MessageDialog
@onready var background = $Background

# 登录面板元素
@onready var login_username = $LoginPanel/VBoxContainer/FormMargin/Form/UsernameInput
@onready var login_password = $LoginPanel/VBoxContainer/FormMargin/Form/PasswordInput

# 注册面板元素
@onready var register_username = $RegisterPanel/VBoxContainer/FormMargin/Form/UsernameInput
@onready var register_password = $RegisterPanel/VBoxContainer/FormMargin/Form/PasswordInput
@onready var register_confirm_password = $RegisterPanel/VBoxContainer/FormMargin/Form/ConfirmPasswordInput

# 设置面板元素
@onready var music_slider = $SettingsPanel/VBoxContainer/SettingsMargin/Settings/MusicControl/MusicSlider
@onready var sound_slider = $SettingsPanel/VBoxContainer/SettingsMargin/Settings/SoundControl/SoundSlider
@onready var brightness_slider = $SettingsPanel/VBoxContainer/SettingsMargin/Settings/BrightnessControl/BrightnessSlider
@onready var fullscreen_checkbox = $SettingsPanel/VBoxContainer/SettingsMargin/Settings/FullscreenControl/FullscreenCheckbox
@onready var theme_option = $SettingsPanel/VBoxContainer/SettingsMargin/Settings/ThemeControl/ThemeOptionButton
@onready var brightness_overlay = $BrightnessOverlay

# 用户数据存储路径
const USER_DATA_PATH = "user://users.json"

func _ready():
	# 确保所有面板初始状态为隐藏
	login_panel.visible = false
	register_panel.visible = false
	settings_panel.visible = false
	
	# 连接主题变更信号（如果 ThemeManager 存在）
	if has_node("/root/ThemeManager"):
		get_node("/root/ThemeManager").theme_changed.connect(_on_theme_changed)
		_apply_theme()
	
	# 初始化设置
	_load_settings()

# ========== 主菜单按钮 ==========

func _on_login_button_pressed():
	login_panel.visible = true
	login_username.clear()
	login_password.clear()
	login_username.grab_focus()

func _on_register_button_pressed():
	register_panel.visible = true
	register_username.clear()
	register_password.clear()
	register_confirm_password.clear()
	register_username.grab_focus()

func _on_settings_button_pressed():
	settings_panel.visible = true

func _on_exit_button_pressed():
	get_tree().quit()

# ========== 登录面板 ==========

func _on_login_confirm_pressed():
	# 调试模式：直接创建测试用户并登录
	var debug_mode = true
	
	if debug_mode:
		var test_user = "test_debug"
		# 如果测试用户不存在，创建它
		if not _user_exists(test_user):
			_register_user(test_user, "debug123")
		# 登录测试用户
		UserSession.login(test_user)
		# 跳转到大厅
		get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
		return
	
	# 正常登录流程
	var username = login_username.text.strip_edges()
	var password = login_password.text
	
	if username.is_empty():
		_show_message("请输入用户名")
		return
	
	if password.is_empty():
		_show_message("请输入密码")
		return
	
	# 验证用户凭据
	if _verify_user(username, password):
		# 登录到用户会话
		UserSession.login(username)
		# 跳转到大厅
		get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
	else:
		_show_message("用户名或密码错误")

func _on_login_cancel_pressed():
	login_panel.visible = false

# ========== 注册面板 ==========

func _on_register_confirm_pressed():
	var username = register_username.text.strip_edges()
	var password = register_password.text
	var confirm_password = register_confirm_password.text
	
	if username.is_empty():
		_show_message("请输入用户名")
		return
	
	if username.length() < 3:
		_show_message("用户名至少需要3个字符")
		return
	
	if password.is_empty():
		_show_message("请输入密码")
		return
	
	if password.length() < 6:
		_show_message("密码至少需要6个字符")
		return
	
	if password != confirm_password:
		_show_message("两次输入的密码不一致")
		return
	
	# 检查用户是否已存在
	if _user_exists(username):
		_show_message("该用户名已被注册")
		return
	
	# 注册新用户
	if _register_user(username, password):
		_show_message("注册成功！正在为您登录...")
		register_panel.visible = false
		# 自动登录并跳转到大厅
		UserSession.login(username)
		get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
	else:
		_show_message("注册失败，请重试")

func _on_register_cancel_pressed():
	register_panel.visible = false

# ========== 设置面板 ==========

func _on_music_slider_changed(value: float):
	# 调整音乐音量
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx == -1:
		bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))
	_save_settings()

func _on_sound_slider_changed(value: float):
	# 调整音效音量
	var bus_idx = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))
	_save_settings()

func _on_brightness_slider_changed(value: float):
	# 调整屏幕亮度（通过黑色覆盖层的透明度）
	# value范围：30-100，值越小越暗
	# alpha范围：0-0.7，值越大越暗
	var alpha = (100.0 - value) / 100.0 * 0.7
	brightness_overlay.color = Color(0, 0, 0, alpha)
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

func _on_settings_close_pressed():
	settings_panel.visible = false

# ========== 用户数据管理 ==========

func _load_users() -> Dictionary:
	if not FileAccess.file_exists(USER_DATA_PATH):
		return {}
	
	var file = FileAccess.open(USER_DATA_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			return json.get_data()
	
	return {}

func _save_users(users: Dictionary) -> bool:
	var file = FileAccess.open(USER_DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(users, "\t"))
		file.close()
		return true
	return false

func _user_exists(username: String) -> bool:
	var users = _load_users()
	return users.has(username)

func _verify_user(username: String, password: String) -> bool:
	var users = _load_users()
	if users.has(username):
		# 简单的密码验证（实际项目中应该使用加密）
		return users[username]["password"] == password.sha256_text()
	return false

func _register_user(username: String, password: String) -> bool:
	var users = _load_users()
	users[username] = {
		"password": password.sha256_text(),  # 使用SHA256加密密码
		"created_at": Time.get_datetime_string_from_system()
	}
	return _save_users(users)

# ========== 设置管理 ==========

const SETTINGS_PATH = "user://settings.json"

func _load_settings():
	var settings = {
		"music_volume": 80.0,
		"sound_volume": 80.0,
		"brightness": 100.0,
		"fullscreen": false
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
	
	# 应用音频设置
	_on_music_slider_changed(music_slider.value)
	_on_sound_slider_changed(sound_slider.value)
	_on_brightness_slider_changed(brightness_slider.value)
	
	# 应用全屏设置
	if fullscreen_checkbox.button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

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

# ========== 主题管理 ==========

func _apply_theme():
	# 应用背景颜色
	if has_node("/root/ThemeManager"):
		background.color = get_node("/root/ThemeManager").get_color("background")

func _on_theme_changed(_new_theme):
	_apply_theme()

# ========== 消息提示 ==========

func _show_message(text: String):
	message_dialog.dialog_text = text
	message_dialog.popup_centered()
