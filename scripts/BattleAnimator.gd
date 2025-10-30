extends Node
class_name BattleAnimator

# 战斗动画管理器 - 负责所有战斗动画效果
# 借鉴 Balatro 的华丽结算动画

signal animation_completed

# 动画容器节点
var animation_layer: CanvasLayer

func _ready():
	# 创建动画层（最顶层显示）
	animation_layer = CanvasLayer.new()
	animation_layer.layer = 100  # 确保在最上层
	add_child(animation_layer)

# ========== 积分结算动画 ==========

func play_score_calculation(
	base_power: int,
	dice: int,
	soul_effects: Array,
	final_damage: int,
	position: Vector2
) -> void:
	"""
	播放积分计算动画序列

	参数：
	- base_power: 基础力量
	- dice: 骰子点数
	- soul_effects: 魂印效果列表 [{name, power, icon}]
	- final_damage: 最终伤害
	- position: 动画显示位置
	"""

	# 创建结算面板容器
	var calculation_panel = _create_calculation_panel(position)
	animation_layer.add_child(calculation_panel)

	# 动画序列
	await _show_base_calculation(calculation_panel, base_power, dice)
	await get_tree().create_timer(0.5).timeout

	await _show_soul_effects(calculation_panel, soul_effects)
	await get_tree().create_timer(0.5).timeout

	await _show_final_result(calculation_panel, final_damage)
	await get_tree().create_timer(1.0).timeout

	# 清理
	await _hide_calculation_panel(calculation_panel)
	calculation_panel.queue_free()

	animation_completed.emit()

func _create_calculation_panel(pos: Vector2) -> Control:
	"""创建结算面板"""
	var panel = PanelContainer.new()

	# 设置样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.95)
	style.border_color = Color(0.8, 0.6, 0.2, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 10
	panel.add_theme_stylebox_override("panel", style)

	# 设置位置和大小
	panel.position = pos - Vector2(200, 150)
	panel.custom_minimum_size = Vector2(400, 300)
	panel.modulate.a = 0  # 初始透明

	# 添加内容容器
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	# 添加标题
	var title = Label.new()
	title.text = "━━━ 力量计算 ━━━"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(title)

	# 计算内容容器
	var calc_container = VBoxContainer.new()
	calc_container.name = "CalcContainer"
	calc_container.add_theme_constant_override("separation", 8)
	vbox.add_child(calc_container)

	# 分隔线
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 2)
	vbox.add_child(separator)

	# 最终结果标签（初始隐藏）
	var final_label = Label.new()
	final_label.name = "FinalLabel"
	final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	final_label.add_theme_font_size_override("font_size", 28)
	final_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	final_label.visible = false
	vbox.add_child(final_label)

	# 淡入动画
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

	# 弹出动画
	panel.scale = Vector2(0.8, 0.8)
	tween.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	return panel

func _show_base_calculation(panel: Control, base_power: int, dice: int) -> void:
	"""显示基础计算"""
	var calc_container = panel.find_child("CalcContainer")

	# 基础力量行
	var base_line = _create_calculation_line("基础力量", str(base_power), Color(0.8, 0.8, 1.0))
	calc_container.add_child(base_line)
	await _animate_line_in(base_line)
	await get_tree().create_timer(0.2).timeout

	# 骰子行
	var dice_line = _create_calculation_line("骰子点数", "× " + str(dice), Color(1.0, 0.8, 0.2))
	calc_container.add_child(dice_line)
	await _animate_line_in(dice_line)
	await get_tree().create_timer(0.2).timeout

	# 结果行
	var result = base_power * dice
	var result_line = _create_calculation_line("", "= " + str(result), Color(0.2, 1.0, 0.5), 18)
	calc_container.add_child(result_line)
	await _animate_line_in(result_line)

