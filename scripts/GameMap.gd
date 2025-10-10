extends Control

@onready var map_name_label = $TopBar/MarginContainer/HBoxContainer/MapNameLabel
@onready var player_info_label = $TopBar/MarginContainer/HBoxContainer/PlayerInfoLabel
@onready var power_label = $TopBar/MarginContainer/HBoxContainer/PowerLabel
@onready var exploration_label = $TopBar/MarginContainer/HBoxContainer/ExplorationLabel
@onready var grid_container = $MainContent/GridPanel/GridContainer
@onready var brightness_overlay = $BrightnessOverlay
@onready var message_dialog = $MessageDialog
@onready var confirm_dialog = $ConfirmDialog

const GRID_SIZE = 9
const CELL_SIZE = 80
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

func _ready():
	_apply_brightness_from_settings()
	_load_game_data()
	_initialize_grid()
	_generate_map_content()
	_update_info()
	
	# 连接绘制和输入
	grid_container.draw.connect(_draw_grid)
	grid_container.gui_input.connect(_on_grid_gui_input)
	grid_container.queue_redraw()
	
	# 启动地形坍塌计时
	_start_collapse_loop()

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
	var max_ring = int((GRID_SIZE - 1) / 2)
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

func _draw_grid():
	# 绘制网格背景
	var bg_rect = Rect2(0, 0, GRID_SIZE * CELL_SIZE, GRID_SIZE * CELL_SIZE)
	grid_container.draw_rect(bg_rect, Color(0, 0, 0, 0.01), true)
	
	# 绘制网格线
	for x in range(GRID_SIZE + 1):
		var start = Vector2(x * CELL_SIZE, 0)
		var end = Vector2(x * CELL_SIZE, GRID_SIZE * CELL_SIZE)
		grid_container.draw_line(start, end, Color(0.3, 0.3, 0.35, 0.5), 2.0)
	
	for y in range(GRID_SIZE + 1):
		var start = Vector2(0, y * CELL_SIZE)
		var end = Vector2(GRID_SIZE * CELL_SIZE, y * CELL_SIZE)
		grid_container.draw_line(start, end, Color(0.3, 0.3, 0.35, 0.5), 2.0)
	
	# 绘制格子内容
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			_draw_cell(x, y)

func _draw_cell(x: int, y: int):
	var cell = grid_data[y][x]
	var rect = Rect2(x * CELL_SIZE + 5, y * CELL_SIZE + 5, CELL_SIZE - 10, CELL_SIZE - 10)
	var center = Vector2(x * CELL_SIZE + CELL_SIZE / 2.0, y * CELL_SIZE + CELL_SIZE / 2.0)
	var mouse_pos = grid_container.get_local_mouse_position()
	var grid_x = int(mouse_pos.x / CELL_SIZE)
	var grid_y = int(mouse_pos.y / CELL_SIZE)
	
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
		var grid_x = int(event.position.x / CELL_SIZE)
		var grid_y = int(event.position.y / CELL_SIZE)
		
		if grid_x >= 0 and grid_x < GRID_SIZE and grid_y >= 0 and grid_y < GRID_SIZE:
			_on_cell_clicked(grid_x, grid_y)
	
	elif event is InputEventMouseMotion:
		grid_container.queue_redraw()

func _on_cell_clicked(x: int, y: int):
	var clicked_pos = Vector2i(x, y)
	
	# 点击自己 - 如果在撤离点上就撤离
	if clicked_pos == player_pos:
		if show_evacuation and evacuation_points.has(player_pos):
			_evacuate()
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
	
	# 如果是未探索的格子，先探索
	if not cell.explored:
		cell.explored = true
		explored_count += 1
		
		# 检查是否达到探索度阈值，显示撤离点（探索40%以上）
		var explore_threshold = int(GRID_SIZE * GRID_SIZE * 0.4)
		if explored_count >= explore_threshold and not show_evacuation:
			show_evacuation = true
			_show_message("探索进度已达 " + str(int(explored_count * 100.0 / (GRID_SIZE * GRID_SIZE))) + "%\n撤离点已显示在地图上！")
	
	# 移动玩家
	player_pos = target_pos
	_update_info()
	grid_container.queue_redraw()
	
	# 检查是否触发战斗
	if cell.has_enemy:
		_start_battle(cell.enemy_data)
		return
	
	# 没有敌人，可以收集资源
	_collect_resources_from_cell(cell)

func _start_battle(enemy_data: Dictionary):
	# 触发战斗，加载战斗场景
	var battle_scene = load("res://scenes/Battle.tscn")
	var battle_instance = battle_scene.instantiate()
	
	# 传递数据给战斗场景
	battle_instance.set_meta("enemy_data", enemy_data)
	battle_instance.set_meta("player_power", _calculate_total_power())
	battle_instance.set_meta("player_hp", player_hp)
	
	# 连接战斗结束信号
	battle_instance.battle_finished.connect(_on_battle_finished)
	
	# 添加为覆盖层
	add_child(battle_instance)

func _on_battle_finished(result: Dictionary):
	# result包含: won (bool), player_hp_change (int), collected_souls (Array)
	
	# 更新玩家血量
	player_hp += result.get("player_hp_change", 0)
	if player_hp <= 0:
		player_hp = 0
		_game_over()
		return
	if player_hp > max_hp:
		player_hp = max_hp
	
	# 如果战斗胜利，收集资源
	if result.get("won", false):
		var cell = grid_data[player_pos.y][player_pos.x]
		cell.has_enemy = false  # 敌人已被击败
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
		_show_message("收集资源成功！\n获得 " + str(souls_collected.size()) + " 个" + quality_name + "品质魂印")
	
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

