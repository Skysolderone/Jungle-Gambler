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
@onready var game_camera = $GameCamera
@onready var collapse_sound_player = $CollapseSoundPlayer
@onready var fall_sound_player = $FallSoundPlayer

const GRID_SIZE = 9
var CELL_SIZE = 80 # 改为变量，支持响应式调整
const SETTINGS_PATH = "user://settings.json"
# const COLLAPSE_INTERVAL := 30.0 # 坍塌间隔（秒），每30秒坍塌一圈
const COLLAPSE_INTERVAL := 5.0 # 坍塌间隔（秒），每30秒坍塌一圈

# 调试模式配置
const DEBUG_MODE = false # 设置为 true 启用调试模式
const DEBUG_NO_ENEMIES = false # 调试模式：不生成敌人
const DEBUG_NO_COLLAPSE = false # 调试模式：禁用地形坍塌

# 格子数据结构（重构版）
class GridCell:
	var quality: int = 0 # 魂印品质 0-5
	var resource_count: int = 1 # 魂印数量 1-3
	var explored: bool = false # 是否已探索
	var has_enemy: bool = false # 是否有敌人（隐藏）
	var enemy_data: Dictionary = {} # 敌人数据 {name: String, hp: int, power: int}

	# 新增：坐标系统
	var logic_pos: Vector2i = Vector2i.ZERO # 逻辑坐标（在紧凑网格中的位置）
	var visual_position: Vector2 = Vector2.ZERO # 视觉位置（绘制位置，用于动画）

	# 动画状态
	var collapsing: bool = false # 正在坍塌动画中
	var collapse_progress: float = 0.0 # 坍塌动画进度 0-1
	var fall_progress: float = 0.0 # 下落动画进度 0-1
	var is_moving: bool = false # 是否正在移动到新位置

	# 唯一标识（用于追踪格子）
	var cell_id: int = 0 # 格子唯一ID

# 地图数据（重构版 - 动态列表）
var active_cells: Array[GridCell] = [] # 所有活跃的格子（未坍塌）
var cell_lookup: Dictionary = {} # 快速查找映射：logic_pos -> GridCell
var next_cell_id: int = 0 # 下一个格子ID

# 网格布局信息
var current_grid_width: int = GRID_SIZE # 当前网格宽度
var current_grid_height: int = GRID_SIZE # 当前网格高度

# 兼容性：保留旧的grid_data用于初始化，但不再用于主要逻辑
var grid_data: Array[Array] = [] # 仅用于初始化阶段

var player_pos = Vector2i(4, 4) # 玩家初始位置（逻辑坐标）
var selected_map = null
var soul_loadout = []
var inventory_instance = null

# 玩家状态
var player_hp = 100
var max_hp = 100

# 撤离点
var evacuation_points: Array[Vector2i] = [] # 撤离点位置
var explored_count: int = 0 # 已探索格子数
var show_evacuation: bool = false # 是否显示撤离点

# 收集记录
var collected_souls: Array[String] = [] # 本局收集到的魂印ID列表

# 坍塌状态
var collapse_ring_index: int = -1 # 已坍塌到第几圈（-1 表示未开始）
var collapse_time_remaining: float = COLLAPSE_INTERVAL # 距离下次坍塌剩余时间

# 输入锁定（防止对话框关闭时误触发点击）
var input_locked: bool = false

# 点击防抖（防止快速连续点击）
var last_click_time: float = 0.0
const CLICK_DEBOUNCE_TIME: float = 0.3 # 300ms 防抖间隔

# 动态布局参数
var current_cell_size: float = 80.0
var current_offset_x: float = 0.0
var current_offset_y: float = 0.0

# 坍塌动画状态
var collapse_animation_running: bool = false
var collapsing_cells: Array[Vector2i] = [] # 正在坍塌的格子坐标

func _ready():
	# 应用像素风格
	_apply_pixel_style()

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

# ========== 像素风格应用 ==========

func _apply_pixel_style():
	"""应用像素艺术风格到地图探索场景"""
	if not has_node("/root/PixelStyleManager"):
		push_warning("PixelStyleManager 未加载，跳过像素风格应用")
		return

	var pixel_style = get_node("/root/PixelStyleManager")

	# 应用背景颜色
	var background = $Background
	background.color = pixel_style.PIXEL_PALETTE["BLACK"]

	# 顶部栏像素风格
	var top_bar = $TopBar
	pixel_style.apply_pixel_panel_style(top_bar, "DARK_GREY")

	# 信息标签 - 使用不同颜色突出重要信息
	pixel_style.apply_pixel_label_style(map_name_label, "YELLOW", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)
	pixel_style.apply_pixel_label_style(player_info_label, "CYAN", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)
	pixel_style.apply_pixel_label_style(power_label, "GREEN", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)
	pixel_style.apply_pixel_label_style(exploration_label, "BLUE", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)
	pixel_style.apply_pixel_label_style(evacuation_label, "ORANGE", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)
	pixel_style.apply_pixel_label_style(collapse_timer_label, "RED", true, pixel_style.PIXEL_FONT_SIZE_NORMAL)

	# 按钮像素风格
	var inventory_btn = $TopBar/MarginContainer/HBoxContainer/InventoryButton
	var exit_btn = $TopBar/MarginContainer/HBoxContainer/ExitButton
	pixel_style.apply_pixel_button_style(inventory_btn, "ORANGE", pixel_style.PIXEL_FONT_SIZE_NORMAL)
	pixel_style.apply_pixel_button_style(exit_btn, "RED", pixel_style.PIXEL_FONT_SIZE_NORMAL)

	# 地图网格面板
	pixel_style.apply_pixel_panel_style(grid_panel, "DARK_GREY")

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
		var available_size = min(panel_size.x, panel_size.y) - 40 # 减去40px边距
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
		_update_panel_size() # 重新调整Panel尺寸
		_update_grid_layout() # 更新网格布局参数
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
			# 检查玩家当前位置是否还存在（坍塌后已在 _start_collapse_and_reorganize 中检查）
		else:
			return # 所有圈已坍塌，结束
		await get_tree().create_timer(COLLAPSE_INTERVAL).timeout

func _start_evacuation_animation():
	# 撤离点动画循环，每帧重绘以实现动画效果
	while true:
		if show_evacuation:
			grid_container.queue_redraw()
		await get_tree().create_timer(0.05).timeout # 20fps动画

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

		await get_tree().create_timer(0.1).timeout # 每0.1秒更新一次

