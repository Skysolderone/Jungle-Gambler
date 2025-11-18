extends Node
# PixelStyleManager - 像素风格管理器
# 提供统一的像素艺术风格资源和样式配置

# ========== 像素艺术调色板（DB16风格） ==========
const PIXEL_PALETTE = {
	"BLACK": Color(0.078, 0.078, 0.110),        # #14141C 深黑色
	"DARK_GREY": Color(0.235, 0.235, 0.306),   # #3C3C4E 深灰色
	"GREY": Color(0.439, 0.439, 0.541),        # #70708A 中灰色
	"LIGHT_GREY": Color(0.729, 0.729, 0.800),  # #BABACE 浅灰色
	"WHITE": Color(0.949, 0.949, 0.969),       # #F2F2F7 白色

	"RED": Color(0.839, 0.216, 0.282),         # #D63748 红色
	"ORANGE": Color(0.937, 0.549, 0.243),     # #EF8C3E 橙色
	"YELLOW": Color(0.945, 0.804, 0.247),     # #F1CD3F 黄色
	"GREEN": Color(0.443, 0.761, 0.314),      # #71C250 绿色
	"CYAN": Color(0.278, 0.773, 0.820),       # #47C5D1 青色
	"BLUE": Color(0.263, 0.510, 0.831),       # #4382D4 蓝色
	"PURPLE": Color(0.537, 0.353, 0.820),     # #8959D1 紫色
	"PINK": Color(0.839, 0.431, 0.682),       # #D66EAE 粉色

	# 魂印品质颜色（像素化版本）
	"QUALITY_COMMON": Color(0.502, 0.502, 0.502),      # 灰色 - 普通
	"QUALITY_UNCOMMON": Color(0.443, 0.761, 0.314),    # 绿色 - 非凡
	"QUALITY_RARE": Color(0.263, 0.510, 0.831),        # 蓝色 - 稀有
	"QUALITY_EPIC": Color(0.537, 0.353, 0.820),        # 紫色 - 史诗
	"QUALITY_LEGENDARY": Color(0.937, 0.549, 0.243),   # 橙色 - 传说
	"QUALITY_MYTHIC": Color(0.839, 0.216, 0.282),      # 红色 - 神话
}

# 像素风格边框宽度
const PIXEL_BORDER_WIDTH = 2
const PIXEL_BORDER_WIDTH_THICK = 3

# ========== 像素字体配置 ==========
const PIXEL_FONT_SIZE_SMALL = 14
const PIXEL_FONT_SIZE_NORMAL = 18
const PIXEL_FONT_SIZE_LARGE = 24
const PIXEL_FONT_SIZE_HUGE = 32
const PIXEL_FONT_SIZE_TITLE = 40

# 缓存字体实例
var _font_cache = {}

# ========== 像素字体生成 ==========
func get_pixel_font(size: int = PIXEL_FONT_SIZE_NORMAL) -> Font:
	"""获取像素风格字体"""
	# 使用缓存避免重复创建
	var cache_key = "pixel_font_%d" % size
	if _font_cache.has(cache_key):
		return _font_cache[cache_key]

	# 创建基础系统字体
	var base_font = SystemFont.new()

	# 使用等宽字体列表（优先级从高到低）
	base_font.font_names = [
		"Consolas",           # Windows 等宽字体
		"Courier New",        # 跨平台等宽字体
		"Monaco",             # macOS 等宽字体
		"Menlo",              # macOS 等宽字体
		"Ubuntu Mono",        # Linux 等宽字体
		"DejaVu Sans Mono",   # Linux 等宽字体
		"monospace"           # 通用等宽字体
	]

	# 像素字体关键配置：禁用抗锯齿和子像素定位
	base_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	base_font.generate_mipmaps = false
	base_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	base_font.hinting = TextServer.HINTING_NONE
	base_font.force_autohinter = false
	base_font.allow_system_fallback = true
	base_font.multichannel_signed_distance_field = false

	# 使用 FontVariation 来设置字体大小
	var font_variation = FontVariation.new()
	font_variation.set_base_font(base_font)
	font_variation.set_spacing(TextServer.SPACING_TOP, 0)
	font_variation.set_spacing(TextServer.SPACING_BOTTOM, 0)

	# 缓存字体变体
	_font_cache[cache_key] = font_variation
	return font_variation

