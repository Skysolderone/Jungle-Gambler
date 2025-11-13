# 管道魂印关节链接系统实现文档

## 概述

为 Jungle Gambler 游戏的背包系统实现了管道魂印的关节链接效果。当相邻的管道魂印的开口能够对齐时，会在它们之间创建视觉上的链接效果，包括：
- 发光连接线
- 流动的能量动画
- 实时连接状态检测

## 实现的功能

### 1. 管道连接检测系统 (`systems/PipeConnectionSystem.gd`)

**核心类和方法：**

#### PipeConnection 类
```gdscript
class PipeConnection:
    var from_item_index: int  # 起始魂印索引
    var to_item_index: int    # 目标魂印索引
    var from_port: int        # 起始端口（UP/DOWN/LEFT/RIGHT）
    var to_port: int          # 目标端口
    var from_pos: Vector2i    # 起始网格位置
    var to_pos: Vector2i      # 目标网格位置
    var strength: float       # 连接强度（用于动画）
```

#### 主要功能函数

1. **detect_connections_between_items()**
   - 检测两个魂印之间是否有端口对接
   - 只检测直接相邻的格子（上下左右）
   - 考虑魂印的旋转状态

2. **detect_all_connections()**
   - 检测背包中所有魂印的连接关系
   - 返回所有有效连接的数组

3. **draw_connection()**
   - 绘制单个管道连接
   - 包含多层发光效果
   - 支持能量流动动画

4. **draw_all_connections()**
   - 绘制所有管道连接
   - 支持动画时间参数

5. **find_connected_path()**
   - 使用BFS算法查找两个魂印之间的连接路径
   - 可用于后续的路径寻找功能

6. **calculate_connectivity_score()**
   - 计算整个管道网络的连通性得分（0.0-1.0）
   - 可用于评估背包配置的优化程度

### 2. 背包场景集成 (`scripts/SoulInventoryV2.gd`)

**新增变量：**
```gdscript
var pipe_connection_system = null      # 管道连接系统实例
var pipe_connections: Array = []       # 当前检测到的所有连接
var connection_animation_time: float   # 动画时间累积
```

**新增/修改的方法：**

1. **_initialize_pipe_connection_system()**
   - 在 `_ready()` 时初始化管道连接系统
   - 加载 PipeConnectionSystem 脚本并创建实例

2. **_process(delta)**
   - 每帧更新动画时间
   - 当有连接时触发网格重绘

3. **_update_pipe_connections()**
   - 在背包内容变化时重新检测连接
   - 在 `_refresh_inventory()` 中调用

4. **_draw_pipe_connections()**
   - 在 `_draw_grid()` 中调用
   - 在魂印上层绘制连接效果

**触发连接更新的操作：**
- 添加新魂印
- 移动魂印
- 旋转魂印
- 删除魂印

## 视觉效果详解

### 连接线渲染

1. **多层发光效果**
   - 3层渐变发光，外层最透明
   - 创造柔和的光晕效果

2. **主连接线**
   - 基础颜色：蓝色能量 `Color(0.2, 0.8, 1.0)`
   - 宽度：4像素（根据连接强度调整）

3. **能量流动动画**
   - 3个流动的能量点
   - 使用正弦函数控制大小和透明度
   - 流动速度：0.5单位/秒

### 连接点位置计算

- 连接线从格子中心向边缘偏移
- 偏移距离：格子大小的一半 - 5像素
- 根据端口方向计算准确的连接点

## 端口系统说明

### 端口枚举（位掩码）
```gdscript
enum PipePort {
    NONE   = 0,   # 0000
    UP     = 1,   # 0001
    DOWN   = 2,   # 0010
    LEFT   = 4,   # 0100
    RIGHT  = 8    # 1000
}
```

### 管道形状和端口配置

| 形状类型 | 端口配置 | 示例 |
|---------|---------|------|
| 直管-横 | LEFT \| RIGHT | ━ |
| 直管-竖 | UP \| DOWN | ┃ |
| 弯管-左上 | LEFT \| UP | ┛ |
| 弯管-左下 | LEFT \| DOWN | ┓ |
| 弯管-右上 | RIGHT \| UP | ┗ |
| 弯管-右下 | RIGHT \| DOWN | ┏ |
| T型-上 | LEFT \| RIGHT \| UP | ┻ |
| T型-下 | LEFT \| RIGHT \| DOWN | ┳ |
| T型-左 | UP \| DOWN \| LEFT | ┫ |
| T型-右 | UP \| DOWN \| RIGHT | ┣ |
| 十字型 | UP \| DOWN \| LEFT \| RIGHT | ╋ |

