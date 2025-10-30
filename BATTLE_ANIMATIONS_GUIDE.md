# 战斗动画系统使用指南

> 基于 Balatro 风格的华丽战斗动画系统
> 文件位置：`scripts/BattleAnimator.gd`

---

## 功能概述

已为战斗场景添加了完整的动画系统，包括：

✅ **积分结算动画** - 分步展示力量计算过程
✅ **骰子滚动动画** - 带旋转效果的骰子动画
✅ **魂印激活特效** - 光环扩散和文字提示
✅ **伤害数字飘出** - 支持普通和暴击效果
✅ **屏幕震动效果** - 根据伤害强度震动
✅ **胜利/失败动画** - 战斗结束的华丽展示

---

## 动画效果展示

### 1. 积分结算动画

**效果描述**：
- 弹出半透明面板，展示计算过程
- 逐行显示：基础力量 → 骰子 → 魂印加成 → 最终结果
- 每行带淡入和缩放动画
- 魂印效果行带发光特效
- 最终结果震撼登场，颜色闪烁

**触发时机**：每回合计算玩家和敌人力量时

**视觉特点**：
```
━━━ 力量计算 ━━━
基础力量               50
骰子点数              × 5
                    = 250

━━━ 魂印加成 ━━━
火焰之魂             + 20
雷霆之魂             + 15
魂印总加成           + 35

最终伤害: 285
```

### 2. 骰子滚动动画

**效果描述**：
- 居中弹出骰子面板
- 快速切换数字模拟滚动（1.5秒）
- 带旋转晃动效果
- 最终结果放大强调

**触发时机**：每回合开始时

**视觉特点**：
- 白色边框方形面板
- 大号数字（64px）
- 弹出动画（TRANS_BACK）

### 3. 魂印激活特效

**效果描述**：
- 光环从中心向外扩散
- 根据魂印品质显示不同颜色
- 魂印名称浮现并上升
- 半透明效果，不遮挡主界面

**触发时机**：玩家选中的魂印生效时

**品质颜色映射**：
- 普通：灰色 (0.5, 0.5, 0.5)
- 非凡：绿色 (0.2, 0.7, 0.2)
- 稀有：蓝色 (0.2, 0.5, 0.9)
- 史诗：紫色 (0.6, 0.2, 0.8)
- 传说：橙色 (0.9, 0.6, 0.2)
- 神话：红色 (0.9, 0.3, 0.3)

### 4. 伤害数字飘出

**效果描述**：
- 大号数字从受伤位置飘出
- 向上移动并淡出
- 支持普通和暴击两种样式

**普通伤害**：
- 字号：36px
- 颜色：红色 (1.0, 0.5, 0.5)
- 黑色描边：2px

**暴击伤害** (伤害>100)：
- 字号：48px
- 颜色：鲜红 (1.0, 0.2, 0.2)
- 金色描边：3px
- 更强的缩放效果

### 5. 屏幕震动

**效果描述**：
- 摄像机快速随机偏移
- 强度根据伤害值动态调整
- 持续 0.3 秒
- 不影响 UI 元素

**强度公式**：
```gdscript
intensity = min(damage / 10.0, 15.0)
最大震动：15 像素
```

### 6. 胜利/失败动画

**胜利动画**：
- "胜利！"大字
- 金色文字 (1.0, 0.8, 0.2)
- 缩放弹出效果
- 5 次颜色闪烁

**失败动画**：
- "失败..."灰色文字
- 缓慢下沉效果
- 淡入显示

---

## API 使用说明

### 初始化

```gdscript
# 在战斗场景的 _ready() 中
var battle_animator: BattleAnimator

func _ready():
    battle_animator = BattleAnimator.new()
    add_child(battle_animator)
```

### 积分结算动画

```gdscript
await battle_animator.play_score_calculation(
    base_power: int,           # 基础力量
    dice: int,                 # 骰子点数
    soul_effects: Array,       # 魂印效果列表
    final_damage: int,         # 最终伤害
    position: Vector2          # 显示位置
)

# soul_effects 格式：
[
    {"name": "火焰之魂", "power": 20, "quality": 2},
    {"name": "雷霆之魂", "power": 15, "quality": 3}
]

# 等待动画完成
await battle_animator.animation_completed
```

### 骰子滚动动画

```gdscript
var dice_result = await battle_animator.play_dice_roll(position)
print("骰子结果: ", dice_result)  # 1-6
```

### 魂印激活特效

```gdscript
battle_animator.play_soul_activation(
    soul_name: String,         # 魂印名称
    position: Vector2,         # 显示位置
    quality: int               # 品质等级 0-5
)

# 注意：此方法不等待完成，可连续调用
```

### 伤害数字飘出

```gdscript
battle_animator.play_damage_number(
    damage: int,               # 伤害数值
    position: Vector2,         # 起始位置
    is_critical: bool          # 是否暴击
)

# 示例
battle_animator.play_damage_number(285, enemy_pos, true)
```

### 屏幕震动

```gdscript
battle_animator.play_screen_shake(
    intensity: float = 10.0,   # 震动强度（像素）
    duration: float = 0.3      # 持续时间（秒）
)

# 示例：根据伤害动态调整
var shake_intensity = min(damage / 10.0, 15.0)
battle_animator.play_screen_shake(shake_intensity, 0.3)
```

