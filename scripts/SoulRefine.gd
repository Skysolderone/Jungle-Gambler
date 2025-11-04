extends Control

signal refine_closed

@onready var background = $Background
@onready var main_panel = $MainPanel
@onready var close_button = $MainPanel/MarginContainer/VBoxContainer/TopBar/CloseButton
@onready var title_label = $MainPanel/MarginContainer/VBoxContainer/TopBar/TitleLabel
@onready var selected_souls_container = $MainPanel/MarginContainer/VBoxContainer/ContentContainer/SelectedSoulsPanel/MarginContainer/VBoxContainer/SelectedSoulsGrid
@onready var inventory_container = $MainPanel/MarginContainer/VBoxContainer/ContentContainer/InventoryPanel/MarginContainer/VBoxContainer/ScrollContainer/InventoryGrid
@onready var refine_button = $MainPanel/MarginContainer/VBoxContainer/BottomBar/RefineButton
@onready var info_label = $MainPanel/MarginContainer/VBoxContainer/BottomBar/InfoLabel
@onready var message_dialog = $MessageDialog

var current_username: String = ""
var selected_souls: Array = []  # 最多3个
var inventory_items: Array = []
const MAX_SELECTION = 3

func _ready():
	# 应用响应式布局
	_setup_responsive_layout()
	
	current_username = UserSession.get_username()
	_load_inventory()
	_update_ui()

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		responsive_manager.apply_responsive_layout(self)
		responsive_manager.optimize_for_touch(self)

func _load_inventory():
	var soul_system = get_node("/root/SoulPrintSystem")
	if soul_system:
		inventory_items = soul_system.get_user_inventory(current_username)

func _update_ui():
	_refresh_selected_souls()
	_refresh_inventory()
	_update_refine_button()

func _refresh_selected_souls():
	# 清空选中区域
	for child in selected_souls_container.get_children():
		child.queue_free()
	
	# 创建3个槽位
	for i in range(MAX_SELECTION):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(120, 140)
		
		var style = StyleBoxFlat.new()
		if i < selected_souls.size():
			# 已选中
			var soul_item = selected_souls[i]
			var soul = soul_item.soul_print
			style.bg_color = Color(0.2, 0.2, 0.25, 1)
			style.border_color = _get_quality_color(soul.quality)
			style.set_border_width_all(3)
		else:
			# 空槽位
			style.bg_color = Color(0.15, 0.15, 0.18, 0.8)
			style.border_color = Color(0.3, 0.3, 0.3, 1)
			style.set_border_width_all(2)
		
		style.set_corner_radius_all(8)
		slot.add_theme_stylebox_override("panel", style)
		
		if i < selected_souls.size():
			# 添加魂印信息
			var vbox = VBoxContainer.new()
			vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
			slot.add_child(vbox)
			
			var name_label = Label.new()
			name_label.text = selected_souls[i].soul_print.name
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_color_override("font_color", _get_quality_color(selected_souls[i].soul_print.quality))
			vbox.add_child(name_label)
		
		selected_souls_container.add_child(slot)

func _refresh_inventory():
	# 清空背包显示
	for child in inventory_container.get_children():
		child.queue_free()
	
	# 显示背包中的魂印
	for i in range(inventory_items.size()):
		var soul_item = inventory_items[i]
		var card = _create_soul_card(soul_item, i)
		inventory_container.add_child(card)

func _create_soul_card(soul_item, index: int) -> Button:
	var soul = soul_item.soul_print
	var button = Button.new()
	button.custom_minimum_size = Vector2(100, 120)
	
	var quality_color = _get_quality_color(soul.quality)
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.18, 1)
	style_normal.border_color = quality_color
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(8)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.2, 0.23, 1)
	style_hover.border_color = quality_color.lightened(0.3)
	style_hover.set_border_width_all(3)
	style_hover.set_corner_radius_all(8)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	
	# 添加文本
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.add_child(vbox)
	
	var name_label = Label.new()
	name_label.text = soul.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", quality_color)
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)
	
	var quality_label = Label.new()
	quality_label.text = _get_quality_name(soul.quality)
	quality_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label.add_theme_color_override("font_color", quality_color)
	quality_label.add_theme_font_size_override("font_size", 12)
	vbox.add_child(quality_label)
	
	# 连接点击事件
	button.pressed.connect(func(): _on_soul_card_clicked(index))
	
	return button