func _update_collapse_timer_display():
	var seconds = int(ceil(collapse_time_remaining))

	# 剩余10秒时的警告效果
	if seconds <= 10 and seconds > 0:
		# 红色闪烁效果
		var time = Time.get_ticks_msec() / 1000.0
		var pulse = (sin(time * 5.0) + 1.0) / 2.0 # 快速脉冲
		var warning_color = Color(1.0, pulse * 0.3, pulse * 0.3) # 红色到暗红色

		collapse_timer_label.add_theme_color_override("font_color", warning_color)
		collapse_timer_label.add_theme_font_size_override("font_size", 15)
		collapse_timer_label.text = "⚠ 坍塌: " + str(seconds) + "秒 ⚠"

		# 添加红色背景
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.5, 0.0, 0.0, 0.6 + pulse * 0.2)
		style_box.set_corner_radius_all(5)
		collapse_timer_label.add_theme_stylebox_override("normal", style_box)
	elif seconds == 0:
		# 坍塌中
		collapse_timer_label.text = "坍塌中..."
		collapse_timer_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		collapse_timer_label.add_theme_font_size_override("font_size", 14)
	else:
		# 正常倒计时
		collapse_timer_label.text = "坍塌: " + str(seconds) + "秒"
		collapse_timer_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		collapse_timer_label.add_theme_font_size_override("font_size", 13)
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
	"""初始化网格（重构版）- 创建动态格子列表"""
	active_cells.clear()
	cell_lookup.clear()
	next_cell_id = 0

	# 创建初始的9×9网格
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell = GridCell.new()
			# 随机分配魂印品质和数量
			cell.quality = randi() % 6 # 0-5
			cell.resource_count = randi() % 3 + 1 # 1-3
			cell.explored = false
			cell.has_enemy = false

			# 设置坐标
			cell.logic_pos = Vector2i(x, y)
			cell.visual_position = Vector2(x, y) # 初始视觉位置与逻辑位置相同

			# 分配唯一ID
			cell.cell_id = next_cell_id
			next_cell_id += 1

			# 添加到活跃列表
			active_cells.append(cell)
			cell_lookup[cell.logic_pos] = cell

	# 初始化网格尺寸
	current_grid_width = GRID_SIZE
	current_grid_height = GRID_SIZE

	# 玩家起始位置自动探索
	var start_cell = _get_cell_at(player_pos)
	if start_cell:
		start_cell.explored = true
		explored_count = 1

	print("初始化网格完成：", active_cells.size(), "个格子")

func _generate_map_content():
	# 调试模式：跳过敌人生成
	if not (DEBUG_MODE and DEBUG_NO_ENEMIES):
		# 根据地图难度调整敌人数量
		var enemy_count = 10 # 默认值
		var difficulty = selected_map.get("difficulty", "普通") if selected_map else "普通"

		match difficulty:
			"简单":
				enemy_count = randi() % 3 + 2 # 2-4 个敌人
			"普通":
				enemy_count = randi() % 6 + 10 # 10-15 个敌人
			"困难":
				enemy_count = randi() % 6 + 15 # 15-20 个敌人
			"专家":
				enemy_count = randi() % 6 + 20 # 20-25 个敌人

		for i in range(enemy_count):
			var pos = _get_random_cell_pos()
			if pos != Vector2i(-1, -1):
				var cell = _get_cell_at(pos)
				if cell and not cell.has_enemy: # 避免重复
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
	var evac_count = randi() % 2 + 2 # 2-3 个撤离点，确保有足够的撤离机会
	var attempts = 0
	while evacuation_points.size() < evac_count and attempts < 50:
		var pos = _get_random_cell_pos()
		if pos != player_pos and not evacuation_points.has(pos):
			evacuation_points.append(pos)
		attempts += 1
	print("生成了 ", evacuation_points.size(), " 个撤离点")

func _get_random_cell_pos() -> Vector2i:
	"""随机获取一个格子的逻辑坐标"""
	if active_cells.is_empty():
		return Vector2i(-1, -1)

	var random_cell = active_cells[randi() % active_cells.size()]
	return random_cell.logic_pos

func _get_cell_at(logic_pos: Vector2i) -> GridCell:
	"""根据逻辑坐标获取格子，返回null表示不存在"""
	return cell_lookup.get(logic_pos, null)

func _has_cell_at(logic_pos: Vector2i) -> bool:
	"""检查指定逻辑坐标是否有格子"""
	return cell_lookup.has(logic_pos)

func _collapse_next_ring() -> bool:
	"""随机选择地块坍塌并重组（重构版）- 保持完全平方数"""
	collapse_ring_index += 1

	# 收集所有可坍塌的格子（不包括玩家位置和撤离点）
	var available_cells: Array[GridCell] = []
	for cell in active_cells:
		# 排除玩家位置和撤离点
		if cell.logic_pos != player_pos and not evacuation_points.has(cell.logic_pos):
			available_cells.append(cell)

	# 如果没有可坍塌的格子，结束
	if available_cells.is_empty():
		print("没有可坍塌的格子，坍塌系统结束")
		return false

	# 计算目标格子数（下一个完全平方数）
	var current_count = active_cells.size()
	var current_size = ceili(sqrt(current_count))
	
	# 目标：减小一圈（边长-1），计算需要坍塌多少格子
	var target_size = max(current_size - 1, 3) # 最小保持3x3
	var target_count = target_size * target_size
	
	# 如果目标格子数大于等于当前数量，说明已经很紧凑了，强制减少
	if target_count >= current_count:
		target_count = max((current_size - 1) * (current_size - 1), 9) # 最小9个（3x3）
	
	var collapse_count = current_count - target_count
	
	# 确保至少坍塌一些格子，但不超过可用格子数
	collapse_count = clamp(collapse_count, 1, available_cells.size())
	
	var cells_to_collapse: Array[GridCell] = []

	# 洗牌算法随机选择
	available_cells.shuffle()
	for i in range(collapse_count):
		cells_to_collapse.append(available_cells[i])

	print("准备坍塌 ", collapse_count, " 个格子，当前剩余 ", active_cells.size(), " 个格子，目标: ", target_count, " (", target_size, "×", target_size, ")")

	# 启动坍塌和重组动画
	_start_collapse_and_reorganize(cells_to_collapse)

	return true

func _update_grid_layout():
	# 使用GridPanel的实际大小而不是GridContainer
	var panel_size = grid_panel.size

	# 计算网格能适应的最大尺寸（正方形）
	var available_size = min(panel_size.x, panel_size.y) - 40 # 减去40px边距
	current_cell_size = available_size / GRID_SIZE

	# 居中偏移
	current_offset_x = (panel_size.x - (GRID_SIZE * current_cell_size)) / 2
	current_offset_y = (panel_size.y - (GRID_SIZE * current_cell_size)) / 2

func _draw_grid():
	"""绘制动态网格（重构版）"""
	# 只在需要时更新布局，避免频繁调用
	if current_cell_size <= 0:
		_update_grid_layout()

	# 使用当前动态网格尺寸
	var grid_width = current_grid_width
	var grid_height = current_grid_height

	# 重新计算cell_size以适配当前网格尺寸
	var panel_size = grid_panel.size
	var available_width = panel_size.x - 40
	var available_height = panel_size.y - 40

	# 根据网格比例计算最佳cell_size
	var cell_size_by_width = available_width / grid_width
	var cell_size_by_height = available_height / grid_height
	current_cell_size = min(cell_size_by_width, cell_size_by_height)

	# 居中偏移
	current_offset_x = (panel_size.x - (grid_width * current_cell_size)) / 2
	current_offset_y = (panel_size.y - (grid_height * current_cell_size)) / 2

	# 绘制网格背景
	var bg_rect = Rect2(current_offset_x, current_offset_y, grid_width * current_cell_size, grid_height * current_cell_size)
	grid_container.draw_rect(bg_rect, Color(0, 0, 0, 0.02), true)

	# 绘制网格线（动态尺寸）- 已隐藏
	# for x in range(grid_width + 1):
	# 	var start = Vector2(current_offset_x + x * current_cell_size, current_offset_y)
	# 	var end = Vector2(current_offset_x + x * current_cell_size, current_offset_y + grid_height * current_cell_size)
	# 	grid_container.draw_line(start, end, Color(0.3, 0.3, 0.35, 0.5), 2.0)

	# for y in range(grid_height + 1):
	# 	var start = Vector2(current_offset_x, current_offset_y + y * current_cell_size)
	# 	var end = Vector2(current_offset_x + grid_width * current_cell_size, current_offset_y + y * current_cell_size)
	# 	grid_container.draw_line(start, end, Color(0.3, 0.3, 0.35, 0.5), 2.0)

	# 绘制所有活跃格子（使用visual_position）
	for cell in active_cells:
		_draw_cell_v2(cell, current_cell_size, current_offset_x, current_offset_y)