### 胜利/失败动画

```gdscript
# 胜利
await battle_animator.play_victory_animation(position)

# 失败
await battle_animator.play_defeat_animation(position)
```

---

## 完整战斗流程示例

```gdscript
func _execute_combat_round():
    var viewport_size = get_viewport_rect().size

    # 1. 骰子滚动
    var dice = await battle_animator.play_dice_roll(viewport_size / 2.0)

    # 2. 魂印激活特效（玩家）
    for soul in player_souls:
        var pos = Vector2(viewport_size.x * 0.3, viewport_size.y * 0.5)
        battle_animator.play_soul_activation(soul.name, pos, soul.quality)
        await get_tree().create_timer(0.3).timeout

    # 3. 玩家积分计算
    var player_pos = Vector2(viewport_size.x * 0.25, viewport_size.y * 0.3)
    battle_animator.play_score_calculation(
        player_base_power, dice, player_soul_effects,
        player_final, player_pos
    )
    await battle_animator.animation_completed

    # 4. 敌人积分计算
    var enemy_pos = Vector2(viewport_size.x * 0.75, viewport_size.y * 0.3)
    battle_animator.play_score_calculation(
        enemy_base_power, dice, enemy_soul_effects,
        enemy_final, enemy_pos
    )
    await battle_animator.animation_completed

    # 5. 伤害判定和动画
    var damage = abs(player_final - enemy_final)
    if player_final > enemy_final:
        # 敌人受伤
        var target_pos = Vector2(viewport_size.x * 0.75, viewport_size.y * 0.5)
        battle_animator.play_damage_number(damage, target_pos, damage > 100)
        battle_animator.play_screen_shake(min(damage / 10.0, 15.0), 0.3)

    # 6. 检查胜负
    if enemy_hp <= 0:
        await battle_animator.play_victory_animation(viewport_size / 2.0)
    elif player_hp <= 0:
        await battle_animator.play_defeat_animation(viewport_size / 2.0)
```

---

## 性能优化建议

### 1. 动画层级管理

动画使用独立的 `CanvasLayer` (layer=100)，确保在最顶层显示，不受其他 UI 影响。

### 2. 内存管理

所有动画元素在完成后自动调用 `queue_free()`，避免内存泄漏。

### 3. 并发控制

- 积分计算动画是串行的（使用 `await animation_completed`）
- 魂印激活特效可以并发播放
- 伤害数字和震动可以同时触发

### 4. 动画速度调整

可以通过修改以下参数调整动画速度：

```gdscript
# 骰子滚动时间
var roll_duration = 1.5  # 秒

# 积分计算每行延迟
await get_tree().create_timer(0.2).timeout

# 魂印激活间隔
await get_tree().create_timer(0.3).timeout
```

---

## 自定义扩展

### 添加新的动画效果

1. 在 `BattleAnimator.gd` 中添加新方法
2. 使用 `Tween` 创建动画
3. 在动画层 `animation_layer` 中添加节点
4. 完成后清理节点

示例：

```gdscript
func play_custom_effect(position: Vector2) -> void:
    var label = Label.new()
    label.text = "自定义效果"
    label.position = position
    animation_layer.add_child(label)

    var tween = create_tween()
    tween.tween_property(label, "modulate:a", 0.0, 1.0)
    await tween.finished

    label.queue_free()
```

---

## 故障排查

### 问题：动画不显示

**检查**：
1. 确认 `BattleAnimator` 已在 `_ready()` 中初始化
2. 检查 `animation_layer` 是否已添加到场景树
3. 确认 `layer = 100` 设置正确

### 问题：屏幕震动无效

**原因**：场景中没有 Camera2D

**解决**：
```gdscript
# 检查摄像机
var camera = get_viewport().get_camera_2d()
if not camera:
    print("警告：未找到摄像机，屏幕震动无效")
```

### 问题：动画卡顿

**优化**：
1. 减少并发动画数量
2. 降低动画刷新频率
3. 简化 Tween 动画步骤

---

## 与 Balatro 的对比

| 特性 | Balatro | Jungle Gambler |
|------|---------|----------------|
| **积分计算** | 分层展示（6层） | 简化版（3层） |
| **骰子动画** | 3D 旋转 | 2D 数字切换 |
| **卡牌特效** | 粒子系统 | 光环扩散 |
| **伤害反馈** | 数字飘出 + 震动 | 相同 |
| **胜利动画** | 金币爆炸 | 文字闪烁 |

---

## 未来改进方向

### 短期（1-2周）

- [ ] 添加音效支持
- [ ] 优化动画时间曲线
- [ ] 添加更多过渡效果

### 中期（1个月）

- [ ] 粒子系统特效
- [ ] 更复杂的魂印激活动画
- [ ] 连击计数器动画

### 长期（3个月）

- [ ] 完整的动画编辑器
- [ ] 动画配置文件系统
- [ ] 自定义动画脚本支持

---

**创建日期**：2025-01-30
**版本**：1.0
**维护者**：Claude Code
