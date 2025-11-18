extends Control

# 管道连接战斗准备场景

const GRID_SIZE = 5 # 5×5 网格
const CELL_SIZE = 80 # 每个格子的大小（像素）
const START_POS = Vector2i(2, 0) # 起点位置
const END_POS = Vector2i(2, 4) # 终点位置
const DEBUG_ENERGY_DRAW = false

# 引用节点
@onready var grid_container = $CenterContainer/MainPanel/VBoxContainer/GridContainer
var energy_overlay: Control = null # 能量流覆盖层（动态创建）
@onready var timer_label = $CenterContainer/MainPanel/VBoxContainer/TopBar/TimerLabel
@onready var power_label = $CenterContainer/MainPanel/VBoxContainer/TopBar/PowerLabel
var power_bar: ProgressBar = null # 能量条（动态创建）
@onready var rotate_button = $CenterContainer/MainPanel/VBoxContainer/BottomBar/RotateButton
@onready var start_battle_button = $CenterContainer/MainPanel/VBoxContainer/BottomBar/StartBattleButton

# 战斗数据
var enemy_data: Dictionary # 敌人数据
var player_souls: Array # 玩家选择的魂印列表

# 管道网格数据
var pipe_grid: Array = [] # 5×5 网格，存储魂印
var selected_soul_index: int = -1 # 当前选中的魂印索引
var connected_souls: Array = [] # 连通的魂印列表
var connected_path: Array = [] # 连通的路径（包含位置信息）用于绘制能量流
var connected_flow_segments: Array = [] # 能量流片段，包含起点、终点和方向信息
var total_power: int = 0 # 连通的总力量
var max_power: int = 0 # 所有魂印的总力量（用于能量条最大值）
var end_point_activated: bool = false # 终点是否被激活

# 拖拽相关
var dragging_soul_index: int = -1 # 正在拖拽的魂印索引
var drag_start_pos: Vector2i = Vector2i(-1, -1) # 拖拽起始位置
var drag_hover_pos: Vector2i = Vector2i(-1, -1) # 鼠标悬停的格子位置（用于高亮）

# 旋转动画锁定
var is_rotating: bool = false # 是否正在播放旋转动画

# 倒计时
var time_remaining: float = 30.0
var timer_active: bool = false
# var timer_active: bool = true

# 能量流动画
var energy_flow_time: float = 0.0 # 能量流动画时间

func _ready():
	# 应用像素风格
	_apply_pixel_style()

	# 初始化网格（如果还没有初始化）
	if pipe_grid.is_empty():
		_initialize_grid()

	# 创建能量流覆盖层（如果不存在）
	_create_energy_overlay()

	# 初始化能量条
	_initialize_power_bar()

	_update_ui()

# ========== 像素风格应用 ==========

func _apply_pixel_style():
	"""应用像素艺术风格到管道战斗场景"""
	if not has_node("/root/PixelStyleManager"):
		push_warning("PixelStyleManager 未加载，跳过像素风格应用")
		return

	var pixel_style = get_node("/root/PixelStyleManager")

	# 应用主面板像素风格
	var main_panel = $CenterContainer/MainPanel
	pixel_style.apply_pixel_panel_style(main_panel, "DARK_GREY")

	# 应用标签像素风格
	pixel_style.apply_pixel_label_style(timer_label, "RED", true, 20)
	pixel_style.apply_pixel_label_style(power_label, "CYAN", true, 20)

	# 应用按钮像素风格
	pixel_style.apply_pixel_button_style(rotate_button, "PURPLE", 16)
	pixel_style.apply_pixel_button_style(start_battle_button, "GREEN", 16)

func _initialize_power_bar():
	"""初始化能量条"""
	if not power_bar:
		# 如果场景中没有能量条，创建一个
		var vbox = $CenterContainer/MainPanel/VBoxContainer/TopBar
		if not vbox.has_node("PowerBar"):
			var bar = ProgressBar.new()
			bar.name = "PowerBar"
			bar.custom_minimum_size = Vector2(200, 20)
			bar.max_value = 100
			bar.value = 0
			bar.show_percentage = false
			# 设置样式
			var style_bg = StyleBoxFlat.new()
			style_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
			bar.add_theme_stylebox_override("background", style_bg)
			var style_fill = StyleBoxFlat.new()
			style_fill.bg_color = Color(0.0, 1.0, 1.0, 0.8) # 青色能量条
			bar.add_theme_stylebox_override("fill", style_fill)
			vbox.add_child(bar)
			power_bar = bar
	
	# 连接信号
	rotate_button.pressed.connect(_on_rotate_button_pressed)
	start_battle_button.pressed.connect(_on_start_battle_button_pressed)
	
	# 如果没有数据（单独运行场景），生成测试数据
	if player_souls.is_empty():
		_generate_test_data()
	else:
		# 如果有数据（从外部调用initialize），确保网格已更新
		_place_souls_on_grid()
		_check_connectivity()

func _create_energy_overlay():
	"""创建能量流覆盖层"""
	var main_panel = $CenterContainer/MainPanel
	if not main_panel.has_node("EnergyOverlay"):
		var overlay = Control.new()
		overlay.name = "EnergyOverlay"
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = 100
		# 覆盖整个面板，后续绘制时再根据 grid_offset 限制范围
		overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		overlay.offset_left = 0
		overlay.offset_top = 0
		overlay.offset_right = 0
		overlay.offset_bottom = 0
		overlay.draw.connect(_on_energy_overlay_draw)
		main_panel.add_child(overlay)
		main_panel.move_child(overlay, main_panel.get_child_count() - 1)
		energy_overlay = overlay
		print("能量流覆盖层已创建并绑定到 MainPanel")
	else:
		energy_overlay = main_panel.get_node("EnergyOverlay")
		print("能量流覆盖层已存在")

func _process(delta):
	if timer_active:
		time_remaining -= delta
		if time_remaining <= 0:
			time_remaining = 0
			timer_active = false
			_on_time_up()
		_update_timer_display()
	
	# 更新能量流动画（始终更新，即使没有连接）
	energy_flow_time += delta * 3.0 # 流动速度（加快）
	if energy_flow_time > 100.0: # 循环动画（增大范围）
		energy_flow_time = 0.0
	# 如果有能量流，触发覆盖层重绘
	if connected_flow_segments.size() > 0 and energy_overlay:
		energy_overlay.queue_redraw()
	
	# 更新管道内部能量条的动画
	if connected_souls.size() > 0:
		_update_all_energy_bars()

func _input(event: InputEvent):
	"""处理全局输入事件（用于拖拽和点击）"""
	if event is InputEventMouseButton:
		var mb_event = event as InputEventMouseButton
		
		# 计算鼠标在网格中的位置
		var mouse_pos = get_global_mouse_position()
		var grid_pos = _screen_to_grid_pos(mouse_pos)
		
		if grid_pos.x < 0 or grid_pos.y < 0:
			# 鼠标在网格外
			if mb_event.button_index == MOUSE_BUTTON_LEFT and not mb_event.pressed:
				# 鼠标释放 - 如果在拖拽状态，取消拖拽
				if dragging_soul_index >= 0:
					print("鼠标在网格外释放，取消拖拽")
					dragging_soul_index = -1
					drag_start_pos = Vector2i(-1, -1)
					drag_hover_pos = Vector2i(-1, -1)
					_update_grid_display()
			return
		
		# 鼠标在网格内
		if mb_event.button_index == MOUSE_BUTTON_RIGHT and mb_event.pressed:
			# 右键点击 - 直接旋转
			get_viewport().set_input_as_handled()
			_on_cell_right_clicked(grid_pos.x, grid_pos.y)
		elif mb_event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			if mb_event.pressed:
				# 鼠标按下 - 开始拖拽
				print("全局输入：左键按下格子 (%d, %d)" % [grid_pos.x, grid_pos.y])
				_on_cell_mouse_down(grid_pos.x, grid_pos.y)
			else:
				# 鼠标释放 - 结束拖拽
				if dragging_soul_index >= 0:
					print("全局输入：左键释放格子 (%d, %d)，dragging_soul_index=%d" % [grid_pos.x, grid_pos.y, dragging_soul_index])
					_on_cell_mouse_up(grid_pos.x, grid_pos.y)
				else:
					print("全局输入：左键释放格子 (%d, %d)，但没有拖拽中的魂印" % [grid_pos.x, grid_pos.y])
	elif event is InputEventMouseMotion:
		# 鼠标移动 - 更新拖拽预览
		if dragging_soul_index >= 0:
			var mouse_pos = get_global_mouse_position()
			var grid_pos = _screen_to_grid_pos(mouse_pos)
			if grid_pos.x >= 0:
				_update_drag_preview(mouse_pos)

