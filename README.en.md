# OpenCode for RISC-V

**OpenCode ported to RISC-V Linux** by [Qixuan Software (深圳启煊软件)](https://www.qixuan.vip)

Based on [OpenCode](https://github.com/anomalyco/opencode) — the open source AI coding agent.

---

## Overview

This project ports OpenCode to run on **riscv64 Linux** systems. Since [Bun](https://bun.sh) (the original runtime) does not support RISC-V, this port uses **Node.js 22+** with a lightweight Bun API polyfill and a one-step build script.

## Target Platform

| | |
|---|---|
| Architecture | riscv64 |
| OS | Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x, etc.) |
| Kernel | 6.6+ |
| Runtime | Node.js 22.12.0 (compiled from source) |

## Quick Start

```bash
# Clone
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v

# Build on the RISC-V device (first run compiles Node.js, ~60-90 min)
bash build-riscv.sh

# Run
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "write a hello world in C"
./dist-riscv/bin/opencode serve
```

## Feature Status

| Feature | Status |
|---------|--------|
| `opencode run` (non-interactive) | ✅ |
| `opencode serve` (API server) | ✅ |
| `opencode session` | ✅ |
| `opencode mcp` | ✅ |
| `opencode --mini` (TUI) | ❌ requires Bun |

## License

MIT — original project by [Anomaly](https://github.com/anomalyco/opencode)
