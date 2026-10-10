# 04 Session 管理设计

## 1. 概述

Session 是 opencode 的核心业务实体，代表用户与 AI 的一次完整对话上下文。Session 管理贯穿整个系统，包含创建、消息处理、执行调度、压缩、撤销、归档等完整生命周期。

---

## 2. Session 架构：V1 与 V2

代码库中同时存在两套 Session 实现，V2 为当前主线：

| 特性 | V1 | V2 |
|------|----|----|
| 消息存储 | `message` + `part` 表 | `session_message` 表 |
| 输入队列 | 无持久化 | `session_input` 表（持久化） |
| 执行模型 | 内存驱动 | 持久化准入 + 异步唤醒 |
| 中断恢复 | 不支持 | 支持（pending session_input 自动重试） |
| 并发控制 | 无 | `SessionRunCoordinator`（进程级） |

---

## 3. Session 生命周期

```
创建 (create)
    │
    ▼
等待输入 (idle)
    │
    ▼ Session.prompt()
准入 (admitted) ← session_input 行写入数据库
    │
    ▼ SessionExecution.wake()
执行中 (running) ← SessionRunner 加载历史、调用 LLM
    │
    ├── 工具调用循环 (tool loop)
    │       └── Tool.execute() → 结果写回
    │
    ▼ 轮次完成
空闲 (idle) ← 等待下一个输入或用户中断
    │
    ├── compact() → 压缩上下文
    ├── revert()  → 撤销到某条消息
    └── archive() → 归档（软删除）
```

---

## 4. Session ID 设计

```typescript
// SessionID 使用降序 ULID（Universally Unique Lexicographically Sortable ID）
// 降序保证新 Session 排在列表前面，无需额外排序
const id = SessionID.descending(optionalExternalID)
// 示例: 01JWXYZ... → 降序后最新的排在字典序最前
```

每个 Session 还有一个 `slug`（人类可读短 ID），用于 URL 和日志显示：
```typescript
const slug = Slug.create()  // 随机可读字符串，如 "swift-fox"
```

---

## 5. 核心 Service 接口

代码：`packages/opencode/src/session/session.ts`

```typescript
interface Session.Interface {
  // ── 查询 ──────────────────────────────────────────────────
  get: (id: SessionID) => Effect.Effect<Info, NotFoundError>
  list: (input?: ListInput) => Effect.Effect<Info[]>
  listGlobal: (input?: GlobalListInput) => Effect.Effect<GlobalInfo[]>
  children: (parentID: SessionID) => Effect.Effect<Info[]>

  // ── 创建与删除 ────────────────────────────────────────────
  create: (input: CreateInput) => Effect.Effect<Info>
  fork: (input: ForkInput) => Effect.Effect<Info>  // 从某条消息分叉新 Session
  remove: (id: SessionID) => Effect.Effect<void>

  // ── 元数据更新 ────────────────────────────────────────────
  setTitle: (input: SetTitleInput) => Effect.Effect<void>
  setArchived: (input: SetArchivedInput) => Effect.Effect<void>
  setMetadata: (input: SetMetadataInput) => Effect.Effect<void>
  setPermission: (input: SetPermissionInput) => Effect.Effect<void>
  setRevert: (input: SetRevertInput) => Effect.Effect<void>

  // ── 消息操作 ──────────────────────────────────────────────
  messages: (input: MessagesInput) => Effect.Effect<MessageV1[]>
  updateMessage: <T>(msg: T) => Effect.Effect<T>

  // ── V2 执行控制 ───────────────────────────────────────────
  prompt: (input: PromptInput) => Effect.Effect<SessionInput.Admitted>
  interrupt: (id: SessionID) => Effect.Effect<void>
  compact: (id: SessionID) => Effect.Effect<void>
  wait: (id: SessionID) => Effect.Effect<void>
}
```

---

## 6. Session.prompt() — 消息准入机制

`Session.prompt()` 是 V2 Session 的核心入口，实现持久化准入：

```typescript
// packages/opencode/src/session/session.ts
const prompt = Effect.fn("Session.prompt")(function* (input) {
  // 1. 分配准入序号（原子递增）
  const admittedSeq = yield* nextSeq(sessionID)

  // 2. 写入 session_input 表（持久化，即使进程崩溃也不丢失）
  yield* db.insert(SessionInputTable).values({
    id: input.id ?? SessionMessage.ID.make(),
    session_id: sessionID,
    prompt: input.prompt,
    delivery: input.delivery ?? "steer",
    admitted_seq: admittedSeq,
    promoted_seq: null,    // ← null 表示尚未被执行器消费
    time_created: Date.now(),
  })

  // 3. 发布事件通知执行器
  if (input.resume !== false) {
    yield* SessionExecution.wake(sessionID)
  }

  return { id: input.id, seq: admittedSeq }
})
```

**Delivery 模式：**

| 模式 | 行为 |
|------|------|
| `steer`（默认） | 立即影响当前正在运行的轮次，会中断并重新调度 |
| `queue` | 进入队列等待，Session 空闲时再提升为执行 |

---

## 7. SessionExecution — 执行调度层

代码：`packages/core/src/session/execution/local.ts`

`SessionRunCoordinator` 是进程级单例，管理所有 Session 的执行状态：

```typescript
// 进程内唯一协调器
class SessionRunCoordinator {
  // Session ID → 当前运行的 Fiber
  private runs: Map<SessionID, Fiber>

  // 唤醒 Session（如果已在运行则合并，否则启动新运行）
  wake(sessionID: SessionID): Effect.Effect<void>

  // 中断 Session（发送中断信号给运行中的 Fiber）
  interrupt(sessionID: SessionID): Effect.Effect<void>

  // 等待 Session 空闲
  wait(sessionID: SessionID): Effect.Effect<void>
}
```

