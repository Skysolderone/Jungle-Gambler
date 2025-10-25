extends Control

@onready var map_info_label = $TopBar/MarginContainer/HBoxContainer/MapInfo
@onready var inventory_grid = $MainContent/HBoxContainer/LeftPanel/ScrollContainer/InventoryGrid
@onready var slots_container = $MainContent/HBoxContainer/RightPanel/SlotsContainer
@onready var total_power_label = $MainContent/HBoxContainer/RightPanel/StatsPanel/MarginContainer/VBoxContainer/TotalPowerLabel
@onready var count_label = $MainContent/HBoxContainer/RightPanel/StatsPanel/MarginContainer/VBoxContainer/CountLabel
@onready var brightness_overlay = $BrightnessOverlay

var current_username: String = ""
var selected_map = null
var loadout = []  # 配置的魂印列表（最多5个）
const MAX_LOADOUT_SIZE = 5

const SETTINGS_PATH = "user://settings.json"

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

func _ready():
	current_username = UserSession.get_username()
	_apply_brightness_from_settings()
	_load_selected_map()
	_create_loadout_slots()
	_load_inventory()

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
	
	var brightness = settings.get("brightness", 100.0)
	var alpha = (100.0 - brightness) / 100.0 * 0.7
	brightness_overlay.color = Color(0, 0, 0, alpha)

func _load_selected_map():
	if has_node("/root/UserSession"):
		var session = get_node("/root/UserSession")
		if session.has_meta("selected_map"):
			selected_map = session.get_meta("selected_map")
			map_info_label.text = "地图: " + selected_map.get("name", "未知")

func _get_soul_system():
	if has_node("/root/SoulPrintSystem"):
		return get_node("/root/SoulPrintSystem")
	return null

func _load_inventory():
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	var items = soul_system.get_user_inventory(current_username)
	
	# 清空网格
	for child in inventory_grid.get_children():
		child.queue_free()
	
	# 创建魂印卡片
	for item in items:
		var card = _create_soul_card(item)
		inventory_grid.add_child(card)

func _create_soul_card(item) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(140, 160)
	
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
	
	# 添加按钮
	var add_button = Button.new()
	add_button.text = "添加"
	add_button.custom_minimum_size = Vector2(100, 35)
	add_button.add_theme_font_size_override("font_size", 14)
	add_button.pressed.connect(_on_add_soul.bind(item))
	
	var button_center = CenterContainer.new()
	button_center.add_child(add_button)
	vbox.add_child(button_center)
	
	# 底部间距
	var bottom_margin = Control.new()
	bottom_margin.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(bottom_margin)
	
	return card

func _create_loadout_slots():
	for i in range(MAX_LOADOUT_SIZE):
		var slot = _create_empty_slot(i)
		slots_container.add_child(slot)

func _create_empty_slot(index: int) -> Panel:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(0, 80)
	slot.set_meta("slot_index", index)
	slot.set_meta("soul_item", null)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.35, 1)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	slot.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 15)
	slot.add_child(hbox)
	
	# 左边距
	var left_margin = Control.new()
	left_margin.custom_minimum_size = Vector2(15, 0)
	hbox.add_child(left_margin)
	
	# 槽位标签
	var slot_label = Label.new()
	slot_label.text = "槽位 " + str(index + 1)
	slot_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	slot_label.add_theme_font_size_override("font_size", 16)
	slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(slot_label)
	
	# 间距
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)
	
	return slot

func _on_add_soul(item):
	if loadout.size() >= MAX_LOADOUT_SIZE:
		return
	
	# 添加到配置
	loadout.append(item)
	
	# 更新槽位显示
	var slot_index = loadout.size() - 1
	var slot = slots_container.get_child(slot_index)
	_update_slot_display(slot, item)
	
	# 更新统计
	_update_stats()

func _update_slot_display(slot: Panel, item):
	# 清空槽位
	for child in slot.get_children():
		child.queue_free()
	
	slot.set_meta("soul_item", item)
	
	var soul = item.soul_print
	var base_color = quality_colors.get(soul.quality, Color.WHITE)
	
	# 更新边框颜色
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = base_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	slot.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 15)
	slot.add_child(hbox)
	
	# 左边距
	var left_margin = Control.new()
	left_margin.custom_minimum_size = Vector2(15, 0)
	hbox.add_child(left_margin)
	
	# 名称
	var name_label = Label.new()
	name_label.text = soul.name
	name_label.add_theme_color_override("font_color", base_color)
	name_label.add_theme_font_size_override("font_size", 16)
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
	power_label.add_theme_font_size_override("font_size", 18)
	power_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hbox.add_child(power_label)
	
	# 移除按钮
	var remove_button = Button.new()
	remove_button.text = "移除"
	remove_button.custom_minimum_size = Vector2(60, 40)
	remove_button.pressed.connect(_on_remove_soul.bind(slot.get_meta("slot_index")))
	hbox.add_child(remove_button)
	
	# 右边距
	var right_margin = Control.new()
	right_margin.custom_minimum_size = Vector2(10, 0)
	hbox.add_child(right_margin)

func _on_remove_soul(slot_index: int):
	if slot_index < 0 or slot_index >= loadout.size():
		return
	
	# 从配置中移除指定索引的魂印
	loadout.remove_at(slot_index)
	
	# 等待一帧确保队列中的节点被清理
	await get_tree().process_frame
	
	# 重新创建所有槽位
	for child in slots_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	_create_loadout_slots()
	
	# 重新显示已配置的魂印
	for i in range(loadout.size()):
		var slot = slots_container.get_child(i)
		_update_slot_display(slot, loadout[i])
	
	# 更新统计
	_update_stats()

func _update_stats():
	var total_power = 0
	for item in loadout:
		total_power += item.soul_print.power
	
	total_power_label.text = "总力量: " + str(total_power)
	count_label.text = "已配置: " + str(loadout.size()) + "/" + str(MAX_LOADOUT_SIZE)

func _on_start_button_pressed():
	if loadout.size() == 0:
		# 提示至少需要配置一个魂印
		return
	
	# 保存配置到全局
	if has_node("/root/UserSession"):
		var session = get_node("/root/UserSession")
		session.set_meta("soul_loadout", loadout)
	
	# 进入游戏地图
	get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/MapSelection.tscn")

