# 01 产品概述与架构总览

## 1. 产品定位

opencode 是一款 AI 驱动的命令行开发工具，核心定位是：

- 通过 LLM（大语言模型）与开发者协作完成代码编写、重构、调试等任务
- 支持多 AI Provider（Anthropic、OpenAI、Google、AWS Bedrock 等 30+），用户自由切换
- 提供 TUI（终端 UI）和 HTTP API 两种交互界面
- 通过 MCP（Model Context Protocol）扩展工具能力
- 全本地运行，数据存储在本地 SQLite，保护代码隐私

---

## 2. 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                        用户交互层                            │
│   CLI (yargs)    TUI (SolidJS+opentui)    HTTP API Client   │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                    packages/opencode (Server 层)             │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │ Session  │  │  Agent   │  │  Tool    │  │  Provider │  │
│  │ Manager  │  │  System  │  │ Registry │  │  Adapter  │  │
│  └──────────┘  └──────────┘  └──────────┘  └───────────┘  │
│                                                             │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │   MCP    │  │  Auth    │  │  Config  │  │   HTTP    │  │
│  │ Manager  │  │ Service  │  │ Service  │  │  Server   │  │
│  └──────────┘  └──────────┘  └──────────┘  └───────────┘  │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                    packages/core (Core 层)                   │
│                                                             │
│  Database(Drizzle/SQLite)  Effect Services  Schema Types   │
└────────────────────────┬────────────────────────────────────┘
                         │
┌────────────────────────▼────────────────────────────────────┐
│                   packages/schema (Schema 层)                │
│                                                             │
│  Effect Schema 类型定义  Session/Message/Provider/Agent 等  │
└─────────────────────────────────────────────────────────────┘
```

---

## 3. Monorepo 包结构

项目使用 Bun workspace + pnpm catalog 管理，共 30+ 个包：

### 核心包

| 包名 | 路径 | 职责 |
|------|------|------|
| `opencode` | `packages/opencode` | 主程序：CLI、HTTP Server、Session、Tool、Agent、Provider |
| `@opencode-ai/core` | `packages/core` | 核心服务层：Database、Effect 服务、Session V2 执行引擎 |
| `@opencode-ai/schema` | `packages/schema` | 共享 Effect Schema 类型定义（Session、Message、Provider 等） |
| `@opencode-ai/protocol` | `packages/protocol` | HTTP API 协议定义（Effect HttpApi 路由声明） |

### 前端包

| 包名 | 路径 | 职责 |
|------|------|------|
| `@opencode-ai/tui` | `packages/tui` | 终端 UI，SolidJS + opentui 渲染器 |
| `@opencode-ai/app` | `packages/app` | Web 前端（React/SolidJS） |
| `@opencode-ai/session-ui` | `packages/session-ui` | Session 对话 UI 组件库 |
| `@opencode-ai/desktop` | `packages/desktop` | Tauri 桌面应用 |

### 扩展包

| 包名 | 路径 | 职责 |
|------|------|------|
| `@opencode-ai/plugin` | `packages/plugin` | Plugin 系统 API |
| `@opencode-ai/sdk` | `packages/sdk/js` | JS/TS SDK（面向外部调用方） |
| `sdk-next` | `packages/sdk-next` | 下一代 SDK（组合 Client + Core + Server） |
| `@opencode-ai/llm` | `packages/llm` | LLM 流式接口封装 |

### 工具包

| 包名 | 路径 | 职责 |
|------|------|------|
| `@opencode-ai/core` | `packages/core` | Effect 工具：LayerNode、serviceUse、EffectBridge |
| GitHub Action | `github/` | CI/CD GitHub Action |
| VSCode Extension | `sdks/vscode/` | VSCode 扩展插件 |

---

## 4. 技术栈

| 层次 | 技术选型 | 说明 |
|------|----------|------|
| 运行时 | Bun / Node.js | 主运行时 Bun，riscv64 降级 Node.js |
| 语言 | TypeScript | 全栈 TypeScript，Effect-TS 函数式风格 |
| 副作用管理 | Effect-TS | 所有副作用、依赖注入、错误处理 |
| 数据库 | SQLite + Drizzle ORM | 本地文件数据库，类型安全 ORM |
| HTTP 框架 | Effect HttpApi + Hono | 协议定义与服务器实现 |
| AI SDK | Vercel AI SDK v4 | 统一 LLM 调用接口，支持流式 |
| TUI | opentui + SolidJS | 终端 UI 框架 |
| 包管理 | Bun workspace + pnpm catalog | Monorepo 包管理 |
| 序列化 | Effect Schema | 运行时类型校验与序列化 |

---

## 5. 包依赖规则

依赖方向严格单向，不允许循环依赖：

```
schema  ──→  core  ──→  opencode (server)
  └──────────────→  opencode (server)
  └──→  protocol  ──→  opencode (server)

client runtime: 可依赖 schema、protocol，不能依赖 core、server
sdk-next: 组合 client + core + server
```

---

## 6. 数据流向

```
用户输入 (CLI/TUI/HTTP)
    │
    ▼
Session.prompt()          ← 持久化 session_input 行
    │
    ▼
SessionExecution.wake()   ← 调度执行器
    │
    ▼
SessionRunner.run()       ← 加载历史、选择模型
    │
    ▼
Provider.llm.stream()     ← 调用 LLM API（流式）
    │
    ▼
Tool.execute()            ← 工具调用（read/write/shell/mcp 等）
    │
    ▼
Event 发布               ← 实时推送给客户端（SSE/WebSocket）
    │
    ▼
Database 持久化          ← session_message、part 写入 SQLite
```