func _show_soul_effects(panel: Control, soul_effects: Array) -> void:
	"""显示魂印效果"""
	if soul_effects.is_empty():
		return

	var calc_container = panel.find_child("CalcContainer")

	# 添加魂印标题
	var soul_title = Label.new()
	soul_title.text = "━━━ 魂印加成 ━━━"
	soul_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soul_title.add_theme_font_size_override("font_size", 16)
	soul_title.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
	calc_container.add_child(soul_title)
	await _animate_line_in(soul_title)
	await get_tree().create_timer(0.2).timeout

	# 逐个显示魂印效果
	var total_soul_power = 0
	for soul_effect in soul_effects:
		var name = soul_effect.get("name", "未知魂印")
		var power = soul_effect.get("power", 0)
		total_soul_power += power

		# 魂印效果行
		var quality_colors = [
			Color(0.5, 0.5, 0.5),    # 普通
			Color(0.2, 0.7, 0.2),    # 非凡
			Color(0.2, 0.5, 0.9),    # 稀有
			Color(0.6, 0.2, 0.8),    # 史诗
			Color(0.9, 0.6, 0.2),    # 传说
			Color(0.9, 0.3, 0.3)     # 神话
		]
		var quality = soul_effect.get("quality", 0)
		var color = quality_colors[quality]

		var soul_line = _create_calculation_line(name, "+ " + str(power), color)
		calc_container.add_child(soul_line)
		await _animate_line_in(soul_line, true)  # 带特效
		await get_tree().create_timer(0.15).timeout

	# 魂印总和
	if total_soul_power > 0:
		var total_line = _create_calculation_line("魂印总加成", "+ " + str(total_soul_power), Color(1.0, 0.5, 1.0), 18)
		calc_container.add_child(total_line)
		await _animate_line_in(total_line, true)

