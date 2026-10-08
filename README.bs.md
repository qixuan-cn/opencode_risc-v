<h1 align="center">OpenCode za RISC-V</h1>

<p align="center">RISC-V verzija <a href="https://github.com/anomalyco/opencode">OpenCode</a>-a koju je razvio <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Open source AI asistent za programiranje za Linux RISC-V sisteme</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.bs.md">Bosanski</a>
</p>

---

## Pregled

Ovaj projekat prenosi [OpenCode](https://github.com/anomalyco/opencode) na **riscv64 Linux**. Budući da originalni [Bun](https://bun.sh) runtime ne podržava RISC-V, koristi se **Node.js 22+** s Bun API polyfill-om.

## Brzi početak

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Nakon izgradnje:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Napiši algoritam sortiranja mjehurićima"
./dist-riscv/bin/opencode serve
```

## Status funkcija

| Funkcija | Status |
|----------|--------|
| `opencode run` neinteraktivni mod | ✅ |
| `opencode serve` API server | ✅ |
| `opencode session` upravljanje sesijama | ✅ |
| `opencode mcp` MCP protokol | ✅ |
| `opencode --mini` TUI sučelje | ❌ Zahtijeva Bun |

## Ciljna platforma

- Arhitektura: riscv64
- OS: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x itd.)
- Runtime: Node.js 22.12.0 (kompajliran iz izvora)

## Licenca

MIT — Originalni projekat [Anomaly](https://github.com/anomalyco/opencode)
