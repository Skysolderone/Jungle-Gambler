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

# 动画管理器
var battle_animator: BattleAnimator

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
var active_souls_used_in_battle: Dictionary = {}  # 战斗中已使用的主动魂印次数 {soul_id: use_count}

# 当前阶段
var current_phase: Phase = Phase.PREPARATION
var countdown: float = 10.0
var battle_over: bool = false

# 战利品选择
var loot_souls: Array = []
var loot_selection_time: float = 10.0

func _ready():
	# 初始化动画管理器
	battle_animator = BattleAnimator.new()
	add_child(battle_animator)

	# 应用响应式布局
	_setup_responsive_layout()

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
	
	# 直接使用 SoulLoadout 配置的魂印，不需要再次选择
	player_selected_souls = player_all_souls.duplicate()

	_initialize_loadout()
	_update_display()
	_add_log("[color=#FFFF00]遭遇敌人：" + enemy_data.get("name", "未知敌人") + "！[/color]")
	_add_log("[color=#00FF00]━━━ 战斗开始 ━━━[/color]")
	if player_selected_souls.size() == 0:
		_add_log("[color=#FF6666]警告：你没有配置任何魂印！只能依靠基础力量战斗[/color]")
	else:
		_add_log("[color=#AAFFAA]已配置魂印：" + str(player_selected_souls.size()) + " 个[/color]")
		_add_log("[color=#FFD700]点击底部主动魂印可使用技能（消耗次数）[/color]")

	# 直接开始战斗，不需要准备阶段
	current_phase = Phase.COMBAT
	phase_label.text = "战斗回合"
	timer_label.visible = false

	# 延迟1秒后开始第一回合
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
		
		# 根据屏幕类型调整布局
		_adjust_battle_layout_for_screen(responsive_manager.current_screen_type)
		
		print("战斗场景已启用响应式布局，屏幕类型：", responsive_manager.get_screen_type_name())
	
	# 为移动端添加手势支持
	_setup_mobile_gestures()

func _setup_mobile_gestures():
	if has_node("/root/MobileInteractionHelper"):
		var mobile_helper = get_node("/root/MobileInteractionHelper")
		
		# 连接手势信号
		mobile_helper.gesture_detected.connect(_on_gesture_detected)
		
		print("战斗场景手势支持已启用")

func _on_gesture_detected(gesture, position: Vector2):
	# 处理移动端手势
	if current_phase == Phase.PREPARATION:
		# 在准备阶段，双击可以快速选择/取消选择魂印
		if gesture == 1:  # DOUBLE_TAP
			_handle_quick_select_at_position(position)
	elif current_phase == Phase.LOOT:
		# 在战利品阶段，长按可以显示物品详情
		if gesture == 2:  # LONG_PRESS
			_handle_loot_item_info_at_position(position)

func _handle_quick_select_at_position(position: Vector2):
	# 将屏幕坐标转换为相对于loadout_grid的坐标
	var local_pos = loadout_grid.get_global_rect()
	if not local_pos.has_point(position):
		return
	
	# 这里可以添加基于位置的快速选择逻辑
	print("快速选择手势检测到，位置：", position)

func _handle_loot_item_info_at_position(position: Vector2):
	# 显示战利品详细信息
	print("长按显示物品信息，位置：", position)
	_add_log("[color=#FFAA00]长按查看物品详情功能[/color]")

func _on_screen_type_changed(_new_type):
	# 屏幕类型变化时重新应用布局
	_setup_responsive_layout()

func _adjust_battle_layout_for_screen(screen_type):
	var info_container = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer
	
	# 在移动端竖屏时将玩家和敌人信息垂直排列
	if screen_type == 0:  # MOBILE_PORTRAIT
		# HBoxContainer 不支持切换方向，只能隐藏分隔符
		var vseparator = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/VSeparator
		if vseparator:
			vseparator.visible = false
	else:
		# 其他情况显示分隔符
		var vseparator = $BattlePanel/MarginContainer/VBoxContainer/InfoContainer/VSeparator
		if vseparator:
			vseparator.visible = true
	
	# 根据屏幕类型调整网格列数
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		loadout_grid.columns = responsive_manager.get_grid_columns_for_screen()

func _process(delta):
	if battle_over:
		return

	if current_phase == Phase.LOOT:
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

