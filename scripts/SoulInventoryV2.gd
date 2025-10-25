extends Control

# 暗黑破坏神3 风格的魂印背包

signal inventory_closed

@onready var grid_container = $MainPanel/ContentContainer/LeftPanel/GridPanel/GridContainer
@onready var count_label = $MainPanel/TopBar/CountLabel
@onready var rotate_button = $MainPanel/ContentContainer/LeftPanel/ToolBar/RotateButton
@onready var delete_button = $MainPanel/ContentContainer/LeftPanel/ToolBar/DeleteButton
@onready var starter_button = $MainPanel/ContentContainer/LeftPanel/ToolBar/StarterButton

# 详情面板
@onready var soul_name = $MainPanel/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/SoulName
@onready var quality_value = $MainPanel/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/QualityContainer/Value
@onready var shape_value = $MainPanel/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/ShapeContainer/Value
@onready var power_value = $MainPanel/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/PowerContainer/Value
@onready var description_label = $MainPanel/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/DescriptionLabel

# 提示面板
@onready var tooltip_panel = $TooltipPanel
@onready var tooltip_label = $TooltipPanel/TooltipMargin/TooltipText

var current_username: String = ""
var selected_item_index: int = -1
var dragging_item_index: int = -1
var drag_offset: Vector2 = Vector2.ZERO
var hover_item_index: int = -1

# 网格设置  
const CELL_SIZE = 50
const GRID_WIDTH = 10
const GRID_HEIGHT = 10

# 品质颜色（暗黑3风格）
var quality_colors = {
	0: Color(0.6, 0.6, 0.6),      # COMMON - 灰色
	1: Color(0.2, 0.8, 0.2),      # UNCOMMON - 绿色
	2: Color(0.2, 0.4, 1.0),      # RARE - 蓝色
	3: Color(0.7, 0.2, 1.0),      # EPIC - 紫色
	4: Color(1.0, 0.5, 0.0),      # LEGENDARY - 橙色
	5: Color(1.0, 0.1, 0.1)       # MYTHIC - 红色
}

var quality_names = {
	0: "普通",
	1: "非凡",
	2: "稀有",
	3: "史诗",
	4: "传说",
	5: "神话"
}

var shape_names = {
	0: "1×1 正方形", 1: "2×2 正方形", 2: "1×2 矩形", 
	3: "2×1 矩形", 4: "1×3 矩形", 5: "3×1 矩形",
	6: "L形状", 7: "T形状", 8: "三角形"
}

func _ready():
	# 应用响应式布局
	_setup_responsive_layout()
	
	current_username = UserSession.get_username()
	
	grid_container.draw.connect(_draw_grid)
	grid_container.gui_input.connect(_on_grid_gui_input)
	grid_container.mouse_entered.connect(_on_grid_mouse_entered)
	grid_container.mouse_exited.connect(_on_grid_mouse_exited)
	
	_check_starter_eligibility()
	_refresh_inventory()

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		
		# 连接屏幕类型变化信号
		responsive_manager.screen_type_changed.connect(_on_screen_type_changed)
		
		# 应用响应式布局
		responsive_manager.apply_responsive_layout(self)
		
		# 为移动端优化触摸
		responsive_manager.optimize_for_touch(self)
		
		# 根据屏幕类型调整布局
		_adjust_layout_for_screen(responsive_manager.current_screen_type)
		
		print("魂印背包已启用响应式布局，屏幕类型：", responsive_manager.get_screen_type_name())

func _on_screen_type_changed(_new_type):
	# 屏幕类型变化时重新应用布局
	_setup_responsive_layout()

func _adjust_layout_for_screen(screen_type):
	var content_container = $MainPanel/ContentContainer
	
	# 在移动端竖屏时将左右面板垂直排列
	if screen_type == 0:  # MOBILE_PORTRAIT
		content_container.vertical = true
		# 调整面板比例
		var left_panel = $MainPanel/ContentContainer/LeftPanel
		var right_panel = $MainPanel/ContentContainer/RightPanel
		left_panel.size_flags_stretch_ratio = 1.5
		right_panel.size_flags_stretch_ratio = 1.0
	else:
		# 其他情况水平排列
		content_container.vertical = false
		var left_panel = $MainPanel/ContentContainer/LeftPanel
		var right_panel = $MainPanel/ContentContainer/RightPanel
		left_panel.size_flags_stretch_ratio = 2.0
		right_panel.size_flags_stretch_ratio = 1.0

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
	count_label.text = "魂印: " + str(items.size())
	grid_container.queue_redraw()

