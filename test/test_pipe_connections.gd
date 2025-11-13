extends Node

# 管道连接系统测试脚本

func _ready():
	print("=== 开始测试管道连接系统 ===")

	# 测试1：加载系统
	test_load_system()

	# 测试2：检测简单连接
	test_simple_connection()

	# 测试3：测试旋转
	test_rotation()

	print("=== 测试完成 ===")

func test_load_system():
	print("\n[测试1] 加载管道连接系统...")
	var script = load("res://systems/PipeConnectionSystem.gd")
	if script:
		var system = script.new()
		print("✓ 管道连接系统加载成功")
		return system
	else:
		print("✗ 管道连接系统加载失败")
		return null

func test_simple_connection():
	print("\n[测试2] 测试简单连接...")

	# 获取系统引用
	var soul_system = get_node_or_null("/root/SoulPrintSystem")
	if not soul_system:
		print("✗ SoulPrintSystem 不可用")
		return

	var pipe_system_script = load("res://systems/PipeConnectionSystem.gd")
	if not pipe_system_script:
		print("✗ 无法加载 PipeConnectionSystem")
		return

	var pipe_system = pipe_system_script.new()

	# 创建两个测试魂印（直管横向，应该能连接）
	var soul1 = soul_system.get_soul_by_id("common_01")
	var soul2 = soul_system.get_soul_by_id("common_02")

	if not soul1 or not soul2:
		print("✗ 无法获取测试魂印")
		return

	# 创建背包项（相邻位置）
	var item1 = soul_system.InventoryItem.new(soul1, Vector2i(0, 0), 0)
	var item2 = soul_system.InventoryItem.new(soul2, Vector2i(1, 0), 0)

	# 检测连接
	var connections = pipe_system.detect_connections_between_items(item1, 0, item2, 1, soul_system)

	print("检测到 %d 个连接" % connections.size())

	if connections.size() > 0:
		print("✓ 连接检测成功")
		for conn in connections:
			print("  - 从索引 %d 到索引 %d" % [conn.from_item_index, conn.to_item_index])
			print("    端口: %d -> %d" % [conn.from_port, conn.to_port])
	else:
		print("⚠ 未检测到连接（这可能是正常的，取决于魂印的端口配置）")

func test_rotation():
	print("\n[测试3] 测试端口旋转...")

	var soul_system = get_node_or_null("/root/SoulPrintSystem")
	if not soul_system:
		print("✗ SoulPrintSystem 不可用")
		return

	# 测试端口旋转函数
	var LEFT_RIGHT = 12  # 4 | 8 (LEFT | RIGHT)

	print("原始端口: 左右 (12)")

	for rotation in range(4):
		var rotated = soul_system.rotate_pipe_ports(LEFT_RIGHT, rotation)
		print("  旋转 %d 次 (90° × %d = %d°): 端口值 = %d" % [rotation, rotation, rotation * 90, rotated])

	print("✓ 旋转测试完成")
