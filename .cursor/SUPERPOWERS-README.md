# Superpowers for Cursor - 安装完成

## ✅ 安装状态

Superpowers 已成功为 Cursor 配置！

### 已完成的配置

1. **✅ Superpowers 仓库克隆**
   - 位置: `C:\Users\BulletS\.codex\superpowers`
   - 包含所有官方 superpowers 技能

2. **✅ Cursor 技能链接**
   - 位置: `C:\Users\BulletS\.cursor\skills-cursor\superpowers`
   - 通过目录联接链接到 superpowers 仓库
   - 所有技能自动同步更新

3. **✅ 规则文件创建**
   - 全局规则: `C:\Users\BulletS\.cursor\rules\superpowers.md`
   - 项目规则: `d:\_Scripts\GitHub\BsKeyTools\.cursor\rules\superpowers.md`

## 📚 可用的 Superpowers 技能

### 🔴 强制性技能（遇到相关情况必须使用）

1. **superpowers/using-superpowers**
   - 使用时机：开始任何对话时
   - 说明：建立如何查找和使用技能的基础

2. **superpowers/brainstorming**
   - 使用时机：任何创意工作前（创建功能、组件、修改行为）
   - 说明：在实现前探索需求和设计

3. **superpowers/systematic-debugging**
   - 使用时机：遇到任何错误、测试失败或意外行为时
   - 说明：系统性的 4 阶段根因分析流程

4. **superpowers/test-driven-development**
   - 使用时机：实现任何功能或修复前
   - 说明：强制执行 RED-GREEN-REFACTOR 循环

5. **superpowers/verification-before-completion**
   - 使用时机：声称工作完成、修复或测试通过前
   - 说明：运行验证命令并确认输出

### 📋 规划与执行技能

- **superpowers/writing-plans** - 为多步任务编写详细实现计划
- **superpowers/executing-plans** - 分批执行计划并设置检查点
- **superpowers/subagent-driven-development** - 使用子代理执行独立任务
- **superpowers/dispatching-parallel-agents** - 并发处理 2 个以上独立任务

### 🔍 代码审查与完成技能

- **superpowers/requesting-code-review** - 完成任务前的预审查清单
- **superpowers/receiving-code-review** - 响应代码审查反馈
- **superpowers/finishing-a-development-branch** - 合并/PR 决策工作流

### 🛠️ 开发工具技能

- **superpowers/using-git-worktrees** - 创建隔离的开发分支
- **superpowers/writing-skills** - 创建新技能或编辑现有技能

## 🚀 如何在 Cursor 中使用

### 方法 1：通过 @ 符号引用技能

在与 AI 对话时，使用 `@` 符号引用技能：

```
@superpowers/brainstorming 我想添加一个新功能...
```

### 方法 2：明确要求使用技能

直接告诉 AI 使用特定技能：

```
请使用 superpowers/brainstorming 技能来帮我设计这个功能
```

### 方法 3：让 AI 自动选择

由于已经配置了规则，AI 应该会自动检查并使用相关技能：

```
我想添加用户认证功能
```

AI 应该会自动：
1. 检测到这是创意工作
2. 使用 brainstorming 技能
3. 引导你完成需求探索和设计

## ⚠️ 重要规则

1. **技能适用时必须使用**
   - 这不是可选的，如果技能适用于你的任务，必须使用它
   - 即使只有 1% 的可能性，也应该检查该技能

2. **在任何响应或行动前检查技能**
   - 甚至在提出澄清问题之前
   - 甚至在探索代码库之前
   - 甚至在收集信息之前

3. **遵循技能的指导**
   - 刚性技能（TDD、调试）：严格遵循
   - 灵活技能（模式）：根据上下文调整原则

## 🔄 更新 Superpowers

要获取最新的技能和改进：

```powershell
cd C:\Users\BulletS\.codex\superpowers
git pull
```

由于使用了目录联接，更新会自动反映到 Cursor 的技能目录中。

## 📖 更多信息

- **Superpowers 官方仓库**: https://github.com/obra/superpowers
- **技能位置**: `C:\Users\BulletS\.cursor\skills-cursor\superpowers\`
- **规则文件**: 
  - 全局: `C:\Users\BulletS\.cursor\rules\superpowers.md`
  - 项目: `.cursor\rules\superpowers.md`

## 🎯 开始使用

1. 重启 Cursor（如果正在运行）
2. 开始新的对话
3. AI 应该会根据规则自动检查并使用相关技能
4. 如果需要，可以明确引用特定技能 `@superpowers/...`

---

**记住**: 如果技能适用于你的任务，没有选择余地 - 必须使用它！这能确保代码质量、系统性方法和最佳实践。
