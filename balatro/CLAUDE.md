# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

这是Balatro游戏的源代码，基于Love2D (LÖVE)引擎用Lua开发的卡牌游戏。游戏采用模块化架构，包含了完整的游戏引擎、UI系统、卡牌逻辑、以及游戏玩法实现。

## 架构结构

### 核心文件
- `main.lua` - 游戏主入口点，负责初始化Love2D引擎和模块加载
- `conf.lua` - Love2D引擎配置文件，设置窗口参数和基本配置
- `game.lua` - 主游戏类，管理游戏状态和全局对象G
- `globals.lua` - 全局变量和常量定义

### 游戏核心模块
- `card.lua` - 卡牌系统实现，包含卡牌逻辑、效果和数据结构 (242KB)
- `cardarea.lua` - 卡牌区域管理，处理卡牌的布局和交互
- `blind.lua` - 盲注系统，管理游戏关卡和难度
- `tag.lua` - 标签系统，处理游戏中的各种标记和状态
- `challenges.lua` - 挑战模式实现
- `back.lua` - 背景和牌背系统

### 引擎模块 (`engine/`)
- `object.lua` - 基础对象系统，提供OOP支持
- `node.lua` - 场景图节点系统
- `sprite.lua` / `animatedsprite.lua` - 精灵和动画系统
- `ui.lua` - UI框架实现 (45KB)
- `controller.lua` - 输入控制器系统 (60KB)
- `event.lua` - 事件系统
- `particles.lua` - 粒子系统
- `text.lua` - 文本渲染系统
- `sound_manager.lua` - 音频管理
- `save_manager.lua` - 存档管理

### 功能模块 (`functions/`)
- `UI_definitions.lua` - UI定义和布局 (349KB)
- `button_callbacks.lua` - 按钮回调函数 (117KB)
- `common_events.lua` - 通用事件处理 (130KB)
- `state_events.lua` - 状态事件管理 (75KB)
- `misc_functions.lua` - 杂项工具函数 (73KB)
- `test_functions.lua` - 测试相关函数

### 其他目录
- `localization/` - 本地化和多语言支持
- `resources/` - 游戏资源文件

## 开发环境

### 运行游戏
Love2D引擎项目，使用以下命令运行：
```bash
love .
```

或者如果Love2D已安装并在PATH中：
```bash
love /path/to/balatro
```

### 调试模式
在`conf.lua`中设置`_RELEASE_MODE = false`可开启调试控制台。

## 代码特点

### 模块化设计
- 游戏采用require模式加载模块，所有模块在main.lua中统一加载
- 使用Object:extend()模式实现面向对象编程
- 全局游戏对象G管理整个游戏状态

### 数据管理
- 使用STR_PACK/STR_UNPACK进行数据序列化
- 存档文件使用.jkr扩展名
- 版本控制通过version.jkr文件管理

### UI系统
- 基于引擎的UI框架，支持复杂的界面布局
- 按钮系统通过回调函数处理用户交互
- 事件驱动的状态管理

## 注意事项

- 代码中包含中文注释，便于理解各模块功能
- 游戏版本为1.0.1o-FULL，是完整版本
- 项目较大，单个文件可能超过200KB，修改时需要注意性能
- Love2D特定的API调用需要参考Love2D文档