func _draw_cell_v2(cell: GridCell, cell_size: float, offset_x: float, offset_y: float):
	"""绘制单个格子（重构版 - 使用visual_position）- 像素风格"""
	# 使用视觉位置进行绘制（支持动画）
	var visual_x = cell.visual_position.x
	var visual_y = cell.visual_position.y

	var rect = Rect2(offset_x + visual_x * cell_size + 5, offset_y + visual_y * cell_size + 5, cell_size - 10, cell_size - 10)
	var center = Vector2(offset_x + visual_x * cell_size + cell_size / 2.0, offset_y + visual_y * cell_size + cell_size / 2.0)

	# 鼠标悬停检测（使用逻辑坐标）
	var mouse_pos = grid_container.get_local_mouse_position()
	var relative_x = mouse_pos.x - offset_x
	var relative_y = mouse_pos.y - offset_y
	var hover_grid_x = int(floor(relative_x / cell_size))
	var hover_grid_y = int(floor(relative_y / cell_size))
	var hover_pos = Vector2i(hover_grid_x, hover_grid_y)
	var is_hovered = (hover_pos == cell.logic_pos)

	# 坍塌动画效果（优先绘制，不绘制底色）
	if cell.collapsing:
		_draw_collapsing_cell_pixel(rect, center, cell)
		return # 坍塌中的格子不绘制其他内容

	# 先绘制格子底色（像素风格 - 纯色块）
	var base_color = _get_cell_color(cell)
	grid_container.draw_rect(rect, base_color, true)

	# 像素风格：添加内部像素化边框（深色）
	var border_width = 3.0
	_draw_pixel_border(rect, Color(0, 0, 0, 0.3), border_width)

	# 像素风格：添加高光边框（右下角更暗，左上角更亮）
	var highlight_color = Color(base_color.r * 1.3, base_color.g * 1.3, base_color.b * 1.3, base_color.a)
	var shadow_color = Color(base_color.r * 0.6, base_color.g * 0.6, base_color.b * 0.6, base_color.a)

	# 左上边亮边
	grid_container.draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), highlight_color, 2.0)
	grid_container.draw_line(rect.position, rect.position + Vector2(0, rect.size.y), highlight_color, 2.0)

	# 右下边暗边
	grid_container.draw_line(rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, shadow_color, 2.0)
	grid_container.draw_line(rect.position + Vector2(0, rect.size.y), rect.position + rect.size, shadow_color, 2.0)

	# 绘制品质图标/符号（已探索或玩家位置）- 像素风格
	if cell.explored or player_pos == cell.logic_pos:
		_draw_quality_indicator_pixel(center, cell.quality, cell.resource_count, cell_size * 0.3)

	# 未探索的格子 - 添加半透明遮罩和像素点阵图案
	if not cell.explored and player_pos != cell.logic_pos:
		grid_container.draw_rect(rect, Color(0.05, 0.05, 0.1, 0.6), true)
		# 像素点阵图案（问号效果）
		_draw_pixel_pattern(rect, Color(0.2, 0.2, 0.25, 0.5))

	# 玩家位置
	if player_pos == cell.logic_pos:
		_draw_player_pixel(center, cell_size)
		return

	# 撤离点（只有达到探索度才显示）
	if show_evacuation and evacuation_points.has(cell.logic_pos) and cell.explored:
		_draw_evacuation_point_pixel(center, cell_size)
		return

	# 悬停高亮（像素风格 - 使用虚线边框）
	if is_hovered and _is_adjacent(player_pos, cell.logic_pos):
		_draw_pixel_dashed_border(rect, Color(1, 1, 1, 0.8), 3.0)

func _get_cell_color(cell: GridCell) -> Color:
	# 品质对应的基础颜色 - 更鲜艳的配色方案
	var quality_colors = [
		Color(0.65, 0.65, 0.7), # 0: 普通 - 明亮灰色
		Color(0.3, 0.9, 0.4), # 1: 非凡 - 鲜绿色
		Color(0.3, 0.7, 1.0), # 2: 稀有 - 亮蓝色
		Color(0.75, 0.35, 0.95), # 3: 史诗 - 鲜紫色
		Color(1.0, 0.7, 0.3), # 4: 传说 - 金橙色
		Color(1.0, 0.25, 0.4) # 5: 神话 - 炫红色
	]

	var base_color = quality_colors[cell.quality]

	# 根据资源数量调整亮度（1-3对应更高的可见度）
	var alpha = 0.5 + (cell.resource_count / 3.0) * 0.45

	return Color(base_color.r, base_color.g, base_color.b, alpha)

func _draw_quality_indicator(center: Vector2, quality: int, resource_count: int, size: float):
	# 绘制品质指示器（符号+数量）
	var quality_colors = [
		Color(0.8, 0.8, 0.85), # 0: 普通 - 亮灰
		Color(0.4, 1.0, 0.5), # 1: 非凡 - 亮绿
		Color(0.4, 0.8, 1.0), # 2: 稀有 - 亮蓝
		Color(0.85, 0.5, 1.0), # 3: 史诗 - 亮紫
		Color(1.0, 0.8, 0.4), # 4: 传说 - 亮金
		Color(1.0, 0.4, 0.5) # 5: 神话 - 亮红
	]

	var color = quality_colors[quality]

	# 根据品质绘制不同的形状
	match quality:
		0: # 普通 - 小圆点
			grid_container.draw_circle(center, size * 0.3, color)
		1: # 非凡 - 菱形
			var points = PackedVector2Array([
				Vector2(center.x, center.y - size * 0.5),
				Vector2(center.x + size * 0.5, center.y),
				Vector2(center.x, center.y + size * 0.5),
				Vector2(center.x - size * 0.5, center.y)
			])
			grid_container.draw_colored_polygon(points, color)
		2: # 稀有 - 六边形
			_draw_hexagon(center, size * 0.5, color)
		3: # 史诗 - 五角星
			_draw_star(center, size * 0.6, color, 5)
		4: # 传说 - 八角星
			_draw_star(center, size * 0.65, color, 8)
		5: # 神话 - 发光的十字星
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
		if i % 2 == 0: # 只在尖角添加光晕
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
	var pulse = (sin(time * 3.0) + 1.0) / 2.0 # 0-1之间脉冲
	var rotate_angle = time * 45.0 # 旋转角度

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
	var diamond_angle = - rotate_angle * 1.5
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

# ============================================
# 像素风格绘制函数
# ============================================

func _draw_pixel_border(rect: Rect2, color: Color, width: float):
	"""绘制像素风格边框"""
	var top_left = rect.position
	var top_right = rect.position + Vector2(rect.size.x, 0)
	var bottom_left = rect.position + Vector2(0, rect.size.y)
	var bottom_right = rect.position + rect.size

	# 上边
	grid_container.draw_line(top_left, top_right, color, width)
	# 下边
	grid_container.draw_line(bottom_left, bottom_right, color, width)
	# 左边
	grid_container.draw_line(top_left, bottom_left, color, width)
	# 右边
	grid_container.draw_line(top_right, bottom_right, color, width)

