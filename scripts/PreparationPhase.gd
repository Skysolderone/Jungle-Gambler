extends Control

@onready var phase_label = $PrepPanel/MarginContainer/VBoxContainer/PhaseLabel
@onready var timer_label = $PrepPanel/MarginContainer/VBoxContainer/TimerLabel
@onready var enemy_info_label = $PrepPanel/MarginContainer/VBoxContainer/EnemyInfo
@onready var loadout_grid = $PrepPanel/MarginContainer/VBoxContainer/LoadoutContainer/LoadoutScroll/LoadoutGrid
@onready var selected_info_label = $PrepPanel/MarginContainer/VBoxContainer/SelectedInfo
@onready var start_button = $PrepPanel/MarginContainer/VBoxContainer/StartButton

# 战斗数据
var enemy_data: Dictionary = {}
var player_all_souls: Array = []  # 玩家所有魂印
var player_selected_souls: Array = []  # 玩家选中的魂印

var countdown: float = 60.0
var auto_start: bool = false

func _ready():
	# 应用响应式布局
	_setup_responsive_layout()
	
	# 从UserSession获取战斗数据
	var session = get_node("/root/UserSession")
	
	print("=== 战前准备场景调试 ===")
	print("UserSession节点存在: ", session != null)
	
	if session.has_meta("battle_enemy_data"):
		enemy_data = session.get_meta("battle_enemy_data")
		print("获取到敌人数据: ", enemy_data)
	else:
		print("警告：未找到敌人数据")
	
	if session.has_meta("battle_player_souls"):
		player_all_souls = session.get_meta("battle_player_souls")
		print("获取到玩家魂印数据，数量: ", player_all_souls.size())
		
		# 如果获取到的魂印配置为空，从背包获取所有魂印
		if player_all_souls.size() == 0:
			print("魂印配置为空，从背包获取所有魂印")
			var soul_system = get_node("/root/SoulPrintSystem")
			if soul_system:
				var username = session.get_username() if session.has_method("get_username") else "default"
				player_all_souls = soul_system.get_user_inventory(username)
				print("从背包获取到魂印数量: ", player_all_souls.size())
	else:
		print("警告：未找到玩家魂印数据，尝试从魂印系统获取")
		# 直接从魂印系统获取
		var soul_system = get_node("/root/SoulPrintSystem")
		if soul_system and has_node("/root/UserSession"):
			var username = session.get_username() if session.has_method("get_username") else "default"
			player_all_souls = soul_system.get_user_inventory(username)
			print("从魂印系统获取到魂印数量: ", player_all_souls.size())
	
	# 保存初始HP用于计算变化
	if session.has_meta("battle_player_hp"):
		session.set_meta("battle_initial_hp", session.get_meta("battle_player_hp"))
	
	phase_label.text = "战前准备"
	timer_label.text = str(int(countdown) + 1)
	
	# 显示敌人信息
	var enemy_name = enemy_data.get("name", "未知敌人")
	var enemy_hp = enemy_data.get("hp", 100)
	var enemy_power = enemy_data.get("power", 30)
	enemy_info_label.text = "敌人：" + enemy_name + " | HP: " + str(enemy_hp) + " | 基础力量: " + str(enemy_power)
	
	_initialize_loadout()
	_update_selected_info()
	
	# 连接开始按钮
	start_button.pressed.connect(_start_combat)

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		
		# 连接屏幕类型变化信号
		responsive_manager.screen_type_changed.connect(_on_screen_type_changed)
		
		# 应用响应式布局
		responsive_manager.apply_responsive_layout(self)
		
		# 为移动端优化触摸
		responsive_manager.optimize_for_touch(self)
		
		# 根据屏幕类型调整网格布局
		_adjust_loadout_grid_for_screen(responsive_manager.current_screen_type)
		
		print("战前准备已启用响应式布局，屏幕类型：", responsive_manager.get_screen_type_name())

func _on_screen_type_changed(_new_type):
	# 屏幕类型变化时重新应用布局
	_setup_responsive_layout()

func _adjust_loadout_grid_for_screen(screen_type):
	# 根据屏幕类型调整网格列数
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		loadout_grid.columns = responsive_manager.get_grid_columns_for_screen()

func _process(delta):
	if auto_start:
		return
	
	countdown -= delta
	timer_label.text = str(int(countdown) + 1)
	if countdown <= 0:
		_start_combat()

func _initialize_loadout():
	# 清空网格
	for child in loadout_grid.get_children():
		child.queue_free()

	await get_tree().process_frame

	print("=== 初始化魂印选择界面 ===")
	print("loadout_grid节点: ", loadout_grid)
	print("loadout_grid是否有效: ", loadout_grid != null)
	if loadout_grid != null:
		print("loadout_grid列数: ", loadout_grid.columns)
		print("loadout_grid大小: ", loadout_grid.size)
		print("loadout_grid可见: ", loadout_grid.visible)
	print("player_all_souls数量: ", player_all_souls.size())

	if player_all_souls.size() == 0:
		print("警告：没有可用的魂印！")
		var label = Label.new()
		label.text = "没有可用的魂印\n请先在魂印配置界面选择魂印"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		loadout_grid.add_child(label)
		return

	# 创建魂印选择卡片
	for i in range(player_all_souls.size()):
		var soul_item = player_all_souls[i]
		print("处理魂印", i, ": ", soul_item)

		# 检查数据结构
		if soul_item == null:
			print("错误：魂印", i, "为null")
			continue

		# InventoryItem可能是对象而不是字典
		var soul = null
		if typeof(soul_item) == TYPE_OBJECT:
			# 对象类型，直接访问属性
			soul = soul_item.soul_print
			print("  对象类型魂印，名称: ", soul.name, " 力量:", soul.power, " 次数:", soul_item.uses_remaining)
		elif typeof(soul_item) == TYPE_DICTIONARY and soul_item.has("soul_print"):
			# 字典类型
			soul = soul_item.soul_print
			print("  字典类型魂印，名称: ", soul.name, " 力量:", soul.power)
		else:
			print("错误：魂印", i, "数据格式不正确，类型:", typeof(soul_item))
			continue

		if soul == null:
			print("错误：无法获取魂印数据")
			continue

		var card = _create_soul_card(soul, i)
		if card != null:
			print("准备添加卡片到网格:", soul.name, " 卡片类型:", typeof(card))
			loadout_grid.add_child(card)
			print("成功添加魂印卡片:", soul.name, " 网格子节点数量:", loadout_grid.get_child_count())
		else:
			print("警告：创建魂印卡片失败:", soul.name)

