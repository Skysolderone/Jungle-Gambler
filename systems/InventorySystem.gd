extends Node

# 背包系统管理
const INVENTORY_DATA_PATH = "user://inventory_data.json"
const MAX_INVENTORY_SIZE = 50  # 默认背包大小

# 物品类型枚举
enum ItemType {
	CONSUMABLE,  # 消耗品
	EQUIPMENT,   # 装备
	MATERIAL,    # 材料
	SPECIAL      # 特殊物品
}

# 物品稀有度
enum ItemRarity {
	COMMON,      # 普通
	UNCOMMON,    # 非凡
	RARE,        # 稀有
	EPIC,        # 史诗
	LEGENDARY    # 传说
}

# 物品数据结构
class Item:
	var id: String
	var name: String
	var description: String
	var type: ItemType
	var rarity: ItemRarity
	var icon: String
	var stackable: bool
	var max_stack: int
	var value: int  # 物品价值
	
	func _init(item_id: String, item_name: String, item_desc: String = "", 
			   item_type: ItemType = ItemType.CONSUMABLE, 
			   item_rarity: ItemRarity = ItemRarity.COMMON,
			   is_stackable: bool = true, stack_size: int = 99, item_value: int = 10):
		id = item_id
		name = item_name
		description = item_desc
		type = item_type
		rarity = item_rarity
		icon = ""
		stackable = is_stackable
		max_stack = stack_size
		value = item_value
	
	func to_dict() -> Dictionary:
		return {
			"id": id,
			"name": name,
			"description": description,
			"type": type,
			"rarity": rarity,
			"icon": icon,
			"stackable": stackable,
			"max_stack": max_stack,
			"value": value
		}
	
	static func from_dict(data: Dictionary) -> Item:
		var item = Item.new(
			data.get("id", ""),
			data.get("name", ""),
			data.get("description", ""),
			data.get("type", ItemType.CONSUMABLE),
			data.get("rarity", ItemRarity.COMMON),
			data.get("stackable", true),
			data.get("max_stack", 99),
			data.get("value", 10)
		)
		item.icon = data.get("icon", "")
		return item

# 背包槽位数据
class InventorySlot:
	var item: Item
	var quantity: int
	
	func _init(slot_item: Item = null, slot_quantity: int = 0):
		item = slot_item
		quantity = slot_quantity
	
	func is_empty() -> bool:
		return item == null or quantity <= 0
	
	func can_add(amount: int) -> bool:
		if item == null:
			return true
		if not item.stackable:
			return false
		return quantity + amount <= item.max_stack
	
	func add(amount: int) -> int:
		if item == null:
			return 0
		var space = item.max_stack - quantity
		var added = min(amount, space)
		quantity += added
		return added
	
	func remove(amount: int) -> int:
		var removed = min(amount, quantity)
		quantity -= removed
		if quantity <= 0:
			item = null
			quantity = 0
		return removed
	
	func to_dict() -> Dictionary:
		if is_empty():
			return {}
		return {
			"item": item.to_dict(),
			"quantity": quantity
		}

# 用户背包数据
var _user_inventories: Dictionary = {}  # username -> inventory_data

func _ready():
	_load_all_inventories()
	_initialize_item_database()

# ========== 物品数据库 ==========
var item_database: Dictionary = {}

func _initialize_item_database():
	# 初始化一些基础物品
	_register_item(Item.new("health_potion", "生命药水", "恢复50点生命值", 
		ItemType.CONSUMABLE, ItemRarity.COMMON, true, 99, 10))
	_register_item(Item.new("mana_potion", "魔法药水", "恢复30点魔法值", 
		ItemType.CONSUMABLE, ItemRarity.COMMON, true, 99, 10))
	_register_item(Item.new("gold_coin", "金币", "闪闪发光的金币", 
		ItemType.MATERIAL, ItemRarity.COMMON, true, 999, 1))
	_register_item(Item.new("iron_sword", "铁剑", "普通的铁制长剑，攻击+10", 
		ItemType.EQUIPMENT, ItemRarity.COMMON, false, 1, 50))
	_register_item(Item.new("steel_armor", "钢铁护甲", "坚固的钢制护甲，防御+15", 
		ItemType.EQUIPMENT, ItemRarity.UNCOMMON, false, 1, 100))
	_register_item(Item.new("lucky_charm", "幸运符", "提升运气的神秘物品", 
		ItemType.SPECIAL, ItemRarity.RARE, true, 5, 200))
	_register_item(Item.new("dragon_scale", "龙鳞", "来自古龙的鳞片，稀有材料", 
		ItemType.MATERIAL, ItemRarity.EPIC, true, 10, 500))
	_register_item(Item.new("legendary_gem", "传说宝石", "蕴含强大力量的宝石", 
		ItemType.SPECIAL, ItemRarity.LEGENDARY, true, 1, 10000))

func _register_item(item: Item):
	item_database[item.id] = item

func get_item_by_id(item_id: String) -> Item:
	if item_database.has(item_id):
		return item_database[item_id]
	return null

# ========== 背包管理 ==========

func get_inventory_size(_username: String) -> int:
	# 根据用户等级或VIP状态返回不同的背包大小
	# 这里可以扩展为从用户数据读取
	return MAX_INVENTORY_SIZE

func get_user_inventory(username: String) -> Array:
	if not _user_inventories.has(username):
		_user_inventories[username] = _create_empty_inventory()
	return _user_inventories[username]

