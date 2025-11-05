extends Control

@onready var map_name_label = $TopBar/MarginContainer/HBoxContainer/MapNameLabel
@onready var player_info_label = $TopBar/MarginContainer/HBoxContainer/PlayerInfoLabel
@onready var power_label = $TopBar/MarginContainer/HBoxContainer/PowerLabel
@onready var exploration_label = $TopBar/MarginContainer/HBoxContainer/ExplorationLabel
@onready var evacuation_label = $TopBar/MarginContainer/HBoxContainer/EvacuationLabel
@onready var collapse_timer_label = $TopBar/MarginContainer/HBoxContainer/CollapseTimerLabel
@onready var grid_container = $MainContent/GridPanel/GridContainer
@onready var grid_panel = $MainContent/GridPanel
@onready var brightness_overlay = $BrightnessOverlay
@onready var message_dialog = $MessageDialog
@onready var confirm_dialog = $ConfirmDialog
@onready var evacuation_confirm_dialog = $EvacuationConfirmDialog

const GRID_SIZE = 9
var CELL_SIZE = 80  # 改为变量，支持响应式调整
const SETTINGS_PATH = "user://settings.json"
const COLLAPSE_INTERVAL := 30.0  # 坍塌间隔（秒），每30秒坍塌一圈

# 调试模式配置
const DEBUG_MODE = false  # 设置为 true 启用调试模式
const DEBUG_NO_ENEMIES = false  # 调试模式：不生成敌人
const DEBUG_NO_COLLAPSE = false  # 调试模式：禁用地形坍塌

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
var collapse_time_remaining: float = COLLAPSE_INTERVAL  # 距离下次坍塌剩余时间

# 输入锁定（防止对话框关闭时误触发点击）
var input_locked: bool = false

# 点击防抖（防止快速连续点击）
var last_click_time: float = 0.0
const CLICK_DEBOUNCE_TIME: float = 0.3  # 300ms 防抖间隔

# 动态布局参数
var current_cell_size: float = 80.0
var current_offset_x: float = 0.0
var current_offset_y: float = 0.0

func _ready():
	# 应用响应式布局
	await _setup_responsive_layout()

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
		if session.has_meta("map_collapse_time_remaining"):
			collapse_time_remaining = session.get_meta("map_collapse_time_remaining")
		
		# 恢复网格数据（如果有保存的话）
		if session.has_meta("map_grid_data"):
			_restore_grid_data(session.get_meta("map_grid_data"))
		else:
			# 没有保存的网格数据，重新初始化
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
		session.remove_meta("map_collapse_time_remaining")
	else:
		_initialize_grid()
		_generate_map_content()
	
	_update_info()
	_update_evacuation_status()

	# 连接绘制和输入
	grid_container.draw.connect(_draw_grid)
	grid_container.gui_input.connect(_on_grid_gui_input)
	grid_container.queue_redraw()

	# 启动地形坍塌计时
	_start_collapse_loop()

	# 启动撤离点动画循环
	_start_evacuation_animation()

	# 启动倒计时更新循环
	_start_collapse_timer_update()

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

		# 动态设置Panel尺寸 - 等待完成以确保布局参数正确初始化
		await _update_panel_size()

		print("游戏地图已启用响应式布局，网格大小：", CELL_SIZE, "，屏幕类型：", responsive_manager.get_screen_type_name())

	# 为移动端添加手势支持
	_setup_mobile_gestures()

func _update_panel_size():
	# 等待下一帧确保Panel大小已更新
	await get_tree().process_frame

	# 获取GridPanel的实际大小
	var panel_size = grid_panel.size

	# 立即计算网格布局参数
	if panel_size.x > 0 and panel_size.y > 0:
		var available_size = min(panel_size.x, panel_size.y) - 40  # 减去40px边距
		current_cell_size = available_size / GRID_SIZE

		# 居中偏移
		current_offset_x = (panel_size.x - (GRID_SIZE * current_cell_size)) / 2
		current_offset_y = (panel_size.y - (GRID_SIZE * current_cell_size)) / 2

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
	# 调试模式：禁用地形坍塌
	if DEBUG_MODE and DEBUG_NO_COLLAPSE:
		print("调试模式：地形坍塌已禁用")
		collapse_timer_label.text = "坍塌: 已禁用"
		return

	# 延迟首轮30秒开始，再每30秒坍塌一圈
	await get_tree().create_timer(COLLAPSE_INTERVAL).timeout
	while true:
		if _collapse_next_ring():
			# 重置倒计时
			collapse_time_remaining = COLLAPSE_INTERVAL
			grid_container.queue_redraw()
			# 如果玩家当前位置已坍塌，判定失败
			if grid_data[player_pos.y][player_pos.x].collapsed:
				await _game_over()
				return
		else:
			return  # 所有圈已坍塌，结束
		await get_tree().create_timer(COLLAPSE_INTERVAL).timeout

