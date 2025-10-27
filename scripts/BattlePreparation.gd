extends Control

# 战前准备场景 - 选择魂印带入战斗

@onready var enemy_name_label = $TopBar/MarginContainer/HBoxContainer/EnemyNameLabel
@onready var enemy_hp_label = $TopBar/MarginContainer/HBoxContainer/EnemyHPLabel
@onready var enemy_power_label = $TopBar/MarginContainer/HBoxContainer/EnemyPowerLabel

@onready var soul_grid = $MainContent/HBoxContainer/LeftPanel/ScrollContainer/SoulGrid
@onready var selected_container = $MainContent/HBoxContainer/RightPanel/ScrollContainer/SelectedContainer
@onready var total_power_label = $MainContent/HBoxContainer/RightPanel/StatsPanel/MarginContainer/VBoxContainer/TotalPowerLabel
@onready var count_label = $MainContent/HBoxContainer/RightPanel/StatsPanel/MarginContainer/VBoxContainer/CountLabel

@onready var brightness_overlay = $BrightnessOverlay
@onready var message_dialog = $MessageDialog

# 战斗数据
var enemy_data: Dictionary = {}
var player_hp: int = 100
var player_all_souls: Array = []
var enemy_souls: Array = []

# 选择的魂印
var selected_souls: Array = []
const MAX_SELECTION = 5  # 最多选择5个魂印

# 品质颜色
var quality_colors = {
	0: Color(0.6, 0.6, 0.6),
	1: Color(0.2, 0.8, 0.2),
	2: Color(0.2, 0.4, 1.0),
	3: Color(0.7, 0.2, 1.0),
	4: Color(1.0, 0.5, 0.0),
	5: Color(1.0, 0.1, 0.1)
}

var quality_names = {
	0: "普通", 1: "非凡", 2: "稀有",
	3: "史诗", 4: "传说", 5: "神话"
}

const SETTINGS_PATH = "user://settings.json"

func _ready():
	_apply_brightness_from_settings()
	_load_battle_data()
	_display_enemy_info()
	_display_all_souls()
	_update_stats()

func _apply_brightness_from_settings():
	var settings = {"brightness": 100.0}
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				settings = json.get_data()
	var brightness = settings.get("brightness", 100.0)
	var alpha = (100.0 - brightness) / 100.0 * 0.7
	brightness_overlay.color = Color(0, 0, 0, alpha)

func _load_battle_data():
	var session = get_node("/root/UserSession")
	if session.has_meta("battle_enemy_data"):
		enemy_data = session.get_meta("battle_enemy_data")
	if session.has_meta("battle_player_hp"):
		player_hp = session.get_meta("battle_player_hp")
	if session.has_meta("battle_player_souls"):
		player_all_souls = session.get_meta("battle_player_souls")
	if session.has_meta("battle_enemy_souls"):
		enemy_souls = session.get_meta("battle_enemy_souls")

func _display_enemy_info():
	enemy_name_label.text = "敌人: " + enemy_data.get("name", "未知")
	enemy_hp_label.text = "HP: " + str(enemy_data.get("hp", 100))

	# 计算敌人总力量
	var enemy_total_power = enemy_data.get("power", 30)
	for soul in enemy_souls:
		enemy_total_power += soul.power
	enemy_power_label.text = "总力量: " + str(enemy_total_power)

func _display_all_souls():
	# 清空网格
	for child in soul_grid.get_children():
		child.queue_free()

	# 创建魂印卡片
	for i in range(player_all_souls.size()):
		var item = player_all_souls[i]
		var card = _create_soul_card(item, i)
		soul_grid.add_child(card)

