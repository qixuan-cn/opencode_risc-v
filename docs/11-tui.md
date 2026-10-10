# 11 TUI 前端设计

## 1. 概述

TUI（Terminal User Interface）是 opencode 的终端交互界面，基于 SolidJS + opentui 渲染器构建，实现了完整的终端 UI 框架，包括多路由视图、命令面板、权限确认对话框、实时事件驱动等。

---

## 2. 技术栈

| 组件 | 技术 | 说明 |
|------|------|------|
| UI 框架 | SolidJS | 响应式 UI，细粒度更新 |
| 渲染器 | opentui | 终端 Unicode 渲染，支持颜色、布局 |
| 状态管理 | SolidJS Signal/Store | 响应式状态 |
| 路由 | 自定义路由系统 | 支持多视图切换 |
| 事件通信 | HTTP SSE | 与 Server 的实时通信 |
| 快捷键 | `@opentui/keymap` | 终端键盘事件映射 |

---

## 3. Context 体系

TUI 通过 SolidJS Context 实现依赖注入，主要 Context：

```typescript
// packages/tui/src/context/
├── sdk.tsx          ← HTTP API Client（与 Server 通信）
├── route.tsx        ← 当前路由状态
├── theme.tsx        ← 主题（颜色、样式）
├── sync.tsx         ← 状态同步（Server ↔ TUI）
├── project.tsx      ← 当前项目信息
└── permission.tsx   ← 权限请求队列
```

### 3.1 SDK Context

```typescript
interface SDKContext {
  // HTTP API 客户端
  session: {
    list: (query: SessionsQuery) => Promise<SessionsResponse>
    create: (input: CreateInput) => Promise<Session.Info>
    get: (id: SessionID) => Promise<Session.Info>
    prompt: (id: SessionID, input: PromptInput) => Promise<Admitted>
    // ...
  }
  provider: {
    list: () => Promise<Provider.Info[]>
  }
  // 实时事件订阅
  subscribe: (sessionID: string, onEvent: (event) => void) => () => void
}
```

### 3.2 Sync Context

负责将 Server 推送的 SSE 事件同步到本地 SolidJS 状态：

```typescript
// 订阅当前 Session 的实时事件
const unsub = sdk.subscribe(sessionID, (event) => {
  switch (event.type) {
    case "message.part.updated":
      // 更新消息内容（流式文本）
      setMessages(prev => [...])
    case "session.updated":
      // 更新 Session 元数据
      setCurrentSession(event.data)
    case "permission.request":
      // 加入权限请求队列
      setPermissionQueue(prev => [...prev, event.data])
  }
})
```

### 3.3 Permission Context

管理权限确认对话框队列：

```typescript
interface PermissionContext {
  queue: PermissionRequest[]    // 待确认队列
  respond: (id: string, action: "allow" | "deny" | "always") => void
}

// 权限请求来自 SSE 事件
// UI 显示模态对话框等待用户确认
// 响应通过 POST /api/permission/:sessionID/respond
```

---

## 4. 路由系统

```typescript
// packages/tui/src/context/route.tsx
type Route =
  | { name: "home" }                           // 首页（Session 列表）
  | { name: "session"; id: SessionID }         // Session 对话视图
  | { name: "session.new" }                    // 新建 Session
  | { name: "plugin"; id: string }             // 插件视图

// 路由切换
navigate({ name: "session", id: sessionID })
```

---

## 5. 主要组件结构