func _create_soul_card(soul, index: int) -> Button:
	var button = Button.new()
	# 增加卡片高度以容纳被动效果描述
	var card_height = 100 if soul.passive_type > 0 else 80
	button.custom_minimum_size = Vector2(140, card_height)
	button.toggle_mode = true

	# 设置文字自动换行和对齐
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	
	# 安全获取魂印物品数据来显示使用次数
	var soul_item = player_all_souls[index]
	var uses_remaining = 5
	var max_uses = 5
	
	# InventoryItem对象直接访问属性
	if soul_item != null:
		uses_remaining = soul_item.uses_remaining
		max_uses = soul_item.max_uses
	
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
	
	# 如果使用次数为0，使用灰色并禁用
	if uses_remaining <= 0:
		color = Color(0.3, 0.3, 0.3)
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
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_selected)
	button.add_theme_stylebox_override("pressed", style_selected)
	
	var quality_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
	var uses_text = ""
	if uses_remaining <= 0:
		uses_text = "\n(已耗尽)"
	else:
		uses_text = "\n次数: " + str(uses_remaining) + "/" + str(max_uses)

	# 被动效果描述
	var passive_text = ""
	var passive_icon = ""
	if soul.passive_type > 0:  # 有被动效果
		# 根据被动类型添加图标
		match soul.passive_type:
			1:  # HEAL
				passive_icon = "❤"
			2:  # POWER_CHANCE
				passive_icon = "⚡"
			3:  # MULT_CHANCE
				passive_icon = "✦"
			4:  # SHIELD
				passive_icon = "🛡"
			5:  # VAMPIRE
				passive_icon = "🩸"
			6:  # CRIT_CHANCE
				passive_icon = "💥"
			7:  # DODGE
				passive_icon = "💨"

		passive_text = "\n" + passive_icon + " " + soul.get_passive_description()

	# 构建卡片文本
	var card_text = soul.name + "\n"
	card_text += "力量: +" + str(soul.power) + " | " + quality_names[soul.quality] + "\n"
	card_text += "次数: " + str(uses_remaining) + "/" + str(max_uses) if uses_remaining > 0 else "(已耗尽)"
	card_text += passive_text

	button.text = card_text
	
	# 只有可用的魂印才能被选择
	if uses_remaining > 0:
		button.toggled.connect(_on_soul_card_toggled.bind(index))
	
	return button

func _on_soul_card_toggled(is_pressed: bool, index: int):
	var soul_item = player_all_souls[index]
	
	# 检查魂印是否还有使用次数
	var uses_remaining = soul_item.uses_remaining
	
	if uses_remaining <= 0:
		print("魂印已耗尽，无法选择：", soul_item.soul_print.name)
		return
	
	if is_pressed:
		if not player_selected_souls.has(soul_item):
			player_selected_souls.append(soul_item)
			print("选择魂印：", soul_item.soul_print.name, " 剩余次数：", uses_remaining)
	else:
		if player_selected_souls.has(soul_item):
			player_selected_souls.erase(soul_item)
			print("取消选择：", soul_item.soul_print.name)
	
	_update_selected_info()

func _update_selected_info():
	var total_power = 0
	var total_multiplier = 0.0
	var selected_count = player_selected_souls.size()

	for soul_item in player_selected_souls:
		var soul = soul_item.soul_print
		total_power += soul.power
		# 品质倍率加成：普通0% 非凡5% 稀有10% 史诗15% 传说20% 神话25%
		total_multiplier += soul.quality * 0.05

	var warning_text = ""
	if selected_count == 0:
		warning_text = " (建议选择至少1个魂印)"

	var mult_percent = int(total_multiplier * 100)
	if mult_percent > 0:
		selected_info_label.text = "已选择: " + str(selected_count) + " 个魂印 | 力量: +" + str(total_power) + " | 品质倍率: +" + str(mult_percent) + "%" + warning_text
	else:
		selected_info_label.text = "已选择: " + str(selected_count) + " 个魂印 | 总加成: +" + str(total_power) + warning_text

func _start_combat():
	auto_start = true
	
	print("开始战斗，选择了", player_selected_souls.size(), "个魂印")
	
	# 保存选择的魂印到UserSession
	var session = get_node("/root/UserSession")
	session.set_meta("battle_selected_souls", player_selected_souls)
	
	# 跳转到战斗阶段
	get_tree().change_scene_to_file("res://scenes/CombatPhase.tscn")
