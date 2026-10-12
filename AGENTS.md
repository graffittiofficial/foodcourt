# Matt Pocock Skills — Factory Droid 适配版

## 使用方法

将此文件放入项目根目录，Droid 启动时会自动读取并遵循以下工作流。

---

## 核心工作流

在开始任何编码之前，按以下流程执行：

### 1. 需求对齐（Grill）

任何时候用户说"帮我做X"，先执行需求追问流程：
- 对计划的每个方面逐一追问，一次只问一个问题
- 每个问题给出你的推荐答案让用户确认或否决
- 如果问题可通过阅读代码回答，主动探索代替提问
- 所有分支走完后，得到用户明确确认才开始编码

### 2. 使用共享语言

- 项目中维护 `CONTEXT.md` 作为领域词汇表
- 代码中使用的术语必须与 `CONTEXT.md` 一致
- 发现模糊或冲突的术语时，立即指出并澄清
- `docs/adr/` 目录存放重要架构决策记录

### 3. TDD 开发（推荐）

- 采用垂直切片模式：一个测试 → 一个实现 → 重复
- 测试通过公共接口验证行为，不验证实现细节
- RED（写失败测试）→ GREEN（最少代码通过）→ Refactor（重构）
- RED 状态下不重构

### 4. 结构化调试（遇到 Bug 时）

- 先构建可复现的反馈回路（最快、最确定的信号）
- 生成 3-5 个可证伪的假设，排序后给用户
- 一次只验证一个变量
- 修复后写回归测试

### 5. 定期架构改进

- 定期检查模块是否"浅"（接口和实现几乎一样复杂）
- 寻找深化机会：小接口背后封装大功能
- 应用"删除测试"：删了这个模块，复杂度会消失还是扩散？
- 使用 `CONTEXT.md` 的术语命名模块

### 6. 文档化

- 功能完成后，决定是否生成 PRD 或拆分为 Issue
- 重要设计决策记录为 ADR
- 交接时生成交接文档

---

## 技能参考

### Engineering（编码用）

| 技能 | 作用 | 触发条件 |
|------|------|---------|
| grill-me | 需求追问 | 开始新功能/变更时 |
| grill-with-docs | 需求追问 + 共享语言构建 | 需要构建领域术语时 |
| tdd | 测试驱动开发 | 用户要求 TDD 或写测试时 |
| diagnose | 结构化调试 | 遇到 Bug 或性能问题时 |
| improve-codebase-architecture | 架构改进 | 代码变乱或用户要求重构时 |
| to-prd | 生成 PRD | 需要记录需求文档时 |
| to-issues | 拆分为 Issue | 需要将计划转为可执行任务时 |
| prototype | 构建原型 | 需要验证设计方向时 |
| triage | Issue 分类 | 管理 Issue 队列时 |
| zoom-out | 全局视角 | 不熟悉某块代码时 |

### Productivity（日常用）

| 技能 | 作用 | 触发条件 |
|------|------|---------|
| caveman | 极简回复 | 想省 Token 时 |
| handoff | 生成交接文档 | 对话/任务需要转交时 |
| write-a-skill | 创建新技能 | 需要自定义 skill 时 |

### Misc（偶尔用）

| 技能 | 作用 | 触发条件 |
|------|------|---------|
| git-guardrails | Git 安全防护 | 需要阻止危险 Git 操作时 |
| migrate-to-shoehorn | 测试代码迁移 | 迁移 as 断言时 |
| scaffold-exercises | 练习题脚手架 | 创建练习结构时 |
| setup-pre-commit | 预提交钩子 | 配置 Husky + Prettier 时 |

---

## 项目文件结构约定

```
/
├── CONTEXT.md              # 领域词汇表（核心，必须）
├── CONTEXT-MAP.md          # 多上下文时使用
├── AGENTS.md               # 本文件
├── docs/
│   ├── adr/                # 架构决策记录
│   │   ├── 0001-xxx.md
│   │   └── 0002-yyy.md
│   └── agents/             # Agent 配置
│       ├── issue-tracker.md
│       ├── triage-labels.md
│       └── domain.md
├── .scratch/               # 本地 Issue 跟踪（可选）
└── src/
```

## Agent skills

This repository is configured for the Matt Pocock skills workflow using GitHub issues and canonical triage labels.

- Issue tracker: GitHub (`gh` CLI)
- Labels: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`
- Domain docs: root `CONTEXT.md` plus `docs/adr/` decisions

See the project-specific configuration files in `docs/agents/`.
