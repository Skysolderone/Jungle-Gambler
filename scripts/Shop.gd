extends Control

signal shop_closed

@onready var items_container = $MainPanel/VBoxContainer/ContentContainer/LeftPanel/LeftPanelContainer/ScrollContainer/ItemsContainer
@onready var detail_title = $MainPanel/VBoxContainer/ContentContainer/RightPanel/ScrollContainer/DetailContainer/DetailTitle
@onready var quality_label = $MainPanel/VBoxContainer/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/QualityLabel
@onready var shape_label = $MainPanel/VBoxContainer/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/ShapeLabel
@onready var power_label = $MainPanel/VBoxContainer/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/PowerLabel
@onready var desc_label = $MainPanel/VBoxContainer/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/DescLabel
@onready var price_label = $MainPanel/VBoxContainer/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/PriceLabel
@onready var buy_button = $MainPanel/VBoxContainer/ContentContainer/RightPanel/ScrollContainer/DetailContainer/InfoMargin/InfoContainer/BuyButton
@onready var message_dialog = $MessageDialog

var current_username: String = ""
var selected_soul = null
var shop_items = []
var filtered_items = []  # 筛选后的商品列表
var current_filter = -1  # -1表示显示全部，0-5表示品质筛选
var current_sort = 0  # 0=默认，1=品质升序，2=品质降序，3=名称

# 品质颜色（暗黑风格）
var quality_colors = {
	0: Color(0.6, 0.6, 0.6),      # 普通 - 灰色
	1: Color(0.3, 0.8, 0.3),      # 非凡 - 绿色
	2: Color(0.3, 0.5, 1.0),      # 稀有 - 蓝色
	3: Color(0.7, 0.3, 1.0),      # 史诗 - 紫色
	4: Color(1.0, 0.6, 0.1),      # 传说 - 橙色
	5: Color(1.0, 0.8, 0.3)       # 神话 - 金色
}

var quality_names = {
	0: "普通", 1: "非凡", 2: "稀有", 
	3: "史诗", 4: "传说", 5: "神话"
}

var pipe_shape_names = {
	0: "直管-横", 1: "直管-竖",
	2: "弯管-左上", 3: "弯管-左下", 4: "弯管-右上", 5: "弯管-右下",
	6: "T型-上开口", 7: "T型-下开口", 8: "T型-左开口", 9: "T型-右开口",
	10: "十字型", 11: "起点", 12: "终点"
}

func _ready():
	# 应用响应式布局
	_setup_responsive_layout()

	current_username = UserSession.get_username()
	_load_shop_items()
	_apply_filter_and_sort()
	_create_item_cards()
	_create_filter_buttons()

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
		_adjust_layout_for_screen(responsive_manager.current_screen_type)
		
		print("商店已启用响应式布局，屏幕类型：", responsive_manager.get_screen_type_name())

func _on_screen_type_changed(_new_type):
	# 屏幕类型变化时重新应用布局
	_setup_responsive_layout()

func _adjust_layout_for_screen(screen_type):
	var content_container = $MainPanel/VBoxContainer/ContentContainer

	# 根据屏幕类型调整网格列数和间距
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		var columns = responsive_manager.get_grid_columns_for_screen()

		# 商城卡片较大，移动端减少列数
		if responsive_manager.is_mobile_device():
			columns = max(2, columns - 1)

		items_container.columns = columns

		# 调整间距
		if responsive_manager.is_mobile_device():
			items_container.add_theme_constant_override("h_separation", 12)
			items_container.add_theme_constant_override("v_separation", 12)
		else:
			items_container.add_theme_constant_override("h_separation", 15)
			items_container.add_theme_constant_override("v_separation", 15)

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			_on_close_button_pressed()
			get_viewport().set_input_as_handled()

func _get_soul_system():
	if has_node("/root/SoulPrintSystem"):
		return get_node("/root/SoulPrintSystem")
	return null

