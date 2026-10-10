# 07 Agent 系统设计

## 1. 概述

Agent 是 opencode 中 LLM 行为模式的抽象单元。每个 Agent 封装了：系统提示词、工具权限规则集、模型偏好、执行模式等配置。用户可使用内置 Agent，也可通过配置文件定义自定义 Agent。

---

## 2. Agent 数据结构

```typescript
// packages/opencode/src/agent/agent.ts
interface Agent.Info {
  name: string                        // Agent 标识名称（唯一）
  description?: string                // 显示描述（用于 task 工具的 agent 选择）
  mode: "subagent" | "primary" | "all" // 执行模式
  native?: boolean                    // 是否为内置 Agent
  hidden?: boolean                    // 是否在列表中隐藏
  prompt?: string                     // 系统提示词（覆盖默认）
  permission: PermissionV1.Ruleset    // 权限规则集
  model?: {                           // 模型偏好（可选）
    modelID: ModelV2.ID
    providerID: ProviderV2.ID
  }
  variant?: string                    // 模型变体
  temperature?: number                // 生成温度
  topP?: number
  color?: string                      // UI 显示颜色
  steps?: number                      // 最大工具调用步数
  options: Record<string, unknown>    // 扩展选项
}
```

---

## 3. 执行模式（mode）

| 模式 | 说明 | 适用场景 |
|------|------|----------|
| `primary` | 主 Agent，可由用户直接使用 | build、plan、title 等 |
| `subagent` | 子 Agent，只能通过 task 工具调用 | explore、general |
| `all` | 主 Agent 且可作为子 Agent 使用 | 自定义 Agent 默认值 |

---

## 4. 内置 Agent 详解

### 4.1 build（默认主 Agent）

```typescript
{
  name: "build",
  description: "The default agent. Executes tools based on configured permissions.",
  mode: "primary",
  native: true,
  permission: Permission.merge(defaults, {
    question: "allow",    // 可向用户提问
    plan_enter: "allow",  // 可进入 plan 模式
  }),
}
```

这是用户交互的主入口，具备最全的工具权限，支持所有内置工具。

### 4.2 plan（计划模式 Agent）

```typescript
{
  name: "plan",
  mode: "primary",
  native: true,
  permission: Permission.merge(defaults, {
    question: "allow",
    plan_exit: "allow",      // 可退出 plan 模式
    task: { general: "deny" }, // 不能调度 general 子 Agent
    external_directory: {
      [planDir + "/*"]: "allow",  // 只能操作 plans 目录
    },
    edit: {
      "*": "deny",
      "**/.opencode/plans/*.md": "allow",  // 只能编辑 plan 文件
    },
  }),
}
```

Plan 模式下 AI 只能操作计划文件，不能直接修改代码文件，降低误操作风险。

### 4.3 general（通用子 Agent）

```typescript
{
  name: "general",
  description: "General-purpose agent for researching complex questions and executing multi-step tasks.",
  mode: "subagent",
  permission: Permission.merge(defaults, {
    todowrite: "deny",   // 不能修改 todo 列表
  }),
}
```

适用于复杂任务分解，可被 build/plan Agent 通过 task 工具并行调度。

### 4.4 explore（探索 Agent）

```typescript
{
  name: "explore",
  description: "Fast agent specialized for exploring codebases.",
  mode: "subagent",
  prompt: PROMPT_EXPLORE,   // 专用探索系统提示词
  permission: Permission.merge(defaults, {
    "*": "deny",          // 默认拒绝所有
    grep: "allow",
    glob: "allow",
    list: "allow",
    bash: "allow",
    webfetch: "allow",
    websearch: "allow",
    read: "allow",
    external_directory: readonlyExternalDirectory,
  }),
}
```

只读权限，专注于快速代码探索，不能写文件。支持三个粒度：quick/medium/very thorough。

### 4.5 compaction（压缩 Agent）[隐藏]

```typescript
{
  name: "compaction",
  mode: "primary",
  native: true,
  hidden: true,         // 不在用户列表显示
  prompt: PROMPT_COMPACTION,
  permission: {
    "*": "deny",        // 不能使用任何工具
  },
}
```

仅用于生成对话摘要，无工具调用权限，防止在压缩过程中执行副作用。

### 4.6 title（标题生成 Agent）[隐藏]

```typescript
{
  name: "title",
  mode: "primary",
  hidden: true,
  temperature: 0.5,
  prompt: PROMPT_TITLE,
  permission: { "*": "deny" },
}
```

根据 Session 第一条消息自动生成简短标题，temperature 0.5 保证一定创意性。