func _screen_to_grid_pos(screen_pos: Vector2) -> Vector2i:
	"""将屏幕坐标转换为网格坐标"""
	if not grid_container:
		return Vector2i(-1, -1)
	
	# 遍历 GridContainer 的所有子节点（cell），检查鼠标位置
	for child in grid_container.get_children():
		if child is Control:
			var cell = child as Control
			var cell_global_rect = Rect2(cell.get_global_position(), cell.size)
			
			# 检查鼠标是否在这个 cell 内
			if cell_global_rect.has_point(screen_pos):
				# 从 meta 数据中获取网格坐标
				if cell.has_meta("grid_x") and cell.has_meta("grid_y"):
					var grid_x = cell.get_meta("grid_x")
					var grid_y = cell.get_meta("grid_y")
					return Vector2i(grid_x, grid_y)
	
	# 如果没找到，使用旧方法作为备用
	var grid_global_pos = grid_container.get_global_position()
	var grid_size = grid_container.size
	var local_pos = screen_pos - grid_global_pos
	
	if local_pos.x < 0 or local_pos.x >= grid_size.x or local_pos.y < 0 or local_pos.y >= grid_size.y:
		return Vector2i(-1, -1)
	
	var grid_x = int(local_pos.x / CELL_SIZE)
	var grid_y = int(local_pos.y / CELL_SIZE)
	
	if grid_x < 0 or grid_x >= GRID_SIZE or grid_y < 0 or grid_y >= GRID_SIZE:
		return Vector2i(-1, -1)
	
	return Vector2i(grid_x, grid_y)

func initialize(souls: Array, enemy: Dictionary, enable_timer: bool = true):
	"""初始化管道连接场景"""
	player_souls = souls
	enemy_data = enemy
	
	# 确保网格已初始化
	_initialize_grid()
	
	# 将魂印初始化到网格中
	_place_souls_on_grid()
	
	# 启动倒计时（可选）
	if enable_timer:
		timer_active = true
		time_remaining = 30.0
	else:
		timer_active = false
		timer_label.text = "调试模式"
	
	# 检测连通性
	_check_connectivity()
	
	# 确保UI已更新
	_update_ui()

func _initialize_grid():
	"""初始化5×5网格"""
	pipe_grid.clear()
	for y in range(GRID_SIZE):
		var row = []
		for x in range(GRID_SIZE):
			row.append(null)
		pipe_grid.append(row)

func _place_souls_on_grid():
	"""将魂印放置到网格中（自动布局）"""
	# 如果魂印已经有 grid_position，使用它；否则使用默认布局
	var soul_index = 0
	for soul_item in player_souls:
		var soul = soul_item.soul_print
		var pos = soul_item.grid_position # 从 InventoryItem 获取位置
		
		# 如果魂印已经有位置（从 InventoryItem 的 grid_position 获取）
		if pos.x >= 0 and pos.y >= 0:
			# 检查位置是否有效且不是起点/终点
			if pos != START_POS and pos != END_POS:
				if pos.x >= 0 and pos.x < GRID_SIZE and pos.y >= 0 and pos.y < GRID_SIZE:
					soul.grid_pos = pos
					soul.rotation = soul_item.rotation_state # 使用 InventoryItem 的旋转
					pipe_grid[pos.y][pos.x] = soul_index
					print("放置魂印 [%d] %s 到 (%d, %d), 旋转:%d" % [soul_index, soul.name, pos.x, pos.y, soul.rotation])
		else:
			# 默认布局：从上到下、从左到右放置
			var placed = false
			for y in range(1, GRID_SIZE - 1): # 跳过起点和终点行
				for x in range(GRID_SIZE):
					if pipe_grid[y][x] == null:
						var default_pos = Vector2i(x, y)
						soul.grid_pos = default_pos
						soul.rotation = soul_item.rotation_state
						soul_item.grid_position = default_pos # 同步更新 InventoryItem 的位置
						pipe_grid[y][x] = soul_index
						placed = true
						print("默认放置魂印 [%d] %s 到 (%d, %d)" % [soul_index, soul.name, x, y])
						break
				if placed:
					break
		
		soul_index += 1
	
	_update_grid_display()

func _update_grid_display():
	"""更新网格显示"""
	# 清空现有显示
	for child in grid_container.get_children():
		child.queue_free()
	
	# 绘制5×5网格
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell = _create_cell(x, y)
			grid_container.add_child(cell)
	
	# 更新能量流覆盖层
	if energy_overlay:
		energy_overlay.queue_redraw()

func _update_single_cell(x: int, y: int):
	"""只更新单个格子的纹理（旋转后使用）"""
	var cell_index = y * GRID_SIZE + x
	if cell_index >= grid_container.get_child_count():
		return
	
	var cell = grid_container.get_child(cell_index) as Control
	if not cell:
		return
	
	# 找到格子中的 TextureRect（Panel -> MarginContainer -> TextureRect）
	var texture_rect: TextureRect = null
	for child in cell.get_children():
		if child is Panel:
			for grand_child in child.get_children():
				if grand_child is MarginContainer:
					for great_grand_child in grand_child.get_children():
						if great_grand_child is TextureRect:
							texture_rect = great_grand_child
							break
				if texture_rect:
					break
			if texture_rect:
				break
	
	if not texture_rect:
		return
	
	# 获取当前格子的魂印
	var soul_index = pipe_grid[y][x]
	if soul_index != null and soul_index >= 0 and soul_index < player_souls.size():
		var soul_item = player_souls[soul_index]
		var soul = soul_item.soul_print
		
		# 更新纹理路径（根据新的旋转角度）
		var texture_path = SoulPrintSystem.get_pipe_texture_path(soul.pipe_shape_type, soul.rotation)
		texture_rect.texture = load(texture_path)

