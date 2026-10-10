# 05 AI Provider 集成设计

## 1. 概述

Provider 系统是 opencode 与各 LLM 服务对接的核心层，基于 Vercel AI SDK v4 构建，统一抽象了 30+ AI 服务商。

---

## 2. Provider 层次结构

```
用户配置 / 环境变量
        │
        ▼
Provider.Service（Effect Service）
  ├── 配置解析（Config + Auth + Env）
  ├── SDK 实例化（Bundled SDKs / 动态加载）
  ├── 模型发现（models.dev 目录 + 自定义）
  └── 模型选择（fuzzysort 模糊匹配）
        │
        ▼
Vercel AI SDK（统一 LLM 调用接口）
        │
        ▼
各 Provider API（Anthropic/OpenAI/Google/Bedrock 等）
```

---

## 3. 内置 Provider 列表

代码：`packages/opencode/src/provider/provider.ts` 中 `BUNDLED_PROVIDERS`

| Provider ID | SDK 包 | 说明 |
|-------------|--------|------|
| `anthropic` | `@ai-sdk/anthropic` | Claude 系列 |
| `openai` | `@ai-sdk/openai` | GPT 系列、o 系列 |
| `google` | `@ai-sdk/google` | Gemini 系列 |
| `google-vertex` | `@ai-sdk/google-vertex` | Vertex AI（GCP） |
| `google-vertex-anthropic` | `@ai-sdk/google-vertex/anthropic` | Vertex 上的 Claude |
| `amazon-bedrock` | `@ai-sdk/amazon-bedrock` | AWS Bedrock |
| `amazon-bedrock-mantle` | `@ai-sdk/amazon-bedrock/mantle` | Bedrock Mantle API |
| `azure` | `@ai-sdk/azure` | Azure OpenAI |
| `openrouter` | `@openrouter/ai-sdk-provider` | OpenRouter 聚合 |
| `xai` | `@ai-sdk/xai` | xAI（Grok） |
| `mistral` | `@ai-sdk/mistral` | Mistral AI |
| `groq` | `@ai-sdk/groq` | Groq（超快推理） |
| `deepinfra` | `@ai-sdk/deepinfra` | DeepInfra |
| `cerebras` | `@ai-sdk/cerebras` | Cerebras |
| `cohere` | `@ai-sdk/cohere` | Cohere |
| `togetherai` | `@ai-sdk/togetherai` | Together AI |
| `perplexity` | `@ai-sdk/perplexity` | Perplexity |
| `vercel` | `@ai-sdk/vercel` | Vercel AI Gateway |
| `alibaba` | `@ai-sdk/alibaba` | 阿里云百炼 |
| `gitlab` | `gitlab-ai-provider` | GitLab Duo |
| `github-copilot` | `@ai-sdk/github-copilot`（内部） | GitHub Copilot |
| `venice` | `venice-ai-sdk-provider` | Venice AI |
| `cloudflare-workers-ai` | 自定义 | Cloudflare Workers AI |
| `cloudflare-ai-gateway` | `ai-gateway-provider` | Cloudflare AI Gateway |
| `sap-ai-core` | 自定义 | SAP AI Core |
| `openai-compatible` | `@ai-sdk/openai-compatible` | 兼容 OpenAI 接口的任意服务 |

---

## 4. Provider Info 数据结构

```typescript
interface Provider.Info {
  id: ProviderV2.ID        // Provider 唯一标识，如 "anthropic"
  name: string             // 显示名称
  env: string[]            // 所需环境变量列表
  models: Record<string, Model>  // 模型字典
  source: "catalog" | "config" | "detected"  // 来源
  options?: {              // 可选配置
    baseURL?: string       // 自定义 API 端点
    apiKey?: string
    headers?: Record<string, string>
    [key: string]: unknown
  }
}
```

---

## 5. 模型数据结构

```typescript
interface Provider.Model {
  id: ModelV2.ID           // 模型 ID，如 "claude-sonnet-4-5"
  name: string             // 显示名称
  providerID: ProviderV2.ID
  attachment?: boolean     // 是否支持附件（图片、PDF）
  contextWindow: number    // 上下文窗口大小（token 数）
  cost?: {
    input: number          // 每百万 input token 价格（美元）
    output: number         // 每百万 output token 价格（美元）
    cache?: { read: number; write: number }
  }
  capabilities: {
    temperature: boolean
    reasoning: boolean     // 是否支持推理模式（o1/o3/Claude think）
    attachment: boolean
    toolcall: boolean      // 是否支持 tool calling
    input: { text: boolean; audio: boolean; image: boolean; video: boolean; pdf: boolean }
    output: { text: boolean; audio: boolean; image: boolean; video: boolean; pdf: boolean }
    interleaved: boolean   // 是否支持交错多模态
  }
  release_date: string
  variants: Record<string, unknown>
}
```

---

## 6. Provider 鉴权解析流程

每个 Provider 在 `CustomLoader` 中实现自己的鉴权解析逻辑，统一的依赖注入接口：

```typescript
type CustomDep = {
  auth: (id: string) => Effect.Effect<Auth.Info | undefined>
  config: () => Effect.Effect<ConfigV1.Info>
  env: () => Effect.Effect<Record<string, string | undefined>>
  get: (key: string) => Effect.Effect<string | undefined>
}
```

