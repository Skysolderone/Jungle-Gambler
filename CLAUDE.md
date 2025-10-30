# CLAUDE.md

没有要求不需要生成文档，使用 godot-expert 搭配 mcp 工具进行代码编写跟调试
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

**Jungle Gambler（丛林赌徒）** - 基于 Godot 4.5 开发的 2D Roguelike 背包管理游戏，灵感源自暗黑破坏神 3 的背包系统。

- **引擎**: Godot 4.5
- **语言**: GDScript
- **入口场景**: `res://scenes/MainMenu.tscn`
- **数据存储**: JSON 文件（user://目录）

## 开发规范

### 核心原则

1. **使用中文**进行所有交流、注释和用户界面文本
2. **立即实现**功能，不只提供建议
3. **不创建**配置文件（project.godot）、测试文件、README（除非明确要求）
4. **不使用 emoji**（除非明确要求）

### GDScript 代码风格

- 变量: `snake_case`
- 常量: `UPPER_SNAKE_CASE`
- 函数: `snake_case`，私有函数加下划线前缀 `_private_func()`
- 类: `PascalCase`
- 使用 `@onready` 延迟加载节点引用
- 信号回调命名: `_on_[节点名]_[信号名]`

## 架构设计

### 全局单例系统（Autoload）

项目核心依赖 4 个全局单例，通过 `get_node("/root/SingletonName")` 访问：

#### 1. UserSession (`systems/UserSession.gd`)

- **职责**: 用户会话和身份管理
- **关键 API**:
  - `login(username: String) -> bool` - 登录用户
  - `get_username() -> String` - 获取当前用户名
  - `get_nickname() -> String` - 获取昵称（自动生成）
  - `set_nickname(new_nickname: String) -> bool` - 更新昵称
- **数据文件**: `user://users.json`
- **特性**: 自动生成随机中文昵称（形容词+名词+数字）

#### 2. SoulPrintSystem (`systems/SoulPrintSystem.gd`)

- **职责**: 魂印和背包管理
- **核心概念**:
  - **魂印品质**: 0-5（普通/非凡/稀有/史诗/传说/神话）
  - **形状系统**: 9 种形状（1×1 方形、2×2 方形、矩形、L 形、T 形、三角形等）
  - **背包网格**: 8 高 ×10 宽，类似暗黑破坏神 3 的背包拼图系统
  - **旋转机制**: 魂印可以 4 个方向旋转放置
- **关键 API**:
  - `get_user_inventory(username) -> Array` - 获取用户背包物品列表
  - `add_soul_print(username, soul_id, x, y, rotation) -> bool` - 添加魂印到背包
  - `can_fit_soul(username, soul_id) -> bool` - 检查是否有空间放置
  - `move_soul_print(username, item_index, new_x, new_y, new_rotation) -> bool` - 移动魂印
  - `get_soul_by_id(soul_id) -> SoulPrint` - 从数据库获取魂印定义
- **数据结构**:
  - `SoulPrint`: 魂印定义类（id, name, quality, shape_type, power, shape_data）
  - `InventoryItem`: 背包实例类（soul_print, grid_x, grid_y, rotation）
- **数据文件**: `user://soul_inventory.json`

#### 3. ThemeManager (`systems/ThemeManager.gd`)

- **职责**: 明暗主题切换
- **主题模式**: `DARK` / `LIGHT`
- **关键 API**:
  - `get_color(color_name: String) -> Color` - 获取主题颜色
  - `set_theme(new_theme: ThemeMode)` - 切换主题
  - `toggle_theme()` - 切换明暗模式
- **预定义颜色**: background, panel, button_normal, accent, text, border, slot_bg
- **数据文件**: `user://settings.json`

#### 4. InventorySystem (`systems/InventorySystem.gd`)

- **状态**: 已弃用，被 SoulPrintSystem 替代

### 场景流程架构

游戏场景按以下流程组织：

```
MainMenu (登录/注册)
    ↓
Lobby (大厅)
    ↓
MapSelection (地图选择)
    ↓
SoulLoadout (魂印配置)
    ↓
GameMap (9×9地图探索) ←→ Battle (战斗场景)
    ↓
返回 Lobby
```

### 核心场景说明

#### GameMap - 地图探索系统

- **网格**: 9×9 格子，每格 80px
- **格子属性**:
  - `quality` (0-5): 决定资源品质和颜色
  - `resource_count` (1-3): 决定颜色深浅（alpha 值）
  - `explored`: 探索状态（未探索有半透明遮罩）
  - `has_enemy`: 是否有敌人（隐藏）
  - `collapsed`: 是否已坍塌
- **机制**:
  - 玩家只能移动到相邻格子（8 方向）
  - 探索度达到 40%后显示撤离点
  - 每 30 秒坍塌一圈地形（从外向内）
  - 踩到坍塌格子或 HP 归零导致失败
- **状态持久化**: 使用 `UserSession.set_meta()` 在战斗前后保持地图状态

#### Battle - 战斗系统

