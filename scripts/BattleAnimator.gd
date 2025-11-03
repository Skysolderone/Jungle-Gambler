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
	animation_layer.layer = 100 # 确保在最上层
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

	# 等待一帧确保节点完全添加到场景树
	await get_tree().process_frame

	# 动画序列
	var base_damage = await _show_base_calculation(calculation_panel, base_power, dice)
	await get_tree().create_timer(0.3).timeout

	# 显示初始伤害
	await _show_final_result(calculation_panel, base_damage)
	await get_tree().create_timer(0.3).timeout

	# 显示魂印效果，每个魂印都会更新最终伤害
	await _show_soul_effects(calculation_panel, soul_effects, base_damage)
	await get_tree().create_timer(2.0).timeout # 显示时间2秒，让玩家看清魂印明细

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

	# 根据视口大小自适应面板尺寸
	var viewport = animation_layer.get_viewport()
	var viewport_size = viewport.get_visible_rect().size
	var panel_width = min(500, viewport_size.x * 0.8) # 最大500px或屏幕宽度的80%
	var panel_height = min(450, viewport_size.y * 0.7) # 最大450px或屏幕高度的70%

	# 面板居中显示
	var panel_x = (viewport_size.x - panel_width) / 2
	var panel_y = (viewport_size.y - panel_height) / 2

	panel.position = Vector2(panel_x, panel_y)
	panel.custom_minimum_size = Vector2(panel_width, panel_height)
	panel.modulate.a = 0 # 初始透明

	# 根据面板宽度计算合适的字体大小
	var title_font_size = int(panel_width * 0.05) # 标题为面板宽度的5%
	var content_font_size = int(panel_width * 0.04) # 内容为面板宽度的4%
	var separation = int(panel_height * 0.02) # 间距为面板高度的2%

	# 添加边距容器，使内容在面板中更加居中
	var margin = MarginContainer.new()
	var side_margin = int(panel_width * 0.08) # 左右边距为面板宽度的8%
	margin.add_theme_constant_override("margin_left", side_margin)
	margin.add_theme_constant_override("margin_right", side_margin)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)

	# 添加内容容器
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", separation)
	margin.add_child(vbox)

	# 添加标题
	var title = Label.new()
	title.text = "━━━ 力量计算 ━━━"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", title_font_size)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	vbox.add_child(title)

	# 添加滚动容器以支持大量魂印
	var scroll_container = ScrollContainer.new()
	# 滚动容器高度为面板高度的60%，确保有足够空间显示魂印
	var scroll_height = panel_height * 0.6
	scroll_container.custom_minimum_size = Vector2(0, scroll_height)
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll_container)

	# 计算内容容器
	var calc_container = VBoxContainer.new()
	calc_container.name = "CalcContainer"
	calc_container.add_theme_constant_override("separation", separation)
	calc_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 保存字体大小供后续使用
	calc_container.set_meta("content_font_size", content_font_size)
	scroll_container.add_child(calc_container)

	# 分隔线
	var separator = HSeparator.new()
	separator.add_theme_constant_override("separation", 2)
	vbox.add_child(separator)

	# 最终结果标签（初始隐藏）
	var final_label = Label.new()
	final_label.name = "FinalLabel"
	final_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# 使用响应式字体大小
	var final_font_size = int(panel_width * 0.06) # 最终伤害为面板宽度的6%
	final_label.add_theme_font_size_override("font_size", final_font_size)
	final_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0)) # 默认白色
	final_label.visible = false
	vbox.add_child(final_label)

	# 淡入动画
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

	# 弹出动画
	panel.scale = Vector2(0.8, 0.8)
	tween.parallel().tween_property(panel, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	return panel

func _show_base_calculation(panel: Control, base_power: int, dice: int) -> int:
	"""显示基础计算，返回基础伤害值"""
	# 获取容器：PanelContainer -> MarginContainer(0) -> VBoxContainer(0) -> ScrollContainer(1) -> CalcContainer(0)
	var vbox = panel.get_child(0).get_child(0)
	var scroll_container = vbox.get_child(1)
	var calc_container = scroll_container.get_child(0)

	if calc_container == null:
		push_error("无法找到 CalcContainer")
		return 0

	# 获取自适应字体大小
	var font_size = calc_container.get_meta("content_font_size", 16)

	# 基础力量行
	var base_line = _create_calculation_line("基础力量", str(base_power), Color(0.8, 0.8, 1.0), font_size)
	calc_container.add_child(base_line)
	await _animate_line_in(base_line)
	await get_tree().create_timer(0.2).timeout

	# 骰子行
	var dice_line = _create_calculation_line("骰子点数", "× " + str(dice), Color(1.0, 0.8, 0.2), font_size)
	calc_container.add_child(dice_line)
	await _animate_line_in(dice_line)
	await get_tree().create_timer(0.2).timeout

	# 结果行
	var result = base_power * dice
	var result_line = _create_calculation_line("", "= " + str(result), Color(0.2, 1.0, 0.5), int(font_size * 1.2))
	calc_container.add_child(result_line)
	await _animate_line_in(result_line)

	return result

func _show_soul_effects(panel: Control, soul_effects: Array, base_damage: int) -> void:
	"""显示魂印效果，每个魂印添加后更新最终伤害"""
	if soul_effects.is_empty():
		return

	# 获取容器：PanelContainer -> MarginContainer(0) -> VBoxContainer(0) -> ScrollContainer(1) -> CalcContainer(0)
	var vbox = panel.get_child(0).get_child(0)
	var scroll_container = vbox.get_child(1)
	var calc_container = scroll_container.get_child(0)

	if calc_container == null:
		push_error("无法找到 CalcContainer")
		return

	# 获取自适应字体大小
	var font_size = calc_container.get_meta("content_font_size", 16)

	# 添加魂印标题
	var soul_title = Label.new()
	soul_title.text = "━━━ 魂印加成 ━━━"
	soul_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	soul_title.add_theme_font_size_override("font_size", int(font_size * 1.1))
	soul_title.add_theme_color_override("font_color", Color(0.8, 0.4, 1.0))
	calc_container.add_child(soul_title)
	await _animate_line_in(soul_title)
	await get_tree().create_timer(0.2).timeout

	# 逐个显示魂印效果，并更新最终伤害
	var current_damage = base_damage
	for soul_effect in soul_effects:
		var soul_name = soul_effect.get("name", "未知魂印")
		var power = soul_effect.get("power", 0)
		current_damage += power

		# 魂印效果行
		var quality_colors = [
			Color(0.5, 0.5, 0.5), # 普通
			Color(0.2, 0.7, 0.2), # 非凡
			Color(0.2, 0.5, 0.9), # 稀有
			Color(0.6, 0.2, 0.8), # 史诗
			Color(0.9, 0.6, 0.2), # 传说
			Color(0.9, 0.3, 0.3) # 神话
		]
		var quality = soul_effect.get("quality", 0)
		var color = quality_colors[quality]

		var soul_line = _create_calculation_line(soul_name, "+ " + str(power), color, font_size)
		calc_container.add_child(soul_line)
		await _animate_line_in(soul_line, true) # 带特效

		# 根据品质决定动画强度和延迟
		var delay = 0.15
		var shake_intensity = 0.0

		match quality:
			0, 1: # 普通、非凡 - 快速
				delay = 0.08
			2, 3: # 稀有、史诗 - 中等
				delay = 0.12
			4, 5: # 传说、神话 - 慢速 + 屏幕震动
				delay = 0.2
				shake_intensity = 3.0 if quality == 4 else 5.0 # 传说3, 神话5

		# 每添加一个魂印，立即更新最终伤害并跳动（带品质颜色）
		await _update_final_damage(panel, current_damage, color, quality)

		# 高品质魂印添加屏幕震动
		if shake_intensity > 0:
			play_screen_shake(shake_intensity, 0.15)

		await get_tree().create_timer(delay).timeout

func _show_final_result(panel: Control, final_damage: int) -> void:
	"""首次显示最终伤害标签"""
	# 获取 FinalLabel：PanelContainer -> MarginContainer(0) -> VBoxContainer(0) -> FinalLabel(3)
	var vbox = panel.get_child(0).get_child(0)
	var final_label = vbox.get_child(3)

	if final_label == null:
		push_error("无法找到 FinalLabel")
		return

	# 获取面板宽度，计算最终结果的字体大小
	var panel_width = panel.custom_minimum_size.x
	var final_font_size = int(panel_width * 0.06) # 最终伤害为面板宽度的6%

	final_label.text = str(final_damage)
	final_label.add_theme_font_size_override("font_size", final_font_size)
	final_label.visible = true
	final_label.modulate.a = 0
	final_label.scale = Vector2(0.5, 0.5)

	# 震撼登场动画
	var tween = create_tween()
	tween.tween_property(final_label, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(final_label, "scale", Vector2(1.2, 1.2), 0.2).set_ease(Tween.EASE_OUT)
	tween.tween_property(final_label, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN)

	# 根据伤害值决定颜色（白色 -> 伤害颜色 -> 白色）
	var damage_color = _get_damage_color(final_damage)
	for i in range(3):
		tween.tween_method(
			func(color): final_label.add_theme_color_override("font_color", color),
			Color.WHITE,
			damage_color,
			0.1
		)
		tween.tween_method(
			func(color): final_label.add_theme_color_override("font_color", color),
			damage_color,
			Color.WHITE,
			0.1
		)

	await tween.finished

func _update_final_damage(panel: Control, new_damage: int, soul_color: Color = Color.WHITE, quality: int = 0) -> void:
	"""更新最终伤害并根据伤害值添加差异化的跳动动画"""
	# 获取 FinalLabel：PanelContainer -> MarginContainer(0) -> VBoxContainer(0) -> FinalLabel(3)
	var vbox = panel.get_child(0).get_child(0)
	var final_label = vbox.get_child(3)

	if final_label == null:
		push_error("无法找到 FinalLabel")
		return

	# 更新文本
	final_label.text = str(new_damage)

	# 根据伤害值决定跳动强度和动画速度
	var scale_factor = 1.15 # 默认缩放
	var animation_time = 0.1 # 默认动画时间

	if new_damage < 50:
		scale_factor = 1.1
		animation_time = 0.08
	elif new_damage < 100:
		scale_factor = 1.15
		animation_time = 0.1
	elif new_damage < 150:
		scale_factor = 1.25
		animation_time = 0.12
	elif new_damage < 200:
		scale_factor = 1.35
		animation_time = 0.14
	elif new_damage < 300:
		scale_factor = 1.45
		animation_time = 0.16
	else: # 300+
		scale_factor = 1.6
		animation_time = 0.18

	# 跳动动画
	var tween = create_tween()
	tween.tween_property(final_label, "scale", Vector2(scale_factor, scale_factor), animation_time).set_ease(Tween.EASE_OUT)
	tween.tween_property(final_label, "scale", Vector2(1.0, 1.0), animation_time).set_ease(Tween.EASE_IN)

	# 根据伤害值决定闪烁颜色
	var damage_color = _get_damage_color(new_damage)

	# 闪烁到伤害颜色，然后回到白色
	tween.parallel().tween_method(
		func(color): final_label.add_theme_color_override("font_color", color),
		Color.WHITE,
		damage_color,
		animation_time
	)
	tween.tween_method(
		func(color): final_label.add_theme_color_override("font_color", color),
		damage_color,
		Color.WHITE,
		animation_time
	)

	await tween.finished

func _get_damage_color(damage: int) -> Color:
	"""根据伤害值返回对应的颜色"""
	if damage < 50:
		return Color(0.2, 1.0, 0.2) # 低伤害 - 绿色
	elif damage < 100:
		return Color(0.2, 1.0, 0.8) # 中低伤害 - 青色
	elif damage < 150:
		return Color(1.0, 1.0, 0.2) # 中等伤害 - 黄色
	elif damage < 200:
		return Color(1.0, 0.6, 0.2) # 中高伤害 - 橙色
	elif damage < 300:
		return Color(1.0, 0.2, 0.2) # 高伤害 - 红色
	else:
		return Color(1.0, 0.2, 0.8) # 超高伤害 - 紫红色

func _hide_calculation_panel(panel: Control) -> void:
	"""隐藏结算面板"""
	var tween = create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.3)
	tween.parallel().tween_property(panel, "scale", Vector2(0.8, 0.8), 0.3).set_ease(Tween.EASE_IN)
	await tween.finished

func _create_calculation_line(label_text: String, value_text: String, color: Color, font_size: int = 16) -> HBoxContainer:
	"""创建计算行"""
	var hbox = HBoxContainer.new()
	hbox.modulate.a = 0 # 初始透明

	# 设置标签和数值之间的间距
	hbox.add_theme_constant_override("separation", 10)

	# 标签
	if not label_text.is_empty():
		var label = Label.new()
		label.text = label_text
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", color)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
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

		# 发光效果（确保最终颜色是完全不透明的）
		tween.tween_property(line, "modulate", Color(1.5, 1.5, 1.5, 1.0), 0.1)
		tween.tween_property(line, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)

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
	var dice_label = dice_panel.get_child(0) as Label

	if dice_label == null:
		push_error("无法找到骰子标签")
		return 1

	# 快速切换数字模拟滚动
	var roll_duration = 1.5 # 滚动时间
	var roll_speed = 0.05 # 切换速度
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
		Color(0.5, 0.5, 0.5), # 普通
		Color(0.2, 0.7, 0.2), # 非凡
		Color(0.2, 0.5, 0.9), # 稀有
		Color(0.6, 0.2, 0.8), # 史诗
		Color(0.9, 0.6, 0.2), # 传说
		Color(0.9, 0.3, 0.3) # 神话
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
	# 优先使用 Camera2D
	var camera = get_viewport().get_camera_2d()
	if camera:
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
	else:
		# 如果没有相机，震动动画层
		var original_offset = animation_layer.offset
		var elapsed = 0.0
		var shake_interval = 0.05

		while elapsed < duration:
			var shake_x = randf_range(-intensity, intensity)
			var shake_y = randf_range(-intensity, intensity)
			animation_layer.offset = original_offset + Vector2(shake_x, shake_y)

			await get_tree().create_timer(shake_interval).timeout
			elapsed += shake_interval

		# 恢复原位
		animation_layer.offset = original_offset

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
