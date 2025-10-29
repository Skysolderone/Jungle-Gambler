extends Control

@onready var title_label = $LootPanel/MarginContainer/VBoxContainer/HeaderContainer/TitleLabel
@onready var timer_label = $LootPanel/MarginContainer/VBoxContainer/HeaderContainer/TimerLabel
@onready var loot_label = $LootPanel/MarginContainer/VBoxContainer/ContentContainer/LootSection/LootLabel
@onready var loot_container = $LootPanel/MarginContainer/VBoxContainer/ContentContainer/LootSection/LootContainer
@onready var loot_grid = $LootPanel/MarginContainer/VBoxContainer/ContentContainer/LootSection/LootContainer/LootGrid
@onready var inventory_label = $LootPanel/MarginContainer/VBoxContainer/ContentContainer/InventorySection/InventoryLabel
@onready var inventory_container = $LootPanel/MarginContainer/VBoxContainer/ContentContainer/InventorySection/InventoryContainer
@onready var inventory_grid = $LootPanel/MarginContainer/VBoxContainer/ContentContainer/InventorySection/InventoryContainer/InventoryGrid
@onready var continue_button = $LootPanel/MarginContainer/VBoxContainer/ButtonContainer/ContinueButton

# 动态创建的对话框
var confirm_dialog: ConfirmationDialog = null
var pending_discard_index: int = -1

# 战利品数据
var enemy_souls: Array = []
var loot_souls: Array = []
var player_all_souls: Array = []
var loot_selection_time: float = 15.0
var auto_finish: bool = false

func _ready():
	# 从UserSession获取数据
	var session = get_node("/root/UserSession")
	
	if session.has_meta("battle_enemy_souls"):
		enemy_souls = session.get_meta("battle_enemy_souls")
	
	# 检查战斗结果
	if not session.has_meta("combat_result"):
		# 如果没有战斗结果，直接返回地图
		get_tree().change_scene_to_file("res://scenes/GameMap.tscn")
		return
	
	var combat_result = session.get_meta("combat_result")
	if not combat_result.get("won", false):
		# 如果战斗失败，直接返回地图
		get_tree().change_scene_to_file("res://scenes/GameMap.tscn")
		return
	
	# 初始化战利品
	loot_souls = enemy_souls.duplicate()
	
	# 获取当前背包
	var soul_system = _get_soul_system()
	if soul_system:
		var username = _get_username()
		player_all_souls = soul_system.get_user_inventory(username)
	
	title_label.text = "战利品获得"
	
	# 尝试直接添加所有战利品
	_try_auto_collect_loot()
	
	# 如果还有剩余战利品，进入选择模式
	if loot_souls.size() > 0:
		_start_loot_selection()
	else:
		_auto_finish_loot()
	
	# 应用响应式布局
	_setup_responsive_layout()

	# 创建确认对话框
	_create_confirm_dialog()

func _setup_responsive_layout():
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		
		# 连接屏幕类型变化信号
		responsive_manager.screen_type_changed.connect(_on_screen_type_changed)
		
		# 应用响应式布局
		responsive_manager.apply_responsive_layout(self)
		
		# 为移动端优化触摸
		responsive_manager.optimize_for_touch(self)
		
		print("战利品阶段已启用响应式布局，屏幕类型：", responsive_manager.get_screen_type_name())

func _on_screen_type_changed(_new_type):
	# 屏幕类型变化时重新应用布局
	_setup_responsive_layout()

func _process(delta):
	if auto_finish:
		return
	
	if loot_souls.size() > 0:
		loot_selection_time -= delta
		timer_label.text = "剩余时间: " + str(int(loot_selection_time) + 1) + "秒"
		if loot_selection_time <= 0:
			_finish_loot_selection()

func _try_auto_collect_loot():
	var soul_system = _get_soul_system()
	if not soul_system:
		print("错误：无法获取魂印系统")
		return
	
	var username = _get_username()
	if username == "":
		print("错误：无法获取用户名")
		return
	
	print("=== 自动收集战利品调试 ===")
	print("用户名: ", username)
	print("战利品数量: ", loot_souls.size())
	
	# 获取当前背包状态
	var current_inventory = soul_system.get_user_inventory(username)
	print("当前背包物品数量: ", current_inventory.size())
	
	var added_souls = []
	
	# 尝试添加所有战利品
	for i in range(loot_souls.size()):
		var soul = loot_souls[i]
		print("尝试添加战利品 ", i+1, "/", loot_souls.size(), ": ", soul.name, " (ID: ", soul.id, ")")
		
		# 检查是否能放置
		var can_fit = soul_system.can_fit_soul(username, soul.id)
		print("  能否放置: ", can_fit)
		
		if can_fit:
			var success = soul_system.add_soul_print(username, soul.id)
			print("  添加结果: ", success)
			if success:
				added_souls.append(soul)
				print("  成功获得战利品：", soul.name)
			else:
				print("  添加失败：", soul.name)
		else:
			print("  背包空间不足，无法放置：", soul.name)
	
	print("成功添加战利品数量: ", added_souls.size(), "/", loot_souls.size())
	
	# 从战利品列表中移除已添加的
	for soul in added_souls:
		loot_souls.erase(soul)
	
	# 更新背包数据
	player_all_souls = soul_system.get_user_inventory(username)
	print("更新后背包物品数量: ", player_all_souls.size())

