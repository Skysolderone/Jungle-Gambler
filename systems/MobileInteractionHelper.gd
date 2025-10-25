extends Node

# 移动端交互辅助器
# 提供触摸优化、手势识别等移动端特有功能

# 触摸手势枚举
enum TouchGesture {
	NONE,
	TAP,
	DOUBLE_TAP,
	LONG_PRESS,
	SWIPE_UP,
	SWIPE_DOWN,
	SWIPE_LEFT,
	SWIPE_RIGHT,
	PINCH_IN,
	PINCH_OUT
}

# 触摸状态
var touch_start_pos: Vector2
var touch_current_pos: Vector2
var touch_start_time: float
var is_touching: bool = false
var touch_count: int = 0
var last_tap_time: float = 0.0
var tap_count: int = 0

# 配置参数
var long_press_duration: float = 0.5  # 长按识别时间
var double_tap_max_interval: float = 0.3  # 双击最大间隔
var swipe_min_distance: float = 50.0  # 滑动最小距离
var tap_max_distance: float = 20.0   # 点击最大移动距离

# 信号
signal gesture_detected(gesture: TouchGesture, position: Vector2)
signal touch_started(position: Vector2)
signal touch_ended(position: Vector2)
signal touch_moved(position: Vector2, delta: Vector2)

func _ready():
	# 检测移动平台并启用相应功能
	_setup_mobile_features()

func _setup_mobile_features():
	var platform = OS.get_name()
	var is_mobile = platform in ["Android", "iOS"]
	
	if is_mobile:
		print("检测到移动平台：", platform, "，启用移动端优化")
		
		# 启用触摸输入处理
		set_process_input(true)
		
		# 设置屏幕不自动关闭（对于游戏很重要）
		DisplayServer.screen_set_keep_on(true)
		
		# 隐藏系统鼠标光标（在触摸设备上不需要）
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	else:
		print("桌面平台，启用触摸模拟")
		# 在桌面上也处理输入，用于测试
		set_process_input(true)

func _input(event):
	# 处理触摸和鼠标输入
	if event is InputEventScreenTouch:
		_handle_touch_event(event)
	elif event is InputEventScreenDrag:
		_handle_drag_event(event)
	elif event is InputEventMouseButton:
		# 在桌面上模拟触摸
		_handle_mouse_as_touch(event)
	elif event is InputEventMouseMotion and is_touching:
		# 鼠标拖拽模拟触摸拖拽
		_handle_mouse_motion_as_drag(event)

func _handle_touch_event(event: InputEventScreenTouch):
	if event.pressed:
		_start_touch(event.position)
	else:
		_end_touch(event.position)

func _handle_drag_event(event: InputEventScreenDrag):
	_move_touch(event.position)

func _handle_mouse_as_touch(event: InputEventMouseButton):
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_touch(event.position)
		else:
			_end_touch(event.position)

func _handle_mouse_motion_as_drag(event: InputEventMouseMotion):
	_move_touch(event.position)

func _start_touch(position: Vector2):
	touch_start_pos = position
	touch_current_pos = position
	touch_start_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60.0
	is_touching = true
	touch_count += 1
	
	# 发送触摸开始信号
	touch_started.emit(position)
	
	# 开始长按检测
	_start_long_press_detection()

func _end_touch(position: Vector2):
	if not is_touching:
		return
	
	var touch_duration = (Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60.0) - touch_start_time
	var touch_distance = touch_start_pos.distance_to(position)
	
	is_touching = false
	
	# 发送触摸结束信号
	touch_ended.emit(position)
	
	# 分析手势
	_analyze_gesture(position, touch_duration, touch_distance)

func _move_touch(position: Vector2):
	if not is_touching:
		return
	
	var delta = position - touch_current_pos
	touch_current_pos = position
	
	# 发送触摸移动信号
	touch_moved.emit(position, delta)

