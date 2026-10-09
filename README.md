<p align="center">
  <a href="https://www.qixuan.vip">
    <img src="packages/console/app/src/asset/logo-ornate-light.svg" alt="OpenCode RISC-V logo">
  </a>
</p>

<h1 align="center">OpenCode for RISC-V</h1>

<p align="center">由 <a href="https://www.qixuan.vip">深圳启煊软件</a> 基于 <a href="https://github.com/anomalyco/opencode">OpenCode</a> 开发的 RISC-V 版本</p>
<p align="center">适用于 RISC-V 指令集 Linux 系统的开源 AI 编程助手</p>

<p align="center">
  <a href="README.md">中文</a> |
  <a href="README.en.md">English</a>
</p>

---

## 项目简介

本项目是深圳启煊软件（[https://www.qixuan.vip](https://www.qixuan.vip)）基于开源项目 [OpenCode](https://github.com/anomalyco/opencode) 进行移植和适配，使其能够在 **RISC-V 指令集** 的 Linux 系统上运行。

OpenCode 是一款开源的 AI 编程智能体，支持与主流大语言模型协作完成代码编写、调试、重构等任务。原版基于 [Bun](https://bun.sh) 运行时构建，而 Bun 目前不支持 RISC-V 架构。本项目通过以下方式实现移植：

- 使用 **Node.js 22+** 替代 Bun 作为运行时
- 注入 **Bun API polyfill**，兼容源码中少量 Bun 专用调用
- 提供 `build-riscv.sh` 一键构建脚本，在 RISC-V 设备上直接从源码编译运行

## 目标平台

| 项目 | 说明 |
|------|------|
| 架构 | riscv64 |
| 系统 | Linux（Debian/Ubuntu，含 RockOS、ESWIN EIC7x 等） |
| 内核 | 6.6+ |
| 运行时 | Node.js 22.12.0+（源码编译） |

## 快速开始

### 1. 克隆代码

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
```

### 2. 构建（在 RISC-V 设备上运行）

```bash
bash build-riscv.sh
```

脚本会自动完成：
- 安装系统依赖
- 从源码编译 Node.js 22.12.0（首次约 60-90 分钟）
- 安装 npm 依赖
- 重建原生模块（@parcel/watcher、node-pty 等）
- 生成 Bun polyfill 和启动脚本

### 3. 运行

```bash
# 查看帮助
./dist-riscv/bin/opencode --help

# 非交互模式（发送单条消息）
./dist-riscv/bin/opencode run "帮我写一个冒泡排序"

# Headless server 模式
./dist-riscv/bin/opencode serve

# 查看版本
./dist-riscv/bin/opencode --version
```

## 功能说明

| 功能 | 状态 | 备注 |
|------|------|------|
| `opencode run` 非交互模式 | ✅ 可用 | 核心功能 |
| `opencode serve` API server | ✅ 可用 | headless 服务端 |
| `opencode session` 会话管理 | ✅ 可用 | |
| `opencode mcp` MCP 协议 | ✅ 可用 | |
| `opencode --mini` TUI 交互界面 | ❌ 不可用 | 依赖 Bun 内置 API |
| 文件监听（@parcel/watcher） | ⚠️ 降级 | 原生模块需自行编译 |

## 构建说明

> 详细的编译踩坑记录和版本选择说明见 [BUILD-NOTES.md](BUILD-NOTES.md)

### Node.js 编译参数

riscv64 上编译 Node.js 需要额外参数，否则 OpenSSL 会使用 x86_64 汇编路径导致 `-m64` 错误：

```bash
./configure \
  --prefix=/usr/local \
  --openssl-no-asm \      # 关键：跳过平台汇编优化
  --without-snapshot \
  --without-node-snapshot
```

### 手动运行（无需 build-riscv.sh）

```bash
# 安装 tsx
sudo npm install -g tsx

# 直接运行
node \
  --experimental-vm-modules \
  --conditions=node \
  --import ./dist-riscv/bun-polyfill.mjs \
  --import tsx/esm \
  packages/opencode/src/index.ts --help
```

## 原项目信息

- 原项目：[OpenCode](https://github.com/anomalyco/opencode) by Anomaly
- 许可证：MIT
- 本项目同样遵循 MIT 许可证

## 关于启煊软件

深圳启煊软件致力于为 RISC-V 生态提供开发工具支持。

官网：[https://www.qixuan.vip](https://www.qixuan.vip)