**典型示例（Anthropic）：**
```typescript
// 1. 优先读取环境变量
const apiKey = env["ANTHROPIC_API_KEY"]
              || auth?.type === "api" ? auth.key : undefined

// 2. 返回 autoload: false 表示配置不完整，不自动加载
if (!apiKey) return { autoload: false }

// 3. 返回 SDK 配置
return {
  autoload: true,
  options: { apiKey }
}
```

**Google Vertex（复杂鉴权）：**
```typescript
// 多环境变量回退
const project = env["GOOGLE_VERTEX_PROJECT"]
              ?? env["GOOGLE_CLOUD_PROJECT"]
              ?? env["GCP_PROJECT"]

// 使用 Google Auth Library 获取 ADC token
const auth = new GoogleAuth({ scopes: [...] })
const token = await auth.getClient().getAccessToken()

// 注入 Authorization header
options.fetch = async (input, init) => {
  const headers = new Headers(init?.headers)
  headers.set("Authorization", `Bearer ${token}`)
  return fetch(input, { ...init, headers })
}
```

---

## 7. 模型发现机制

### 7.1 models.dev 目录

opencode 使用 [models.dev](https://models.dev) 作为模型目录，定期更新：

```typescript
// packages/core/src/models-dev/index.ts
const ModelsDev = {
  // 获取所有模型（从内置 JSON 文件）
  models: () => Effect.Effect<Record<string, ModelDevEntry>>
}
```

启动时将 models.dev 数据与用户配置合并，生成完整的 Provider/Model 列表。

### 7.2 动态模型发现

部分 Provider 支持动态发现（`discoverModels`）：

```typescript
// Cloudflare Workers AI 动态获取模型列表
async discoverModels() {
  const response = await fetch(
    `https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/models/search`,
    { headers: { "Authorization": `Bearer ${apiKey}` } }
  )
  const data = await response.json()
  // 转换为 Record<string, Model>
}
```

### 7.3 模糊搜索

用户输入模型名时使用 `fuzzysort` 进行模糊匹配：

```typescript
// 支持不完整名称匹配
// "sonnet" → "claude-sonnet-4-5"
// "gpt4" → "gpt-4o"
const results = fuzzysort.go(query, modelIds, { threshold: -1000 })
```

---

## 8. LLM 调用流程

核心调用在 `SessionRunner` 中，使用 Vercel AI SDK 的 `streamText`：

```typescript
const result = streamText({
  model: providerSDK.languageModel(modelID),
  messages: conversationHistory,
  tools: toolDefinitions,
  system: agentSystemPrompt,
  temperature: agent.temperature,
  topP: agent.topP,
  maxSteps: agent.steps ?? 100,       // 最大工具调用步数
  abortSignal: interruptSignal,
})

// 处理流式响应
for await (const chunk of result.fullStream) {
  switch (chunk.type) {
    case "text-delta":        // 文本增量
    case "tool-call":         // 工具调用请求
    case "tool-result":       // 工具执行结果
    case "reasoning":         // 推理过程（o1/Claude think）
    case "finish":            // 完成，含 usage 统计
  }
}
```

---

## 9. SSE 超时处理

对于 SSE（Server-Sent Events）流，opencode 实现了自定义超时保护：

```typescript
function wrapSSE(res: Response, ms: number, ctl: AbortController) {
  // 拦截 SSE 响应的 ReadableStream
  // 每次 read 操作设置定时器
  // 超过 ms 毫秒没有数据则 abort
  const id = setTimeout(() => {
    ctl.abort(new ProviderError.ResponseStreamError("SSE read timed out"))
  }, ms)
  // ...
}

// 默认超时：5 分钟
const OPENAI_HEADER_TIMEOUT_DEFAULT = 300_000
```

---

## 10. Token 计费统计

每次 LLM 调用后统计 token 使用量和费用：

```typescript
const usage = {
  inputTokens,
  outputTokens,
  reasoningTokens,
  cacheReadInputTokens,    // Anthropic prompt cache
  cacheWriteInputTokens,
}

// AI SDK v6 已将缓存 token 计入 inputTokens
// 需要减去缓存 token 避免重复计算
const adjustedInputTokens = inputTokens - cacheReadTokens - cacheWriteTokens

// 费用计算
const cost = (adjustedInput / 1_000_000) * model.cost.input
           + (output / 1_000_000) * model.cost.output
           + (cacheRead / 1_000_000) * model.cost.cache.read
           + (cacheWrite / 1_000_000) * model.cost.cache.write

// 累计到 session 表
await db.update(SessionTable).set({
  cost: sql`${SessionTable.cost} + ${cost}`,
  tokens_input: sql`${SessionTable.tokens_input} + ${adjustedInput}`,
  // ...
})
```

---

## 11. Provider 变换层（Transform）

代码：`packages/opencode/src/provider/transform.ts`

在原始 Provider SDK 和调用层之间插入变换，用于：

- 注入自定义 HTTP headers（User-Agent、billing 标识等）
- 添加请求拦截（日志、监控）
- 模型 ID 映射（如 Cloudflare AI Gateway 的 `anthropic/claude-haiku-4.5` → `claude-haiku-4-5`）

---

## 12. 自定义 Provider（插件扩展）

用户可通过配置文件添加自定义 Provider：

```yaml
# ~/.config/opencode/config.yaml
provider:
  my-provider:
    npm: "my-ai-sdk-package"     # npm 包名
    options:
      apiKey: "${MY_API_KEY}"
      baseURL: "https://api.example.com"
    models:
      my-model:
        name: "My Custom Model"
        contextWindow: 128000
```

opencode 在运行时动态 `import()` npm 包，无需重启。