func _start_loot_selection():
	timer_label.text = "剩余时间: " + str(int(loot_selection_time) + 1) + "秒"
	timer_label.visible = true
	continue_button.visible = false
	
	# 显示提示
	title_label.text = "背包空间不足！选择要保留的战利品"
	
	_refresh_loot_display()

func _auto_finish_loot():
	auto_finish = true
	title_label.text = "战利品获得完成！"
	timer_label.text = "获得了 " + str(enemy_souls.size()) + " 个战利品"
	timer_label.visible = true
	continue_button.visible = true
	continue_button.text = "继续"
	continue_button.pressed.connect(_finish_loot_selection)
	
	# 显示获得的战利品和当前背包
	_refresh_loot_display()

func _refresh_loot_display():
	# 清空现有网格内容
	for child in loot_grid.get_children():
		child.queue_free()
	for child in inventory_grid.get_children():
		child.queue_free()
	
	# 等待一帧确保队列中的节点被清理
	await get_tree().process_frame
	
	# 更新网格列数以适应屏幕
	_update_grid_columns()
	
	# 添加战利品卡片
	var display_souls = loot_souls if loot_souls.size() > 0 else enemy_souls
	
	# 更新战利品标签文本
	if auto_finish:
		loot_label.text = "获得的战利品 (" + str(enemy_souls.size()) + ")"
	elif loot_souls.size() > 0:
		loot_label.text = "待选择战利品 (" + str(loot_souls.size()) + ")"
	else:
		loot_label.text = "战利品"
	
	for i in range(display_souls.size()):
		var soul = display_souls[i]
		# 在自动完成状态下，战利品不可交互
		var is_interactive = not auto_finish and loot_souls.size() > 0
		var card = _create_loot_card(soul, is_interactive, i, true)  # true表示是战利品
		loot_grid.add_child(card)
	
	# 添加背包卡片
	var max_capacity = _get_max_inventory_capacity()
	inventory_label.text = "当前背包 (" + str(player_all_souls.size()) + "/" + str(max_capacity) + ")"
	
	# 显示所有背包物品（可以通过ScrollContainer滚动查看）
	for i in range(player_all_souls.size()):
		var soul_item = player_all_souls[i]
		# 在自动完成状态下，背包物品不可交互
		var is_interactive = not auto_finish
		var card = _create_loot_card(soul_item.soul_print, is_interactive, i, false)  # false表示是背包物品
		inventory_grid.add_child(card)

func _update_grid_columns():
	# 根据屏幕尺寸动态调整网格列数
	if has_node("/root/ResponsiveLayoutManager"):
		var responsive_manager = get_node("/root/ResponsiveLayoutManager")
		var columns = responsive_manager.get_grid_columns_for_screen()
		loot_grid.columns = columns
		inventory_grid.columns = columns
	else:
		# 默认列数
		loot_grid.columns = 4
		inventory_grid.columns = 4

func _create_loot_card(soul, is_interactive: bool, index: int, is_loot: bool) -> Button:
	var button = Button.new()
	button.custom_minimum_size = Vector2(100, 80)
	
	# 品质颜色
	var quality_colors = [
		Color(0.5, 0.5, 0.5), Color(0.2, 0.7, 0.2), Color(0.2, 0.5, 0.9),
		Color(0.6, 0.2, 0.8), Color(0.9, 0.6, 0.2), Color(0.9, 0.3, 0.3)
	]
	
	var color = quality_colors[soul.quality]
	var style = StyleBoxFlat.new()
	style.bg_color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 0.8)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	
	button.add_theme_stylebox_override("normal", style)
	
	var quality_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
	var button_text = soul.name + "\n力量: " + str(soul.power) + "\n" + quality_names[soul.quality]
	
	# 为战利品添加提示文本
	if is_loot and is_interactive:
		button_text += "\n点击获取"
	elif not is_loot and is_interactive:
		button_text += "\n点击丢弃"
	
	button.text = button_text
	
	# 连接正确的信号
	if is_interactive:
		if is_loot:
			# 战利品交互 - 获取战利品
			button.pressed.connect(func(): _on_loot_selected(index))
			print("连接战利品选择信号，索引：", index, " 魂印：", soul.name)
		else:
			# 背包交互 - 丢弃物品
			button.pressed.connect(func(): _on_inventory_discard_request(index))
			print("连接背包丢弃信号，索引：", index, " 魂印：", soul.name)

		# 确保按钮可以接收输入
		button.disabled = false
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.focus_mode = Control.FOCUS_ALL
	
	return button

