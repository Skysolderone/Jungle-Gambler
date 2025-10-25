extends Control

signal shop_closed

@onready var items_container = $MainPanel/VBoxContainer/ContentContainer/LeftPanel/ScrollContainer/ItemsContainer
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
	if screen_type == 0:  # MOBILE_PORTRAIT
		content_container.vertical = true
	else:
		# 其他情况水平排列
		content_container.vertical = false

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
	# 创建商城物品列表（所有已注册的魂印）
	var soul_system = _get_soul_system()
	if soul_system == null:
		return
	
	# 从 SoulPrintSystem 获取所有可用的魂印
	# 这里我们手动创建一些商城物品
	var SoulPrint = soul_system.SoulPrint
	var Quality = soul_system.Quality
	var ShapeType = soul_system.ShapeType
	
	shop_items = [
		SoulPrint.new("soul_basic_1", "初始魂印", Quality.COMMON, ShapeType.SQUARE_1X1),
		SoulPrint.new("soul_basic_2", "双生魂印", Quality.COMMON, ShapeType.RECT_1X2),
		SoulPrint.new("soul_forest", "森林之魂", Quality.UNCOMMON, ShapeType.SQUARE_2X2),
		SoulPrint.new("soul_flame", "火焰之心", Quality.RARE, ShapeType.L_SHAPE),
		SoulPrint.new("soul_ocean", "深海之力", Quality.RARE, ShapeType.T_SHAPE),
		SoulPrint.new("soul_thunder", "雷霆之怒", Quality.EPIC, ShapeType.RECT_1X3),
		SoulPrint.new("soul_shadow", "暗影追踪", Quality.EPIC, ShapeType.TRIANGLE),
		SoulPrint.new("soul_phoenix", "不死鸟", Quality.LEGENDARY, ShapeType.SQUARE_2X2),
		SoulPrint.new("soul_dragon", "龙之魂", Quality.LEGENDARY, ShapeType.T_SHAPE),
		SoulPrint.new("soul_god", "神之祝福", Quality.MYTHIC, ShapeType.L_SHAPE),
	]
	
	# 设置每个魂印的描述和力量
	shop_items[0].description = "最基础的魂印，适合新手使用。"
	shop_items[0].power = 5
	
	shop_items[1].description = "双格魂印，提供额外的空间利用。"
	shop_items[1].power = 8
	
	shop_items[2].description = "蕴含森林之力，提升生命力。"
	shop_items[2].power = 15
	
	shop_items[3].description = "炽热的火焰之力，增强攻击力。"
	shop_items[3].power = 25
	
	shop_items[4].description = "深海的神秘力量，提升防御。"
	shop_items[4].power = 28
	
	shop_items[5].description = "雷霆之怒，闪电般的速度。"
	shop_items[5].power = 40
	
	shop_items[6].description = "来自暗影的追踪者，提升暴击。"
	shop_items[6].power = 45
	
	shop_items[7].description = "浴火重生的不死鸟之力。"
	shop_items[7].power = 60
	
	shop_items[8].description = "远古巨龙的灵魂力量。"
	shop_items[8].power = 70
	
	shop_items[9].description = "神明的祝福，至高无上的力量。"
	shop_items[9].power = 100

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
	var card = Panel.new()
	card.custom_minimum_size = Vector2(200, 180)
	
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
	
	# 力量
	var power_label_card = Label.new()
	power_label_card.text = "力量: " + str(soul.power)
	power_label_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label_card.add_theme_color_override("font_color", Color(1, 0.85, 0.4, 1))
	power_label_card.add_theme_font_size_override("font_size", 16)
	vbox.add_child(power_label_card)
	
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
	power_label.text = "力量：" + str(soul.power)
	desc_label.text = "描述：" + soul.description
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
