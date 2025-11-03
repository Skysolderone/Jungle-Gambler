extends Control

# 战斗场景 - 回合制战斗逻辑

@onready var phase_label: Label = $BattlePanel/MarginContainer/VBoxContainer/PhaseLabel
@onready var player_hp_label: Label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/PlayerInfo/PlayerHP
@onready var player_power_label: Label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/PlayerInfo/PlayerPower
@onready var player_dice_label: Label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/PlayerInfo/PlayerDice
@onready var player_final_power_label: Label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/PlayerInfo/PlayerFinalPower
@onready var enemy_hp_label: Label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/EnemyInfo/EnemyHP
@onready var enemy_power_label: Label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/EnemyInfo/EnemyPower
@onready var enemy_dice_label: Label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/EnemyInfo/EnemyDice
@onready var enemy_final_power_label: Label = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/EnemyInfo/EnemyFinalPower
@onready var battle_log: RichTextLabel = $BattlePanel/MarginContainer/VBoxContainer/BattleLog

# 动画管理器
var battle_animator: BattleAnimator

# 战斗数据
var enemy_data: Dictionary = {}
var player_hp: int = 100
var enemy_hp: int = 100
var player_base_power: int = 50
var enemy_base_power: int = 30

# 魂印相关
var player_selected_souls: Array = [] # 玩家选中的魂印
var enemy_souls: Array = [] # 敌人的魂印

# 战斗状态
var battle_over: bool = false
var initial_player_hp: int = 100

func _ready():
	# 初始化动画管理器
	battle_animator = BattleAnimator.new()
	add_child(battle_animator)

	# 应用响应式布局
	_setup_responsive_layout()

	# 从 UserSession 获取战斗数据
	var session = get_node("/root/UserSession")

	if session.has_meta("battle_enemy_data"):
		enemy_data = session.get_meta("battle_enemy_data")
	if session.has_meta("battle_player_hp"):
		player_hp = session.get_meta("battle_player_hp")
		initial_player_hp = player_hp
	if session.has_meta("battle_selected_souls"):
		player_selected_souls = session.get_meta("battle_selected_souls")
	if session.has_meta("battle_enemy_souls"):
		enemy_souls = session.get_meta("battle_enemy_souls")

	enemy_hp = enemy_data.get("hp", 100)
	enemy_base_power = enemy_data.get("power", 30)

	_update_display()
	_add_log("[color=#FFFF00]━━━ 战斗开始 ━━━[/color]")
	_add_log("[color=#00FF00]遭遇敌人：" + enemy_data.get("name", "未知敌人") + "！[/color]")

	# 显示玩家配置的魂印信息
	if player_selected_souls.size() > 0:
		_add_log("[color=#FFFF00]━━━ 你的魂印配置 ━━━[/color]")
		var total_soul_power = 0
		for soul_item in player_selected_souls:
			var soul = soul_item.soul_print
			total_soul_power += soul.power
			var quality_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
			var quality_name = quality_names[soul.quality]
			_add_log("[color=#FFD700]" + soul.name + "[/color] (" + quality_name + ") - 力量加成: [color=#FF6600]+" + str(soul.power) + "[/color]")
		_add_log("[color=#00FFFF]总魂印加成: +" + str(total_soul_power) + " 点力量！[/color]")
	else:
		_add_log("[color=#888888]未配置任何魂印，仅依靠基础力量战斗[/color]")

	# 延迟开始第一回合
	await get_tree().create_timer(1.0).timeout
	_execute_combat_round()

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		responsive_manager.apply_responsive_layout(self)
		responsive_manager.optimize_for_touch(self)