func _show_final_result(panel: Control, final_damage: int) -> void:
	"""显示最终结果"""
	var final_label = panel.find_child("FinalLabel")
	final_label.text = "最终伤害: " + str(final_damage)
	final_label.visible = true
	final_label.modulate.a = 0
	final_label.scale = Vector2(0.5, 0.5)

	# 震撼登场动画
	var tween = create_tween()
	tween.tween_property(final_label, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(final_label, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(final_label, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN)

	# 颜色闪烁效果
	for i in range(3):
		tween.tween_property(final_label, "modulate", Color(1.5, 0.5, 0.5), 0.1)
		tween.tween_property(final_label, "modulate", Color(1.0, 1.0, 1.0), 0.1)

func _hide_calculation_panel(panel: Control) -> void:
	"""隐藏结算面板"""
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(panel, "scale", Vector2(0.8, 0.8), 0.3).set_ease(Tween.EASE_IN)
	await tween.finished

func _create_calculation_line(label_text: String, value_text: String, color: Color, font_size: int = 16) -> HBoxContainer:
	"""创建计算行"""
	var hbox = HBoxContainer.new()
	hbox.modulate.a = 0  # 初始透明

	# 标签
	if not label_text.is_empty():
		var label = Label.new()
		label.text = label_text
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)

	# 值
	var value = Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", font_size)
	value.add_theme_color_override("font_color", color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if label_text.is_empty():
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(value)

	return hbox

func _animate_line_in(line: Control, with_effect: bool = false) -> void:
	"""行淡入动画"""
	var tween = create_tween()
	tween.tween_property(line, "modulate:a", 1.0, 0.2)

	if with_effect:
		# 带特效的淡入（魂印效果用）
		line.scale = Vector2(0.8, 0.8)
		tween.parallel().tween_property(line, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_OUT)

		# 发光效果
		var original_color = line.modulate
		tween.tween_property(line, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		tween.tween_property(line, "modulate", original_color, 0.1)

	await tween.finished

# ========== 伤害数字飘出动画 ==========

func play_damage_number(damage: int, pos: Vector2, is_critical: bool = false) -> void:
	"""
	播放伤害数字飘出动画

	参数：
	- damage: 伤害数值
	- pos: 起始位置
	- is_critical: 是否暴击
	"""
	var damage_label = Label.new()
	damage_label.text = str(damage)
	damage_label.position = pos

	# 根据是否暴击设置样式
	if is_critical:
		damage_label.add_theme_font_size_override("font_size", 48)
		damage_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		damage_label.add_theme_color_override("font_outline_color", Color(1.0, 1.0, 0.0))
		damage_label.add_theme_constant_override("outline_size", 3)
	else:
		damage_label.add_theme_font_size_override("font_size", 36)
		damage_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		damage_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
		damage_label.add_theme_constant_override("outline_size", 2)

	animation_layer.add_child(damage_label)

	# 飘出动画
	var tween = create_tween()

	# 向上飘动
	var end_pos = pos + Vector2(randf_range(-30, 30), -100)
	tween.tween_property(damage_label, "position", end_pos, 1.0).set_ease(Tween.EASE_OUT)

	# 缩放弹出效果
	damage_label.scale = Vector2(0.5, 0.5)
	tween.parallel().tween_property(damage_label, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.1)

	# 淡出
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.5).set_delay(0.3)

	await tween.finished
	damage_label.queue_free()

# ========== 骰子滚动动画 ==========

func play_dice_roll(pos: Vector2) -> int:
	"""
	播放骰子滚动动画

	返回：骰子点数 (1-6)
	"""
	var dice_panel = _create_dice_panel(pos)
	animation_layer.add_child(dice_panel)

	# 滚动动画
	var result = await _animate_dice_roll(dice_panel)

	# 短暂停留显示结果
	await get_tree().create_timer(1.0).timeout

	# 淡出
	var tween = create_tween()
	tween.tween_property(dice_panel, "modulate:a", 0.0, 0.3)
	await tween.finished

	dice_panel.queue_free()
	return result

func _create_dice_panel(pos: Vector2) -> Control:
	"""创建骰子面板"""
	var panel = PanelContainer.new()

	# 样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	style.border_color = Color(1.0, 1.0, 1.0, 0.8)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", style)

	panel.position = pos - Vector2(60, 60)
	panel.custom_minimum_size = Vector2(120, 120)

	# 骰子标签
	var dice_label = Label.new()
	dice_label.name = "DiceLabel"
	dice_label.text = "?"
	dice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dice_label.add_theme_font_size_override("font_size", 64)
	dice_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	panel.add_child(dice_label)

	# 弹入动画
	panel.scale = Vector2(0.0, 0.0)
	var tween = create_tween()
	tween.tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	return panel

func _animate_dice_roll(dice_panel: Control) -> int:
	"""骰子滚动动画"""
	var dice_label = dice_panel.find_child("DiceLabel") as Label

	# 快速切换数字模拟滚动
	var roll_duration = 1.5  # 滚动时间
	var roll_speed = 0.05     # 切换速度
	var elapsed = 0.0

	while elapsed < roll_duration:
		var random_num = randi() % 6 + 1
		dice_label.text = str(random_num)

		# 旋转动画
		var roll_tween = create_tween()
		roll_tween.tween_property(dice_panel, "rotation", randf_range(-0.2, 0.2), roll_speed)

		await get_tree().create_timer(roll_speed).timeout
		elapsed += roll_speed

	# 最终结果
	var final_result = randi() % 6 + 1
	dice_label.text = str(final_result)

	# 重置旋转
	var reset_tween = create_tween()
	reset_tween.tween_property(dice_panel, "rotation", 0.0, 0.2)

	# 强调动画
	var scale_tween = create_tween()
	scale_tween.tween_property(dice_panel, "scale", Vector2(1.3, 1.3), 0.2).set_ease(Tween.EASE_OUT)
	scale_tween.tween_property(dice_panel, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN)

	await scale_tween.finished
	return final_result

# ========== 魂印激活特效 ==========

func play_soul_activation(soul_name: String, pos: Vector2, quality: int) -> void:
	"""
	播放魂印激活特效

	参数：
	- soul_name: 魂印名称
	- pos: 位置
	- quality: 品质等级 (0-5)
	"""
	var quality_colors = [
		Color(0.5, 0.5, 0.5),    # 普通
		Color(0.2, 0.7, 0.2),    # 非凡
		Color(0.2, 0.5, 0.9),    # 稀有
		Color(0.6, 0.2, 0.8),    # 史诗
		Color(0.9, 0.6, 0.2),    # 传说
		Color(0.9, 0.3, 0.3)     # 神话
	]
	var color = quality_colors[quality]

	# 创建光环效果
	var glow = ColorRect.new()
	glow.color = color
	glow.size = Vector2(100, 100)
	glow.position = pos - Vector2(50, 50)
	glow.modulate.a = 0
	animation_layer.add_child(glow)

	# 创建文字
	var label = Label.new()
	label.text = soul_name + " 激活！"
	label.position = pos + Vector2(-80, -30)
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.modulate.a = 0
	animation_layer.add_child(label)

	# 动画序列
	var tween = create_tween()

	# 光环扩散
	tween.tween_property(glow, "modulate:a", 0.5, 0.2)
	tween.parallel().tween_property(glow, "scale", Vector2(2.0, 2.0), 0.4).set_ease(Tween.EASE_OUT)
	tween.tween_property(glow, "modulate:a", 0.0, 0.3)

	# 文字出现
	tween.parallel().tween_property(label, "modulate:a", 1.0, 0.2).set_delay(0.1)
	tween.tween_property(label, "position:y", label.position.y - 30, 0.5).set_delay(0.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.4)

	await tween.finished
	glow.queue_free()
	label.queue_free()

# ========== 屏幕震动效果 ==========

func play_screen_shake(intensity: float = 10.0, duration: float = 0.3) -> void:
	"""
	播放屏幕震动效果

	参数：
	- intensity: 震动强度
	- duration: 持续时间
	"""
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return

	var original_offset = camera.offset
	var elapsed = 0.0
	var shake_interval = 0.05

	while elapsed < duration:
		var shake_x = randf_range(-intensity, intensity)
		var shake_y = randf_range(-intensity, intensity)
		camera.offset = original_offset + Vector2(shake_x, shake_y)

		await get_tree().create_timer(shake_interval).timeout
		elapsed += shake_interval

	# 恢复原位
	camera.offset = original_offset

# ========== 胜利/失败动画 ==========

func play_victory_animation(pos: Vector2) -> void:
	"""播放胜利动画"""
	var victory_label = Label.new()
	victory_label.text = "胜利！"
	victory_label.position = pos - Vector2(100, 50)
	victory_label.add_theme_font_size_override("font_size", 72)
	victory_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	victory_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	victory_label.add_theme_constant_override("outline_size", 5)
	victory_label.modulate.a = 0
	victory_label.scale = Vector2(0.5, 0.5)
	animation_layer.add_child(victory_label)

	var tween = create_tween()
	tween.tween_property(victory_label, "modulate:a", 1.0, 0.3)
	tween.parallel().tween_property(victory_label, "scale", Vector2(1.2, 1.2), 0.3).set_ease(Tween.EASE_OUT)
	tween.tween_property(victory_label, "scale", Vector2(1.0, 1.0), 0.2)

	# 颜色闪烁
	for i in range(5):
		tween.tween_property(victory_label, "modulate", Color(2.0, 2.0, 2.0), 0.1)
		tween.tween_property(victory_label, "modulate", Color(1.0, 1.0, 1.0), 0.1)

	await tween.finished
	await get_tree().create_timer(1.0).timeout
	victory_label.queue_free()

func play_defeat_animation(pos: Vector2) -> void:
	"""播放失败动画"""
	var defeat_label = Label.new()
	defeat_label.text = "失败..."
	defeat_label.position = pos - Vector2(100, 50)
	defeat_label.add_theme_font_size_override("font_size", 72)
	defeat_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	defeat_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0))
	defeat_label.add_theme_constant_override("outline_size", 5)
	defeat_label.modulate.a = 0
	animation_layer.add_child(defeat_label)

	var tween = create_tween()
	tween.tween_property(defeat_label, "modulate:a", 1.0, 0.5)
	tween.tween_property(defeat_label, "position:y", defeat_label.position.y + 30, 1.0).set_ease(Tween.EASE_OUT)

	await tween.finished
	await get_tree().create_timer(1.0).timeout
	defeat_label.queue_free()
