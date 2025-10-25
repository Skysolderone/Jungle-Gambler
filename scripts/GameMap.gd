extends Control

@onready var map_name_label = $TopBar/MarginContainer/HBoxContainer/MapNameLabel
@onready var player_info_label = $TopBar/MarginContainer/HBoxContainer/PlayerInfoLabel
@onready var power_label = $TopBar/MarginContainer/HBoxContainer/PowerLabel
@onready var exploration_label = $TopBar/MarginContainer/HBoxContainer/ExplorationLabel
@onready var grid_container = $MainContent/GridPanel/GridContainer
@onready var grid_panel = $MainContent/GridPanel
@onready var brightness_overlay = $BrightnessOverlay
@onready var message_dialog = $MessageDialog
@onready var confirm_dialog = $ConfirmDialog

const GRID_SIZE = 9
var CELL_SIZE = 80  # 改为变量，支持响应式调整
const SETTINGS_PATH = "user://settings.json"
const COLLAPSE_INTERVAL := 30.0  # 坍塌间隔（秒），每30秒坍塌一圈

# 格子数据结构
class GridCell:
	var quality: int = 0  # 魂印品质 0-5
	var resource_count: int = 1  # 魂印数量 1-3
	var explored: bool = false  # 是否已探索
	var has_enemy: bool = false  # 是否有敌人（隐藏）
	var enemy_data: Dictionary = {}  # 敌人数据 {name: String, hp: int, power: int}
	var collapsed: bool = false  # 是否已坍塌

# 地图数据
var grid_data: Array[Array] = []  # GridCell[][]
var player_pos = Vector2i(4, 4)  # 玩家初始位置（中心）
var selected_map = null
var soul_loadout = []
var inventory_instance = null

# 玩家状态
var player_hp = 100
var max_hp = 100

# 撤离点
var evacuation_points: Array[Vector2i] = []  # 撤离点位置
var explored_count: int = 0  # 已探索格子数
var show_evacuation: bool = false  # 是否显示撤离点

# 收集记录
var collected_souls: Array[String] = []  # 本局收集到的魂印ID列表

# 坍塌状态
var collapse_ring_index: int = -1  # 已坍塌到第几圈（-1 表示未开始）

# 动态布局参数
var current_cell_size: float = 80.0
var current_offset_x: float = 0.0
var current_offset_y: float = 0.0

func _ready():
	# 应用响应式布局
	_setup_responsive_layout()
	
	_apply_brightness_from_settings()
	_load_game_data()
	
	# 检查是否从战斗返回
	var session = get_node("/root/UserSession")
	if session.has_meta("return_to_map") and session.get_meta("return_to_map"):
		# 恢复地图状态
		if session.has_meta("map_player_pos"):
			player_pos = session.get_meta("map_player_pos")
		if session.has_meta("map_player_hp"):
			player_hp = session.get_meta("map_player_hp")
		if session.has_meta("map_max_hp"):
			max_hp = session.get_meta("map_max_hp")
		if session.has_meta("map_explored_count"):
			explored_count = session.get_meta("map_explored_count")
		if session.has_meta("map_show_evacuation"):
			show_evacuation = session.get_meta("map_show_evacuation")
		if session.has_meta("map_collapse_ring_index"):
			collapse_ring_index = session.get_meta("map_collapse_ring_index")
		if session.has_meta("map_collected_souls"):
			collected_souls = session.get_meta("map_collected_souls")
		
		# 重新初始化地图（需要grid_data）
		_initialize_grid()
		_generate_map_content()
		
		# 处理战斗结果
		if session.has_meta("battle_result"):
			var result = session.get_meta("battle_result")
			_on_battle_finished(result)
		
		# 清除战斗数据
		session.remove_meta("return_to_map")
		session.remove_meta("battle_result")
		session.remove_meta("battle_enemy_data")
		session.remove_meta("battle_player_hp")
		session.remove_meta("battle_player_souls")
		session.remove_meta("battle_enemy_souls")
		session.remove_meta("map_player_pos")
		session.remove_meta("map_player_hp")
		session.remove_meta("map_max_hp")
		session.remove_meta("map_explored_count")
		session.remove_meta("map_show_evacuation")
		session.remove_meta("map_collapse_ring_index")
		session.remove_meta("map_collected_souls")
	else:
		_initialize_grid()
		_generate_map_content()
	
	_update_info()
	
	# 连接绘制和输入
	grid_container.draw.connect(_draw_grid)
	grid_container.gui_input.connect(_on_grid_gui_input)
	grid_container.queue_redraw()
	
	# 启动地形坍塌计时
	_start_collapse_loop()

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		
		# 连接屏幕类型变化信号
		responsive_manager.screen_type_changed.connect(_on_screen_type_changed)
		
		# 根据屏幕类型调整网格大小
		CELL_SIZE = responsive_manager.get_game_grid_cell_size()
		
		# 应用响应式布局
		responsive_manager.apply_responsive_layout(self)
		
		# 为移动端优化触摸
		responsive_manager.optimize_for_touch(self)
		
		# 动态设置Panel尺寸
		_update_panel_size()
		
		print("游戏地图已启用响应式布局，网格大小：", CELL_SIZE, "，屏幕类型：", responsive_manager.get_screen_type_name())
	
	# 为移动端添加手势支持
	_setup_mobile_gestures()

