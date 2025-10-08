extends Node

# 主题管理系统

enum ThemeMode {
	DARK,
	LIGHT
}

var current_theme: ThemeMode = ThemeMode.DARK

# 主题颜色配置
var theme_colors = {
	ThemeMode.DARK: {
		"background": Color(0.15, 0.15, 0.2, 1),
		"panel": Color(0.2, 0.2, 0.25, 1),
		"panel_light": Color(0.25, 0.25, 0.3, 1),
		"button_normal": Color(0.25, 0.25, 0.3, 1),
		"button_hover": Color(0.35, 0.35, 0.4, 1),
		"button_pressed": Color(0.35, 0.35, 0.4, 1),
		"accent": Color(1, 0.85, 0.3, 1),  # 金黄色
		"text": Color(1, 1, 1, 1),
		"text_secondary": Color(0.8, 0.8, 0.8, 1),
		"border": Color(0.3, 0.3, 0.35, 1),
		"slot_bg": Color(0.2, 0.2, 0.25, 1),
	},
	ThemeMode.LIGHT: {
		"background": Color(0.95, 0.95, 0.98, 1),
		"panel": Color(1, 1, 1, 1),
		"panel_light": Color(0.98, 0.98, 1, 1),
		"button_normal": Color(0.9, 0.9, 0.95, 1),
		"button_hover": Color(0.85, 0.85, 0.9, 1),
		"button_pressed": Color(0.85, 0.85, 0.9, 1),
		"accent": Color(0.2, 0.5, 0.9, 1),  # 蓝色
		"text": Color(0.1, 0.1, 0.1, 1),
		"text_secondary": Color(0.3, 0.3, 0.3, 1),
		"border": Color(0.7, 0.7, 0.75, 1),
		"slot_bg": Color(0.95, 0.95, 0.98, 1),
	}
}

# 主题变更信号
signal theme_changed(new_theme: ThemeMode)

const SETTINGS_PATH = "user://settings.json"

func _ready():
	_load_theme()

func get_color(color_name: String) -> Color:
	if theme_colors[current_theme].has(color_name):
		return theme_colors[current_theme][color_name]
	return Color.WHITE

func set_theme(new_theme: ThemeMode):
	if current_theme != new_theme:
		current_theme = new_theme
		_save_theme()
		theme_changed.emit(new_theme)

func toggle_theme():
	if current_theme == ThemeMode.DARK:
		set_theme(ThemeMode.LIGHT)
	else:
		set_theme(ThemeMode.DARK)

func is_dark_mode() -> bool:
	return current_theme == ThemeMode.DARK

func is_light_mode() -> bool:
	return current_theme == ThemeMode.LIGHT

func _load_theme():
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			if json.parse(json_string) == OK:
				var settings = json.get_data()
				if settings.has("theme"):
					current_theme = settings["theme"]

func _save_theme():
	var settings = {}
	
	# 加载现有设置
	if FileAccess.file_exists(SETTINGS_PATH):
		var file = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			var json = JSON.new()
			if json.parse(json_string) == OK:
				settings = json.get_data()
	
	# 更新主题设置
	settings["theme"] = current_theme
	
	# 保存
	var file = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(settings, "\t"))
		file.close()

# 辅助函数：应用主题到 ColorRect
func apply_to_color_rect(node: ColorRect, color_name: String = "background"):
	node.color = get_color(color_name)

# 辅助函数：应用主题到 Panel
func apply_to_panel(node: Panel, color_name: String = "panel"):
	var style = StyleBoxFlat.new()
	style.bg_color = get_color(color_name)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	node.add_theme_stylebox_override("panel", style)

# 辅助函数：应用主题到 Label
func apply_to_label(node: Label, color_name: String = "text"):
	node.add_theme_color_override("font_color", get_color(color_name))