func _update_all_cells_color():
	"""只更新所有格子的颜色（根据连通状态）"""
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var cell_index = y * GRID_SIZE + x
			if cell_index >= grid_container.get_child_count():
				continue
			
			var cell = grid_container.get_child(cell_index) as Control
			if not cell:
				continue
			
			# 更新能量条
			var energy_bar = cell.get_node_or_null("EnergyBarContainer")
			if energy_bar:
				energy_bar.queue_redraw()
			
			# 找到格子中的组件
			var texture_rect: TextureRect = null
			var panel: Panel = null
			for child in cell.get_children():
				if child is Panel:
					panel = child
					for grand_child in child.get_children():
						if grand_child is MarginContainer:
							for great_grand_child in grand_child.get_children():
								if great_grand_child is TextureRect:
									texture_rect = great_grand_child
									break
						if texture_rect:
							break
					if texture_rect:
						break
			
			if not texture_rect or not panel:
				continue
			
			# 更新颜色和边框
			var soul_index = pipe_grid[y][x]
			if soul_index != null and soul_index >= 0 and soul_index < player_souls.size():
				var soul_item = player_souls[soul_index]
				var soul = soul_item.soul_print
				var quality_color = _get_quality_color(soul.quality)
				
				# 根据连通状态和拖拽状态设置颜色
				if soul_index == dragging_soul_index:
					# 拖拽中的魂印：半透明
					if soul_index in connected_souls:
						texture_rect.modulate = Color(quality_color.r, quality_color.g, quality_color.b, 0.5)
					else:
						texture_rect.modulate = Color(0.5, 0.5, 0.5, 0.5)
				elif soul_index in connected_souls:
					# 激活状态：增加亮度
					texture_rect.modulate = quality_color.lightened(0.3)
				else:
					texture_rect.modulate = Color(0.5, 0.5, 0.5)
				
				# 更新边框样式（跳过选中和拖拽的格子）
				if soul_index != selected_soul_index and soul_index != dragging_soul_index:
					var style = panel.get_theme_stylebox("panel") as StyleBoxFlat
					if style:
						if soul_index in connected_souls:
							# 已连通：应用明亮的品质边框
							_apply_quality_border_style(style, quality_color, soul.quality, true)
						else:
							# 未连通：应用暗淡的品质边框
							var dim_color = quality_color * 0.5
							_apply_quality_border_style(style, dim_color, soul.quality, false)

func _play_rotation_animation(x: int, y: int):
	"""播放旋转动画"""
	var cell_index = y * GRID_SIZE + x
	if cell_index >= grid_container.get_child_count():
		return
	
	var cell = grid_container.get_child(cell_index) as Control
	if not cell:
		return
	
	# 找到管道图标 TextureRect（Panel -> MarginContainer -> TextureRect）
	var texture_rect: TextureRect = null
	for child in cell.get_children():
		if child is Panel:
			for grand_child in child.get_children():
				if grand_child is MarginContainer:
					for great_grand_child in grand_child.get_children():
						if great_grand_child is TextureRect:
							texture_rect = great_grand_child
							break
				if texture_rect:
					break
			if texture_rect:
				break
	
	if not texture_rect:
		return
	
	# 创建旋转动画（顺时针90度）
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC) # 使用三次曲线，比BACK更平滑
	
	# 从0度旋转到90度（弧度制）
	texture_rect.rotation = 0
	tween.tween_property(texture_rect, "rotation", deg_to_rad(90), 0.2) # 缩短到0.2秒
	
	await tween.finished
	
	# 动画结束后重置旋转角度（因为图标已经更新了）
	texture_rect.rotation = 0

func _create_cell(x: int, y: int) -> Control:
	"""创建单个格子"""
	var cell = Control.new()
	cell.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	cell.clip_contents = true # 启用裁剪
	
	# 添加背景面板
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE # 让鼠标事件穿透到 cell
	panel.focus_mode = Control.FOCUS_NONE
	
	# 设置样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.4, 0.4)
	panel.add_theme_stylebox_override("panel", style)
	cell.add_child(panel)
	
	# 保存位置信息
	cell.set_meta("grid_x", x)
	cell.set_meta("grid_y", y)
	
	# 直接在 cell 上连接 gui_input 信号（更可靠）
	cell.mouse_filter = Control.MOUSE_FILTER_STOP # 确保能接收鼠标事件
	cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var connection_result = cell.gui_input.connect(_on_cell_gui_input.bind(x, y))
	if connection_result != OK:
		print("警告：cell信号连接失败，错误代码: %d" % connection_result)
	else:
		print("cell信号连接成功: 格子 (%d, %d)" % [x, y])
	
	var pos = Vector2i(x, y)
	
	# 起点
	if pos == START_POS:
		var label = Label.new()
		label.text = "◉"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 36)
		label.add_theme_color_override("font_color", Color.GREEN)
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE # 让鼠标事件穿透
		panel.add_child(label)
		return cell
	
	# 终点
	if pos == END_POS:
		var label = Label.new()
		label.text = "◎"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 36)
		
		# 根据激活状态设置颜色和效果
		if end_point_activated:
			# 激活状态：亮红色，带发光效果
			label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3)) # 亮红色
			# 添加发光效果（通过边框）
			style.border_color = Color(1.0, 0.5, 0.5) # 浅红色边框
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			style.shadow_color = Color(1.0, 0.3, 0.3, 0.8) # 红色发光
			style.shadow_size = 10
		else:
			# 未激活：暗红色
			label.add_theme_color_override("font_color", Color(0.6, 0.0, 0.0)) # 暗红色
			style.border_color = Color(0.3, 0.0, 0.0)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
		
		label.set_anchors_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE # 让鼠标事件穿透
		panel.add_child(label)
		panel.add_theme_stylebox_override("panel", style)
		return cell
	
	# 魂印管道
	var soul_index = pipe_grid[y][x]
	if soul_index != null and soul_index >= 0 and soul_index < player_souls.size():
		var soul_item = player_souls[soul_index]
		var soul = soul_item.soul_print
		
		# 创建边距容器，给图标留出旋转空间
		var margin = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 10)
		margin.add_theme_constant_override("margin_bottom", 10)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(margin)
		
		# 显示管道图标
		var texture_rect = TextureRect.new()
		var texture_path = SoulPrintSystem.get_pipe_texture_path(soul.pipe_shape_type, soul.rotation)
		texture_rect.texture = load(texture_path)
		texture_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		texture_rect.pivot_offset = Vector2((CELL_SIZE - 20) / 2.0, (CELL_SIZE - 20) / 2.0) # 设置旋转中心（减去边距后的中心）
		texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE # 让图标不阻挡点击
		
		# 根据连通状态和拖拽状态设置颜色调制
		if soul_index == dragging_soul_index:
			# 拖拽中的魂印：半透明
			if soul_index in connected_souls:
				var quality_color = _get_quality_color(soul.quality)
				texture_rect.modulate = Color(quality_color.r, quality_color.g, quality_color.b, 0.5)
			else:
				texture_rect.modulate = Color(0.5, 0.5, 0.5, 0.5)
		elif soul_index in connected_souls:
			# 激活状态：使用品质颜色，并增加亮度
			var quality_color_active = _get_quality_color(soul.quality)
			texture_rect.modulate = quality_color_active.lightened(0.3) # 增加亮度表示激活
		else:
			# 未激活：灰色
			texture_rect.modulate = Color(0.5, 0.5, 0.5)
		
		margin.add_child(texture_rect)
		
		# 根据魂印品质和状态设置边框特效
		var quality_color = _get_quality_color(soul.quality)
		
		# 拖拽高亮（优先级最高）
		if soul_index == dragging_soul_index:
			# 使用更明显的青色边框
			style.border_color = Color(0.0, 1.0, 1.0) # 纯青色
			style.border_width_left = 5
			style.border_width_right = 5
			style.border_width_top = 5
			style.border_width_bottom = 5
			# 添加发光效果
			style.shadow_color = Color(0.0, 1.0, 1.0, 0.8)
			style.shadow_size = 8
			print("设置拖拽边框: 魂印索引 %d, dragging_soul_index=%d" % [soul_index, dragging_soul_index])
		# 选中高亮（优先级次高）
		elif soul_index == selected_soul_index:
			style.border_color = Color.YELLOW
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
		# 品质边框特效
		else:
			if soul_index in connected_souls:
				# 已连通：根据品质显示明亮的边框效果
				_apply_quality_border_style(style, quality_color, soul.quality, true)
			else:
				# 未连通：根据品质显示暗淡的边框效果
				var dim_color = quality_color * 0.5 # 降低亮度
				_apply_quality_border_style(style, dim_color, soul.quality, false)
		
		panel.add_theme_stylebox_override("panel", style)
		
		# 为高品质已连通魂印添加呼吸光效动画
		if soul_index in connected_souls and soul.quality >= 3: # 史诗及以上品质
			_add_glow_animation(panel, quality_color, soul.quality)
		
		# 如果管道已激活，添加能量条显示（在最后添加，确保在最上层）
		if soul_index in connected_souls:
			_draw_energy_bar_in_pipe(cell, soul, soul_index)
	else:
		# 空格子 - 检查是否是拖拽时的目标位置
		if dragging_soul_index >= 0 and drag_hover_pos == pos:
			# 鼠标悬停在空格子上，高亮显示（可以放置）
			var can_place = (pos != START_POS and pos != END_POS)
			if can_place:
				style.border_color = Color(0.0, 1.0, 0.5) # 青绿色，表示可以放置
				style.border_width_left = 3
				style.border_width_right = 3
				style.border_width_top = 3
				style.border_width_bottom = 3
				style.shadow_color = Color(0.0, 1.0, 0.5, 0.5)
				style.shadow_size = 4
				panel.add_theme_stylebox_override("panel", style)
	
	return cell