**关键设计原则：**
- 同一 Session 同一时刻只有一个运行的 Drain（`SessionRunCoordinator` 保证）
- 不同 Session 可以并发运行
- Advisory wakes（唤醒信号）会合并：多次 wake 只触发一次 drain
- 中断是进程本地的，针对活跃的 Fiber

---

## 8. SessionRunner — 执行引擎

每次 drain 启动一个 `SessionRunner`，其执行流程：

```typescript
// 简化伪代码
async function run(sessionID) {
  // 1. 从数据库加载 session_input（promoted_seq IS NULL）
  const pendingInputs = await db.select()
    .from(SessionInputTable)
    .where(and(
      eq(SessionInputTable.session_id, sessionID),
      isNull(SessionInputTable.promoted_seq)
    ))
    .orderBy(asc(SessionInputTable.admitted_seq))

  // 2. 选择要执行的输入
  //    - steer：取最后一个 steer 输入（跳过中间的）
  //    - queue：取第一个 queue 输入（Session 空闲时）
  const input = selectNextInput(pendingInputs)
  if (!input) return  // 没有待处理输入，退出

  // 3. 加载历史消息（从 session_message 表，读取 context epoch 之后的）
  const history = await loadProjectedHistory(sessionID)

  // 4. 解析 Agent 和模型配置
  const agent = await Agent.get(session.agent ?? defaultAgent)
  const model = await Provider.resolveModel(session.model ?? agent.model ?? defaultModel)

  // 5. 构建工具列表（根据 Agent 权限过滤）
  const tools = await ToolRegistry.tools({
    providerID: model.providerID,
    modelID: model.modelID,
    agent,
    permission: session.permission,
  })

  // 6. 调用 LLM（流式）
  const stream = await llm.stream({
    model,
    messages: [...history, userMessage(input.prompt)],
    tools,
    system: agent.prompt ?? defaultSystemPrompt,
  })

  // 7. 处理流：工具调用 → 执行 → 结果写回 → 继续流
  for await (const chunk of stream) {
    if (chunk.type === "tool_call") {
      const result = await Tool.execute(chunk.tool, chunk.args)
      // 写入 session_message 并继续 LLM 调用
    }
    // 发布实时事件给客户端
    await EventV2Bridge.publish(chunk)
  }

  // 8. 更新 promoted_seq，标记输入已处理
  await db.update(SessionInputTable)
    .set({ promoted_seq: nextSeq() })
    .where(eq(SessionInputTable.id, input.id))

  // 9. 检查是否有更多待处理输入，若有则继续
}
```

---

## 9. 消息模型

### V2 消息类型（session_message.type）

| 类型 | 说明 |
|------|------|
| `user` | 用户输入（来自 session_input 提升） |
| `assistant` | LLM 响应文本 |
| `tool_call` | 工具调用请求 |
| `tool_result` | 工具调用结果 |
| `system` | 系统消息（Compaction 后的摘要等） |

### 消息序号（seq）

每条 `session_message` 有单调递增的 `seq`，用于：
- 精确定位历史位置
- Revert 操作的目标点
- 分页查询（`after: seq`）
- Context Epoch 的基线标记

---

## 10. Session 压缩（Compaction）

当上下文 token 接近模型限制时触发压缩：

```
1. 调用 compaction agent（隐藏 agent）
   → 生成当前对话的结构化摘要

2. 将摘要写入 session_context_epoch 表
   { baseline: <摘要文本>, baseline_seq: <当前最大 seq> }

3. 后续 SessionRunner 加载历史时：
   - 从 context_epoch 读取摘要作为系统消息
   - 只加载 baseline_seq 之后的增量消息
   - 大幅减少 token 消耗
```

---

## 11. Session Revert（撤销）

支持将 Session 状态撤销到某条消息之前：

```typescript
// 阶段1：暂存撤销点
Session.revert.stage({
  sessionID,
  messageID,      // 撤销到此消息之前
  files: true,    // 是否同时恢复文件变更
})
// → 返回 Revert.State，包含文件 diff

// 阶段2：确认提交
Session.revert.commit({ sessionID })
// → 删除 messageID 之后的所有 session_message
// → 如有文件变更，应用反向 diff

// 或取消
Session.revert.clear({ sessionID })
```

---

## 12. Session Fork（分叉）

从现有 Session 的某条消息处创建分支：

```typescript
Session.fork({
  sessionID: "parent-session-id",
  messageID: "fork-from-this-message",  // 可选，不指定则从末尾分叉
})
// → 创建新 Session，复制 parent 到 messageID 为止的所有消息
// → 新 Session.parentID = parent.id
// → 标题格式: "原标题 (fork #1)"
```

---

## 13. Session 分页查询

V2 API 使用 Cursor-based 分页：

```typescript
// 第一页
GET /api/session?limit=50&order=desc

// 响应
{
  data: [...],
  cursor: {
    previous: "base64-encoded-cursor",  // 更新的数据
    next: "base64-encoded-cursor"       // 更旧的数据
  }
}

// 翻页
GET /api/session?cursor=<next-cursor>
```

Cursor 内容是 Base64URL 编码的 JSON，包含查询条件的完整快照（目录、项目、搜索词、排序锚点）。

---

## 14. Session 共享

Session 可以生成公开分享链接：

```typescript
// 在 session 表中存储 share_url
session.share = { url: "https://opencode.ai/share/..." }

// 通过服务端 API 创建分享
POST /api/session/:sessionID/share
// → 写入 session_share 表（存储 secret 用于验证）
// → 返回公开 URL
```
