extends Node

# 响应式布局管理器
# 支持桌面端和移动端的自适应布局

# 屏幕类型枚举
enum ScreenType {
	MOBILE_PORTRAIT,   # 手机竖屏 (< 600px width)
	MOBILE_LANDSCAPE,  # 手机横屏 (< 900px width, aspect < 1.5)
	TABLET_PORTRAIT,   # 平板竖屏 (600-900px width, aspect > 1.2)
	TABLET_LANDSCAPE,  # 平板横屏 (900-1200px width or aspect > 1.5)
	DESKTOP           # 桌面端 (> 1200px width)
}

# 当前屏幕信息
var current_screen_type: ScreenType
var screen_size: Vector2
var screen_scale: float = 1.0
var is_mobile: bool = false

# 响应式配置
var mobile_ui_scale: float = 1.2
var tablet_ui_scale: float = 1.1
var desktop_ui_scale: float = 1.0

# 字体缩放配置
var font_scale_mobile: float = 1.3
var font_scale_tablet: float = 1.15
var font_scale_desktop: float = 1.0

# 间距缩放配置
var margin_scale_mobile: float = 1.5
var margin_scale_tablet: float = 1.25
var margin_scale_desktop: float = 1.0

# 信号
signal screen_type_changed(new_type: ScreenType)
signal layout_updated

func _ready():
	# 连接窗口大小变化信号
	get_tree().get_root().size_changed.connect(_on_window_resized)
	
	# 初始化屏幕信息
	_update_screen_info()
	
	# 检测是否为移动平台
	_detect_mobile_platform()

func _detect_mobile_platform():
	var platform = OS.get_name()
	is_mobile = platform in ["Android", "iOS"]
	
	# 如果是移动平台，启用触摸输入
	if is_mobile:
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)

func _on_window_resized():
	_update_screen_info()

func _update_screen_info():
	var old_type = current_screen_type
	screen_size = get_tree().get_root().get_visible_rect().size
	
	# 计算屏幕类型
	current_screen_type = _calculate_screen_type(screen_size)
	
	# 更新UI缩放
	_update_ui_scale()
	
	# 如果屏幕类型改变，发送信号
	if old_type != current_screen_type:
		screen_type_changed.emit(current_screen_type)
		layout_updated.emit()

func _calculate_screen_type(size: Vector2) -> ScreenType:
	var width = size.x
	var height = size.y
	var aspect_ratio = width / height
	
	if width < 600:
		return ScreenType.MOBILE_PORTRAIT if aspect_ratio < 1.5 else ScreenType.MOBILE_LANDSCAPE
	elif width < 900:
		return ScreenType.TABLET_PORTRAIT if aspect_ratio < 1.5 else ScreenType.TABLET_LANDSCAPE
	elif width < 1200:
		return ScreenType.TABLET_LANDSCAPE
	else:
		return ScreenType.DESKTOP

func _update_ui_scale():
	match current_screen_type:
		ScreenType.MOBILE_PORTRAIT, ScreenType.MOBILE_LANDSCAPE:
			screen_scale = mobile_ui_scale
		ScreenType.TABLET_PORTRAIT, ScreenType.TABLET_LANDSCAPE:
			screen_scale = tablet_ui_scale
		ScreenType.DESKTOP:
			screen_scale = desktop_ui_scale

# 获取当前字体缩放
func get_font_scale() -> float:
	match current_screen_type:
		ScreenType.MOBILE_PORTRAIT, ScreenType.MOBILE_LANDSCAPE:
			return font_scale_mobile
		ScreenType.TABLET_PORTRAIT, ScreenType.TABLET_LANDSCAPE:
			return font_scale_tablet
		_:
			return font_scale_desktop

# 获取当前间距缩放
func get_margin_scale() -> float:
	match current_screen_type:
		ScreenType.MOBILE_PORTRAIT, ScreenType.MOBILE_LANDSCAPE:
			return margin_scale_mobile
		ScreenType.TABLET_PORTRAIT, ScreenType.TABLET_LANDSCAPE:
			return margin_scale_tablet
		_:
			return margin_scale_desktop

# 获取推荐的按钮最小尺寸
func get_min_button_size() -> Vector2:
	match current_screen_type:
		ScreenType.MOBILE_PORTRAIT, ScreenType.MOBILE_LANDSCAPE:
			return Vector2(120, 60)  # 移动端按钮更大，便于触摸
		ScreenType.TABLET_PORTRAIT, ScreenType.TABLET_LANDSCAPE:
			return Vector2(100, 50)
		_:
			return Vector2(80, 40)

# 应用响应式布局到Control节点
func apply_responsive_layout(control: Control):
	if not control:
		return
	
	# 设置字体大小
	_apply_font_scaling(control)
	
	# 设置间距
	_apply_margin_scaling(control)
	
	# 设置按钮最小尺寸
	_apply_button_sizing(control)
	
	# 应用到子节点
	for child in control.get_children():
		if child is Control:
			apply_responsive_layout(child)