func _apply_quality_border_style(style: StyleBoxFlat, color: Color, quality: int, show_glow: bool = true):
	"""根据品质应用不同的边框样式"""
	match quality:
		0: # 普通 - 简单边框
			style.border_color = color
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1
			if show_glow:
				style.shadow_color = color
				style.shadow_color.a = 0.3
				style.shadow_size = 2
			else:
				style.shadow_size = 0
		
		1: # 非凡 - 稍微加粗
			style.border_color = color
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			if show_glow:
				style.shadow_color = color
				style.shadow_color.a = 0.4
				style.shadow_size = 3
			else:
				style.shadow_size = 1
		
		2: # 稀有 - 明显边框
			style.border_color = color
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
			if show_glow:
				style.shadow_color = color
				style.shadow_color.a = 0.5
				style.shadow_size = 4
			else:
				style.shadow_size = 1
		
		3: # 史诗 - 粗边框+明显发光
			style.border_color = color
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			if show_glow:
				style.shadow_color = color
				style.shadow_color.a = 0.6
				style.shadow_size = 5
			else:
				style.shadow_size = 1
		
		4: # 传说 - 更粗边框+强发光
			style.border_color = color
			style.border_width_left = 3
			style.border_width_right = 3
			style.border_width_top = 3
			style.border_width_bottom = 3
			if show_glow:
				style.shadow_color = color
				style.shadow_color.a = 0.7
				style.shadow_size = 6
			else:
				style.shadow_size = 1
		
		5: # 神话 - 最粗边框+超强发光
			style.border_color = color
			style.border_width_left = 4
			style.border_width_right = 4
			style.border_width_top = 4
			style.border_width_bottom = 4
			if show_glow:
				style.shadow_color = color
				style.shadow_color.a = 0.8
				style.shadow_size = 8
			else:
				style.shadow_size = 1

func _add_glow_animation(panel: Panel, color: Color, quality: int):
	"""为高品质魂印添加呼吸光效动画"""
	var tween = create_tween()
	tween.set_loops()
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	
	# 根据品质调整动画速度
	var duration = 2.0 # 史诗
	if quality == 4: # 传说
		duration = 1.5
	elif quality == 5: # 神话
		duration = 1.0
	
	# 创建发光效果（通过调制颜色的alpha值）
	var start_color = color
	start_color.a = 0.3
	var end_color = color
	end_color.a = 0.8
	
	# 获取样式并创建呼吸动画
	var style = panel.get_theme_stylebox("panel")
	if style is StyleBoxFlat:
		tween.tween_property(style, "shadow_color", end_color, duration / 2.0)
		tween.tween_property(style, "shadow_color", start_color, duration / 2.0)

func _on_cell_gui_input(event: InputEvent, x: int, y: int):
	"""处理格子的输入事件（保留作为备用，主要使用全局_input）"""
	# 注意：现在主要使用全局 _input 函数来处理鼠标事件
	# 这个函数保留作为备用，但不会主动处理事件
	pass

func _on_cell_right_clicked(x: int, y: int):
	"""右键点击格子 - 直接旋转魂印（带动画）"""
	# 如果正在播放旋转动画，忽略新的旋转请求
	if is_rotating:
		print("旋转动画进行中，请稍候...")
		return
	
	print("右键点击格子: (%d, %d)" % [x, y])
	var pos = Vector2i(x, y)
	
	# 如果是起点或终点，不处理
	if pos == START_POS or pos == END_POS:
		return
	
	var soul_index = pipe_grid[y][x]
	
	# 如果有魂印，旋转并播放动画
	if soul_index != null and soul_index >= 0 and soul_index < player_souls.size():
		var soul_item = player_souls[soul_index]
		var soul = soul_item.soul_print
		
		# 锁定旋转
		is_rotating = true
		
		# 更新旋转角度
		soul.rotation = (soul.rotation + 1) % 4
		
		# 播放旋转动画
		await _play_rotation_animation(x, y)
		
		# 只更新当前格子的纹理和颜色
		_update_single_cell(x, y)
		
		# 检查连通性（可能影响其他格子的颜色）
		_check_connectivity()
		
		# 只更新所有格子的颜色（不重建整个网格）
		_update_all_cells_color()
		
		# 解锁旋转
		is_rotating = false
	else:
		print("这里没有魂印")

func _on_cell_mouse_down(x: int, y: int):
	"""鼠标按下格子"""
	# 如果已经在拖拽，忽略新的按下事件
	if dragging_soul_index >= 0:
		return
		
	var pos = Vector2i(x, y)
	
	# 如果是起点或终点，不处理
	if pos == START_POS or pos == END_POS:
		return
	
	var soul_index = pipe_grid[y][x]
	
	# 如果点击了魂印，开始拖拽
	if soul_index != null and soul_index >= 0 and soul_index < player_souls.size():
		dragging_soul_index = soul_index
		drag_start_pos = pos
		print("开始拖拽魂印 %s (索引: %d)" % [player_souls[soul_index].soul_print.name, soul_index])
		# 注意：不设置 selected_soul_index，让拖拽状态优先显示青色边框
		_update_grid_display()
	else:
		print("格子 (%d, %d) 没有魂印或索引无效: %s" % [x, y, soul_index])

func _on_cell_mouse_up(x: int, y: int):
	"""鼠标释放格子"""
	if dragging_soul_index < 0:
		return
	
	var pos = Vector2i(x, y)
	
	print("鼠标释放: 格子 (%d, %d), dragging_soul_index=%d" % [pos.x, pos.y, dragging_soul_index])
	
	# 如果是起点或终点，取消拖拽
	if pos == START_POS or pos == END_POS:
		print("不能放置到起点或终点")
		dragging_soul_index = -1
		drag_start_pos = Vector2i(-1, -1)
		drag_hover_pos = Vector2i(-1, -1)
		_update_grid_display()
		return
	
	# 边界检查
	if pos.x < 0 or pos.x >= GRID_SIZE or pos.y < 0 or pos.y >= GRID_SIZE:
		print("目标位置超出边界: (%d, %d)" % [pos.x, pos.y])
		dragging_soul_index = -1
		drag_start_pos = Vector2i(-1, -1)
		drag_hover_pos = Vector2i(-1, -1)
		_update_grid_display()
		return
	
	# 检查目标位置是否为空（允许移动到空格子）
	# 边界检查 pipe_grid
	if pos.y < 0 or pos.y >= pipe_grid.size() or pos.x < 0 or pos.x >= GRID_SIZE:
		print("错误：目标位置 (%d, %d) 超出 pipe_grid 范围" % [pos.x, pos.y])
		dragging_soul_index = -1
		drag_start_pos = Vector2i(-1, -1)
		drag_hover_pos = Vector2i(-1, -1)
		_update_grid_display()
		return
	
	var target_soul_index = pipe_grid[pos.y][pos.x]
	print("检查目标位置 (%d, %d): target_soul_index=%s, dragging_soul_index=%d, START_POS=%s, END_POS=%s" % [pos.x, pos.y, target_soul_index, dragging_soul_index, START_POS, END_POS])
	
	if target_soul_index == null:
		# 空格子 - 可以移动
		print("目标位置 (%d, %d) 是空格子，开始移动" % [pos.x, pos.y])
		_try_move_soul(dragging_soul_index, pos)
	elif target_soul_index == dragging_soul_index:
		# 目标位置是同一个魂印（可能是当前位置）- 允许"移动"（实际不移动）
		print("目标位置 (%d, %d) 是当前拖拽的魂印，取消移动" % [pos.x, pos.y])
	else:
		# 目标位置有不同魂印 - 交换位置
		print("目标位置 (%d, %d) 已有魂印 (索引: %d)，尝试交换位置" % [pos.x, pos.y, target_soul_index])
		_try_swap_souls(dragging_soul_index, target_soul_index)
	
	dragging_soul_index = -1
	drag_start_pos = Vector2i(-1, -1)
	drag_hover_pos = Vector2i(-1, -1)
	_update_grid_display()

