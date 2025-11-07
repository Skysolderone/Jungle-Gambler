extends Node

# 魂印背包系统 - 基于管道连接的战斗系统

# 魂印品质
enum Quality {
	COMMON,      # 普通 - 白色
	UNCOMMON,    # 非凡 - 绿色
	RARE,        # 稀有 - 蓝色
	EPIC,        # 史诗 - 紫色
	LEGENDARY,   # 传说 - 橙色
	MYTHIC       # 神话 - 红色
}

# 管道端口（用于管道连接系统）
enum PipePort {
	NONE   = 0,   # 0000
	UP     = 1,   # 0001
	DOWN   = 2,   # 0010
	LEFT   = 4,   # 0100
	RIGHT  = 8    # 1000
}

# 管道形状类型
enum PipeShapeType {
	STRAIGHT_H,   # 直管-横 ━
	STRAIGHT_V,   # 直管-竖 ┃
	BEND_LU,      # 弯管-左上 ┛
	BEND_LD,      # 弯管-左下 ┓
	BEND_RU,      # 弯管-右上 ┗
	BEND_RD,      # 弯管-右下 ┏
	T_UP,         # T型-上开口 ┻
	T_DOWN,       # T型-下开口 ┳
	T_LEFT,       # T型-左开口 ┫
	T_RIGHT,      # T型-右开口 ┣
	CROSS,        # 十字型 ╋
	SOURCE,       # 起点 ◉
	SINK          # 终点 ◎
}

# 魂印类型
enum SoulType {
	ACTIVE,   # 主动类型：战斗中直接生效
	PASSIVE   # 被动类型：战斗中有概率触发
}

