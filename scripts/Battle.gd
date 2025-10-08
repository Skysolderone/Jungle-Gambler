extends Control

@onready var enemy_name_label = $BattlePanel/MarginContainer/VBoxContainer/EnemyInfo/EnemyName
@onready var enemy_hp_label = $BattlePanel/MarginContainer/VBoxContainer/EnemyInfo/EnemyHP
@onready var enemy_power_label = $BattlePanel/MarginContainer/VBoxContainer/EnemyInfo/EnemyPower
@onready var player_hp_label = $BattlePanel/MarginContainer/VBoxContainer/PlayerInfo/PlayerHP
@onready var player_power_label = $BattlePanel/MarginContainer/VBoxContainer/PlayerInfo/PlayerPower
@onready var battle_log = $BattlePanel/MarginContainer/VBoxContainer/BattleLog
@onready var attack_button = $BattlePanel/MarginContainer/VBoxContainer/ButtonContainer/AttackButton
@onready var flee_button = $BattlePanel/MarginContainer/VBoxContainer/ButtonContainer/FleeButton

signal battle_finished(result: Dictionary)

var enemy_data: Dictionary = {}
var player_power: int = 0
var player_hp: int = 100
var initial_player_hp: int = 100  # 记录初始HP
var current_enemy_hp: int = 100
var battle_over: bool = false

func _ready():
	# 从meta中获取数据
	if has_meta("enemy_data"):
		enemy_data = get_meta("enemy_data")
	if has_meta("player_power"):
		player_power = get_meta("player_power")
	if has_meta("player_hp"):
		player_hp = get_meta("player_hp")
	
	initial_player_hp = player_hp  # 记录初始血量
	current_enemy_hp = enemy_data.get("hp", 100)
	
	_update_display()
	_add_log("[color=#FFFF00]遭遇敌人：" + enemy_data.get("name", "未知敌人") + "！[/color]")

func _update_display():
	enemy_name_label.text = "敌人: " + enemy_data.get("name", "未知")
	enemy_hp_label.text = "生命值: " + str(current_enemy_hp) + "/" + str(enemy_data.get("hp", 100))
	enemy_power_label.text = "攻击力: " + str(enemy_data.get("power", 10))
	
	player_hp_label.text = "生命值: " + str(player_hp)
	player_power_label.text = "攻击力: " + str(player_power)

func _add_log(text: String):
	battle_log.text += "\n" + text
	# 滚动到底部
	await get_tree().process_frame
	battle_log.scroll_to_line(battle_log.get_line_count())

func _on_attack_button_pressed():
	if battle_over:
		return
	
	# 玩家攻击
	var damage_to_enemy = player_power
	current_enemy_hp -= damage_to_enemy
	_add_log("[color=#00FF00]你对敌人造成了 " + str(damage_to_enemy) + " 点伤害！[/color]")
	_update_display()
	
	# 检查敌人是否被击败
	if current_enemy_hp <= 0:
		_add_log("[color=#FFD700]战斗胜利！敌人被击败了！[/color]")
		battle_over = true
		_finish_battle(true)
		return
	
	# 敌人反击
	await get_tree().create_timer(0.5).timeout
	var damage_to_player = enemy_data.get("power", 10)
	player_hp -= damage_to_player
	_add_log("[color=#FF0000]敌人对你造成了 " + str(damage_to_player) + " 点伤害！[/color]")
	_update_display()
	
	# 检查玩家是否被击败
	if player_hp <= 0:
		_add_log("[color=#808080]战斗失败！你被击败了...[/color]")
		battle_over = true
		_finish_battle(false)
		return

func _on_flee_button_pressed():
	if battle_over:
		return
	
	# 逃跑成功率50%
	var flee_success = randf() > 0.5
	
	if flee_success:
		_add_log("[color=#FFFF00]逃跑成功！但无法收集此格子的资源。[/color]")
		battle_over = true
		_finish_battle(false, true)
	else:
		_add_log("[color=#FF0000]逃跑失败！[/color]")
		# 敌人攻击
		await get_tree().create_timer(0.5).timeout
		var damage_to_player = enemy_data.get("power", 10)
		player_hp -= damage_to_player
		_add_log("[color=#FF0000]敌人对你造成了 " + str(damage_to_player) + " 点伤害！[/color]")
		_update_display()
		
		# 检查玩家是否被击败
		if player_hp <= 0:
			_add_log("[color=#808080]战斗失败！你被击败了...[/color]")
			battle_over = true
			_finish_battle(false)

func _finish_battle(won: bool, fled: bool = false):
	# 禁用按钮
	attack_button.disabled = true
	flee_button.disabled = true
	
	# 延迟关闭战斗场景
	await get_tree().create_timer(1.5).timeout
	
	# 计算HP变化量（当前HP - 初始HP）
	var hp_change = player_hp - initial_player_hp
	
	# 发送战斗结果
	var result = {
		"won": won and not fled,
		"player_hp_change": hp_change,
		"fled": fled
	}
	
	battle_finished.emit(result)
	queue_free()