- **三阶段流程**:
  1. **PREPARATION (10 秒)**: 从所有魂印中选择要使用的
  2. **COMBAT**: 回合制战斗，共用骰子机制
  3. **LOOT (10 秒)**: 背包满时选择丢弃旧魂印获取新魂印
- **战斗公式**:
  - 玩家伤害 = `base_power × dice + sum(selected_souls.power)`
  - 敌人伤害 = `base_power × dice + sum(enemy_souls.power)`
  - 伤害 = abs(player_damage - enemy_damage)
- **状态传递**: 通过 `UserSession.set_meta()` 传递战斗数据和结果

#### SoulLoadout - 魂印配置

- **槽位**: 最多 5 个魂印出战槽位
- **功能**: 从背包选择魂印组成出战阵容
- **数据传递**: 配置好的 loadout 通过 `UserSession.set_meta("soul_loadout", loadout)` 传递给地图场景

### 场景间数据传递模式

使用 `UserSession` 的 meta 数据机制传递场景状态：

```gdscript
# 保存数据
var session = get_node("/root/UserSession")
session.set_meta("key", value)

# 读取数据
if session.has_meta("key"):
    var value = session.get_meta("key")

# 清除数据
session.remove_meta("key")
```

**常用 meta 键**:

- `selected_map`: 选中的地图数据
- `soul_loadout`: 出战魂印配置
- `battle_enemy_data`, `battle_player_hp`, `battle_player_souls`, `battle_enemy_souls`: 战斗数据
- `return_to_map`: 标记是否从战斗返回
- `battle_result`: 战斗结果（won, player_hp_change, loot_souls）
- `map_*`: 地图状态保存（player_pos, player_hp, explored_count 等）

## 游戏系统详解

### 魂印品质和颜色映射

```gdscript
0: 普通 (COMMON)   - Color(0.5, 0.5, 0.5)   灰色
1: 非凡 (UNCOMMON) - Color(0.2, 0.7, 0.2)   绿色
2: 稀有 (RARE)     - Color(0.2, 0.5, 0.9)   蓝色
3: 史诗 (EPIC)     - Color(0.6, 0.2, 0.8)   紫色
4: 传说 (LEGENDARY)- Color(0.9, 0.6, 0.2)   橙色
5: 神话 (MYTHIC)   - Color(0.9, 0.3, 0.3)   红色
```

### 魂印形状数据

形状通过相对坐标数组定义，例如：

- `SQUARE_1X1`: `[[0,0]]`
- `SQUARE_2X2`: `[[0,0],[0,1],[1,0],[1,1]]`
- `L_SHAPE`: `[[0,0],[0,1],[1,0]]`
- `T_SHAPE`: `[[0,0],[0,1],[0,2],[1,1]]`

旋转通过 `get_rotated_shape(rotation)` 计算，rotation 取值 0-3 代表 0°/90°/180°/270°。

### 地形坍塌机制

从外向内每 30 秒坍塌一圈：

- `collapse_ring_index` 追踪已坍塌圈数
- 第 0 圈=最外层，第 4 圈=中心（9×9 地图）
- 坍塌格子标记为 `collapsed=true`，显示深红色 X 标记
- 玩家无法进入已坍塌格子

## 调试配置

- **测试账户**: `test_debug` / `test`
- **商城价格**: 调试阶段设为 0
- **退出地图按钮**: 保留用于调试（生产环境应移除或隐藏）

## UI 规范

- 按钮使用 `StyleBoxFlat` 自定义样式，不使用透明效果
- 错误/提示消息: `AcceptDialog`
- 确认操作: `ConfirmationDialog`
- 亮度控制: 使用 `ColorRect` 覆盖层，alpha = `(100 - brightness) / 100 * 0.7`

## 常见开发任务

### 访问全局系统

```gdscript
# 检查并访问单例
if has_node("/root/UserSession"):
    var session = get_node("/root/UserSession")
```

### 读取用户背包

```gdscript
var soul_system = get_node("/root/SoulPrintSystem")
var username = get_node("/root/UserSession").get_username()
var items = soul_system.get_user_inventory(username)
```

### 添加魂印到背包

```gdscript
var soul_system = get_node("/root/SoulPrintSystem")
var username = get_node("/root/UserSession").get_username()

# 自动寻找位置
soul_system.add_soul_print(username, "soul_thunder")

# 指定位置和旋转
soul_system.add_soul_print(username, "soul_thunder", 2, 3, 1)
```

### 场景跳转

```gdscript
get_tree().change_scene_to_file("res://scenes/Lobby.tscn")
```

## 重要提示

1. **音频总线**: 可能不存在 "Music" 总线，需回退到 "Master"
2. **背包满提示**: 使用 `can_fit_soul()` 检查空间，满时禁止添加
3. **战斗 HP 变化**: 传递给地图的是 `current_hp - initial_hp`（差值）
4. **地图颜色**: 所有格子颜色在进入时就可见，未探索格子有半透明遮罩
5. **撤离机制**: 只能通过撤离点或 HP 归零退出，直接退出会失去所有收集的魂印
6. **战斗战利品**: 优先自动添加到背包，满时进入 LOOT 阶段让玩家选择丢弃
