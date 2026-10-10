# 09 MCP 集成设计

## 1. 概述

MCP（Model Context Protocol）是 opencode 的工具扩展机制，允许外部服务通过标准协议向 AI 提供额外工具。opencode 作为 MCP Client，可连接多个 MCP Server。

---

## 2. MCP 架构

```
opencode (MCP Client)
    │
    ├── MCP.Service（Effect Service）
    │       ├── 管理多个 MCP Server 连接
    │       ├── 工具列表缓存
    │       └── 连接状态监控
    │
    └── 传输层
            ├── StdioClientTransport    ← 本地进程（最常用）
            ├── SSEClientTransport      ← HTTP SSE（远程）
            └── StreamableHTTPClientTransport ← HTTP 流式（新标准）
```

---

## 3. 连接类型

### 3.1 本地进程（stdio）

```yaml
# config.yaml
mcp:
  my-server:
    type: local
    command: ["npx", "-y", "@modelcontextprotocol/server-filesystem", "/path"]
    env:
      MY_VAR: "value"
    timeout: 30000    # 毫秒
```

启动时 opencode 以子进程方式运行命令，通过 stdin/stdout 进行 JSON-RPC 通信。

### 3.2 远程服务（SSE / HTTP）

```yaml
mcp:
  remote-server:
    type: remote
    url: "https://mcp.example.com"
    headers:
      Authorization: "Bearer ${MY_TOKEN}"
```

自动检测协议：
- 服务器支持 `StreamableHTTP` → 使用 `StreamableHTTPClientTransport`
- 回退到 `SSEClientTransport`（兼容旧版）

---

## 4. MCP.Service 接口

```typescript
interface MCP.Interface {
  // 获取所有 MCP Server 状态
  status: () => Effect.Effect<Record<string, MCP.Status>>

  // 获取所有已连接 Server 的工具定义
  tools: () => Effect.Effect<Record<string, MCPToolDef[]>>

  // 获取所有 MCP Client 实例
  clients: () => Effect.Effect<Record<string, MCPClient>>

  // 获取单个 Server 的工具列表
  toolsForServer: (name: string) => Effect.Effect<MCPToolDef[]>

  // 动态添加 MCP Server
  add: (name: string, config: ConfigMCPV1.Info) => Effect.Effect<MCP.Status>

  // 获取所有 Server 的使用说明（instructions）
  instructions: () => Effect.Effect<ServerInstructions>

  // OAuth 回调处理
  oauthCallback: (serverName: string, code: string, state: string) => Effect.Effect<void>
}
```

---

## 5. 连接状态机

```typescript
type MCP.Status =
  | { status: "connected" }
  | { status: "disabled" }
  | { status: "failed"; error: string }
  | { status: "needs_auth" }
  | { status: "needs_client_registration"; error: string }
```

状态转换：

```
启动
  │
  ▼
连接中（connecting）
  ├── 成功 → connected
  ├── 401 Unauthorized → needs_auth
  ├── Client Registration Required → needs_client_registration
  ├── 配置 enabled=false → disabled
  └── 其他错误 → failed

connected
  └── 连接断开（onclose） → failed，触发 ToolsChanged 事件
```

---

## 6. OAuth 鉴权流程

```
需要 OAuth 的远程 MCP Server：

opencode 检测到 401 / needs_auth
        │
        ▼
创建 McpOAuthProvider（处理 PKCE + 回调）
  - 生成 code_verifier（随机 32 字节）
  - 生成 code_challenge = SHA-256(code_verifier) Base64URL
        │
        ▼
发布 TuiEvent 通知前端（打开浏览器）
  或直接调用 McpBrowser.open(authorizationUrl)
        │
        ▼
用户在浏览器完成授权
        │
        ▼
回调到 http://localhost:<port>/oauth/callback
  (OAUTH_CALLBACK_PATH = "/oauth/callback")
        │
        ▼
提取 code + state
  验证 state 防 CSRF
        │
        ▼
POST /token
  code=<authorization_code>
  code_verifier=<pkce_verifier>
  grant_type=authorization_code
        │
        ▼
获取 { access_token, refresh_token, expires_in }
        │
        ▼
Auth.set(`mcp:${serverName}`, { type: "oauth", ... })
        │
        ▼
用 access_token 重新连接 MCP Server
```

