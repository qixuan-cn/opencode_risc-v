<h1 align="center">OpenCode für RISC-V</h1>

<p align="center">Von <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a> basierend auf <a href="https://github.com/anomalyco/opencode">OpenCode</a> entwickelte RISC-V-Portierung</p>
<p align="center">Open-Source-KI-Programmierassistent für RISC-V Linux-Systeme</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.de.md">Deutsch</a>
</p>

---

## Übersicht

Dieses Projekt portiert [OpenCode](https://github.com/anomalyco/opencode) auf **riscv64 Linux**. Da die originale [Bun](https://bun.sh)-Laufzeitumgebung RISC-V nicht unterstützt, wird **Node.js 22+** mit einem Bun-API-Polyfill verwendet.

## Schnellstart

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Nach dem Build:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Schreibe eine Bubble-Sort-Funktion"
./dist-riscv/bin/opencode serve
```

## Funktionsstatus

| Funktion | Status |
|----------|--------|
| `opencode run` nicht-interaktiv | ✅ |
| `opencode serve` API-Server | ✅ |
| `opencode session` Sitzungsverwaltung | ✅ |
| `opencode mcp` MCP-Protokoll | ✅ |
| `opencode --mini` TUI | ❌ Erfordert Bun |

## Zielplattform

- Architektur: riscv64
- OS: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x usw.)
- Laufzeit: Node.js 22.12.0 (aus Quellcode kompiliert)

## Lizenz

MIT — Originalprojekt von [Anomaly](https://github.com/anomalyco/opencode)