func _update_panel_size():
	# Panel现在自动填充MainContent，无需手动设置尺寸
	# 只需要确保网格绘制能适应Panel的实际大小
	print("Panel将自动适配MainContent大小，网格大小：", GRID_SIZE, "x", GRID_SIZE, "，格子尺寸：", CELL_SIZE)

func _setup_mobile_gestures():
	if has_node("/root/MobileInteractionHelper"):
		var mobile_helper = get_node("/root/MobileInteractionHelper")
		
		# 连接手势信号
		mobile_helper.gesture_detected.connect(_on_gesture_detected)
		
		# 为按钮添加触摸反馈
		mobile_helper.add_touch_feedback($TopBar/MarginContainer/HBoxContainer/InventoryButton)
		mobile_helper.add_touch_feedback($TopBar/MarginContainer/HBoxContainer/ExitButton)

func _on_screen_type_changed(_new_type):
	# 屏幕类型变化时重新应用布局
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		CELL_SIZE = responsive_manager.get_game_grid_cell_size()
		_update_panel_size()  # 重新调整Panel尺寸
		_update_grid_layout()  # 更新网格布局参数
		grid_container.queue_redraw()

func _start_collapse_loop():
	# 延迟首轮30秒开始，再每30秒坍塌一圈
	await get_tree().create_timer(COLLAPSE_INTERVAL).timeout
	while true:
		if _collapse_next_ring():
			grid_container.queue_redraw()
			# 如果玩家当前位置已坍塌，判定失败
			if grid_data[player_pos.y][player_pos.x].collapsed:
				_game_over()
				return
		else:
			return  # 所有圈已坍塌，结束
		await get_tree().create_timer(COLLAPSE_INTERVAL).timeout

func _apply_brightness_from_settings():
	var settings = {"brightness": 100.0}
	if FileAccess.file_exists(SETTINGS_PATH):
		var settings_file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if settings_file:
			var json_string = settings_file.get_as_text()
			settings_file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				settings = json.get_data()
	var brightness = settings.get("brightness", 100.0)
	var alpha = (100.0 - brightness) / 100.0 * 0.7
	brightness_overlay.color = Color(0, 0, 0, alpha)

func _load_game_data():
	if has_node("/root/UserSession"):
		var session = get_node("/root/UserSession")
		if session.has_meta("selected_map"):
			selected_map = session.get_meta("selected_map")
			map_name_label.text = selected_map.get("name", "未知地图")
		if session.has_meta("soul_loadout"):
			soul_loadout = session.get_meta("soul_loadout")

func _initialize_grid():
	grid_data = []
	for y in range(GRID_SIZE):
		var row: Array[GridCell] = []
		for x in range(GRID_SIZE):
			var cell = GridCell.new()
			# 随机分配魂印品质和数量
			cell.quality = randi() % 6  # 0-5
			cell.resource_count = randi() % 3 + 1  # 1-3
			cell.explored = false
			cell.has_enemy = false
			row.append(cell)
		grid_data.append(row)
	
	# 玩家起始位置自动探索
	grid_data[player_pos.y][player_pos.x].explored = true
	explored_count = 1