func _draw_pixel_dashed_border(rect: Rect2, color: Color, width: float):
	"""绘制像素风格虚线边框"""
	var dash_length = 6.0
	var gap_length = 4.0
	var segment = dash_length + gap_length

	# 上边
	var x = rect.position.x
	while x < rect.position.x + rect.size.x:
		var end_x = min(x + dash_length, rect.position.x + rect.size.x)
		grid_container.draw_line(Vector2(x, rect.position.y), Vector2(end_x, rect.position.y), color, width)
		x += segment

	# 下边
	x = rect.position.x
	while x < rect.position.x + rect.size.x:
		var end_x = min(x + dash_length, rect.position.x + rect.size.x)
		var y = rect.position.y + rect.size.y
		grid_container.draw_line(Vector2(x, y), Vector2(end_x, y), color, width)
		x += segment

	# 左边
	var y = rect.position.y
	while y < rect.position.y + rect.size.y:
		var end_y = min(y + dash_length, rect.position.y + rect.size.y)
		grid_container.draw_line(Vector2(rect.position.x, y), Vector2(rect.position.x, end_y), color, width)
		y += segment

	# 右边
	y = rect.position.y
	while y < rect.position.y + rect.size.y:
		var end_y = min(y + dash_length, rect.position.y + rect.size.y)
		var x_pos = rect.position.x + rect.size.x
		grid_container.draw_line(Vector2(x_pos, y), Vector2(x_pos, end_y), color, width)
		y += segment

func _draw_pixel_pattern(rect: Rect2, color: Color):
	"""在未探索格子上绘制像素点阵图案"""
	var pixel_size = 4.0
	var spacing = 8.0

	var start_x = rect.position.x + spacing
	var start_y = rect.position.y + spacing

	var y = start_y
	while y < rect.position.y + rect.size.y - spacing:
		var x = start_x
		while x < rect.position.x + rect.size.x - spacing:
			var pixel_rect = Rect2(x, y, pixel_size, pixel_size)
			grid_container.draw_rect(pixel_rect, color, true)
			x += spacing
		y += spacing

func _draw_quality_indicator_pixel(center: Vector2, quality: int, resource_count: int, size: float):
	"""绘制品质指示器（像素风格）"""
	var quality_colors = [
		Color(0.8, 0.8, 0.85), # 0: 普通 - 亮灰
		Color(0.4, 1.0, 0.5), # 1: 非凡 - 亮绿
		Color(0.4, 0.8, 1.0), # 2: 稀有 - 亮蓝
		Color(0.85, 0.5, 1.0), # 3: 史诗 - 亮紫
		Color(1.0, 0.8, 0.4), # 4: 传说 - 亮金
		Color(1.0, 0.4, 0.5) # 5: 神话 - 亮红
	]

	var color = quality_colors[quality]

	# 根据品质绘制不同的像素化形状
	match quality:
		0: # 普通 - 小方块
			var pixel_size = size * 0.4
			var pixel_rect = Rect2(center - Vector2(pixel_size/2, pixel_size/2), Vector2(pixel_size, pixel_size))
			grid_container.draw_rect(pixel_rect, color, true)
			grid_container.draw_rect(pixel_rect, Color(1, 1, 1, 0.5), false, 2.0)
		1: # 非凡 - 像素菱形
			_draw_pixel_diamond(center, size * 0.6, color)
		2: # 稀有 - 像素六边形
			_draw_pixel_hexagon(center, size * 0.5, color)
		3: # 史诗 - 像素五角星
			_draw_pixel_star(center, size * 0.6, color, 5)
		4: # 传说 - 像素八角星
			_draw_pixel_star(center, size * 0.65, color, 8)
		5: # 神话 - 像素十字星
			_draw_pixel_cross_star(center, size * 0.7, color)

	# 绘制资源数量指示器（像素方块）
	if resource_count > 0:
		var dot_size = 4.0
		var dot_spacing = size * 0.3
		var start_x = center.x - (resource_count - 1) * dot_spacing / 2
		var dot_y = center.y + size * 0.8

		for i in range(resource_count):
			var dot_pos = Vector2(start_x + i * dot_spacing, dot_y)
			var dot_rect = Rect2(dot_pos - Vector2(dot_size/2, dot_size/2), Vector2(dot_size, dot_size))
			# 外边框（阴影）
			grid_container.draw_rect(dot_rect.grow(1), Color(0, 0, 0, 0.6), true)
			# 内部（亮色）
			grid_container.draw_rect(dot_rect, Color(1, 1, 1, 0.9), true)

func _draw_pixel_diamond(center: Vector2, size: float, color: Color):
	"""绘制像素化菱形"""
	var points = PackedVector2Array([
		Vector2(center.x, center.y - size),
		Vector2(center.x + size, center.y),
		Vector2(center.x, center.y + size),
		Vector2(center.x - size, center.y)
	])
	grid_container.draw_colored_polygon(points, color)
	grid_container.draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 0.6), 2.0)

func _draw_pixel_hexagon(center: Vector2, radius: float, color: Color):
	"""绘制像素化六边形"""
	var points = PackedVector2Array()
	for i in range(6):
		var angle = deg_to_rad(60 * i - 30)
		points.append(Vector2(
			center.x + cos(angle) * radius,
			center.y + sin(angle) * radius
		))
	grid_container.draw_colored_polygon(points, color)
	grid_container.draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 0.6), 2.0)

func _draw_pixel_star(center: Vector2, radius: float, color: Color, points_count: int):
	"""绘制像素化星形"""
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
	# 添加白色像素边框
	grid_container.draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 0.5), 2.0)

func _draw_pixel_cross_star(center: Vector2, radius: float, color: Color):
	"""绘制像素化十字星（神话品质）"""
	var beam_width = radius * 0.3

	# 绘制四条光束（像素化）
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
		grid_container.draw_polyline(points + PackedVector2Array([points[0]]), Color(1, 1, 1, 0.4), 2.0)

	# 中心方块
	var core_size = radius * 0.4
	var core_rect = Rect2(center - Vector2(core_size/2, core_size/2), Vector2(core_size, core_size))
	grid_container.draw_rect(core_rect, color, true)
	grid_container.draw_rect(core_rect.grow(-2), Color(1, 1, 1, 0.9), true)

func _draw_player_pixel(center: Vector2, cell_size: float):
	"""绘制像素风格玩家标记"""
	var time = Time.get_ticks_msec() / 1000.0
	var pulse = (sin(time * 2.5) + 1.0) / 2.0

	# 外圈光晕（像素化）
	var glow_size = 34.0 + pulse * 4.0
	var glow_rect = Rect2(center - Vector2(glow_size/2, glow_size/2), Vector2(glow_size, glow_size))
	grid_container.draw_rect(glow_rect, Color(0.3, 0.6, 1.0, 0.2 + pulse * 0.1), true)

	# 主体方块（像素风格）
	var main_size = 24.0
	var main_rect = Rect2(center - Vector2(main_size/2, main_size/2), Vector2(main_size, main_size))

	# 主体填充
	grid_container.draw_rect(main_rect, Color(0.25, 0.55, 0.95, 0.9), true)

	# 像素边框（高光效果）
	_draw_pixel_border(main_rect, Color(0.4, 0.7, 1.0), 3.0)

	# 内部高光方块
	var highlight_size = 8.0
	var highlight_rect = Rect2(
		center - Vector2(main_size/4, main_size/4) - Vector2(highlight_size/2, highlight_size/2),
		Vector2(highlight_size, highlight_size)
	)
	grid_container.draw_rect(highlight_rect, Color(0.7, 0.9, 1.0, 0.6), true)

	# 文字（像素风格）
	var font = ThemeDB.fallback_font
	var text = "P" # 玩家标记使用P（Player）
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16)
	var text_pos = center - Vector2(text_size.x / 2.0, -text_size.y / 2.0 + 2)

	# 文字阴影
	grid_container.draw_string(font, text_pos + Vector2(2, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.7))
	# 文字主体
	grid_container.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1))