func _start_evacuation_animation():
	# 撤离点动画循环，每帧重绘以实现动画效果
	while true:
		if show_evacuation:
			grid_container.queue_redraw()
		await get_tree().create_timer(0.05).timeout  # 20fps动画

func _start_collapse_timer_update():
	# 倒计时更新循环
	if DEBUG_MODE and DEBUG_NO_COLLAPSE:
		return

	while true:
		# 更新剩余时间
		collapse_time_remaining -= 0.1
		if collapse_time_remaining < 0:
			collapse_time_remaining = 0

		# 更新UI显示
		_update_collapse_timer_display()

		await get_tree().create_timer(0.1).timeout  # 每0.1秒更新一次

func _update_collapse_timer_display():
	var seconds = int(ceil(collapse_time_remaining))

	# 剩余10秒时的警告效果
	if seconds <= 10 and seconds > 0:
		# 红色闪烁效果
		var time = Time.get_ticks_msec() / 1000.0
		var pulse = (sin(time * 5.0) + 1.0) / 2.0  # 快速脉冲
		var warning_color = Color(1.0, pulse * 0.3, pulse * 0.3)  # 红色到暗红色

		collapse_timer_label.add_theme_color_override("font_color", warning_color)
		collapse_timer_label.add_theme_font_size_override("font_size", 18)
		collapse_timer_label.text = "⚠ 坍塌倒计时: " + str(seconds) + "秒 ⚠"

		# 添加红色背景
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.5, 0.0, 0.0, 0.6 + pulse * 0.2)
		style_box.set_corner_radius_all(5)
		collapse_timer_label.add_theme_stylebox_override("normal", style_box)
	elif seconds == 0:
		# 坍塌中
		collapse_timer_label.text = "地形坍塌中..."
		collapse_timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		collapse_timer_label.add_theme_font_size_override("font_size", 16)
	else:
		# 正常倒计时
		collapse_timer_label.text = "下次坍塌: " + str(seconds) + "秒"
		collapse_timer_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		collapse_timer_label.add_theme_font_size_override("font_size", 14)
		collapse_timer_label.remove_theme_stylebox_override("normal")

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
	# 调试模式：跳过敌人生成
	if not (DEBUG_MODE and DEBUG_NO_ENEMIES):
		# 根据地图难度调整敌人数量
		var enemy_count = 10  # 默认值
		var difficulty = selected_map.get("difficulty", "普通") if selected_map else "普通"

		match difficulty:
			"简单":
				enemy_count = randi() % 3 + 2  # 2-4 个敌人
			"普通":
				enemy_count = randi() % 6 + 10  # 10-15 个敌人
			"困难":
				enemy_count = randi() % 6 + 15  # 15-20 个敌人
			"专家":
				enemy_count = randi() % 6 + 20  # 20-25 个敌人

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
		print("生成了 ", enemy_count, " 个敌人")
	else:
		print("调试模式：已禁用敌人生成")

	# 生成2-3个撤离点（隐藏，需要探索一定数量后显示）
	var evac_count = randi() % 2 + 2  # 2-3 个撤离点，确保有足够的撤离机会
	var attempts = 0
	while evacuation_points.size() < evac_count and attempts < 50:
		var pos = _get_random_cell_pos()
		if pos != player_pos and not evacuation_points.has(pos):
			evacuation_points.append(pos)
		attempts += 1
	print("生成了 ", evacuation_points.size(), " 个撤离点")

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
	# 使用GridPanel的实际大小而不是GridContainer
	var panel_size = grid_panel.size

	# 计算网格能适应的最大尺寸（正方形）
	var available_size = min(panel_size.x, panel_size.y) - 40  # 减去40px边距
	current_cell_size = available_size / GRID_SIZE

	# 居中偏移
	current_offset_x = (panel_size.x - (GRID_SIZE * current_cell_size)) / 2
	current_offset_y = (panel_size.y - (GRID_SIZE * current_cell_size)) / 2

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
	# 使用与点击检测相同的计算方式，确保一致性
	var relative_x = mouse_pos.x - offset_x
	var relative_y = mouse_pos.y - offset_y
	var grid_x = int(floor(relative_x / cell_size))
	var grid_y = int(floor(relative_y / cell_size))

	# 先绘制格子底色（所有格子都显示颜色）
	var base_color = _get_cell_color(cell)
	grid_container.draw_rect(rect, base_color, true)

	# 添加渐变光效 - 从中心向外发散
	if not cell.collapsed:
		var gradient_size = rect.size * 0.8
		var gradient_rect = Rect2(rect.position + (rect.size - gradient_size) / 2, gradient_size)
		var glow_color = Color(base_color.r, base_color.g, base_color.b, base_color.a * 0.4)
		grid_container.draw_rect(gradient_rect, glow_color, true)

	# 绘制品质图标/符号（已探索或玩家位置）
	if cell.explored or player_pos == Vector2i(x, y):
		_draw_quality_indicator(center, cell.quality, cell.resource_count, cell_size * 0.3)

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
		_draw_player(center)
		return
	
	# 撤离点（只有达到探索度才显示）
	if show_evacuation and evacuation_points.has(Vector2i(x, y)) and cell.explored:
		_draw_evacuation_point(center, cell_size)
		return
	
	# 悬停高亮（只有相邻格子才能移动）
	if grid_x == x and grid_y == y and _is_adjacent(player_pos, Vector2i(x, y)):
		grid_container.draw_rect(rect, Color(1, 1, 1, 0.3), false, 2.0)

