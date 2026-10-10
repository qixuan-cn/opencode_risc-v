# 08 HTTP API 设计

## 1. 概述

opencode 的 HTTP API 基于 Effect HttpApi 框架构建，提供类型安全的 REST + SSE 接口，供 TUI、Web 前端、SDK 和外部工具调用。API 定义集中在 `packages/protocol/src/` 包中，实现在 `packages/opencode/src/server/` 包中。

---

## 2. API 架构

```
packages/protocol/src/api.ts        ← 根 API 定义（组装所有 Group）
    │
    ├── groups/session.ts           ← Session CRUD + 执行控制
    ├── groups/message.ts           ← 消息查询
    ├── groups/provider.ts          ← Provider/模型管理
    ├── groups/model.ts             ← 模型查询
    ├── groups/agent.ts             ← Agent 管理
    ├── groups/auth.ts              ← 认证管理（已重命名为 credential）
    ├── groups/credential.ts        ← 凭据管理
    ├── groups/integration.ts       ← 集成管理
    ├── groups/event.ts             ← 实时事件流（SSE）
    ├── groups/fs.ts                ← 文件系统操作
    ├── groups/command.ts           ← 自定义命令执行
    ├── groups/skill.ts             ← Skill 管理
    ├── groups/permission.ts        ← 权限查询与确认
    ├── groups/pty.ts               ← 伪终端（PTY）
    ├── groups/question.ts          ← 用户提问响应
    ├── groups/reference.ts         ← Reference 管理
    ├── groups/location.ts          ← 位置服务
    ├── groups/health.ts            ← 健康检查
    └── groups/project-copy.ts      ← 项目复制
```

---

## 3. 全局中间件

API 顶层挂载两个全局中间件：

```typescript
HttpApi.make("server")
  .add(...)
  .middleware(Authorization)          // ① Bearer token 鉴权
  .middleware(SchemaErrorMiddleware)  // ② Effect Schema 错误处理
```

`HealthGroup`（`/api/health`）豁免鉴权中间件。

---

## 4. Session API（核心）

Base path: `/api/session`

| Method | Path | 说明 |
|--------|------|------|
| `GET` | `/api/session` | 列出 Session（分页、搜索、过滤） |
| `POST` | `/api/session` | 创建 Session |
| `GET` | `/api/session/active` | 列出当前运行中的 Session |
| `GET` | `/api/session/:id` | 获取单个 Session |
| `POST` | `/api/session/:id/agent` | 切换 Session 使用的 Agent |
| `POST` | `/api/session/:id/model` | 切换 Session 使用的模型 |
| `POST` | `/api/session/:id/prompt` | 发送消息（准入 + 触发执行） |
| `POST` | `/api/session/:id/compact` | 触发 Session 压缩 |
| `POST` | `/api/session/:id/wait` | 等待 Session 空闲 |
| `POST` | `/api/session/:id/revert/stage` | 暂存撤销点 |
| `POST` | `/api/session/:id/revert/clear` | 清除撤销暂存 |
| `POST` | `/api/session/:id/revert/commit` | 提交撤销 |
| `GET` | `/api/session/:id/context` | 获取 Session 当前上下文消息 |
| `GET` | `/api/session/:id/history` | 获取 Session 历史事件（分页） |
| `GET` | `/api/session/:id/event` | 订阅 Session 实时事件（SSE） |

### 4.1 创建 Session

```
POST /api/session
Content-Type: application/json

{
  "id": "optional-client-provided-id",
  "agent": "build",
  "model": {
    "id": "claude-sonnet-4-5",
    "providerID": "anthropic"
  },
  "location": {
    "directory": "/home/user/project"
  }
}

Response 200:
{
  "data": { ...Session.Info }
}
```

### 4.2 发送消息

```
POST /api/session/:id/prompt
Content-Type: application/json

{
  "id": "optional-message-id",     // 客户端幂等 ID
  "prompt": {
    "type": "text",
    "text": "请帮我重构这个函数",
    "attachments": [               // 可选附件
      { "type": "file", "path": "/src/utils.ts" }
    ]
  },
  "delivery": "steer",             // steer | queue
  "resume": true                   // false = 只准入不执行
}

Response 200:
{
  "data": {
    "id": "01JWXYZ...",
    "seq": 42                      // 准入序号
  }
}
```

**幂等性保证：** 相同 `id` 的重复请求在以下条件下会返回相同结果：
- Session ID 匹配
- prompt 内容匹配
- delivery 模式匹配

### 4.3 实时事件流（SSE）

```
GET /api/session/:id/event?after=0
Accept: text/event-stream

// 响应格式（Server-Sent Events）
data: {"type":"session.updated","data":{...}}

data: {"type":"message.part.updated","data":{...}}

data: {"type":"session.error","data":{"error":"..."}}
```

支持的事件类型：