func _load_shop_items():
	# 从 SoulPrintSystem 数据库中获取所有已配置的魂印
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	# 定义商城中要售卖的魂印ID列表（36个管道魂印）
	var shop_soul_ids = [
		# 普通品质 (6个)
		"common_01",      # 破损的剑刃
		"common_02",      # 旧木盾
		"common_03",      # 碎裂的宝石
		"common_04",      # 生锈的匕首
		"common_05",      # 褪色的护符
		"common_06",      # 断裂的长矛

		# 非凡品质 (6个)
		"uncommon_01",    # 精钢剑
		"uncommon_02",    # 铁制盾牌
		"uncommon_03",    # 绿宝石
		"uncommon_04",    # 精制弓箭
		"uncommon_05",    # 强化护符
		"uncommon_06",    # 战斧

		# 稀有品质 (6个)
		"rare_01",        # 秘银之刃
		"rare_02",        # 符文盾
		"rare_03",        # 蓝宝石
		"rare_04",        # 精灵长弓
		"rare_05",        # 魔法护符
		"rare_06",        # 雷霆之锤

		# 史诗品质 (6个)
		"epic_01",        # 龙骨剑
		"epic_02",        # 泰坦之盾
		"epic_03",        # 紫水晶
		"epic_04",        # 凤凰之翼
		"epic_05",        # 古神护符
		"epic_06",        # 毁灭之镰

		# 传说品质 (6个)
		"legendary_01",   # 圣剑·誓约胜利之剑
		"legendary_02",   # 神盾·埃吉斯
		"legendary_03",   # 帝王宝石
		"legendary_04",   # 神弓·甘地瓦
		"legendary_05",   # 永恒护符
		"legendary_06",   # 弑神之矛

		# 神话品质 (6个)
		"mythic_01",      # 创世之刃
		"mythic_02",      # 混沌之盾
		"mythic_03",      # 宇宙之心
		"mythic_04",      # 终末之箭
		"mythic_05",      # 不朽圣物
		"mythic_06"       # 真理之杖
	]
	
	# 从数据库中获取完整的魂印数据（包含被动效果）
	shop_items = []
	for soul_id in shop_soul_ids:
		var soul = soul_system.get_soul_by_id(soul_id)
		if soul != null:
			shop_items.append(soul)
		else:
			print("警告：商城中的魂印不存在于数据库中: ", soul_id)

func _create_item_cards():
	# 清空容器
	for child in items_container.get_children():
		child.queue_free()

	# 使用筛选后的列表创建卡片
	for i in range(filtered_items.size()):
		var soul = filtered_items[i]
		# 找到在 shop_items 中的原始索引
		var original_index = shop_items.find(soul)
		var card = _create_soul_card(soul, original_index)
		items_container.add_child(card)

func _create_soul_card(soul, index: int) -> Button:
	var soul_system = _get_soul_system()
	if soul_system == null:
		return Button.new()

	# 使用 Button 替代 Panel 以获得更好的触摸反馈
	var card = Button.new()

	# 根据屏幕类型调整卡片大小
	var card_size = Vector2(200, 240)
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		var min_size = responsive_manager.get_min_button_size()
		if responsive_manager.is_mobile_device():
			card_size = Vector2(max(min_size.x, 160), 220)
		else:
			card_size = Vector2(200, 240)

	card.custom_minimum_size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	# 设置卡片样式
	var quality_color = quality_colors.get(soul.quality, Color.WHITE)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.15, 0.15, 0.18, 1)
	style_normal.set_border_width_all(3)
	style_normal.border_color = quality_color
	style_normal.set_corner_radius_all(10)
	style_normal.content_margin_left = 8
	style_normal.content_margin_right = 8
	style_normal.content_margin_top = 8
	style_normal.content_margin_bottom = 8

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.2, 0.2, 0.23, 1)
	style_hover.set_border_width_all(4)
	style_hover.border_color = quality_color.lightened(0.3)
	style_hover.set_corner_radius_all(10)
	style_hover.content_margin_left = 8
	style_hover.content_margin_right = 8
	style_hover.content_margin_top = 8
	style_hover.content_margin_bottom = 8

	var style_pressed = StyleBoxFlat.new()
	style_pressed.bg_color = Color(0.25, 0.25, 0.28, 1)
	style_pressed.set_border_width_all(4)
	style_pressed.border_color = Color(1, 0.9, 0.3, 1)  # 金色高亮
	style_pressed.set_corner_radius_all(10)
	style_pressed.content_margin_left = 8
	style_pressed.content_margin_right = 8
	style_pressed.content_margin_top = 8
	style_pressed.content_margin_bottom = 8

	card.add_theme_stylebox_override("normal", style_normal)
	card.add_theme_stylebox_override("hover", style_hover)
	card.add_theme_stylebox_override("pressed", style_pressed)
	card.add_theme_stylebox_override("focus", style_hover)
	
	# 创建内容容器
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 8)
	card.add_child(vbox)
	
	# 顶部间距
	var top_margin = Control.new()
	top_margin.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(top_margin)
	
	# 名称
	var name_label = Label.new()
	name_label.text = soul.name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", quality_colors.get(soul.quality, Color.WHITE))
	name_label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(name_label)
	
	# 品质
	var quality_label_card = Label.new()
	quality_label_card.text = quality_names.get(soul.quality, "未知")
	quality_label_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quality_label_card.add_theme_color_override("font_color", quality_colors.get(soul.quality, Color.WHITE))
	quality_label_card.add_theme_font_size_override("font_size", 14)
	vbox.add_child(quality_label_card)
	
	# 类型标签
	var type_label = Label.new()
	if soul.soul_type == soul_system.SoulType.ACTIVE:
		type_label.text = "[主动]"
		type_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))  # 橙色
	else:
		type_label.text = "[被动]"
		type_label.add_theme_color_override("font_color", Color(0.5, 0.5, 1.0))  # 蓝色
	type_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(type_label)

	# 效果描述
	var effect_label = Label.new()
	effect_label.text = soul.get_effect_description()
	effect_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
	effect_label.add_theme_font_size_override("font_size", 12)
	effect_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	effect_label.custom_minimum_size = Vector2(180, 0)
	vbox.add_child(effect_label)

	# 间距
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# 价格
	var price_label_card = Label.new()
	price_label_card.text = "免费（调试）"
	price_label_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_label_card.add_theme_color_override("font_color", Color(0.3, 1, 0.3, 1))
	price_label_card.add_theme_font_size_override("font_size", 14)
	vbox.add_child(price_label_card)
	
	# 底部间距
	var bottom_margin = Control.new()
	bottom_margin.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(bottom_margin)
	
	# 连接按钮点击事件
	card.pressed.connect(func(): _on_soul_card_clicked(index))

	# 添加移动端触摸反馈
	if has_node("/root/MobileInteractionHelper"):
		var mobile_helper = get_node("/root/MobileInteractionHelper")
		mobile_helper.add_touch_feedback(card)

	return card

