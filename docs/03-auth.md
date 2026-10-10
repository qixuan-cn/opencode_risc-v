# 03 用户鉴权设计

## 1. 鉴权体系概述

opencode 的鉴权分为两个完全独立的层次：

| 层次 | 说明 | 存储位置 |
|------|------|----------|
| **AI Provider 鉴权** | 用于调用 LLM API（OpenAI、Anthropic 等）的凭据管理 | `~/.local/share/opencode/auth.json` |
| **HTTP API 鉴权** | 保护 opencode 自身 HTTP Server 不被未授权访问 | 启动时生成，存储在 `~/.local/share/opencode/` |

---

## 2. AI Provider 鉴权

### 2.1 凭据类型

代码定义于 `packages/opencode/src/auth/index.ts`，支持三种凭据类型：

#### OAuth（OAuth 2.0）
```typescript
class Oauth {
  type: "oauth"
  refresh: string      // refresh token
  access: string       // access token
  expires: number      // 过期时间（Unix 毫秒）
  accountId?: string   // 账号 ID（如 Cloudflare Account ID）
  enterpriseUrl?: string // 企业版 URL（GitHub Enterprise 等）
}
```
适用场景：GitHub Copilot、GitLab、Cloudflare（OAuth 认证流程）

#### API Key
```typescript
class Api {
  type: "api"
  key: string                              // API Key 明文
  metadata?: Record<string, string>        // 附加元数据（如 accountId）
}
```
适用场景：Anthropic、OpenAI、Google AI、AWS Bedrock 等大多数 Provider

#### WellKnown Token
```typescript
class WellKnown {
  type: "wellknown"
  key: string    // 密钥标识
  token: string  // token 值
}
```
适用场景：opencode 自身的托管服务鉴权

### 2.2 凭据存储

**存储文件：** `~/.local/share/opencode/auth.json`

文件格式（JSON）：
```json
{
  "anthropic": {
    "type": "api",
    "key": "sk-ant-..."
  },
  "openai": {
    "type": "api",
    "key": "sk-..."
  },
  "github-copilot": {
    "type": "oauth",
    "refresh": "...",
    "access": "...",
    "expires": 1720000000000
  }
}
```

**文件权限：** `0o600`（仅所有者可读写）

**环境变量覆盖：** 设置 `OPENCODE_AUTH_CONTENT` 环境变量可完全覆盖文件内容（适用于 CI/容器环境）：
```bash
export OPENCODE_AUTH_CONTENT='{"anthropic":{"type":"api","key":"sk-ant-..."}}'
```

### 2.3 Auth Service 接口

```typescript
interface Auth.Interface {
  // 获取指定 Provider 的凭据
  get: (providerID: string) => Effect.Effect<Auth.Info | undefined, AuthError>
  // 获取所有凭据
  all: () => Effect.Effect<Record<string, Auth.Info>, AuthError>
  // 保存凭据（写入文件，权限 0o600）
  set: (key: string, info: Auth.Info) => Effect.Effect<void, AuthError>
  // 删除凭据
  remove: (key: string) => Effect.Effect<void, AuthError>
}
```

**键名规范化：** 保存时自动去除尾部 `/`，防止重复存储。

### 2.4 Provider 鉴权解析顺序

对于每个 AI Provider，鉴权信息按以下优先级解析（以 OpenAI 为例）：

```
1. 环境变量（如 OPENAI_API_KEY）
2. auth.json 中存储的凭据
3. Provider 配置文件中的 options.apiKey
4. 未找到 → 标记为 autoload: false，不自动加载
```

### 2.5 OAuth 流程

部分 Provider（GitHub Copilot、GitLab、Cloudflare）使用 OAuth 2.0 授权码流程：

```
用户执行 opencode auth <provider>
        │
        ▼
浏览器打开 Provider 授权页面
        │
        ▼
用户授权 → 回调到 localhost:<port>/callback
        │
        ▼
获取 authorization_code
        │
        ▼
换取 access_token + refresh_token
        │
        ▼
Auth.set(providerID, { type: "oauth", ... }) 写入 auth.json
```

