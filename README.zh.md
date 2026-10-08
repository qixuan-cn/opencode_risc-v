<h1 align="center">OpenCode RISC-V 版本</h1>

<p align="center">由 <a href="https://www.qixuan.vip">深圳启煊软件</a> 基于 <a href="https://github.com/anomalyco/opencode">OpenCode</a> 开发的 RISC-V 移植版本</p>
<p align="center">适用于 RISC-V 指令集 Linux 系统的开源 AI 编程助手</p>

<p align="center">
  <a href="README.md">中文（繁）</a> |
  <a href="README.zh.md">中文（简）</a> |
  <a href="README.en.md">English</a>
</p>

---

## 简介

本项目是深圳启煊软件（[https://www.qixuan.vip](https://www.qixuan.vip)）基于开源项目 [OpenCode](https://github.com/anomalyco/opencode) 进行的 RISC-V 架构移植。

由于原版依赖的 [Bun](https://bun.sh) 运行时不支持 RISC-V，本移植版改用 **Node.js 22+** 运行，并通过 Bun API polyfill 保持源码兼容。

## 快速开始

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

构建完成后：

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "帮我写一个快速排序"
./dist-riscv/bin/opencode serve
```

## 功能支持

| 功能 | 状态 |
|------|------|
| `opencode run` 非交互模式 | ✅ |
| `opencode serve` API server | ✅ |
| `opencode session` 会话管理 | ✅ |
| `opencode mcp` MCP 协议 | ✅ |
| `opencode --mini` TUI 界面 | ❌ 依赖 Bun |

## 目标平台

- 架构：riscv64
- 系统：Linux（Debian/Ubuntu、RockOS、ESWIN EIC7x 等）
- 运行时：Node.js 22.12.0（源码编译）

## 许可证

MIT — 原项目由 [Anomaly](https://github.com/anomalyco/opencode) 开发