### 旋转处理

- 旋转值：0/1/2/3 对应 0°/90°/180°/270°
- 使用 `rotate_pipe_ports()` 计算旋转后的端口
- 顺时针旋转：UP→RIGHT→DOWN→LEFT→UP

## 连接检测逻辑

### 判断条件

1. **位置相邻**
   - 仅检测横向或纵向相邻（不包括斜向）
   - 曼哈顿距离 = 1

2. **端口匹配**
   ```gdscript
   # 例如：item1 在左，item2 在右
   # item1 需要有 RIGHT 端口
   # item2 需要有 LEFT 端口
   if (ports1 & PipePort.RIGHT) and (ports2 & PipePort.LEFT):
       # 可以连接
   ```

3. **考虑旋转**
   - 先根据当前旋转角度计算实际端口配置
   - 再进行端口匹配判断

## 测试

### 测试脚本 (`test_pipe_connections.gd`)

提供了三个测试用例：
1. **加载系统** - 验证系统能正确加载
2. **简单连接** - 测试相邻魂印的连接检测
3. **端口旋转** - 验证端口旋转逻辑

### 运行测试

1. 将 `test_pipe_connections.gd` 添加到场景树
2. 运行场景
3. 查看控制台输出

## 使用示例

### 在其他场景中使用

```gdscript
# 1. 初始化系统
var pipe_system_script = load("res://systems/PipeConnectionSystem.gd")
var pipe_system = pipe_system_script.new()

# 2. 检测连接
var soul_system = get_node("/root/SoulPrintSystem")
var items = soul_system.get_user_inventory(username)
var connections = pipe_system.detect_all_connections(items, soul_system)

# 3. 绘制连接（在 _draw() 或 draw 信号中）
func _draw():
    pipe_system.draw_all_connections(self, connections, 50, time)
```

### 查找连接路径

```gdscript
# 查找从魂印0到魂印5的连接路径
var path = pipe_system.find_connected_path(items, connections, 0, 5)
if path.size() > 0:
    print("找到路径：", path)
else:
    print("两个魂印没有连通")
```

### 计算连通性

```gdscript
var score = pipe_system.calculate_connectivity_score(items, connections)
print("背包连通性得分：%.2f" % score)
```

## 性能优化建议

1. **连接检测**
   - 只在背包变化时重新检测
   - 避免每帧检测

2. **绘制优化**
   - 使用 `queue_redraw()` 而非 `update()`
   - 只在有连接时启用动画

3. **缓存优化**
   - 缓存端口旋转结果
   - 缓存连接线位置计算

## 未来扩展可能

1. **连接强度计算**
   - 根据魂印品质调整连接强度
   - 影响视觉效果（颜色、亮度）

2. **路径高亮**
   - 选中魂印时高亮显示其连接路径
   - 显示连通的魂印网络

3. **连接奖励**
   - 根据连通性给予属性加成
   - 鼓励玩家优化背包布局

4. **特殊连接效果**
   - 不同品质的魂印连接显示不同颜色
   - 特殊组合触发特效

5. **声音效果**
   - 连接成功时播放音效
   - 形成大型网络时播放特殊音效

## 相关文件

- `systems/PipeConnectionSystem.gd` - 管道连接系统核心
- `scripts/SoulInventoryV2.gd` - 背包场景脚本（已集成）
- `scenes/SoulInventoryV2.tscn` - 背包场景
- `systems/SoulPrintSystem.gd` - 魂印系统（提供端口和旋转功能）
- `test_pipe_connections.gd` - 测试脚本

## 调试信息

系统会在以下情况输出日志：
- 管道连接系统初始化
- 每次检测到连接（数量）
- 魂印旋转（角度和次数）

查看日志：
```
管道连接系统已初始化
检测到 3 个管道连接
魂印已旋转到 90° (1/4)
```

## 已知限制

1. **斜向连接**
   - 当前不支持斜向（45度）连接
   - 只支持横向和纵向

2. **多格魂印**
   - 当前每个魂印只占1格
   - 如果将来支持多格魂印，需要调整连接检测逻辑

3. **性能**
   - 大量魂印时（80+）可能影响性能
   - 建议优化绘制逻辑或使用对象池

## 版本历史

- **v1.0** (2025-11-13)
  - 初始实现
  - 基础连接检测
  - 视觉效果和动画
  - 集成到背包场景
