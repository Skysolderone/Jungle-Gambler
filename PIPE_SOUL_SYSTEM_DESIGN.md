# 管道魂印系统设计文档

## 概述

将魂印系统改造为管道连接机制，战斗时需要连接管道才能激活魂印效果。

## 管道形状类型

### 基础管道（6种）

```
1. 直管-横 ━  [端口: 左, 右]
2. 直管-竖 ┃  [端口: 上, 下]
3. 弯管-左下 ┗ [端口: 上, 右]
4. 弯管-左上 ┏ [端口: 下, 右]
5. 弯管-右下 ┛ [端口: 上, 左]
6. 弯管-右上 ┓ [端口: 下, 左]
```

### 高级管道（3种）

```
7. T型-上开口 ┳ [端口: 左, 右, 下]
8. T型-下开口 ┻ [端口: 左, 右, 上]
9. T型-左开口 ┣ [端口: 上, 下, 右]
10. T型-右开口 ┫ [端口: 上, 下, 左]
11. 十字型 ╋ [端口: 上, 下, 左, 右]
```

### 特殊端点（2种）

```
12. 起点 ◉ [端口: 根据连接方向]
13. 终点 ◎ [端口: 根据连接方向]
```

## 战斗流程

### 原流程
```
准备阶段 → 选择魂印 → 战斗 → 战利品
```

### 新流程
```
准备阶段 → 选择魂印 → **管道连接** → 战斗 → 战利品
```

## 管道连接阶段

### 布局

```
┌─────────────────────────────────────┐
│  【管道连接 - 30秒倒计时】           │
├─────────────────────────────────────┤
│                                     │
│   ◉ [起点] ← 玩家能量源              │
│   ┃                                 │
│   ┗━━[雷霆] (20力量)               │
│       ┃                             │
│       ┃                             │
│   [火焰]━━┛ (15力量)               │
│       ┃                             │
│       ◎ [终点]                      │
│                                     │
│   未连接: [冰霜] [暗影]             │
│                                     │
├─────────────────────────────────────┤
│  连通力量: 35 / 100                 │
│  [旋转选中] [开始战斗]              │
└─────────────────────────────────────┘
```

### 规则

1. **起点和终点**
   - 起点固定在顶部，终点固定在底部
   - 必须从起点连接到终点

2. **魂印作为管道**
   - 每个魂印有固定的管道形状
   - 点击魂印可以旋转90°（顺时针）
   - 拖拽魂印可以移动位置（5×5网格）

3. **连通性检测**
   - 实时检测起点到终点的路径
   - 只有连通的魂印才计入总力量
   - 显示当前连通路径（高亮）

4. **战斗触发**
   - 可以不连通全部魂印，直接开始
   - 未连通的魂印不计入战斗力量
   - 鼓励玩家尽量连通更多魂印

## 数据结构

### 管道端口

```gdscript
enum PipePort {
    NONE   = 0,
    UP     = 1,  # 0001
    DOWN   = 2,  # 0010
    LEFT   = 4,  # 0100
    RIGHT  = 8   # 1000
}
```

### 管道形状数据

```gdscript
var pipe_shapes = {
    "straight_h": {"ports": LEFT | RIGHT, "symbol": "━"},
    "straight_v": {"ports": UP | DOWN, "symbol": "┃"},
    "bend_lu": {"ports": LEFT | UP, "symbol": "┛"},
    "bend_ld": {"ports": LEFT | DOWN, "symbol": "┓"},
    "bend_ru": {"ports": RIGHT | UP, "symbol": "┗"},
    "bend_rd": {"ports": RIGHT | DOWN, "symbol": "┏"},
    "t_up": {"ports": LEFT | RIGHT | UP, "symbol": "┻"},
    "t_down": {"ports": LEFT | RIGHT | DOWN, "symbol": "┳"},
    "t_left": {"ports": UP | DOWN | LEFT, "symbol": "┫"},
    "t_right": {"ports": UP | DOWN | RIGHT, "symbol": "┣"},
    "cross": {"ports": UP | DOWN | LEFT | RIGHT, "symbol": "╋"}
}
```

### 魂印管道属性

```gdscript
class SoulPrint:
    # ... 原有属性 ...
    
    # 新增管道属性
    var pipe_shape: String  # 管道形状ID
    var pipe_ports: int     # 端口位掩码
    var rotation: int       # 旋转角度 0/1/2/3 对应 0°/90°/180°/270°
    var grid_pos: Vector2i  # 在5×5网格中的位置
```

## 连通性算法

### 深度优先搜索（DFS）

```gdscript
func check_connectivity(start: Vector2i, end: Vector2i) -> Array:
    var visited = {}
    var path = []
    
    func dfs(pos: Vector2i, from_direction: int) -> bool:
        if pos == end:
            return true
            
        if visited.has(pos):
            return false
            
        var soul = get_soul_at(pos)
        if not soul:
            return false
            
        visited[pos] = true
        path.append(soul)
        
        # 检查当前魂印的端口
        var ports = get_rotated_ports(soul)
        
        # 尝试向四个方向连接
        for direction in [UP, DOWN, LEFT, RIGHT]:
            if ports & direction and opposite_direction(direction) == from_direction:
                var next_pos = pos + direction_vector(direction)
                var next_soul = get_soul_at(next_pos)
                
                if next_soul and has_port(next_soul, opposite_direction(direction)):
                    if dfs(next_pos, direction):
                        return true
        
        path.pop_back()
        return false
    
    if dfs(start, NONE):
        return path
    return []
```

## UI设计

### 管道网格

- 5×5 网格布局
- 起点固定在 (2, 0)
- 终点固定在 (2, 4)
- 中间3行用于放置魂印管道

### 交互操作

1. **点击魂印** - 旋转90°
2. **拖拽魂印** - 移动到其他格子
3. **路径高亮** - 连通的管道显示发光效果
4. **实时反馈** - 显示当前连通力量

## 视觉效果

### 管道流动动画

```
━ → ━ → ━  (能量流动)
    ↓
    ┗ → ━  (顺时针流动)
```

### 颜色编码

- **未连通管道**: 灰色
- **连通管道**: 根据魂印品质显示颜色
- **能量流动**: 白色/金色粒子效果

## 平衡性调整

### 魂印分配

- **普通/非凡**: 直管、弯管
- **稀有/史诗**: T型管
- **传说/神话**: 十字管

### 难度设计

- **简单**: 3个魂印，容易连接
- **普通**: 5个魂印，需要规划
- **困难**: 7个魂印，空间受限

## 实现优先级

### 第一阶段（核心功能）
- [ ] 定义管道形状和端口系统
- [ ] 实现管道网格布局
- [ ] 实现旋转和移动操作
- [ ] 实现连通性检测算法

### 第二阶段（视觉优化）
- [ ] 添加管道流动动画
- [ ] 添加路径高亮效果
- [ ] 添加粒子效果

### 第三阶段（体验优化）
- [ ] 添加自动连接提示
- [ ] 添加最优解提示
- [ ] 添加连击奖励机制

