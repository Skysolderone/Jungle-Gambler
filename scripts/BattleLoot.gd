extends Control

# 战利品选择场景

@onready var title_label = $TopBar/MarginContainer/HBoxContainer/TitleLabel
@onready var loot_grid = $MainContent/HBoxContainer/LeftPanel/ScrollContainer/LootGrid
@onready var inventory_grid = $MainContent/HBoxContainer/RightPanel/ScrollContainer/InventoryGrid
@onready var message_label = $MainContent/HBoxContainer/LeftPanel/MessageLabel
@onready var brightness_overlay = $BrightnessOverlay
@onready var message_dialog = $MessageDialog

# 战利品数据
var loot_souls: Array = []
var player_all_souls: Array = []
var username: String = ""

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
	_load_loot_data()
	_process_loot()

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

func _load_loot_data():
	var session = get_node("/root/UserSession")
	username = session.get_username()

	if session.has_meta("battle_loot_souls"):
		loot_souls = session.get_meta("battle_loot_souls")

	# 获取当前背包
	var soul_system = _get_soul_system()
	if soul_system:
		player_all_souls = soul_system.get_user_inventory(username)

func _process_loot():
	# 尝试自动添加所有战利品
	var soul_system = _get_soul_system()
	if not soul_system:
		_show_message("系统错误：无法获取魂印系统")
		return

	var added_souls = []
	for soul in loot_souls:
		if soul_system.add_soul_print(username, soul.id):
			added_souls.append(soul)
			print("成功自动添加战利品：", soul.name)

	# 从战利品列表中移除已添加的
	for soul in added_souls:
		loot_souls.erase(soul)

	# 刷新背包数据
	player_all_souls = soul_system.get_user_inventory(username)

	# 显示结果
	if loot_souls.size() == 0:
		# 所有战利品都已添加
		message_label.text = "恭喜！所有战利品已添加到背包！"
		_display_loot()
		_hide_inventory_panel()
	else:
		# 还有剩余战利品
		message_label.text = "背包空间不足！请丢弃旧魂印来获取新战利品"
		_display_loot()
		_display_inventory()

func _display_loot():
	# 清空网格
	for child in loot_grid.get_children():
		child.queue_free()

	if loot_souls.size() == 0:
		var empty_label = Label.new()
		empty_label.text = "所有战利品已获得"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3))
		loot_grid.add_child(empty_label)
		return

	# 显示剩余战利品
	for soul in loot_souls:
		var card = _create_loot_card(soul)
		loot_grid.add_child(card)

func _display_inventory():
	# 清空网格
	for child in inventory_grid.get_children():
		child.queue_free()

	# 显示背包魂印（可以丢弃）
	for i in range(player_all_souls.size()):
		var item = player_all_souls[i]
		var card = _create_inventory_card(item, i)
		inventory_grid.add_child(card)

func _hide_inventory_panel():
	$MainContent/HBoxContainer/RightPanel.visible = false

func _create_loot_card(soul) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(120, 140)

	var base_color = quality_colors.get(soul.quality, Color.WHITE)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = base_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	# 间距
	var top_margin = Control.new()
	top_margin.custom_minimum_size = Vector2(0, 8)
	vbox.add_child(top_margin)

	# 名称
	var name_label = Label.new()
	name_label.text = soul.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", base_color)
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# 品质
	var quality_label = Label.new()
	quality_label.text = quality_names.get(soul.quality, "未知")
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.add_theme_color_override("font_color", base_color)
	quality_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(quality_label)

	# 力量
	var power_label = Label.new()
	power_label.text = "+" + str(soul.power)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	power_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(power_label)

	return card

func _create_inventory_card(item, index: int) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(120, 140)

	var soul = item.soul_print
	var base_color = quality_colors.get(soul.quality, Color.WHITE)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = base_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	# 间距
	var top_margin = Control.new()
	top_margin.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(top_margin)

	# 名称
	var name_label = Label.new()
	name_label.text = soul.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", base_color)
	name_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(name_label)

	# 品质
	var quality_label = Label.new()
	quality_label.text = quality_names.get(soul.quality, "未知")
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.add_theme_color_override("font_color", base_color)
	quality_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(quality_label)

	# 力量
	var power_label = Label.new()
	power_label.text = "+" + str(soul.power)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	power_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(power_label)

	# 间距
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	# 丢弃按钮
	var discard_button = Button.new()
	discard_button.text = "丢弃"
	discard_button.custom_minimum_size = Vector2(80, 25)
	discard_button.add_theme_font_size_override("font_size", 12)
	discard_button.pressed.connect(_on_discard_soul.bind(index))

	var button_center = CenterContainer.new()
	button_center.add_child(discard_button)
	vbox.add_child(button_center)

	# 底部间距
	var bottom_margin = Control.new()
	bottom_margin.custom_minimum_size = Vector2(0, 5)
	vbox.add_child(bottom_margin)

	return card

func _on_discard_soul(index: int):
	var soul_system = _get_soul_system()
	if not soul_system:
		return

	# 重新获取当前背包（可能已经变化）
	player_all_souls = soul_system.get_user_inventory(username)

	if index >= player_all_souls.size():
		print("索引越界：", index, " >= ", player_all_souls.size())
		return

	var item = player_all_souls[index]
	print("丢弃魂印：", item.soul_print.name)

	# 从背包移除
	var removed = soul_system.remove_soul_print(username, index)
	if not removed:
		print("移除失败")
		return

	# 尝试添加一个战利品
	if loot_souls.size() > 0:
		var soul_to_add = loot_souls[0]
		if soul_system.add_soul_print(username, soul_to_add.id):
			print("成功添加战利品：", soul_to_add.name)
			loot_souls.remove_at(0)

			# 检查是否所有战利品都已获得
			if loot_souls.size() == 0:
				message_label.text = "恭喜！所有战利品已获得！"

	# 刷新显示
	_refresh_display()

func _refresh_display():
	player_all_souls = _get_soul_system().get_user_inventory(username)
	_display_loot()
	if loot_souls.size() > 0:
		_display_inventory()
	else:
		_hide_inventory_panel()

func _on_continue_button_pressed():
	# 保存战斗结果并返回地图
	var session = get_node("/root/UserSession")

	# 计算玩家HP变化
	var initial_hp = session.get_meta("battle_player_hp") if session.has_meta("battle_player_hp") else 100
	var final_hp = session.get_meta("battle_player_hp_final") if session.has_meta("battle_player_hp_final") else 100

	# 获取所有已添加的战利品
	var original_loot = session.get_meta("battle_loot_souls") if session.has_meta("battle_loot_souls") else []
	var obtained_souls = []
	for soul in original_loot:
		if not loot_souls.has(soul):  # 不在剩余列表中，说明已获得
			obtained_souls.append(soul)

	session.set_meta("battle_result", {
		"won": true,
		"player_hp_change": final_hp - initial_hp,
		"loot_souls": obtained_souls
	})

	# 清理战斗数据
	session.remove_meta("battle_won")
	session.remove_meta("battle_player_hp_final")
	session.remove_meta("battle_loot_souls")

	# 返回地图
	get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _get_soul_system():
	if has_node("/root/SoulPrintSystem"):
		return get_node("/root/SoulPrintSystem")
	return null

func _show_message(text: String):
	message_dialog.dialog_text = text
	message_dialog.popup_centered()