func _draw_grid():
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	var items = soul_system.get_user_inventory(current_username)
	
	# 绘制一个透明的背景矩形，确保可以接收鼠标事件
	var bg_rect = Rect2(0, 0, GRID_WIDTH * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)
	grid_container.draw_rect(bg_rect, Color(0, 0, 0, 0.01), true)
	
	# 绘制网格线（暗黑风格）
	for x in range(GRID_WIDTH + 1):
		var start = Vector2(x * CELL_SIZE, 0)
		var end = Vector2(x * CELL_SIZE, GRID_HEIGHT * CELL_SIZE)
		var color = Color(0.3, 0.25, 0.1, 0.5)
		grid_container.draw_line(start, end, color, 1.0)
	
	for y in range(GRID_HEIGHT + 1):
		var start = Vector2(0, y * CELL_SIZE)
		var end = Vector2(GRID_WIDTH * CELL_SIZE, y * CELL_SIZE)
		var color = Color(0.3, 0.25, 0.1, 0.5)
		grid_container.draw_line(start, end, color, 1.0)
	
	# 绘制魂印（带发光效果）
	for i in range(items.size()):
		if i == dragging_item_index:
			continue
		
		var item = items[i]
		var is_selected = (i == selected_item_index)
		var is_hover = (i == hover_item_index)
		_draw_soul_item(item, is_selected, is_hover)
	
	# 绘制拖拽中的魂印
	if dragging_item_index >= 0 and dragging_item_index < items.size():
		var drag_item = items[dragging_item_index]
		var mouse_pos = grid_container.get_local_mouse_position()
		_draw_dragging_item(drag_item, mouse_pos)

func _draw_soul_item(item, is_selected: bool, is_hover: bool):
	var cells = item.get_occupied_cells()
	var base_color = quality_colors.get(item.soul_print.quality, Color.WHITE)
	
	# 计算颜色（暗黑风格：中心亮，边缘暗）
	var fill_color = base_color * 0.3
	if is_selected:
		fill_color = base_color * 0.5
	elif is_hover:
		fill_color = base_color * 0.4
	
	# 绘制每个格子
	for cell in cells:
		var x = cell[0]
		var y = cell[1]
		
		if x >= 0 and x < GRID_WIDTH and y >= 0 and y < GRID_HEIGHT:
			var rect = Rect2(x * CELL_SIZE + 2, y * CELL_SIZE + 2, CELL_SIZE - 4, CELL_SIZE - 4)
			
			# 绘制填充
			grid_container.draw_rect(rect, fill_color, true)
			
			# 绘制发光边框（暗黑风格）
			var border_color = base_color
			if is_selected or is_hover:
				border_color = base_color.lightened(0.3)
			grid_container.draw_rect(rect, border_color, false, 2.0)
			
			# 内发光
			var inner_rect = Rect2(x * CELL_SIZE + 4, y * CELL_SIZE + 4, CELL_SIZE - 8, CELL_SIZE - 8)
			grid_container.draw_rect(inner_rect, base_color * 0.2, false, 1.0)
	
	# 在中心位置绘制名称
	if cells.size() > 0:
		var center_x = 0
		var center_y = 0
		for cell in cells:
			center_x += cell[0]
			center_y += cell[1]
		center_x = center_x / cells.size()
		center_y = center_y / cells.size()
		
		var text_pos = Vector2(center_x * CELL_SIZE + CELL_SIZE / 2.0, center_y * CELL_SIZE + CELL_SIZE / 2.0)
		var font = ThemeDB.fallback_font
		var text = item.soul_print.name
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		text_pos.x -= text_size.x / 2.0
		text_pos.y += 7
		
		# 文字阴影
		grid_container.draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		# 文字本体
		grid_container.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, base_color.lightened(0.5))