# ========== 获取不同尺寸的像素字体 ==========
func get_small_font() -> Font:
	"""获取小号像素字体"""
	return get_pixel_font(PIXEL_FONT_SIZE_SMALL)

func get_normal_font() -> Font:
	"""获取普通像素字体"""
	return get_pixel_font(PIXEL_FONT_SIZE_NORMAL)

func get_large_font() -> Font:
	"""获取大号像素字体"""
	return get_pixel_font(PIXEL_FONT_SIZE_LARGE)

func get_huge_font() -> Font:
	"""获取特大号像素字体"""
	return get_pixel_font(PIXEL_FONT_SIZE_HUGE)

func get_title_font() -> Font:
	"""获取标题像素字体"""
	return get_pixel_font(PIXEL_FONT_SIZE_TITLE)

# ========== 魂印品质颜色获取 ==========
func get_quality_color(quality: int) -> Color:
	match quality:
		0: return PIXEL_PALETTE["QUALITY_COMMON"]
		1: return PIXEL_PALETTE["QUALITY_UNCOMMON"]
		2: return PIXEL_PALETTE["QUALITY_RARE"]
		3: return PIXEL_PALETTE["QUALITY_EPIC"]
		4: return PIXEL_PALETTE["QUALITY_LEGENDARY"]
		5: return PIXEL_PALETTE["QUALITY_MYTHIC"]
		_: return PIXEL_PALETTE["GREY"]

# ========== 像素风格按钮样式生成 ==========
func create_pixel_button_style(
	bg_color: Color,
	border_color: Color,
	hover_brightness: float = 1.2,
	pressed_brightness: float = 0.8
) -> Dictionary:
	"""创建像素风格按钮的三态样式"""
	var styles = {}

	# 普通状态
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_width_left = PIXEL_BORDER_WIDTH
	normal.border_width_right = PIXEL_BORDER_WIDTH
	normal.border_width_top = PIXEL_BORDER_WIDTH
	normal.border_width_bottom = PIXEL_BORDER_WIDTH
	normal.border_color = border_color
	normal.corner_radius_top_left = 0
	normal.corner_radius_top_right = 0
	normal.corner_radius_bottom_left = 0
	normal.corner_radius_bottom_right = 0
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	styles["normal"] = normal

	# 悬停状态
	var hover = normal.duplicate()
	hover.bg_color = _brighten_color(bg_color, hover_brightness)
	styles["hover"] = hover

	# 按下状态
	var pressed = normal.duplicate()
	pressed.bg_color = _brighten_color(bg_color, pressed_brightness)
	pressed.content_margin_top = 7
	pressed.content_margin_bottom = 5
	styles["pressed"] = pressed

	# 禁用状态
	var disabled = normal.duplicate()
	disabled.bg_color = PIXEL_PALETTE["DARK_GREY"]
	disabled.border_color = PIXEL_PALETTE["GREY"]
	styles["disabled"] = disabled

	return styles

# ========== 像素风格面板样式生成 ==========
func create_pixel_panel_style(
	bg_color: Color,
	border_color: Color,
	border_width: int = PIXEL_BORDER_WIDTH
) -> StyleBoxFlat:
	"""创建像素风格面板样式"""
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = 0
	style.corner_radius_top_right = 0
	style.corner_radius_bottom_left = 0
	style.corner_radius_bottom_right = 0
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	return style

# ========== 像素风格输入框样式生成 ==========
func create_pixel_input_style(
	bg_color: Color,
	border_color: Color,
	focus_border_color: Color
) -> Dictionary:
	"""创建像素风格输入框样式"""
	var styles = {}

	# 普通状态
	var normal = StyleBoxFlat.new()
	normal.bg_color = bg_color
	normal.border_width_left = PIXEL_BORDER_WIDTH
	normal.border_width_right = PIXEL_BORDER_WIDTH
	normal.border_width_top = PIXEL_BORDER_WIDTH
	normal.border_width_bottom = PIXEL_BORDER_WIDTH
	normal.border_color = border_color
	normal.corner_radius_top_left = 0
	normal.corner_radius_top_right = 0
	normal.corner_radius_bottom_left = 0
	normal.corner_radius_bottom_right = 0
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	styles["normal"] = normal

	# 聚焦状态
	var focus = normal.duplicate()
	focus.border_color = focus_border_color
	styles["focus"] = focus

	return styles

