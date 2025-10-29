extends Node

# 魂印背包系统 - 基于形状的网格背包

# 魂印品质
enum Quality {
	COMMON,      # 普通 - 白色
	UNCOMMON,    # 非凡 - 绿色
	RARE,        # 稀有 - 蓝色
	EPIC,        # 史诗 - 紫色
	LEGENDARY,   # 传说 - 橙色
	MYTHIC       # 神话 - 红色
}

# 魂印形状类型
enum ShapeType {
	SQUARE_1X1,   # 1×1 正方形
	SQUARE_2X2,   # 2×2 正方形
	RECT_1X2,     # 1×2 矩形
	RECT_2X1,     # 2×1 矩形
	RECT_1X3,     # 1×3 矩形
	RECT_3X1,     # 3×1 矩形
	L_SHAPE,      # L形状
	T_SHAPE,      # T形状
	TRIANGLE,     # 三角形（占3格）
}

# 被动效果类型
enum PassiveType {
	NONE,           # 无被动
	HEAL,           # 回血：每回合恢复HP
	POWER_CHANCE,   # 力量几率：有几率额外增加力量
	MULT_CHANCE,    # 倍率几率：有几率额外增加倍率
	SHIELD,         # 护盾：减少受到的伤害
	VAMPIRE,        # 吸血：造成伤害时回血
	CRIT_CHANCE,    # 暴击几率：有几率造成额外伤害
	DODGE,          # 闪避：有几率完全躲避伤害
}

# 魂印数据类
class SoulPrint:
	var id: String
	var name: String
	var description: String
	var quality: Quality
	var shape_type: ShapeType
	var shape_data: Array  # 形状数据 [[0,0], [0,1], [1,0]] 表示占用的相对格子
	var icon: String
	var power: int  # 魂印力量值
	var special_effect: String  # 特殊效果（已弃用，使用passive_type）

	# 被动效果系统
	var passive_type: PassiveType  # 被动类型
	var passive_value: float  # 被动数值（回血量/力量值/倍率值/几率等）
	var passive_chance: float  # 触发几率（0-1），对于需要几率判定的被动

	func _init(soul_id: String, soul_name: String, soul_quality: Quality, soul_shape: ShapeType):
		id = soul_id
		name = soul_name
		description = ""
		quality = soul_quality
		shape_type = soul_shape
		shape_data = _get_shape_data(soul_shape)
		icon = ""
		power = 10
		special_effect = ""

		# 初始化被动效果
		passive_type = PassiveType.NONE
		passive_value = 0.0
		passive_chance = 0.0

	func get_passive_description() -> String:
		# 返回被动效果的描述文本
		match passive_type:
			PassiveType.NONE:
				return ""
			PassiveType.HEAL:
				return "每回合回复 " + str(int(passive_value)) + " HP"
			PassiveType.POWER_CHANCE:
				return str(int(passive_chance * 100)) + "% 几率额外 +" + str(int(passive_value)) + " 力量"
			PassiveType.MULT_CHANCE:
				return str(int(passive_chance * 100)) + "% 几率额外 +" + str(int(passive_value * 100)) + "% 倍率"
			PassiveType.SHIELD:
				return "减少 " + str(int(passive_value)) + "% 受到的伤害"
			PassiveType.VAMPIRE:
				return "造成伤害时回复 " + str(int(passive_value * 100)) + "% HP"
			PassiveType.CRIT_CHANCE:
				return str(int(passive_chance * 100)) + "% 几率造成 " + str(int(passive_value * 100)) + "% 额外伤害"
			PassiveType.DODGE:
				return str(int(passive_value * 100)) + "% 几率闪避伤害"
		return ""
	
	func _get_shape_data(shape: ShapeType) -> Array:
		match shape:
			ShapeType.SQUARE_1X1:
				return [[0, 0]]
			ShapeType.SQUARE_2X2:
				return [[0, 0], [0, 1], [1, 0], [1, 1]]
			ShapeType.RECT_1X2:
				return [[0, 0], [0, 1]]
			ShapeType.RECT_2X1:
				return [[0, 0], [1, 0]]
			ShapeType.RECT_1X3:
				return [[0, 0], [0, 1], [0, 2]]
			ShapeType.RECT_3X1:
				return [[0, 0], [1, 0], [2, 0]]
			ShapeType.L_SHAPE:
				return [[0, 0], [0, 1], [1, 0]]
			ShapeType.T_SHAPE:
				return [[0, 0], [0, 1], [0, 2], [1, 1]]
			ShapeType.TRIANGLE:
				return [[0, 0], [1, 0], [0, 1]]
		return [[0, 0]]
	
	func get_rotated_shape(rotation: int) -> Array:
		# 旋转形状数据（0, 90, 180, 270度）
		var rotated = []
		for cell in shape_data:
			var x = cell[0]
			var y = cell[1]
			match rotation:
				0:  # 0度
					rotated.append([x, y])
				1:  # 90度
					rotated.append([y, -x])
				2:  # 180度
					rotated.append([-x, -y])
				3:  # 270度
					rotated.append([-y, x])
		
		# 标准化坐标：找到最小的x和y，然后将所有坐标偏移使最小值为0
		if rotated.size() > 0:
			var min_x = rotated[0][0]
			var min_y = rotated[0][1]
			for cell in rotated:
				if cell[0] < min_x:
					min_x = cell[0]
				if cell[1] < min_y:
					min_y = cell[1]
			
			# 偏移所有坐标
			var normalized = []
			for cell in rotated:
				normalized.append([cell[0] - min_x, cell[1] - min_y])
			return normalized
		
		return rotated
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"description": description,
			"quality": quality,
			"shape_type": shape_type,
			"power": power,
			"special_effect": special_effect,
			"passive_type": passive_type,
			"passive_value": passive_value,
			"passive_chance": passive_chance
		}
	
	static func from_dict(data: Dictionary) -> SoulPrint:
		var soul = SoulPrint.new(
			data.get("id", ""),
			data.get("name", ""),
			data.get("quality", Quality.COMMON),
			data.get("shape_type", ShapeType.SQUARE_1X1)
		)
		soul.description = data.get("description", "")
		soul.power = data.get("power", 10)
		soul.special_effect = data.get("special_effect", "")
		soul.passive_type = data.get("passive_type", PassiveType.NONE)
		soul.passive_value = data.get("passive_value", 0.0)
		soul.passive_chance = data.get("passive_chance", 0.0)
		return soul

