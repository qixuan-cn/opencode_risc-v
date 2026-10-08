<h1 align="center">OpenCode สำหรับ RISC-V</h1>

<p align="center">เวอร์ชัน RISC-V ของ <a href="https://github.com/anomalyco/opencode">OpenCode</a> พัฒนาโดย <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">ผู้ช่วยเขียนโปรแกรม AI โอเพนซอร์สสำหรับระบบ Linux RISC-V</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.th.md">ไทย</a>
</p>

---

## ภาพรวม

โปรเจกต์นี้พอร์ต [OpenCode](https://github.com/anomalyco/opencode) ไปยัง **riscv64 Linux** เนื่องจาก [Bun](https://bun.sh) runtime ดั้งเดิมไม่รองรับ RISC-V จึงใช้ **Node.js 22+** พร้อม Bun API polyfill

## เริ่มต้นใช้งาน

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

หลังจาก build เสร็จ:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "เขียน bubble sort algorithm"
./dist-riscv/bin/opencode serve
```

## สถานะฟีเจอร์

| ฟีเจอร์ | สถานะ |
|---------|-------|
| `opencode run` โหมดไม่โต้ตอบ | ✅ |
| `opencode serve` API server | ✅ |
| `opencode session` จัดการเซสชัน | ✅ |
| `opencode mcp` โปรโตคอล MCP | ✅ |
| `opencode --mini` TUI interface | ❌ ต้องการ Bun |

## แพลตฟอร์มเป้าหมาย

- สถาปัตยกรรม: riscv64
- OS: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x ฯลฯ)
- Runtime: Node.js 22.12.0 (คอมไพล์จากซอร์สโค้ด)

## สัญญาอนุญาต

MIT — โปรเจกต์ต้นฉบับโดย [Anomaly](https://github.com/anomalyco/opencode)
