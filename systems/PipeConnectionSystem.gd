extends Node

# 管道链接系统 - 负责检测和渲染管道之间的连接关系

## 管道连接数据类
class PipeConnection:
	var from_item_index: int  # 起始魂印索引
	var to_item_index: int    # 目标魂印索引
	var from_port: int        # 起始端口（PipePort枚举）
	var to_port: int          # 目标端口
	var from_pos: Vector2i    # 起始网格位置
	var to_pos: Vector2i      # 目标网格位置
	var strength: float       # 连接强度（用于动画）

	func _init(from_idx: int, to_idx: int, f_port: int, t_port: int, f_pos: Vector2i, t_pos: Vector2i):
		from_item_index = from_idx
		to_item_index = to_idx
		from_port = f_port
		to_port = t_port
		from_pos = f_pos
		to_pos = t_pos
		strength = 1.0

## 检测两个魂印之间的所有可能连接
func detect_connections_between_items(item1, item1_index: int, item2, item2_index: int, soul_system) -> Array:
	"""检测两个魂印项之间是否有端口对接"""
	var connections = []

	# 获取两个魂印的位置和旋转后的端口
	var pos1 = item1.grid_position
	var pos2 = item2.grid_position

	# 计算位置差
	var delta = pos2 - pos1

	# 只检测直接相邻的格子（横向或纵向）
	if abs(delta.x) + abs(delta.y) != 1:
		return connections

	# 获取旋转后的端口配置
	var ports1 = soul_system.rotate_pipe_ports(
		item1.soul_print.pipe_ports,
		item1.rotation_state
	)
	var ports2 = soul_system.rotate_pipe_ports(
		item2.soul_print.pipe_ports,
		item2.rotation_state
	)

	# 根据相对位置判断需要的端口
	var required_port1: int
	var required_port2: int

	if delta.x == 1 and delta.y == 0:  # item2 在 item1 右边
		required_port1 = soul_system.PipePort.RIGHT
		required_port2 = soul_system.PipePort.LEFT
	elif delta.x == -1 and delta.y == 0:  # item2 在 item1 左边
		required_port1 = soul_system.PipePort.LEFT
		required_port2 = soul_system.PipePort.RIGHT
	elif delta.x == 0 and delta.y == 1:  # item2 在 item1 下边
		required_port1 = soul_system.PipePort.DOWN
		required_port2 = soul_system.PipePort.UP
	elif delta.x == 0 and delta.y == -1:  # item2 在 item1 上边
		required_port1 = soul_system.PipePort.UP
		required_port2 = soul_system.PipePort.DOWN
	else:
		return connections

	# 检查两个魂印是否都有对应的端口
	if (ports1 & required_port1) and (ports2 & required_port2):
		var connection = PipeConnection.new(
			item1_index, item2_index,
			required_port1, required_port2,
			pos1, pos2
		)
		connections.append(connection)

	return connections

## 检测所有魂印之间的连接
func detect_all_connections(items: Array, soul_system) -> Array:
	"""检测背包中所有魂印的连接关系"""
	var all_connections = []

	# 遍历所有魂印对
	for i in range(items.size()):
		for j in range(i + 1, items.size()):
			var connections = detect_connections_between_items(
				items[i], i,
				items[j], j,
				soul_system
			)
			all_connections.append_array(connections)

	return all_connections

## 计算连接线的起点和终点位置（像素坐标）
func get_connection_line_positions(connection: PipeConnection, cell_size: int) -> Dictionary:
	"""返回连接线的起点和终点坐标（相对于网格容器）"""
	var result = {
		"start": Vector2.ZERO,
		"end": Vector2.ZERO
	}

	# 计算格子中心点
	var center1 = Vector2(
		connection.from_pos.x * cell_size + cell_size / 2.0,
		connection.from_pos.y * cell_size + cell_size / 2.0
	)
	var center2 = Vector2(
		connection.to_pos.x * cell_size + cell_size / 2.0,
		connection.to_pos.y * cell_size + cell_size / 2.0
	)

	# 根据端口方向计算连接点位置（从格子边缘向内偏移一点）
	var offset = cell_size / 2.0 - 5  # 距离边缘5像素

	result.start = center1 + _get_port_offset_vector(connection.from_port, offset)
	result.end = center2 + _get_port_offset_vector(connection.to_port, offset)

	return result

## 将端口转换为偏移向量
func _get_port_offset_vector(port: int, distance: float) -> Vector2:
	"""将端口枚举转换为偏移向量"""
	# 这里使用字符串匹配，因为不能直接访问 SoulPrintSystem 的枚举
	match port:
		1:  # UP
			return Vector2(0, -distance)
		2:  # DOWN
			return Vector2(0, distance)
		4:  # LEFT
			return Vector2(-distance, 0)
		8:  # RIGHT
			return Vector2(distance, 0)
	return Vector2.ZERO