func _generate_map_content():
	# 随机给10-15个格子分配敌人（隐藏）
	var enemy_count = randi() % 6 + 10
	for i in range(enemy_count):
		var pos = _get_random_cell_pos()
		if pos != Vector2i(-1, -1):
			var cell = grid_data[pos.y][pos.x]
			if not cell.has_enemy:  # 避免重复
				cell.has_enemy = true
				cell.enemy_data = {
					"name": "敌人" + str(i + 1),
					"hp": randi() % 50 + 50,
					"power": randi() % 20 + 10
				}
	
	# 生成1-2个撤离点（隐藏，需要探索一定数量后显示）
	var evac_count = randi() % 2 + 1
	for i in range(evac_count):
		var pos = _get_random_cell_pos()
		if pos != Vector2i(-1, -1) and pos != player_pos:
			evacuation_points.append(pos)

func _get_random_cell_pos() -> Vector2i:
	var x = randi() % GRID_SIZE
	var y = randi() % GRID_SIZE
	return Vector2i(x, y)

func _collapse_next_ring() -> bool:
	# 计算下一圈索引，并坍塌其外环格子
	var max_ring = int((GRID_SIZE - 1) / 2.0)
	if collapse_ring_index >= max_ring:
		return false
	collapse_ring_index += 1
	var r = collapse_ring_index
	var start = r
	var end = GRID_SIZE - 1 - r
	# 上边和下边
	for x in range(start, end + 1):
		grid_data[start][x].collapsed = true
		grid_data[end][x].collapsed = true
	# 左边和右边
	for y in range(start, end + 1):
		grid_data[y][start].collapsed = true
		grid_data[y][end].collapsed = true
	# 信息提示
	_show_message("地形坍塌蔓延中！第 " + str(r + 1) + " 圈已坍塌")
	return true

func _update_grid_layout():
	# 获取Panel的实际大小
	var panel_size = grid_container.size
	
	# 计算网格能适应的最大尺寸（正方形）
	var available_size = min(panel_size.x, panel_size.y) - 40  # 减去40px边距
	current_cell_size = available_size / GRID_SIZE
	
	# 居中偏移
	current_offset_x = (panel_size.x - (GRID_SIZE * current_cell_size)) / 2
	current_offset_y = (panel_size.y - (GRID_SIZE * current_cell_size)) / 2
	
	print("网格布局更新: panel_size=", panel_size, " cell_size=", current_cell_size, " offset=(", current_offset_x, ",", current_offset_y, ")")

func _draw_grid():
	# 只在需要时更新布局，避免频繁调用
	if current_cell_size <= 0:
		_update_grid_layout()
	
	# 绘制网格背景
	var bg_rect = Rect2(current_offset_x, current_offset_y, GRID_SIZE * current_cell_size, GRID_SIZE * current_cell_size)
	grid_container.draw_rect(bg_rect, Color(0, 0, 0, 0.01), true)
	
	# 绘制网格线
	for x in range(GRID_SIZE + 1):
		var start = Vector2(current_offset_x + x * current_cell_size, current_offset_y)
		var end = Vector2(current_offset_x + x * current_cell_size, current_offset_y + GRID_SIZE * current_cell_size)
		grid_container.draw_line(start, end, Color(0.3, 0.3, 0.35, 0.5), 2.0)
	
	for y in range(GRID_SIZE + 1):
		var start = Vector2(current_offset_x, current_offset_y + y * current_cell_size)
		var end = Vector2(current_offset_x + GRID_SIZE * current_cell_size, current_offset_y + y * current_cell_size)
		grid_container.draw_line(start, end, Color(0.3, 0.3, 0.35, 0.5), 2.0)
	
	# 绘制格子内容
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			_draw_cell(x, y, current_cell_size, current_offset_x, current_offset_y)