func _draw_dragging_item(item, mouse_pos: Vector2):
	var shape = item.soul_print.get_rotated_shape(item.rotation)
	var base_color = quality_colors.get(item.soul_print.quality, Color.WHITE)
	var fill_color = base_color * 0.6  # 拖拽时更亮
	
	# 计算起始位置（相对于鼠标位置减去拖拽偏移）
	var start_pos = mouse_pos - drag_offset
	
	# 绘制每个格子
	for offset in shape:
		var x = start_pos.x + offset[0] * CELL_SIZE
		var y = start_pos.y + offset[1] * CELL_SIZE
		var rect = Rect2(x + 2, y + 2, CELL_SIZE - 4, CELL_SIZE - 4)
		
		# 半透明填充
		grid_container.draw_rect(rect, fill_color * Color(1, 1, 1, 0.7), true)
		
		# 发光边框
		var border_color = base_color.lightened(0.4)
		grid_container.draw_rect(rect, border_color, false, 3.0)
	
	# 绘制名称
	if shape.size() > 0:
		var center_x = 0.0
		var center_y = 0.0
		for offset in shape:
			center_x += offset[0]
			center_y += offset[1]
		center_x = center_x / shape.size()
		center_y = center_y / shape.size()
		
		var text_pos = Vector2(
			start_pos.x + center_x * CELL_SIZE + CELL_SIZE / 2.0,
			start_pos.y + center_y * CELL_SIZE + CELL_SIZE / 2.0 + 7
		)
		var font = ThemeDB.fallback_font
		var text = item.soul_print.name
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
		text_pos.x -= text_size.x / 2.0
		
		# 文字阴影
		grid_container.draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
		# 文字本体
		grid_container.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, base_color.lightened(0.6))

func _input(event):
	# 处理鼠标事件
	if event is InputEventMouseButton:
		var local_pos = grid_container.get_local_mouse_position()
		var in_grid = grid_container.get_rect().has_point(local_pos)
		
		if in_grid:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_on_grid_click(local_pos)
					get_viewport().set_input_as_handled()
				else:
					_on_grid_release(local_pos)
					get_viewport().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		var local_pos = grid_container.get_local_mouse_position()
		var in_grid = grid_container.get_rect().has_point(local_pos)
		if in_grid:
			_on_mouse_move(local_pos)
			if dragging_item_index >= 0:
				grid_container.queue_redraw()
	
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_on_rotate_button_pressed()
		elif event.keycode == KEY_DELETE:
			_on_delete_button_pressed()
		elif event.keycode == KEY_ESCAPE:
			inventory_closed.emit()
			get_viewport().set_input_as_handled()

func _on_grid_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_grid_click(event.position)
			else:
				_on_grid_release(event.position)
	
	elif event is InputEventMouseMotion:
		_on_mouse_move(event.position)
		if dragging_item_index >= 0:
			grid_container.queue_redraw()

func _on_grid_mouse_entered():
	pass

func _on_grid_mouse_exited():
	if hover_item_index >= 0:
		hover_item_index = -1
		tooltip_panel.visible = false
		grid_container.queue_redraw()

func _on_grid_click(mouse_pos: Vector2):
	var grid_x = int(mouse_pos.x / CELL_SIZE)
	var grid_y = int(mouse_pos.y / CELL_SIZE)
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	if grid_x < 0 or grid_x >= GRID_WIDTH or grid_y < 0 or grid_y >= GRID_HEIGHT:
		return
	
	var items = soul_system.get_user_inventory(current_username)
	for i in range(items.size()):
		var item = items[i]
		var cells = item.get_occupied_cells()
		
		for cell in cells:
			if cell[0] == grid_x and cell[1] == grid_y:
				selected_item_index = i
				dragging_item_index = i
				drag_offset = mouse_pos - Vector2(item.grid_x * CELL_SIZE, item.grid_y * CELL_SIZE)
				tooltip_panel.visible = false
				_show_soul_details(i)
				rotate_button.disabled = false
				delete_button.disabled = false
				grid_container.queue_redraw()
				return
	
	selected_item_index = -1
	dragging_item_index = -1
	_clear_soul_details()
	rotate_button.disabled = true
	delete_button.disabled = true
	grid_container.queue_redraw()

func _on_grid_release(mouse_pos: Vector2):
	if dragging_item_index < 0:
		return
	
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	var new_grid_x = int((mouse_pos.x - drag_offset.x + CELL_SIZE / 2.0) / CELL_SIZE)
	var new_grid_y = int((mouse_pos.y - drag_offset.y + CELL_SIZE / 2.0) / CELL_SIZE)
	
	soul_system.move_soul_print(current_username, dragging_item_index, new_grid_x, new_grid_y)
	
	dragging_item_index = -1
	_refresh_inventory()

