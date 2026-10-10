# 06 Tool 系统设计

## 1. 概述

Tool 系统是 opencode 赋予 AI 执行实际操作能力的核心机制。每个工具代表一类可以被 LLM 调用的操作，如读写文件、执行 shell 命令、搜索代码等。

---

## 2. Tool 类型体系

```
Tool
├── 内置工具（Built-in）     ← 代码内置，15 个
├── MCP 工具（MCP）          ← 外部 MCP Server 提供
└── Plugin 工具（Plugin）    ← 用户插件提供
```

---

## 3. Tool 数据结构

```typescript
// packages/opencode/src/tool/tool.ts
interface Tool.Def {
  id: string                    // 工具唯一 ID（如 "read", "bash", "glob"）
  description: string           // 工具描述（注入给 LLM 的 system prompt）
  parameters: z.ZodSchema       // Zod 参数 schema（用于 LLM 生成调用）
  jsonSchema: JSONSchema7        // JSON Schema 版本（备用）
  execute: (args, ctx) => Promise<ToolResult>  // 执行函数
}
```

---

## 4. 内置工具清单

代码：`packages/opencode/src/tool/registry.ts`

| 工具 ID | 文件 | 功能描述 |
|---------|------|----------|
| `read` | `read.ts` | 读取文件内容（支持行范围、图片 base64） |
| `write` | `write.ts` | 写入文件（创建或覆盖） |
| `edit` | `edit.ts` | 精确编辑文件（查找替换，原子操作） |
| `apply_patch` | `apply_patch.ts` | 应用 unified diff 格式的补丁 |
| `bash` | `shell.ts` | 执行 shell 命令（超时保护） |
| `glob` | `glob.ts` | 文件路径 glob 匹配 |
| `grep` | `grep.ts` | 基于 ripgrep 的代码搜索 |
| `list` | （内含于 glob） | 列出目录内容 |
| `webfetch` | `webfetch.ts` | HTTP 请求（网页抓取） |
| `websearch` | `websearch.ts` | 网络搜索（需 Exa API 或 opencode provider） |
| `task` | `task.ts` | 调度子 Agent（并行执行子任务） |
| `todowrite` | `todo.ts` | 写入/更新待办事项列表 |
| `skill` | `skill.ts` | 读取 Skill（可复用提示片段） |
| `question` | `question.ts` | 向用户提问（TUI/app 模式） |
| `lsp` | `lsp.ts` | LSP 操作（代码跳转、补全）[实验性] |
| `plan_exit` | `plan.ts` | 退出 Plan 模式 [实验性] |

### 4.1 read 工具

```typescript
// 参数
{
  filePath: string,           // 绝对或相对路径
  startLine?: number,         // 起始行（1-indexed）
  endLine?: number,           // 结束行（含）
}

// 特性：
// - 自动截断过长内容（Truncate.Service 控制）
// - 图片文件转 base64 返回（支持视觉模型）
// - 超出行范围时返回实际行数提示
```

### 4.2 edit 工具

```typescript
// 参数
{
  filePath: string,
  oldStr: string,      // 要替换的原始文本（必须精确匹配）
  newStr: string,      // 替换后的文本
}

// 特性：
// - 原子性：先计算结果，验证通过后一次性写入
// - 精确匹配：oldStr 必须在文件中只出现一次
// - 自动创建目录
```

### 4.3 bash 工具

```typescript
// 参数
{
  command: string,        // shell 命令
  timeout?: number,       // 超时毫秒数（默认 10 分钟）
  description?: string,  // 命令描述（权限提示显示给用户）
}

// 特性：
// - 超时后发送 SIGTERM，等待 5 秒后 SIGKILL
// - 输出截断保护（过长输出自动截断）
// - 环境变量继承（包括 PATH）
```

### 4.4 task 工具（子 Agent）

```typescript
// 参数
{
  agent: string,           // 子 Agent 名称（explore/general 等）
  prompt: string,          // 子任务描述
  timeout?: number,
}

// 特性：
// - 创建新的子 Session（parentID 指向当前 Session）
// - 子 Session 使用独立的权限规则集（通常更受限）
// - 支持并发调用多个子 Agent（task 工具并行）
// - 子 Session 完成后返回结果文本
```

---

## 5. Tool Registry 服务

```typescript
interface ToolRegistry.Interface {
  // 获取所有工具 ID
  ids: () => Effect.Effect<string[]>

  // 获取所有工具定义（内置 + 自定义）
  all: () => Effect.Effect<Tool.Def[]>

  // 获取特定工具的引用
  named: () => Effect.Effect<{ task: TaskDef; read: ReadDef }>

  // 根据 Provider/模型/Agent 过滤工具列表
  tools: (model: {
    providerID: ProviderV2.ID
    modelID: ModelV2.ID
    agent: Agent.Info
    permission?: PermissionV1.Ruleset
  }) => Effect.Effect<Tool.Def[]>
}
```