func _refresh_loadout_display():
	# 刷新魂印卡片显示状态
	var cards = loadout_grid.get_children()
	for i in range(min(cards.size(), player_all_souls.size())):
		var button = cards[i] as Button
		if not button:
			continue

		var soul_item = player_all_souls[i]
		var soul = soul_item.soul_print

		# 更新按钮文本显示剩余次数
		var uses_text = str(soul_item.uses_remaining) + "/" + str(soul_item.max_uses)
		var type_text = "[主动]" if soul.soul_type == 0 else "[被动]"
		var effect_desc = soul.get_effect_description()
		button.text = soul.name + " " + type_text + "\n力量+" + str(soul.power) + "\n" + effect_desc + "\n次数:" + uses_text

		if current_phase == Phase.COMBAT:
			# 战斗阶段：根据使用次数显示状态
			if soul.soul_type == 0 and soul_item.uses_remaining <= 0:
				# 次数耗尽：深灰色显示
				var style_depleted = StyleBoxFlat.new()
				style_depleted.bg_color = Color(0.2, 0.2, 0.2, 0.8)
				style_depleted.border_color = Color(0.4, 0.4, 0.4)
				style_depleted.set_border_width_all(2)
				style_depleted.set_corner_radius_all(5)
				button.add_theme_stylebox_override("normal", style_depleted)
				button.add_theme_stylebox_override("hover", style_depleted)
				button.disabled = false  # 仍可点击查看
			elif soul.soul_type == 0:
				# 可使用的主动魂印：绿色高亮边框
				var quality_colors = [
					Color(0.5, 0.5, 0.5),
					Color(0.2, 0.7, 0.2),
					Color(0.2, 0.5, 0.9),
					Color(0.6, 0.2, 0.8),
					Color(0.9, 0.6, 0.2),
					Color(0.9, 0.3, 0.3)
				]
				var color = quality_colors[soul.quality]
				var style_active = StyleBoxFlat.new()
				style_active.bg_color = Color(color.r * 0.6, color.g * 0.6, color.b * 0.6, 1.0)
				style_active.border_color = Color(0, 1, 0, 1)  # 绿色边框
				style_active.set_border_width_all(4)
				style_active.set_corner_radius_all(5)
				button.add_theme_stylebox_override("normal", style_active)

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
	
	# 获取魂印使用次数信息
	var soul_item = player_all_souls[index]
	var uses_text = str(soul_item.uses_remaining) + "/" + str(soul_item.max_uses)

	# 显示魂印类型和效果
	var type_text = "[主动]" if soul.soul_type == 0 else "[被动]"
	var effect_desc = soul.get_effect_description()

	button.text = soul.name + " " + type_text + "\n力量+" + str(soul.power) + "\n" + effect_desc + "\n次数:" + uses_text
	button.pressed.connect(_on_soul_card_pressed.bind(index))
	
	return button

func _on_soul_card_pressed(index: int):
	var soul_item = player_all_souls[index]
	var soul = soul_item.soul_print

	if current_phase == Phase.PREPARATION:
		# 准备阶段：选择/取消魂印
		if player_selected_souls.has(soul_item):
			player_selected_souls.erase(soul_item)
			_add_log("[color=#FFAA00]取消选择：" + soul.name + "[/color]")
		else:
			player_selected_souls.append(soul_item)
			_add_log("[color=#00FF00]选择魂印：" + soul.name + " (+" + str(soul.power) + ")[/color]")
		_update_display()

	elif current_phase == Phase.COMBAT:
		# 战斗阶段：使用主动魂印
		if not player_selected_souls.has(soul_item):
			return  # 未选择的魂印不能使用

		if soul.soul_type != 0:  # 只有主动类型才能手动使用
			_add_log("[color=#FF6666]" + soul.name + " 是被动魂印，无法手动使用[/color]")
			return

		# 检查剩余使用次数
		if soul_item.uses_remaining <= 0:
			_add_log("[color=#FF6666]" + soul.name + " 使用次数已耗尽（0/" + str(soul_item.max_uses) + "）[/color]")
			return

		# 使用主动魂印
		soul_item.uses_remaining -= 1

		# 记录本战斗中的使用
		if not active_souls_used_in_battle.has(soul.id):
			active_souls_used_in_battle[soul.id] = 0
		active_souls_used_in_battle[soul.id] += 1

		_add_log("[color=#00FF00]★ 使用主动魂印：" + soul.name + "！[/color]")
		_add_log("[color=#FFD700]" + soul.get_effect_description() + "[/color]")
		_add_log("[color=#AAAAAA]剩余次数：" + str(soul_item.uses_remaining) + "/" + str(soul_item.max_uses) + "[/color]")

		# 更新魂印数据到背包系统
		_update_soul_uses_in_inventory(soul.id, soul_item.uses_remaining)
		_refresh_loadout_display()

