extends Control

@onready var grid_container = $MainContainer/HBoxContainer/InventoryPanel/MarginContainer/VBoxContainer/ScrollContainer/GridContainer
@onready var info_label = $TopBar/MarginContainer/HBoxContainer/InfoLabel
@onready var starter_pack_button = $MainContainer/HBoxContainer/InventoryPanel/MarginContainer/VBoxContainer/ToolBar/StarterPackButton

# 物品详情面板
@onready var item_name_label = $MainContainer/HBoxContainer/ItemDetailPanel/MarginContainer/VBoxContainer/ItemName
@onready var item_rarity_label = $MainContainer/HBoxContainer/ItemDetailPanel/MarginContainer/VBoxContainer/ItemRarity
@onready var item_type_label = $MainContainer/HBoxContainer/ItemDetailPanel/MarginContainer/VBoxContainer/ItemType
@onready var item_quantity_label = $MainContainer/HBoxContainer/ItemDetailPanel/MarginContainer/VBoxContainer/ItemQuantity
@onready var item_description_label = $MainContainer/HBoxContainer/ItemDetailPanel/MarginContainer/VBoxContainer/ItemDescription
@onready var item_value_label = $MainContainer/HBoxContainer/ItemDetailPanel/MarginContainer/VBoxContainer/ItemValue
@onready var use_button = $MainContainer/HBoxContainer/ItemDetailPanel/MarginContainer/VBoxContainer/ButtonsContainer/UseButton
@onready var discard_button = $MainContainer/HBoxContainer/ItemDetailPanel/MarginContainer/VBoxContainer/ButtonsContainer/DiscardButton

var current_username: String = ""
var selected_slot_index: int = -1
var slot_buttons: Array = []

# 稀有度颜色映射
var rarity_colors = {
	InventorySystem.ItemRarity.COMMON: Color(0.8, 0.8, 0.8),      # 灰白色
	InventorySystem.ItemRarity.UNCOMMON: Color(0.3, 1.0, 0.3),    # 绿色
	InventorySystem.ItemRarity.RARE: Color(0.3, 0.5, 1.0),        # 蓝色
	InventorySystem.ItemRarity.EPIC: Color(0.8, 0.3, 1.0),        # 紫色
	InventorySystem.ItemRarity.LEGENDARY: Color(1.0, 0.6, 0.0)    # 橙色
}

# 稀有度名称
var rarity_names = {
	InventorySystem.ItemRarity.COMMON: "普通",
	InventorySystem.ItemRarity.UNCOMMON: "非凡",
	InventorySystem.ItemRarity.RARE: "稀有",
	InventorySystem.ItemRarity.EPIC: "史诗",
	InventorySystem.ItemRarity.LEGENDARY: "传说"
}

# 物品类型名称
var type_names = {
	InventorySystem.ItemType.CONSUMABLE: "消耗品",
	InventorySystem.ItemType.EQUIPMENT: "装备",
	InventorySystem.ItemType.MATERIAL: "材料",
	InventorySystem.ItemType.SPECIAL: "特殊物品"
}

func _ready():
	if not UserSession.is_logged_in():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	
	current_username = UserSession.get_username()
	_check_starter_pack_eligibility()
	_create_inventory_slots()
	_refresh_inventory()

func _check_starter_pack_eligibility():
	# 检查是否已经领取过新手礼包
	var total_items = 0
	var inventory = InventorySystem.get_user_inventory(current_username)
	for slot in inventory:
		if not slot.is_empty():
			total_items += 1
	
	# 如果背包是空的，显示新手礼包按钮
	starter_pack_button.visible = (total_items == 0)

func _create_inventory_slots():
	# 清空现有槽位
	for child in grid_container.get_children():
		child.queue_free()
	slot_buttons.clear()
	
	var inventory_size = InventorySystem.get_inventory_size(current_username)
	
	# 创建背包槽位按钮
	for i in range(inventory_size):
		var slot_button = Button.new()
		slot_button.custom_minimum_size = Vector2(80, 80)
		slot_button.text = ""
		
		# 应用样式
		var style_normal = StyleBoxFlat.new()
		style_normal.bg_color = Color(0.2, 0.2, 0.25)
		style_normal.border_width_left = 2
		style_normal.border_width_top = 2
		style_normal.border_width_right = 2
		style_normal.border_width_bottom = 2
		style_normal.border_color = Color(0.3, 0.3, 0.35)
		style_normal.corner_radius_top_left = 4
		style_normal.corner_radius_top_right = 4
		style_normal.corner_radius_bottom_right = 4
		style_normal.corner_radius_bottom_left = 4
		slot_button.add_theme_stylebox_override("normal", style_normal)
		
		var style_hover = style_normal.duplicate()
		style_hover.bg_color = Color(0.3, 0.3, 0.35)
		slot_button.add_theme_stylebox_override("hover", style_hover)
		
		var style_pressed = style_hover.duplicate()
		slot_button.add_theme_stylebox_override("pressed", style_pressed)
		
		slot_button.pressed.connect(_on_slot_pressed.bind(i))
		
		grid_container.add_child(slot_button)
		slot_buttons.append(slot_button)

