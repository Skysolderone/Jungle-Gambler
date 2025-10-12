extends Control

@onready var phase_label = $BattlePanel/MarginContainer/VBoxContainer/PhaseLabel
@onready var timer_label = $BattlePanel/MarginContainer/VBoxContainer/TimerLabel
@onready var player_hp_label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/PlayerInfo/PlayerHP
@onready var player_power_label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/PlayerInfo/PlayerPower
@onready var player_dice_label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/PlayerInfo/PlayerDice
@onready var player_final_power_label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/PlayerInfo/PlayerFinalPower
@onready var enemy_hp_label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/EnemyInfo/EnemyHP
@onready var enemy_power_label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/EnemyInfo/EnemyPower
@onready var enemy_dice_label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/EnemyInfo/EnemyDice
@onready var enemy_final_power_label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/EnemyInfo/EnemyFinalPower
@onready var loadout_grid = $BattlePanel/MarginContainer/VBoxContainer/LoadoutContainer/LoadoutScroll/LoadoutGrid
@onready var battle_log = $BattlePanel/MarginContainer/VBoxContainer/BattleLog
@onready var message_dialog = $MessageDialog

# 战斗阶段
enum Phase {
	PREPARATION,  # 准备阶段（配置魂印）
	COMBAT,       # 战斗回合
	LOOT          # 战利品选择
}

# 战斗数据
var enemy_data: Dictionary = {}
var player_hp: int = 100
var enemy_hp: int = 100
var player_base_power: int = 50
var enemy_base_power: int = 30

# 魂印相关
var player_all_souls: Array = []  # 玩家所有魂印
var player_selected_souls: Array = []  # 玩家选中的魂印
var enemy_souls: Array = []  # 敌人的魂印

# 当前阶段
var current_phase: Phase = Phase.PREPARATION
var countdown: float = 10.0
var battle_over: bool = false

# 战利品选择
var loot_souls: Array = []
var loot_selection_time: float = 10.0

func _ready():
	# 从UserSession获取战斗数据
	var session = get_node("/root/UserSession")
	
	if session.has_meta("battle_enemy_data"):
		enemy_data = session.get_meta("battle_enemy_data")
	if session.has_meta("battle_player_hp"):
		player_hp = session.get_meta("battle_player_hp")
	if session.has_meta("battle_player_souls"):
		player_all_souls = session.get_meta("battle_player_souls")
	if session.has_meta("battle_enemy_souls"):
		enemy_souls = session.get_meta("battle_enemy_souls")
	
	enemy_hp = enemy_data.get("hp", 100)
	enemy_base_power = enemy_data.get("power", 30)
	
	_initialize_loadout()
	_update_display()
	_add_log("[color=#FFFF00]遭遇敌人：" + enemy_data.get("name", "未知敌人") + "！[/color]")
	_add_log("[color=#00FF00]配置阶段：选择你要使用的魂印！[/color]")

func _process(delta):
	if battle_over:
		return
	
	if current_phase == Phase.PREPARATION:
		countdown -= delta
		timer_label.text = str(int(countdown) + 1)
		if countdown <= 0:
			_start_combat_phase()
	elif current_phase == Phase.LOOT:
		loot_selection_time -= delta
		timer_label.text = str(int(loot_selection_time) + 1)
		if loot_selection_time <= 0:
			print("战利品选择时间到，强制结束")
			battle_over = true
			_finish_loot_selection()

func _initialize_loadout():
	# 清空网格
	for child in loadout_grid.get_children():
		child.queue_free()
	
	# 创建魂印选择卡片
	for i in range(player_all_souls.size()):
		var soul_item = player_all_souls[i]
		var soul = soul_item.soul_print
		var card = _create_soul_card(soul, i)
		loadout_grid.add_child(card)

func _create_soul_card(soul, index: int) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(120, 60)
	
	# 品质颜色
	var quality_colors = [
		Color(0.5, 0.5, 0.5),    # 普通
		Color(0.2, 0.7, 0.2),    # 非凡
		Color(0.2, 0.5, 0.9),    # 稀有
		Color(0.6, 0.2, 0.8),    # 史诗
		Color(0.9, 0.6, 0.2),    # 传说
		Color(0.9, 0.3, 0.3)     # 神话
	]
	
	var color = quality_colors[soul.quality]
	
	# 设置按钮样式
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.8)
	style_normal.border_color = color
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(5)
	
	var style_selected = StyleBoxFlat.new()
	style_selected.bg_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 1.0)
	style_selected.border_color = Color(1, 1, 0, 1)
	style_selected.set_border_width_all(3)
	style_selected.set_corner_radius_all(5)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_selected)
	button.add_theme_stylebox_override("pressed", style_selected)
	
	button.text = soul.name + "\n力量+" + str(soul.power)
	button.pressed.connect(_on_soul_card_pressed.bind(index))
	
	return button