# 魂印数据类
class SoulPrint:
	var id: String
	var name: String
	var description: String
	var quality: Quality
	var icon: String
	var power: int  # 魂印基础力量
	
	# 魂印类型系统
	var soul_type: SoulType  # 魂印类型（主动/被动）
	
	# 主动类型属性
	var active_multiplier: float  # 主动纯倍率（如 1.5 表示 1.5x）
	var active_bonus_percent: float  # 主动加成百分比（如 0.5 表示 +50%）
	
	# 被动类型属性
	var passive_trigger_chance: float  # 被动触发概率（0.0-1.0）
	var passive_bonus_flat: int  # 被动纯数值加成
	var passive_bonus_multiplier: float  # 被动倍率加成（如 1.5 表示 1.5x）
	
	# 管道系统属性
	var pipe_shape_type: PipeShapeType  # 管道形状类型
	var pipe_ports: int  # 端口位掩码（使用PipePort组合）
	var rotation: int  # 旋转角度 0/1/2/3 对应 0°/90°/180°/270°
	var grid_pos: Vector2i  # 在管道网格中的位置（-1,-1表示未放置）
	var is_connected: bool  # 是否连通到能量路径

	func _init(soul_id: String, soul_name: String, soul_quality: Quality):
		id = soul_id
		name = soul_name
		description = ""
		quality = soul_quality
		icon = ""
		power = 10

		# 初始化魂印类型系统
		soul_type = SoulType.ACTIVE
		active_multiplier = 0.0
		active_bonus_percent = 0.0
		passive_trigger_chance = 0.0
		passive_bonus_flat = 0
		passive_bonus_multiplier = 0.0
		
		# 初始化管道属性
		pipe_shape_type = _quality_to_pipe_shape(soul_quality)
		pipe_ports = _get_pipe_ports(pipe_shape_type)
		rotation = 0
		grid_pos = Vector2i(-1, -1)
		is_connected = false

	func get_effect_description() -> String:
		# 返回魂印效果的描述文本
		match soul_type:
			SoulType.ACTIVE:
				# 主动类型描述
				var desc = "主动："
				if active_multiplier > 0:
					desc += " %.1fx 伤害倍率" % active_multiplier
				elif active_bonus_percent > 0:
					desc += " +%d%% 伤害" % int(active_bonus_percent * 100)
				else:
					desc += " 无特殊效果"
				return desc
			SoulType.PASSIVE:
				# 被动类型描述
				var desc = "被动："
				var chance_text = " %d%% 概率" % int(passive_trigger_chance * 100)
				if passive_bonus_flat > 0 and passive_bonus_multiplier > 0:
					desc += chance_text + " +%d 伤害 + %.1fx 暴击" % [passive_bonus_flat, passive_bonus_multiplier]
				elif passive_bonus_flat > 0:
					desc += chance_text + " +%d 伤害" % passive_bonus_flat
				elif passive_bonus_multiplier > 0:
					desc += chance_text + " %.1fx 暴击" % passive_bonus_multiplier
				else:
					desc += " 无特殊效果"
				return desc
		return ""
	
	func _quality_to_pipe_shape(soul_quality: Quality) -> PipeShapeType:
		"""根据魂印品质分配管道形状"""
		match soul_quality:
			Quality.COMMON, Quality.UNCOMMON:
				# 普通/非凡 - 简单形状（直管、弯管）
				return [PipeShapeType.STRAIGHT_H, PipeShapeType.BEND_RD][randi() % 2]
			Quality.RARE, Quality.EPIC:
				# 稀有/史诗 - T型管（3端口）
				return [PipeShapeType.T_UP, PipeShapeType.T_DOWN, 
						PipeShapeType.T_LEFT, PipeShapeType.T_RIGHT][randi() % 4]
			Quality.LEGENDARY, Quality.MYTHIC:
				# 传说/神话 - 十字管（4端口，最灵活）
				return PipeShapeType.CROSS
		return PipeShapeType.STRAIGHT_H
	
	func _get_pipe_ports(pipe_shape: PipeShapeType) -> int:
		"""获取管道形状的端口配置"""
		match pipe_shape:
			PipeShapeType.STRAIGHT_H:
				return PipePort.LEFT | PipePort.RIGHT
			PipeShapeType.STRAIGHT_V:
				return PipePort.UP | PipePort.DOWN
			PipeShapeType.BEND_LU:
				return PipePort.LEFT | PipePort.UP
			PipeShapeType.BEND_LD:
				return PipePort.LEFT | PipePort.DOWN
			PipeShapeType.BEND_RU:
				return PipePort.RIGHT | PipePort.UP
			PipeShapeType.BEND_RD:
				return PipePort.RIGHT | PipePort.DOWN
			PipeShapeType.T_UP:
				return PipePort.LEFT | PipePort.RIGHT | PipePort.UP
			PipeShapeType.T_DOWN:
				return PipePort.LEFT | PipePort.RIGHT | PipePort.DOWN
			PipeShapeType.T_LEFT:
				return PipePort.UP | PipePort.DOWN | PipePort.LEFT
			PipeShapeType.T_RIGHT:
				return PipePort.UP | PipePort.DOWN | PipePort.RIGHT
			PipeShapeType.CROSS:
				return PipePort.UP | PipePort.DOWN | PipePort.LEFT | PipePort.RIGHT
			PipeShapeType.SOURCE:
				return PipePort.RIGHT  # 起点只有右侧出口
			PipeShapeType.SINK:
				return PipePort.LEFT   # 终点只有左侧入口
		return PipePort.NONE

	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"description": description,
			"quality": quality,
			"icon": icon,
			"power": power,
			"soul_type": soul_type,
			"active_multiplier": active_multiplier,
			"active_bonus_percent": active_bonus_percent,
			"passive_trigger_chance": passive_trigger_chance,
			"passive_bonus_flat": passive_bonus_flat,
			"passive_bonus_multiplier": passive_bonus_multiplier,
			"pipe_shape_type": pipe_shape_type,
			"pipe_ports": pipe_ports,
			"rotation": rotation,
			"grid_pos": {"x": grid_pos.x, "y": grid_pos.y},
			"is_connected": is_connected
		}
	
	static func from_dict(data: Dictionary) -> SoulPrint:
		var soul = SoulPrint.new(
			data.get("id", ""),
			data.get("name", ""),
			data.get("quality", Quality.COMMON)
		)
		soul.description = data.get("description", "")
		soul.icon = data.get("icon", "")
		soul.power = data.get("power", 10)
		soul.soul_type = data.get("soul_type", SoulType.ACTIVE)
		soul.active_multiplier = data.get("active_multiplier", 0.0)
		soul.active_bonus_percent = data.get("active_bonus_percent", 0.0)
		soul.passive_trigger_chance = data.get("passive_trigger_chance", 0.0)
		soul.passive_bonus_flat = data.get("passive_bonus_flat", 0)
		soul.passive_bonus_multiplier = data.get("passive_bonus_multiplier", 0.0)
		
		# 管道属性
		if data.has("pipe_shape_type"):
			soul.pipe_shape_type = data.get("pipe_shape_type")
			soul.pipe_ports = data.get("pipe_ports", soul._get_pipe_ports(soul.pipe_shape_type))
		soul.rotation = data.get("rotation", 0)
		if data.has("grid_pos"):
			var pos = data["grid_pos"]
			soul.grid_pos = Vector2i(pos.get("x", -1), pos.get("y", -1))
		soul.is_connected = data.get("is_connected", false)
		
		return soul