# ========== 像素风格滑块样式生成 ==========
func create_pixel_slider_style() -> Dictionary:
	"""创建像素风格滑块样式"""
	var styles = {}

	# 滑块轨道
	var track = StyleBoxFlat.new()
	track.bg_color = PIXEL_PALETTE["DARK_GREY"]
	track.border_width_left = PIXEL_BORDER_WIDTH
	track.border_width_right = PIXEL_BORDER_WIDTH
	track.border_width_top = PIXEL_BORDER_WIDTH
	track.border_width_bottom = PIXEL_BORDER_WIDTH
	track.border_color = PIXEL_PALETTE["BLACK"]
	track.corner_radius_top_left = 0
	track.corner_radius_top_right = 0
	track.corner_radius_bottom_left = 0
	track.corner_radius_bottom_right = 0
	styles["track"] = track

	# 滑块抓手
	var grabber = StyleBoxFlat.new()
	grabber.bg_color = PIXEL_PALETTE["CYAN"]
	grabber.border_width_left = PIXEL_BORDER_WIDTH
	grabber.border_width_right = PIXEL_BORDER_WIDTH
	grabber.border_width_top = PIXEL_BORDER_WIDTH
	grabber.border_width_bottom = PIXEL_BORDER_WIDTH
	grabber.border_color = PIXEL_PALETTE["WHITE"]
	grabber.corner_radius_top_left = 0
	grabber.corner_radius_top_right = 0
	grabber.corner_radius_bottom_left = 0
	grabber.corner_radius_bottom_right = 0
	styles["grabber"] = grabber

	# 抓手高亮状态
	var grabber_highlight = grabber.duplicate()
	grabber_highlight.bg_color = _brighten_color(PIXEL_PALETTE["CYAN"], 1.3)
	styles["grabber_highlight"] = grabber_highlight

	return styles

# ========== 应用像素风格到按钮 ==========
func apply_pixel_button_style(button: Button, color_name: String = "BLUE", font_size: int = PIXEL_FONT_SIZE_NORMAL):
	"""应用像素风格到按钮"""
	var bg_color = PIXEL_PALETTE.get(color_name, PIXEL_PALETTE["BLUE"])
	var border_color = PIXEL_PALETTE["WHITE"]
	var styles = create_pixel_button_style(bg_color, border_color)

	button.add_theme_stylebox_override("normal", styles["normal"])
	button.add_theme_stylebox_override("hover", styles["hover"])
	button.add_theme_stylebox_override("pressed", styles["pressed"])
	button.add_theme_stylebox_override("disabled", styles["disabled"])

	# 应用像素字体
	var font = get_pixel_font(font_size)
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)

	# 设置像素化字体颜色
	button.add_theme_color_override("font_color", PIXEL_PALETTE["WHITE"])
	button.add_theme_color_override("font_hover_color", PIXEL_PALETTE["YELLOW"])
	button.add_theme_color_override("font_pressed_color", PIXEL_PALETTE["LIGHT_GREY"])

# ========== 应用像素风格到面板 ==========
func apply_pixel_panel_style(panel: Control, bg_color_name: String = "DARK_GREY"):
	"""应用像素风格到面板（支持 Panel 和 PanelContainer）"""
	var bg_color = PIXEL_PALETTE.get(bg_color_name, PIXEL_PALETTE["DARK_GREY"])
	var border_color = PIXEL_PALETTE["WHITE"]
	var style = create_pixel_panel_style(bg_color, border_color, PIXEL_BORDER_WIDTH_THICK)
	panel.add_theme_stylebox_override("panel", style)

