extends Control

@onready var grid_container = $MainContainer/InventoryPanel/MarginContainer/VBoxContainer/GridContainer
@onready var info_label = $TopBar/MarginContainer/HBoxContainer/InfoLabel
@onready var rotate_button = $MainContainer/InventoryPanel/MarginContainer/VBoxContainer/ToolBar/RotateButton
@onready var delete_button = $MainContainer/InventoryPanel/MarginContainer/VBoxContainer/ToolBar/DeleteButton
@onready var starter_button = $MainContainer/InventoryPanel/MarginContainer/VBoxContainer/ToolBar/StarterButton

# 详情面板
@onready var soul_name_label = $MainContainer/SoulDetailPanel/ScrollContainer/MarginContainer/VBoxContainer/SoulName
@onready var soul_quality_label = $MainContainer/SoulDetailPanel/ScrollContainer/MarginContainer/VBoxContainer/SoulQuality
@onready var soul_shape_label = $MainContainer/SoulDetailPanel/ScrollContainer/MarginContainer/VBoxContainer/SoulShape
@onready var soul_description_label = $MainContainer/SoulDetailPanel/ScrollContainer/MarginContainer/VBoxContainer/SoulDescription
@onready var soul_power_label = $MainContainer/SoulDetailPanel/ScrollContainer/MarginContainer/VBoxContainer/SoulPower

var current_username: String = ""
var selected_item_index: int = -1
var dragging_item_index: int = -1
var drag_offset: Vector2 = Vector2.ZERO

# 网格设置
const CELL_SIZE = 60
const GRID_WIDTH = 10
const GRID_HEIGHT = 8

# 品质颜色
var quality_colors = {
	0: Color(0.8, 0.8, 0.8),      # COMMON - 白色
	1: Color(0.3, 1.0, 0.3),      # UNCOMMON - 绿色
	2: Color(0.3, 0.5, 1.0),      # RARE - 蓝色
	3: Color(0.8, 0.3, 1.0),      # EPIC - 紫色
	4: Color(1.0, 0.6, 0.0),      # LEGENDARY - 橙色
	5: Color(1.0, 0.2, 0.2)       # MYTHIC - 红色
}

# 品质名称
var quality_names = {
	0: "普通",
	1: "非凡",
	2: "稀有",
	3: "史诗",
	4: "传说",
	5: "神话"
}

# 形状名称
var shape_names = {
	0: "1×1 正方形",
	1: "2×2 正方形",
	2: "1×2 矩形",
	3: "2×1 矩形",
	4: "1×3 矩形",
	5: "3×1 矩形",
	6: "L形状",
	7: "T形状",
	8: "三角形"
}

func _ready():
	if not UserSession.is_logged_in():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return
	
	current_username = UserSession.get_username()
	
	# 设置网格容器绘制
	grid_container.draw.connect(_draw_grid)
	
	_check_starter_eligibility()
	_refresh_inventory()

func _get_soul_system():
	if has_node("/root/SoulPrintSystem"):
		return get_node("/root/SoulPrintSystem")
	return null

func _check_starter_eligibility():
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	var items = soul_system.get_user_inventory(current_username)
	starter_button.visible = (items.size() == 0)

func _refresh_inventory():
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	var items = soul_system.get_user_inventory(current_username)
	
	# 显示魂印个数，而不是占用的格子数
	info_label.text = "魂印: " + str(items.size())
	grid_container.queue_redraw()

func _draw_grid():
	# 绘制背包网格
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	var items = soul_system.get_user_inventory(current_username)
	
	# 绘制网格线
	for x in range(GRID_WIDTH + 1):
		var start = Vector2(x * CELL_SIZE, 0)
		var end = Vector2(x * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)
		grid_container.draw_line(start, end, Color(0.4, 0.4, 0.45), 1.0)
	
	for y in range(GRID_HEIGHT + 1):
		var start = Vector2(0, y * CELL_SIZE)
		var end = Vector2(GRID_WIDTH * CELL_SIZE, y * CELL_SIZE)
		grid_container.draw_line(start, end, Color(0.4, 0.4, 0.45), 1.0)
	
	# 绘制已放置的魂印
	for i in range(items.size()):
		if i == dragging_item_index:
			continue  # 跳过正在拖拽的物品
		
		var item = items[i]
		_draw_soul_item(item, i == selected_item_index)