func _analyze_gesture(end_position: Vector2, duration: float, distance: float):
	var current_time = Time.get_time_dict_from_system()["second"] + Time.get_time_dict_from_system()["minute"] * 60.0
	
	if duration >= long_press_duration:
		# 长按
		gesture_detected.emit(TouchGesture.LONG_PRESS, touch_start_pos)
	elif distance <= tap_max_distance:
		# 点击或双击
		if current_time - last_tap_time <= double_tap_max_interval:
			tap_count += 1
			if tap_count >= 2:
				gesture_detected.emit(TouchGesture.DOUBLE_TAP, touch_start_pos)
				tap_count = 0
		else:
			tap_count = 1
			# 延迟检测是否为单击（等待可能的第二次点击）
			get_tree().create_timer(double_tap_max_interval).timeout.connect(_check_single_tap.bind(touch_start_pos))
		
		last_tap_time = current_time
	elif distance >= swipe_min_distance:
		# 滑动
		var swipe_direction = (end_position - touch_start_pos).normalized()
		var gesture = _get_swipe_gesture(swipe_direction)
		gesture_detected.emit(gesture, touch_start_pos)

func _check_single_tap(position: Vector2):
	if tap_count == 1:
		gesture_detected.emit(TouchGesture.TAP, position)
		tap_count = 0

func _get_swipe_gesture(direction: Vector2) -> TouchGesture:
	var angle = direction.angle()
	
	# 将角度转换为度数并归一化到0-360
	var degrees = rad_to_deg(angle)
	if degrees < 0:
		degrees += 360
	
	# 根据角度确定滑动方向
	if degrees >= 315 or degrees < 45:
		return TouchGesture.SWIPE_RIGHT
	elif degrees >= 45 and degrees < 135:
		return TouchGesture.SWIPE_DOWN
	elif degrees >= 135 and degrees < 225:
		return TouchGesture.SWIPE_LEFT
	else:
		return TouchGesture.SWIPE_UP

func _start_long_press_detection():
	# 使用计时器检测长按
	get_tree().create_timer(long_press_duration).timeout.connect(_check_long_press)

func _check_long_press():
	if is_touching:
		var distance = touch_start_pos.distance_to(touch_current_pos)
		if distance <= tap_max_distance:
			gesture_detected.emit(TouchGesture.LONG_PRESS, touch_start_pos)

# 工具函数：为按钮添加触摸反馈
func add_touch_feedback(button: Button):
	if not button:
		return
	
	# 连接按钮的按下和释放信号
	button.button_down.connect(_on_button_pressed.bind(button))
	button.button_up.connect(_on_button_released.bind(button))

func _on_button_pressed(button: Button):
	# 添加按下效果
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.1)
	
	# 触觉反馈（如果支持）
	if Input.get_connected_joypads().size() > 0:
		Input.start_joy_vibration(0, 0.1, 0.1, 0.1)

func _on_button_released(button: Button):
	# 恢复按钮大小
	var tween = create_tween()
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1)

# 工具函数：为控件添加滑动手势支持
func add_swipe_support(control: Control, callback: Callable):
	gesture_detected.connect(_on_gesture_for_control.bind(control, callback))

func _on_gesture_for_control(control: Control, callback: Callable, gesture: TouchGesture, position: Vector2):
	# 检查手势是否在控件范围内
	var local_pos = control.global_position
	var size = control.size
	var rect = Rect2(local_pos, size)
	
	if rect.has_point(position):
		if gesture in [TouchGesture.SWIPE_UP, TouchGesture.SWIPE_DOWN, TouchGesture.SWIPE_LEFT, TouchGesture.SWIPE_RIGHT]:
			callback.call(gesture, position)

# 获取手势名称（用于调试）
func get_gesture_name(gesture: TouchGesture) -> String:
	match gesture:
		TouchGesture.TAP:
			return "点击"
		TouchGesture.DOUBLE_TAP:
			return "双击"
		TouchGesture.LONG_PRESS:
			return "长按"
		TouchGesture.SWIPE_UP:
			return "上滑"
		TouchGesture.SWIPE_DOWN:
			return "下滑"
		TouchGesture.SWIPE_LEFT:
			return "左滑"
		TouchGesture.SWIPE_RIGHT:
			return "右滑"
		TouchGesture.PINCH_IN:
			return "缩放-缩小"
		TouchGesture.PINCH_OUT:
			return "缩放-放大"
		_:
			return "无手势"