# 背包中的魂印实例
class InventoryItem:
	var soul_print: SoulPrint
	var grid_x: int  # 在背包网格中的起始X位置
	var grid_y: int  # 在背包网格中的起始Y位置
	var rotation: int  # 旋转状态 0-3
	var uses_remaining: int  # 剩余使用次数
	var max_uses: int  # 最大使用次数
	
	func _init(soul: SoulPrint, x: int, y: int, rot: int = 0):
		soul_print = soul
		grid_x = x
		grid_y = y
		rotation = rot
		max_uses = _get_max_uses_by_quality(soul.quality)
		uses_remaining = max_uses
	
	func _get_max_uses_by_quality(quality: int) -> int:
		# 根据品质确定使用次数：普通5次，非凡4次，稀有3次，史诗2次，传说1次，神话1次
		match quality:
			0: return 5  # 普通
			1: return 4  # 非凡
			2: return 3  # 稀有
			3: return 2  # 史诗
			4: return 1  # 传说
			5: return 1  # 神话
			_: return 3
	
	func get_occupied_cells() -> Array:
		# 获取该物品占用的所有格子
		var cells = []
		var rotated_shape = soul_print.get_rotated_shape(rotation)
		for cell in rotated_shape:
			cells.append([grid_x + cell[0], grid_y + cell[1]])
		return cells
	
	func to_dict() -> Dictionary:
		return {
			"soul_print": soul_print.to_dict(),
			"grid_x": grid_x,
			"grid_y": grid_y,
			"rotation": rotation,
			"uses_remaining": uses_remaining,
			"max_uses": max_uses
		}
	
	static func from_dict(data: Dictionary) -> InventoryItem:
		var soul = SoulPrint.from_dict(data["soul_print"])
		var item = InventoryItem.new(soul, data["grid_x"], data["grid_y"], data["rotation"])
		item.uses_remaining = data.get("uses_remaining", item.max_uses)
		item.max_uses = data.get("max_uses", item.max_uses)
		return item

# 背包网格大小
const GRID_WIDTH = 10
const GRID_HEIGHT = 8

# 用户背包数据
var _user_inventories: Dictionary = {}  # username -> inventory_data

const INVENTORY_DATA_PATH = "user://soul_inventory.json"

func _ready():
	_load_all_inventories()
	_initialize_soul_database()

# ========== 魂印数据库 ==========
var soul_database: Dictionary = {}

