<h1 align="center">OpenCode RISC-V için</h1>

<p align="center"><a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a> tarafından <a href="https://github.com/anomalyco/opencode">OpenCode</a> tabanlı geliştirilen RISC-V uyarlaması</p>
<p align="center">RISC-V komut seti Linux sistemleri için açık kaynaklı yapay zeka programlama asistanı</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.tr.md">Türkçe</a>
</p>

---

## Genel Bakış

Bu proje, [OpenCode](https://github.com/anomalyco/opencode)'u **riscv64 Linux** için taşır. Orijinal [Bun](https://bun.sh) çalışma ortamı RISC-V'yi desteklemediğinden, Bun API polyfill ile **Node.js 22+** kullanılmaktadır.

## Hızlı Başlangıç

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Derlemeden sonra:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Kabarcık sıralama algoritması yaz"
./dist-riscv/bin/opencode serve
```

## Özellik Durumu

| Özellik | Durum |
|---------|-------|
| `opencode run` etkileşimsiz mod | ✅ |
| `opencode serve` API sunucusu | ✅ |
| `opencode session` oturum yönetimi | ✅ |
| `opencode mcp` MCP protokolü | ✅ |
| `opencode --mini` TUI arayüzü | ❌ Bun gerektirir |

## Hedef Platform

- Mimari: riscv64
- İşletim Sistemi: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x vb.)
- Çalışma Ortamı: Node.js 22.12.0 (kaynak koddan derlendi)

## Lisans

MIT — Orijinal proje: [Anomaly](https://github.com/anomalyco/opencode)
