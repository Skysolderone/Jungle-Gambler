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

# 管道连接系统
var pipe_connection_system = null
var pipe_connections: Array = []
var connection_animation_time: float = 0.0

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

var pipe_shape_names = {
	0: "直管-横", 1: "直管-竖",
	2: "弯管-左上", 3: "弯管-左下", 4: "弯管-右上", 5: "弯管-右下",
	6: "T型-上开口", 7: "T型-下开口", 8: "T型-左开口", 9: "T型-右开口",
	10: "十字型", 11: "起点", 12: "终点"
}

func _ready():
	# 应用像素风格
	_apply_pixel_style()

	# 初始化管道连接系统
	_initialize_pipe_connection_system()

	# 应用响应式布局
	_setup_responsive_layout()

	current_username = UserSession.get_username()

	# 确保加载用户库存数据
	var soul_system = _get_soul_system()
	if soul_system:
		soul_system.load_user_inventory(current_username)

	grid_container.draw.connect(_draw_grid)
	grid_container.gui_input.connect(_on_grid_gui_input)
	grid_container.mouse_entered.connect(_on_grid_mouse_entered)
	grid_container.mouse_exited.connect(_on_grid_mouse_exited)

	_check_starter_eligibility()
	_refresh_inventory()

func _apply_pixel_style():
	"""应用像素风格到所有UI元素"""
	if has_node("/root/PixelStyleManager"):
		var pixel_style = get_node("/root/PixelStyleManager")

		# 更新品质颜色为像素风格
		quality_colors = {
			0: pixel_style.PIXEL_PALETTE["QUALITY_COMMON"],
			1: pixel_style.PIXEL_PALETTE["QUALITY_UNCOMMON"],
			2: pixel_style.PIXEL_PALETTE["QUALITY_RARE"],
			3: pixel_style.PIXEL_PALETTE["QUALITY_EPIC"],
			4: pixel_style.PIXEL_PALETTE["QUALITY_LEGENDARY"],
			5: pixel_style.PIXEL_PALETTE["QUALITY_MYTHIC"]
		}

		# 应用像素风格到顶部栏标签
		var title_label = $MainPanel/TopBar/TitleLabel
		pixel_style.apply_title_style(title_label, "YELLOW")

		var count_label_node = $MainPanel/TopBar/CountLabel
		pixel_style.apply_subtitle_style(count_label_node, "YELLOW")

		# 应用像素风格到关闭按钮
		var close_button = $MainPanel/TopBar/CloseButton
		pixel_style.apply_secondary_button_style(close_button)

		# 应用像素风格到工具栏按钮
		var all_button = $MainPanel/ContentContainer/LeftPanel/ToolBar/AllButton
		pixel_style.apply_secondary_button_style(all_button)

		pixel_style.apply_secondary_button_style(rotate_button)
		pixel_style.apply_danger_button_style(delete_button)
		pixel_style.apply_success_button_style(starter_button)

		# 应用像素风格到详情面板标签
		var detail_title = $MainPanel/ContentContainer/RightPanel/ScrollContainer/DetailContainer/TitleMargin/TitleLabel
		pixel_style.apply_subtitle_style(detail_title, "YELLOW")

		pixel_style.apply_subtitle_style(soul_name, "WHITE")

		var quality_label = $MainPanel/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/QualityContainer/Label
		pixel_style.apply_body_style(quality_label, "YELLOW")

		var shape_label = $MainPanel/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/ShapeContainer/Label
		pixel_style.apply_body_style(shape_label, "YELLOW")

		var power_label = $MainPanel/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/PowerContainer/Label
		pixel_style.apply_body_style(power_label, "YELLOW")

		pixel_style.apply_body_style(quality_value, "WHITE")
		pixel_style.apply_body_style(shape_value, "WHITE")
		pixel_style.apply_body_style(power_value, "YELLOW")
		pixel_style.apply_small_text_style(description_label, "LIGHT_GREY")

		# 应用像素风格到品质图例
		var legend_title = $MainPanel/ContentContainer/RightPanel/ScrollContainer/DetailContainer/LegendMargin/LegendContainer/Title
		pixel_style.apply_body_style(legend_title, "YELLOW")

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
	# ContentContainer是HBoxContainer，方向已固定为horizontal，只调整面板比例
	var left_panel = $MainPanel/ContentContainer/LeftPanel
	var right_panel = $MainPanel/ContentContainer/RightPanel
	
	# 在移动端竖屏时调整比例
	if screen_type == 0:  # MOBILE_PORTRAIT
		left_panel.size_flags_stretch_ratio = 1.5
		right_panel.size_flags_stretch_ratio = 1.0
	else:
		# 其他情况保持常规比例
		left_panel.size_flags_stretch_ratio = 2.0
		right_panel.size_flags_stretch_ratio = 1.0

func _get_soul_system():
	if has_node("/root/SoulPrintSystem"):
		return get_node("/root/SoulPrintSystem")
	return null

func _initialize_pipe_connection_system():
	"""初始化管道连接系统"""
	# 加载管道连接系统脚本
	var script = load("res://systems/PipeConnectionSystem.gd")
	if script:
		pipe_connection_system = script.new()
		print("管道连接系统已初始化")
	else:
		push_error("无法加载管道连接系统脚本")