func _initialize_soul_database():
	# 普通品质魂印
	var soul_basic_1 = SoulPrint.new("soul_basic_1", "初始魂印", Quality.COMMON, ShapeType.SQUARE_1X1)
	soul_basic_1.power = 5
	soul_basic_1.description = "最基础的魂印，适合新手使用。"
	_register_soul(soul_basic_1)
	
	var soul_basic_2 = SoulPrint.new("soul_basic_2", "双生魂印", Quality.COMMON, ShapeType.RECT_1X2)
	soul_basic_2.power = 8
	soul_basic_2.description = "双格魂印，提供额外的空间利用。"
	_register_soul(soul_basic_2)
	
	# 非凡品质魂印
	var soul_forest = SoulPrint.new("soul_forest", "森林之魂", Quality.UNCOMMON, ShapeType.SQUARE_2X2)
	soul_forest.power = 15
	soul_forest.description = "蕴含森林之力，提升生命力。"
	soul_forest.passive_type = PassiveType.HEAL
	soul_forest.passive_value = 3.0  # 每回合回复3点HP
	_register_soul(soul_forest)

	var soul_wind = SoulPrint.new("soul_wind", "疾风魂印", Quality.UNCOMMON, ShapeType.RECT_1X3)
	soul_wind.power = 12
	soul_wind.description = "风之力量，提升移动速度。"
	soul_wind.passive_type = PassiveType.DODGE
	soul_wind.passive_value = 0.15  # 15%闪避率
	_register_soul(soul_wind)
	
	# 稀有品质魂印
	var soul_flame = SoulPrint.new("soul_flame", "火焰之心", Quality.RARE, ShapeType.L_SHAPE)
	soul_flame.power = 25
	soul_flame.description = "炽热的火焰之力，增强攻击力。"
	soul_flame.passive_type = PassiveType.POWER_CHANCE
	soul_flame.passive_value = 15.0  # 额外15点力量
	soul_flame.passive_chance = 0.30  # 30%触发几率
	_register_soul(soul_flame)

	var soul_ocean = SoulPrint.new("soul_ocean", "深海之力", Quality.RARE, ShapeType.T_SHAPE)
	soul_ocean.power = 28
	soul_ocean.description = "深海的神秘力量，提升防御。"
	soul_ocean.passive_type = PassiveType.SHIELD
	soul_ocean.passive_value = 0.20  # 减少20%受到的伤害
	_register_soul(soul_ocean)
	
	var soul_thunder = SoulPrint.new("soul_thunder", "雷霆之怒", Quality.EPIC, ShapeType.RECT_1X3)
	soul_thunder.power = 40
	soul_thunder.description = "雷霆之怒，闪电般的速度。"
	soul_thunder.passive_type = PassiveType.MULT_CHANCE
	soul_thunder.passive_value = 0.25  # 额外25%倍率
	soul_thunder.passive_chance = 0.35  # 35%触发几率
	_register_soul(soul_thunder)

	# 史诗品质魂印
	var soul_shadow = SoulPrint.new("soul_shadow", "暗影追踪", Quality.EPIC, ShapeType.TRIANGLE)
	soul_shadow.power = 45
	soul_shadow.description = "来自暗影的追踪者，提升暴击。"
	soul_shadow.passive_type = PassiveType.CRIT_CHANCE
	soul_shadow.passive_value = 0.50  # 50%额外暴击伤害
	soul_shadow.passive_chance = 0.25  # 25%暴击率
	_register_soul(soul_shadow)
	
	# 传说品质魂印
	var soul_phoenix = SoulPrint.new("soul_phoenix", "不死鸟", Quality.LEGENDARY, ShapeType.SQUARE_2X2)
	soul_phoenix.power = 60
	soul_phoenix.description = "浴火重生的不死鸟之力。"
	soul_phoenix.passive_type = PassiveType.HEAL
	soul_phoenix.passive_value = 8.0  # 每回合回复8点HP
	_register_soul(soul_phoenix)

	var soul_dragon = SoulPrint.new("soul_dragon", "龙之魂", Quality.LEGENDARY, ShapeType.T_SHAPE)
	soul_dragon.power = 70
	soul_dragon.description = "远古巨龙的灵魂力量。"
	soul_dragon.passive_type = PassiveType.VAMPIRE
	soul_dragon.passive_value = 0.30  # 吸血30%造成的伤害
	_register_soul(soul_dragon)

	# 神话品质魂印
	var soul_god = SoulPrint.new("soul_god", "神之祝福", Quality.MYTHIC, ShapeType.L_SHAPE)
	soul_god.power = 100
	soul_god.description = "神明的祝福，至高无上的力量。"
	soul_god.passive_type = PassiveType.CRIT_CHANCE
	soul_god.passive_value = 1.0  # 100%额外暴击伤害（双倍伤害）
	soul_god.passive_chance = 0.40  # 40%暴击率
	_register_soul(soul_god)

