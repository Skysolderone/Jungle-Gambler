extends Control

@onready var title_label = $LootPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var timer_label = $LootPanel/MarginContainer/VBoxContainer/TimerLabel
@onready var loot_container = $LootPanel/MarginContainer/VBoxContainer/LootContainer
@onready var inventory_container = $LootPanel/MarginContainer/VBoxContainer/InventoryContainer
@onready var continue_button = $LootPanel/MarginContainer/VBoxContainer/ContinueButton

# 战利品数据
var enemy_souls: Array = []
var loot_souls: Array = []
var player_all_souls: Array = []
var loot_selection_time: float = 15.0
var auto_finish: bool = false

func _ready():
	# 从UserSession获取数据
	var session = get_node("/root/UserSession")
	
	if session.has_meta("battle_enemy_souls"):
		enemy_souls = session.get_meta("battle_enemy_souls")
	
	# 检查战斗结果
	if not session.has_meta("combat_result"):
		# 如果没有战斗结果，直接返回地图
		get_tree().change_scene_to_file("res://scenes/GameMap.tscn")
		return
	
	var combat_result = session.get_meta("combat_result")
	if not combat_result.get("won", false):
		# 如果战斗失败，直接返回地图
		get_tree().change_scene_to_file("res://scenes/GameMap.tscn")
		return
	
	# 初始化战利品
	loot_souls = enemy_souls.duplicate()
	
	# 获取当前背包
	var soul_system = _get_soul_system()
	if soul_system:
		var username = _get_username()
		player_all_souls = soul_system.get_user_inventory(username)
	
	title_label.text = "战利品获得"
	
	# 尝试直接添加所有战利品
	_try_auto_collect_loot()
	
	# 如果还有剩余战利品，进入选择模式
	if loot_souls.size() > 0:
		_start_loot_selection()
	else:
		_auto_finish_loot()

func _process(delta):
	if auto_finish:
		return
	
	if loot_souls.size() > 0:
		loot_selection_time -= delta
		timer_label.text = "剩余时间: " + str(int(loot_selection_time) + 1) + "秒"
		if loot_selection_time <= 0:
			_finish_loot_selection()

func _try_auto_collect_loot():
	var soul_system = _get_soul_system()
	if not soul_system:
		return
	
	var username = _get_username()
	var added_souls = []
	
	# 尝试添加所有战利品
	for soul in loot_souls:
		if soul_system.add_soul_print(username, soul.id):
			added_souls.append(soul)
			print("自动获得战利品：", soul.name)
	
	# 从战利品列表中移除已添加的
	for soul in added_souls:
		loot_souls.erase(soul)
	
	# 更新背包数据
	player_all_souls = soul_system.get_user_inventory(username)

func _start_loot_selection():
	timer_label.text = "剩余时间: " + str(int(loot_selection_time) + 1) + "秒"
	timer_label.visible = true
	continue_button.visible = false
	
	# 显示提示
	title_label.text = "背包空间不足！选择要保留的战利品"
	
	_refresh_loot_display()

func _auto_finish_loot():
	auto_finish = true
	title_label.text = "战利品获得完成！"
	timer_label.text = "获得了 " + str(enemy_souls.size()) + " 个战利品"
	timer_label.visible = true
	continue_button.visible = true
	continue_button.text = "继续"
	continue_button.pressed.connect(_finish_loot_selection)

