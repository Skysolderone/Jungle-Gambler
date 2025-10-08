extends Control

@onready var maps_container = $MainContent/VBoxContainer/MapsContainer
@onready var brightness_overlay = $BrightnessOverlay

const SETTINGS_PATH = "user://settings.json"

# 地图数据
var maps = [
	{
		"id": "forest",
		"name": "迷雾森林",
		"difficulty": "简单",
		"description": "一个适合新手的森林地图，怪物较弱。",
		"color": Color(0.2, 0.8, 0.2)
	},
	{
		"id": "desert",
		"name": "荒漠废墟",
		"difficulty": "普通",
		"description": "炎热的沙漠中隐藏着古老的秘密。",
		"color": Color(1.0, 0.7, 0.2)
	},
	{
		"id": "mountain",
		"name": "雪山之巅",
		"difficulty": "困难",
		"description": "寒冷的山峰，只有强者才能征服。",
		"color": Color(0.6, 0.8, 1.0)
	},
	{
		"id": "volcano",
		"name": "熔岩火山",
		"difficulty": "专家",
		"description": "炽热的火山，充满了危险的挑战。",
		"color": Color(1.0, 0.3, 0.1)
	}
]

func _ready():
	_apply_brightness_from_settings()
	_create_map_cards()

func _apply_brightness_from_settings():
	var settings = {
		"brightness": 100.0
	}
	
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(json_string) == OK:
				settings = json.get_data()
	
	# 应用亮度
	var brightness = settings.get("brightness", 100.0)
	var alpha = (100.0 - brightness) / 100.0 * 0.7
	brightness_overlay.color = Color(0, 0, 0, alpha)

func _create_map_cards():
	for i in range(maps.size()):
		var map_data = maps[i]
		var card = _create_map_card(map_data, i)
		maps_container.add_child(card)

func _create_map_card(map_data: Dictionary, index: int) -> Panel:
	var card = Panel.new()
	card.custom_minimum_size = Vector2(250, 350)
	
	# 设置卡片样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.18, 1)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.border_color = map_data.get("color", Color.WHITE)
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	card.add_theme_stylebox_override("panel", style)
	
	# 创建内容容器
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 15)
	card.add_child(vbox)
	
	# 顶部间距
	var top_margin = Control.new()
	top_margin.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(top_margin)
	
	# 地图名称
	var name_label = Label.new()
	name_label.text = map_data.get("name", "未知地图")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", map_data.get("color", Color.WHITE))
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)
	
	# 难度
	var difficulty_label = Label.new()
	difficulty_label.text = "难度: " + map_data.get("difficulty", "未知")
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	difficulty_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(difficulty_label)
	
	# 分隔线
	var separator = ColorRect.new()
	separator.custom_minimum_size = Vector2(200, 2)
	separator.color = map_data.get("color", Color.WHITE) * 0.5
	separator.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(separator)
	
	# 描述
	var desc_label = Label.new()
	desc_label.text = map_data.get("description", "")
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	desc_label.custom_minimum_size = Vector2(200, 0)
	vbox.add_child(desc_label)
	
	# 间距
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# 选择按钮
	var select_button = Button.new()
	select_button.text = "选择地图"
	select_button.custom_minimum_size = Vector2(180, 50)
	select_button.add_theme_font_size_override("font_size", 18)
	
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.25, 0.25, 0.3, 1)
	btn_style_normal.corner_radius_top_left = 8
	btn_style_normal.corner_radius_top_right = 8
	btn_style_normal.corner_radius_bottom_right = 8
	btn_style_normal.corner_radius_bottom_left = 8
	select_button.add_theme_stylebox_override("normal", btn_style_normal)
	
	var btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = map_data.get("color", Color.WHITE) * 0.6
	btn_style_hover.corner_radius_top_left = 8
	btn_style_hover.corner_radius_top_right = 8
	btn_style_hover.corner_radius_bottom_right = 8
	btn_style_hover.corner_radius_bottom_left = 8
	select_button.add_theme_stylebox_override("hover", btn_style_hover)
	
	select_button.pressed.connect(_on_map_selected.bind(map_data))
	
	var button_center = CenterContainer.new()
	button_center.add_child(select_button)
	vbox.add_child(button_center)
	
	# 底部间距
	var bottom_margin = Control.new()
	bottom_margin.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(bottom_margin)
	
	return card

func _on_map_selected(map_data: Dictionary):
	# 保存选择的地图到全局
	if has_node("/root/UserSession"):
		var session = get_node("/root/UserSession")
		session.set_meta("selected_map", map_data)
	
	# 进入魂印配置页面
	get_tree().change_scene_to_file("res://scenes/SoulLoadout.tscn")

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/Lobby.tscn")

