extends Control

# 准备阶段场景 - 玩家选择本次战斗使用的魂印

@onready var phase_label: Label = $MainPanel/MarginContainer/VBoxContainer/PhaseLabel
@onready var timer_label: Label = $MainPanel/MarginContainer/VBoxContainer/TimerLabel
@onready var enemy_name_label: Label = $MainPanel/MarginContainer/VBoxContainer/EnemyInfo/EnemyName
@onready var enemy_hp_label: Label = $MainPanel/MarginContainer/VBoxContainer/EnemyInfo/EnemyHP
@onready var enemy_power_label: Label = $MainPanel/MarginContainer/VBoxContainer/EnemyInfo/EnemyPower
@onready var soul_grid: GridContainer = $MainPanel/MarginContainer/VBoxContainer/SoulScroll/SoulGrid
@onready var hint_label: Label = $MainPanel/MarginContainer/VBoxContainer/HintLabel
@onready var start_battle_button: Button = $MainPanel/MarginContainer/VBoxContainer/StartBattleButton

# 战斗数据
var enemy_data: Dictionary = {}
var player_hp: int = 100
var player_all_souls: Array = []  # 玩家所有魂印
var player_selected_souls: Array = []  # 玩家选中的魂印
var enemy_souls: Array = []

# 倒计时
var countdown: float = 30.0

func _ready():
	# 应用像素风格
	_apply_pixel_style()

	# 应用响应式布局
	_setup_responsive_layout()

	# 从 UserSession 获取战斗数据
	var session = get_node("/root/UserSession")

	if session.has_meta("battle_enemy_data"):
		enemy_data = session.get_meta("battle_enemy_data")
	if session.has_meta("battle_player_hp"):
		player_hp = session.get_meta("battle_player_hp")
	if session.has_meta("battle_player_souls"):
		player_all_souls = session.get_meta("battle_player_souls")
	if session.has_meta("battle_enemy_souls"):
		enemy_souls = session.get_meta("battle_enemy_souls")

	# 显示敌人信息
	_update_enemy_display()

	# 显示玩家魂印
	_initialize_soul_selection()

	# 显示提示
	hint_label.text = "点击魂印选择/取消（未选择任何魂印时将使用全部），或直接点击按钮开始战斗"

	# 设置并连接开始战斗按钮
	start_battle_button.text = "直接开始战斗"
	start_battle_button.pressed.connect(_on_start_battle_pressed)

# ========== 像素风格应用 ==========

func _apply_pixel_style():
	"""应用像素艺术风格"""
	if not has_node("/root/PixelStyleManager"):
		return

	var pixel_style = get_node("/root/PixelStyleManager")
	var main_panel = $MainPanel
	pixel_style.apply_pixel_panel_style(main_panel, "DARK_GREY")

	pixel_style.apply_pixel_label_style(phase_label, "YELLOW", true, 24)
	pixel_style.apply_pixel_label_style(timer_label, "RED", true, 20)
	pixel_style.apply_pixel_label_style(enemy_name_label, "ORANGE", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)
	pixel_style.apply_pixel_label_style(enemy_hp_label, "CYAN", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)
	pixel_style.apply_pixel_label_style(enemy_power_label, "GREEN", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)
	pixel_style.apply_pixel_label_style(hint_label, "LIGHT_GREY", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)

	pixel_style.apply_pixel_button_style(start_battle_button, "GREEN", 18)

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		responsive_manager.apply_responsive_layout(self)
		responsive_manager.optimize_for_touch(self)

		# 根据屏幕类型调整网格列数
		soul_grid.columns = responsive_manager.get_grid_columns_for_screen()

func _process(delta: float):
	countdown -= delta
	timer_label.text = "倒计时: " + str(int(countdown) + 1)

	if countdown <= 0:
		_start_combat()

func _update_enemy_display():
	enemy_name_label.text = "敌人: " + enemy_data.get("name", "未知敌人")
	enemy_hp_label.text = "HP: " + str(enemy_data.get("hp", 100))
	enemy_power_label.text = "基础力量: " + str(enemy_data.get("power", 30))

func _initialize_soul_selection():
	# 清空网格
	for child in soul_grid.get_children():
		child.queue_free()

	# 创建魂印选择卡片（跳过使用次数为0的魂印）
	for i in range(player_all_souls.size()):
		var soul_item = player_all_souls[i]

		# 跳过使用次数为0的魂印
		if soul_item.uses == 0:
			continue

		var soul = soul_item.soul_print
		var card = _create_soul_card(soul, i)
		soul_grid.add_child(card)

