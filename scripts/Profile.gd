extends Control

@onready var username_display = $MainContent/ProfilePanel/ScrollContainer/MarginContainer/VBoxContainer/UsernameSection/UsernameDisplay
@onready var nickname_input = $MainContent/ProfilePanel/ScrollContainer/MarginContainer/VBoxContainer/NicknameSection/NicknameInput
@onready var old_password_input = $MainContent/ProfilePanel/ScrollContainer/MarginContainer/VBoxContainer/PasswordSection/OldPasswordInput
@onready var new_password_input = $MainContent/ProfilePanel/ScrollContainer/MarginContainer/VBoxContainer/PasswordSection/NewPasswordInput
@onready var confirm_password_input = $MainContent/ProfilePanel/ScrollContainer/MarginContainer/VBoxContainer/PasswordSection/ConfirmPasswordInput
@onready var message_dialog = $MessageDialog
@onready var brightness_overlay = $BrightnessOverlay

var current_username: String = ""

const USER_DATA_PATH = "user://users.json"
const SETTINGS_PATH = "user://settings.json"

func _ready():
	if not UserSession.is_logged_in():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	
	# 应用响应式布局
	_setup_responsive_layout()
	
	current_username = UserSession.get_username()
	_load_user_info()
	_apply_brightness_from_settings()

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		
		# 连接屏幕类型变化信号
		responsive_manager.screen_type_changed.connect(_on_screen_type_changed)
		
		# 应用响应式布局
		responsive_manager.apply_responsive_layout(self)
		
		# 为移动端优化触摸
		responsive_manager.optimize_for_touch(self)
		
		print("个人资料界面已启用响应式布局，屏幕类型：", responsive_manager.get_screen_type_name())

func _on_screen_type_changed(_new_type):
	# 屏幕类型变化时重新应用布局
	_setup_responsive_layout()

func _load_user_info():
	# 显示用户名（只读）
	username_display.text = current_username
	
	# 显示当前昵称
	nickname_input.text = UserSession.get_nickname()

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_save_nickname_button_pressed():
	var new_nickname = nickname_input.text.strip_edges()
	
	if new_nickname.is_empty():
		_show_message("昵称不能为空")
		return
	
	if new_nickname.length() < 2:
		_show_message("昵称至少需要2个字符")
		return
	
	if new_nickname.length() > 20:
		_show_message("昵称最多20个字符")
		return
	
	# 保存昵称
	if UserSession.set_nickname(new_nickname):
		_show_message("昵称修改成功！")
	else:
		_show_message("昵称修改失败，请重试")

func _on_save_password_button_pressed():
	var old_password = old_password_input.text
	var new_password = new_password_input.text
	var confirm_password = confirm_password_input.text
	
	if old_password.is_empty():
		_show_message("请输入当前密码")
		return
	
	if new_password.is_empty():
		_show_message("请输入新密码")
		return
	
	if new_password.length() < 6:
		_show_message("新密码至少需要6个字符")
		return
	
	if new_password != confirm_password:
		_show_message("两次输入的新密码不一致")
		return
	
	if old_password == new_password:
		_show_message("新密码不能与旧密码相同")
		return
	
	# 验证旧密码
	if not _verify_old_password(old_password):
		_show_message("当前密码错误")
		return
	
	# 修改密码
	if _change_password(new_password):
		_show_message("密码修改成功！")
		# 清空输入框
		old_password_input.clear()
		new_password_input.clear()
		confirm_password_input.clear()
	else:
		_show_message("密码修改失败，请重试")

func _verify_old_password(password: String) -> bool:
	var users = _load_users()
	if users.has(current_username):
		return users[current_username]["password"] == password.sha256_text()
	return false

func _change_password(new_password: String) -> bool:
	var users = _load_users()
	if users.has(current_username):
		users[current_username]["password"] = new_password.sha256_text()
		users[current_username]["password_updated_at"] = Time.get_datetime_string_from_system()
		return _save_users(users)
	return false

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

func _show_message(text: String):
	message_dialog.dialog_text = text
	message_dialog.popup_centered()

func _apply_brightness_from_settings():
	var settings = {
		"brightness": 100.0
	}
	
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(json_string) == OK:
				settings = json.get_data()
	
	# 应用亮度
	var brightness = settings.get("brightness", 100.0)
	var alpha = (100.0 - brightness) / 100.0 * 0.7
	brightness_overlay.color = Color(0, 0, 0, alpha)