**工具过滤逻辑（`tools()` 方法）：**

```typescript
// 1. 按模型特性选择编辑工具
const usePatch = modelID.includes("gpt-") && !isOss && !isGpt4
// GPT 模型使用 apply_patch，其他模型使用 edit + write

// 2. 按 Provider 特性启用 websearch
const searchEnabled = webSearchEnabled(providerID, flags)
// opencode provider 或 Exa API 可用时启用

// 3. 按 Agent 权限规则集过滤
const filtered = tools.filter(tool =>
  Permission.evaluate(tool.id, "*", agent.permission).action !== "deny"
)
```

---

## 6. 权限控制

每个工具调用都经过权限评估：

### 6.1 权限规则结构

```typescript
type Rule = {
  permission: string   // 对应工具 ID 或通配符 "*"
  action: "allow" | "deny" | "ask"
  pattern: string      // 资源路径 glob 模式
}
```

### 6.2 默认权限（build agent）

```typescript
Permission.fromConfig({
  "*": "allow",             // 默认允许所有
  doom_loop: "ask",         // 防止无限循环时询问
  external_directory: {
    "*": "ask",             // 项目目录外的文件询问
    [Truncate.GLOB]: "allow",  // 截断临时文件目录允许
  },
  question: "deny",         // build agent 不主动提问
  plan_enter: "deny",
  read: {
    "*": "allow",
    "*.env": "ask",         // 敏感文件询问
    "*.env.*": "ask",
    "*.env.example": "allow",
  },
})
```

### 6.3 权限评估流程

```typescript
// 工具执行前调用
const result = Permission.evaluate(
  toolName,        // 如 "read"
  resourcePath,    // 如 "/home/user/project/.env"
  agent.permission
)

switch (result.action) {
  case "allow":
    return await tool.execute(args)
  case "deny":
    return { error: "Permission denied" }
  case "ask":
    // 发布 PermissionRequest 事件
    const userDecision = await waitForUserApproval()
    if (userDecision === "allow") return await tool.execute(args)
    if (userDecision === "deny") return { error: "Denied by user" }
    if (userDecision === "always") {
      // 持久化此规则到 session.permission
      await Permission.persist(toolName, resourcePath, "allow")
      return await tool.execute(args)
    }
}
```

### 6.4 永久权限持久化

当用户选择"永久允许"时，规则写入数据库：

```sql
INSERT INTO permission (project_id, action, resource, ...)
VALUES (?, ?, ?, ...)
ON CONFLICT DO UPDATE SET time_updated = ?
```

---

## 7. 工具截断（Truncate）

大型文件/输出通过 Truncate.Service 处理，防止 token 超限：

```typescript
// packages/opencode/src/tool/truncate.ts
interface Truncate.Interface {
  // 截断文本到 token 限制
  text: (content: string, maxTokens?: number) => Effect.Effect<string>

  // 截断文件内容（优先保留开头和结尾）
  file: (content: string, path: string) => Effect.Effect<string>
}

// 特殊目录：截断结果缓存到临时文件
// GLOB 常量：允许 AI 读取截断后的文件
export const GLOB = path.join(Global.Path.tmp, "*")
```

---

## 8. MCP 工具集成

MCP 工具由外部 MCP Server 提供，通过 `MCP.Service` 注入 Tool Registry：

```typescript
// Tool Registry 初始化时获取所有 MCP 工具
const mcpTools = await MCP.Service.tools()

// MCP 工具 Def 结构与内置工具相同
// 工具名：mcp__{serverName}__{toolName}（命名空间隔离）
```

详细 MCP 设计见 [09-mcp.md](./09-mcp.md)。

---

## 9. Plugin 工具

用户可通过插件 API 注册自定义工具：

```typescript
// 插件文件：~/.config/opencode/plugins/my-plugin.ts
import { definePlugin } from "@opencode-ai/plugin"

export default definePlugin({
  tool: {
    "my-custom-tool": {
      description: "Does something custom",
      args: {
        input: z.string().describe("Input text"),
      },
      execute: async ({ input }) => {
        return { content: `Processed: ${input}` }
      }
    }
  }
})
```

Plugin 工具在 Tool Registry 初始化时合并到 `custom` 列表。

---

## 10. 工具调用触发点

工具的 `trigger` 钩子允许插件在工具调用前修改工具定义：

```typescript
// Plugin 可监听 tool.definition 事件
plugin.trigger("tool.definition", { toolID }, output)
// output.description 可被修改
// output.parameters 可被增强
```