### 4.7 summary（摘要 Agent）[隐藏]

```typescript
{
  name: "summary",
  mode: "primary",
  hidden: true,
  prompt: PROMPT_SUMMARY,
  permission: { "*": "deny" },
}
```

生成 Session 的代码变更摘要（additions/deletions/files 统计）。

---

## 5. Agent Service 接口

```typescript
interface Agent.Interface {
  // 根据名称获取 Agent 信息
  get: (agent: string) => Effect.Effect<Agent.Info>

  // 获取所有可见 Agent 列表（按默认 Agent 优先排序）
  list: () => Effect.Effect<Agent.Info[]>

  // 获取默认 Agent 信息
  defaultInfo: () => Effect.Effect<Agent.Info>

  // 获取默认 Agent 名称
  defaultAgent: () => Effect.Effect<string>

  // 使用 LLM 动态生成新 Agent 定义
  generate: (input: {
    description: string
    model?: { providerID: ProviderV2.ID; modelID: ModelV2.ID }
  }) => Effect.Effect<{
    identifier: string
    whenToUse: string
    systemPrompt: string
  }, Provider.DefaultModelError>
}
```

---

## 6. 权限规则集（Ruleset）详解

### 6.1 规则评估算法

权限评估使用最长匹配原则（类似 gitignore）：

```typescript
function evaluate(toolName: string, resource: string, ruleset: Ruleset) {
  // 1. 收集所有匹配的规则（工具名匹配 + 资源路径 glob 匹配）
  const matches = ruleset.filter(rule =>
    matchesToolName(rule.permission, toolName) &&
    minimatch(resource, rule.pattern)
  )

  // 2. 取最具体的匹配（最长 pattern）
  const best = matches.sort((a, b) =>
    b.pattern.length - a.pattern.length
  )[0]

  // 3. 返回动作
  return best?.action ?? "deny"  // 默认拒绝
}
```

### 6.2 权限合并

多个 Ruleset 的合并规则：**后面的 Ruleset 追加到前面，相同 pattern 的规则后者优先**

```typescript
Permission.merge(defaults, userConfig)
// → userConfig 的规则会覆盖 defaults 中相同 pattern 的规则
```

### 6.3 whitelistedDirs（白名单目录）

系统自动将以下目录加入外部目录白名单（allow）：

```typescript
const whitelistedDirs = [
  Truncate.GLOB,                        // 截断缓存目录
  path.join(Global.Path.tmp, "*"),      // 临时文件
  ...skillDirs.map(dir => path.join(dir, "*")),       // Skill 目录
  ...referenceDirs.map(dir => path.join(dir, "*")),   // Reference 目录
]
```

---

## 7. 自定义 Agent 配置

用户可在配置文件中定义自定义 Agent：

```yaml
# ~/.config/opencode/config.yaml 或项目 .opencode/config.yaml
agent:
  reviewer:
    name: "Code Reviewer"
    description: "Specialized for code review, suggests improvements without modifying code"
    mode: "subagent"
    prompt: |
      You are a code reviewer. Analyze code for issues and suggest improvements.
      Never modify files directly.
    permission:
      "*": "deny"
      read: "allow"
      grep: "allow"
      glob: "allow"
    model:
      provider: anthropic
      model: claude-opus-4-5

  fast-helper:
    description: "Quick tasks with limited tools"
    mode: "all"
    model:
      provider: openai
      model: gpt-4o-mini
    temperature: 0.3
    steps: 10
```

---

## 8. Agent 动态生成

`Agent.generate()` 使用 LLM 根据用户描述生成新 Agent 定义：

```typescript
// 输入：自然语言描述
const result = await Agent.generate({
  description: "An agent for writing unit tests",
})

// 输出
{
  identifier: "test-writer",
  whenToUse: "Use when you need to write unit tests for existing code",
  systemPrompt: "You are an expert at writing comprehensive unit tests..."
}
```

生成结果可保存为用户配置文件中的自定义 Agent。

---

## 9. 子 Agent 调度流程

通过 `task` 工具调度子 Agent：

```
主 Agent（build）执行 task 工具
    │
    ├── 创建子 Session（parentID = 当前 sessionID）
    ├── 子 Session 使用指定子 Agent（explore/general）
    ├── 子 Session 权限 = 子 Agent 权限（更严格）
    │
    ▼ 并发执行（多个 task 可同时运行）
    │
    ├── 子 Session 完成 → 返回结果文本
    └── 主 Session 继续（汇总子结果）
```

子 Agent 的 Session 在数据库中完整记录，支持在 TUI 中查看子 Agent 的执行过程。
