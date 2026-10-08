<h1 align="center">OpenCode RISC-V版</h1>

<p align="center"><a href="https://www.qixuan.vip">深圳启煊软件（Qixuan Software）</a>が<a href="https://github.com/anomalyco/opencode">OpenCode</a>をベースに開発したRISC-V移植版</p>
<p align="center">RISC-V命令セットのLinuxシステム向けオープンソースAIコーディングアシスタント</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.ja.md">日本語</a>
</p>

---

## 概要

本プロジェクトは、[OpenCode](https://github.com/anomalyco/opencode)を**riscv64 Linux**向けに移植したものです。オリジナルが依存する[Bun](https://bun.sh)ランタイムがRISC-Vをサポートしていないため、**Node.js 22+**を使用し、Bun APIポリフィルで互換性を維持しています。

## クイックスタート

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

ビルド後：

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "バブルソートを書いて"
./dist-riscv/bin/opencode serve
```

## 機能状況

| 機能 | 状態 |
|------|------|
| `opencode run` 非インタラクティブ | ✅ |
| `opencode serve` APIサーバー | ✅ |
| `opencode session` セッション管理 | ✅ |
| `opencode mcp` MCPプロトコル | ✅ |
| `opencode --mini` TUI | ❌ Bun依存 |

## 対象プラットフォーム

- アーキテクチャ：riscv64
- OS：Linux（Debian/Ubuntu、RockOS、ESWIN EIC7xなど）
- ランタイム：Node.js 22.12.0（ソースからビルド）

## ライセンス

MIT — オリジナルは[Anomaly](https://github.com/anomalyco/opencode)が開発