func _draw_evacuation_point_pixel(center: Vector2, cell_size: float):
	"""绘制像素风格撤离点"""
	var time = Time.get_ticks_msec() / 1000.0
	var pulse = (sin(time * 3.0) + 1.0) / 2.0

	# 外圈光晕方块（脉冲效果）
	var glow_size = 38.0 + pulse * 6.0
	var glow_rect = Rect2(center - Vector2(glow_size/2, glow_size/2), Vector2(glow_size, glow_size))
	grid_container.draw_rect(glow_rect, Color(0.3, 1.0, 0.5, 0.15 + pulse * 0.15), true)

	# 主体方块
	var main_size = 28.0
	var main_rect = Rect2(center - Vector2(main_size/2, main_size/2), Vector2(main_size, main_size))
	grid_container.draw_rect(main_rect, Color(0.2, 0.9, 0.3, 0.6), true)

	# 像素边框
	_draw_pixel_border(main_rect, Color(0.4, 1.0, 0.5), 3.0)

	# 内部菱形（像素风格）
	var diamond_size = 12.0
	_draw_pixel_diamond(center, diamond_size, Color(0.3, 1.0, 0.4, 0.8))

	# 四个角的像素点（闪烁）
	var corner_offset = 20.0
	var corner_positions = [
		center + Vector2(-corner_offset, -corner_offset),
		center + Vector2(corner_offset, -corner_offset),
		center + Vector2(-corner_offset, corner_offset),
		center + Vector2(corner_offset, corner_offset)
	]

	for corner_pos in corner_positions:
		var corner_size = 3.0 + pulse * 2.0
		var corner_rect = Rect2(corner_pos - Vector2(corner_size/2, corner_size/2), Vector2(corner_size, corner_size))
		grid_container.draw_rect(corner_rect, Color(0.8, 1.0, 0.9), true)

	# 文字（像素风格）
	var font = ThemeDB.fallback_font
	var text = "出口"
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)
	var text_pos = center - Vector2(text_size.x / 2.0, -main_size/2 - 12)

	# 文字阴影
	grid_container.draw_string(font, text_pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0, 0, 0, 0.8))
	# 文字主体（绿色）
	grid_container.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 1.0, 0.95))

func _draw_collapsing_cell_pixel(rect: Rect2, center: Vector2, cell: GridCell):
	"""绘制正在坍塌的格子（像素风格）"""
	var base_color = _get_cell_color(cell)

	# 预警阶段 - 闪烁效果（像素化）
	if cell.collapse_progress == 0.0:
		var time = Time.get_ticks_msec() / 1000.0
		var flash = abs(sin(time * 10.0))
		var warning_color = Color(1.0, 0.3, 0.0, 0.6 + flash * 0.4)
		grid_container.draw_rect(rect, warning_color, true)

		# 像素边框抖动
		var shake_offset = Vector2(
			floor(randf_range(-2, 3)),
			floor(randf_range(-2, 3))
		)
		var shaky_rect = Rect2(rect.position + shake_offset, rect.size)
		_draw_pixel_border(shaky_rect, Color(1.0, 0.5, 0.0), 3.0)
		return

	# 破碎阶段 - 显示像素裂纹
	if cell.collapse_progress > 0.0 and cell.fall_progress == 0.0:
		# 绘制基础格子
		grid_container.draw_rect(rect, base_color, true)

		# 绘制像素化裂纹（X形状）
		var crack_color = Color(0.3, 0.0, 0.0, cell.collapse_progress * 0.8)
		var crack_width = 4.0

		# 左上到右下的裂纹
		grid_container.draw_line(rect.position, rect.position + rect.size, crack_color, crack_width)

		# 右上到左下的裂纹
		grid_container.draw_line(
			rect.position + Vector2(rect.size.x, 0),
			rect.position + Vector2(0, rect.size.y),
			crack_color,
			crack_width
		)

		# 绘制像素块破碎效果
		var num_fragments = int(cell.collapse_progress * 5)
		for i in range(num_fragments):
			var frag_x = rect.position.x + (rect.size.x / 5.0) * (i % 3)
			var frag_y = rect.position.y + (rect.size.y / 5.0) * floor(i / 3.0)
			var frag_size = 6.0
			var frag_rect = Rect2(frag_x, frag_y, frag_size, frag_size)
			grid_container.draw_rect(frag_rect, Color(0, 0, 0, cell.collapse_progress * 0.5), true)

		return

	# 下落阶段 - 像素化下落效果
	if cell.fall_progress > 0.0:
		var fall_offset = cell.fall_progress * 200.0
		var fallen_rect = Rect2(rect.position + Vector2(0, fall_offset), rect.size)
		var fall_alpha = 1.0 - cell.fall_progress
		var fallen_color = Color(base_color.r, base_color.g, base_color.b, fall_alpha)

		grid_container.draw_rect(fallen_rect, fallen_color, true)
		_draw_pixel_border(fallen_rect, Color(0, 0, 0, fall_alpha * 0.5), 3.0)

		# 添加像素化残影效果
		for i in range(3):
			var trail_offset = fall_offset * (1.0 - (i + 1) * 0.25)
			var trail_rect = Rect2(rect.position + Vector2(0, trail_offset), rect.size)
			var trail_alpha = fall_alpha * (1.0 - (i + 1) * 0.3)
			grid_container.draw_rect(trail_rect, Color(base_color.r, base_color.g, base_color.b, trail_alpha * 0.3), true)

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
		0: # TAP - 正常点击移动
			_on_cell_clicked(grid_x, grid_y)
		2: # LONG_PRESS - 显示格子信息
			_show_cell_info(grid_x, grid_y)
		3, 4, 5, 6: # 滑动手势 - 快速移动
			_handle_swipe_movement(gesture)

func _handle_swipe_movement(gesture):
	# 根据滑动方向移动玩家
	var move_direction = Vector2i.ZERO
	
	match gesture:
		3: # SWIPE_UP
			move_direction = Vector2i(0, -1)
		4: # SWIPE_DOWN
			move_direction = Vector2i(0, 1)
		5: # SWIPE_LEFT
			move_direction = Vector2i(-1, 0)
		6: # SWIPE_RIGHT
			move_direction = Vector2i(1, 0)
	
	var target_pos = player_pos + move_direction
	
	# 检查目标位置有效性
	if target_pos.x >= 0 and target_pos.x < GRID_SIZE and target_pos.y >= 0 and target_pos.y < GRID_SIZE:
		_on_cell_clicked(target_pos.x, target_pos.y)

func _show_cell_info(x: int, y: int):
	"""显示格子详细信息（长按功能 - 重构版）"""
	var cell = _get_cell_at(Vector2i(x, y))
	if not cell:
		_show_message("该区域不存在")
		return

	var quality_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]

	var info_text = "位置: (" + str(x) + "," + str(y) + ")\n"
	info_text += "品质: " + quality_names[cell.quality] + "\n"
	info_text += "资源数量: " + str(cell.resource_count) + "\n"
	info_text += "已探索: " + ("是" if cell.explored else "否")

	if cell.has_enemy and cell.explored:
		info_text += "\n发现敌人: " + cell.enemy_data.get("name", "未知")

	_show_message(info_text)