func _process(delta):
	"""每帧更新连接动画"""
	if pipe_connections.size() > 0:
		connection_animation_time += delta
		grid_container.queue_redraw()  # 触发重绘以显示动画

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

	# 更新管道连接
	_update_pipe_connections()

	grid_container.queue_redraw()

func _update_pipe_connections():
	"""更新管道连接检测"""
	if pipe_connection_system == null:
		return

	var soul_system = _get_soul_system()
	if soul_system == null:
		return

	var items = soul_system.get_user_inventory(current_username)

	# 检测所有连接
	pipe_connections = pipe_connection_system.detect_all_connections(items, soul_system)

	# 输出调试信息
	if pipe_connections.size() > 0:
		print("检测到 %d 个管道连接" % pipe_connections.size())
	else:
		print("未检测到管道连接")

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

	# 绘制管道连接（在魂印上层）
	_draw_pipe_connections()

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
	
	# 在中心位置绘制名称（自适应字体大小和换行）
	if cells.size() > 0:
		# 计算魂印占据的区域大小
		var min_x = 999
		var max_x = -999
		var min_y = 999
		var max_y = -999
		for cell in cells:
			min_x = min(min_x, cell[0])
			max_x = max(max_x, cell[0])
			min_y = min(min_y, cell[1])
			max_y = max(max_y, cell[1])

		var width_cells = max_x - min_x + 1
		var height_cells = max_y - min_y + 1
		var available_width = width_cells * CELL_SIZE - 8  # 减去边距
		var available_height = height_cells * CELL_SIZE - 8

		# 计算中心点
		var center_x = (min_x + max_x) / 2.0
		var center_y = (min_y + max_y) / 2.0

		var font = ThemeDB.fallback_font
		var text = item.soul_print.name

		# 根据可用空间自适应字体大小
		var font_size = 14
		if width_cells == 1 and height_cells == 1:
			font_size = 10  # 1×1 格子用小字体
		elif width_cells <= 2 and height_cells <= 2:
			font_size = 12  # 2×2 或更小用中等字体

		# 尝试分行显示长名称
		var lines = []
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)

		if text_size.x > available_width and text.length() > 3:
			# 文本太长，尝试分成两行
			var mid = text.length() / 2
			var line1 = text.substr(0, mid)
			var line2 = text.substr(mid)
			lines.append(line1)
			lines.append(line2)
		else:
			# 单行显示
			lines.append(text)

		# 绘制文本（居中）
		var line_height = font_size + 2
		var total_height = lines.size() * line_height
		var start_y = center_y * CELL_SIZE + CELL_SIZE / 2.0 - total_height / 2.0 + line_height / 2.0

		for i in range(lines.size()):
			var line = lines[i]
			var line_size = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
			var text_pos = Vector2(center_x * CELL_SIZE + CELL_SIZE / 2.0, start_y + i * line_height)
			text_pos.x -= line_size.x / 2.0

			# 文字阴影
			grid_container.draw_string(font, text_pos + Vector2(1, 1), line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLACK)
			# 文字本体
			grid_container.draw_string(font, text_pos, line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, base_color.lightened(0.5))

func _draw_dragging_item(item, mouse_pos: Vector2):
	var shape = [[0, 0]]  # 管道系统下每个魂印只占1个格子
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
				drag_offset = mouse_pos - Vector2(item.grid_position.x * CELL_SIZE, item.grid_position.y * CELL_SIZE)
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

	# 更新连接
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
	text += "[color=#FFD700]管道:[/color] [color=#AAAAAA]%s[/color]\n" % pipe_shape_names.get(soul.pipe_shape_type, "未知")

	# 显示魂印效果描述
	var effect_desc = soul.get_effect_description()
	if effect_desc != "":
		var effect_color = "#90EE90" if soul.soul_type == 1 else "#FFD700"  # 被动绿色，主动金色
		text += "[color=%s]%s[/color]\n" % [effect_color, effect_desc]

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
	
	shape_value.text = pipe_shape_names.get(soul.pipe_shape_type, "未知")
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
	var new_rotation = (item.rotation_state + 1) % 4

	if soul_system.move_soul_print(current_username, selected_item_index, item.grid_position.x, item.grid_position.y, new_rotation):
		# 旋转后重新检测连接
		_refresh_inventory()
		print("魂印已旋转到 %d° (%d/4)" % [new_rotation * 90, new_rotation])

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

		# 删除后重新检测连接
		_refresh_inventory()

func _on_starter_button_pressed():
	var soul_system = _get_soul_system()
	if soul_system == null:
		return

	soul_system.give_starter_souls(current_username)
	starter_button.visible = false
	_refresh_inventory()

func _draw_pipe_connections():
	"""绘制所有管道连接"""
	if pipe_connection_system == null or pipe_connections.size() == 0:
		return

	# 使用管道连接系统绘制所有连接
	pipe_connection_system.draw_all_connections(
		grid_container,
		pipe_connections,
		CELL_SIZE,
		connection_animation_time
	)