func _on_soul_card_pressed(index: int):
	if current_phase != Phase.PREPARATION:
		return
	
	var soul_item = player_all_souls[index]
	
	if player_selected_souls.has(soul_item):
		player_selected_souls.erase(soul_item)
		_add_log("[color=#FFAA00]取消选择：" + soul_item.soul_print.name + "[/color]")
	else:
		player_selected_souls.append(soul_item)
		_add_log("[color=#00FF00]选择魂印：" + soul_item.soul_print.name + " (+" + str(soul_item.soul_print.power) + ")[/color]")
	
	_update_display()

func _start_combat_phase():
	current_phase = Phase.COMBAT
	phase_label.text = "战斗回合"
	timer_label.visible = false
	_add_log("[color=#FFD700]准备阶段结束！开始战斗！[/color]")
	
	# 延迟开始第一回合
	await get_tree().create_timer(1.0).timeout
	_execute_combat_round()

func _execute_combat_round():
	if battle_over:
		return
	
	# 掷一个共用骰子
	var dice = randi() % 6 + 1
	
	player_dice_label.text = "骰子: " + str(dice)
	enemy_dice_label.text = "骰子: " + str(dice)
	
	_add_log("[color=#FFFF00]━━━ 新回合 ━━━[/color]")
	_add_log("掷出骰子：[color=#FFD700]" + str(dice) + "[/color]（双方共用）")
	
	await get_tree().create_timer(1.0).timeout
	
	# 计算玩家力量
	var player_soul_bonus = 0
	for soul_item in player_selected_souls:
		player_soul_bonus += soul_item.soul_print.power
	
	var player_final = player_base_power * dice + player_soul_bonus
	player_final_power_label.text = "最终力量: " + str(player_final)
	
	_add_log("玩家力量：[color=#00FF00]" + str(player_base_power) + " × " + str(dice) + " + " + str(player_soul_bonus) + " = " + str(player_final) + "[/color]")
	
	# 计算敌人力量
	var enemy_soul_bonus = 0
	for soul in enemy_souls:
		enemy_soul_bonus += soul.power
	
	var enemy_final = enemy_base_power * dice + enemy_soul_bonus
	enemy_final_power_label.text = "最终力量: " + str(enemy_final)
	
	_add_log("敌人力量：[color=#FF0000]" + str(enemy_base_power) + " × " + str(dice) + " + " + str(enemy_soul_bonus) + " = " + str(enemy_final) + "[/color]")
	
	await get_tree().create_timer(1.0).timeout
	
	# 计算伤害
	var damage_diff = abs(player_final - enemy_final)
	
	if player_final > enemy_final:
		enemy_hp -= damage_diff
		if enemy_hp < 0:
			enemy_hp = 0
		_add_log("[color=#00FF00]玩家获胜！对敌人造成 " + str(damage_diff) + " 点伤害！[/color]")
	elif enemy_final > player_final:
		player_hp -= damage_diff
		if player_hp < 0:
			player_hp = 0
		_add_log("[color=#FF0000]敌人获胜！受到 " + str(damage_diff) + " 点伤害！[/color]")
	else:
		_add_log("[color=#FFFF00]平局！双方均未受伤！[/color]")
	
	_update_display()
	
	await get_tree().create_timer(1.5).timeout
	
	# 检查战斗结果
	if player_hp <= 0:
		_player_defeated()
	elif enemy_hp <= 0:
		_enemy_defeated()
	else:
		_execute_combat_round()