func _draw_cell(x: int, y: int, cell_size: float, offset_x: float, offset_y: float):
	var cell = grid_data[y][x]
	var rect = Rect2(offset_x + x * cell_size + 5, offset_y + y * cell_size + 5, cell_size - 10, cell_size - 10)
	var center = Vector2(offset_x + x * cell_size + cell_size / 2.0, offset_y + y * cell_size + cell_size / 2.0)
	var mouse_pos = grid_container.get_local_mouse_position()
	var grid_x = int((mouse_pos.x - offset_x) / cell_size)
	var grid_y = int((mouse_pos.y - offset_y) / cell_size)
	
	# 先绘制格子底色（所有格子都显示颜色）
	var base_color = _get_cell_color(cell)
	grid_container.draw_rect(rect, base_color, true)
	
	# 未探索的格子 - 添加半透明遮罩
	if not cell.explored and player_pos != Vector2i(x, y):
		grid_container.draw_rect(rect, Color(0.05, 0.05, 0.1, 0.7), true)

	# 已坍塌的格子 - 深红遮罩与X标记
	if cell.collapsed:
		grid_container.draw_rect(rect, Color(0.4, 0.0, 0.0, 0.75), true)
		# 画一个X
		var p1 = Vector2(rect.position.x, rect.position.y)
		var p2 = Vector2(rect.position.x + rect.size.x, rect.position.y + rect.size.y)
		var p3 = Vector2(rect.position.x + rect.size.x, rect.position.y)
		var p4 = Vector2(rect.position.x, rect.position.y + rect.size.y)
		grid_container.draw_line(p1, p2, Color(0.9, 0.2, 0.2), 3.0)
		grid_container.draw_line(p3, p4, Color(0.9, 0.2, 0.2), 3.0)
	
	# 玩家位置
	if player_pos == Vector2i(x, y):
		# 玩家 - 蓝色圆形
		grid_container.draw_circle(center, 30, Color(0.2, 0.5, 1.0))
		grid_container.draw_circle(center, 30, Color(0.4, 0.7, 1.0), false, 3.0)
		_draw_text(center, "玩家", Color(1, 1, 1))
		return
	
	# 撤离点（只有达到探索度才显示）
	if show_evacuation and evacuation_points.has(Vector2i(x, y)) and cell.explored:
		# 绘制绿色菱形
		var points = PackedVector2Array([
			Vector2(center.x, center.y - 25),  # 上
			Vector2(center.x + 25, center.y),  # 右
			Vector2(center.x, center.y + 25),  # 下
			Vector2(center.x - 25, center.y)   # 左
		])
		grid_container.draw_colored_polygon(points, Color(0.2, 0.8, 0.2, 0.6))
		grid_container.draw_polyline(points + PackedVector2Array([points[0]]), Color(0.3, 1.0, 0.3), 3.0)
		_draw_text(center, "撤离", Color(0.3, 1.0, 0.3))
		return
	
	# 悬停高亮（只有相邻格子才能移动）
	if grid_x == x and grid_y == y and _is_adjacent(player_pos, Vector2i(x, y)):
		grid_container.draw_rect(rect, Color(1, 1, 1, 0.3), false, 2.0)

func _get_cell_color(cell: GridCell) -> Color:
	# 品质对应的基础颜色
	var quality_colors = [
		Color(0.5, 0.5, 0.5),    # 0: 普通 - 灰色
		Color(0.2, 0.7, 0.2),    # 1: 非凡 - 绿色
		Color(0.2, 0.5, 0.9),    # 2: 稀有 - 蓝色
		Color(0.6, 0.2, 0.8),    # 3: 史诗 - 紫色
		Color(0.9, 0.6, 0.2),    # 4: 传说 - 橙色
		Color(0.9, 0.3, 0.3)     # 5: 神话 - 红色
	]
	
	var base_color = quality_colors[cell.quality]
	
	# 根据资源数量调整亮度（1-3对应0.3-0.7的alpha）
	var alpha = 0.2 + (cell.resource_count / 3.0) * 0.5
	
	return Color(base_color.r, base_color.g, base_color.b, alpha)

