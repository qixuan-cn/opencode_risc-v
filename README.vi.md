<h1 align="center">OpenCode cho RISC-V</h1>

<p align="center">Phiên bản RISC-V của <a href="https://github.com/anomalyco/opencode">OpenCode</a> được phát triển bởi <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Trợ lý lập trình AI mã nguồn mở cho các hệ thống Linux RISC-V</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.vi.md">Tiếng Việt</a>
</p>

---

## Tổng quan

Dự án này chuyển [OpenCode](https://github.com/anomalyco/opencode) sang **riscv64 Linux**. Vì runtime [Bun](https://bun.sh) gốc không hỗ trợ RISC-V, **Node.js 22+** được sử dụng cùng với Bun API polyfill.

## Bắt đầu nhanh

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Sau khi build:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Viết thuật toán sắp xếp nổi bọt"
./dist-riscv/bin/opencode serve
```

## Trạng thái tính năng

| Tính năng | Trạng thái |
|-----------|-----------|
| `opencode run` chế độ không tương tác | ✅ |
| `opencode serve` máy chủ API | ✅ |
| `opencode session` quản lý phiên | ✅ |
| `opencode mcp` giao thức MCP | ✅ |
| `opencode --mini` giao diện TUI | ❌ Yêu cầu Bun |

## Nền tảng mục tiêu

- Kiến trúc: riscv64
- OS: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x, v.v.)
- Runtime: Node.js 22.12.0 (biên dịch từ mã nguồn)

## Giấy phép

MIT — Dự án gốc bởi [Anomaly](https://github.com/anomalyco/opencode)
