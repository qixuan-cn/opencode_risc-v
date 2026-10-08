<h1 align="center">OpenCode dla RISC-V</h1>

<p align="center">Portowanie RISC-V projektu <a href="https://github.com/anomalyco/opencode">OpenCode</a> opracowane przez <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Otwartoźródłowy asystent programowania AI dla systemów Linux RISC-V</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.pl.md">Polski</a>
</p>

---

## Przegląd

Ten projekt przenosi [OpenCode](https://github.com/anomalyco/opencode) na **riscv64 Linux**. Ponieważ oryginalny runtime [Bun](https://bun.sh) nie obsługuje RISC-V, używany jest **Node.js 22+** z polyfillem API Bun.

## Szybki start

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Po zbudowaniu:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Napisz algorytm sortowania bąbelkowego"
./dist-riscv/bin/opencode serve
```

## Status funkcji

| Funkcja | Status |
|---------|--------|
| `opencode run` tryb nieinteraktywny | ✅ |
| `opencode serve` serwer API | ✅ |
| `opencode session` zarządzanie sesjami | ✅ |
| `opencode mcp` protokół MCP | ✅ |
| `opencode --mini` interfejs TUI | ❌ Wymaga Bun |

## Platforma docelowa

- Architektura: riscv64
- OS: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x itp.)
- Runtime: Node.js 22.12.0 (skompilowany ze źródeł)

## Licencja

MIT — Oryginalny projekt [Anomaly](https://github.com/anomalyco/opencode)