func _on_soul_card_clicked(index: int):
	if index < 0 or index >= shop_items.size():
		return

	selected_soul = shop_items[index]
	_show_soul_details(selected_soul)
	buy_button.disabled = false

	# 优化购买按钮样式
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.2, 0.7, 0.2, 1)
	btn_style_normal.set_corner_radius_all(8)
	btn_style_normal.set_border_width_all(2)
	btn_style_normal.border_color = Color(0.3, 0.9, 0.3, 1)
	buy_button.add_theme_stylebox_override("normal", btn_style_normal)

	var btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.3, 0.8, 0.3, 1)
	btn_style_hover.set_corner_radius_all(8)
	btn_style_hover.set_border_width_all(3)
	btn_style_hover.border_color = Color(0.4, 1, 0.4, 1)
	buy_button.add_theme_stylebox_override("hover", btn_style_hover)

	buy_button.add_theme_font_size_override("font_size", 16)
	buy_button.custom_minimum_size = Vector2(0, 45)

func _show_soul_details(soul):
	detail_title.text = soul.name
	detail_title.add_theme_color_override("font_color", quality_colors.get(soul.quality, Color.WHITE))
	detail_title.add_theme_font_size_override("font_size", 24)

	quality_label.text = "品质：" + quality_names.get(soul.quality, "未知")
	quality_label.add_theme_color_override("font_color", quality_colors.get(soul.quality, Color.WHITE))
	quality_label.add_theme_font_size_override("font_size", 16)

	shape_label.text = "管道：" + pipe_shape_names.get(soul.pipe_shape_type, "未知")
	shape_label.add_theme_font_size_override("font_size", 14)

	# 显示魂印类型和效果（更详细）
	var soul_system = _get_soul_system()
	var power_text = ""

	if soul_system:
		if soul.soul_type == soul_system.SoulType.ACTIVE:
			power_text = "[主动技能]\n"
			power_text += soul.get_effect_description() + "\n"
			power_text += "基础力量: +" + str(soul.power) + "\n"
			if soul.active_multiplier > 0:
				power_text += "伤害倍率: %.1fx" % soul.active_multiplier + "\n"
			if soul.active_bonus_percent > 0:
				power_text += "伤害加成: +%d%%" % (soul.active_bonus_percent * 100)
		else:
			power_text = "[被动技能]\n"
			power_text += soul.get_effect_description() + "\n"
			power_text += "基础力量: +" + str(soul.power) + "\n"
			if soul.passive_trigger_chance > 0:
				power_text += "触发概率: %d%%" % (soul.passive_trigger_chance * 100) + "\n"
			if soul.passive_bonus_flat > 0:
				power_text += "额外伤害: +" + str(soul.passive_bonus_flat) + "\n"
			if soul.passive_bonus_multiplier > 0:
				power_text += "暴击倍率: %.1fx" % soul.passive_bonus_multiplier

	power_label.text = power_text
	power_label.add_theme_font_size_override("font_size", 14)

	# 更新描述
	desc_label.text = "描述：" + soul.description
	desc_label.add_theme_font_size_override("font_size", 13)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))

	price_label.text = "价格：免费（调试）"
	price_label.add_theme_font_size_override("font_size", 16)
	price_label.add_theme_color_override("font_color", Color(0.3, 1, 0.3))