func _update_drag_preview(mouse_pos: Vector2):
	"""更新拖拽预览"""
	# 计算鼠标下的格子位置
	var grid_pos = _screen_to_grid_pos(mouse_pos)
	
	# 更新悬停位置
	if grid_pos.x >= 0 and grid_pos.y >= 0:
		# 如果悬停位置改变，更新显示
		if drag_hover_pos != grid_pos:
			drag_hover_pos = grid_pos
			_update_grid_display()
	else:
		# 鼠标在网格外，清除悬停位置
		if drag_hover_pos.x >= 0:
			drag_hover_pos = Vector2i(-1, -1)
			_update_grid_display()

func _on_cell_left_clicked(_x: int, _y: int):
	"""左键点击格子（保留兼容性，但主要使用鼠标事件）"""
	# 这个函数现在主要用于兼容，实际拖拽由 _on_cell_mouse_down/up 处理
	pass

func _try_move_soul(soul_index: int, target_pos: Vector2i):
	"""尝试移动魂印到目标位置"""
	# 边界检查
	if soul_index < 0 or soul_index >= player_souls.size():
		print("警告：魂印索引越界 %d" % soul_index)
		return
	
	# 检查目标位置是否有效
	if target_pos.x < 0 or target_pos.x >= GRID_SIZE or target_pos.y < 0 or target_pos.y >= GRID_SIZE:
		return
	
	# 不能移动到起点或终点
	if target_pos == START_POS or target_pos == END_POS:
		print("不能移动到起点或终点: target_pos=%s, START_POS=%s, END_POS=%s" % [target_pos, START_POS, END_POS])
		return
	
	# 检查目标位置是否为空
	if pipe_grid[target_pos.y][target_pos.x] != null:
		return
	
	# 找到当前位置
	var current_pos = Vector2i(-1, -1)
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if pipe_grid[y][x] == soul_index:
				current_pos = Vector2i(x, y)
				break
		if current_pos.x >= 0:
			break
	
	if current_pos.x < 0:
		return
	
	# 移动魂印
	pipe_grid[current_pos.y][current_pos.x] = null
	pipe_grid[target_pos.y][target_pos.x] = soul_index
	
	# 更新魂印的网格位置
	var soul_item = player_souls[soul_index]
	soul_item.soul_print.grid_pos = target_pos
	
	# 重新检测连通性
	_check_connectivity()

func _try_swap_souls(soul_index1: int, soul_index2: int):
	"""交换两个魂印的位置"""
	# 边界检查
	if soul_index1 < 0 or soul_index1 >= player_souls.size() or soul_index2 < 0 or soul_index2 >= player_souls.size():
		print("警告：魂印索引越界 soul_index1=%d, soul_index2=%d" % [soul_index1, soul_index2])
		return
	
	# 找到两个魂印的当前位置
	var pos1 = Vector2i(-1, -1)
	var pos2 = Vector2i(-1, -1)
	
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if pipe_grid[y][x] == soul_index1:
				pos1 = Vector2i(x, y)
			if pipe_grid[y][x] == soul_index2:
				pos2 = Vector2i(x, y)
			if pos1.x >= 0 and pos2.x >= 0:
				break
		if pos1.x >= 0 and pos2.x >= 0:
			break
	
	if pos1.x < 0 or pos2.x < 0:
		print("警告：无法找到魂印位置 pos1=%s, pos2=%s" % [pos1, pos2])
		return
	
	# 检查是否在起点或终点
	if pos1 == START_POS or pos1 == END_POS or pos2 == START_POS or pos2 == END_POS:
		print("不能交换起点或终点的魂印")
		return
	
	# 交换位置
	pipe_grid[pos1.y][pos1.x] = soul_index2
	pipe_grid[pos2.y][pos2.x] = soul_index1
	
	# 更新魂印的网格位置
	player_souls[soul_index1].soul_print.grid_pos = pos2
	player_souls[soul_index2].soul_print.grid_pos = pos1
	
	print("成功交换魂印 %d 和 %d 的位置: (%d, %d) <-> (%d, %d)" % [soul_index1, soul_index2, pos1.x, pos1.y, pos2.x, pos2.y])
	
	# 重新检测连通性
	_check_connectivity()

func _on_rotate_button_pressed():
	"""旋转选中的魂印"""
	print("旋转按钮被点击")
	if selected_soul_index >= 0 and selected_soul_index < player_souls.size():
		var soul_item = player_souls[selected_soul_index]
		var soul = soul_item.soul_print
		var old_rotation = soul.rotation
		soul.rotation = (soul.rotation + 1) % 4
		print("魂印 %s 旋转: %d° -> %d°" % [soul.name, old_rotation * 90, soul.rotation * 90])
		_check_connectivity()
		_update_grid_display()
	else:
		print("没有选中魂印！请先点击一个魂印选中它（黄色边框）")

func _on_start_battle_button_pressed():
	"""开始战斗"""
	timer_active = false
	_start_battle()

func _check_connectivity():
	"""检测管道连通性（深度优先搜索）- 只要连接到起点就算激活，能到终点则终点也激活"""
	connected_souls.clear()
	connected_path.clear()
	total_power = 0
	end_point_activated = false
	
	var visited = {}
	var path = [] # 存储魂印索引
	var path_positions = [] # 存储位置信息，用于绘制能量流
	var flow_segments = [] # 存储能量流片段信息
	
	# 从起点开始DFS，找到所有能连接到的魂印（不要求到达终点）
	_dfs_from_start_with_flow(START_POS, -1, visited, path, path_positions, flow_segments)
	
	# 检查是否能到达终点
	if END_POS in path_positions:
		end_point_activated = true
		# 如果到达终点，添加终点到路径中（用于绘制能量流）
		if not path_positions.has(END_POS):
			path_positions.append(END_POS)
	
	# 更新连通魂印列表和总力量
	for soul_index in path:
		if soul_index >= 0 and soul_index < player_souls.size():
			connected_souls.append(soul_index)
			var soul_item = player_souls[soul_index]
			total_power += soul_item.soul_print.power
			# 标记为激活状态
			soul_item.soul_print.is_connected = true
	
	# 保存路径位置信息和能量流片段
	connected_path = path_positions.duplicate()
	connected_flow_segments = flow_segments.duplicate()
	print("连通检查完成：%d 个魂印，%d 个能量流片段" % [connected_souls.size(), connected_flow_segments.size()])
	
	# 标记未连通的魂印
	for i in range(player_souls.size()):
		if i not in connected_souls:
			player_souls[i].soul_print.is_connected = false
	
	_update_ui()
	# 触发能量流覆盖层重绘和网格重绘（更新终点显示和能量条）
	if energy_overlay:
		energy_overlay.queue_redraw()
	_update_grid_display() # 更新终点显示和能量条
	# 更新所有能量条
	_update_all_energy_bars()

