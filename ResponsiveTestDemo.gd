extends Control

# 响应式布局演示脚本
# 展示不同屏幕尺寸下的适配效果

@onready var info_label = Label.new()
@onready var test_button = Button.new()
@onready var test_grid = GridContainer.new()

func _ready():
	# 设置基本布局
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# 创建UI元素
	_create_demo_ui()
	
	# 连接响应式管理器
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		responsive_manager.screen_type_changed.connect(_update_demo_info)
		responsive_manager.layout_updated.connect(_update_demo_info)
		_update_demo_info()

func _create_demo_ui():
	# 主容器
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 20)
	add_child(main_vbox)
	
	# 信息标签
	info_label.text = "响应式布局演示"
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(info_label)
	
	# 测试按钮
	test_button.text = "测试按钮"
	test_button.pressed.connect(_on_test_button_pressed)
	main_vbox.add_child(test_button)
	
	# 测试网格
	test_grid.columns = 3
	main_vbox.add_child(test_grid)
	
	# 添加网格项目
	for i in range(9):
		var grid_button = Button.new()
		grid_button.text = "项目 " + str(i + 1)
		grid_button.custom_minimum_size = Vector2(100, 50)
		test_grid.add_child(grid_button)
	
	# 应用响应式布局
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		responsive_manager.apply_responsive_layout(self)

func _update_demo_info():
	if not has_node("/root/ResponsiveLayoutManager"):
		return
	
	var responsive_manager = get_node("/root/ResponsiveLayoutManager")
	var screen_type_name = responsive_manager.get_screen_type_name()
	var screen_size = responsive_manager.screen_size
	var font_scale = responsive_manager.get_font_scale()
	var margin_scale = responsive_manager.get_margin_scale()
	
	var info_text = "响应式布局演示\n"
	info_text += "屏幕类型: " + screen_type_name + "\n"
	info_text += "屏幕尺寸: " + str(int(screen_size.x)) + "x" + str(int(screen_size.y)) + "\n"
	info_text += "字体缩放: " + str(font_scale) + "\n"
	info_text += "间距缩放: " + str(margin_scale) + "\n"
	info_text += "是否移动端: " + ("是" if responsive_manager.is_mobile_device() else "否")
	
	info_label.text = info_text
	
	# 根据屏幕类型调整网格列数
	test_grid.columns = responsive_manager.get_grid_columns_for_screen()

func _on_test_button_pressed():
	print("测试按钮被点击")
	
	# 添加移动端触摸反馈
	if has_node("/root/MobileInteractionHelper"):
		var mobile_helper = get_node("/root/MobileInteractionHelper")
		mobile_helper.add_touch_feedback(test_button)

func _input(event):
	# 模拟屏幕尺寸变化进行测试
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_simulate_screen_size(Vector2(400, 800))  # 手机竖屏
			KEY_2:
				_simulate_screen_size(Vector2(800, 400))  # 手机横屏
			KEY_3:
				_simulate_screen_size(Vector2(768, 1024)) # 平板竖屏
			KEY_4:
				_simulate_screen_size(Vector2(1024, 768)) # 平板横屏
			KEY_5:
				_simulate_screen_size(Vector2(1920, 1080)) # 桌面端

func _simulate_screen_size(new_size: Vector2):
	# 这是一个演示函数，实际中窗口大小变化会自动触发响应式更新
	print("模拟屏幕尺寸变化: ", new_size)
	get_tree().get_root().set_size(new_size)
