# 02 数据模型设计

## 1. 数据库概述

- 数据库引擎：SQLite（本地文件）
- ORM：Drizzle ORM（类型安全）
- 文件路径：`~/.local/share/opencode/opencode.db`（Linux）
- 迁移管理：内置 Effect 迁移系统，按版本顺序执行

---

## 2. 实体关系图

```
project ──┬── session ──┬── message ──── part
          │             ├── session_message
          │             ├── session_input
          │             ├── session_context_epoch
          │             ├── todo
          │             └── session_share
          ├── workspace
          ├── project_directory
          └── permission

account ──── account_state

event_sequence ──── event

credential
```

---

## 3. 核心表定义

### 3.1 project（项目）

```sql
CREATE TABLE project (
  id              TEXT PRIMARY KEY,        -- ProjectV2.ID，ULID
  worktree        TEXT NOT NULL,           -- 项目工作目录绝对路径
  vcs             TEXT,                    -- 版本控制类型（git 等）
  name            TEXT,                    -- 项目显示名称
  icon_url        TEXT,                    -- 项目图标 URL
  icon_url_override TEXT,
  icon_color      TEXT,
  time_created    INTEGER NOT NULL,        -- Unix 毫秒时间戳
  time_updated    INTEGER NOT NULL,
  time_initialized INTEGER,
  sandboxes       TEXT NOT NULL,           -- JSON，沙箱配置
  commands        TEXT                     -- JSON，项目命令
);
```

### 3.2 session（会话）

```sql
CREATE TABLE session (
  id              TEXT PRIMARY KEY,        -- SessionID，降序 ULID
  project_id      TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
  workspace_id    TEXT,                    -- WorkspaceV2.ID（可选）
  parent_id       TEXT,                    -- 父 Session（子 Session 场景）
  slug            TEXT NOT NULL,           -- 人类可读短 ID
  directory       TEXT NOT NULL,           -- Session 工作目录
  path            TEXT,                    -- 当前文件路径
  title           TEXT NOT NULL,           -- 会话标题
  version         TEXT NOT NULL,           -- opencode 版本号
  share_url       TEXT,                    -- 分享 URL
  summary_additions INTEGER,              -- 代码变更统计：新增行数
  summary_deletions INTEGER,              -- 代码变更统计：删除行数
  summary_files    INTEGER,               -- 代码变更统计：文件数
  summary_diffs    TEXT,                  -- JSON，文件 diff 快照
  metadata         TEXT,                  -- JSON，自定义元数据
  cost             REAL NOT NULL DEFAULT 0, -- 累计 API 费用（美元）
  tokens_input     INTEGER NOT NULL DEFAULT 0, -- 累计输入 token
  tokens_output    INTEGER NOT NULL DEFAULT 0, -- 累计输出 token
  tokens_reasoning INTEGER NOT NULL DEFAULT 0, -- 推理 token
  tokens_cache_read  INTEGER NOT NULL DEFAULT 0, -- 缓存读取 token
  tokens_cache_write INTEGER NOT NULL DEFAULT 0, -- 缓存写入 token
  revert           TEXT,                  -- JSON，可撤销操作状态
  permission       TEXT,                  -- JSON，会话级权限覆盖
  agent            TEXT,                  -- 当前使用的 Agent 名称
  model            TEXT,                  -- JSON，当前使用的模型
  time_created     INTEGER NOT NULL,
  time_updated     INTEGER NOT NULL,
  time_compacting  INTEGER,               -- 压缩开始时间
  time_archived    INTEGER                -- 归档时间
);
```

**索引：**
- `session_project_idx`：按 project_id 查询
- `session_workspace_idx`：按 workspace_id 查询
- `session_parent_idx`：按 parent_id 查询（父子 Session 关系）

### 3.3 session_message（Session 消息 V2）

```sql
CREATE TABLE session_message (
  id          TEXT PRIMARY KEY,            -- SessionMessage.ID
  session_id  TEXT NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  type        TEXT NOT NULL,               -- 消息类型（user/assistant/tool 等）
  seq         INTEGER NOT NULL,            -- 会话内单调递增序号
  time_created INTEGER NOT NULL,
  time_updated INTEGER NOT NULL,
  data        TEXT NOT NULL                -- JSON，消息内容
);
```

**唯一索引：** `(session_id, seq)` — 保证每个 Session 内序号唯一

### 3.4 session_input（Session 输入队列）

```sql
CREATE TABLE session_input (
  id          TEXT PRIMARY KEY,            -- SessionMessage.ID
  session_id  TEXT NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  prompt      TEXT NOT NULL,               -- JSON，提示内容
  delivery    TEXT NOT NULL,               -- 投递模式：steer/queue
  admitted_seq INTEGER NOT NULL,           -- 准入序号
  promoted_seq INTEGER,                    -- 晋升序号（NULL 表示待处理）
  time_created INTEGER NOT NULL
);
```

`session_input` 是 V2 Session 的核心持久化机制：
- `admitted_seq`：输入被准入时的序号，单调递增
- `promoted_seq`：输入被提升为实际执行时的序号，NULL 表示尚未执行
- `delivery`：`steer` 立即影响当前轮次，`queue` 等待空闲时执行

### 3.5 session_context_epoch（上下文快照）

```sql
CREATE TABLE session_context_epoch (
  session_id   TEXT PRIMARY KEY REFERENCES session(id) ON DELETE CASCADE,
  baseline     TEXT NOT NULL,              -- 上下文基线快照（JSON）
  snapshot     TEXT NOT NULL,             -- 系统上下文快照
  baseline_seq INTEGER NOT NULL           -- 对应的消息序号
);
```