func _draw_soul_item(item, is_selected: bool):
	var cells = item.get_occupied_cells()
	var color = quality_colors.get(item.soul_print.quality, Color.WHITE)
	
	if is_selected:
		color = color.lightened(0.3)
	
	# 绘制每个占用的格子
	for cell in cells:
		var x = cell[0]
		var y = cell[1]
		
		if x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT:
			var rect = Rect2(x * CELL_SIZE + 2, y * CELL_SIZE + 2, CELL_SIZE - 4, CELL_SIZE - 4)
			grid_container.draw_rect(rect, color, true)
			
			# 绘制边框
			grid_container.draw_rect(rect, color.lightened(0.2), false, 2.0)
	
	# 在第一个格子绘制名称
	if cells.size() > 0:
		var first_cell = cells[0]
		var text_pos = Vector2(first_cell[0] * CELL_SIZE + 5, first_cell[1] * CELL_SIZE + 20)
		grid_container.draw_string(ThemeDB.fallback_font, text_pos, item.soul_print.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_grid_click(event.position)
			else:
				_on_grid_release(event.position)
	
	elif event is InputEventMouseMotion:
		if dragging_item_index >= 0:
			grid_container.queue_redraw()
	
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_on_rotate_button_pressed()
		elif event.keycode == KEY_DELETE:
			_on_delete_button_pressed()

func _on_grid_click(_mouse_pos: Vector2):
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	var local_pos = grid_container.get_local_mouse_position()
	var grid_x = int(local_pos.x / CELL_SIZE)
	var grid_y = int(local_pos.y / CELL_SIZE)
	
	if grid_x < 0 or grid_x >= GRID_WIDTH or grid_y < 0 or grid_y >= GRID_HEIGHT:
		return
	
	# 检查点击的格子是否有魂印
	var items = soul_system.get_user_inventory(current_username)
	for i in range(items.size()):
		var item = items[i]
		var cells = item.get_occupied_cells()
		
		for cell in cells:
			if cell[0] == grid_x and cell[1] == grid_y:
				selected_item_index = i
				dragging_item_index = i
				drag_offset = local_pos - Vector2(item.grid_x * CELL_SIZE, item.grid_y * CELL_SIZE)
				_show_soul_details(i)
				rotate_button.disabled = false
				delete_button.disabled = false
				grid_container.queue_redraw()
				return
	
	# 没有点击到任何魂印
	selected_item_index = -1
	dragging_item_index = -1
	_clear_soul_details()
	rotate_button.disabled = true
	delete_button.disabled = true
	grid_container.queue_redraw()

func _on_grid_release(_mouse_pos: Vector2):
	if dragging_item_index < 0:
		return
	
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	var local_pos = grid_container.get_local_mouse_position()
	var new_grid_x = int((local_pos.x - drag_offset.x + CELL_SIZE / 2.0) / CELL_SIZE)
	var new_grid_y = int((local_pos.y - drag_offset.y + CELL_SIZE / 2.0) / CELL_SIZE)
	
	# 尝试移动魂印
	if soul_system.move_soul_print(current_username, dragging_item_index, new_grid_x, new_grid_y):
		print("魂印已移动到: ", new_grid_x, ", ", new_grid_y)
	else:
		print("无法移动到该位置")
	
	dragging_item_index = -1
	_refresh_inventory()

func _show_soul_details(item_index: int):
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	var items = soul_system.get_user_inventory(current_username)
	if item_index < 0 or item_index >= items.size():
		return
	
	var item = items[item_index]
	var soul = item.soul_print
	
	soul_name_label.text = soul.name
	soul_name_label.add_theme_color_override("font_color", quality_colors.get(soul.quality, Color.WHITE))
	
	soul_quality_label.text = quality_names.get(soul.quality, "未知")
	soul_quality_label.add_theme_color_override("font_color", quality_colors.get(soul.quality, Color.WHITE))
	
	soul_shape_label.text = "形状: " + shape_names.get(soul.shape_type, "未知")
	soul_description_label.text = soul.description if soul.description != "" else "这个魂印充满了神秘的力量..."
	soul_power_label.text = "力量值: " + str(soul.power)

func _clear_soul_details():
	soul_name_label.text = "未选择魂印"
	soul_name_label.add_theme_color_override("font_color", Color.WHITE)
	soul_quality_label.text = ""
	soul_shape_label.text = ""
	soul_description_label.text = ""
	soul_power_label.text = ""

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _on_rotate_button_pressed():
	if selected_item_index < 0:
		return
	
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	var items = soul_system.get_user_inventory(current_username)
	if selected_item_index >= items.size():
		return
	
	var item = items[selected_item_index]
	var new_rotation = (item.rotation + 1) % 4
	
	if soul_system.move_soul_print(current_username, selected_item_index, item.grid_x, item.grid_y, new_rotation):
		print("魂印已旋转")
		_refresh_inventory()
	else:
		print("无法旋转，空间不足")

func _on_delete_button_pressed():
	if selected_item_index < 0:
		return
	
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	if soul_system.remove_soul_print(current_username, selected_item_index):
		print("魂印已删除")
		selected_item_index = -1
		_clear_soul_details()
		rotate_button.disabled = true
		delete_button.disabled = true
		_refresh_inventory()

func _on_starter_button_pressed():
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	soul_system.give_starter_souls(current_username)
	starter_button.visible = false
	_refresh_inventory()