func _create_soul_card(soul, index: int) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(180, 120)

	# 获取魂印使用次数信息
	var soul_item = player_all_souls[index]
	var uses_text = str(soul_item.uses) if soul_item.uses >= 0 else "∞"
	var is_depleted = (soul_item.uses == 0)

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

	# 如果使用次数为0，变成灰色
	if is_depleted:
		color = Color(0.3, 0.3, 0.3)  # 灰色
		button.disabled = true

	# 设置按钮样式
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.8)
	style_normal.border_color = color
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(5)

	var style_selected = StyleBoxFlat.new()
	style_selected.bg_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 1.0)
	style_selected.border_color = Color(1, 1, 0, 1)
	style_selected.set_border_width_all(3)
	style_selected.set_corner_radius_all(5)

	var style_disabled = StyleBoxFlat.new()
	style_disabled.bg_color = Color(0.2, 0.2, 0.2, 0.6)
	style_disabled.border_color = Color(0.3, 0.3, 0.3)
	style_disabled.set_border_width_all(2)
	style_disabled.set_corner_radius_all(5)

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_selected)
	button.add_theme_stylebox_override("pressed", style_selected)
	button.add_theme_stylebox_override("disabled", style_disabled)

	# 设置按钮文本
	var status_text = "[已耗尽]" if is_depleted else ""
	button.text = soul.name + " " + status_text + "\n力量+" + str(soul.power) + "\n次数:" + uses_text
	button.add_theme_font_size_override("font_size", 18)

	if not is_depleted:
		button.pressed.connect(_on_soul_card_pressed.bind(index))

	# 添加触摸反馈
	if has_node("/root/MobileInteractionHelper"):
		var mobile_helper = get_node("/root/MobileInteractionHelper")
		mobile_helper.add_touch_feedback(button)

	return button

func _on_soul_card_pressed(index: int):
	var soul_item = player_all_souls[index]

	if player_selected_souls.has(soul_item):
		player_selected_souls.erase(soul_item)
	else:
		player_selected_souls.append(soul_item)

	# 更新卡片视觉状态
	_update_soul_card_states()

func _update_soul_card_states():
	# 更新所有魂印卡片的选中状态
	for i in range(soul_grid.get_child_count()):
		if i >= player_all_souls.size():
			break
		var button = soul_grid.get_child(i)
		var soul_item = player_all_souls[i]
		var soul = soul_item.soul_print

		# 品质颜色
		var quality_colors = [
			Color(0.5, 0.5, 0.5), Color(0.2, 0.7, 0.2), Color(0.2, 0.5, 0.9),
			Color(0.6, 0.2, 0.8), Color(0.9, 0.6, 0.2), Color(0.9, 0.3, 0.3)
		]
		var color = quality_colors[soul.quality]

		# 根据选中状态设置样式
		if player_selected_souls.has(soul_item):
			# 选中状态 - 更亮，黄色边框
			var style_selected = StyleBoxFlat.new()
			style_selected.bg_color = Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, 1.0)
			style_selected.border_color = Color(1, 1, 0, 1)
			style_selected.set_border_width_all(4)
			style_selected.set_corner_radius_all(5)
			button.add_theme_stylebox_override("normal", style_selected)
		else:
			# 未选中状态 - 正常样式
			var style_normal = StyleBoxFlat.new()
			style_normal.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.8)
			style_normal.border_color = color
			style_normal.set_border_width_all(2)
			style_normal.set_corner_radius_all(5)
			button.add_theme_stylebox_override("normal", style_normal)

func _on_start_battle_pressed():
	# 立即开始战斗（无需等待倒计时）
	_start_combat()

func _start_combat():
	# 如果没有选择任何魂印，默认使用所有可用魂印
	if player_selected_souls.is_empty():
		player_selected_souls = player_all_souls.duplicate()

	# 保存选中的魂印到 UserSession
	var session = get_node("/root/UserSession")
	session.set_meta("battle_selected_souls", player_selected_souls)

	# 跳转到管道连接场景（新增）
	var pipe_scene = preload("res://scenes/PipeBattle.tscn").instantiate()
	get_tree().root.add_child(pipe_scene)
	pipe_scene.initialize(player_selected_souls, enemy_data)
	queue_free()