用于 Session 压缩（compaction）后的上下文恢复。

### 3.6 message / part（消息 V1，旧版兼容）

```sql
CREATE TABLE message (
  id          TEXT PRIMARY KEY,
  session_id  TEXT NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  time_created INTEGER NOT NULL,
  time_updated INTEGER NOT NULL,
  data        TEXT NOT NULL               -- JSON，V1 消息数据
);

CREATE TABLE part (
  id          TEXT PRIMARY KEY,
  message_id  TEXT NOT NULL REFERENCES message(id) ON DELETE CASCADE,
  session_id  TEXT NOT NULL,
  time_created INTEGER NOT NULL,
  time_updated INTEGER NOT NULL,
  data        TEXT NOT NULL               -- JSON，V1 消息分片数据
);
```

### 3.7 todo（待办事项）

```sql
CREATE TABLE todo (
  session_id  TEXT NOT NULL REFERENCES session(id) ON DELETE CASCADE,
  content     TEXT NOT NULL,              -- 待办内容
  status      TEXT NOT NULL,             -- pending/in_progress/completed/cancelled
  priority    TEXT NOT NULL,             -- high/medium/low
  position    INTEGER NOT NULL,          -- 排序位置
  time_created INTEGER NOT NULL,
  time_updated INTEGER NOT NULL,
  PRIMARY KEY (session_id, position)
);
```

### 3.8 account（用户账号）

```sql
CREATE TABLE account (
  id            TEXT PRIMARY KEY,
  email         TEXT NOT NULL,
  url           TEXT NOT NULL,           -- 账号服务 URL
  access_token  TEXT NOT NULL,          -- OAuth access token
  refresh_token TEXT NOT NULL,          -- OAuth refresh token
  token_expiry  INTEGER,                -- token 过期时间
  time_created  INTEGER NOT NULL,
  time_updated  INTEGER NOT NULL
);
```

### 3.9 credential（凭据）

```sql
CREATE TABLE credential (
  id            TEXT PRIMARY KEY,
  integration_id TEXT,                  -- 关联集成
  label         TEXT NOT NULL,          -- 显示名称
  value         TEXT NOT NULL,          -- 加密存储的凭据值
  connector_id  TEXT,
  method_id     TEXT,
  active        INTEGER,                -- 是否激活
  time_created  INTEGER NOT NULL,
  time_updated  INTEGER NOT NULL
);
```

### 3.10 event / event_sequence（事件溯源）

```sql
CREATE TABLE event_sequence (
  aggregate_id TEXT PRIMARY KEY,        -- 聚合根 ID（通常是 session_id）
  seq          INTEGER NOT NULL,        -- 当前最大序号
  owner_id     TEXT                     -- 当前执行所有者（进程 ID）
);

CREATE TABLE event (
  id           TEXT PRIMARY KEY,
  aggregate_id TEXT NOT NULL REFERENCES event_sequence(aggregate_id) ON DELETE CASCADE,
  seq          INTEGER NOT NULL,
  type         TEXT NOT NULL,           -- 事件类型
  data         TEXT NOT NULL            -- JSON，事件数据
);
```

**唯一索引：** `(aggregate_id, seq)` — 保证事件顺序唯一性

### 3.11 permission（权限记录）

```sql
CREATE TABLE permission (
  id          TEXT PRIMARY KEY,
  project_id  TEXT NOT NULL REFERENCES project(id) ON DELETE CASCADE,
  action      TEXT NOT NULL,            -- 操作类型（read/write/bash 等）
  resource    TEXT NOT NULL,            -- 资源（文件路径、URL 等）
  time_created INTEGER NOT NULL,
  time_updated INTEGER NOT NULL,
  UNIQUE (project_id, action, resource)
);
```

---

## 4. 核心 TypeScript 类型

### 4.1 Session.Info

```typescript
interface Session.Info {
  id: SessionID                          // 降序 ULID
  slug: string                           // 人类可读短 ID
  projectID: ProjectV2.ID
  workspaceID?: WorkspaceV2.ID
  directory: string
  path?: string
  parentID?: SessionID                   // 子 Session
  title: string
  agent?: string
  model?: {
    id: ModelV2.ID
    providerID: ProviderV2.ID
    variant?: string
  }
  version: string
  summary?: {
    additions: number
    deletions: number
    files: number
    diffs?: Snapshot.LegacyFileDiff[]
  }
  cost?: number
  tokens?: {
    input: number
    output: number
    reasoning: number
    cache: { read: number; write: number }
  }
  share?: { url: string }
  metadata?: Record<string, unknown>
  revert?: Revert.State
  permission?: PermissionV1.Ruleset
  time: {
    created: number
    updated: number
    compacting?: number
    archived?: number
  }
}
```

### 4.2 Auth.Info

```typescript
type Auth.Info =
  | { type: "oauth"; refresh: string; access: string; expires: number; accountId?: string; enterpriseUrl?: string }
  | { type: "api"; key: string; metadata?: Record<string, string> }
  | { type: "wellknown"; key: string; token: string }
```

### 4.3 PermissionV1.Ruleset

```typescript
type PermissionV1.Ruleset = Array<{
  permission: string    // 权限类型（read/write/bash/external_directory 等）
  action: "allow" | "deny" | "ask"
  pattern: string       // glob 模式或资源名
}>
```