# 背包物品类（包装了SoulPrint和位置信息）
class InventoryItem:
	var soul_print: SoulPrint
	var grid_position: Vector2i  # 在8x10背包网格中的位置
	var rotation_state: int  # 旋转状态（0-3）
	var uses: int  # 使用次数（-1表示无限）
	
	func _init(soul: SoulPrint, pos: Vector2i = Vector2i(0, 0), rot: int = 0, use_count: int = -1):
		soul_print = soul
		grid_position = pos
		rotation_state = rot
		uses = use_count
	
	func get_occupied_cells() -> Array:
		"""获取魂印占据的格子（管道系统下每个魂印只占1个格子）"""
		return [[grid_position.x, grid_position.y]]
	
	func to_dict() -> Dictionary:
		return {
			"soul_print": soul_print.to_dict(),
			"grid_position": {"x": grid_position.x, "y": grid_position.y},
			"rotation_state": rotation_state,
			"uses": uses
		}
	
	static func from_dict(data: Dictionary) -> InventoryItem:
		var soul = SoulPrint.from_dict(data["soul_print"])
		var pos_data = data["grid_position"]
		var pos = Vector2i(pos_data["x"], pos_data["y"])
		return InventoryItem.new(
			soul,
			pos,
			data.get("rotation_state", 0),
			data.get("uses", -1)
		)

# 全局变量
var soul_database: Dictionary = {}  # 所有魂印的数据库 {id: SoulPrint}
var player_inventory: Array = []  # 玩家背包中的魂印 [InventoryItem]（已弃用，保留兼容）
var _user_inventories: Dictionary = {}  # 多用户背包 {username: [InventoryItem]}
const INVENTORY_WIDTH = 8
const INVENTORY_HEIGHT = 10

func _ready():
	_initialize_soul_database()

# 多用户背包管理

func get_user_inventory(username: String) -> Array:
	"""获取指定用户的魂印背包"""
	if not _user_inventories.has(username):
		# 第一次访问时，尝试从文件加载
		load_user_inventory(username)
	return _user_inventories[username]

func add_soul_to_user_inventory(username: String, soul_id: String, position: Vector2i = Vector2i(-1, -1)) -> bool:
	"""添加魂印到指定用户的背包"""
	if not soul_database.has(soul_id):
		print("错误：魂印ID不存在: ", soul_id)
		return false
	
	var soul = soul_database[soul_id]
	
	# 如果没有指定位置，自动寻找空位
	if position == Vector2i(-1, -1):
		position = _find_empty_slot_for_user(username)
		if position == Vector2i(-1, -1):
			print("背包已满，无法添加魂印 %s" % soul.name)
			return false
	
	var item = InventoryItem.new(soul, position)
	
	if not _user_inventories.has(username):
		_user_inventories[username] = []
	
	_user_inventories[username].append(item)
	
	# 自动保存用户库存
	save_user_inventory(username)
	print("已添加魂印 %s 到用户 %s 的背包位置 (%d, %d)，并保存库存" % [soul.name, username, position.x, position.y])
	
	return true

func _find_empty_slot_for_user(username: String) -> Vector2i:
	"""为指定用户在背包中寻找空位"""
	var inventory = get_user_inventory(username)
	
	for y in range(INVENTORY_HEIGHT):
		for x in range(INVENTORY_WIDTH):
			var pos = Vector2i(x, y)
			var is_empty = true
			
			# 检查该位置是否已被占用
			for item in inventory:
				var cells = item.get_occupied_cells()
				for cell in cells:
					if cell[0] == pos.x and cell[1] == pos.y:
						is_empty = false
						break
				if not is_empty:
					break
			
			if is_empty:
				return pos
	
	return Vector2i(-1, -1)  # 没有空位