---

## 7. Dynamic Client Registration

部分 MCP Server 要求先注册 OAuth Client（RFC 7591）：

```typescript
// 检测到 needs_client_registration
const response = await fetch(server.registrationEndpoint, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    client_name: "opencode",
    redirect_uris: [`http://localhost:${callbackPort}/oauth/callback`],
    grant_types: ["authorization_code"],
    response_types: ["code"],
    token_endpoint_auth_method: "none",   // PKCE public client
  })
})

const { client_id, client_secret } = await response.json()

// 存储 client credentials
Auth.set(`mcp:${serverName}:client`, { client_id, client_secret })
```

---

## 8. 工具集成

MCP 工具注入到 Tool Registry 的流程：

```typescript
// 1. MCP.Service 获取所有工具
const mcpToolsByServer = await MCP.tools()

// 2. 工具命名空间化
// 原始工具名: "read_file"
// 注入后名称: mcp__my-server__read_file
const toolId = `mcp__${serverName}__${tool.name}`

// 3. 转换为 Tool.Def 格式
const toolDef: Tool.Def = {
  id: toolId,
  description: tool.description,
  parameters: zodSchemaFromJsonSchema(tool.inputSchema),
  execute: async (args) => {
    const result = await mcpClient.callTool({
      name: tool.name,
      arguments: args,
    })
    return { content: result.content }
  }
}
```

---

## 9. 工具列表变更通知

MCP Server 可以通知工具列表发生变化：

```typescript
// 注册 ToolListChanged 通知处理器
client.setNotificationHandler(
  ToolListChangedNotificationSchema,
  async () => {
    // 重新获取工具列表
    const listed = await McpCatalog.defs(client, timeout)
    s.defs[name] = listed

    // 发布事件通知 Tool Registry 更新
    await events.publish(ToolsChanged, { server: name })
  }
)
```

---

## 10. MCP 服务器日志

MCP Server 发送的日志消息会转发到 opencode 日志系统：

```typescript
client.setNotificationHandler(
  LoggingMessageNotificationSchema,
  ({ params }) => {
    // level: debug/info/notice/warning/error/critical/alert/emergency
    switch (params.level) {
      case "debug":   Effect.logDebug("MCP server log", { server, ...params })
      case "warning": Effect.logWarning("MCP server log", { server, ...params })
      // ...
    }
  }
)
```

---

## 11. MCP 目录（McpCatalog）

`packages/opencode/src/mcp/catalog.ts` 管理工具命名规范：

```typescript
// Server 名称消毒（去除特殊字符）
McpCatalog.sanitize("my-server.v2") → "my-server-v2"

// 获取工具定义（带超时保护）
McpCatalog.defs(client, timeout) → MCPToolDef[]
```

---

## 12. 连接断开处理

```typescript
// 监听连接断开事件
client.onclose = () => {
  if (s.clients[name] !== client) return  // 已被新连接替代，忽略

  // 清理连接状态
  delete s.clients[name]
  delete s.defs[name]
  delete s.instructions[name]
  s.status[name] = { status: "failed", error: "Connection closed" }

  // 通知 Tool Registry 工具已失效
  events.publish(ToolsChanged, { server: name })
}
```

---

## 13. MCP Roots 协议

opencode 声明支持 MCP Roots 能力，当 MCP Server 请求工作目录列表时返回：

```typescript
client.setRequestHandler(ListRootsRequestSchema, () => ({
  roots: [
    { uri: pathToFileURL(directory).href }
    // 格式: "file:///home/user/project"
  ]
}))
```
