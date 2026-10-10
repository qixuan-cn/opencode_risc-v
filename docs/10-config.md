# 10 配置系统设计

## 1. 概述

opencode 使用多层次、多源的配置系统，支持全局配置、项目配置、环境变量、远程托管配置等多种来源，按优先级合并。

---

## 2. 配置文件位置

| 优先级 | 位置 | 说明 |
|--------|------|------|
| 1（最低）| `~/.config/opencode/config.yaml` | 用户全局配置 |
| 2 | `<project>/.opencode/config.yaml` | 项目级配置 |
| 3 | 环境变量（`OPENCODE_*`） | 运行时覆盖 |
| 4 | Remote Well-Known（`/.well-known/opencode`） | 远程托管配置 |
| 5（最高）| MDM 托管配置（企业管理） | 企业管理员强制配置 |

---

## 3. 配置文件格式

```yaml
# config.yaml 完整示例
$schema: "https://opencode.ai/config.json"

# 默认使用的 Agent
default_agent: build

# Provider 配置
provider:
  anthropic:
    options:
      apiKey: "${ANTHROPIC_API_KEY}"   # 支持环境变量插值

  # 自定义 OpenAI 兼容接口
  my-ollama:
    npm: "@ai-sdk/openai-compatible"
    options:
      baseURL: "http://localhost:11434/v1"
      apiKey: "ollama"
    models:
      llama3:
        name: "Llama 3"
        contextWindow: 8192

# 默认模型
model: anthropic/claude-sonnet-4-5

# Agent 配置
agent:
  build:
    permission:
      bash: "ask"              # 覆盖默认权限

  reviewer:
    description: "Code reviewer"
    prompt: "You are a code reviewer..."

# 全局权限覆盖（应用到所有 Agent）
permission:
  "*.env": "deny"              # 拒绝读取所有 .env 文件

# MCP Server 配置
mcp:
  filesystem:
    type: local
    command: ["npx", "-y", "@modelcontextprotocol/server-filesystem", "."]

  my-remote-mcp:
    type: remote
    url: "https://mcp.example.com"
    enabled: true

# 扩展 Instructions（追加到系统提示词）
instructions: |
  Always use TypeScript strict mode.
  Prefer functional programming patterns.

# 自动压缩阈值（token 数）
autoshare: false

# Keybindings（仅 TUI）
keybindings:
  leader: "ctrl+x"

# LSP 配置
lsp:
  typescript:
    disabled: false

# Skill 目录
skills: "./my-skills"

# Reference 配置
references:
  api-spec:
    path: "./docs/api.yaml"
    description: "OpenAPI spec"
```

---

## 4. Config Service 接口

```typescript
interface Config.Interface {
  // 获取当前合并后的配置（缓存，监听文件变化自动刷新）
  get: () => Effect.Effect<ConfigV1.Info>

  // 监听配置变化
  watch: () => Stream.Stream<ConfigV1.Info>
}
```

---

## 5. 配置合并策略

```typescript
// 合并顺序（从低到高优先级）
const merged = deepMerge(
  defaultConfig,          // 硬编码默认值
  globalConfig,           // ~/.config/opencode/config.yaml
  projectConfig,          // .opencode/config.yaml
  envConfig,              // OPENCODE_* 环境变量
  remoteConfig,           // /.well-known/opencode
  managedConfig,          // MDM 企业配置
)
```

**深度合并规则：**
- 对象：递归合并
- 数组：后者覆盖前者（不追加）
- 原始值：后者覆盖前者
- `null`：显式清除字段

---

## 6. 环境变量插值

配置值中可使用 `${VAR_NAME}` 语法引用环境变量：

```yaml
provider:
  openai:
    options:
      apiKey: "${OPENAI_API_KEY}"
      baseURL: "${OPENAI_BASE_URL:-https://api.openai.com/v1}"
      # :-后面是默认值
```

插值在配置加载时执行，支持默认值语法 `${VAR:-default}`。

---

## 7. 远程配置（Well-Known）

适用于团队/企业统一配置场景：

```
opencode 启动时检测项目目录
        │
        ▼
解析 Git remote URL（如 https://github.com/org/repo）
        │
        ▼
请求 https://github.com/.well-known/opencode
        │
        ├── 成功 → 解析 JSON/YAML，合并到配置
        └── 失败 → 静默忽略
```

Well-Known 配置通常由团队管理员在 GitHub/GitLab 等平台的根目录维护。

---

## 8. MDM 托管配置（企业）

适用于企业强制管控场景，最高优先级：

```typescript
// 从系统 MDM 读取配置（macOS: /Library/Managed Preferences/）
// Windows: 注册表 HKLM\SOFTWARE\Policies\opencode
// Linux: /etc/opencode/managed-config.yaml
```

MDM 配置的字段无法被用户覆盖，适用于：
- 强制使用内部 Provider
- 禁止特定工具（如 bash）
- 强制连接特定 MCP Server

---

## 9. 配置验证

使用 Effect Schema 进行运行时验证：

```typescript
// packages/core/src/v1/config/config.ts
const ConfigV1 = Schema.Struct({
  default_agent: Schema.optional(Schema.String),
  model: Schema.optional(Schema.String),
  provider: Schema.optional(Schema.Record(...)),
  agent: Schema.optional(Schema.Record(...)),
  permission: Schema.optional(PermissionV1.Config),
  mcp: Schema.optional(Schema.Record(...)),
  instructions: Schema.optional(Schema.String),
  // ...
})
```

配置加载失败时给出友好错误信息，不会导致程序崩溃。

---

## 10. LSP 配置

```yaml
lsp:
  # 启用 TypeScript Language Server
  typescript:
    disabled: false

  # 自定义 LSP
  my-lsp:
    command: ["my-lsp-binary"]
    args: ["--stdio"]
    filetypes: ["myext"]
```

---

## 11. Skills 系统

Skills 是可复用的提示片段，通过 `skill` 工具注入：

```
~/.config/opencode/skills/         ← 全局 skill 目录
<project>/.opencode/skills/        ← 项目 skill 目录
```

每个 skill 是一个 Markdown 文件，AI 可通过 `skill` 工具读取并注入到上下文：

```markdown
<!-- ~/.config/opencode/skills/typescript-best-practices.md -->
# TypeScript Best Practices

Always use strict type annotations.
Prefer interfaces over type aliases for object shapes.
```

---

## 12. References 系统

References 允许将外部文档（API Spec、数据库 Schema 等）注入到 AI 上下文：

```yaml
references:
  api-spec:
    path: "./docs/openapi.yaml"
    description: "REST API specification"
  db-schema:
    path: "./schema.sql"
    description: "Database schema"
```

References 通过 `PluginV2` 系统异步加载，完成后注入到 Agent 的系统上下文。
