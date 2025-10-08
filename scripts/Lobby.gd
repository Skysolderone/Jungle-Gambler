extends Control

@onready var username_label = $TopBar/MarginContainer/HBoxContainer/UserInfo/UsernameLabel
@onready var welcome_message = $MainContent/VBoxContainer/WelcomePanel/MarginContainer/VBoxContainer/WelcomeMessage
@onready var brightness_overlay = $BrightnessOverlay

var current_username: String = ""
var current_nickname: String = ""
var inventory_instance = null
var settings_instance = null
var shop_instance = null

const SETTINGS_PATH = "user://settings.json"

func _ready():
	# 获取当前登录的用户信息
	if UserSession.is_logged_in():
		current_username = UserSession.get_username()
		current_nickname = UserSession.get_nickname()
		username_label.text = current_nickname
		welcome_message.text = "准备好开始你的冒险了吗，" + current_nickname + "？"
	else:
		# 如果没有登录，返回主菜单
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	
	# 应用亮度设置
	_apply_brightness_from_settings()

func _on_logout_button_pressed():
	UserSession.logout()
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

func _on_start_game_button_pressed():
	# 进入地图选择页面
	get_tree().change_scene_to_file("res://scenes/MapSelection.tscn")

func _on_profile_button_pressed():
	get_tree().change_scene_to_file("res://scenes/Profile.tscn")

func _on_settings_button_pressed():
	if settings_instance != null:
		return  # 已经打开了
	
	# 加载设置场景
	var settings_scene = load("res://scenes/Settings.tscn")
	settings_instance = settings_scene.instantiate()
	
	# 连接信号
	settings_instance.settings_closed.connect(_on_settings_closed)
	settings_instance.brightness_changed.connect(_on_brightness_changed)
	
	# 添加到当前场景作为覆盖层
	add_child(settings_instance)

func _on_settings_closed():
	if settings_instance != null:
		settings_instance.queue_free()
		settings_instance = null

func _on_brightness_changed(value: float):
	# 更新亮度覆盖层
	var alpha = (100.0 - value) / 100.0 * 0.7
	brightness_overlay.color = Color(0, 0, 0, alpha)

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
	_on_brightness_changed(brightness)

func _on_inventory_button_pressed():
	if inventory_instance != null:
		return  # 已经打开了
	
	# 加载背包场景
	var inventory_scene = load("res://scenes/SoulInventoryV2.tscn")
	inventory_instance = inventory_scene.instantiate()
	
	# 连接关闭信号
	inventory_instance.inventory_closed.connect(_on_inventory_closed)
	
	# 添加到当前场景作为覆盖层
	add_child(inventory_instance)

func _on_inventory_closed():
	if inventory_instance != null:
		inventory_instance.queue_free()
		inventory_instance = null

func _on_shop_button_pressed():
	if shop_instance != null:
		return  # 已经打开了
	
	# 加载商城场景
	var shop_scene = load("res://scenes/Shop.tscn")
	shop_instance = shop_scene.instantiate()
	
	# 连接关闭信号
	shop_instance.shop_closed.connect(_on_shop_closed)
	
	# 添加到当前场景作为覆盖层
	add_child(shop_instance)

func _on_shop_closed():
	if shop_instance != null:
		shop_instance.queue_free()
		shop_instance = null