func _draw_text(center: Vector2, text: String, color: Color):
	var font = ThemeDB.fallback_font
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var text_pos = center - Vector2(text_size.x / 2.0, -5)
	# 阴影
	grid_container.draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
	# 文字
	grid_container.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _on_grid_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# 计算相对于网格的位置
		var relative_x = event.position.x - current_offset_x
		var relative_y = event.position.y - current_offset_y
		
		print("=== 点击调试信息 ===")
		print("原始点击位置: ", event.position)
		print("网格偏移: (", current_offset_x, ", ", current_offset_y, ")")
		print("相对位置: (", relative_x, ", ", relative_y, ")")
		print("格子大小: ", current_cell_size)
		
		# 检查是否在网格范围内
		if relative_x < 0 or relative_y < 0:
			print("点击在网格外部（负坐标）")
			return
		
		var total_grid_width = GRID_SIZE * current_cell_size
		var total_grid_height = GRID_SIZE * current_cell_size
		
		if relative_x >= total_grid_width or relative_y >= total_grid_height:
			print("点击在网格外部（超出范围）")
			return
		
		# 精确计算网格坐标 - 使用floor确保在正确的格子内
		var grid_x = int(floor(relative_x / current_cell_size))
		var grid_y = int(floor(relative_y / current_cell_size))
		
		# 再次边界检查
		grid_x = clamp(grid_x, 0, GRID_SIZE - 1)
		grid_y = clamp(grid_y, 0, GRID_SIZE - 1)
		
		print("计算的网格坐标: (", grid_x, ", ", grid_y, ")")
		print("玩家当前位置: ", player_pos)
		
		# 验证计算的坐标
		var cell_center_x = current_offset_x + (grid_x + 0.5) * current_cell_size
		var cell_center_y = current_offset_y + (grid_y + 0.5) * current_cell_size
		print("对应格子中心: (", cell_center_x, ", ", cell_center_y, ")")
		
		_on_cell_clicked(grid_x, grid_y)
	
	elif event is InputEventMouseMotion:
		grid_container.queue_redraw()

func _on_gesture_detected(gesture, position: Vector2):
	# 处理移动端手势
	var grid_x = int((position.x - current_offset_x) / current_cell_size)
	var grid_y = int((position.y - current_offset_y) / current_cell_size)
	
	# 确保手势在网格范围内
	if grid_x < 0 or grid_x >= GRID_SIZE or grid_y < 0 or grid_y >= GRID_SIZE:
		return
	
	match gesture:
		0:  # TAP - 正常点击移动
			_on_cell_clicked(grid_x, grid_y)
		2:  # LONG_PRESS - 显示格子信息
			_show_cell_info(grid_x, grid_y)
		3, 4, 5, 6:  # 滑动手势 - 快速移动
			_handle_swipe_movement(gesture)

func _handle_swipe_movement(gesture):
	# 根据滑动方向移动玩家
	var move_direction = Vector2i.ZERO
	
	match gesture:
		3:  # SWIPE_UP
			move_direction = Vector2i(0, -1)
		4:  # SWIPE_DOWN  
			move_direction = Vector2i(0, 1)
		5:  # SWIPE_LEFT
			move_direction = Vector2i(-1, 0)
		6:  # SWIPE_RIGHT
			move_direction = Vector2i(1, 0)
	
	var target_pos = player_pos + move_direction
	
	# 检查目标位置有效性
	if target_pos.x >= 0 and target_pos.x < GRID_SIZE and target_pos.y >= 0 and target_pos.y < GRID_SIZE:
		_on_cell_clicked(target_pos.x, target_pos.y)

func _show_cell_info(x: int, y: int):
	# 显示格子详细信息（长按功能）
	var cell = grid_data[y][x]
	var quality_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
	
	var info_text = "位置: (" + str(x) + "," + str(y) + ")\n"
	info_text += "品质: " + quality_names[cell.quality] + "\n"
	info_text += "资源数量: " + str(cell.resource_count) + "\n"
	info_text += "已探索: " + ("是" if cell.explored else "否") + "\n"
	info_text += "已坍塌: " + ("是" if cell.collapsed else "否")
	
	if cell.has_enemy and cell.explored:
		info_text += "\n发现敌人: " + cell.enemy_data.get("name", "未知")
	
	_show_message(info_text)