func _apply_font_scaling(control: Control):
	var font_scale = get_font_scale()
	
	if control is Label:
		var label = control as Label
		_scale_label_font(label, font_scale)
	elif control is Button:
		var button = control as Button
		_scale_button_font(button, font_scale)
	elif control is LineEdit:
		var line_edit = control as LineEdit
		_scale_line_edit_font(line_edit, font_scale)

func _scale_label_font(label: Label, scale: float):
	# 获取当前字体大小，如果没有设置则使用默认值
	var current_size = 16  # 默认字体大小
	
	# 检查是否已经设置了字体大小覆盖
	if label.has_theme_font_size_override("font_size"):
		current_size = label.get_theme_font_size("font_size")
	
	var new_size = int(current_size * scale)
	label.add_theme_font_size_override("font_size", new_size)

func _scale_button_font(button: Button, scale: float):
	var current_size = 16
	if button.has_theme_font_size_override("font_size"):
		current_size = button.get_theme_font_size("font_size")
	
	var new_size = int(current_size * scale)
	button.add_theme_font_size_override("font_size", new_size)

func _scale_line_edit_font(line_edit: LineEdit, scale: float):
	var current_size = 16
	if line_edit.has_theme_font_size_override("font_size"):
		current_size = line_edit.get_theme_font_size("font_size")
	
	var new_size = int(current_size * scale)
	line_edit.add_theme_font_size_override("font_size", new_size)

func _apply_margin_scaling(control: Control):
	var margin_scale = get_margin_scale()
	
	if control is MarginContainer:
		var margin_container = control as MarginContainer
		_scale_margin_container(margin_container, margin_scale)

func _scale_margin_container(margin_container: MarginContainer, scale: float):
	# 获取当前边距或使用默认值
	var base_margin = 10
	
	# 检查是否有主题覆盖
	if margin_container.has_theme_constant_override("margin_left"):
		base_margin = margin_container.get_theme_constant("margin_left")
	
	var new_margin = int(base_margin * scale)
	margin_container.add_theme_constant_override("margin_left", new_margin)
	margin_container.add_theme_constant_override("margin_right", new_margin)
	margin_container.add_theme_constant_override("margin_top", new_margin)
	margin_container.add_theme_constant_override("margin_bottom", new_margin)

func _apply_button_sizing(control: Control):
	if control is Button:
		var button = control as Button
		var min_size = get_min_button_size()
		button.custom_minimum_size = min_size

# 获取网格容器的推荐列数
func get_grid_columns_for_screen() -> int:
	match current_screen_type:
		ScreenType.MOBILE_PORTRAIT:
			return 3  # 手机竖屏较窄，3列
		ScreenType.MOBILE_LANDSCAPE:
			return 5  # 手机横屏，5列
		ScreenType.TABLET_PORTRAIT:
			return 4  # 平板竖屏，4列
		ScreenType.TABLET_LANDSCAPE:
			return 6  # 平板横屏，6列
		_:
			return 8  # 桌面端，8列

# 获取游戏地图网格的推荐大小
func get_game_grid_cell_size() -> int:
	match current_screen_type:
		ScreenType.MOBILE_PORTRAIT:
			return 60  # 移动端较小
		ScreenType.MOBILE_LANDSCAPE:
			return 70
		ScreenType.TABLET_PORTRAIT, ScreenType.TABLET_LANDSCAPE:
			return 75
		_:
			return 80  # 桌面端正常大小

# 检查是否为移动端
func is_mobile_device() -> bool:
	return current_screen_type in [ScreenType.MOBILE_PORTRAIT, ScreenType.MOBILE_LANDSCAPE] or is_mobile

# 检查是否为平板
func is_tablet_device() -> bool:
	return current_screen_type in [ScreenType.TABLET_PORTRAIT, ScreenType.TABLET_LANDSCAPE]

# 检查是否为桌面端
func is_desktop_device() -> bool:
	return current_screen_type == ScreenType.DESKTOP

# 获取屏幕类型名称（用于调试）
func get_screen_type_name() -> String:
	match current_screen_type:
		ScreenType.MOBILE_PORTRAIT:
			return "移动端竖屏"
		ScreenType.MOBILE_LANDSCAPE:
			return "移动端横屏"
		ScreenType.TABLET_PORTRAIT:
			return "平板竖屏"
		ScreenType.TABLET_LANDSCAPE:
			return "平板横屏"
		ScreenType.DESKTOP:
			return "桌面端"
		_:
			return "未知"

# 为移动端优化触摸交互
func optimize_for_touch(control: Control):
	if not is_mobile_device():
		return
	
	# 增加按钮的触摸区域
	for child in control.get_children():
		if child is Button:
			var button = child as Button
			# 确保按钮有足够的触摸区域
			if button.custom_minimum_size.x < 80:
				button.custom_minimum_size.x = 80
			if button.custom_minimum_size.y < 50:
				button.custom_minimum_size.y = 50
		
		# 递归处理子节点
		if child is Control:
			optimize_for_touch(child)