func add_soul_print(username: String, soul_id: String) -> bool:
	"""添加魂印到用户背包（兼容旧API）"""
	return add_soul_to_user_inventory(username, soul_id)

func remove_soul_from_user_inventory(username: String, item_index: int) -> bool:
	"""从指定用户背包中移除魂印"""
	if not _user_inventories.has(username):
		return false
	
	var inventory = _user_inventories[username]
	if item_index < 0 or item_index >= inventory.size():
		return false
	
	inventory.remove_at(item_index)
	return true

func remove_soul_print(username: String, item_index: int) -> bool:
	"""从用户背包移除魂印（兼容旧API）"""
	return remove_soul_from_user_inventory(username, item_index)

func get_max_inventory_capacity(username: String) -> int:
	"""获取用户背包最大容量"""
	return INVENTORY_WIDTH * INVENTORY_HEIGHT  # 8 × 10 = 80

func give_starter_souls(username: String):
	"""给新玩家发放初始魂印（新手礼包）"""
	# 发放6个初始魂印，涵盖不同品质
	var starter_souls = [
		"common_01",     # 普通 - 破损的剑刃
		"common_02",     # 普通 - 旧木盾
		"uncommon_01",   # 非凡 - 精钢剑
		"uncommon_02",   # 非凡 - 铁制盾牌
		"rare_01",       # 稀有 - 秘银之刃
		"rare_02",       # 稀有 - 符文盾
	]
	
	var pos_x = 0
	var pos_y = 0
	
	for soul_id in starter_souls:
		add_soul_to_user_inventory(username, soul_id, Vector2i(pos_x, pos_y))
		pos_x += 1
		if pos_x >= INVENTORY_WIDTH:
			pos_x = 0
			pos_y += 1
	
	print("已为用户 %s 发放新手礼包，共 %d 个魂印" % [username, starter_souls.size()])

func move_soul_print(username: String, item_index: int, new_x: int, new_y: int, new_rotation: int = -1) -> bool:
	"""移动/旋转背包中的魂印"""
	if not _user_inventories.has(username):
		return false
	
	var inventory = _user_inventories[username]
	if item_index < 0 or item_index >= inventory.size():
		return false
	
	# 检查新位置是否在有效范围内
	if new_x < 0 or new_x >= INVENTORY_WIDTH or new_y < 0 or new_y >= INVENTORY_HEIGHT:
		return false
	
	var item = inventory[item_index]
	item.grid_position = Vector2i(new_x, new_y)
	
	# 如果指定了新的旋转角度，则更新
	if new_rotation >= 0:
		item.rotation_state = new_rotation % 4
	
	return true

func use_soul_print(username: String, item_index: int) -> bool:
	"""使用魂印（减少使用次数）"""
	if not _user_inventories.has(username):
		return false
	
	var inventory = _user_inventories[username]
	if item_index < 0 or item_index >= inventory.size():
		return false
	
	var item = inventory[item_index]
	
	# 如果是无限使用（-1），不减少次数
	if item.uses == -1:
		return true
	
	# 减少使用次数
	if item.uses > 0:
		item.uses -= 1
		print("魂印 %s 使用次数：%d" % [item.soul_print.name, item.uses])
		
		# 如果使用次数为0，可选：自动删除（根据游戏设计决定）
		# if item.uses == 0:
		#     inventory.remove_at(item_index)
		
		return true
	
	return false

func save_user_inventory(username: String):
	"""保存指定用户的背包数据"""
	if not _user_inventories.has(username):
		return
	
	var data = {
		"username": username,
		"inventory": []
	}
	
	for item in _user_inventories[username]:
		data["inventory"].append(item.to_dict())
	
	var file_path = "user://inventory_%s.json" % username
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("用户 %s 的背包已保存" % username)

