extends Control

# 胜利结算场景 - 处理战利品拾取

@onready var title_label: Label = $MainPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var result_label: Label = $MainPanel/MarginContainer/VBoxContainer/ResultLabel
@onready var loot_container: VBoxContainer = $MainPanel/MarginContainer/VBoxContainer/LootScroll/LootContainer
@onready var button_container: HBoxContainer = $MainPanel/MarginContainer/VBoxContainer/ButtonContainer
@onready var take_all_button: Button = $MainPanel/MarginContainer/VBoxContainer/ButtonContainer/TakeAllButton
@onready var skip_button: Button = $MainPanel/MarginContainer/VBoxContainer/ButtonContainer/SkipButton

# 战斗结果数据
var battle_result: Dictionary = {}
var loot_souls: Array = []
var player_selected_souls: Array = []  # 战斗中使用的魂印

# 战利品选择阶段
var is_in_loot_selection: bool = false

func _ready():
	# 应用响应式布局
	_setup_responsive_layout()

	# 从 UserSession 获取数据
	var session = get_node("/root/UserSession")

	if session.has_meta("battle_result"):
		battle_result = session.get_meta("battle_result")
	if session.has_meta("battle_loot_souls"):
		loot_souls = session.get_meta("battle_loot_souls")
	if session.has_meta("battle_selected_souls"):
		player_selected_souls = session.get_meta("battle_selected_souls")

	# 显示战斗结果
	_display_victory_info()

	# 连接按钮信号
	take_all_button.pressed.connect(_on_take_all_pressed)
	skip_button.pressed.connect(_on_skip_pressed)

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		responsive_manager.apply_responsive_layout(self)
		responsive_manager.optimize_for_touch(self)

func _display_victory_info():
	title_label.text = "战斗胜利！"

	# 显示 HP 变化
	var hp_change = battle_result.get("player_hp_change", 0)
	if hp_change < 0:
		result_label.text = "HP 变化: " + str(hp_change)
	elif hp_change > 0:
		result_label.text = "HP 变化: +" + str(hp_change)
	else:
		result_label.text = "HP 变化: 无"

	# 显示战利品
	if loot_souls.size() > 0:
		_display_loot_souls()
	else:
		var no_loot_label = Label.new()
		no_loot_label.text = "没有战利品"
		no_loot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loot_container.add_child(no_loot_label)

		# 没有战利品时隐藏"全部拾取"按钮
		take_all_button.visible = false

func _display_loot_souls():
	# 清空容器
	for child in loot_container.get_children():
		child.queue_free()

	# 添加标题
	var loot_title = Label.new()
	loot_title.text = "战利品："
	loot_title.add_theme_font_size_override("font_size", 18)
	loot_title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	loot_container.add_child(loot_title)

	# 获取响应式网格列数
	var grid_columns = 5  # 默认值
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		grid_columns = responsive_manager.get_grid_columns_for_screen()

	# 创建网格显示战利品
	var loot_grid = GridContainer.new()
	loot_grid.columns = grid_columns
	loot_grid.add_theme_constant_override("h_separation", 8)
	loot_grid.add_theme_constant_override("v_separation", 8)

	for soul in loot_souls:
		var card = _create_loot_card(soul)
		loot_grid.add_child(card)

	loot_container.add_child(loot_grid)

func _create_loot_card(soul) -> PanelContainer:
	var panel = PanelContainer.new()

	# 品质颜色
	var quality_colors = [
		Color(0.5, 0.5, 0.5),    # 普通
		Color(0.2, 0.7, 0.2),    # 非凡
		Color(0.2, 0.5, 0.9),    # 稀有
		Color(0.6, 0.2, 0.8),    # 史诗
		Color(0.9, 0.6, 0.2),    # 传说
		Color(0.9, 0.3, 0.3)     # 神话
	]

	var color = quality_colors[soul.quality]

	# 设置面板样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	# 根据屏幕类型调整面板大小
	var min_size = Vector2(100, 80)
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		min_size = responsive_manager.get_min_button_size()
		min_size.y = min_size.y * 1.2
	panel.custom_minimum_size = min_size

	# 创建内容
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)

	var name_label = Label.new()
	name_label.text = soul.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", color)
	vbox.add_child(name_label)

	var power_label = Label.new()
	power_label.text = "力量: +" + str(soul.power)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(power_label)

	var quality_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
	var quality_label = Label.new()
	quality_label.text = quality_names[soul.quality]
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.add_theme_font_size_override("font_size", 10)
	quality_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(quality_label)

	# 添加效果描述
	var effect_label = Label.new()
	effect_label.text = soul.get_effect_description()
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.add_theme_font_size_override("font_size", 9)
	effect_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.6))
	vbox.add_child(effect_label)

	panel.add_child(vbox)
	return panel

