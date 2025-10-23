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
	
	# 更新选中魂印的总加成
	var total_bonus = 0
	for soul_item in player_selected_souls:
		total_bonus += soul_item.soul_print.power
	
	player_final_power_label.text = "魂印加成: +" + str(total_bonus)

func _add_log(text: String):
	battle_log.text += "\n" + text
	await get_tree().process_frame
	battle_log.scroll_to_line(battle_log.get_line_count())