func load_user_inventory(username: String):
	"""加载指定用户的背包数据"""
	var file_path = "user://inventory_%s.json" % username
	if not FileAccess.file_exists(file_path):
		print("没有找到用户 %s 的背包存档" % username)
		_user_inventories[username] = []
		return
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			_user_inventories[username] = []
			for item_data in data.get("inventory", []):
				var item = InventoryItem.from_dict(item_data)
				_user_inventories[username].append(item)
			print("用户 %s 的背包已加载，共 %d 个魂印" % [username, _user_inventories[username].size()])
		else:
			print("解析用户 %s 的背包数据失败" % username)
			_user_inventories[username] = []

func _initialize_soul_database():
	"""初始化魂印数据库 - 36个不同的魂印"""
	
	# 品质0：普通 (6个)
	_create_soul("common_01", "破损的剑刃", Quality.COMMON, 8, SoulType.ACTIVE, 1.2, 0.0)
	_create_soul("common_02", "旧木盾", Quality.COMMON, 6, SoulType.PASSIVE, 0.0, 0.0, 0.3, 5, 0.0)
	_create_soul("common_03", "碎裂的宝石", Quality.COMMON, 7, SoulType.ACTIVE, 0.0, 0.15)
	_create_soul("common_04", "生锈的匕首", Quality.COMMON, 9, SoulType.ACTIVE, 1.1, 0.0)
	_create_soul("common_05", "褪色的护符", Quality.COMMON, 5, SoulType.PASSIVE, 0.0, 0.0, 0.25, 3, 0.0)
	_create_soul("common_06", "断裂的长矛", Quality.COMMON, 8, SoulType.ACTIVE, 1.15, 0.0)
	
	# 品质1：非凡 (6个)
	_create_soul("uncommon_01", "精钢剑", Quality.UNCOMMON, 15, SoulType.ACTIVE, 1.5, 0.0)
	_create_soul("uncommon_02", "铁制盾牌", Quality.UNCOMMON, 12, SoulType.PASSIVE, 0.0, 0.0, 0.4, 8, 0.0)
	_create_soul("uncommon_03", "绿宝石", Quality.UNCOMMON, 14, SoulType.ACTIVE, 0.0, 0.25)
	_create_soul("uncommon_04", "精制弓箭", Quality.UNCOMMON, 16, SoulType.ACTIVE, 1.4, 0.0)
	_create_soul("uncommon_05", "强化护符", Quality.UNCOMMON, 11, SoulType.PASSIVE, 0.0, 0.0, 0.35, 6, 0.0)
	_create_soul("uncommon_06", "战斧", Quality.UNCOMMON, 17, SoulType.ACTIVE, 1.6, 0.0)
	
	# 品质2：稀有 (6个)
	_create_soul("rare_01", "秘银之刃", Quality.RARE, 25, SoulType.ACTIVE, 2.0, 0.0)
	_create_soul("rare_02", "符文盾", Quality.RARE, 20, SoulType.PASSIVE, 0.0, 0.0, 0.5, 15, 0.0)
	_create_soul("rare_03", "蓝宝石", Quality.RARE, 23, SoulType.ACTIVE, 0.0, 0.4)
	_create_soul("rare_04", "精灵长弓", Quality.RARE, 27, SoulType.ACTIVE, 1.8, 0.0)
	_create_soul("rare_05", "魔法护符", Quality.RARE, 22, SoulType.PASSIVE, 0.0, 0.0, 0.45, 12, 1.3)
	_create_soul("rare_06", "雷霆之锤", Quality.RARE, 28, SoulType.ACTIVE, 2.2, 0.0)
	
	# 品质3：史诗 (6个)
	_create_soul("epic_01", "龙骨剑", Quality.EPIC, 40, SoulType.ACTIVE, 2.5, 0.0)
	_create_soul("epic_02", "泰坦之盾", Quality.EPIC, 35, SoulType.PASSIVE, 0.0, 0.0, 0.6, 25, 0.0)
	_create_soul("epic_03", "紫水晶", Quality.EPIC, 38, SoulType.ACTIVE, 0.0, 0.6)
	_create_soul("epic_04", "凤凰之翼", Quality.EPIC, 42, SoulType.ACTIVE, 2.3, 0.0)
	_create_soul("epic_05", "古神护符", Quality.EPIC, 37, SoulType.PASSIVE, 0.0, 0.0, 0.55, 20, 1.5)
	_create_soul("epic_06", "毁灭之镰", Quality.EPIC, 45, SoulType.ACTIVE, 2.8, 0.0)
	
	# 品质4：传说 (6个)
	_create_soul("legendary_01", "圣剑·誓约胜利之剑", Quality.LEGENDARY, 60, SoulType.ACTIVE, 3.5, 0.0)
	_create_soul("legendary_02", "神盾·埃吉斯", Quality.LEGENDARY, 55, SoulType.PASSIVE, 0.0, 0.0, 0.7, 40, 0.0)
	_create_soul("legendary_03", "帝王宝石", Quality.LEGENDARY, 58, SoulType.ACTIVE, 0.0, 0.8)
	_create_soul("legendary_04", "神弓·甘地瓦", Quality.LEGENDARY, 62, SoulType.ACTIVE, 3.2, 0.0)
	_create_soul("legendary_05", "永恒护符", Quality.LEGENDARY, 57, SoulType.PASSIVE, 0.0, 0.0, 0.65, 35, 2.0)
	_create_soul("legendary_06", "弑神之矛", Quality.LEGENDARY, 65, SoulType.ACTIVE, 4.0, 0.0)
	
	# 品质5：神话 (6个)
	_create_soul("mythic_01", "创世之刃", Quality.MYTHIC, 100, SoulType.ACTIVE, 5.0, 0.0)
	_create_soul("mythic_02", "混沌之盾", Quality.MYTHIC, 90, SoulType.PASSIVE, 0.0, 0.0, 0.8, 60, 0.0)
	_create_soul("mythic_03", "宇宙之心", Quality.MYTHIC, 95, SoulType.ACTIVE, 0.0, 1.2)
	_create_soul("mythic_04", "终末之箭", Quality.MYTHIC, 105, SoulType.ACTIVE, 4.5, 0.0)
	_create_soul("mythic_05", "不朽圣物", Quality.MYTHIC, 92, SoulType.PASSIVE, 0.0, 0.0, 0.75, 50, 2.5)
	_create_soul("mythic_06", "真理之杖", Quality.MYTHIC, 110, SoulType.ACTIVE, 6.0, 0.0)