func _player_defeated():
	battle_over = true
	_add_log("[color=#808080]战斗失败！你被击败了...[/color]")
	
	await get_tree().create_timer(2.0).timeout
	
	# 保存战斗结果到UserSession
	var session = get_node("/root/UserSession")
	var initial_hp = session.get_meta("battle_player_hp") if session.has_meta("battle_player_hp") else 100
	
	session.set_meta("battle_result", {
		"won": false,
		"player_hp_change": player_hp - initial_hp,
		"loot_souls": []
	})
	
	# 返回地图
	get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _enemy_defeated():
	battle_over = true
	_add_log("[color=#FFD700]战斗胜利！敌人被击败了！[/color]")
	_add_log("[color=#00FF00]获得敌人的魂印！[/color]")
	
	await get_tree().create_timer(2.0).timeout
	
	# 检查背包空间
	var soul_system = _get_soul_system()
	if not soul_system:
		print("无法获取SoulPrintSystem")
		_finish_battle_success()
		return
	
	var username = _get_username()
	loot_souls = enemy_souls.duplicate()
	
	print("战利品数量：", loot_souls.size())
	
	# 先尝试直接添加所有战利品
	var added_souls = []
	for soul in loot_souls:
		if soul_system.add_soul_print(username, soul.id):
			added_souls.append(soul)
			_add_log("[color=#00FF00]获得：" + soul.name + "[/color]")
			print("成功添加战利品：", soul.name)
	
	# 从战利品列表中移除已添加的
	for soul in added_souls:
		loot_souls.erase(soul)
	
	print("剩余战利品数量：", loot_souls.size())
	
	# 如果还有剩余战利品，进入选择阶段
	if loot_souls.size() > 0:
		_add_log("[color=#FFAA00]背包空间不足！剩余 " + str(loot_souls.size()) + " 个战利品[/color]")
		battle_over = false  # 重新设置为false，允许进入选择阶段
		_start_loot_selection()
	else:
		_finish_battle_success()

func _start_loot_selection():
	current_phase = Phase.LOOT
	phase_label.text = "战利品选择（背包已满）"
	timer_label.visible = true
	loot_selection_time = 10.0
	
	_add_log("[color=#FFAA00]背包空间不足！你有10秒丢弃旧魂印来获取新魂印！[/color]")
	
	# 清空当前显示
	for child in loadout_grid.get_children():
		child.queue_free()
	
	# 显示战利品和当前背包
	var container = VBoxContainer.new()
	container.name = "LootContainer"
	
	# 战利品区域
	var loot_label = Label.new()
	loot_label.text = "战利品（可获得）："
	loot_label.add_theme_font_size_override("font_size", 16)
	container.add_child(loot_label)
	
	var loot_grid = GridContainer.new()
	loot_grid.columns = 5
	loot_grid.add_theme_constant_override("h_separation", 10)
	loot_grid.add_theme_constant_override("v_separation", 10)
	
	for soul in loot_souls:
		var card = _create_loot_card(soul, true)
		loot_grid.add_child(card)
	
	container.add_child(loot_grid)
	
	# 当前背包区域
	var inventory_label = Label.new()
	inventory_label.text = "\n当前背包（点击丢弃）："
	inventory_label.add_theme_font_size_override("font_size", 16)
	container.add_child(inventory_label)
	
	var inventory_grid = GridContainer.new()
	inventory_grid.columns = 5
	inventory_grid.add_theme_constant_override("h_separation", 10)
	inventory_grid.add_theme_constant_override("v_separation", 10)
	
	for i in range(min(10, player_all_souls.size())):
		var soul_item = player_all_souls[i]
		var card = _create_loot_card(soul_item.soul_print, false, i)
		inventory_grid.add_child(card)
	
	container.add_child(inventory_grid)
	
	loadout_grid.add_child(container)

func _create_loot_card(soul, is_loot: bool, inventory_index: int = -1) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(100, 70)
	
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
	button.text = soul.name + "\n+" + str(soul.power)
	
	if not is_loot:
		button.pressed.connect(_on_discard_soul.bind(inventory_index))
	
	return button

func _on_discard_soul(index: int):
	if current_phase != Phase.LOOT:
		return
	
	print("尝试丢弃魂印索引：", index)
	
	var soul_system = _get_soul_system()
	if not soul_system:
		print("无法获取SoulPrintSystem")
		return
	
	var username = _get_username()
	
	# 重新获取当前背包（可能已经变化）
	player_all_souls = soul_system.get_user_inventory(username)
	
	if index >= player_all_souls.size():
		print("索引越界：", index, " >= ", player_all_souls.size())
		return
	
	var soul_item = player_all_souls[index]
	_add_log("[color=#FF5555]丢弃魂印：" + soul_item.soul_print.name + "[/color]")
	
	# 从背包移除
	var removed = soul_system.remove_soul_print(username, index)
	print("移除结果：", removed)
	
	# 尝试添加一个战利品
	if loot_souls.size() > 0:
		var soul_to_add = loot_souls[0]
		if soul_system.add_soul_print(username, soul_to_add.id):
			_add_log("[color=#00FF00]获得战利品：" + soul_to_add.name + "[/color]")
			loot_souls.remove_at(0)
			print("成功添加战利品，剩余：", loot_souls.size())
			
			# 检查是否所有战利品都已获得
			if loot_souls.size() == 0:
				_add_log("[color=#FFD700]所有战利品已获得！返回地图...[/color]")
				battle_over = true
				await get_tree().create_timer(1.0).timeout
				_finish_battle_success()
				return  # 重要：立即返回，不要继续执行
		else:
			print("添加战利品失败，背包仍然满")
	
	# 刷新显示
	_refresh_loot_display()