func _on_cell_clicked(x: int, y: int):
	var clicked_pos = Vector2i(x, y)
	
	print("=== 点击格子调试信息 ===")
	print("点击坐标: (", x, ", ", y, ")")
	print("玩家当前位置: ", player_pos)
	print("点击位置: ", clicked_pos)
	
	# 点击自己 - 如果在撤离点上就撤离
	if clicked_pos == player_pos:
		print("点击自己的位置")
		if show_evacuation and evacuation_points.has(player_pos):
			print("在撤离点，执行撤离")
			_evacuate()
		return
	
	# 只能移动到相邻格子
	if not _is_adjacent(player_pos, clicked_pos):
		print("不是相邻格子，无法移动")
		return
	# 禁止移动到已坍塌格子
	if grid_data[clicked_pos.y][clicked_pos.x].collapsed:
		print("目标格子已坍塌")
		_show_message("该区域已坍塌，无法进入！")
		return
	
	print("开始移动到目标格子: (", clicked_pos.x, ", ", clicked_pos.y, ")")
	# 移动到目标格子
	_move_to_cell(clicked_pos)

func _is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	return (dx <= 1 and dy <= 1) and not (dx == 0 and dy == 0)

func _move_to_cell(target_pos: Vector2i):
	var cell = grid_data[target_pos.y][target_pos.x]
	
	print("=== 移动到格子调试信息 ===")
	print("目标位置: (", target_pos.x, ", ", target_pos.y, ")")
	print("格子是否已探索: ", cell.explored)
	print("格子是否有敌人: ", cell.has_enemy)
	print("格子资源数量: ", cell.resource_count)
	
	# 如果是未探索的格子，先探索
	if not cell.explored:
		cell.explored = true
		explored_count += 1
		print("探索新格子，总探索数: ", explored_count)
		
		# 检查是否达到探索度阈值，显示撤离点（探索40%以上）
		var explore_threshold = int(GRID_SIZE * GRID_SIZE * 0.4)
		if explored_count >= explore_threshold and not show_evacuation:
			show_evacuation = true
			_show_message("探索进度已达 " + str(int(explored_count * 100.0 / (GRID_SIZE * GRID_SIZE))) + "%\n撤离点已显示在地图上！")
	
	# 移动玩家
	var old_pos = player_pos
	player_pos = target_pos
	print("玩家位置更新: ", old_pos, " -> ", player_pos)
	
	_update_info()
	grid_container.queue_redraw()
	
	# 检查是否触发战斗
	if cell.has_enemy:
		print("触发战斗！")
		_start_battle(cell.enemy_data)
		return
	
	print("没有敌人，收集资源")
	# 没有敌人，可以收集资源
	_collect_resources_from_cell(cell)

func _start_battle(enemy_data: Dictionary):
	# 保存当前游戏状态到UserSession
	var session = get_node("/root/UserSession")
	
	print("=== 开始战斗调试信息 ===")
	print("带入地图的魂印配置数量: ", soul_loadout.size())
	for i in range(soul_loadout.size()):
		var item = soul_loadout[i]
		print("  魂印", i+1, ": ", item.soul_print.name, " 力量:", item.soul_print.power, " 次数:", item.uses_remaining, "/", item.max_uses)
	
	# 生成敌人魂印（根据敌人力量随机生成1-3个）
	var enemy_souls = _generate_enemy_souls(enemy_data.get("power", 30))
	
	# 保存地图状态
	session.set_meta("map_player_pos", player_pos)
	session.set_meta("map_player_hp", player_hp)
	session.set_meta("map_max_hp", max_hp)
	session.set_meta("map_explored_count", explored_count)
	session.set_meta("map_show_evacuation", show_evacuation)
	session.set_meta("map_collapse_ring_index", collapse_ring_index)
	session.set_meta("map_collected_souls", collected_souls)
	
	# 保存战斗数据 - 使用带入地图的魂印配置而不是全部背包
	session.set_meta("battle_enemy_data", enemy_data)
	session.set_meta("battle_player_hp", player_hp)
	session.set_meta("battle_player_souls", soul_loadout)  # 使用带入地图的魂印配置
	session.set_meta("battle_enemy_souls", enemy_souls)
	session.set_meta("return_to_map", true)
	
	print("保存到UserSession的战斗魂印数量: ", soul_loadout.size())
	
	# 跳转到战前准备阶段
	get_tree().change_scene_to_file("res://scenes/PreparationPhase.tscn")