func _refresh_inventory():
	var inventory = InventorySystem.get_user_inventory(current_username)
	var used_slots = 0
	
	for i in range(slot_buttons.size()):
		var slot = inventory[i]
		var button = slot_buttons[i]
		
		if slot.is_empty():
			button.text = ""
			button.modulate = Color.WHITE
		else:
			used_slots += 1
			# 显示物品名称和数量
			if slot.item.stackable and slot.quantity > 1:
				button.text = slot.item.name + "\n×" + str(slot.quantity)
			else:
				button.text = slot.item.name
			
			# 根据稀有度设置颜色
			button.modulate = rarity_colors.get(slot.item.rarity, Color.WHITE)
			button.add_theme_font_size_override("font_size", 12)
	
	# 更新背包容量显示
	info_label.text = str(used_slots) + "/" + str(InventorySystem.get_inventory_size(current_username))
	
	# 如果有选中的槽位，更新详情
	if selected_slot_index >= 0:
		_show_item_details(selected_slot_index)

func _on_slot_pressed(slot_index: int):
	selected_slot_index = slot_index
	_show_item_details(slot_index)

func _show_item_details(slot_index: int):
	var inventory = InventorySystem.get_user_inventory(current_username)
	var slot = inventory[slot_index]
	
	if slot.is_empty():
		_clear_item_details()
		return
	
	var item = slot.item
	
	# 显示物品信息
	item_name_label.text = item.name
	item_name_label.add_theme_color_override("font_color", rarity_colors.get(item.rarity, Color.WHITE))
	
	item_rarity_label.text = rarity_names.get(item.rarity, "未知")
	item_rarity_label.add_theme_color_override("font_color", rarity_colors.get(item.rarity, Color.WHITE))
	
	item_type_label.text = "类型: " + type_names.get(item.type, "未知")
	item_quantity_label.text = "数量: " + str(slot.quantity)
	item_description_label.text = item.description if item.description != "" else "这个物品没有描述。"
	item_value_label.text = "价值: " + str(item.value) + " 金币"
	
	# 启用按钮
	use_button.disabled = false
	discard_button.disabled = false
	
	# 根据物品类型决定是否可以使用
	if item.type == InventorySystem.ItemType.MATERIAL:
		use_button.disabled = true

func _clear_item_details():
	item_name_label.text = "未选择物品"
	item_name_label.add_theme_color_override("font_color", Color.WHITE)
	item_rarity_label.text = ""
	item_type_label.text = ""
	item_quantity_label.text = ""
	item_description_label.text = ""
	item_value_label.text = ""
	use_button.disabled = true
	discard_button.disabled = true
	selected_slot_index = -1

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_sort_button_pressed():
	InventorySystem.sort_inventory(current_username)
	_refresh_inventory()
	_clear_item_details()

func _on_starter_pack_button_pressed():
	InventorySystem.give_starter_pack(current_username)
	starter_pack_button.visible = false
	_refresh_inventory()
	_show_message("新手礼包已领取！")

func _on_use_button_pressed():
	if selected_slot_index < 0:
		return
	
	var inventory = InventorySystem.get_user_inventory(current_username)
	var slot = inventory[selected_slot_index]
	
	if slot.is_empty():
		return
	
	var item_name = slot.item.name
	
	if InventorySystem.use_item(current_username, selected_slot_index):
		_show_message("使用了: " + item_name)
		_refresh_inventory()
	else:
		_show_message("无法使用该物品")

func _on_discard_button_pressed():
	if selected_slot_index < 0:
		return
	
	var inventory = InventorySystem.get_user_inventory(current_username)
	var slot = inventory[selected_slot_index]
	
	if slot.is_empty():
		return
	
	var item_name = slot.item.name
	
	# 丢弃1个物品
	if InventorySystem.discard_item(current_username, selected_slot_index, 1):
		_show_message("丢弃了: " + item_name)
		_refresh_inventory()

func _show_message(text: String):
	print(text)
	# 可以添加更好的消息提示UI
