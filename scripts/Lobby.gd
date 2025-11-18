extends Control

@onready var username_label = $TopBar/MarginContainer/HBoxContainer/UserInfo/UsernameLabel
@onready var welcome_message = $MainContent/VBoxContainer/WelcomePanel/MarginContainer/VBoxContainer/WelcomeMessage
@onready var brightness_overlay = $BrightnessOverlay

var current_username: String = ""
var current_nickname: String = ""
var inventory_instance = null
var settings_instance = null
var shop_instance = null
var refine_instance = null

const SETTINGS_PATH = "user://settings.json"

func _ready():
	# 应用像素风格
	_apply_pixel_style()

	# 应用响应式布局
	_setup_responsive_layout()

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

# ========== 像素风格应用 ==========

func _apply_pixel_style():
	"""应用像素艺术风格到大厅场景"""
	if not has_node("/root/PixelStyleManager"):
		push_warning("PixelStyleManager 未加载，跳过像素风格应用")
		return

	var pixel_style = get_node("/root/PixelStyleManager")

	# 应用背景颜色
	var background = $Background
	background.color = pixel_style.PIXEL_PALETTE["BLACK"]

	# 顶部栏像素风格
	var top_bar = $TopBar
	pixel_style.apply_pixel_panel_style(top_bar, "DARK_GREY")

	# 标题标签 - 使用大号字体
	var game_title = $TopBar/MarginContainer/HBoxContainer/GameTitle
	pixel_style.apply_pixel_label_style(game_title, "YELLOW", true, pixel_style.PIXEL_FONT_SIZE_HUGE)

	# 用户信息标签
	var welcome_label = $TopBar/MarginContainer/HBoxContainer/UserInfo/WelcomeLabel
	var username_label = $TopBar/MarginContainer/HBoxContainer/UserInfo/UsernameLabel
	pixel_style.apply_pixel_label_style(welcome_label, "LIGHT_GREY", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)
	pixel_style.apply_pixel_label_style(username_label, "CYAN", true, pixel_style.PIXEL_FONT_SIZE_LARGE)

	# 登出按钮
	var logout_btn = $TopBar/MarginContainer/HBoxContainer/LogoutButton
	pixel_style.apply_pixel_button_style(logout_btn, "RED", pixel_style.PIXEL_FONT_SIZE_NORMAL)

	# 欢迎面板
	var welcome_panel = $MainContent/VBoxContainer/WelcomePanel
	pixel_style.apply_pixel_panel_style(welcome_panel, "DARK_GREY")

	# 欢迎标题和消息 - 使用便捷函数
	var welcome_title = $MainContent/VBoxContainer/WelcomePanel/MarginContainer/VBoxContainer/WelcomeTitle
	var welcome_msg = $MainContent/VBoxContainer/WelcomePanel/MarginContainer/VBoxContainer/WelcomeMessage
	pixel_style.apply_subtitle_style(welcome_title, "YELLOW")
	pixel_style.apply_body_style(welcome_msg, "WHITE")

	# 游戏功能按钮 - 使用不同颜色区分功能
	var start_game_btn = $MainContent/VBoxContainer/GameButtons/StartGameButton
	var profile_btn = $MainContent/VBoxContainer/GameButtons/ProfileButton
	var settings_btn = $MainContent/VBoxContainer/GameButtons/SettingsButton
	var inventory_btn = $MainContent/VBoxContainer/GameButtons/InventoryButton
	var shop_btn = $MainContent/VBoxContainer/GameButtons/ShopButton
	var refine_btn = $MainContent/VBoxContainer/GameButtons/RefineButton

	# 游戏功能按钮 - 使用大号字体和不同颜色
	pixel_style.apply_pixel_button_style(start_game_btn, "GREEN", pixel_style.PIXEL_FONT_SIZE_LARGE)    # 开始游戏 - 绿色
	pixel_style.apply_pixel_button_style(profile_btn, "BLUE", pixel_style.PIXEL_FONT_SIZE_LARGE)        # 个人信息 - 蓝色
	pixel_style.apply_pixel_button_style(settings_btn, "PURPLE", pixel_style.PIXEL_FONT_SIZE_LARGE)     # 设置 - 紫色
	pixel_style.apply_pixel_button_style(inventory_btn, "ORANGE", pixel_style.PIXEL_FONT_SIZE_LARGE)    # 背包 - 橙色
	pixel_style.apply_pixel_button_style(shop_btn, "YELLOW", pixel_style.PIXEL_FONT_SIZE_LARGE)         # 商城 - 黄色
	pixel_style.apply_pixel_button_style(refine_btn, "CYAN", pixel_style.PIXEL_FONT_SIZE_LARGE)         # 精炼 - 青色

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		
		# 连接屏幕类型变化信号
		responsive_manager.screen_type_changed.connect(_on_screen_type_changed)
		
		# 应用响应式布局
		responsive_manager.apply_responsive_layout(self)
		
		# 为移动端优化触摸
		responsive_manager.optimize_for_touch(self)
		
		# 根据屏幕类型调整按钮布局
		_adjust_button_layout_for_screen(responsive_manager.current_screen_type)
		
		print("大厅已启用响应式布局，屏幕类型：", responsive_manager.get_screen_type_name())

func _on_screen_type_changed(_new_type):
	# 屏幕类型变化时重新应用布局
	_setup_responsive_layout()

func _adjust_button_layout_for_screen(screen_type):
	var game_buttons = $MainContent/VBoxContainer/GameButtons
	
	# 根据屏幕类型调整按钮容器方向
	if screen_type in [0, 1]:  # 移动端
		# 将HBoxContainer改为VBoxContainer以适应窄屏
		if game_buttons is HBoxContainer:
			game_buttons.columns = 2  # 如果是GridContainer的话
	else:
		# 桌面端和平板横屏保持水平布局
		pass

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

func _on_refine_button_pressed():
	if refine_instance != null:
		return  # 已经打开了

	# 加载精炼场景
	var refine_scene = load("res://scenes/SoulRefine.tscn")
	refine_instance = refine_scene.instantiate()

	# 连接关闭信号
	refine_instance.refine_closed.connect(_on_refine_closed)

	# 添加到当前场景作为覆盖层
	add_child(refine_instance)

func _on_refine_closed():
	if refine_instance != null:
		refine_instance.queue_free()
		refine_instance = null