func _dfs_from_start_with_flow(pos: Vector2i, from_port: int, visited: Dictionary, path: Array, path_positions: Array, flow_segments: Array):
	"""从起点开始的深度优先搜索 - 记录能量流片段信息"""
	# 已访问过
	var pos_key = "%d,%d" % [pos.x, pos.y]
	if visited.has(pos_key):
		return
	
	visited[pos_key] = true
	
	# 检查是否到达终点
	if pos == END_POS:
		path_positions.append(pos)
		# 记录从上一个位置到终点的能量流
		if path_positions.size() > 1:
			var prev_pos = path_positions[path_positions.size() - 2]
			flow_segments.append({
				"from_pos": prev_pos,
				"to_pos": pos,
				"from_port": SoulPrintSystem.PipePort.DOWN, # 终点从上方接收
				"to_port": SoulPrintSystem.PipePort.UP
			})
		return
	
	# 获取当前位置的魂印
	var soul_index = pipe_grid[pos.y][pos.x] if pos.y >= 0 and pos.y < GRID_SIZE and pos.x >= 0 and pos.x < GRID_SIZE else null
	
	# 起点特殊处理
	if pos == START_POS:
		path_positions.append(pos)
		# 起点只能向下连接
		var next_pos = pos + Vector2i(0, 1)
		# 检查下一个位置是否有管道
		var next_soul_index = pipe_grid[next_pos.y][next_pos.x] if next_pos.y >= 0 and next_pos.y < GRID_SIZE and next_pos.x >= 0 and next_pos.x < GRID_SIZE else null
		if next_soul_index != null:
			# 记录从起点到第一个管道的能量流
			flow_segments.append({
				"from_pos": pos,
				"to_pos": next_pos,
				"from_port": SoulPrintSystem.PipePort.DOWN, # 起点向下输出
				"to_port": SoulPrintSystem.PipePort.UP # 管道从上方接收
			})
		_dfs_from_start_with_flow(next_pos, SoulPrintSystem.PipePort.DOWN, visited, path, path_positions, flow_segments)
		return
	
	# 没有魂印，停止搜索
	if soul_index == null:
		return
	
	# 边界检查
	if soul_index < 0 or soul_index >= player_souls.size():
		print("警告：魂印索引越界 %d，player_souls.size = %d" % [soul_index, player_souls.size()])
		return
	
	var soul_item = player_souls[soul_index]
	var soul = soul_item.soul_print
	var rotated_ports = SoulPrintSystem.rotate_pipe_ports(soul.pipe_ports, soul.rotation)
	
	# 检查当前魂印是否有对应的入口端口
	var opposite_port = SoulPrintSystem.get_opposite_port(from_port)
	if not (rotated_ports & opposite_port):
		# 端口不匹配，无法连接
		return
	
	# 记录从上一个位置到当前位置的能量流（只在端口匹配时记录）
	if path_positions.size() > 0:
		var prev_pos = path_positions[path_positions.size() - 1]
		# 确保端口匹配：上一个位置有输出端口，当前位置有对应的输入端口
		var prev_soul_index = pipe_grid[prev_pos.y][prev_pos.x] if prev_pos.y >= 0 and prev_pos.y < GRID_SIZE and prev_pos.x >= 0 and prev_pos.x < GRID_SIZE else null
		if prev_soul_index != null and prev_soul_index >= 0 and prev_soul_index < player_souls.size():
			var prev_soul = player_souls[prev_soul_index].soul_print
			var prev_rotated_ports = SoulPrintSystem.rotate_pipe_ports(prev_soul.pipe_ports, prev_soul.rotation)
			# 检查上一个位置是否有对应的输出端口
			if prev_rotated_ports & from_port:
				flow_segments.append({
					"from_pos": prev_pos,
					"to_pos": pos,
					"from_port": from_port,
					"to_port": opposite_port
				})
	
	# 添加到路径（已连接）
	path.append(soul_index)
	path_positions.append(pos)
	
	# 尝试向四个方向继续搜索
	var directions = [
		{"port": SoulPrintSystem.PipePort.UP, "vec": Vector2i(0, -1)},
		{"port": SoulPrintSystem.PipePort.DOWN, "vec": Vector2i(0, 1)},
		{"port": SoulPrintSystem.PipePort.LEFT, "vec": Vector2i(-1, 0)},
		{"port": SoulPrintSystem.PipePort.RIGHT, "vec": Vector2i(1, 0)}
	]
	
	for dir in directions:
		if rotated_ports & dir["port"]:
			var next_pos = pos + dir["vec"]
			# 边界检查
			if next_pos.x >= 0 and next_pos.x < GRID_SIZE and next_pos.y >= 0 and next_pos.y < GRID_SIZE:
				_dfs_from_start_with_flow(next_pos, dir["port"], visited, path, path_positions, flow_segments)

func _dfs_from_start(pos: Vector2i, from_port: int, visited: Dictionary, path: Array, path_positions: Array):
	"""从起点开始的深度优先搜索（兼容性函数）"""
	var flow_segments = []
	_dfs_from_start_with_flow(pos, from_port, visited, path, path_positions, flow_segments)

func _dfs_with_path(pos: Vector2i, from_port: int, visited: Dictionary, path: Array, path_positions: Array) -> bool:
	"""深度优先搜索（带路径位置记录）- 保留用于兼容性"""
	# 到达终点
	if pos == END_POS:
		path_positions.append(pos)
		return true
	
	# 已访问过
	var pos_key = "%d,%d" % [pos.x, pos.y]
	if visited.has(pos_key):
		return false
	
	visited[pos_key] = true
	
	# 获取当前位置的魂印
	var soul_index = pipe_grid[pos.y][pos.x] if pos.y >= 0 and pos.y < GRID_SIZE and pos.x >= 0 and pos.x < GRID_SIZE else null
	
	# 起点特殊处理
	if pos == START_POS:
		path_positions.append(pos)
		# 起点只能向下连接
		var next_pos = pos + Vector2i(0, 1)
		if _dfs_with_path(next_pos, SoulPrintSystem.PipePort.DOWN, visited, path, path_positions):
			return true
		path_positions.pop_back()
		return false
	
	# 没有魂印
	if soul_index == null:
		return false
	
	# 边界检查
	if soul_index < 0 or soul_index >= player_souls.size():
		print("警告：魂印索引越界 %d，player_souls.size = %d" % [soul_index, player_souls.size()])
		return false
	
	# 添加到路径
	path.append(soul_index)
	path_positions.append(pos)
	
	var soul_item = player_souls[soul_index]
	var soul = soul_item.soul_print
	var rotated_ports = SoulPrintSystem.rotate_pipe_ports(soul.pipe_ports, soul.rotation)
	
	# 检查当前魂印是否有对应的入口端口
	var opposite_port = SoulPrintSystem.get_opposite_port(from_port)
	if not (rotated_ports & opposite_port):
		path.pop_back()
		path_positions.pop_back()
		return false
	
	# 尝试向四个方向连接
	var directions = [
		{"port": SoulPrintSystem.PipePort.UP, "vec": Vector2i(0, -1)},
		{"port": SoulPrintSystem.PipePort.DOWN, "vec": Vector2i(0, 1)},
		{"port": SoulPrintSystem.PipePort.LEFT, "vec": Vector2i(-1, 0)},
		{"port": SoulPrintSystem.PipePort.RIGHT, "vec": Vector2i(1, 0)}
	]
	
	for dir in directions:
		if rotated_ports & dir["port"]:
			var next_pos = pos + dir["vec"]
			if _dfs_with_path(next_pos, dir["port"], visited, path, path_positions):
				return true
	
	# 回溯
	path.pop_back()
	path_positions.pop_back()
	return false