func _on_take_all_pressed():
	# 尝试将所有战利品加入背包
	var soul_system = _get_soul_system()
	if not soul_system:
		_show_error("无法访问魂印系统")
		return

	var username = _get_username()
	var added_souls = []

	for soul in loot_souls:
		if soul_system.add_soul_print(username, soul.id):
			added_souls.append(soul)

	# 从战利品列表中移除已添加的
	for soul in added_souls:
		loot_souls.erase(soul)

	# 如果还有剩余战利品，说明背包满了
	if loot_souls.size() > 0:
		_show_message("背包已满！剩余 " + str(loot_souls.size()) + " 个战利品")
		# 进入战利品选择阶段
		_start_loot_selection()
	else:
		# 所有战利品都成功添加
		_finish_victory()

func _on_skip_pressed():
	# 直接结束，不拾取战利品
	_finish_victory()

func _start_loot_selection():
	is_in_loot_selection = true

	# 隐藏原有按钮
	take_all_button.visible = false
	skip_button.text = "放弃剩余战利品"

	# 清空并重建界面
	for child in loot_container.get_children():
		child.queue_free()

	await get_tree().process_frame

	# 创建选择界面
	_create_loot_selection_interface()

func _create_loot_selection_interface():
	# 获取响应式网格列数
	var grid_columns = 5  # 默认值
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		grid_columns = responsive_manager.get_grid_columns_for_screen()
		if responsive_manager.is_mobile_device():
			grid_columns = max(2, grid_columns - 2)

	# 战利品区域
	var loot_label = Label.new()
	loot_label.text = "战利品（剩余）："
	loot_label.add_theme_font_size_override("font_size", 16)
	loot_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	loot_container.add_child(loot_label)

	var loot_grid = GridContainer.new()
	loot_grid.columns = grid_columns
	loot_grid.add_theme_constant_override("h_separation", 8)
	loot_grid.add_theme_constant_override("v_separation", 8)

	for soul in loot_souls:
		var card = _create_loot_card(soul)
		loot_grid.add_child(card)

	loot_container.add_child(loot_grid)

	# 分隔空间
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	loot_container.add_child(spacer)

	# 当前背包区域
	var inventory_label = Label.new()
	inventory_label.text = "当前背包（点击丢弃以腾出空间）："
	inventory_label.add_theme_font_size_override("font_size", 16)
	inventory_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1))
	loot_container.add_child(inventory_label)

	var inventory_grid = GridContainer.new()
	inventory_grid.name = "InventoryGrid"
	inventory_grid.columns = grid_columns
	inventory_grid.add_theme_constant_override("h_separation", 8)
	inventory_grid.add_theme_constant_override("v_separation", 8)

	# 显示背包中的魂印
	var soul_system = _get_soul_system()
	if soul_system:
		var username = _get_username()
		var inventory_items = soul_system.get_user_inventory(username)

		for i in range(min(10, inventory_items.size())):
			var soul_item = inventory_items[i]
			var card = _create_inventory_card(soul_item.soul_print, i)
			inventory_grid.add_child(card)

	loot_container.add_child(inventory_grid)

