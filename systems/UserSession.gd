extends Node

# 全局用户会话管理
var _current_username: String = ""
var _current_nickname: String = ""
var _is_logged_in: bool = false

# 用户数据存储路径
const USER_DATA_PATH = "user://users.json"

func login(username: String) -> bool:
	var users = _load_users()
	if users.has(username):
		_current_username = username
		_is_logged_in = true
		
		# 获取或生成昵称
		if users[username].has("nickname") and users[username]["nickname"] != "":
			_current_nickname = users[username]["nickname"]
		else:
			# 自动生成昵称
			_current_nickname = _generate_nickname()
			# 保存昵称到用户数据
			users[username]["nickname"] = _current_nickname
			_save_users(users)
		
		return true
	return false

func logout():
	_current_username = ""
	_current_nickname = ""
	_is_logged_in = false

func is_logged_in() -> bool:
	return _is_logged_in

func get_username() -> String:
	return _current_username

func get_nickname() -> String:
	return _current_nickname

func set_nickname(new_nickname: String) -> bool:
	if not _is_logged_in:
		return false
	
	var users = _load_users()
	if users.has(_current_username):
		users[_current_username]["nickname"] = new_nickname
		if _save_users(users):
			_current_nickname = new_nickname
			return true
	return false

# 生成随机昵称
func _generate_nickname() -> String:
	var adjectives = [
		"勇敢的", "聪明的", "幸运的", "神秘的", "传奇的",
		"强大的", "敏捷的", "无畏的", "狡猾的", "英勇的",
		"威猛的", "灵巧的", "睿智的", "果敢的", "冷静的"
	]
	
	var nouns = [
		"猎人", "冒险家", "战士", "探险家", "赌徒",
		"剑客", "游侠", "法师", "刺客", "骑士",
		"勇者", "英雄", "王者", "领主", "传说"
	]
	
	var random_adjective = adjectives[randi() % adjectives.size()]
	var random_noun = nouns[randi() % nouns.size()]
	var random_number = randi() % 1000
	
	return random_adjective + random_noun + str(random_number)

# 加载用户数据
func _load_users() -> Dictionary:
	if not FileAccess.file_exists(USER_DATA_PATH):
		return {}
	
	var file = FileAccess.open(USER_DATA_PATH, FileAccess.READ)
	if file:
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result == OK:
			return json.get_data()
	
	return {}

# 保存用户数据
func _save_users(users: Dictionary) -> bool:
	var file = FileAccess.open(USER_DATA_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(users, "\t"))
		file.close()
		return true
	return false