| 事件类型 | 说明 |
|----------|------|
| `session.updated` | Session 元数据更新 |
| `message.created` | 新消息创建 |
| `message.updated` | 消息内容更新 |
| `message.part.updated` | 消息分片更新（流式文本） |
| `session.error` | 执行错误 |
| `session.idle` | Session 进入空闲状态 |
| `permission.request` | 工具调用权限请求（等待用户确认） |
| `question.created` | AI 向用户提问 |

### 4.4 分页查询

```
GET /api/session?limit=50&order=desc&directory=/home/user/project

Response:
{
  "data": [...],
  "cursor": {
    "previous": "eyJ0eXBlIjoiZGlyZWN0b3J5...",   // 更新数据
    "next": "eyJ0eXBlIjoiZGlyZWN0b3J5..."         // 更旧数据
  }
}

// 翻页
GET /api/session?cursor=eyJ0eXBlIjoiZGlyZWN0b3J5...
```

---

## 5. Provider / Model API

| Method | Path | 说明 |
|--------|------|------|
| `GET` | `/api/provider` | 列出所有 Provider（含状态） |
| `GET` | `/api/provider/:id` | 获取单个 Provider 详情 |
| `GET` | `/api/model` | 列出所有模型 |
| `GET` | `/api/model/:providerID/:modelID` | 获取单个模型详情 |

---

## 6. Agent API

| Method | Path | 说明 |
|--------|------|------|
| `GET` | `/api/agent` | 列出所有 Agent |
| `GET` | `/api/agent/:name` | 获取单个 Agent 详情 |
| `POST` | `/api/agent/generate` | 使用 LLM 生成新 Agent 定义 |

---

## 7. 权限 API

| Method | Path | 说明 |
|--------|------|------|
| `GET` | `/api/permission` | 列出已持久化的权限规则 |
| `POST` | `/api/permission/:sessionID/respond` | 响应权限询问（allow/deny/always） |

---

## 8. 文件系统 API

| Method | Path | 说明 |
|--------|------|------|
| `GET` | `/api/fs/list` | 列目录 |
| `GET` | `/api/fs/read` | 读文件 |
| `GET` | `/api/fs/diff` | 获取文件 diff |

---

## 9. PTY API（伪终端）

| Method | Path | 说明 |
|--------|------|------|
| `POST` | `/api/pty` | 创建 PTY 会话 |
| `POST` | `/api/pty/:id/input` | 发送键盘输入 |
| `GET` | `/api/pty/:id/output` | 接收终端输出（SSE） |
| `DELETE` | `/api/pty/:id` | 关闭 PTY |

---

## 10. 健康检查

```
GET /api/health

Response 200:
{
  "ok": true,
  "version": "1.18.23"
}
```

无需鉴权，客户端启动前轮询此接口等待 Server 就绪。

---

## 11. 错误格式

所有错误统一通过 `SchemaErrorMiddleware` 处理，响应格式：

```json
{
  "error": {
    "type": "SessionNotFoundError",
    "message": "Session not found: 01JWXYZ...",
    "_tag": "SessionNotFoundError"
  }
}
```

错误类型定义（`packages/protocol/src/errors.ts`）：

| 错误类型 | HTTP 状态码 | 说明 |
|----------|-------------|------|
| `SessionNotFoundError` | 404 | Session 不存在 |
| `MessageNotFoundError` | 404 | 消息不存在 |
| `ConflictError` | 409 | 资源冲突（重复 ID 等） |
| `InvalidRequestError` | 400 | 请求参数无效 |
| `InvalidCursorError` | 400 | 分页游标无效 |
| `ServiceUnavailableError` | 503 | 服务不可用 |
| `UnknownError` | 500 | 未知错误 |

---

## 12. HTTP Server 实现

代码：`packages/opencode/src/server/server.ts`

```typescript
// 服务器启动流程
const app = HttpApp.make(api, {
  // Effect HttpApi 路由处理器
})

// Node.js HTTP Server（通过 Effect NodeHttpServer）
const server = NodeHttpServer.make(app, {
  port: config.port ?? 0,    // port=0 表示随机端口
})

// MDNS 服务发现（局域网内自动发现）
MDNS.advertise({
  name: "opencode",
  port: actualPort,
})

// WebSocket 跟踪
// 优雅关闭（等待活跃连接断开）
```

**端口策略：**
- `serve` 命令：默认 port 4096，若占用则递增
- `run` 命令：随机端口（仅 TUI 连接）
- 端口写入 `~/.local/share/opencode/server.json`，客户端读取此文件连接

---

## 13. OpenAPI 规范

所有 API 端点自动生成 OpenAPI 3.0 文档：

```typescript
// 通过 @effect/platform HttpApi 自动生成
// 可通过以下接口获取
GET /api/openapi.json
```

每个端点都有 `identifier`（格式：`v2.resource.action`），例如：
- `v2.session.list`
- `v2.session.prompt`
- `v2.provider.list`