func _on_mouse_move(mouse_pos: Vector2):
	if dragging_item_index >= 0:
		tooltip_panel.visible = false
		return
	
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	var grid_x = int(mouse_pos.x / CELL_SIZE)
	var grid_y = int(mouse_pos.y / CELL_SIZE)
	
	if grid_x < 0 or grid_x >= GRID_WIDTH or grid_y < 0 or grid_y >= GRID_HEIGHT:
		if hover_item_index >= 0:
			hover_item_index = -1
			tooltip_panel.visible = false
			grid_container.queue_redraw()
		return
	
	var items = soul_system.get_user_inventory(current_username)
	var old_hover = hover_item_index
	hover_item_index = -1
	
	for i in range(items.size()):
		var item = items[i]
		var cells = item.get_occupied_cells()
		for cell in cells:
			if cell[0] == grid_x and cell[1] == grid_y:
				hover_item_index = i
				break
		if hover_item_index >= 0:
			break
	
	if old_hover != hover_item_index:
		grid_container.queue_redraw()
	
	# 显示提示
	if hover_item_index >= 0 and hover_item_index != selected_item_index:
		var item = items[hover_item_index]
		_show_tooltip(item, get_global_mouse_position())
	else:
		tooltip_panel.visible = false

func _show_tooltip(item, pos: Vector2):
	var soul = item.soul_print
	var quality_name = quality_names.get(soul.quality, "未知")
	var quality_color = quality_colors.get(soul.quality, Color.WHITE)
	
	# 使用富文本格式，属性左对齐
	var text = "[center][b][color=#%s]%s[/color][/b][/center]\n" % [quality_color.to_html(false), soul.name]
	text += "[center][color=#%s]%s[/color][/center]\n" % [quality_color.to_html(false), quality_name]
	text += "[center]━━━━━━━━━━[/center]\n"
	text += "[color=#FFD700]力量:[/color] [color=#FFFFFF]%d[/color]\n" % soul.power
	text += "[color=#FFD700]形状:[/color] [color=#AAAAAA]%s[/color]\n" % shape_names.get(soul.shape_type, "未知")
	if soul.description != "":
		text += "[center]━━━━━━━━━━[/center]\n"
		text += "[color=#CCCCCC][i]%s[/i][/color]" % soul.description
	
	tooltip_label.text = text
	tooltip_panel.size = Vector2.ZERO  # 重置大小让其自动调整
	
	# 确保提示框不超出屏幕
	var viewport_size = get_viewport_rect().size
	var tooltip_size = Vector2(250, 200)  # 预估大小
	var final_pos = pos + Vector2(15, 15)
	
	if final_pos.x + tooltip_size.x > viewport_size.x:
		final_pos.x = pos.x - tooltip_size.x - 15
	if final_pos.y + tooltip_size.y > viewport_size.y:
		final_pos.y = pos.y - tooltip_size.y - 15
	
	tooltip_panel.position = final_pos
	tooltip_panel.visible = true

func _show_soul_details(item_index: int):
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	var items = soul_system.get_user_inventory(current_username)
	if item_index < 0 or item_index >= items.size():
		return
	
	var item = items[item_index]
	var soul = item.soul_print
	var color = quality_colors.get(soul.quality, Color.WHITE)
	
	soul_name.text = soul.name
	soul_name.add_theme_color_override("font_color", color)
	
	quality_value.text = quality_names.get(soul.quality, "未知")
	quality_value.add_theme_color_override("font_color", color)
	
	shape_value.text = shape_names.get(soul.shape_type, "未知")
	power_value.text = str(soul.power)
	description_label.text = soul.description if soul.description != "" else "这个魂印蕴含着强大的力量..."

func _clear_soul_details():
	soul_name.text = "未选择魂印"
	soul_name.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	quality_value.text = ""
	shape_value.text = ""
	power_value.text = ""
	description_label.text = ""

func _on_close_button_pressed():
	inventory_closed.emit()

func _on_filter_all_pressed():
	_refresh_inventory()

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
		_refresh_inventory()

func _on_delete_button_pressed():
	if selected_item_index < 0:
		return
	
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	if soul_system.remove_soul_print(current_username, selected_item_index):
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