func _execute_combat_round():
	if battle_over:
		return

	_add_log("[color=#FFFF00]━━━ 新回合 ━━━[/color]")

	# 1. 骰子滚动动画
	var viewport_size = get_viewport_rect().size
	var dice_pos = viewport_size / 2.0
	var dice = await battle_animator.play_dice_roll(dice_pos)

	player_dice_label.text = "骰子: " + str(dice)
	enemy_dice_label.text = "骰子: " + str(dice)
	_add_log("掷出骰子：[color=#FFD700]" + str(dice) + "[/color]（双方共用）")

	await get_tree().create_timer(0.5).timeout

	# 2. 玩家魂印激活动画
	var player_soul_effects = []
	for soul_item in player_selected_souls:
		var soul = soul_item.soul_print
		player_soul_effects.append({
			"name": soul.name,
			"power": soul.power,
			"quality": soul.quality
		})

		# 播放魂印激活特效
		var soul_pos = Vector2(viewport_size.x * 0.3, viewport_size.y * 0.5)
		battle_animator.play_soul_activation(soul.name, soul_pos, soul.quality)
		await get_tree().create_timer(0.3).timeout

	# 3. 计算玩家力量（新公式）
	# 基础伤害 = 基础力量 × 骰子
	var player_base_damage = player_base_power * dice

	# 应用主动魂印效果
	var player_damage_after_active = float(player_base_damage)
	var player_active_souls = []
	var player_passive_souls = []

	# 分类魂印
	for soul_item in player_selected_souls:
		var soul = soul_item.soul_print
		if soul.soul_type == 0: # ACTIVE
			player_active_souls.append(soul)
		else: # PASSIVE
			player_passive_souls.append(soul)

	# 应用主动魂印
	for soul in player_active_souls:
		if soul.active_multiplier > 0:
			player_damage_after_active *= soul.active_multiplier
			_add_log("[color=#FFD700]主动效果：" + soul.name + " %.1fx 倍率[/color]" % soul.active_multiplier)
		if soul.active_bonus_percent > 0:
			player_damage_after_active *= (1.0 + soul.active_bonus_percent)
			_add_log("[color=#FFD700]主动效果：" + soul.name + " +%d%% 伤害[/color]" % int(soul.active_bonus_percent * 100))

	# 应用被动魂印（随机触发）
	var player_passive_bonus = 0
	var triggered_passives = []
	for soul in player_passive_souls:
		var random_value = randf()
		if random_value < soul.passive_trigger_chance:
			triggered_passives.append(soul)
			player_passive_bonus += soul.passive_bonus_flat
			if soul.passive_bonus_multiplier > 0:
				player_damage_after_active *= soul.passive_bonus_multiplier

			# 记录触发的被动效果
			var effect_desc = "[color=#00FFFF]被动触发：" + soul.name
			if soul.passive_bonus_flat > 0:
				effect_desc += " +%d 伤害" % soul.passive_bonus_flat
			if soul.passive_bonus_multiplier > 0:
				effect_desc += " %.1fx 暴击" % soul.passive_bonus_multiplier
			effect_desc += "[/color]"
			_add_log(effect_desc)

	# 最终伤害
	var player_final = int(player_damage_after_active) + player_passive_bonus
	player_final_power_label.text = str(player_final)

	# 4. 播放玩家积分计算动画
	var player_calc_pos = Vector2(viewport_size.x * 0.25, viewport_size.y * 0.3)
	battle_animator.play_score_calculation(
		player_base_power,
		dice,
		player_soul_effects,
		player_final,
		player_calc_pos
	)

	# 输出计算过程
	_add_log("[color=#00FF00]玩家伤害计算：[/color]")
	_add_log("  基础：%d × %d = %d" % [player_base_power, dice, player_base_damage])
	if player_active_souls.size() > 0:
		_add_log("  主动魂印效果已应用（%d 个）" % player_active_souls.size())
	if triggered_passives.size() > 0:
		_add_log("  被动触发成功（%d/%d 个）" % [triggered_passives.size(), player_passive_souls.size()])
	_add_log("  [color=#FFFF00]最终伤害：%d[/color]" % player_final)

	# 等待玩家计算动画完成
	await battle_animator.animation_completed

	# 5. 计算敌人力量（新公式）
	var enemy_soul_effects = []
	var enemy_base_damage = enemy_base_power * dice

	# 应用主动魂印效果
	var enemy_damage_after_active = float(enemy_base_damage)
	var enemy_active_souls = []
	var enemy_passive_souls = []

	# 分类魂印
	for soul in enemy_souls:
		if soul.soul_type == 0: # ACTIVE
			enemy_active_souls.append(soul)
		else: # PASSIVE
			enemy_passive_souls.append(soul)

		enemy_soul_effects.append({
			"name": soul.name,
			"power": soul.power,
			"quality": soul.quality
		})

	# 应用主动魂印
	for soul in enemy_active_souls:
		if soul.active_multiplier > 0:
			enemy_damage_after_active *= soul.active_multiplier
		if soul.active_bonus_percent > 0:
			enemy_damage_after_active *= (1.0 + soul.active_bonus_percent)

	# 应用被动魂印（随机触发）
	var enemy_passive_bonus = 0
	for soul in enemy_passive_souls:
		var random_value = randf()
		if random_value < soul.passive_trigger_chance:
			enemy_passive_bonus += soul.passive_bonus_flat
			if soul.passive_bonus_multiplier > 0:
				enemy_damage_after_active *= soul.passive_bonus_multiplier

	# 最终伤害
	var enemy_final = int(enemy_damage_after_active) + enemy_passive_bonus
	enemy_final_power_label.text = str(enemy_final)

	# 6. 播放敌人积分计算动画
	var enemy_calc_pos = Vector2(viewport_size.x * 0.75, viewport_size.y * 0.3)
	battle_animator.play_score_calculation(
		enemy_base_power,
		dice,
		enemy_soul_effects,
		enemy_final,
		enemy_calc_pos
	)

	_add_log("[color=#FF0000]敌人伤害计算：[/color]")
	_add_log("  基础：%d × %d = %d" % [enemy_base_power, dice, enemy_base_damage])
	_add_log("  [color=#FFAA00]最终伤害：%d[/color]" % enemy_final)

	# 等待敌人计算动画完成
	await battle_animator.animation_completed

	await get_tree().create_timer(0.5).timeout

	# 7. 计算伤害并播放伤害动画
	var damage_diff = abs(player_final - enemy_final)

	if player_final > enemy_final:
		enemy_hp -= damage_diff
		if enemy_hp < 0:
			enemy_hp = 0

		_add_log("[color=#00FF00]玩家获胜！对敌人造成 " + str(damage_diff) + " 点伤害！[/color]")

		# 敌人受伤动画
		var enemy_pos = Vector2(viewport_size.x * 0.75, viewport_size.y * 0.5)
		battle_animator.play_damage_number(damage_diff, enemy_pos, damage_diff > 100)
		battle_animator.play_screen_shake(min(damage_diff / 10.0, 15.0), 0.3)

	elif enemy_final > player_final:
		player_hp -= damage_diff
		if player_hp < 0:
			player_hp = 0

		_add_log("[color=#FF0000]敌人获胜！受到 " + str(damage_diff) + " 点伤害！[/color]")

		# 玩家受伤动画
		var player_pos = Vector2(viewport_size.x * 0.25, viewport_size.y * 0.5)
		battle_animator.play_damage_number(damage_diff, player_pos, false)
		battle_animator.play_screen_shake(min(damage_diff / 10.0, 15.0), 0.3)

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

	# 播放失败动画
	var viewport_size = get_viewport_rect().size
	await battle_animator.play_defeat_animation(viewport_size / 2.0)

	await get_tree().create_timer(1.0).timeout

	# 保存战斗结果到 UserSession
	var session = get_node("/root/UserSession")

	session.set_meta("battle_result", {
		"won": false,
		"player_hp_change": player_hp - initial_player_hp,
		"final_player_hp": player_hp
	})

	# 返回地图
	get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _enemy_defeated():
	battle_over = true
	_add_log("[color=#FFD700]战斗胜利！敌人被击败了！[/color]")

	# 播放胜利动画
	var viewport_size = get_viewport_rect().size
	await battle_animator.play_victory_animation(viewport_size / 2.0)

	await get_tree().create_timer(1.0).timeout

	# 保存战斗数据供胜利场景使用
	var session = get_node("/root/UserSession")

	session.set_meta("battle_result", {
		"won": true,
		"player_hp_change": player_hp - initial_player_hp,
		"final_player_hp": player_hp
	})

	# 战利品是敌人的魂印
	session.set_meta("battle_loot_souls", enemy_souls.duplicate())

	# 跳转到胜利场景
	get_tree().change_scene_to_file("res://scenes/BattleVictory.tscn")

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