func _create_soul(soul_id: String, soul_name: String, soul_quality: Quality, 
				 base_power: int, s_type: SoulType,
				 act_mult: float = 0.0, act_bonus: float = 0.0,
				 pass_chance: float = 0.0, pass_flat: int = 0, pass_mult: float = 0.0):
	"""创建并添加魂印到数据库"""
	var soul = SoulPrint.new(soul_id, soul_name, soul_quality)
	soul.power = base_power
	soul.soul_type = s_type
	soul.active_multiplier = act_mult
	soul.active_bonus_percent = act_bonus
	soul.passive_trigger_chance = pass_chance
	soul.passive_bonus_flat = pass_flat
	soul.passive_bonus_multiplier = pass_mult
	soul_database[soul_id] = soul

# 管道辅助函数（节点级别）

func rotate_pipe_ports(ports: int, rotation: int) -> int:
	"""旋转管道端口（顺时针90度 * rotation次）"""
	var result = ports
	for i in range(rotation % 4):
		var new_ports = 0
		if result & PipePort.UP:
			new_ports |= PipePort.RIGHT
		if result & PipePort.RIGHT:
			new_ports |= PipePort.DOWN
		if result & PipePort.DOWN:
			new_ports |= PipePort.LEFT
		if result & PipePort.LEFT:
			new_ports |= PipePort.UP
		result = new_ports
	return result

func get_pipe_symbol(pipe_shape: PipeShapeType, rotation: int) -> String:
	"""获取管道形状的Unicode符号（考虑旋转）"""
	var base_ports = _get_pipe_ports_static(pipe_shape)
	var rotated_ports = rotate_pipe_ports(base_ports, rotation)
	return _ports_to_symbol(rotated_ports)

func get_pipe_texture_path(pipe_shape: PipeShapeType, rotation: int) -> String:
	"""获取管道形状的SVG纹理路径（考虑旋转）"""
	var base_ports = _get_pipe_ports_static(pipe_shape)
	var rotated_ports = rotate_pipe_ports(base_ports, rotation)
	return _ports_to_texture_path(rotated_ports)