# ========== 应用像素风格到标签 ==========
func apply_pixel_label_style(label: Label, color_name: String = "WHITE", outline: bool = true, font_size: int = PIXEL_FONT_SIZE_NORMAL):
	"""应用像素风格到标签"""
	var text_color = PIXEL_PALETTE.get(color_name, PIXEL_PALETTE["WHITE"])
	label.add_theme_color_override("font_color", text_color)

	# 应用像素字体
	var font = get_pixel_font(font_size)
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)

	if outline:
		# 添加黑色描边效果
		label.add_theme_color_override("font_outline_color", PIXEL_PALETTE["BLACK"])
		label.add_theme_constant_override("outline_size", 2)

# ========== 应用像素风格到输入框 ==========
func apply_pixel_input_style(input: LineEdit, font_size: int = PIXEL_FONT_SIZE_NORMAL):
	"""应用像素风格到输入框"""
	var bg_color = PIXEL_PALETTE["BLACK"]
	var border_color = PIXEL_PALETTE["GREY"]
	var focus_color = PIXEL_PALETTE["CYAN"]
	var styles = create_pixel_input_style(bg_color, border_color, focus_color)

	input.add_theme_stylebox_override("normal", styles["normal"])
	input.add_theme_stylebox_override("focus", styles["focus"])

	# 应用像素字体
	var font = get_pixel_font(font_size)
	input.add_theme_font_override("font", font)
	input.add_theme_font_size_override("font_size", font_size)

	# 设置字体颜色
	input.add_theme_color_override("font_color", PIXEL_PALETTE["WHITE"])
	input.add_theme_color_override("font_placeholder_color", PIXEL_PALETTE["GREY"])

# ========== 应用像素风格到滑块 ==========
func apply_pixel_slider_style(slider: HSlider):
	"""应用像素风格到滑块"""
	var styles = create_pixel_slider_style()
	slider.add_theme_stylebox_override("slider", styles["track"])
	slider.add_theme_stylebox_override("grabber_area", styles["track"])
	slider.add_theme_stylebox_override("grabber_area_highlight", styles["track"])

	# 设置抓手图标（使用纯色方块）
	var grabber_icon = _create_pixel_grabber_icon()
	slider.add_theme_icon_override("grabber", grabber_icon)
	slider.add_theme_icon_override("grabber_highlight", grabber_icon)

# ========== 应用像素风格到复选框 ==========
func apply_pixel_checkbox_style(checkbox: CheckButton, font_size: int = PIXEL_FONT_SIZE_NORMAL):
	"""应用像素风格到复选框"""
	# 创建像素化的勾选框图标
	var unchecked = _create_checkbox_icon(false)
	var checked = _create_checkbox_icon(true)

	checkbox.add_theme_icon_override("off", unchecked)
	checkbox.add_theme_icon_override("on", checked)

	# 应用像素字体
	var font = get_pixel_font(font_size)
	checkbox.add_theme_font_override("font", font)
	checkbox.add_theme_font_size_override("font_size", font_size)

	checkbox.add_theme_color_override("font_color", PIXEL_PALETTE["WHITE"])

# ========== 创建像素滑块抓手图标 ==========
func _create_pixel_grabber_icon() -> ImageTexture:
	"""创建像素化的滑块抓手图标"""
	var size = 16
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# 绘制实心方块
	for x in range(2, size - 2):
		for y in range(2, size - 2):
			if x >= 3 and x < size - 3 and y >= 3 and y < size - 3:
				image.set_pixel(x, y, PIXEL_PALETTE["CYAN"])
			else:
				image.set_pixel(x, y, PIXEL_PALETTE["WHITE"])

	return ImageTexture.create_from_image(image)