func _dfs(pos: Vector2i, from_port: int, visited: Dictionary, path: Array) -> bool:
	"""深度优先搜索（保留兼容性）"""
	var path_positions = []
	return _dfs_with_path(pos, from_port, visited, path, path_positions)

func _get_port_direction(port: int) -> Vector2:
	match port:
		SoulPrintSystem.PipePort.UP:
			return Vector2(0, -1)
		SoulPrintSystem.PipePort.DOWN:
			return Vector2(0, 1)
		SoulPrintSystem.PipePort.LEFT:
			return Vector2(-1, 0)
		SoulPrintSystem.PipePort.RIGHT:
			return Vector2(1, 0)
	return Vector2.ZERO

func _get_direction_offset(direction: Vector2, cell_size: Vector2) -> Vector2:
	return Vector2(direction.x * cell_size.x * 0.5, direction.y * cell_size.y * 0.5)

func _on_energy_overlay_draw():
	"""绘制能量流动效果（在覆盖层上）- 沿着管道实际路径"""
	if not energy_overlay:
		return
	
	if connected_flow_segments.size() == 0:
		if DEBUG_ENERGY_DRAW:
			print("警告：connected_flow_segments 为空，无法绘制能量流")
		return
	if DEBUG_ENERGY_DRAW:
		print("绘制能量流：%d 个片段" % connected_flow_segments.size())
	
	# 计算 GridContainer 相对于覆盖层的偏移
	var grid_offset = grid_container.get_global_position() - energy_overlay.get_global_position()
	if DEBUG_ENERGY_DRAW and connected_flow_segments.size() > 0:
		print("GridOffset: %s" % grid_offset)
	
	var energy_color = Color(0.0, 1.0, 1.0, 0.9) # 青色能量流
	
	# 绘制每个能量流片段（带流动动画）
	for i in range(connected_flow_segments.size()):
		pass
	

func _update_ui():
	"""更新UI显示"""
	var status_text = ""
	if dragging_soul_index >= 0:
		status_text = " | 拖拽中：点击空格放下"
	elif selected_soul_index >= 0:
		status_text = " | 已选中：再次点击开始拖拽"
	
	# 显示激活状态
	var activated_count = connected_souls.size()
	if activated_count > 0:
		status_text += " | 已激活: %d" % activated_count
	
	# 显示终点激活状态
	if end_point_activated:
		status_text += " | 终点已激活"
	
	power_label.text = "连通力量: %d%s" % [total_power, status_text]
	
	# 更新能量条
	if power_bar:
		# 计算所有魂印的总力量（如果没有计算过）
		if max_power == 0:
			_calculate_max_power()
		
		# 更新能量条的值和最大值
		if max_power > 0:
			power_bar.max_value = max_power
			power_bar.value = total_power
		else:
			power_bar.value = 0

func _calculate_max_power():
	"""计算所有魂印的总力量"""
	max_power = 0
	for soul_item in player_souls:
		if soul_item and soul_item.soul_print:
			max_power += soul_item.soul_print.power

func _draw_energy_bar_in_pipe(cell: Control, soul: SoulPrintSystem.SoulPrint, soul_index: int):
	"""在管道内部绘制能量条"""
	# 检查是否已存在能量条容器，如果存在则删除
	var existing_bar = cell.get_node_or_null("EnergyBarContainer")
	if existing_bar:
		existing_bar.queue_free()
	
	# 创建一个Control节点用于绘制能量条
	var energy_bar_container = Control.new()
	energy_bar_container.name = "EnergyBarContainer"
	energy_bar_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	energy_bar_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 将 soul 和 soul_index 存储到容器的 meta 中
	energy_bar_container.set_meta("soul_index", soul_index)
	energy_bar_container.set_meta("soul_power", soul.power)
	energy_bar_container.set_meta("soul_ports", soul.pipe_ports)
	energy_bar_container.set_meta("soul_rotation", soul.rotation)
	
	# 确保能量条容器在最上层（最后添加）
	cell.add_child(energy_bar_container)
	cell.move_child(energy_bar_container, cell.get_child_count() - 1)
	
	# 连接绘制信号（使用 lambda 函数）
	energy_bar_container.draw.connect(func(): _on_energy_bar_draw(energy_bar_container))
	
	# 立即触发一次绘制
	energy_bar_container.queue_redraw()

func _on_energy_bar_draw(container: Control):
	"""绘制管道内部的能量条"""
	var soul_index = container.get_meta("soul_index", -1)
	if soul_index < 0 or soul_index not in connected_souls:
		return
	
	# 从 meta 中获取数据
	var soul_power = container.get_meta("soul_power", 0)
	var soul_ports = container.get_meta("soul_ports", 0)
	var soul_rotation = container.get_meta("soul_rotation", 0)
	
	# 计算能量条的比例（当前力量 / 最大力量）
	var energy_ratio = 1.0
	if max_power > 0:
		energy_ratio = float(soul_power) / float(max_power)
		energy_ratio = clamp(energy_ratio, 0.0, 1.0)
	
	# 获取管道端口配置
	var rotated_ports = SoulPrintSystem.rotate_pipe_ports(soul_ports, soul_rotation)
	var cell_size = container.size
	
	# 如果容器大小无效，使用默认值
	if cell_size.x <= 0 or cell_size.y <= 0:
		cell_size = Vector2(CELL_SIZE, CELL_SIZE)
	
	var center = cell_size / 2.0
	var bar_width = clamp(CELL_SIZE * 0.16, 5.0, 12.0)

	var base_alpha = 0.18 + energy_ratio * 0.22
	var highlight_alpha = 0.45 + energy_ratio * 0.4
	var base_color = Color(0.05, 0.7, 0.95, base_alpha)
	var highlight_color = Color(0.5, 1.0, 1.0, highlight_alpha)
	var glint_color = Color(0.95, 1.0, 1.0, highlight_alpha)
	
	var flow_phase = fmod(energy_flow_time * 0.6 + float(soul_index) * 0.21, 1.0)
	
	var has_up = (rotated_ports & SoulPrintSystem.PipePort.UP) != 0
	var has_down = (rotated_ports & SoulPrintSystem.PipePort.DOWN) != 0
	var has_left = (rotated_ports & SoulPrintSystem.PipePort.LEFT) != 0
	var has_right = (rotated_ports & SoulPrintSystem.PipePort.RIGHT) != 0
	var directions: Array[Vector2] = []
	if has_up:
		directions.append(Vector2(0, -1))
	if has_down:
		directions.append(Vector2(0, 1))
	if has_left:
		directions.append(Vector2(-1, 0))
	if has_right:
		directions.append(Vector2(1, 0))
	if directions.is_empty():
		return
	
	var draw_segment := func(start_point: Vector2, end_point: Vector2, phase_shift: float):
		container.draw_line(start_point, end_point, base_color, bar_width)
		var inner_color = Color(highlight_color.r, highlight_color.g, highlight_color.b, highlight_color.a * 0.75)
		container.draw_line(start_point, end_point, inner_color, bar_width * 0.5)
		var segment_phase = fmod(flow_phase + phase_shift, 1.0)
		var highlight_pos = start_point.lerp(end_point, segment_phase)
		var halo_color = Color(highlight_color.r, highlight_color.g, highlight_color.b, highlight_color.a * 0.45)
		container.draw_circle(highlight_pos, bar_width * 0.55, halo_color)
		var glint = Color(glint_color.r, glint_color.g, glint_color.b, glint_color.a)
		container.draw_circle(highlight_pos, bar_width * 0.28, glint)

	var half_min = min(cell_size.x, cell_size.y) * 0.5
	var margin = max(bar_width * 0.75, 5.0)
	var outer_ratio = 0.85
	if half_min > margin:
		outer_ratio = clamp((half_min - margin) / half_min, 0.6, 0.92)
	var inner_ratio = clamp(outer_ratio * 0.45, 0.25, 0.5)

	# 绘制中心光晕
	var hub_radius = bar_width * 0.7
	var hub_outer_color = Color(base_color.r, base_color.g, base_color.b, min(base_color.a * 1.4, 0.75))
	container.draw_circle(center, hub_radius * 1.4, hub_outer_color)
	var hub_inner = Color(highlight_color.r, highlight_color.g, highlight_color.b, highlight_color.a * 0.75)
	container.draw_circle(center, hub_radius, hub_inner)
	container.draw_circle(center, hub_radius * 0.5, glint_color)

	for i in range(directions.size()):
		var dir = directions[i]
		var border_offset = _get_direction_offset(dir, cell_size)
		var start_point = center + border_offset * inner_ratio
		var end_point = center + border_offset * outer_ratio
		draw_segment.call(start_point, end_point, float(i) / max(directions.size(), 1))