func _get_pipe_ports_static(pipe_shape: PipeShapeType) -> int:
	"""静态方法获取基础端口配置"""
	match pipe_shape:
		PipeShapeType.STRAIGHT_H:
			return PipePort.LEFT | PipePort.RIGHT
		PipeShapeType.STRAIGHT_V:
			return PipePort.UP | PipePort.DOWN
		PipeShapeType.BEND_LU:
			return PipePort.LEFT | PipePort.UP
		PipeShapeType.BEND_LD:
			return PipePort.LEFT | PipePort.DOWN
		PipeShapeType.BEND_RU:
			return PipePort.RIGHT | PipePort.UP
		PipeShapeType.BEND_RD:
			return PipePort.RIGHT | PipePort.DOWN
		PipeShapeType.T_UP:
			return PipePort.LEFT | PipePort.RIGHT | PipePort.UP
		PipeShapeType.T_DOWN:
			return PipePort.LEFT | PipePort.RIGHT | PipePort.DOWN
		PipeShapeType.T_LEFT:
			return PipePort.UP | PipePort.DOWN | PipePort.LEFT
		PipeShapeType.T_RIGHT:
			return PipePort.UP | PipePort.DOWN | PipePort.RIGHT
		PipeShapeType.CROSS:
			return PipePort.UP | PipePort.DOWN | PipePort.LEFT | PipePort.RIGHT
		PipeShapeType.SOURCE:
			return PipePort.RIGHT
		PipeShapeType.SINK:
			return PipePort.LEFT
	return PipePort.NONE

func _ports_to_symbol(ports: int) -> String:
	"""将端口配置转换为Unicode符号"""
	var u = (ports & PipePort.UP) != 0
	var d = (ports & PipePort.DOWN) != 0
	var l = (ports & PipePort.LEFT) != 0
	var r = (ports & PipePort.RIGHT) != 0
	
	if u and d and l and r:
		return "╋"  # 十字
	elif u and d and l:
		return "┫"  # T-左
	elif u and d and r:
		return "┣"  # T-右
	elif u and l and r:
		return "┻"  # T-上
	elif d and l and r:
		return "┳"  # T-下
	elif l and r:
		return "━"  # 横直管
	elif u and d:
		return "┃"  # 竖直管
	elif l and u:
		return "┛"  # 左上弯
	elif l and d:
		return "┓"  # 左下弯
	elif r and u:
		return "┗"  # 右上弯
	elif r and d:
		return "┏"  # 右下弯
	elif r:
		return "◉"  # 起点（只有右）
	elif l:
		return "◎"  # 终点（只有左）
	return "●"

func _ports_to_texture_path(ports: int) -> String:
	"""将端口配置转换为SVG纹理路径"""
	var u = (ports & PipePort.UP) != 0
	var d = (ports & PipePort.DOWN) != 0
	var l = (ports & PipePort.LEFT) != 0
	var r = (ports & PipePort.RIGHT) != 0
	
	if u and d and l and r:
		return "res://assets/ui/pipes/pipe_cross.svg"
	elif u and d and l:
		return "res://assets/ui/pipes/pipe_t_left.svg"
	elif u and d and r:
		return "res://assets/ui/pipes/pipe_t_right.svg"
	elif u and l and r:
		return "res://assets/ui/pipes/pipe_t_up.svg"
	elif d and l and r:
		return "res://assets/ui/pipes/pipe_t_down.svg"
	elif l and r:
		return "res://assets/ui/pipes/pipe_straight_h.svg"
	elif u and d:
		return "res://assets/ui/pipes/pipe_straight_v.svg"
	elif l and u:
		return "res://assets/ui/pipes/pipe_bend_lu.svg"
	elif l and d:
		return "res://assets/ui/pipes/pipe_bend_ld.svg"
	elif r and u:
		return "res://assets/ui/pipes/pipe_bend_ru.svg"
	elif r and d:
		return "res://assets/ui/pipes/pipe_bend_rd.svg"
	elif r:
		return "res://assets/ui/pipes/pipe_source.svg"
	elif l:
		return "res://assets/ui/pipes/pipe_sink.svg"
	return "res://assets/ui/pipes/pipe_source.svg"

