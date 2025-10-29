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
@onready var battle_log = $BattlePanel/MarginContainer/VBoxContainer/BattleLog

# 战斗数据
var enemy_data: Dictionary = {}
var player_hp: int = 100
var enemy_hp: int = 100
var player_base_power: int = 50
var enemy_base_power: int = 30

# 魂印相关
var player_selected_souls: Array = []  # 玩家选中的魂印
var enemy_souls: Array = []  # 敌人的魂印

var battle_over: bool = false

func _ready():
	# 应用响应式布局
	_setup_responsive_layout()
	
	# 从UserSession获取战斗数据
	var session = get_node("/root/UserSession")
	
	if session.has_meta("battle_enemy_data"):
		enemy_data = session.get_meta("battle_enemy_data")
	if session.has_meta("battle_player_hp"):
		player_hp = session.get_meta("battle_player_hp")
	if session.has_meta("battle_selected_souls"):
		player_selected_souls = session.get_meta("battle_selected_souls")
	if session.has_meta("battle_enemy_souls"):
		enemy_souls = session.get_meta("battle_enemy_souls")
	
	enemy_hp = enemy_data.get("hp", 100)
	enemy_base_power = enemy_data.get("power", 30)
	
	phase_label.text = "战斗回合"
	timer_label.visible = false
	
	_update_display()
	_add_log("[color=#FFFF00]遭遇敌人：" + enemy_data.get("name", "未知敌人") + "！[/color]")
	_add_log("[color=#FFD700]战斗开始！[/color]")
	
	# 延迟开始第一回合
	await get_tree().create_timer(1.0).timeout
	_execute_combat_round()

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		
		# 连接屏幕类型变化信号
		responsive_manager.screen_type_changed.connect(_on_screen_type_changed)
		
		# 应用响应式布局
		responsive_manager.apply_responsive_layout(self)
		
		# 为移动端优化触摸
		responsive_manager.optimize_for_touch(self)
		
		# 根据屏幕类型调整信息布局
		_adjust_info_layout_for_screen(responsive_manager.current_screen_type)
		
		print("战斗阶段已启用响应式布局，屏幕类型：", responsive_manager.get_screen_type_name())

func _on_screen_type_changed(_new_type):
	# 屏幕类型变化时重新应用布局
	_setup_responsive_layout()