func _on_loot_selected(loot_index: int):
	if loot_index >= loot_souls.size():
		print("错误：战利品索引超出范围：", loot_index, "/", loot_souls.size())
		return
	
	var soul = loot_souls[loot_index]
	var soul_system = _get_soul_system()
	if not soul_system:
		print("错误：无法获取魂印系统")
		return
	
	var username = _get_username()
	if username == "":
		print("错误：无法获取用户名")
		return
	
	# 尝试添加到背包
	print("尝试添加战利品到背包：", soul.name, " ID:", soul.id)
	var success = soul_system.add_soul_print(username, soul.id)
	print("添加结果：", success)
	
	if success:
		print("获得战利品：", soul.name)
		loot_souls.remove_at(loot_index)
		
		# 立即更新背包数据并保存
		player_all_souls = soul_system.get_user_inventory(username)
		print("背包更新后物品数量：", player_all_souls.size())
		
		# 显示成功消息
		title_label.text = "成功获得：" + soul.name + "！"
		
		# 检查是否所有战利品都已获得
		if loot_souls.size() == 0:
			await get_tree().create_timer(1.0).timeout  # 让用户看到成功消息
			_finish_loot_selection()
			return
		
		# 刷新显示
		_refresh_loot_display()
	else:
		print("背包空间不足，无法获得战利品：", soul.name)
		# 显示错误提示
		title_label.text = "背包空间不足！请先清理背包空间"

func _create_confirm_dialog():
	# 动态创建确认对话框
	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "确认丢弃"
	confirm_dialog.get_ok_button().text = "确认丢弃"
	confirm_dialog.get_cancel_button().text = "取消"
	add_child(confirm_dialog)

	# 连接确认信号
	confirm_dialog.confirmed.connect(_on_discard_confirmed)

func _on_inventory_discard_request(inventory_index: int):
	# 先检查品质，高品质魂印需要确认
	if inventory_index >= player_all_souls.size():
		return

	var soul_item = player_all_souls[inventory_index]
	var soul = soul_item.soul_print

	# 稀有及以上品质需要确认（品质>=2）
	if soul.quality >= 2:
		pending_discard_index = inventory_index

		var quality_names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
		var quality_name = quality_names[soul.quality]

		confirm_dialog.dialog_text = "确定要丢弃 [" + quality_name + "] 品质的魂印吗？\n\n" + soul.name + "\n力量: +" + str(soul.power)

		# 显示被动效果
		if soul.passive_type > 0:
			confirm_dialog.dialog_text += "\n被动: " + soul.get_passive_description()

		confirm_dialog.dialog_text += "\n\n此操作无法撤销！"
		confirm_dialog.popup_centered()
	else:
		# 普通和非凡品质直接丢弃
		_on_inventory_discard(inventory_index)

func _on_discard_confirmed():
	# 确认丢弃
	if pending_discard_index >= 0:
		_on_inventory_discard(pending_discard_index)
		pending_discard_index = -1

func _on_inventory_discard(inventory_index: int):
	if inventory_index >= player_all_souls.size():
		return

	var soul_system = _get_soul_system()
	if not soul_system:
		return

	var username = _get_username()
	var soul_item = player_all_souls[inventory_index]

	print("丢弃魂印：", soul_item.soul_print.name)

	# 从背包移除
	soul_system.remove_soul_print(username, inventory_index)
	player_all_souls = soul_system.get_user_inventory(username)

	# 显示提示
	title_label.text = "已丢弃：" + soul_item.soul_print.name

	# 刷新显示
	_refresh_loot_display()

func _finish_loot_selection():
	auto_finish = true
	
	# 计算实际获得的战利品
	var obtained_souls = []
	for soul in enemy_souls:
		if not loot_souls.has(soul):  # 不在剩余列表中，说明已获得
			obtained_souls.append(soul)
	
	print("战利品阶段结束，获得", obtained_souls.size(), "个战利品")
	
	# 保存最终战斗结果到UserSession
	var session = get_node("/root/UserSession")
	var combat_result = session.get_meta("combat_result")
	
	session.set_meta("battle_result", {
		"won": true,
		"player_hp_change": combat_result.get("player_hp_change", 0),
		"loot_souls": obtained_souls
	})
	
	# 清除临时数据
	session.remove_meta("combat_result")
	session.remove_meta("battle_enemy_souls")
	
	# 返回地图
	get_tree().change_scene_to_file("res://scenes/GameMap.tscn")

func _get_soul_system():
	if has_node("/root/SoulPrintSystem"):
		return get_node("/root/SoulPrintSystem")
	return null

func _get_username():
	if has_node("/root/UserSession"):
		return get_node("/root/UserSession").get_username()
	return ""

func _get_max_inventory_capacity() -> int:
	var soul_system = _get_soul_system()
	if soul_system and soul_system.has_method("get_max_inventory_capacity"):
		var username = _get_username()
		return soul_system.get_max_inventory_capacity(username)
	# 魂印系统的默认网格是10x8，但实际容量取决于魂印形状
	# 这里返回一个合理的估计值
	return 80
