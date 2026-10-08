<h1 align="center">OpenCode per RISC-V</h1>

<p align="center">Porting RISC-V di <a href="https://github.com/anomalyco/opencode">OpenCode</a> sviluppato da <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Assistente di programmazione AI open source per sistemi Linux RISC-V</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.it.md">Italiano</a>
</p>

---

## Panoramica

Questo progetto porta [OpenCode](https://github.com/anomalyco/opencode) su **riscv64 Linux**. Poiché il runtime [Bun](https://bun.sh) originale non supporta RISC-V, viene usato **Node.js 22+** con un polyfill dell'API Bun.

## Avvio rapido

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Dopo la compilazione:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Scrivi un bubble sort"
./dist-riscv/bin/opencode serve
```

## Stato delle funzionalità

| Funzionalità | Stato |
|--------------|-------|
| `opencode run` modalità non interattiva | ✅ |
| `opencode serve` server API | ✅ |
| `opencode session` gestione sessioni | ✅ |
| `opencode mcp` protocollo MCP | ✅ |
| `opencode --mini` interfaccia TUI | ❌ Richiede Bun |

## Piattaforma target

- Architettura: riscv64
- OS: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x, ecc.)
- Runtime: Node.js 22.12.0 (compilato dai sorgenti)

## Licenza

MIT — Progetto originale di [Anomaly](https://github.com/anomalyco/opencode)