func _adjust_info_layout_for_screen(screen_type):
	var info_container = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer
	
	# 在移动端竖屏时将HBoxContainer改为VBoxContainer
	if screen_type == 0:  # MOBILE_PORTRAIT
		# 移动端竖屏时垂直排列信息
		info_container.vertical = true
	else:
		# 其他情况水平排列
		info_container.vertical = false

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

	# 回合开始：触发HEAL被动
	_trigger_heal_passive()
	
	# 计算玩家力量 - 使用力量值加成系统
	var player_soul_power = 0  # 魂印提供的总力量值
	var player_soul_multiplier = 0.0  # 魂印提供的倍率加成
	var player_passive_power_bonus = 0  # 被动提供的额外力量
	var player_passive_mult_bonus = 0.0  # 被动提供的额外倍率

	for soul_item in player_selected_souls:
		var soul = soul_item.soul_print
		player_soul_power += soul.power
		# 根据品质提供额外倍率加成：普通0% 非凡5% 稀有10% 史诗15% 传说20% 神话25%
		var quality_multiplier = soul.quality * 0.05
		player_soul_multiplier += quality_multiplier

		# 触发被动：力量几率
		if soul.passive_type == 2:  # PassiveType.POWER_CHANCE
			if randf() < soul.passive_chance:
				player_passive_power_bonus += int(soul.passive_value)
				_add_log("  [color=#90EE90]✦ " + soul.name + " 被动触发！额外 +" + str(int(soul.passive_value)) + " 力量[/color]")

		# 触发被动：倍率几率
		elif soul.passive_type == 3:  # PassiveType.MULT_CHANCE
			if randf() < soul.passive_chance:
				player_passive_mult_bonus += soul.passive_value
				_add_log("  [color=#90EE90]✦ " + soul.name + " 被动触发！额外 +" + str(int(soul.passive_value * 100)) + "% 倍率[/color]")

	# 最终力量 = (基础力量 + 魂印力量 + 被动力量) × (1 + 倍率加成 + 被动倍率) × 骰子
	var player_base_total = player_base_power + player_soul_power + player_passive_power_bonus
	var player_multiplier_total = 1.0 + player_soul_multiplier + player_passive_mult_bonus
	var player_final = int(player_base_total * player_multiplier_total * dice)

	player_final_power_label.text = "最终力量: " + str(player_final)

	var mult_percent = int(player_soul_multiplier * 100)
	var power_text = str(player_base_power) + "+" + str(player_soul_power)
	if player_passive_power_bonus > 0:
		power_text += "+" + str(player_passive_power_bonus) + "(被动)"

	_add_log("玩家力量：[color=#00FF00](" + power_text + ") × " + str(player_multiplier_total) + " × " + str(dice) + " = " + str(player_final) + "[/color]")
	if mult_percent > 0:
		_add_log("  [color=#90EE90]魂印品质加成: +" + str(mult_percent) + "%[/color]")

	# 计算敌人力量 - 使用相同系统
	var enemy_soul_power = 0
	var enemy_soul_multiplier = 0.0

	for soul in enemy_souls:
		enemy_soul_power += soul.power
		var quality_multiplier = soul.quality * 0.05
		enemy_soul_multiplier += quality_multiplier

	var enemy_base_total = enemy_base_power + enemy_soul_power
	var enemy_multiplier_total = 1.0 + enemy_soul_multiplier
	var enemy_final = int(enemy_base_total * enemy_multiplier_total * dice)

	enemy_final_power_label.text = "最终力量: " + str(enemy_final)

	var enemy_mult_percent = int(enemy_soul_multiplier * 100)
	_add_log("敌人力量：[color=#FF0000](" + str(enemy_base_power) + "+" + str(enemy_soul_power) + ") × " + str(enemy_multiplier_total) + " × " + str(dice) + " = " + str(enemy_final) + "[/color]")
	if enemy_mult_percent > 0:
		_add_log("  [color=#FFB6C1]魂印品质加成: +" + str(enemy_mult_percent) + "%[/color]")
	
	await get_tree().create_timer(1.0).timeout

	# 计算伤害并触发被动
	var damage_diff = abs(player_final - enemy_final)
	var actual_player_damage = damage_diff  # 玩家实际受到的伤害
	var actual_enemy_damage = damage_diff  # 敌人实际受到的伤害

	if player_final > enemy_final:
		# 玩家获胜，对敌人造成伤害

		# 暴击被动
		var crit_bonus = _trigger_crit_passive(actual_enemy_damage)
		actual_enemy_damage += crit_bonus

		enemy_hp -= actual_enemy_damage
		if enemy_hp < 0:
			enemy_hp = 0
		_add_log("[color=#00FF00]玩家获胜！对敌人造成 " + str(actual_enemy_damage) + " 点伤害！[/color]")

		# 吸血被动
		_trigger_vampire_passive(actual_enemy_damage)

	elif enemy_final > player_final:
		# 敌人获胜，玩家受到伤害

		# 闪避被动
		if _trigger_dodge_passive():
			_add_log("[color=#00FF00]✦ 闪避成功！完全躲避了伤害！[/color]")
			actual_player_damage = 0
		else:
			# 护盾被动
			var shield_reduction = _trigger_shield_passive(actual_player_damage)
			actual_player_damage -= shield_reduction

			player_hp -= actual_player_damage
			if player_hp < 0:
				player_hp = 0
			_add_log("[color=#FF0000]敌人获胜！受到 " + str(actual_player_damage) + " 点伤害！[/color]")

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
	var initial_hp = session.get_meta("battle_initial_hp") if session.has_meta("battle_initial_hp") else 100
	
	session.set_meta("combat_result", {
		"won": false,
		"player_hp_change": player_hp - initial_hp,
		"loot_souls": []
	})
	
	# 返回地图
	get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _enemy_defeated():
	battle_over = true
	_add_log("[color=#FFD700]战斗胜利！敌人被击败了！[/color]")
	
	await get_tree().create_timer(2.0).timeout
	
	# 保存战斗结果并跳转到战利品阶段
	var session = get_node("/root/UserSession")
	var initial_hp = session.get_meta("battle_initial_hp") if session.has_meta("battle_initial_hp") else 100
	
	session.set_meta("combat_result", {
		"won": true,
		"player_hp_change": player_hp - initial_hp,
		"player_final_hp": player_hp
	})
	
	# 跳转到战利品选择阶段
	get_tree().change_scene_to_file("res://scenes/LootPhase.tscn")