func _update_soul_uses_in_inventory(soul_id: String, new_uses_remaining: int):
	# 更新背包系统中的魂印使用次数
	var soul_system = get_node("/root/SoulPrintSystem")
	var session = get_node("/root/UserSession")
	var username = session.get_username()

	var inventory = soul_system.get_user_inventory(username)
	for item in inventory:
		if item.soul_print.id == soul_id:
			item.uses_remaining = new_uses_remaining
			break

	# 保存到文件
	soul_system._save_inventories()

func _start_combat_phase():
	current_phase = Phase.COMBAT
	phase_label.text = "战斗回合"
	timer_label.visible = false
	_add_log("[color=#FFD700]准备阶段结束！开始战斗！[/color]")
	
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

func _execute_combat_round():
	if battle_over:
		return

	_add_log("[color=#FFFF00]━━━ 新回合 ━━━[/color]")

	# 提示玩家可以使用主动魂印
	_add_log("[color=#FFD700]点击下方主动魂印使用技能！（消耗使用次数）[/color]")
	_refresh_loadout_display()

	# 等待3秒，让玩家选择使用主动魂印
	await get_tree().create_timer(3.0).timeout

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

	# 3. 计算玩家力量（新公式：应用主动/被动效果）
	var player_base_damage = player_base_power * dice
	var player_damage_after_active = float(player_base_damage)
	var player_passive_bonus = 0
	var player_active_souls = []
	var player_passive_souls = []

	# 分类魂印
	for soul_item in player_selected_souls:
		var soul = soul_item.soul_print
		if soul.soul_type == 0:  # ACTIVE
			player_active_souls.append(soul)
		else:  # PASSIVE
			player_passive_souls.append(soul)

	# 应用主动魂印（应用本战斗中已使用的所有次数）
	for soul in player_active_souls:
		if not active_souls_used_in_battle.has(soul.id):
			continue  # 未使用的主动魂印不生效

		var use_count = active_souls_used_in_battle[soul.id]

		# 每次使用都应用一次效果（可叠加）
		for i in range(use_count):
			if soul.active_multiplier > 0:
				player_damage_after_active *= soul.active_multiplier
			if soul.active_bonus_percent > 0:
				player_damage_after_active *= (1.0 + soul.active_bonus_percent)

		# 记录总效果
		if soul.active_multiplier > 0:
			_add_log("[color=#FFD700]主动效果：" + soul.name + " %.1fx 倍率 × %d 次[/color]" % [soul.active_multiplier, use_count])
		if soul.active_bonus_percent > 0:
			_add_log("[color=#FFD700]主动效果：" + soul.name + " +%d%% 伤害 × %d 次[/color]" % [int(soul.active_bonus_percent * 100), use_count])

	# 应用被动魂印（随机触发）
	for soul in player_passive_souls:
		if randf() < soul.passive_trigger_chance:
			player_passive_bonus += soul.passive_bonus_flat
			if soul.passive_bonus_multiplier > 0:
				player_damage_after_active *= soul.passive_bonus_multiplier

			var effect_desc = "[color=#00FFFF]被动触发：" + soul.name
			if soul.passive_bonus_flat > 0:
				effect_desc += " +%d 伤害" % soul.passive_bonus_flat
			if soul.passive_bonus_multiplier > 0:
				effect_desc += " %.1fx 暴击" % soul.passive_bonus_multiplier
			effect_desc += "[/color]"
			_add_log(effect_desc)

	var player_final = int(player_damage_after_active) + player_passive_bonus
	player_final_power_label.text = "最终伤害: " + str(player_final)

	# 4. 播放玩家积分计算动画
	var player_calc_pos = Vector2(viewport_size.x * 0.25, viewport_size.y * 0.3)
	battle_animator.play_score_calculation(
		player_base_power,
		dice,
		player_soul_effects,
		player_final,
		player_calc_pos
	)

	_add_log("[color=#00FF00]玩家伤害计算：[/color]")
	_add_log("  基础：%d × %d = %d" % [player_base_power, dice, player_base_damage])
	var total_active_uses = 0
	for uses in active_souls_used_in_battle.values():
		total_active_uses += uses
	if total_active_uses > 0:
		_add_log("  主动魂印累计使用（%d 次）" % total_active_uses)
	_add_log("  [color=#FFFF00]最终伤害：%d[/color]" % player_final)

	# 等待玩家计算动画完成
	await battle_animator.animation_completed

	# 5. 计算敌人力量
	var enemy_soul_effects = []
	var enemy_soul_bonus = 0
	for soul in enemy_souls:
		enemy_soul_bonus += soul.power
		enemy_soul_effects.append({
			"name": soul.name,
			"power": soul.power,
			"quality": soul.quality
		})

	var enemy_final = enemy_base_power * dice + enemy_soul_bonus
	enemy_final_power_label.text = "最终力量: " + str(enemy_final)

	# 6. 播放敌人积分计算动画
	var enemy_calc_pos = Vector2(viewport_size.x * 0.75, viewport_size.y * 0.3)
	battle_animator.play_score_calculation(
		enemy_base_power,
		dice,
		enemy_soul_effects,
		enemy_final,
		enemy_calc_pos
	)

	_add_log("敌人力量：[color=#FF0000]" + str(enemy_base_power) + " × " + str(dice) + " + " + str(enemy_soul_bonus) + " = " + str(enemy_final) + "[/color]")

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

	# 播放胜利动画
	var viewport_size = get_viewport_rect().size
	await battle_animator.play_victory_animation(viewport_size / 2.0)

	await get_tree().create_timer(1.0).timeout
	
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
	
	# 等待一帧确保清理完成
	await get_tree().process_frame
	
	# 显示战利品和当前背包
	_create_loot_interface()