func _create_inventory_card(soul, index: int) -> Button:
	var button = Button.new()

	# 根据屏幕类型调整按钮大小
	var min_size = Vector2(100, 80)
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		min_size = responsive_manager.get_min_button_size()
		min_size.y = min_size.y * 1.2
	button.custom_minimum_size = min_size

	var quality_colors = [
		Color(0.5, 0.5, 0.5), Color(0.2, 0.7, 0.2), Color(0.2, 0.5, 0.9),
		Color(0.6, 0.2, 0.8), Color(0.9, 0.6, 0.2), Color(0.9, 0.3, 0.3)
	]

	var quality_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
	var color = quality_colors[soul.quality]

	# 设置按钮样式（偏红表示可丢弃）
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.6, 0.3, 0.3, 0.8)
	style_normal.border_color = color
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(8)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.8, 0.4, 0.4, 1.0)
	style_hover.border_color = color.lightened(0.3)
	style_hover.set_border_width_all(3)
	style_hover.set_corner_radius_all(8)

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)

	# 设置文本
	var type_text = "[主动]" if soul.soul_type == 0 else "[被动]"
	var effect_desc = soul.get_effect_description()

	var text = soul.name + " " + type_text + "\n力量: +" + str(soul.power) + "\n" + quality_names[soul.quality] + "\n" + effect_desc
	button.text = text

	# 连接信号
	button.pressed.connect(_on_discard_soul.bind(index))

	# 添加触摸反馈
	if has_node("/root/MobileInteractionHelper"):
		var mobile_helper = get_node("/root/MobileInteractionHelper")
		mobile_helper.add_touch_feedback(button)

	return button

func _on_discard_soul(index: int):
	var soul_system = _get_soul_system()
	if not soul_system:
		return

	var username = _get_username()

	# 移除背包中的魂印
	if soul_system.remove_soul_print(username, index):
		# 尝试添加一个战利品
		if loot_souls.size() > 0:
			var soul_to_add = loot_souls[0]
			if soul_system.add_soul_print(username, soul_to_add.id):
				loot_souls.remove_at(0)

				# 检查是否所有战利品都已获得
				if loot_souls.size() == 0:
					_show_message("所有战利品已获得！")
					await get_tree().create_timer(1.0).timeout
					_finish_victory()
					return

		# 刷新显示
		_refresh_loot_selection_display()

func _refresh_loot_selection_display():
	# 重新生成选择界面
	for child in loot_container.get_children():
		child.queue_free()

	await get_tree().process_frame
	_create_loot_selection_interface()

func _finish_victory():
	# 消耗选中魂印的使用次数
	_consume_selected_soul_uses()

	# 更新战斗结果（实际获得的战利品）
	var session = get_node("/root/UserSession")
	var all_loot_souls = session.get_meta("battle_loot_souls") if session.has_meta("battle_loot_souls") else []

	var obtained_souls = []
	for soul in all_loot_souls:
		if not loot_souls.has(soul):  # 不在剩余列表中，说明已获得
			obtained_souls.append(soul)

	battle_result["loot_souls"] = obtained_souls
	session.set_meta("battle_result", battle_result)

	# 返回地图
	get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _consume_selected_soul_uses():
	# 消耗战斗中使用的魂印次数
	var soul_system = _get_soul_system()
	if not soul_system:
		return

	var username = _get_username()

	# 重新获取当前背包
	var current_inventory = soul_system.get_user_inventory(username)

	# 找到并消耗选中魂印的使用次数
	for selected_soul_item in player_selected_souls:
		for i in range(current_inventory.size()):
			var soul_item = current_inventory[i]
			# 通过ID和位置匹配魂印实例
			if (soul_item.soul_print.id == selected_soul_item.soul_print.id and
				soul_item.grid_position.x == selected_soul_item.grid_position.x and
				soul_item.grid_position.y == selected_soul_item.grid_position.y):
				soul_system.use_soul_print(username, i)
				break

func _show_message(message: String):
	# 简单的消息显示
	result_label.text = message

func _show_error(error: String):
	# 错误消息显示
	result_label.text = "错误: " + error
	result_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))

func _get_soul_system():
	if has_node("/root/SoulPrintSystem"):
		return get_node("/root/SoulPrintSystem")
	return null

func _get_username():
	if has_node("/root/UserSession"):
		return get_node("/root/UserSession").get_username()
	return ""
