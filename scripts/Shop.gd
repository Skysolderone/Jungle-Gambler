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

var shape_names = {
	0: "1×1 正方形", 1: "2×2 正方形", 2: "1×2 矩形", 
	3: "2×1 矩形", 4: "1×3 矩形", 5: "3×1 矩形",
	6: "L形状", 7: "T形状", 8: "三角形"
}

func _ready():
	# 应用响应式布局
	_setup_responsive_layout()
	
	current_username = UserSession.get_username()
	_load_shop_items()
	_create_item_cards()

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
	
	# 根据屏幕类型调整网格列数
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		items_container.columns = responsive_manager.get_grid_columns_for_screen()
	
	# 在移动端竖屏时将左右面板垂直排列
	# 注意：HBoxContainer 没有 vertical 属性，需要通过其他方式处理布局

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
	
	# 定义商城中要售卖的魂印ID列表
	var shop_soul_ids = [
		"soul_basic_1",   # 初始魂印
		"soul_basic_2",   # 双生魂印
		"soul_forest",    # 森林之魂
		"soul_wind",      # 疾风魂印
		"soul_flame",     # 火焰之心
		"soul_ocean",     # 深海之力
		"soul_thunder",   # 雷霆之怒
		"soul_shadow",    # 暗影追踪
		"soul_phoenix",   # 不死鸟
		"soul_dragon",    # 龙之魂
		"soul_god"        # 神之祝福
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
	
	# 为每个魂印创建卡片
	for i in range(shop_items.size()):
		var soul = shop_items[i]
		var card = _create_soul_card(soul, i)
		items_container.add_child(card)

func _create_soul_card(soul, index: int) -> Panel:
	var soul_system = _get_soul_system()
	if soul_system == null:
		return Panel.new()

	var card = Panel.new()
	card.custom_minimum_size = Vector2(200, 220)  # 增加高度以容纳新内容

	# 设置卡片样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 1)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = quality_colors.get(soul.quality, Color.WHITE)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	card.add_theme_stylebox_override("panel", style)
	
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
	
	# 添加点击事件
	card.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_soul_card_clicked(index)
	)
	
	return card

func _on_soul_card_clicked(index: int):
	if index < 0 or index >= shop_items.size():
		return
	
	selected_soul = shop_items[index]
	_show_soul_details(selected_soul)
	buy_button.disabled = false

func _show_soul_details(soul):
	detail_title.text = soul.name
	detail_title.add_theme_color_override("font_color", quality_colors.get(soul.quality, Color.WHITE))
	
	quality_label.text = "品质：" + quality_names.get(soul.quality, "未知")
	quality_label.add_theme_color_override("font_color", quality_colors.get(soul.quality, Color.WHITE))
	
	shape_label.text = "形状：" + shape_names.get(soul.shape_type, "未知")

	# 显示魂印类型
	var soul_system = _get_soul_system()
	var type_text = ""
	if soul_system:
		if soul.soul_type == soul_system.SoulType.ACTIVE:
			type_text = "[主动] "
		else:
			type_text = "[被动] "
	power_label.text = type_text + "效果：" + soul.get_effect_description()

	# 更新描述
	var full_description = soul.description

	desc_label.text = "描述：" + full_description
	price_label.text = "价格：免费（调试）"

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