# ========== 魂印使用次数管理 ==========

# 使用魂印（战斗中调用）
func use_soul_print(username: String, item_index: int) -> bool:
	if not _user_inventories.has(username):
		return false
	
	var inventory = _user_inventories[username]
	if item_index < 0 or item_index >= inventory["items"].size():
		return false
	
	var item = inventory["items"][item_index]
	if item.uses_remaining <= 0:
		return false
	
	item.uses_remaining -= 1
	print("使用魂印：", item.soul_print.name, " 剩余次数：", item.uses_remaining)
	
	# 如果使用次数为0，从背包中移除
	if item.uses_remaining <= 0:
		print("魂印使用次数耗尽，永久消失：", item.soul_print.name)
		inventory["items"].remove_at(item_index)
		_update_grid_occupation(username)
	
	_save_inventory(username)
	return true

# 重置所有魂印使用次数（通关或逃离时调用）
func reset_all_soul_uses(username: String):
	if not _user_inventories.has(username):
		return
	
	var inventory = _user_inventories[username]
	for item in inventory["items"]:
		item.uses_remaining = item.max_uses
	
	print("重置所有魂印使用次数")
	_save_inventory(username)

# 获取魂印剩余使用次数
func get_soul_uses_remaining(username: String, item_index: int) -> int:
	if not _user_inventories.has(username):
		return 0
	
	var inventory = _user_inventories[username]
	if item_index < 0 or item_index >= inventory["items"].size():
		return 0
	
	return inventory["items"][item_index].uses_remaining

func _register_soul(soul: SoulPrint):
	soul_database[soul.id] = soul

func get_soul_by_id(soul_id: String) -> SoulPrint:
	if soul_database.has(soul_id):
		return soul_database[soul_id]
	return null

# ========== 背包管理 ==========

func get_user_inventory(username: String) -> Array:
	if not _user_inventories.has(username):
		_user_inventories[username] = {
			"items": [],
			"grid": _create_empty_grid()
		}
	return _user_inventories[username]["items"]

func _create_empty_grid() -> Array:
	var grid = []
	for y in range(GRID_HEIGHT):
		var row = []
		for x in range(GRID_WIDTH):
			row.append(null)  # null 表示空格
		grid.append(row)
	return grid

# 检查是否可以放置魂印
func can_fit_soul(username: String, soul_id: String) -> bool:
	# 检查是否能放置该魂印（尝试所有位置和旋转）
	var soul = get_soul_by_id(soul_id)
	if not soul:
		return false
	
	for rotation in range(4):
		for y in range(GRID_HEIGHT):
			for x in range(GRID_WIDTH):
				if can_place_soul(username, soul, x, y, rotation):
					return true
	return false

func can_place_soul(username: String, soul: SoulPrint, x: int, y: int, rotation: int = 0) -> bool:
	var inventory = _user_inventories.get(username, {"items": [], "grid": _create_empty_grid()})
	var grid = inventory["grid"]
	
	var rotated_shape = soul.get_rotated_shape(rotation)
	
	# 检查每个格子
	for cell in rotated_shape:
		var check_x = x + cell[0]
		var check_y = y + cell[1]
		
		# 检查是否超出边界
		if check_x < 0 or check_x >= GRID_WIDTH or check_y < 0 or check_y >= GRID_HEIGHT:
			return false
		
		# 检查格子是否已被占用
		if grid[check_y][check_x] != null:
			return false
	
	return true