func _refresh_loot_display():
	# 清空现有显示
	for child in loot_container.get_children():
		child.queue_free()
	for child in inventory_container.get_children():
		child.queue_free()
	
	await get_tree().process_frame
	
	# 战利品区域标题
	var loot_label = Label.new()
	loot_label.text = "可获得的战利品（点击获得）："
	loot_label.add_theme_font_size_override("font_size", 16)
	loot_container.add_child(loot_label)
	
	# 战利品网格
	var loot_grid = GridContainer.new()
	loot_grid.columns = 5
	loot_grid.add_theme_constant_override("h_separation", 10)
	loot_grid.add_theme_constant_override("v_separation", 10)
	
	for i in range(loot_souls.size()):
		var soul = loot_souls[i]
		var card = _create_loot_card(soul, true, i)
		loot_grid.add_child(card)
	
	loot_container.add_child(loot_grid)
	
	# 当前背包区域标题
	var inventory_label = Label.new()
	inventory_label.text = "当前背包（点击丢弃）："
	inventory_label.add_theme_font_size_override("font_size", 16)
	inventory_container.add_child(inventory_label)
	
	# 背包网格
	var inventory_grid = GridContainer.new()
	inventory_grid.columns = 5
	inventory_grid.add_theme_constant_override("h_separation", 10)
	inventory_grid.add_theme_constant_override("v_separation", 10)
	
	for i in range(min(10, player_all_souls.size())):
		var soul_item = player_all_souls[i]
		var card = _create_loot_card(soul_item.soul_print, false, i)
		inventory_grid.add_child(card)
	
	inventory_container.add_child(inventory_grid)

func _create_loot_card(soul, is_loot: bool, index: int) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(100, 80)
	
	# 品质颜色
	var quality_colors = [
		Color(0.5, 0.5, 0.5), Color(0.2, 0.7, 0.2), Color(0.2, 0.5, 0.9),
		Color(0.6, 0.2, 0.8), Color(0.9, 0.6, 0.2), Color(0.9, 0.3, 0.3)
	]
	
	var color = quality_colors[soul.quality]
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.8)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	
	button.add_theme_stylebox_override("normal", style)
	
	var quality_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
	button.text = soul.name + "\n力量: " + str(soul.power) + "\n" + quality_names[soul.quality]
	
	if is_loot:
		button.pressed.connect(_on_loot_selected.bind(index))
	else:
		button.pressed.connect(_on_inventory_discard.bind(index))
	
	return button

func _on_loot_selected(loot_index: int):
	if loot_index >= loot_souls.size():
		return
	
	var soul = loot_souls[loot_index]
	var soul_system = _get_soul_system()
	if not soul_system:
		return
	
	var username = _get_username()
	
	# 尝试添加到背包
	if soul_system.add_soul_print(username, soul.id):
		print("获得战利品：", soul.name)
		loot_souls.remove_at(loot_index)
		player_all_souls = soul_system.get_user_inventory(username)
		
		# 检查是否所有战利品都已获得
		if loot_souls.size() == 0:
			_finish_loot_selection()
			return
		
		# 刷新显示
		_refresh_loot_display()
	else:
		print("背包空间不足，无法获得战利品")

func _on_inventory_discard(inventory_index: int):
	if inventory_index >= player_all_souls.size():
		return
	
	var soul_system = _get_soul_system()
	if not soul_system:
		return
	
	var username = _get_username()
	var soul_item = player_all_souls[inventory_index]
	
	print("丢弃魂印：", soul_item.soul_print.name)
	
	# 从背包移除
	soul_system.remove_soul_print(username, inventory_index)
	player_all_souls = soul_system.get_user_inventory(username)
	
	# 刷新显示
	_refresh_loot_display()

func _finish_loot_selection():
	auto_finish = true
	
	# 计算实际获得的战利品
	var obtained_souls = []
	for soul in enemy_souls:
		if not loot_souls.has(soul):  # 不在剩余列表中，说明已获得
			obtained_souls.append(soul)
	
	print("战利品阶段结束，获得", obtained_souls.size(), "个战利品")
	
	# 保存最终战斗结果到UserSession
	var session = get_node("/root/UserSession")
	var combat_result = session.get_meta("combat_result")
	
	session.set_meta("battle_result", {
		"won": true,
		"player_hp_change": combat_result.get("player_hp_change", 0),
		"loot_souls": obtained_souls
	})
	
	# 清除临时数据
	session.remove_meta("combat_result")
	session.remove_meta("battle_enemy_souls")
	
	# 返回地图
	get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _get_soul_system():
	if has_node("/root/SoulPrintSystem"):
		return get_node("/root/SoulPrintSystem")
	return null

func _get_username():
	if has_node("/root/UserSession"):
		return get_node("/root/UserSession").get_username()
	return ""