```
App (packages/tui/src/app.tsx)
├── ThemeProvider
├── SDKProvider
├── ProjectProvider
├── SyncProvider
├── PermissionProvider
│
├── Router
│   ├── HomeView
│   │   ├── SessionList（Session 列表）
│   │   ├── NewSessionInput（新建输入框）
│   │   └── SidebarProviders（Provider 状态）
│   │
│   ├── SessionView
│   │   ├── MessageList（消息列表）
│   │   │   ├── UserMessage
│   │   │   ├── AssistantMessage
│   │   │   │   ├── TextPart（流式文本）
│   │   │   │   ├── ToolCallPart（工具调用）
│   │   │   │   ├── ToolResultPart（工具结果）
│   │   │   │   └── ReasoningPart（推理过程）
│   │   │   └── LoadingIndicator
│   │   │
│   │   └── InputArea（输入区域）
│   │       ├── TextEditor
│   │       ├── AttachmentBar
│   │       └── StatusBar
│   │
│   └── PluginView
│
├── CommandPalette（命令面板，Ctrl+K）
│   ├── SessionCommands
│   ├── ProviderCommands
│   └── ThemeCommands
│
└── DialogSystem（模态对话框）
    ├── PermissionDialog（权限确认）
    ├── QuestionDialog（AI 提问）
    └── ConfirmDialog（通用确认）
```

---

## 6. 键盘快捷键

由 `@opentui/keymap` 管理，可通过配置文件自定义：

| 快捷键 | 功能 |
|--------|------|
| `Ctrl+K` | 打开命令面板 |
| `Ctrl+C` | 中断当前 AI 执行 |
| `Ctrl+N` | 新建 Session |
| `Ctrl+W` | 关闭当前 Session |
| `↑` / `↓` | 滚动消息列表 |
| `PgUp` / `PgDn` | 快速滚动 |
| `Ctrl+R` | 重新发送上一条消息 |
| `Esc` | 关闭对话框/命令面板 |

---

## 7. 主题系统

```typescript
// packages/tui/src/theme/
interface Theme {
  colors: {
    background: string
    foreground: string
    accent: string
    success: string
    warning: string
    error: string
    muted: string
  }
  // opentui 颜色格式（支持 24-bit 颜色）
}

// 内置主题：dark / light / dracula / catppuccin 等
// 可通过配置文件自定义
```

---

## 8. 流式文本渲染

AI 响应以流式方式推送，TUI 实时渲染：

```typescript
// SSE 事件：message.part.updated
// { partID, content: "累积文本", delta: "新增文字" }

// SolidJS 细粒度更新（只更新变化的文本节点）
const [partContent, setPartContent] = createSignal("")

// 接收到 delta 时追加
setPartContent(prev => prev + event.data.delta)
```

---

## 9. 权限确认 UI

当 AI 调用受限工具时，显示权限确认对话框：

```
┌─────────────────────────────────────────────┐
│  Permission Request                          │
│                                             │
│  The AI wants to execute:                   │
│                                             │
│  bash: rm -rf ./dist/                       │
│                                             │
│  [Allow Once] [Allow Always] [Deny]         │
└─────────────────────────────────────────────┘
```

用户选择后通过 `POST /api/permission/:sessionID/respond` 发送响应。

---

## 10. TUI 启动流程

```typescript
// packages/tui/src/index.tsx
async function main() {
  // 1. 连接到 opencode HTTP Server（读取 server.json 获取端口）
  const serverUrl = await readServerUrl()

  // 2. 健康检查（轮询 /api/health 直到就绪）
  await waitForServer(serverUrl)

  // 3. 初始化 SolidJS 应用
  render(() => (
    <SDKProvider url={serverUrl}>
      <App />
    </SDKProvider>
  ), container)

  // 4. 初始化 opentui 渲染器
  await opentui.init({ fullscreen: true })
}
```

---

## 11. TUI 与 Server 关系

TUI 是 HTTP Client，通过 REST API 和 SSE 与 Server 通信：

```
TUI (packages/tui)          Server (packages/opencode)
        │                              │
        │  GET /api/session            │
        │ ──────────────────────────→  │
        │                              │
        │  POST /api/session/:id/prompt│
        │ ──────────────────────────→  │
        │                              │
        │  GET /api/session/:id/event  │
        │ ←────────── SSE stream ────  │
        │  (实时事件推送)               │
        │                              │
        │  POST /api/permission/respond│
        │ ──────────────────────────→  │
```

TUI 本身不包含业务逻辑，所有计算都在 Server 侧。