func get_direction_vector(port: int) -> Vector2i:
	"""将端口转换为方向向量"""
	match port:
		PipePort.UP:
			return Vector2i(0, -1)
		PipePort.DOWN:
			return Vector2i(0, 1)
		PipePort.LEFT:
			return Vector2i(-1, 0)
		PipePort.RIGHT:
			return Vector2i(1, 0)
	return Vector2i(0, 0)

func get_opposite_port(port: int) -> int:
	"""获取相反方向的端口"""
	match port:
		PipePort.UP:
			return PipePort.DOWN
		PipePort.DOWN:
			return PipePort.UP
		PipePort.LEFT:
			return PipePort.RIGHT
		PipePort.RIGHT:
			return PipePort.LEFT
	return PipePort.NONE

# 背包管理函数

func add_soul_to_inventory(soul_id: String, position: Vector2i = Vector2i(-1, -1)) -> bool:
	"""添加魂印到背包"""
	if not soul_database.has(soul_id):
		print("错误：魂印ID不存在: ", soul_id)
		return false
	
	var soul = soul_database[soul_id]
	
	# 如果没有指定位置，自动寻找空位
	if position == Vector2i(-1, -1):
		position = _find_empty_slot()
		if position == Vector2i(-1, -1):
			print("背包已满")
			return false
	
	var item = InventoryItem.new(soul, position)
	player_inventory.append(item)
	return true

func _find_empty_slot() -> Vector2i:
	"""在背包中寻找空位"""
	for y in range(INVENTORY_HEIGHT):
		for x in range(INVENTORY_WIDTH):
			if _is_slot_empty(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func _is_slot_empty(pos: Vector2i) -> bool:
	"""检查指定位置是否为空"""
	for item in player_inventory:
		if item.grid_position == pos:
			return false
	return true

func get_soul_by_id(soul_id: String) -> SoulPrint:
	"""根据ID获取魂印"""
	return soul_database.get(soul_id, null)

func get_quality_color(quality: Quality) -> Color:
	"""获取品质对应的颜色（带边界检查）"""
	# 边界检查
	if quality < 0 or quality > Quality.MYTHIC:
		print("警告：品质值越界 %d，使用默认颜色" % quality)
		return Color.WHITE
	
	match quality:
		Quality.COMMON:
			return Color(0.6, 0.6, 0.6)  # 灰色
		Quality.UNCOMMON:
			return Color(0.2, 0.8, 0.2)  # 绿色
		Quality.RARE:
			return Color(0.2, 0.5, 1.0)  # 蓝色
		Quality.EPIC:
			return Color(0.8, 0.2, 0.8)  # 紫色
		Quality.LEGENDARY:
			return Color(1.0, 0.6, 0.0)  # 橙色
		Quality.MYTHIC:
			return Color(1.0, 0.2, 0.2)  # 红色
	return Color.WHITE

func get_quality_name(quality: Quality) -> String:
	"""获取品质对应的名称（带边界检查）"""
	var names = ["普通", "非凡", "稀有", "史诗", "传说", "神话"]
	if quality >= 0 and quality < names.size():
		return names[quality]
	print("警告：品质值越界 %d" % quality)
	return "未知"

func get_quality_colors_array() -> Array:
	"""获取所有品质颜色数组"""
	return [
		Color(0.5, 0.5, 0.5),    # 普通
		Color(0.2, 0.7, 0.2),    # 非凡
		Color(0.2, 0.5, 0.9),    # 稀有
		Color(0.6, 0.2, 0.8),    # 史诗
		Color(0.9, 0.6, 0.2),    # 传说
		Color(0.9, 0.3, 0.3)     # 神话
	]

# 数据持久化

func save_inventory():
	"""保存背包数据"""
	var data = {
		"inventory": []
	}
	for item in player_inventory:
		data["inventory"].append(item.to_dict())
	
	var file = FileAccess.open("user://inventory.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("背包已保存")

func load_inventory():
	"""加载背包数据"""
	if not FileAccess.file_exists("user://inventory.json"):
		print("没有找到背包存档")
		return
	
	var file = FileAccess.open("user://inventory.json", FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			var data = json.data
			player_inventory.clear()
			for item_data in data.get("inventory", []):
				var item = InventoryItem.from_dict(item_data)
				player_inventory.append(item)
			print("背包已加载，共 ", player_inventory.size(), " 个魂印")
		else:
			print("解析背包数据失败")