func _on_cell_clicked(x: int, y: int):
	"""处理格子点击事件（重构版）"""
	var clicked_pos = Vector2i(x, y)

	# 点击自己 - 如果在撤离点上弹窗询问是否撤离
	if clicked_pos == player_pos:
		if show_evacuation and evacuation_points.has(player_pos):
			_show_evacuation_confirm()
		return

	# 检查目标格子是否存在
	if not _has_cell_at(clicked_pos):
		_show_message("该区域已不存在！")
		return

	# 只能移动到相邻格子
	if not _is_adjacent(player_pos, clicked_pos):
		return

	# 移动到目标格子
	_move_to_cell(clicked_pos)

func _is_adjacent(pos1: Vector2i, pos2: Vector2i) -> bool:
	var dx = abs(pos1.x - pos2.x)
	var dy = abs(pos1.y - pos2.y)
	return (dx <= 1 and dy <= 1) and not (dx == 0 and dy == 0)

func _move_to_cell(target_pos: Vector2i):
	"""移动玩家到目标格子（重构版）"""
	var cell = _get_cell_at(target_pos)
	if not cell:
		print("错误：目标格子不存在！")
		return

	# 记录是否是首次探索（用于决定是否收集资源）
	var is_first_exploration = not cell.explored

	# 如果是未探索的格子，先探索
	if not cell.explored:
		cell.explored = true
		explored_count += 1

		# 检查是否达到探索度阈值，显示撤离点（探索40%以上）
		var total_cells = active_cells.size() # 使用当前剩余格子数量
		var explore_threshold = int(total_cells * 0.4)
		if explored_count >= explore_threshold and not show_evacuation:
			show_evacuation = true
			_show_message("探索进度已达 " + str(int(explored_count * 100.0 / total_cells)) + "%\n撤离点已显示在地图上！")
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
	session.set_meta("battle_player_souls", soul_loadout) # 使用带入地图的魂印配置
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
	var soul_count = 1 + randi() % 3 # 1-3个魂印
	
	# 根据敌人力量决定魂印品质
	var quality = 0
	if enemy_power >= 40:
		quality = 3 + randi() % 2 # 史诗或传说
	elif enemy_power >= 30:
		quality = 2 + randi() % 2 # 稀有或史诗
	elif enemy_power >= 20:
		quality = 1 + randi() % 2 # 非凡或稀有
	else:
		quality = randi() % 2 # 普通或非凡
	
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
	"""处理战斗结果（重构版）"""
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
		var cell = _get_cell_at(player_pos)
		if cell:
			cell.has_enemy = false # 敌人已被击败

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
		["soul_basic_1", "soul_basic_2"], # 0: 普通
		["soul_forest", "soul_wind"], # 1: 非凡
		["soul_thunder", "soul_flame"], # 2: 稀有
		["soul_dragon", "soul_shadow"], # 3: 史诗
		["soul_phoenix", "soul_celestial", "soul_titan"], # 4: 传说
		["soul_chaos", "soul_eternity", "soul_god"] # 5: 神话
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
	"""更新信息显示（重构版 - 使用动态格子数量）"""
	player_info_label.text = "位置: (" + str(player_pos.x) + "," + str(player_pos.y) + ") | HP: " + str(player_hp) + "/" + str(max_hp)
	power_label.text = "力量: " + str(_calculate_total_power())

	# 更新探索进度（使用当前剩余格子数量）
	var total_cells = active_cells.size()
	if total_cells > 0:
		var exploration_percent = int(explored_count * 100.0 / total_cells)
		exploration_label.text = "探索: " + str(exploration_percent) + "% (" + str(explored_count) + "/" + str(total_cells) + ")"
	else:
		exploration_label.text = "探索: 100% (完成)"

func _update_evacuation_status():
	"""更新撤离点状态显示"""
	if show_evacuation:
		evacuation_label.text = "⚠ 撤离点 ⚠"
		evacuation_label.add_theme_font_size_override("font_size", 15)
		evacuation_label.add_theme_color_override("font_color", Color(1.0, 1.0, 0.0)) # 黄色

		# 添加背景高亮
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.0, 0.5, 0.0, 0.8) # 深绿色背景
		style_box.set_corner_radius_all(5)
		evacuation_label.add_theme_stylebox_override("normal", style_box)

		# 开始闪烁动画
		_start_evacuation_blink()
	else:
		evacuation_label.text = "撤离: 未出现"
		evacuation_label.add_theme_font_size_override("font_size", 13)
		evacuation_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7)) # 灰色
		evacuation_label.remove_theme_stylebox_override("normal")

func _start_evacuation_blink():
	"""撤离点标签闪烁动画"""
	var tween = create_tween()
	tween.set_loops() # 无限循环

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

func _serialize_grid_data() -> Dictionary:
	"""序列化网格数据（重构版 - 保存动态格子列表）"""
	var serialized_data = {
		"current_grid_width": current_grid_width,
		"current_grid_height": current_grid_height,
		"next_cell_id": next_cell_id,
		"cells": []
	}

	# 序列化每个活跃格子
	for cell in active_cells:
		var cell_data = {
			"cell_id": cell.cell_id,
			"quality": cell.quality,
			"resource_count": cell.resource_count,
			"explored": cell.explored,
			"has_enemy": cell.has_enemy,
			"enemy_data": cell.enemy_data,
			"logic_pos": {"x": cell.logic_pos.x, "y": cell.logic_pos.y},
			"visual_position": {"x": cell.visual_position.x, "y": cell.visual_position.y}
		}
		serialized_data["cells"].append(cell_data)

	return serialized_data

func _restore_grid_data(serialized_data):
	"""恢复网格数据（重构版 - 从动态格子列表恢复）"""
	# 兼容性检查：如果是旧版Array格式，转换为新格式
	if serialized_data is Array:
		print("检测到旧版地图数据格式，跳过恢复")
		_initialize_grid() # 重新初始化
		return

	if not serialized_data is Dictionary:
		print("错误：无效的序列化数据格式")
		_initialize_grid()
		return

	# 清空当前数据
	active_cells.clear()
	cell_lookup.clear()

	# 恢复网格尺寸
	current_grid_width = serialized_data.get("current_grid_width", GRID_SIZE)
	current_grid_height = serialized_data.get("current_grid_height", GRID_SIZE)
	next_cell_id = serialized_data.get("next_cell_id", 0)

	# 恢复格子数据
	var cells_data = serialized_data.get("cells", [])
	for cell_data in cells_data:
		var cell = GridCell.new()
		cell.cell_id = cell_data.get("cell_id", 0)
		cell.quality = cell_data.get("quality", 0)
		cell.resource_count = cell_data.get("resource_count", 1)
		cell.explored = cell_data.get("explored", false)
		cell.has_enemy = cell_data.get("has_enemy", false)
		cell.enemy_data = cell_data.get("enemy_data", {})

		# 恢复坐标
		var logic_pos_data = cell_data.get("logic_pos", {"x": 0, "y": 0})
		cell.logic_pos = Vector2i(logic_pos_data.get("x", 0), logic_pos_data.get("y", 0))

		var visual_pos_data = cell_data.get("visual_position", null)
		if visual_pos_data:
			cell.visual_position = Vector2(visual_pos_data.get("x", 0), visual_pos_data.get("y", 0))
		else:
			cell.visual_position = Vector2(cell.logic_pos.x, cell.logic_pos.y)

		# 添加到活跃列表
		active_cells.append(cell)
		cell_lookup[cell.logic_pos] = cell

	print("恢复网格完成：", active_cells.size(), "个格子，网格尺寸：", current_grid_width, "×", current_grid_height)

# ========== 坍塌动画系统 ==========