func _get_cell_color(cell: GridCell) -> Color:
	# 品质对应的基础颜色 - 更鲜艳的配色方案
	var quality_colors = [
		Color(0.65, 0.65, 0.7),     # 0: 普通 - 明亮灰色
		Color(0.3, 0.9, 0.4),       # 1: 非凡 - 鲜绿色
		Color(0.3, 0.7, 1.0),       # 2: 稀有 - 亮蓝色
		Color(0.75, 0.35, 0.95),    # 3: 史诗 - 鲜紫色
		Color(1.0, 0.7, 0.3),       # 4: 传说 - 金橙色
		Color(1.0, 0.25, 0.4)       # 5: 神话 - 炫红色
	]

	var base_color = quality_colors[cell.quality]

	# 根据资源数量调整亮度（1-3对应更高的可见度）
	var alpha = 0.5 + (cell.resource_count / 3.0) * 0.45

	return Color(base_color.r, base_color.g, base_color.b, alpha)

func _draw_quality_indicator(center: Vector2, quality: int, resource_count: int, size: float):
	# 绘制品质指示器（符号+数量）
	var quality_colors = [
		Color(0.8, 0.8, 0.85),      # 0: 普通 - 亮灰
		Color(0.4, 1.0, 0.5),       # 1: 非凡 - 亮绿
		Color(0.4, 0.8, 1.0),       # 2: 稀有 - 亮蓝
		Color(0.85, 0.5, 1.0),      # 3: 史诗 - 亮紫
		Color(1.0, 0.8, 0.4),       # 4: 传说 - 亮金
		Color(1.0, 0.4, 0.5)        # 5: 神话 - 亮红
	]

	var color = quality_colors[quality]

	# 根据品质绘制不同的形状
	match quality:
		0:  # 普通 - 小圆点
			grid_container.draw_circle(center, size * 0.3, color)
		1:  # 非凡 - 菱形
			var points = PackedVector2Array([
				Vector2(center.x, center.y - size * 0.5),
				Vector2(center.x + size * 0.5, center.y),
				Vector2(center.x, center.y + size * 0.5),
				Vector2(center.x - size * 0.5, center.y)
			])
			grid_container.draw_colored_polygon(points, color)
		2:  # 稀有 - 六边形
			_draw_hexagon(center, size * 0.5, color)
		3:  # 史诗 - 五角星
			_draw_star(center, size * 0.6, color, 5)
		4:  # 传说 - 八角星
			_draw_star(center, size * 0.65, color, 8)
		5:  # 神话 - 发光的十字星
			_draw_cross_star(center, size * 0.7, color)

	# 绘制资源数量指示器（小圆点）
	if resource_count > 0:
		var dot_size = size * 0.12
		var dot_spacing = size * 0.25
		var start_x = center.x - (resource_count - 1) * dot_spacing / 2
		var dot_y = center.y + size * 0.8

		for i in range(resource_count):
			var dot_pos = Vector2(start_x + i * dot_spacing, dot_y)
			# 外圈（阴影）
			grid_container.draw_circle(dot_pos, dot_size * 1.2, Color(0, 0, 0, 0.6))
			# 内圈（亮色）
			grid_container.draw_circle(dot_pos, dot_size, Color(1, 1, 1, 0.9))