func _on_soul_card_clicked(index: int):
	if index < 0 or index >= inventory_items.size():
		return
	
	var soul_item = inventory_items[index]
	
	# 检查是否已选中
	if selected_souls.has(soul_item):
		selected_souls.erase(soul_item)
	elif selected_souls.size() < MAX_SELECTION:
		selected_souls.append(soul_item)
	else:
		_show_message("最多只能选择3个魂印！")
		return
	
	_update_ui()

func _update_refine_button():
	if selected_souls.size() == MAX_SELECTION:
		# 检查是否同品质
		var first_quality = selected_souls[0].soul_print.quality
		var same_quality = true
		for soul_item in selected_souls:
			if soul_item.soul_print.quality != first_quality:
				same_quality = false
				break
		
		if same_quality:
			refine_button.disabled = false
			info_label.text = "选择3个" + _get_quality_name(first_quality) + "魂印，精炼成功率：" + str(_get_refine_chance(first_quality)) + "%"
		else:
			refine_button.disabled = true
			info_label.text = "请选择3个相同品质的魂印"
	else:
		refine_button.disabled = true
		info_label.text = "请选择3个魂印（" + str(selected_souls.size()) + "/3）"

func _on_refine_button_pressed():
	if selected_souls.size() != MAX_SELECTION:
		return
	
	var quality = selected_souls[0].soul_print.quality
	var chance = _get_refine_chance(quality)
	
	# 随机判断是否成功
	var success = randf() * 100 < chance
	
	# 移除选中的魂印
	var soul_system = get_node("/root/SoulPrintSystem")
	for soul_item in selected_souls:
		var item_index = inventory_items.find(soul_item)
		if item_index >= 0:
			soul_system.remove_soul_print(current_username, item_index)
			inventory_items = soul_system.get_user_inventory(current_username)
	
	if success and quality < 5:  # 神话品质无法再提升
		# 成功：获得更高品质的随机魂印
		var new_quality = quality + 1
		var available_souls = _get_souls_by_quality(new_quality)
		if available_souls.size() > 0:
			var random_soul_id = available_souls[randi() % available_souls.size()]
			soul_system.add_soul_print(current_username, random_soul_id)
			
			var new_soul = soul_system.get_soul_by_id(random_soul_id)
			_show_message("精炼成功！\n获得：" + new_soul.name + "（" + _get_quality_name(new_quality) + "）")
	else:
		# 失败
		_show_message("精炼失败！\n3个魂印已消失...")
	
	# 重置选择
	selected_souls.clear()
	inventory_items = soul_system.get_user_inventory(current_username)
	_update_ui()

func _get_refine_chance(quality: int) -> int:
	# 品质越高，成功率越低
	match quality:
		0: return 80  # 普通 -> 非凡 80%
		1: return 60  # 非凡 -> 稀有 60%
		2: return 40  # 稀有 -> 史诗 40%
		3: return 25  # 史诗 -> 传说 25%
		4: return 10  # 传说 -> 神话 10%
		_: return 0

func _get_souls_by_quality(quality: int) -> Array:
	var soul_system = get_node("/root/SoulPrintSystem")
	var result = []
	
	# 获取所有该品质的魂印ID
	for soul_id in soul_system.soul_database.keys():
		var soul = soul_system.get_soul_by_id(soul_id)
		if soul and soul.quality == quality:
			result.append(soul_id)
	
	return result

func _get_quality_color(quality: int) -> Color:
	match quality:
		0: return Color(0.6, 0.6, 0.6)      # 普通 - 灰色
		1: return Color(0.3, 0.8, 0.3)      # 非凡 - 绿色
		2: return Color(0.3, 0.5, 1.0)      # 稀有 - 蓝色
		3: return Color(0.7, 0.3, 1.0)      # 史诗 - 紫色
		4: return Color(1.0, 0.6, 0.1)      # 传说 - 橙色
		5: return Color(1.0, 0.8, 0.3)      # 神话 - 金色
		_: return Color.WHITE

func _get_quality_name(quality: int) -> String:
	match quality:
		0: return "普通"
		1: return "非凡"
		2: return "稀有"
		3: return "史诗"
		4: return "传说"
		5: return "神话"
		_: return "未知"

func _show_message(text: String):
	message_dialog.dialog_text = text
	message_dialog.popup_centered()

func _on_close_button_pressed():
	refine_closed.emit()