func _start_collapse_and_reorganize(cells: Array[GridCell]):
	"""启动坍塌和重组动画序列（重构版）"""
	if collapse_animation_running:
		return

	collapse_animation_running = true

	# 播放屏幕震动
	_camera_shake(cells.size() * 0.5)

	# 阶段1: 预警动画（闪烁抖动）
	await _play_warning_animation_v2(cells)

	# 阶段2: 破碎动画
	await _play_crack_animation_v2(cells)

	# 阶段3: 下落动画
	await _play_fall_animation_v2(cells)

	# 阶段4: 从活跃列表中移除坍塌的格子
	_remove_collapsed_cells(cells)

	# 阶段5: 重组剩余格子（向中心紧凑）
	await _reorganize_grid()

	collapse_animation_running = false

	# 显示提示信息
	var remaining = active_cells.size()
	_show_message("地形坍塌蔓延中！第 " + str(collapse_ring_index + 1) + " 波坍塌\n剩余 " + str(remaining) + " 个格子")

	grid_container.queue_redraw()

	# 检查玩家是否站在已移除的格子上（理论上不会发生，但保险起见）
	if not _has_cell_at(player_pos):
		print("警告：玩家位置已坍塌！")
		await _game_over()

func _remove_collapsed_cells(cells: Array[GridCell]):
	"""从活跃列表中移除坍塌的格子"""
	for cell in cells:
		# 从查找表中移除
		cell_lookup.erase(cell.logic_pos)
		# 从活跃列表中移除
		active_cells.erase(cell)

	print("移除了 ", cells.size(), " 个格子，剩余 ", active_cells.size(), " 个格子")

func _reorganize_grid():
	"""重组网格 - 将剩余格子重新排列成紧凑的正方形布局"""
	if active_cells.is_empty():
		print("没有剩余格子，跳过重组")
		return

	# 1. 计算新的网格尺寸（保持正方形，积极缩小）
	var cell_count = active_cells.size()
	
	# 策略：只要剩余格子能放入更小的正方形（允许一定空位），就缩小
	# 检查能否放入(当前尺寸-1)的正方形
	var new_size = current_grid_width
	
	# 持续尝试缩小，直到不能再缩小为止
	while new_size > 1:
		var smaller_size = new_size - 1
		var smaller_capacity = smaller_size * smaller_size
		
		# 如果更小的正方形能容纳所有格子，就缩小
		if smaller_capacity >= cell_count:
			new_size = smaller_size
		else:
			break
	
	# 确保是正方形
	var new_width = new_size
	var new_height = new_size
	
	var old_capacity = current_grid_width * current_grid_height
	var new_capacity = new_width * new_height
	var fill_ratio = float(cell_count) / float(new_capacity) if new_capacity > 0 else 0.0

	print("重组网格：从 ", current_grid_width, "×", current_grid_height, " (", old_capacity, "格) -> ", new_width, "×", new_height, " (", new_capacity, "格)，剩余", cell_count, "格，填充率", int(fill_ratio * 100), "%")

	current_grid_width = new_width
	current_grid_height = new_height

	# 2. 为每个格子分配新的逻辑坐标（螺旋排列，从中心向外）
	var new_layout = _calculate_spiral_layout(active_cells.size(), new_width, new_height)

	# 3. 清空查找表，准备重建
	cell_lookup.clear()

	# 4. 更新每个格子的目标位置
	var index = 0
	for cell in active_cells:
		var new_pos = new_layout[index]

		# 更新逻辑坐标
		cell.logic_pos = new_pos
		cell.is_moving = true

		# 重建查找表
		cell_lookup[new_pos] = cell

		index += 1

	# 5. 播放重组动画（平滑移动到新位置）
	await _play_reorganize_animation()

	# 6. 清理移动状态
	for cell in active_cells:
		cell.is_moving = false

	print("重组完成")

func _calculate_spiral_layout(count: int, width: int, height: int) -> Array[Vector2i]:
	"""计算螺旋布局的坐标序列（从中心向外）"""
	var layout: Array[Vector2i] = []

	# 简化版：从左上到右下，按行填充（后续可改进为螺旋）
	for y in range(height):
		for x in range(width):
			if layout.size() >= count:
				break
			layout.append(Vector2i(x, y))
		if layout.size() >= count:
			break

	return layout

func _play_reorganize_animation():
	"""播放重组动画 - 格子平滑移动到新位置"""
	var duration = 1.2 # 重组动画持续1.2秒
	var tween = create_tween()
	tween.set_parallel(true) # 所有格子同时移动

	# 轻微震动效果
	_camera_shake(3.0, duration * 0.5)

	# 为每个格子创建移动动画
	for cell in active_cells:
		if cell.is_moving:
			# 使用 ease_in_out 缓动
			tween.tween_property(
				cell,
				"visual_position",
				Vector2(cell.logic_pos.x, cell.logic_pos.y),
				duration
			).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	# 动画期间持续重绘
	var redraw_finished = false
	var redraw_task = func():
		while not redraw_finished:
			grid_container.queue_redraw()
			await get_tree().create_timer(0.05).timeout

	redraw_task.call()

	# 等待动画完成
	await tween.finished

	# 停止重绘循环
	redraw_finished = true

	# 最终刷新
	grid_container.queue_redraw()

func _play_warning_animation_v2(cells: Array[GridCell]):
	"""预警动画 - 格子闪烁和轻微抖动（重构版）"""
	var duration = 1.5 # 预警持续1.5秒

	# 标记格子进入坍塌状态
	for cell in cells:
		cell.collapsing = true

	# 轻微震动
	_camera_shake(2.0, 0.3)

	# 闪烁循环
	var elapsed = 0.0
	while elapsed < duration:
		grid_container.queue_redraw()
		await get_tree().create_timer(0.1).timeout
		elapsed += 0.1

func _play_crack_animation_v2(cells: Array[GridCell]):
	"""破碎动画 - 裂纹扩散（重构版）"""
	var duration = 1.0 # 破碎持续1秒
	var elapsed = 0.0
	var delta_time = 0.05

	# 播放破碎音效
	_play_collapse_sound()

	# 中等强度震动
	_camera_shake(5.0, 0.5)

	while elapsed < duration:
		var progress = elapsed / duration

		# 更新所有坍塌格子的破碎进度
		for cell in cells:
			cell.collapse_progress = progress

		grid_container.queue_redraw()

		await get_tree().create_timer(delta_time).timeout
		elapsed += delta_time

	# 确保进度达到100%
	for cell in cells:
		cell.collapse_progress = 1.0

	grid_container.queue_redraw()

func _play_fall_animation_v2(cells: Array[GridCell]):
	"""下落动画 - 碎片向下掉落（重构版）"""
	var duration = 0.8 # 下落持续0.8秒
	var elapsed = 0.0
	var delta_time = 0.05

	# 播放下落音效
	_play_fall_sound()

	# 轻微震动
	_camera_shake(3.0, 0.3)

	while elapsed < duration:
		var progress = elapsed / duration

		# 更新下落进度
		for cell in cells:
			cell.fall_progress = ease(progress, -2.0) # 使用ease实现加速下落

		grid_container.queue_redraw()

		await get_tree().create_timer(delta_time).timeout
		elapsed += delta_time

func _camera_shake(intensity: float, duration: float = 0.5):
	"""屏幕震动效果"""
	if not game_camera:
		return

	var shake_tween = create_tween()
	shake_tween.set_parallel(true)

	var shake_count = int(duration / 0.05) # 每0.05秒一次震动

	for i in range(shake_count):
		var offset_x = randf_range(-intensity, intensity)
		var offset_y = randf_range(-intensity, intensity)

		shake_tween.tween_property(
			game_camera,
			"offset",
			Vector2(offset_x, offset_y),
			0.05
		).set_delay(i * 0.05)

	# 最后回到原位
	shake_tween.tween_property(
		game_camera,
		"offset",
		Vector2.ZERO,
		0.1
	).set_delay(duration)