**Token 刷新：** Provider Adapter 在调用前检查 `expires` 字段，若即将过期则自动使用 `refresh_token` 换取新 token，并更新 `auth.json`。

---

## 3. HTTP API 鉴权

### 3.1 鉴权中间件

代码定义于 `packages/protocol/src/middleware/authorization.ts`：

```typescript
export const Authorization = HttpApiMiddleware.make(Authorization)
```

HTTP Server 在所有 API 路由上挂载 `Authorization` 中间件（定义于 `packages/protocol/src/api.ts`）：

```typescript
HttpApi.make("server")
  .add(...)
  .middleware(Authorization)   // ← 全局鉴权中间件
  .middleware(SchemaErrorMiddleware)
```

### 3.2 Token 生成与传递

opencode HTTP Server 启动时生成一个随机 token，客户端（TUI、SDK）通过以下方式传递：

- **HTTP Header：** `Authorization: Bearer <token>`
- **查询参数：** 部分 SSE 端点支持 `?token=<token>`（浏览器 EventSource 不支持自定义 header）

### 3.3 健康检查豁免

`HealthGroup`（`/api/health`）不挂载 `Authorization` 中间件，可无鉴权访问，用于客户端检测 Server 是否就绪。

---

## 4. MCP Server 鉴权

MCP（Model Context Protocol）服务器支持独立的 OAuth 流程，代码在 `packages/opencode/src/mcp/oauth-provider.ts`：

### 4.1 OAuth 流程

```
MCP 服务器返回 401 Unauthorized
        │
        ▼
opencode 启动 OAuth 流程
  - 创建临时 HTTP 服务器监听回调
  - 生成 PKCE code_verifier + code_challenge
        │
        ▼
打开浏览器 → 用户在 MCP Server 授权
        │
        ▼
回调到 localhost:<port>/oauth/callback
  (路径常量: OAUTH_CALLBACK_PATH = "/oauth/callback")
        │
        ▼
用 authorization_code + code_verifier 换取 token
        │
        ▼
Auth.set(`mcp:${serverName}`, token) 存储凭据
        │
        ▼
重新连接 MCP 服务器（携带 Bearer token）
```

### 4.2 Client Registration

部分 MCP Server 要求先进行 Dynamic Client Registration（RFC 7591）：

```
服务器返回 needs_client_registration 状态
        │
        ▼
POST /register → 获取 client_id + client_secret
        │
        ▼
存储 client credentials
        │
        ▼
重新发起 OAuth 授权流程
```

### 4.3 MCP 鉴权状态

```typescript
type MCP.Status =
  | { status: "connected" }
  | { status: "disabled" }
  | { status: "failed"; error: string }
  | { status: "needs_auth" }              // 需要用户完成 OAuth
  | { status: "needs_client_registration"; error: string }
```

---

## 5. 权限控制系统

权限控制独立于鉴权，控制 AI 工具调用能力，详见 [07 Agent 系统设计](./07-agent.md)。

核心类型：

```typescript
// 权限规则
type Rule = {
  permission: string   // read/write/bash/external_directory/webfetch 等
  action: "allow" | "deny" | "ask"
  pattern: string      // glob 模式
}

type Ruleset = Rule[]

// 权限评估
Permission.evaluate(toolName, resource, ruleset) 
// → { action: "allow" | "deny" | "ask" }
```

**权限合并：** 多个 Ruleset 按优先级合并，后面的规则覆盖前面的。

---

## 6. 安全设计要点

| 要点 | 实现方式 |
|------|----------|
| API Key 存储安全 | 文件权限 0o600，不写入数据库 |
| 容器/CI 环境支持 | `OPENCODE_AUTH_CONTENT` 环境变量注入 |
| OAuth Token 刷新 | 自动检测过期并刷新 |
| MCP OAuth | PKCE 流程（防止授权码拦截攻击） |
| 工具调用权限 | 多层权限规则集，支持 ask/allow/deny |
| 敏感文件保护 | 默认规则对 `*.env`、`*.env.*` 设置 ask 权限 |