## 绘制单个连接
func draw_connection(canvas: CanvasItem, connection: PipeConnection, cell_size: int, base_color: Color, animated_offset: float = 0.0):
	"""在 CanvasItem 上绘制一个管道连接"""
	var positions = get_connection_line_positions(connection, cell_size)
	var start = positions.start
	var end = positions.end

	# 计算连接强度影响的颜色和宽度
	var color = base_color * connection.strength
	color.a = 0.8 + 0.2 * connection.strength
	var width = 4.0 * connection.strength

	# 绘制发光效果（多层）
	for i in range(3):
		var glow_color = color
		glow_color.a *= 0.3 - i * 0.1
		var glow_width = width + (3 - i) * 2
		canvas.draw_line(start, end, glow_color, glow_width)

	# 绘制主连接线
	canvas.draw_line(start, end, color, width)

	# 绘制能量流动效果（可选）
	if animated_offset > 0.0:
		_draw_energy_flow(canvas, start, end, color, animated_offset)

## 绘制能量流动动画
func _draw_energy_flow(canvas: CanvasItem, start: Vector2, end: Vector2, color: Color, offset: float):
	"""在连接线上绘制流动的能量点"""
	var direction = (end - start).normalized()
	var distance = start.distance_to(end)

	# 绘制3个流动的能量点
	for i in range(3):
		var t = fmod(offset + i * 0.33, 1.0)
		var pos = start.lerp(end, t)

		# 能量点大小和透明度随位置变化
		var point_alpha = sin(t * PI) * 0.8  # 中间最亮
		var point_color = color
		point_color.a = point_alpha
		var point_size = 3.0 + sin(t * PI) * 2.0

		canvas.draw_circle(pos, point_size, point_color)

## 绘制所有连接
func draw_all_connections(canvas: CanvasItem, connections: Array, cell_size: int, time: float = 0.0):
	"""绘制所有管道连接"""
	# 获取基础颜色（能量流动的颜色）
	var base_color = Color(0.2, 0.8, 1.0)  # 蓝色能量

	# 计算动画偏移
	var animated_offset = fmod(time * 0.5, 1.0)  # 0.5 是流动速度

	for connection in connections:
		draw_connection(canvas, connection, cell_size, base_color, animated_offset)

## 检查特定位置的魂印是否有连接
func has_connection_at_position(connections: Array, pos: Vector2i) -> bool:
	"""检查指定网格位置是否有管道连接"""
	for connection in connections:
		if connection.from_pos == pos or connection.to_pos == pos:
			return true
	return false

## 获取指定魂印的所有连接
func get_connections_for_item(connections: Array, item_index: int) -> Array:
	"""获取指定魂印索引的所有连接"""
	var item_connections = []
	for connection in connections:
		if connection.from_item_index == item_index or connection.to_item_index == item_index:
			item_connections.append(connection)
	return item_connections

## 连接路径查找（BFS）
func find_connected_path(items: Array, connections: Array, start_index: int, end_index: int) -> Array:
	"""使用BFS查找从起始魂印到结束魂印的连接路径"""
	if start_index == end_index:
		return [start_index]

	var visited = {}
	var queue = [[start_index]]  # 队列存储路径
	visited[start_index] = true

	while queue.size() > 0:
		var path = queue.pop_front()
		var current = path[-1]

		# 获取当前节点的所有连接
		var neighbors = []
		for connection in connections:
			if connection.from_item_index == current:
				neighbors.append(connection.to_item_index)
			elif connection.to_item_index == current:
				neighbors.append(connection.from_item_index)

		# 遍历相邻节点
		for neighbor in neighbors:
			if neighbor == end_index:
				# 找到目标，返回路径
				path.append(neighbor)
				return path

			if not visited.has(neighbor):
				visited[neighbor] = true
				var new_path = path.duplicate()
				new_path.append(neighbor)
				queue.append(new_path)

	return []  # 没有找到路径

## 计算连接网络的连通性
func calculate_connectivity_score(items: Array, connections: Array) -> float:
	"""计算整个管道网络的连通性得分（0.0-1.0）"""
	if items.size() <= 1:
		return 0.0

	# 最大可能的连接数（每个魂印最多4个连接）
	var max_connections = items.size() * 4 / 2  # 除以2因为连接是双向的
	var current_connections = connections.size()

	return min(float(current_connections) / max_connections, 1.0)