func _update_all_energy_bars():
	"""更新所有能量条的显示"""
	# 遍历所有格子，更新能量条
	for child in grid_container.get_children():
		if child is Control:
			var energy_bar = child.get_node_or_null("EnergyBarContainer")
			if energy_bar:
				energy_bar.queue_redraw()

func _update_timer_display():
	"""更新倒计时显示"""
	var minutes = int(time_remaining) / 60
	var seconds = int(time_remaining) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	
	# 时间不足10秒时变红
	if time_remaining <= 10:
		timer_label.add_theme_color_override("font_color", Color.RED)
	else:
		timer_label.add_theme_color_override("font_color", Color.WHITE)

func _on_time_up():
	"""时间到"""
	_start_battle()

func _start_battle():
	"""开始战斗"""
	# 标记连通的魂印
	for i in range(player_souls.size()):
		var soul_item = player_souls[i]
		soul_item.soul_print.is_connected = (i in connected_souls)
	
	# 保存数据到UserSession（和BattlePreparation一样的方式）
	var session = get_node("/root/UserSession")
	session.set_meta("battle_selected_souls", player_souls)
	
	# 切换到战斗场景
	get_tree().change_scene_to_file("res://scenes/BattleCombat.tscn")

func _generate_test_data():
	"""生成测试用的魂印数据（单独调试时使用）- 自动生成能形成完整流通路径的分布"""
	print("=== 管道连接场景 - 独立调试模式 ===")
	
	# 获取 SoulPrintSystem
	var soul_system = get_node("/root/SoulPrintSystem")
	if not soul_system:
		print("错误：找不到 SoulPrintSystem")
		return
	
	# 设计一条从起点到终点的完整路径
	# START_POS = (2, 0), END_POS = (2, 4)
	# 路径设计：(2,0) -> (2,1) -> (2,2) -> (1,2) -> (1,3) -> (2,3) -> (2,4)
	
	# 定义路径上的魂印配置：位置、魂印ID、旋转角度
	var path_config = [
		{"pos": Vector2i(2, 1), "soul_id": "common_01", "rotation": 0}, # 垂直管道（上下）
		{"pos": Vector2i(2, 2), "soul_id": "uncommon_01", "rotation": 0}, # T型管（上、下、右）
		{"pos": Vector2i(1, 2), "soul_id": "common_02", "rotation": 0}, # L型管（右、下）
		{"pos": Vector2i(1, 3), "soul_id": "uncommon_02", "rotation": 0}, # L型管（上、右）
		{"pos": Vector2i(2, 3), "soul_id": "rare_01", "rotation": 0}, # T型管（上、下、左）
	]
	
	# 创建测试魂印列表
	var test_souls = []
	var soul_index = 0
	
	# 先创建路径上的魂印
	for config in path_config:
		var soul = soul_system.get_soul_by_id(config["soul_id"])
		if soul:
			# 设置管道形状和旋转，确保能形成路径
			# 根据位置和路径需求，设置正确的管道形状和旋转
			match config["pos"]:
				Vector2i(2, 1): # 需要上下连接
					soul.pipe_shape_type = SoulPrintSystem.PipeShapeType.STRAIGHT_V
					soul.pipe_ports = SoulPrintSystem.PipePort.UP | SoulPrintSystem.PipePort.DOWN
					soul.rotation = 0
				Vector2i(2, 2): # 需要上、下、右连接
					soul.pipe_shape_type = SoulPrintSystem.PipeShapeType.T_RIGHT
					soul.pipe_ports = SoulPrintSystem.PipePort.UP | SoulPrintSystem.PipePort.DOWN | SoulPrintSystem.PipePort.RIGHT
					soul.rotation = 0
				Vector2i(1, 2): # 需要右、下连接
					soul.pipe_shape_type = SoulPrintSystem.PipeShapeType.BEND_RD
					soul.pipe_ports = SoulPrintSystem.PipePort.RIGHT | SoulPrintSystem.PipePort.DOWN
					soul.rotation = 0
				Vector2i(1, 3): # 需要上、右连接
					soul.pipe_shape_type = SoulPrintSystem.PipeShapeType.BEND_RU
					soul.pipe_ports = SoulPrintSystem.PipePort.UP | SoulPrintSystem.PipePort.RIGHT
					soul.rotation = 0
				Vector2i(2, 3): # 需要上、下、左连接
					soul.pipe_shape_type = SoulPrintSystem.PipeShapeType.T_LEFT
					soul.pipe_ports = SoulPrintSystem.PipePort.UP | SoulPrintSystem.PipePort.DOWN | SoulPrintSystem.PipePort.LEFT
					soul.rotation = 0
			
			# 创建 InventoryItem 包装
			var item = soul_system.InventoryItem.new(soul, config["pos"], config["rotation"], -1)
			test_souls.append(item)
			soul_index += 1
			print("添加路径魂印 [%d]: %s 在 (%d, %d), 形状:%d, 旋转:%d" % [soul_index - 1, soul.name, config["pos"].x, config["pos"].y, soul.pipe_shape_type, config["rotation"]])
	
	# 添加一些额外的魂印作为装饰（不参与路径）
	var extra_soul_ids = ["rare_02", "epic_01", "legendary_01"]
	var extra_positions = [Vector2i(0, 1), Vector2i(4, 1), Vector2i(0, 3)]
	
	for i in range(min(extra_soul_ids.size(), extra_positions.size())):
		var soul = soul_system.get_soul_by_id(extra_soul_ids[i])
		if soul:
			var item = soul_system.InventoryItem.new(soul, extra_positions[i], 0, -1)
			test_souls.append(item)
			print("添加额外魂印 [%d]: %s 在 (%d, %d)" % [soul_index, soul.name, extra_positions[i].x, extra_positions[i].y])
			soul_index += 1
	
	# 创建测试敌人数据
	var test_enemy = {
		"name": "测试敌人",
		"hp": 100,
		"power": 30
	}
	
	print("生成了 %d 个测试魂印（%d 个在路径上）" % [test_souls.size(), path_config.size()])
	print("路径: (2,0) -> (2,1) -> (2,2) -> (1,2) -> (1,3) -> (2,3) -> (2,4)")
	print("调试模式：倒计时已禁用")
	print("=============================")
	
	# 初始化场景（禁用倒计时）
	initialize(test_souls, test_enemy, false)

func _get_quality_color(quality: int) -> Color:
	"""获取品质颜色"""
	match quality:
		0: return Color(0.8, 0.8, 0.8) # 普通 - 灰色
		1: return Color(0.3, 0.9, 0.3) # 非凡 - 绿色
		2: return Color(0.3, 0.6, 1.0) # 稀有 - 蓝色
		3: return Color(0.8, 0.3, 0.9) # 史诗 - 紫色
		4: return Color(1.0, 0.6, 0.2) # 传说 - 橙色
		5: return Color(1.0, 0.2, 0.2) # 神话 - 红色
	return Color.WHITE