func _create_loot_interface():
	var container = VBoxContainer.new()
	container.name = "LootContainer"
	
	# 获取响应式网格列数
	var grid_columns = 5  # 默认值
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		grid_columns = responsive_manager.get_grid_columns_for_screen()
		# 对于战利品界面，适当减少列数以避免过于拥挤
		if responsive_manager.is_mobile_device():
			grid_columns = max(2, grid_columns - 2)
	
	# 战利品区域
	var loot_label = Label.new()
	loot_label.text = "战利品（可获得）："
	loot_label.add_theme_font_size_override("font_size", 16)
	loot_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	container.add_child(loot_label)
	
	var loot_grid = GridContainer.new()
	loot_grid.columns = grid_columns
	loot_grid.add_theme_constant_override("h_separation", 8)
	loot_grid.add_theme_constant_override("v_separation", 8)
	
	for soul in loot_souls:
		var card = _create_loot_card(soul, true)
		loot_grid.add_child(card)
	
	container.add_child(loot_grid)
	
	# 添加分隔空间
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	container.add_child(spacer)
	
	# 当前背包区域
	var inventory_label = Label.new()
	inventory_label.text = "当前背包（点击丢弃）："
	inventory_label.add_theme_font_size_override("font_size", 16)
	inventory_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1))
	container.add_child(inventory_label)
	
	var inventory_grid = GridContainer.new()
	inventory_grid.columns = grid_columns
	inventory_grid.add_theme_constant_override("h_separation", 8)
	inventory_grid.add_theme_constant_override("v_separation", 8)
	
	# 显示背包中的前10个魂印
	for i in range(min(10, player_all_souls.size())):
		var soul_item = player_all_souls[i]
		var card = _create_loot_card(soul_item.soul_print, false, i)
		inventory_grid.add_child(card)
	
	container.add_child(inventory_grid)
	
	# 添加操作提示
	var hint_label = Label.new()
	hint_label.text = "提示：点击背包中的魂印丢弃，自动获得战利品"
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(hint_label)
	
	loadout_grid.add_child(container)

func _create_loot_card(soul, is_loot: bool, inventory_index: int = -1) -> Button:
	var button = Button.new()
	
	# 根据屏幕类型调整按钮大小
	var min_size = Vector2(100, 70)  # 默认大小
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		min_size = responsive_manager.get_min_button_size()
		# 战利品卡片稍微调整比例
		min_size.y = min_size.y * 1.2
	
	button.custom_minimum_size = min_size
	
	var quality_colors = [
		Color(0.5, 0.5, 0.5), Color(0.2, 0.7, 0.2), Color(0.2, 0.5, 0.9),
		Color(0.6, 0.2, 0.8), Color(0.9, 0.6, 0.2), Color(0.9, 0.3, 0.3)
	]
	
	var quality_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
	var color = quality_colors[soul.quality]
	
	# 设置按钮样式
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.9)
	style_normal.border_color = color
	style_normal.set_border_width_all(2)
	style_normal.set_corner_radius_all(8)
	
	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(color.r * 0.5, color.g * 0.5, color.b * 0.5, 1.0)
	style_hover.border_color = color.lightened(0.3)
	style_hover.set_border_width_all(3)
	style_hover.set_corner_radius_all(8)
	
	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(color.r * 0.7, color.g * 0.7, color.b * 0.7, 1.0)
	style_pressed.border_color = Color.WHITE
	style_pressed.set_border_width_all(3)
	style_pressed.set_corner_radius_all(8)
	
	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_pressed)
	
	# 设置文本内容和颜色
	var type_text = "[主动]" if soul.soul_type == 0 else "[被动]"
	var effect_desc = soul.get_effect_description()

	var text = soul.name + " " + type_text + "\n力量: +" + str(soul.power) + "\n" + quality_names[soul.quality] + "\n" + effect_desc
	button.text = text
	button.add_theme_color_override("font_color", Color.WHITE)
	
	# 添加触摸反馈
	if has_node("/root/MobileInteractionHelper"):
		var mobile_helper = get_node("/root/MobileInteractionHelper")
		mobile_helper.add_touch_feedback(button)
	
	# 连接信号
	if not is_loot:
		button.pressed.connect(_on_discard_soul.bind(inventory_index))
		# 为背包物品添加不同的提示色调
		style_normal.bg_color = Color(0.6, 0.3, 0.3, 0.8)  # 稍微偏红，表示可丢弃
		button.add_theme_stylebox_override("normal", style_normal)
	
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
	
	# 使用统一的界面创建函数
	_create_loot_interface()