func _update_display():
	player_hp_label.text = "HP: " + str(player_hp)
	player_power_label.text = "基础力量: " + str(player_base_power)
	enemy_hp_label.text = "HP: " + str(enemy_hp)
	enemy_power_label.text = "基础力量: " + str(enemy_base_power)

	# 更新选中魂印的总加成（力量+倍率）
	var soul_power = 0
	var soul_multiplier = 0.0

	for soul_item in player_selected_souls:
		var soul = soul_item.soul_print
		soul_power += soul.power
		soul_multiplier += soul.quality * 0.05

	var mult_percent = int(soul_multiplier * 100)
	if mult_percent > 0:
		player_final_power_label.text = "魂印: +" + str(soul_power) + " 力量, +" + str(mult_percent) + "% 倍率"
	else:
		player_final_power_label.text = "魂印加成: +" + str(soul_power)

func _add_log(text: String):
	battle_log.text += "\n" + text
	await get_tree().process_frame
	battle_log.scroll_to_line(battle_log.get_line_count())

# ============ 被动效果触发函数 ============

func _trigger_heal_passive():
	# 回血被动：每回合开始时触发
	var total_heal = 0

	for soul_item in player_selected_souls:
		var soul = soul_item.soul_print
		if soul.passive_type == 1:  # PassiveType.HEAL
			var heal_amount = int(soul.passive_value)
			total_heal += heal_amount
			_add_log("  [color=#90EE90]✦ " + soul.name + " 被动：回复 " + str(heal_amount) + " HP[/color]")

	if total_heal > 0:
		player_hp += total_heal
		# 不超过初始HP
		var session = get_node("/root/UserSession")
		var initial_hp = session.get_meta("battle_initial_hp") if session.has_meta("battle_initial_hp") else 100
		if player_hp > initial_hp:
			player_hp = initial_hp
		_update_display()

func _trigger_crit_passive(base_damage: int) -> int:
	# 暴击被动：有几率造成额外伤害
	var bonus_damage = 0

	for soul_item in player_selected_souls:
		var soul = soul_item.soul_print
		if soul.passive_type == 6:  # PassiveType.CRIT_CHANCE
			if randf() < soul.passive_chance:
				var crit_damage = int(base_damage * soul.passive_value)
				bonus_damage += crit_damage
				_add_log("  [color=#FFD700]✦ " + soul.name + " 暴击！额外造成 " + str(crit_damage) + " 点伤害！[/color]")

	return bonus_damage

func _trigger_vampire_passive(damage_dealt: int):
	# 吸血被动：造成伤害时回血
	var total_heal = 0

	for soul_item in player_selected_souls:
		var soul = soul_item.soul_print
		if soul.passive_type == 5:  # PassiveType.VAMPIRE
			var heal_amount = int(damage_dealt * soul.passive_value)
			total_heal += heal_amount
			_add_log("  [color=#90EE90]✦ " + soul.name + " 吸血：回复 " + str(heal_amount) + " HP[/color]")

	if total_heal > 0:
		player_hp += total_heal
		# 不超过初始HP
		var session = get_node("/root/UserSession")
		var initial_hp = session.get_meta("battle_initial_hp") if session.has_meta("battle_initial_hp") else 100
		if player_hp > initial_hp:
			player_hp = initial_hp
		_update_display()

func _trigger_shield_passive(base_damage: int) -> int:
	# 护盾被动：减少受到的伤害
	var total_reduction = 0
	var total_shield_percent = 0.0

	for soul_item in player_selected_souls:
		var soul = soul_item.soul_print
		if soul.passive_type == 4:  # PassiveType.SHIELD
			total_shield_percent += soul.passive_value

	if total_shield_percent > 0:
		total_reduction = int(base_damage * total_shield_percent)
		_add_log("  [color=#87CEEB]✦ 护盾减免 " + str(int(total_shield_percent * 100)) + "%：减少 " + str(total_reduction) + " 点伤害[/color]")

	return total_reduction

func _trigger_dodge_passive() -> bool:
	# 闪避被动：有几率完全躲避伤害
	for soul_item in player_selected_souls:
		var soul = soul_item.soul_print
		if soul.passive_type == 7:  # PassiveType.DODGE
			if randf() < soul.passive_value:
				return true

	return false