func _draw_hexagon(center: Vector2, radius: float, color: Color):
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60 * i - 30)
		points.append(Vector2(
			center.x + cos(angle) * radius,
			center.y + sin(angle) * radius
		))
	grid_container.draw_colored_polygon(points, color)
	# 添加外边框增强效果
	grid_container.draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 0.5), 1.5)

func _draw_star(center: Vector2, radius: float, color: Color, points_count: int):
	var points = PackedVector2Array()
	var inner_radius = radius * 0.4

	for i in range(points_count * 2):
		var angle = deg_to_rad(360.0 / (points_count * 2) * i - 90)
		var r = radius if i % 2 == 0 else inner_radius
		points.append(Vector2(
			center.x + cos(angle) * r,
			center.y + sin(angle) * r
		))

	grid_container.draw_colored_polygon(points, color)
	# 添加光晕效果
	for i in range(points_count * 2):
		if i % 2 == 0:  # 只在尖角添加光晕
			var angle = deg_to_rad(360.0 / (points_count * 2) * i - 90)
			var glow_pos = Vector2(
				center.x + cos(angle) * radius,
				center.y + sin(angle) * radius
			)
			grid_container.draw_circle(glow_pos, radius * 0.15, Color(1, 1, 1, 0.7))

func _draw_cross_star(center: Vector2, radius: float, color: Color):
	# 绘制十字星（神话品质专属）
	var beam_width = radius * 0.25

	# 绘制四条光束
	for i in range(4):
		var angle = deg_to_rad(90 * i)
		var direction = Vector2(cos(angle), sin(angle))
		var perpendicular = Vector2(-direction.y, direction.x)

		var points = PackedVector2Array([
			center + perpendicular * beam_width,
			center + direction * radius + perpendicular * beam_width * 0.3,
			center + direction * radius,
			center + direction * radius - perpendicular * beam_width * 0.3,
			center - perpendicular * beam_width
		])

		grid_container.draw_colored_polygon(points, color)

	# 中心圆形
	grid_container.draw_circle(center, radius * 0.35, color)
	grid_container.draw_circle(center, radius * 0.25, Color(1, 1, 1, 0.9))

func _draw_player(center: Vector2):
	# 玩家标记 - 蓝色发光圆形
	var time = Time.get_ticks_msec() / 1000.0
	var pulse = (sin(time * 2.5) + 1.0) / 2.0

	# 外圈光晕
	var glow_radius = 32 + pulse * 6
	for i in range(2):
		var r = glow_radius + i * 6
		var a = (0.2 - i * 0.08) + pulse * 0.1
		grid_container.draw_circle(center, r, Color(0.3, 0.6, 1.0, a))

	# 主体圆形
	grid_container.draw_circle(center, 28, Color(0.25, 0.55, 0.95, 0.9))
	grid_container.draw_circle(center, 28, Color(0.4, 0.7, 1.0), false, 3.5)

	# 内圈高光
	var highlight_offset = Vector2(-6, -6)
	grid_container.draw_circle(center + highlight_offset, 10, Color(0.7, 0.9, 1.0, 0.6))

	# 文字
	var font = ThemeDB.fallback_font
	var text = "玩家"
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
	var text_pos = center - Vector2(text_size.x / 2.0, -6)

	# 文字外发光
	grid_container.draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.2, 0.4, 0.8, 0.5))
	grid_container.draw_string(font, text_pos - Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.5, 0.8, 1.0, 0.3))
	# 主文字
	grid_container.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1))

