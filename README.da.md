<h1 align="center">OpenCode til RISC-V</h1>

<p align="center">RISC-V-tilpasning af <a href="https://github.com/anomalyco/opencode">OpenCode</a> udviklet af <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Open source AI-programmeringsassistent til Linux RISC-V-systemer</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.da.md">Dansk</a>
</p>

---

## Oversigt

Dette projekt overfører [OpenCode](https://github.com/anomalyco/opencode) til **riscv64 Linux**. Da den originale [Bun](https://bun.sh)-runtime ikke understøtter RISC-V, bruges **Node.js 22+** med et Bun API-polyfill.

## Hurtig start

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Efter build:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Skriv en boblesorteringsalgoritme"
./dist-riscv/bin/opencode serve
```

## Funktionsstatus

| Funktion | Status |
|----------|--------|
| `opencode run` ikke-interaktiv tilstand | ✅ |
| `opencode serve` API-server | ✅ |
| `opencode session` sessionsstyring | ✅ |
| `opencode mcp` MCP-protokol | ✅ |
| `opencode --mini` TUI-grænseflade | ❌ Kræver Bun |

## Målplatform

- Arkitektur: riscv64
- OS: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x osv.)
- Runtime: Node.js 22.12.0 (kompileret fra kildekode)

## Licens

MIT — Originalt projekt af [Anomaly](https://github.com/anomalyco/opencode)