func _refresh_loot_display():
	if battle_over:
		return  # 战斗已结束，不要刷新显示
	
	# 重新生成战利品显示
	for child in loadout_grid.get_children():
		child.queue_free()
	
	# 检查节点是否还在树中
	if not is_inside_tree():
		return
	
	await get_tree().process_frame
	
	# 再次检查
	if not is_inside_tree() or battle_over:
		return
	
	var soul_system = _get_soul_system()
	if soul_system:
		player_all_souls = soul_system.get_user_inventory(_get_username())
	
	# 检查 loadout_grid 是否有效
	if not is_instance_valid(loadout_grid):
		return
	
	# 重新创建显示
	var container = VBoxContainer.new()
	
	# 战利品区域
	if loot_souls.size() > 0:
		var loot_label = Label.new()
		loot_label.text = "剩余战利品（可获得）："
		loot_label.add_theme_font_size_override("font_size", 16)
		container.add_child(loot_label)
		
		var loot_grid = GridContainer.new()
		loot_grid.columns = 5
		loot_grid.add_theme_constant_override("h_separation", 10)
		loot_grid.add_theme_constant_override("v_separation", 10)
		
		for soul in loot_souls:
			var card = _create_loot_card(soul, true)
			loot_grid.add_child(card)
		
		container.add_child(loot_grid)
	
	# 当前背包区域
	var inventory_label = Label.new()
	inventory_label.text = "\n当前背包（点击丢弃）："
	inventory_label.add_theme_font_size_override("font_size", 16)
	container.add_child(inventory_label)
	
	var inventory_grid = GridContainer.new()
	inventory_grid.columns = 5
	inventory_grid.add_theme_constant_override("h_separation", 10)
	inventory_grid.add_theme_constant_override("v_separation", 10)
	
	for i in range(min(10, player_all_souls.size())):
		var soul_item = player_all_souls[i]
		var card = _create_loot_card(soul_item.soul_print, false, i)
		inventory_grid.add_child(card)
	
	container.add_child(inventory_grid)
	
	loadout_grid.add_child(container)

func _finish_loot_selection():
	print("战利品选择结束，剩余战利品：", loot_souls.size())
	_add_log("[color=#FFAA00]时间到！剩余战利品未获得。[/color]")
	
	await get_tree().create_timer(1.0).timeout
	_finish_battle_success()

func _finish_battle_success():
	print("_finish_battle_success 被调用")
	
	# 保存战斗结果到UserSession
	var session = get_node("/root/UserSession")
	var initial_hp = session.get_meta("battle_player_hp") if session.has_meta("battle_player_hp") else 100
	
	# 计算实际获得的战利品（已经在背包中的）
	var obtained_souls = []
	for soul in enemy_souls:
		if not loot_souls.has(soul):  # 不在剩余列表中，说明已获得
			obtained_souls.append(soul)
	
	print("实际获得的战利品数量：", obtained_souls.size())
	
	session.set_meta("battle_result", {
		"won": true,
		"player_hp_change": player_hp - initial_hp,
		"loot_souls": obtained_souls
	})
	
	print("返回地图场景")
	# 返回地图
	get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _update_display():
	player_hp_label.text = "HP: " + str(player_hp)
	player_power_label.text = "基础力量: " + str(player_base_power)
	enemy_hp_label.text = "HP: " + str(enemy_hp)
	enemy_power_label.text = "基础力量: " + str(enemy_base_power)
	
	# 更新选中魂印的总加成
	var total_bonus = 0
	for soul_item in player_selected_souls:
		total_bonus += soul_item.soul_print.power
	
	if current_phase == Phase.PREPARATION:
		player_final_power_label.text = "魂印加成: +" + str(total_bonus)

func _add_log(text: String):
	battle_log.text += "\n" + text
	await get_tree().process_frame
	battle_log.scroll_to_line(battle_log.get_line_count())

func _get_soul_system():
	if has_node("/root/SoulPrintSystem"):
		return get_node("/root/SoulPrintSystem")
	return null

func _get_username():
	if has_node("/root/UserSession"):
		return get_node("/root/UserSession").get_username()
	return ""

func _on_message_confirmed():
	pass