func _draw_evacuation_point(center: Vector2, cell_size: float):
	# 获取动画时间（基于游戏运行时间）
	var time = Time.get_ticks_msec() / 1000.0
	var pulse = (sin(time * 3.0) + 1.0) / 2.0  # 0-1之间脉冲
	var rotate_angle = time * 45.0  # 旋转角度

	# 外圈光晕（脉冲效果）
	var glow_radius = 35 + pulse * 8
	var glow_alpha = 0.15 + pulse * 0.15
	for i in range(3):
		var r = glow_radius + i * 8
		var a = glow_alpha - i * 0.05
		grid_container.draw_circle(center, r, Color(0.3, 1.0, 0.5, a))

	# 旋转的外圈六边形
	var outer_hex_radius = 32
	var outer_points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60 * i + rotate_angle)
		outer_points.append(Vector2(
			center.x + cos(angle) * outer_hex_radius,
			center.y + sin(angle) * outer_hex_radius
		))
	grid_container.draw_colored_polygon(outer_points, Color(0.2, 0.9, 0.3, 0.4))
	grid_container.draw_polyline(outer_points + PackedVector2Array([outer_points[0]]), Color(0.4, 1.0, 0.5), 3.0)

	# 内圈菱形（反向旋转）
	var diamond_size = 22
	var diamond_angle = -rotate_angle * 1.5
	var diamond_points = PackedVector2Array([
		Vector2(center.x, center.y - diamond_size) + Vector2(cos(deg_to_rad(diamond_angle)), sin(deg_to_rad(diamond_angle))) * 0,
		Vector2(center.x + diamond_size, center.y),
		Vector2(center.x, center.y + diamond_size),
		Vector2(center.x - diamond_size, center.y)
	])

	# 旋转菱形
	var rotated_diamond = PackedVector2Array()
	for point in diamond_points:
		var offset = point - center
		var rotated_offset = Vector2(
			offset.x * cos(deg_to_rad(diamond_angle)) - offset.y * sin(deg_to_rad(diamond_angle)),
			offset.x * sin(deg_to_rad(diamond_angle)) + offset.y * cos(deg_to_rad(diamond_angle))
		)
		rotated_diamond.append(center + rotated_offset)

	grid_container.draw_colored_polygon(rotated_diamond, Color(0.3, 1.0, 0.4, 0.8))
	grid_container.draw_polyline(rotated_diamond + PackedVector2Array([rotated_diamond[0]]), Color(0.5, 1.0, 0.6), 2.5)

	# 中心圆形（脉冲）
	var core_radius = 8 + pulse * 3
	grid_container.draw_circle(center, core_radius, Color(0.9, 1.0, 0.9))
	grid_container.draw_circle(center, core_radius * 0.7, Color(0.3, 1.0, 0.5))

	# 四个角的发光点（旋转）
	for i in range(4):
		var angle = deg_to_rad(90 * i + rotate_angle * 0.5)
		var point_pos = center + Vector2(cos(angle), sin(angle)) * 26
		var point_size = 3 + pulse * 2
		grid_container.draw_circle(point_pos, point_size * 1.5, Color(0.3, 1.0, 0.5, 0.3))
		grid_container.draw_circle(point_pos, point_size, Color(0.8, 1.0, 0.9))

	# 文字（带发光效果）
	var text_color = Color(0.9, 1.0, 0.95)
	var text_glow = Color(0.3, 1.0, 0.5, 0.3 + pulse * 0.3)

	var font = ThemeDB.fallback_font
	var text = "撤离"
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14)
	var text_pos = center - Vector2(text_size.x / 2.0, -35)

	# 外发光
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			if dx != 0 or dy != 0:
				grid_container.draw_string(font, text_pos + Vector2(dx, dy), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_glow)

	# 阴影
	grid_container.draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
	# 文字
	grid_container.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, text_color)

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
		var current_time = Time.get_ticks_msec() / 1000.0

		# 如果输入被锁定，忽略点击
		if input_locked:
			return

		# 防抖：忽略过快的连续点击
		if current_time - last_click_time < CLICK_DEBOUNCE_TIME:
			return

		last_click_time = current_time

		# 确保布局参数是最新的
		if current_cell_size <= 0:
			_update_grid_layout()

		# 使用本地鼠标位置而非事件位置，确保坐标一致性
		var mouse_pos = grid_container.get_local_mouse_position()

		# 计算相对于网格的位置
		var relative_x = mouse_pos.x - current_offset_x
		var relative_y = mouse_pos.y - current_offset_y

		# 检查是否在网格范围内
		if relative_x < 0 or relative_y < 0:
			return

		var total_grid_width = GRID_SIZE * current_cell_size
		var total_grid_height = GRID_SIZE * current_cell_size

		if relative_x >= total_grid_width or relative_y >= total_grid_height:
			return

		# 精确计算网格坐标 - 使用floor确保在正确的格子内
		var grid_x = int(floor(relative_x / current_cell_size))
		var grid_y = int(floor(relative_y / current_cell_size))

		# 再次边界检查
		grid_x = clamp(grid_x, 0, GRID_SIZE - 1)
		grid_y = clamp(grid_y, 0, GRID_SIZE - 1)

		_on_cell_clicked(grid_x, grid_y)
	
	elif event is InputEventMouseMotion:
		grid_container.queue_redraw()

