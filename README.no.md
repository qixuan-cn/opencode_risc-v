<h1 align="center">OpenCode for RISC-V</h1>

<p align="center">RISC-V-tilpasning av <a href="https://github.com/anomalyco/opencode">OpenCode</a> utviklet av <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Åpen kildekode AI-programmeringsassistent for Linux RISC-V-systemer</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.no.md">Norsk</a>
</p>

---

## Oversikt

Dette prosjektet porterer [OpenCode](https://github.com/anomalyco/opencode) til **riscv64 Linux**. Siden den originale [Bun](https://bun.sh)-kjøretiden ikke støtter RISC-V, brukes **Node.js 22+** med et Bun API-polyfill.

## Rask start

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Etter bygging:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Skriv en boblesorteringsalgoritme"
./dist-riscv/bin/opencode serve
```

## Funksjonsstatus

| Funksjon | Status |
|----------|--------|
| `opencode run` ikke-interaktiv modus | ✅ |
| `opencode serve` API-server | ✅ |
| `opencode session` øktbehandling | ✅ |
| `opencode mcp` MCP-protokoll | ✅ |
| `opencode --mini` TUI-grensesnitt | ❌ Krever Bun |

## Målplattform

- Arkitektur: riscv64
- OS: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x osv.)
- Kjøretid: Node.js 22.12.0 (kompilert fra kildekode)

## Lisens

MIT — Originalprosjekt av [Anomaly](https://github.com/anomalyco/opencode)