func _finish_loot_selection():
	print("战利品选择结束，剩余战利品：", loot_souls.size())
	_add_log("[color=#FFAA00]时间到！剩余战利品未获得。[/color]")
	
	await get_tree().create_timer(1.0).timeout
	_finish_battle_success()

func _finish_battle_success():
	print("_finish_battle_success 被调用")
	
	# 消耗选中魂印的使用次数
	_consume_selected_soul_uses()
	
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
		player_final_power_label.text = "魂印加成: +" + str(total_bonus) + " (总力量: " + str(player_base_power + total_bonus) + ")"
		# 更新魂印卡片的选中状态
		_update_soul_card_states()
	else:
		# 在战斗阶段也显示魂印加成效果
		player_final_power_label.text = "总力量: " + str(player_base_power + total_bonus) + " (基础:" + str(player_base_power) + " +魂印:" + str(total_bonus) + ")"

func _update_soul_card_states():
	# 更新所有魂印卡片的选中状态
	for i in range(loadout_grid.get_child_count()):
		if i >= player_all_souls.size():
			break
		var button = loadout_grid.get_child(i)
		var soul_item = player_all_souls[i]
		var soul = soul_item.soul_print
		
		# 品质颜色
		var quality_colors = [
			Color(0.5, 0.5, 0.5), Color(0.2, 0.7, 0.2), Color(0.2, 0.5, 0.9),
			Color(0.6, 0.2, 0.8), Color(0.9, 0.6, 0.2), Color(0.9, 0.3, 0.3)
		]
		var color = quality_colors[soul.quality]
		
		# 根据选中状态设置样式
		if player_selected_souls.has(soul_item):
			# 选中状态 - 更亮，黄色边框
			var style_selected = StyleBoxFlat.new()
			style_selected.bg_color = Color(color.r * 0.8, color.g * 0.8, color.b * 0.8, 1.0)
			style_selected.border_color = Color(1, 1, 0, 1)
			style_selected.set_border_width_all(4)
			style_selected.set_corner_radius_all(5)
			button.add_theme_stylebox_override("normal", style_selected)
		else:
			# 未选中状态 - 正常样式
			var style_normal = StyleBoxFlat.new()
			style_normal.bg_color = Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.8)
			style_normal.border_color = color
			style_normal.set_border_width_all(2)
			style_normal.set_corner_radius_all(5)
			button.add_theme_stylebox_override("normal", style_normal)

func _add_log(text: String):
	battle_log.text += "\n" + text
	await get_tree().process_frame
	battle_log.scroll_to_line(battle_log.get_line_count())

func _consume_selected_soul_uses():
	# 消耗选中魂印的使用次数
	var soul_system = _get_soul_system()
	if not soul_system:
		return
	
	var username = _get_username()
	var consumed_souls = []
	
	# 找到所有选中魂印在player_all_souls中的索引并消耗使用次数
	for selected_soul_item in player_selected_souls:
		for i in range(player_all_souls.size()):
			var soul_item = player_all_souls[i]
			# 通过ID和位置匹配魂印实例
			if (soul_item.soul_print.id == selected_soul_item.soul_print.id and 
				soul_item.grid_x == selected_soul_item.grid_x and 
				soul_item.grid_y == selected_soul_item.grid_y):
				var success = soul_system.use_soul_print(username, i)
				if success:
					consumed_souls.append(soul_item.soul_print.name)
				break
	
	# 更新显示信息
	if consumed_souls.size() > 0:
		_add_log("[color=#FFAA00]消耗魂印使用次数：[/color]")
		for soul_name in consumed_souls:
			_add_log("[color=#FF6666]- " + soul_name + "[/color]")

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