func _on_gesture_detected(gesture, position: Vector2):
	# 处理移动端手势
	# 在桌面平台禁用手势检测，避免与鼠标点击冲突
	if OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
		return

	# 检查输入是否被锁定
	if input_locked:
		return

	# 防抖：忽略过快的手势
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_click_time < CLICK_DEBOUNCE_TIME:
		return

	var grid_x = int((position.x - current_offset_x) / current_cell_size)
	var grid_y = int((position.y - current_offset_y) / current_cell_size)

	# 确保手势在网格范围内
	if grid_x < 0 or grid_x >= GRID_SIZE or grid_y < 0 or grid_y >= GRID_SIZE:
		return

	last_click_time = current_time

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

	# 点击自己 - 如果在撤离点上弹窗询问是否撤离
	if clicked_pos == player_pos:
		if show_evacuation and evacuation_points.has(player_pos):
			_show_evacuation_confirm()
		return

	# 只能移动到相邻格子
	if not _is_adjacent(player_pos, clicked_pos):
		return

	# 禁止移动到已坍塌格子
	if grid_data[clicked_pos.y][clicked_pos.x].collapsed:
		_show_message("该区域已坍塌，无法进入！")
		return

	# 移动到目标格子
	_move_to_cell(clicked_pos)

func _is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	return (dx <= 1 and dy <= 1) and not (dx == 0 and dy == 0)

func _move_to_cell(target_pos: Vector2i):
	var cell = grid_data[target_pos.y][target_pos.x]

	# 记录是否是首次探索（用于决定是否收集资源）
	var is_first_exploration = not cell.explored

	# 如果是未探索的格子，先探索
	if not cell.explored:
		cell.explored = true
		explored_count += 1

		# 检查是否达到探索度阈值，显示撤离点（探索40%以上）
		var explore_threshold = int(GRID_SIZE * GRID_SIZE * 0.4)
		if explored_count >= explore_threshold and not show_evacuation:
			show_evacuation = true
			_show_message("探索进度已达 " + str(int(explored_count * 100.0 / (GRID_SIZE * GRID_SIZE))) + "%\n撤离点已显示在地图上！")
			_update_evacuation_status()

	# 移动玩家
	player_pos = target_pos

	_update_info()
	grid_container.queue_redraw()

	# 检查是否移动到撤离点，弹窗询问是否撤离
	if show_evacuation and evacuation_points.has(target_pos):
		_show_evacuation_confirm()
		return

	# 检查是否触发战斗
	if cell.has_enemy:
		_start_battle(cell.enemy_data)
		return

	# 只在首次探索且没有敌人时收集资源
	if is_first_exploration:
		_collect_resources_from_cell(cell)

func _start_battle(enemy_data: Dictionary):
	# 保存当前游戏状态到UserSession
	var session = get_node("/root/UserSession")

	# 生成敌人魂印（根据敌人力量随机生成1-3个）
	var enemy_souls = _generate_enemy_souls(enemy_data.get("power", 30))

	# 保存地图状态（包括网格数据）
	session.set_meta("map_player_pos", player_pos)
	session.set_meta("map_player_hp", player_hp)
	session.set_meta("map_max_hp", max_hp)
	session.set_meta("map_explored_count", explored_count)
	session.set_meta("map_show_evacuation", show_evacuation)
	session.set_meta("map_collapse_ring_index", collapse_ring_index)
	session.set_meta("map_collected_souls", collected_souls)
	session.set_meta("map_collapse_time_remaining", collapse_time_remaining)
	# 保存网格数据（探索状态、资源等）
	session.set_meta("map_grid_data", _serialize_grid_data())

	# 保存战斗数据 - 使用带入地图的魂印配置而不是全部背包
	session.set_meta("battle_enemy_data", enemy_data)
	session.set_meta("battle_player_hp", player_hp)
	session.set_meta("battle_player_souls", soul_loadout)  # 使用带入地图的魂印配置
	session.set_meta("battle_enemy_souls", enemy_souls)
	session.set_meta("return_to_map", true)

	# 跳转到准备场景
	get_tree().change_scene_to_file("res://scenes/BattlePreparation.tscn")

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
	
	# 等待用户关闭对话框
	await _show_message(message)

	# 短暂延迟后返回大厅
	await get_tree().create_timer(0.5).timeout
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