func _generate_enemy_souls(enemy_power: int) -> Array:
	# 根据敌人力量生成魂印
	var soul_system = _get_soul_system()
	if not soul_system:
		return []
	
	var souls = []
	var soul_count = 1 + randi() % 3  # 1-3个魂印
	
	# 根据敌人力量决定魂印品质
	var quality = 0
	if enemy_power >= 40:
		quality = 3 + randi() % 2  # 史诗或传说
	elif enemy_power >= 30:
		quality = 2 + randi() % 2  # 稀有或史诗
	elif enemy_power >= 20:
		quality = 1 + randi() % 2  # 非凡或稀有
	else:
		quality = randi() % 2  # 普通或非凡
	
	# 生成魂印
	var soul_pools = [
		["soul_basic_1", "soul_basic_2"],
		["soul_forest", "soul_wind"],
		["soul_thunder", "soul_flame"],
		["soul_dragon", "soul_shadow"],
		["soul_phoenix", "soul_celestial", "soul_titan"],
		["soul_chaos", "soul_eternity", "soul_god"]
	]
	
	for i in range(soul_count):
		if quality < soul_pools.size():
			var pool = soul_pools[quality]
			var soul_id = pool[randi() % pool.size()]
			var soul = soul_system.get_soul_by_id(soul_id)
			if soul:
				souls.append(soul)
	
	return souls

func _on_battle_finished(result: Dictionary):
	# result包含: won (bool), player_hp_change (int), loot_souls (Array)
	
	# 更新玩家血量
	player_hp += result.get("player_hp_change", 0)
	if player_hp <= 0:
		player_hp = 0
		_game_over()
		return
	if player_hp > max_hp:
		player_hp = max_hp
	
	# 如果战斗胜利
	if result.get("won", false):
		var cell = grid_data[player_pos.y][player_pos.x]
		cell.has_enemy = false  # 敌人已被击败
		
		# 战利品已经在战斗场景中添加到背包
		var loot_souls = result.get("loot_souls", [])
		for soul in loot_souls:
			collected_souls.append(soul.id)
		
		# 收集格子资源
		_collect_resources_from_cell(cell)
	
	_update_info()
	grid_container.queue_redraw()

func _collect_resources_from_cell(cell: GridCell):
	# 根据格子的品质和数量，收集魂印
	var soul_system = _get_soul_system()
	if not soul_system:
		return
	
	var username = UserSession.get_username()
	var souls_collected = []
	
	for i in range(cell.resource_count):
		# 根据品质生成魂印ID
		var soul_id = _get_soul_id_by_quality(cell.quality)
		var success = soul_system.add_soul_print(username, soul_id)
		
		if success:
			collected_souls.append(soul_id)
			souls_collected.append(soul_id)
	
	# 显示收集信息
	if souls_collected.size() > 0:
		var quality_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
		var quality_name = quality_names[cell.quality]
		
		# 获取具体的魂印信息
		var soul_names = []
		for soul_id in souls_collected:
			var soul_data = soul_system.get_soul_by_id(soul_id)
			if soul_data:
				soul_names.append(soul_data.name + " (力量:" + str(soul_data.power) + ")")
		
		var message = "收集资源成功！\n获得 " + str(souls_collected.size()) + " 个" + quality_name + "品质魂印:\n"
		message += "\n".join(soul_names)
		_show_message(message)
	
	# 清空格子资源
	cell.resource_count = 0