func _on_buy_button_pressed():
	if selected_soul == null:
		return
	
	var soul_system = _get_soul_system()
	if soul_system == null:
		_show_message("系统错误：无法访问魂印系统")
		return
	
	# 尝试添加魂印到背包
	var success = soul_system.add_soul_print(current_username, selected_soul.id)
	
	if success:
		_show_message("购买成功！\n" + selected_soul.name + " 已添加到你的背包。")
	else:
		_show_message("购买失败！\n背包空间不足，请先整理背包。")

func _show_message(text: String):
	message_dialog.dialog_text = text
	message_dialog.popup_centered()

func _on_close_button_pressed():
	shop_closed.emit()

func _apply_filter_and_sort():
	# 应用品质筛选
	if current_filter == -1:
		filtered_items = shop_items.duplicate()
	else:
		filtered_items = []
		for soul in shop_items:
			if soul.quality == current_filter:
				filtered_items.append(soul)

	# 应用排序
	if current_sort == 1:  # 品质升序
		filtered_items.sort_custom(func(a, b): return a.quality < b.quality)
	elif current_sort == 2:  # 品质降序
		filtered_items.sort_custom(func(a, b): return a.quality > b.quality)
	elif current_sort == 3:  # 名称排序
		filtered_items.sort_custom(func(a, b): return a.name < b.name)

func _create_filter_buttons():
	# 在左侧面板顶部添加筛选按钮
	var left_panel_container = $MainPanel/VBoxContainer/ContentContainer/LeftPanel/LeftPanelContainer
	var top_margin = left_panel_container.get_node("TopMargin")

	# 创建筛选容器
	var filter_container = HBoxContainer.new()
	filter_container.name = "FilterContainer"
	filter_container.add_theme_constant_override("separation", 5)
	left_panel_container.add_child(filter_container)
	left_panel_container.move_child(filter_container, 1)  # 放在 TopMargin 后面

	# 全部按钮
	var all_btn = _create_filter_button("全部", -1)
	filter_container.add_child(all_btn)

	# 品质筛选按钮
	for i in range(6):
		var btn = _create_filter_button(quality_names[i], i)
		btn.add_theme_color_override("font_color", quality_colors[i])
		filter_container.add_child(btn)

	# 添加排序按钮
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	filter_container.add_child(spacer)

	var sort_btn = Button.new()
	sort_btn.text = "排序"
	sort_btn.custom_minimum_size = Vector2(60, 30)
	sort_btn.pressed.connect(_on_sort_button_pressed)
	filter_container.add_child(sort_btn)

func _create_filter_button(label: String, quality: int) -> Button:
	var btn = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(50, 30)

	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.2, 0.2, 0.23, 1)
	style_normal.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("normal", style_normal)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = Color(0.25, 0.25, 0.28, 1)
	style_hover.set_corner_radius_all(5)
	btn.add_theme_stylebox_override("hover", style_hover)

	btn.pressed.connect(func(): _on_filter_button_pressed(quality))

	return btn

func _on_filter_button_pressed(quality: int):
	current_filter = quality
	_apply_filter_and_sort()
	_refresh_items()

func _on_sort_button_pressed():
	# 循环切换排序方式
	current_sort = (current_sort + 1) % 4
	_apply_filter_and_sort()
	_refresh_items()

func _refresh_items():
	# 清空并重新创建卡片
	for child in items_container.get_children():
		child.queue_free()

	# 使用筛选后的列表
	for i in range(filtered_items.size()):
		var soul = filtered_items[i]
		# 找到原始索引
		var original_index = shop_items.find(soul)
		var card = _create_soul_card(soul, original_index)
		items_container.add_child(card)
