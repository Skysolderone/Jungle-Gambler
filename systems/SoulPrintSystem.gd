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
	var special_effect: String  # 特殊效果
	
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
			"special_effect": special_effect
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
		return soul

# 背包中的魂印实例
class InventoryItem:
	var soul_print: SoulPrint
	var grid_x: int  # 在背包网格中的起始X位置
	var grid_y: int  # 在背包网格中的起始Y位置
	var rotation: int  # 旋转状态 0-3
	
	func _init(soul: SoulPrint, x: int, y: int, rot: int = 0):
		soul_print = soul
		grid_x = x
		grid_y = y
		rotation = rot
	
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
			"rotation": rotation
		}

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
	_register_soul(SoulPrint.new("soul_basic_1", "初始魂印", Quality.COMMON, ShapeType.SQUARE_1X1))
	_register_soul(SoulPrint.new("soul_basic_2", "双生魂印", Quality.COMMON, ShapeType.RECT_1X2))
	
	# 非凡品质魂印
	_register_soul(SoulPrint.new("soul_forest", "森林之魂", Quality.UNCOMMON, ShapeType.SQUARE_2X2))
	_register_soul(SoulPrint.new("soul_wind", "疾风魂印", Quality.UNCOMMON, ShapeType.RECT_1X3))
	
	# 稀有品质魂印
	_register_soul(SoulPrint.new("soul_thunder", "雷霆魂印", Quality.RARE, ShapeType.L_SHAPE))
	_register_soul(SoulPrint.new("soul_flame", "烈焰魂印", Quality.RARE, ShapeType.T_SHAPE))
	
	# 史诗品质魂印
	_register_soul(SoulPrint.new("soul_dragon", "龙魂印记", Quality.EPIC, ShapeType.SQUARE_2X2))
	_register_soul(SoulPrint.new("soul_shadow", "暗影魂印", Quality.EPIC, ShapeType.L_SHAPE))
	
	# 传说品质魂印
	_register_soul(SoulPrint.new("soul_phoenix", "凤凰魂印", Quality.LEGENDARY, ShapeType.T_SHAPE))
	_register_soul(SoulPrint.new("soul_celestial", "天命魂印", Quality.LEGENDARY, ShapeType.SQUARE_2X2))
	
	# 神话品质魂印
	_register_soul(SoulPrint.new("soul_chaos", "混沌之魂", Quality.MYTHIC, ShapeType.SQUARE_2X2))
	_register_soul(SoulPrint.new("soul_eternity", "永恒魂印", Quality.MYTHIC, ShapeType.T_SHAPE))
	_register_soul(SoulPrint.new("soul_phoenix", "凤凰魂印", Quality.EPIC, ShapeType.RECT_3X1))
	
	# 传说品质魂印
	_register_soul(SoulPrint.new("soul_titan", "泰坦魂印", Quality.LEGENDARY, ShapeType.T_SHAPE))
	
	# 神话品质魂印
	_register_soul(SoulPrint.new("soul_god", "神祇魂印", Quality.MYTHIC, ShapeType.SQUARE_2X2))

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
			var soul = SoulPrint.from_dict(item_data["soul_print"])
			var item = InventoryItem.new(
				soul,
				item_data["grid_x"],
				item_data["grid_y"],
				item_data["rotation"]
			)
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