func _update_evacuation_status():
	"""更新撤离点状态显示"""
	if show_evacuation:
		evacuation_label.text = "⚠ 撤离点已出现 ⚠"
		evacuation_label.add_theme_font_size_override("font_size", 20)
		evacuation_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0))  # 黄色

		# 添加背景高亮
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.0, 0.5, 0.0, 0.8)  # 深绿色背景
		style_box.set_corner_radius_all(5)
		evacuation_label.add_theme_stylebox_override("normal", style_box)

		# 开始闪烁动画
		_start_evacuation_blink()
	else:
		evacuation_label.text = "撤离点: 未出现"
		evacuation_label.add_theme_font_size_override("font_size", 14)
		evacuation_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))  # 灰色
		evacuation_label.remove_theme_stylebox_override("normal")

func _start_evacuation_blink():
	"""撤离点标签闪烁动画"""
	var tween = create_tween()
	tween.set_loops()  # 无限循环

	# 在黄色和白色之间闪烁
	tween.tween_property(evacuation_label, "theme_override_colors/font_color", Color(1.0, 1.0, 1.0), 0.5)
	tween.tween_property(evacuation_label, "theme_override_colors/font_color", Color(1.0, 1.0, 0.0), 0.5)

func _show_evacuation_confirm():
	# 显示撤离确认对话框
	var message = "确定要撤离吗？\n\n"
	if collected_souls.size() > 0:
		message += "本次收集了 " + str(collected_souls.size()) + " 个魂印\n"
		message += "撤离后将保留所有收集的魂印"
	else:
		message += "本次没有收集到魂印"

	evacuation_confirm_dialog.dialog_text = message
	evacuation_confirm_dialog.popup_centered()

func _evacuate():
	# 成功撤离，保留所有收集的魂印
	var message = "成功撤离！\n"
	if collected_souls.size() > 0:
		message += "本次收集了 " + str(collected_souls.size()) + " 个魂印"
	else:
		message += "本次没有收集到魂印"

	# 等待用户关闭对话框
	await _show_message(message)

	# 短暂延迟后返回大厅
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

func _show_message(text: String):
	# 锁定输入以防止对话框关闭时误触发点击
	input_locked = true

	message_dialog.dialog_text = text
	message_dialog.popup_centered()

	# 等待对话框关闭（循环等待直到对话框不可见）
	while message_dialog.visible:
		await message_dialog.visibility_changed

	# 对话框已关闭，短暂延迟后解锁输入（防止关闭点击穿透）
	await get_tree().create_timer(0.15).timeout
	input_locked = false

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

func _on_evacuation_confirmed():
	# 确认撤离
	_evacuate()

# ========== 地图状态序列化 ==========

func _serialize_grid_data() -> Array:
	# 将网格数据序列化为可保存的数组
	var serialized_data = []
	for y in range(GRID_SIZE):
		var row = []
		for x in range(GRID_SIZE):
			var cell = grid_data[y][x]
			var cell_data = {
				"quality": cell.quality,
				"resource_count": cell.resource_count,
				"explored": cell.explored,
				"has_enemy": cell.has_enemy,
				"enemy_data": cell.enemy_data,
				"collapsed": cell.collapsed
			}
			row.append(cell_data)
		serialized_data.append(row)
	return serialized_data

func _restore_grid_data(serialized_data: Array):
	# 从序列化数据恢复网格
	grid_data = []
	for y in range(GRID_SIZE):
		var row: Array[GridCell] = []
		for x in range(GRID_SIZE):
			var cell = GridCell.new()
			if y < serialized_data.size() and x < serialized_data[y].size():
				var cell_data = serialized_data[y][x]
				cell.quality = cell_data.get("quality", 0)
				cell.resource_count = cell_data.get("resource_count", 1)
				cell.explored = cell_data.get("explored", false)
				cell.has_enemy = cell_data.get("has_enemy", false)
				cell.enemy_data = cell_data.get("enemy_data", {})
				cell.collapsed = cell_data.get("collapsed", false)
			row.append(cell)
		grid_data.append(row)