func _play_collapse_sound():
	"""播放破碎音效"""
	if not collapse_sound_player:
		return

	# 这里应该加载实际的音效文件
	# collapse_sound_player.stream = load("res://assets/sounds/collapse.ogg")
	# collapse_sound_player.play()

	# 临时方案：使用AudioStreamGenerator生成简单音效
	print("播放坍塌音效（需要实际音频文件）")

func _play_fall_sound():
	"""播放下落音效"""
	if not fall_sound_player:
		return

	# 这里应该加载实际的音效文件
	# fall_sound_player.stream = load("res://assets/sounds/fall.ogg")
	# fall_sound_player.play()

	# 临时方案
	print("播放下落音效（需要实际音频文件）")

func _draw_collapsing_cell(rect: Rect2, center: Vector2, cell: GridCell):
	"""绘制正在坍塌的格子特效"""
	var base_color = _get_cell_color(cell)

	# 预警阶段 - 闪烁效果
	if cell.collapse_progress == 0.0:
		var time = Time.get_ticks_msec() / 1000.0
		var flash = abs(sin(time * 10.0)) # 快速闪烁
		var warning_color = Color(1.0, 0.3, 0.0, 0.6 + flash * 0.4)
		grid_container.draw_rect(rect, warning_color, true)

		# 抖动效果（通过修改rect位置）
		var shake_offset = Vector2(
			randf_range(-2, 2),
			randf_range(-2, 2)
		)
		var shaky_rect = Rect2(rect.position + shake_offset, rect.size)
		grid_container.draw_rect(shaky_rect, base_color, false, 2.0)
		return

	# 破碎阶段 - 显示裂纹
	if cell.collapse_progress > 0.0 and cell.fall_progress == 0.0:
		# 绘制基础格子
		grid_container.draw_rect(rect, base_color, true)

		# 绘制裂纹效果（用多条线模拟）
		var crack_color = Color(0.3, 0.0, 0.0, cell.collapse_progress)
		var num_cracks = int(cell.collapse_progress * 8) + 3

		for i in range(num_cracks):
			var angle = (i * TAU / num_cracks) + cell.collapse_progress * 2.0
			var start_dist = rect.size.x * 0.1
			var end_dist = rect.size.x * 0.5 * cell.collapse_progress

			var start = center + Vector2(cos(angle), sin(angle)) * start_dist
			var end = center + Vector2(cos(angle), sin(angle)) * end_dist

			grid_container.draw_line(start, end, crack_color, 2.0 + cell.collapse_progress * 3.0)

		# 边缘高光
		if cell.collapse_progress > 0.3:
			var glow_color = Color(1.0, 0.5, 0.2, (cell.collapse_progress - 0.3) * 2.0)
			grid_container.draw_rect(rect, glow_color, false, 3.0)

	# 下落阶段 - 碎片向下移动并淡出
	if cell.fall_progress > 0.0:
		# 计算下落偏移（增大偏移量使效果更明显）
		var fall_offset_y = cell.fall_progress * rect.size.y * 4.0 # 增加到4倍，使下落更明显

		# 移动后的rect
		var falling_rect = Rect2(
			rect.position + Vector2(0, fall_offset_y),
			rect.size
		)

		# 透明度衰减（更快淡出）
		var alpha = 1.0 - (cell.fall_progress * cell.fall_progress) # 平方衰减，下落时快速淡出
		var falling_color = Color(base_color.r, base_color.g, base_color.b, base_color.a * alpha)

		# 绘制整体格子（半透明）
		grid_container.draw_rect(falling_rect, falling_color, true)

		# 绘制碎片效果 - 分裂成多个小块
		var fragment_count = 4
		var fragment_size = rect.size / 2.0

		for fx in range(2):
			for fy in range(2):
				var fragment_offset = Vector2(fx * fragment_size.x, fy * fragment_size.y)
				# 每个碎片有不同的下落速度和旋转
				var fragment_fall = fall_offset_y * (1.0 + randf_range(-0.2, 0.2))
				var fragment_drift = Vector2(
					randf_range(-10, 10) * cell.fall_progress,
					fragment_fall
				)

				var fragment_rect = Rect2(
					falling_rect.position + fragment_offset + fragment_drift,
					fragment_size * 0.9 # 稍微缩小，产生裂缝
				)

				# 碎片颜色随机暗化
				var fragment_color = Color(
					falling_color.r * randf_range(0.7, 1.0),
					falling_color.g * randf_range(0.7, 1.0),
					falling_color.b * randf_range(0.7, 1.0),
					falling_color.a * randf_range(0.5, 1.0)
				)

				grid_container.draw_rect(fragment_rect, fragment_color, true)

				# 碎片边缘
				grid_container.draw_rect(fragment_rect, Color(0.3, 0.0, 0.0, alpha * 0.5), false, 1.0)
		
		return # 下落阶段完成，不需要绘制其他内容

func _play_squeeze_animation():
	"""地形挤压动画 - 剩余格子向中心聚拢"""

	# 1. 计算所有未坍塌格子的重心（几何中心）
	var total_pos = Vector2.ZERO
	var active_count = 0

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if not grid_data[y][x].collapsed:
				total_pos += Vector2(x, y)
				active_count += 1

	# 如果没有未坍塌的格子，跳过动画
	if active_count == 0:
		return

	# 计算重心坐标
	var center_of_mass = total_pos / active_count

	# 2. 为每个未坍塌格子计算目标位置（向重心移动）
	var target_positions: Dictionary = {} # {Vector2i: Vector2}

	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell = grid_data[y][x]
			if not cell.collapsed:
				var current_pos = Vector2(x, y)
				var direction = (center_of_mass - current_pos).normalized()

				# 移动距离与离重心的距离成正比，但有最大限制
				var distance = current_pos.distance_to(center_of_mass)
				var move_distance = min(distance * 0.15, 1.5) # 最多移动1.5格

				# 计算目标位置
				var target_pos = current_pos + direction * move_distance
				target_positions[Vector2i(x, y)] = target_pos

				# 标记正在挤压
				cell.is_squeezing = true

	# 3. 使用 Tween 动画平滑移动所有格子
	var squeeze_duration = 1.5 # 挤压动画持续1.5秒
	var tween = create_tween()
	tween.set_parallel(true) # 所有格子同时移动

	# 轻微震动效果
	_camera_shake(4.0, squeeze_duration * 0.5)

	# 为每个未坍塌格子创建移动动画
	for pos in target_positions.keys():
		var cell = grid_data[pos.y][pos.x]
		var target = target_positions[pos]

		# 使用 ease_out_cubic 缓动函数，先快后慢
		tween.tween_property(
			cell,
			"visual_position",
			target,
			squeeze_duration
		).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# 4. 启动绘制更新循环（与 tween 并行）
	var redraw_finished = false
	var redraw_task = func():
		while not redraw_finished:
			grid_container.queue_redraw()
			await get_tree().create_timer(0.05).timeout

	# 异步启动重绘任务
	redraw_task.call()

	# 等待挤压动画完成
	await tween.finished

	# 停止重绘循环
	redraw_finished = true

	# 5. 清理挤压状态
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell = grid_data[y][x]
			cell.is_squeezing = false

	# 最终刷新
	grid_container.queue_redraw()