func _create_empty_inventory() -> Array:
	var inventory: Array = []
	for i in range(MAX_INVENTORY_SIZE):
		inventory.append(InventorySlot.new())
	return inventory

# 添加物品到背包
func add_item(username: String, item_id: String, quantity: int) -> bool:
	var item = get_item_by_id(item_id)
	if item == null:
		print("物品不存在: ", item_id)
		return false
	
	var inventory = get_user_inventory(username)
	var remaining = quantity
	
	# 如果物品可堆叠，先尝试加到现有堆叠
	if item.stackable:
		for slot in inventory:
			if not slot.is_empty() and slot.item.id == item_id:
				var added = slot.add(remaining)
				remaining -= added
				if remaining <= 0:
					_save_inventory(username)
					return true
	
	# 找空槽位
	while remaining > 0:
		var empty_slot = _find_empty_slot(inventory)
		if empty_slot == null:
			print("背包已满")
			return false
		
		empty_slot.item = item
		var add_amount = min(remaining, item.max_stack if item.stackable else 1)
		empty_slot.quantity = add_amount
		remaining -= add_amount
	
	_save_inventory(username)
	return true

# 移除物品
func remove_item(username: String, item_id: String, quantity: int) -> bool:
	var inventory = get_user_inventory(username)
	var remaining = quantity
	
	for slot in inventory:
		if not slot.is_empty() and slot.item.id == item_id:
			var removed = slot.remove(remaining)
			remaining -= removed
			if remaining <= 0:
				_save_inventory(username)
				return true
	
	if remaining > 0:
		print("物品数量不足")
		return false
	
	_save_inventory(username)
	return true

# 获取物品数量
func get_item_count(username: String, item_id: String) -> int:
	var inventory = get_user_inventory(username)
	var count = 0
	
	for slot in inventory:
		if not slot.is_empty() and slot.item.id == item_id:
			count += slot.quantity
	
	return count

# 使用物品
func use_item(username: String, slot_index: int) -> bool:
	var inventory = get_user_inventory(username)
	if slot_index < 0 or slot_index >= inventory.size():
		return false
	
	var slot = inventory[slot_index]
	if slot.is_empty():
		return false
	
	# 根据物品类型执行不同的使用逻辑
	match slot.item.type:
		ItemType.CONSUMABLE:
			print("使用消耗品: ", slot.item.name)
			slot.remove(1)
			_save_inventory(username)
			return true
		ItemType.EQUIPMENT:
			print("装备物品: ", slot.item.name)
			# 这里可以添加装备逻辑
			return true
		_:
			print("该物品无法使用")
			return false

# 丢弃物品
func discard_item(username: String, slot_index: int, quantity: int) -> bool:
	var inventory = get_user_inventory(username)
	if slot_index < 0 or slot_index >= inventory.size():
		return false
	
	var slot = inventory[slot_index]
	if slot.is_empty():
		return false
	
	slot.remove(quantity)
	_save_inventory(username)
	return true

# 整理背包
func sort_inventory(username: String):
	var inventory = get_user_inventory(username)
	var items_data: Array = []
	
	# 收集所有物品
	for slot in inventory:
		if not slot.is_empty():
			items_data.append({
				"item": slot.item,
				"quantity": slot.quantity
			})
	
	# 清空背包
	for slot in inventory:
		slot.item = null
		slot.quantity = 0
	
	# 按稀有度和名称排序
	items_data.sort_custom(func(a, b): 
		if a["item"].rarity != b["item"].rarity:
			return a["item"].rarity > b["item"].rarity
		return a["item"].name < b["item"].name
	)
	
	# 重新放入背包
	var slot_index = 0
	for data in items_data:
		inventory[slot_index].item = data["item"]
		inventory[slot_index].quantity = data["quantity"]
		slot_index += 1
	
	_save_inventory(username)

func _find_empty_slot(inventory: Array) -> InventorySlot:
	for slot in inventory:
		if slot.is_empty():
			return slot
	return null

# ========== 数据持久化 ==========

func _save_inventory(username: String):
	if not _user_inventories.has(username):
		return
	
	var save_data = _load_all_inventories_raw()
	save_data[username] = _inventory_to_dict(_user_inventories[username])
	
	var file = FileAccess.open(INVENTORY_DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))
		file.close()

func _load_all_inventories():
	var data = _load_all_inventories_raw()
	for username in data.keys():
		_user_inventories[username] = _dict_to_inventory(data[username])

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

func _inventory_to_dict(inventory: Array) -> Array:
	var result: Array = []
	for slot in inventory:
		result.append(slot.to_dict())
	return result

func _dict_to_inventory(data: Array) -> Array:
	var inventory: Array = []
	for i in range(MAX_INVENTORY_SIZE):
		if i < data.size() and not data[i].is_empty():
			var slot_data = data[i]
			var item = Item.from_dict(slot_data["item"])
			var slot = InventorySlot.new(item, slot_data["quantity"])
			inventory.append(slot)
		else:
			inventory.append(InventorySlot.new())
	return inventory

# ========== 新手礼包 ==========

func give_starter_pack(username: String):
	# 给新玩家一些初始物品
	add_item(username, "health_potion", 5)
	add_item(username, "mana_potion", 3)
	add_item(username, "gold_coin", 100)
	add_item(username, "iron_sword", 1)
	print("新手礼包已发放给: ", username)
