<h1 align="center">OpenCode RISC-V 版本</h1>

<p align="center">由 <a href="https://www.qixuan.vip">深圳啟煊軟體</a> 基於 <a href="https://github.com/anomalyco/opencode">OpenCode</a> 開發的 RISC-V 移植版本</p>
<p align="center">適用於 RISC-V 指令集 Linux 系統的開源 AI 程式設計助手</p>

<p align="center">
  <a href="README.md">中文（繁）</a> |
  <a href="README.zh.md">中文（簡）</a> |
  <a href="README.en.md">English</a>
</p>

---

## 簡介

本專案是深圳啟煊軟體（[https://www.qixuan.vip](https://www.qixuan.vip)）基於開源專案 [OpenCode](https://github.com/anomalyco/opencode) 進行的 RISC-V 架構移植。

由於原版依賴的 [Bun](https://bun.sh) 執行環境不支援 RISC-V，本移植版改用 **Node.js 22+** 執行，並透過 Bun API polyfill 保持原始碼相容。

## 快速開始

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

建置完成後：

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "幫我寫一個快速排序"
./dist-riscv/bin/opencode serve
```

## 功能支援

| 功能 | 狀態 |
|------|------|
| `opencode run` 非互動模式 | ✅ |
| `opencode serve` API 伺服器 | ✅ |
| `opencode session` 工作階段管理 | ✅ |
| `opencode mcp` MCP 協定 | ✅ |
| `opencode --mini` TUI 介面 | ❌ 依賴 Bun |

## 目標平台

- 架構：riscv64
- 系統：Linux（Debian/Ubuntu、RockOS、ESWIN EIC7x 等）
- 執行環境：Node.js 22.12.0（原始碼編譯）

## 授權

MIT — 原專案由 [Anomaly](https://github.com/anomalyco/opencode) 開發