func _create_soul_card(item, index: int) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(140, 160)

	var soul = item.soul_print
	var base_color = quality_colors.get(soul.quality, Color.WHITE)

	# 检查是否已选中
	var is_selected = selected_souls.has(item)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 1) if not is_selected else Color(0.2, 0.25, 0.3, 1)
	style.border_width_left = 3 if is_selected else 2
	style.border_width_top = 3 if is_selected else 2
	style.border_width_right = 3 if is_selected else 2
	style.border_width_bottom = 3 if is_selected else 2
	style.border_color = Color(1, 0.85, 0.3) if is_selected else base_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)

	# 间距
	var top_margin = Control.new()
	top_margin.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(top_margin)

	# 名称
	var name_label = Label.new()
	name_label.text = soul.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", base_color)
	name_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(name_label)

	# 品质
	var quality_label = Label.new()
	quality_label.text = quality_names.get(soul.quality, "未知")
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.add_theme_color_override("font_color", base_color)
	quality_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(quality_label)

	# 力量
	var power_label = Label.new()
	power_label.text = "力量: " + str(soul.power)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	power_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(power_label)

	# 间距
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 选择/取消按钮
	var button = Button.new()
	button.text = "取消选择" if is_selected else "选择"
	button.custom_minimum_size = Vector2(100, 35)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(_on_soul_card_clicked.bind(item, index))

	var button_center = CenterContainer.new()
	button_center.add_child(button)
	vbox.add_child(button_center)

	# 底部间距
	var bottom_margin = Control.new()
	bottom_margin.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(bottom_margin)

	return card

func _on_soul_card_clicked(item, index: int):
	if selected_souls.has(item):
		# 取消选择
		selected_souls.erase(item)
	else:
		# 选择魂印
		if selected_souls.size() >= MAX_SELECTION:
			_show_message("最多只能选择 " + str(MAX_SELECTION) + " 个魂印！")
			return
		selected_souls.append(item)

	# 刷新显示
	_refresh_display()

func _refresh_display():
	_display_all_souls()
	_display_selected_souls()
	_update_stats()

func _display_selected_souls():
	# 清空已选区域
	for child in selected_container.get_children():
		child.queue_free()

	if selected_souls.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "还未选择任何魂印"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		selected_container.add_child(empty_label)
		return

	# 显示已选魂印
	for item in selected_souls:
		var slot = _create_selected_slot(item)
		selected_container.add_child(slot)

func _create_selected_slot(item) -> Panel:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(0, 60)

	var soul = item.soul_print
	var base_color = quality_colors.get(soul.quality, Color.WHITE)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = base_color
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6
	style.corner_radius_bottom_left = 6
	slot.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 10)
	slot.add_child(hbox)

	# 左边距
	var left_margin = Control.new()
	left_margin.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(left_margin)

	# 名称
	var name_label = Label.new()
	name_label.text = soul.name
	name_label.add_theme_color_override("font_color", base_color)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(name_label)

	# 间距
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	# 力量
	var power_label = Label.new()
	power_label.text = "+" + str(soul.power)
	power_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	power_label.add_theme_font_size_override("font_size", 16)
	power_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(power_label)

	# 右边距
	var right_margin = Control.new()
	right_margin.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(right_margin)

	return slot

func _update_stats():
	var total_power = 0
	for item in selected_souls:
		total_power += item.soul_print.power

	total_power_label.text = "总力量加成: +" + str(total_power)
	count_label.text = "已选择: " + str(selected_souls.size()) + "/" + str(MAX_SELECTION)

func _on_start_battle_button_pressed():
	if selected_souls.size() == 0:
		_show_message("至少需要选择一个魂印！")
		return

	# 保存选择的魂印到UserSession
	var session = get_node("/root/UserSession")
	session.set_meta("battle_selected_souls", selected_souls)

	# 跳转到战斗场景
	get_tree().change_scene_to_file("res://scenes/Battle.tscn")

func _on_cancel_button_pressed():
	# 取消战斗，返回地图（视为逃跑失败？或者允许返回？）
	_show_message("取消战斗将失去本轮探索进度！")
	# 暂时允许返回，后续可以添加惩罚机制
	get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _show_message(text: String):
	message_dialog.dialog_text = text
	message_dialog.popup_centered()