# 添加魂印到背包
func add_soul_print(username: String, soul_id: String, x: int = -1, y: int = -1, rotation: int = 0) -> bool:
	var soul = get_soul_by_id(soul_id)
	if soul == null:
		print("魂印不存在: ", soul_id)
		return false
	
	if not _user_inventories.has(username):
		_user_inventories[username] = {
			"items": [],
			"grid": _create_empty_grid()
		}
	
	var inventory = _user_inventories[username]
	
	# 如果没有指定位置，自动寻找空位
	if x == -1 or y == -1:
		var pos = _find_empty_position(username, soul, rotation)
		if pos == null:
			print("背包已满，无法放置魂印")
			return false
		x = pos[0]
		y = pos[1]
	
	# 检查是否可以放置
	if not can_place_soul(username, soul, x, y, rotation):
		print("该位置无法放置魂印")
		return false
	
	# 创建物品实例
	var item = InventoryItem.new(soul, x, y, rotation)
	inventory["items"].append(item)
	
	# 更新网格占用
	_update_grid_occupation(username)
	
	_save_inventory(username)
	return true

# 移除魂印
func remove_soul_print(username: String, item_index: int) -> bool:
	if not _user_inventories.has(username):
		return false
	
	var inventory = _user_inventories[username]
	if item_index < 0 or item_index >= inventory["items"].size():
		return false
	
	inventory["items"].remove_at(item_index)
	_update_grid_occupation(username)
	_save_inventory(username)
	return true

# 移动魂印
func move_soul_print(username: String, item_index: int, new_x: int, new_y: int, new_rotation: int = -1) -> bool:
	if not _user_inventories.has(username):
		return false
	
	var inventory = _user_inventories[username]
	if item_index < 0 or item_index >= inventory["items"].size():
		return false
	
	var item = inventory["items"][item_index]
	var old_x = item.grid_x
	var old_y = item.grid_y
	var old_rotation = item.rotation
	
	# 如果没有指定旋转，使用原来的
	if new_rotation == -1:
		new_rotation = old_rotation
	
	# 临时移除物品占用
	inventory["items"].remove_at(item_index)
	_update_grid_occupation(username)
	
	# 检查新位置是否可以放置
	if can_place_soul(username, item.soul_print, new_x, new_y, new_rotation):
		item.grid_x = new_x
		item.grid_y = new_y
		item.rotation = new_rotation
		inventory["items"].insert(item_index, item)
		_update_grid_occupation(username)
		_save_inventory(username)
		return true
	else:
		# 恢复原位置
		item.grid_x = old_x
		item.grid_y = old_y
		item.rotation = old_rotation
		inventory["items"].insert(item_index, item)
		_update_grid_occupation(username)
		return false

# 更新网格占用状态
func _update_grid_occupation(username: String):
	var inventory = _user_inventories[username]
	var grid = _create_empty_grid()
	
	for i in range(inventory["items"].size()):
		var item = inventory["items"][i]
		var cells = item.get_occupied_cells()
		for cell in cells:
			if cell[1] >= 0 and cell[1] < GRID_HEIGHT and cell[0] >= 0 and cell[0] < GRID_WIDTH:
				grid[cell[1]][cell[0]] = i  # 存储物品索引
	
	inventory["grid"] = grid

# 自动寻找空位
func _find_empty_position(username: String, soul: SoulPrint, rotation: int):
	for y in range(GRID_HEIGHT):
		for x in range(GRID_WIDTH):
			if can_place_soul(username, soul, x, y, rotation):
				return [x, y]
	return null

# ========== 数据持久化 ==========

func _save_inventory(username: String):
	if not _user_inventories.has(username):
		return
	
	var save_data = _load_all_inventories_raw()
	
	var items_data = []
	for item in _user_inventories[username]["items"]:
		items_data.append(item.to_dict())
	
	save_data[username] = items_data
	
	var file = FileAccess.open(INVENTORY_DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()

func _load_all_inventories():
	var data = _load_all_inventories_raw()
	for username in data.keys():
		var items = []
		for item_data in data[username]:
			# 使用新的from_dict方法来正确加载所有属性
			var item = InventoryItem.from_dict(item_data)
			items.append(item)
		
		_user_inventories[username] = {
			"items": items,
			"grid": _create_empty_grid()
		}
		_update_grid_occupation(username)

func _load_all_inventories_raw() -> Dictionary:
	if not FileAccess.file_exists(INVENTORY_DATA_PATH):
		return {}
	
	var file = FileAccess.open(INVENTORY_DATA_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		if json.parse(json_string) == OK:
			return json.get_data()
	
	return {}

# ========== 新手礼包 ==========

func give_starter_souls(username: String):
	# 给新玩家一些初始魂印
	add_soul_print(username, "soul_basic_1")  # 自动寻找位置
	add_soul_print(username, "soul_basic_2")
	add_soul_print(username, "soul_forest")
	print("新手魂印已发放给: ", username)