func _get_soul_id_by_quality(quality: int) -> String:
	# 根据品质返回对应的魂印ID，随机选择一个
	var soul_pools = [
		["soul_basic_1", "soul_basic_2"],  # 0: 普通
		["soul_forest", "soul_wind"],  # 1: 非凡
		["soul_thunder", "soul_flame"],  # 2: 稀有
		["soul_dragon", "soul_shadow"],  # 3: 史诗
		["soul_phoenix", "soul_celestial", "soul_titan"],  # 4: 传说
		["soul_chaos", "soul_eternity", "soul_god"]  # 5: 神话
	]
	
	if quality >= 0 and quality < soul_pools.size():
		var pool = soul_pools[quality]
		return pool[randi() % pool.size()]
	
	return "soul_basic_1"

func _game_over():
	# 玩家血量归零，游戏结束，失去所有收集的魂印
	var message = "你的生命值归零！\n本次收集的 " + str(collected_souls.size()) + " 个魂印已失去。"
	
	# 移除本次收集的魂印
	if collected_souls.size() > 0:
		var soul_system = _get_soul_system()
		if soul_system:
			var username = UserSession.get_username()
			for soul_id in collected_souls:
				var items = soul_system.get_user_inventory(username)
				for i in range(items.size() - 1, -1, -1):
					if items[i].soul_print.id == soul_id:
						soul_system.remove_soul_print(username, i)
						break
	
	_show_message(message)
	
	# 延迟返回大厅
	await get_tree().create_timer(2.0).timeout
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _calculate_total_power() -> int:
	var total = 0
	for item in soul_loadout:
		total += item.soul_print.power
	return total

func _get_soul_system():
	if has_node("/root/SoulPrintSystem"):
		return get_node("/root/SoulPrintSystem")
	return null

func _update_info():
	player_info_label.text = "位置: (" + str(player_pos.x) + "," + str(player_pos.y) + ") | HP: " + str(player_hp) + "/" + str(max_hp)
	power_label.text = "总力量: " + str(_calculate_total_power())
	
	# 更新探索进度
	var total_cells = GRID_SIZE * GRID_SIZE
	var exploration_percent = int(explored_count * 100.0 / total_cells)
	exploration_label.text = "探索: " + str(exploration_percent) + "% (" + str(explored_count) + "/" + str(total_cells) + ")"

func _evacuate():
	# 成功撤离，保留所有收集的魂印
	var message = "成功撤离！\n"
	if collected_souls.size() > 0:
		message += "本次收集了 " + str(collected_souls.size()) + " 个魂印"
	else:
		message += "本次没有收集到魂印"
	
	_show_message(message)
	
	# 延迟返回大厅
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _show_message(text: String):
	message_dialog.dialog_text = text
	message_dialog.popup_centered()

func _on_inventory_button_pressed():
	if inventory_instance != null:
		return
	
	# 加载背包场景
	var inventory_scene = load("res://scenes/SoulInventoryV2.tscn")
	inventory_instance = inventory_scene.instantiate()
	
	# 连接关闭信号
	inventory_instance.inventory_closed.connect(_on_inventory_closed)
	
	# 添加为覆盖层
	add_child(inventory_instance)

func _on_inventory_closed():
	if inventory_instance != null:
		inventory_instance.queue_free()
		inventory_instance = null

func _on_exit_button_pressed():
	# 警告：直接退出会失去收集的魂印
	var message = "警告：直接退出地图将失去本次收集的所有魂印！\n"
	message += "（请通过绿色撤离点安全撤离）\n\n"
	message += "本次已收集: " + str(collected_souls.size()) + " 个魂印\n"
	message += "确定要强制退出吗？"
	
	confirm_dialog.dialog_text = message
	confirm_dialog.popup_centered()

func _on_exit_confirmed():
	# 强制退出，移除本次收集的魂印
	if collected_souls.size() > 0:
		var soul_system = _get_soul_system()
		if soul_system:
			var username = UserSession.get_username()
			for soul_id in collected_souls:
				# 从背包中移除
				var items = soul_system.get_user_inventory(username)
				for i in range(items.size() - 1, -1, -1):
					if items[i].soul_print.id == soul_id:
						soul_system.remove_soul_print(username, i)
						break
	
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