# ========== 创建像素复选框图标 ==========
func _create_checkbox_icon(checked: bool) -> ImageTexture:
	"""创建像素化的复选框图标"""
	var size = 20
	var image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))

	# 绘制边框
	for x in range(size):
		image.set_pixel(x, 0, PIXEL_PALETTE["WHITE"])
		image.set_pixel(x, size - 1, PIXEL_PALETTE["WHITE"])
	for y in range(size):
		image.set_pixel(0, y, PIXEL_PALETTE["WHITE"])
		image.set_pixel(size - 1, y, PIXEL_PALETTE["WHITE"])

	# 填充背景
	for x in range(2, size - 2):
		for y in range(2, size - 2):
			image.set_pixel(x, y, PIXEL_PALETTE["DARK_GREY"])

	# 如果选中，绘制勾
	if checked:
		var check_color = PIXEL_PALETTE["GREEN"]
		# 简单的勾形状
		for i in range(5, 9):
			image.set_pixel(6, i, check_color)
			image.set_pixel(7, i, check_color)
		for i in range(9, 15):
			image.set_pixel(i - 2, 16 - i, check_color)
			image.set_pixel(i - 1, 16 - i, check_color)

	return ImageTexture.create_from_image(image)

# ========== 辅助函数：颜色变亮/变暗 ==========
func _brighten_color(color: Color, factor: float) -> Color:
	"""调整颜色亮度"""
	var h = color.h
	var s = color.s
	var v = color.v * factor
	v = clamp(v, 0.0, 1.0)
	return Color.from_hsv(h, s, v, color.a)

# ========== 批量应用像素风格到所有子节点 ==========
func apply_pixel_style_recursive(node: Node, default_font_size: int = PIXEL_FONT_SIZE_NORMAL):
	"""递归应用像素风格到节点及其所有子节点"""
	if node is Button:
		apply_pixel_button_style(node, "BLUE", default_font_size)
	elif node is Panel or node is PanelContainer:
		apply_pixel_panel_style(node)
	elif node is Label:
		apply_pixel_label_style(node, "WHITE", true, default_font_size)
	elif node is LineEdit:
		apply_pixel_input_style(node, default_font_size)
	elif node is HSlider:
		apply_pixel_slider_style(node)
	elif node is CheckButton:
		apply_pixel_checkbox_style(node, default_font_size)

	# 递归处理子节点
	for child in node.get_children():
		apply_pixel_style_recursive(child, default_font_size)

# ========== 便捷函数：应用标题样式 ==========
func apply_title_style(label: Label, color_name: String = "YELLOW"):
	"""应用像素标题样式（大字体+描边）"""
	apply_pixel_label_style(label, color_name, true, PIXEL_FONT_SIZE_TITLE)

# ========== 便捷函数：应用副标题样式 ==========
func apply_subtitle_style(label: Label, color_name: String = "WHITE"):
	"""应用像素副标题样式"""
	apply_pixel_label_style(label, color_name, true, PIXEL_FONT_SIZE_LARGE)

# ========== 便捷函数：应用正文样式 ==========
func apply_body_style(label: Label, color_name: String = "WHITE"):
	"""应用像素正文样式"""
	apply_pixel_label_style(label, color_name, true, PIXEL_FONT_SIZE_NORMAL)

# ========== 便捷函数：应用小字样式 ==========
func apply_small_text_style(label: Label, color_name: String = "LIGHT_GREY"):
	"""应用像素小字样式"""
	apply_pixel_label_style(label, color_name, true, PIXEL_FONT_SIZE_SMALL)

# ========== 便捷函数：应用主按钮样式 ==========
func apply_primary_button_style(button: Button):
	"""应用主要按钮样式（蓝色，大字体）"""
	apply_pixel_button_style(button, "BLUE", PIXEL_FONT_SIZE_LARGE)

# ========== 便捷函数：应用次要按钮样式 ==========
func apply_secondary_button_style(button: Button):
	"""应用次要按钮样式（灰色，普通字体）"""
	apply_pixel_button_style(button, "GREY", PIXEL_FONT_SIZE_NORMAL)

# ========== 便捷函数：应用危险按钮样式 ==========
func apply_danger_button_style(button: Button):
	"""应用危险按钮样式（红色，普通字体）"""
	apply_pixel_button_style(button, "RED", PIXEL_FONT_SIZE_NORMAL)

# ========== 便捷函数：应用成功按钮样式 ==========
func apply_success_button_style(button: Button):
	"""应用成功按钮样式（绿色，普通字体）"""
	apply_pixel_button_style(button, "GREEN", PIXEL_FONT_SIZE_NORMAL)
