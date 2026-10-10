# opencode 开发设计文档索引

> 文档版本：1.0  
> 基准代码版本：opencode 1.18.x  
> 流程参考：IPD（集成产品开发）  

---

## 文档目录

| 编号 | 文档名称 | 说明 |
|------|----------|------|
| 01 | [产品概述与架构总览](./01-product-overview.md) | 产品定位、整体架构、包依赖关系 |
| 02 | [数据模型设计](./02-data-model.md) | 数据库 Schema、实体关系、核心类型定义 |
| 03 | [用户鉴权设计](./03-auth.md) | 认证类型、存储机制、OAuth 流程、MCP 鉴权 |
| 04 | [Session 管理设计](./04-session.md) | Session 生命周期、V1/V2 架构、消息模型、执行引擎 |
| 05 | [AI Provider 集成设计](./05-provider.md) | Provider 抽象层、30+ SDK 集成、模型发现、鉴权解析 |
| 06 | [Tool 系统设计](./06-tool.md) | 内置工具、权限控制、MCP 工具、Plugin 工具 |
| 07 | [Agent 系统设计](./07-agent.md) | 内置 Agent、权限规则集、自定义 Agent、子 Agent 调度 |
| 08 | [HTTP API 设计](./08-http-api.md) | Effect HttpApi 路由、中间件、鉴权、OpenAPI 规范 |
| 09 | [MCP 集成设计](./09-mcp.md) | MCP 协议、传输层、OAuth 流程、工具生命周期 |
| 10 | [配置系统设计](./10-config.md) | 多源配置合并、变量替换、远程配置、MDM 管理 |
| 11 | [TUI 前端设计](./11-tui.md) | SolidJS 组件树、路由、Context、事件驱动 |
| 12 | [CLI 设计](./12-cli.md) | 命令体系、运行模式、入口点 |
