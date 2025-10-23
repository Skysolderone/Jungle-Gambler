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

var countdown: float = 15.0
var auto_start: bool = false

func _ready():
	# 从UserSession获取战斗数据
	var session = get_node("/root/UserSession")
	
	if session.has_meta("battle_enemy_data"):
		enemy_data = session.get_meta("battle_enemy_data")
	if session.has_meta("battle_player_souls"):
		player_all_souls = session.get_meta("battle_player_souls")
	
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
	
	# 创建魂印选择卡片
	for i in range(player_all_souls.size()):
		var soul_item = player_all_souls[i]
		var soul = soul_item.soul_print
		var card = _create_soul_card(soul, i)
		loadout_grid.add_child(card)

func _create_soul_card(soul, index: int) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(120, 80)
	button.toggle_mode = true
	
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
	button.text = soul.name + "\n力量: +" + str(soul.power) + "\n" + quality_names[soul.quality]
	button.toggled.connect(_on_soul_card_toggled.bind(index))
	
	return button

func _on_soul_card_toggled(is_pressed: bool, index: int):
	var soul_item = player_all_souls[index]
	
	if is_pressed:
		if not player_selected_souls.has(soul_item):
			player_selected_souls.append(soul_item)
			print("选择魂印：", soul_item.soul_print.name)
	else:
		if player_selected_souls.has(soul_item):
			player_selected_souls.erase(soul_item)
			print("取消选择：", soul_item.soul_print.name)
	
	_update_selected_info()

func _update_selected_info():
	var total_power = 0
	var selected_count = player_selected_souls.size()
	
	for soul_item in player_selected_souls:
		total_power += soul_item.soul_print.power
	
	selected_info_label.text = "已选择: " + str(selected_count) + " 个魂印 | 总加成: +" + str(total_power)

func _start_combat():
	auto_start = true
	
	print("开始战斗，选择了", player_selected_souls.size(), "个魂印")
	
	# 保存选择的魂印到UserSession
	var session = get_node("/root/UserSession")
	session.set_meta("battle_selected_souls", player_selected_souls)
	
	# 跳转到战斗阶段
	get_tree().change_scene_to_file("res://scenes/CombatPhase.tscn")