# 12 CLI 设计

## 1. 概述

opencode 的 CLI 基于 yargs 构建，入口文件为 `packages/opencode/src/index.ts`。CLI 负责启动 HTTP Server、TUI，以及提供各类管理命令。

---

## 2. 运行模式

### 2.1 交互模式（默认）

```bash
opencode
# 启动 HTTP Server（随机端口）+ TUI
# Server 与 TUI 在同一进程内
```

### 2.2 Serve 模式

```bash
opencode serve [--port 4096]
# 只启动 HTTP Server，不启动 TUI
# 供外部客户端（Web 前端、SDK）连接
```

### 2.3 Run 模式（非交互）

```bash
opencode run "请帮我重构 src/utils.ts"
# 非交互式执行单条指令
# 完成后退出
```

---

## 3. 完整命令列表

| 命令 | 说明 |
|------|------|
| `opencode` | 启动交互模式（Server + TUI） |
| `opencode serve` | 仅启动 HTTP Server |
| `opencode run <prompt>` | 非交互式执行单条指令 |
| `opencode session list` | 列出所有 Session |
| `opencode session get <id>` | 获取 Session 详情 |
| `opencode session remove <id>` | 删除 Session |
| `opencode session compact <id>` | 压缩 Session |
| `opencode session share <id>` | 分享 Session |
| `opencode attach <id>` | 附加到运行中的 Server |
| `opencode providers` | 列出所有 Provider 及状态 |
| `opencode models` | 列出所有可用模型 |
| `opencode auth <provider>` | 为 Provider 进行 OAuth 认证 |
| `opencode auth remove <provider>` | 删除 Provider 认证 |
| `opencode mcp list` | 列出 MCP Server |
| `opencode mcp add` | 交互式添加 MCP Server |
| `opencode mcp remove <name>` | 删除 MCP Server |
| `opencode export <session>` | 导出 Session 为 Markdown |
| `opencode import <file>` | 导入 Session |
| `opencode plugin list` | 列出已安装插件 |
| `opencode plugin add <name>` | 安装插件 |
| `opencode acp` | ACP（Agent Communication Protocol）服务 |
| `opencode github pr` | GitHub PR 集成 |
| `opencode db` | 数据库管理工具（调试用） |
| `opencode debug` | 调试信息输出 |

---

## 4. 启动流程

### 4.1 交互模式启动

```typescript
// packages/opencode/src/index.ts
async function main() {
  // 1. 解析 CLI 参数
  const args = await yargs(process.argv.slice(2)).parse()

  // 2. 初始化 Effect Runtime
  const runtime = await createRuntime({
    flags: RuntimeFlags.fromArgs(args),
  })

  // 3. 启动 HTTP Server
  const server = await runtime.run(Server.start({
    port: args.port ?? 0,    // 0 = 随机端口
  }))

  // 4. 写入 server.json（端口等信息）
  await writeServerInfo(server.port)

  // 5. 启动 TUI（如果不是 --headless 模式）
  if (!args.headless) {
    const tui = await import("@opencode-ai/tui")
    await tui.start({ serverUrl: `http://localhost:${server.port}` })
  }
}
```

### 4.2 Effect Runtime 初始化

```typescript
// 所有 Effect Service 组装为 Layer
const AppLayer = Layer.mergeAll(
  Database.node,
  Auth.node,
  Config.node,
  Provider.node,
  Agent.node,
  ToolRegistry.node,
  MCP.node,
  Session.node,
  EventV2Bridge.node,
  // ...
)

const runtime = ManagedRuntime.make(AppLayer)
```

---

## 5. RuntimeFlags（运行时标志）

控制功能开关和运行模式：

```typescript
interface RuntimeFlags {
  client: "cli" | "app" | "desktop"  // 客户端类型
  headless: boolean                   // 无 TUI 模式
  
  // 实验性功能
  experimentalWorkspaces: boolean
  experimentalLspTool: boolean
  experimentalPlanMode: boolean
  experimentalCodeMode: boolean
  
  // 功能开关
  enableExa: boolean          // 启用 Exa 搜索
  enableParallel: boolean     // 并行搜索
  enableQuestionTool: boolean // 启用提问工具
}
```

---

## 6. run 命令实现

非交互模式执行：

```typescript
opencode run "请帮我添加单元测试" [options]

// 选项
--model anthropic/claude-sonnet-4-5   // 指定模型
--agent build                          // 指定 Agent
--session <id>                         // 附加到已有 Session
--no-auto-share                        // 不自动分享结果
```

```typescript
async function runCommand(prompt: string, opts) {
  // 1. 创建或获取 Session
  const session = opts.session
    ? await Session.get(opts.session)
    : await Session.create({ agent: opts.agent, model: opts.model })

  // 2. 发送消息
  await Session.prompt(session.id, { prompt: { type: "text", text: prompt } })

  // 3. 等待完成（订阅 SSE 直到 session.idle 事件）
  await Session.wait(session.id)

  // 4. 输出结果到 stdout
  const messages = await Session.messages(session.id)
  printLastAssistantMessage(messages)
}
```

---

## 7. serve 命令

```bash
opencode serve --port 4096 --hostname 0.0.0.0

# 选项
--port <n>        监听端口（默认 4096）
--hostname <h>    监听地址（默认 localhost）
--no-mdns         禁用 MDNS 服务发现
```

Serve 模式适用于：
- 作为后台服务运行（systemd 等）
- 供多个客户端（TUI、Web、SDK）同时连接
- CI/CD 环境中提供 AI 能力

---

## 8. attach 命令

附加到已运行的 Server：

```bash
opencode attach [server-url]

# 不指定 URL 时，读取 ~/.local/share/opencode/server.json
# 获取本机运行的 Server 端口
```

---

## 9. 进程信号处理

```typescript
// 优雅关闭
process.on("SIGTERM", async () => {
  // 1. 停止接受新连接
  // 2. 等待活跃 Session 完成（或超时）
  // 3. 关闭数据库连接
  // 4. 退出
})

process.on("SIGINT", async () => {
  // Ctrl+C：中断当前运行的 Session，然后优雅关闭
})
```

---

## 10. 日志系统

```typescript
// Effect.logInfo/logWarning/logError
// 日志格式：结构化 JSON

// 日志级别控制
OPENCODE_LOG=debug opencode serve

// 日志文件
~/.local/share/opencode/logs/opencode-<date>.log
```
