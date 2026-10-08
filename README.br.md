<h1 align="center">OpenCode para RISC-V</h1>

<p align="center">Portabilização RISC-V do <a href="https://github.com/anomalyco/opencode">OpenCode</a> desenvolvida por <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Assistente de programação IA open source para sistemas Linux RISC-V</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.br.md">Português (Brasil)</a>
</p>

---

## Visão Geral

Este projeto porta o [OpenCode](https://github.com/anomalyco/opencode) para **riscv64 Linux**. Como o runtime [Bun](https://bun.sh) original não suporta RISC-V, utiliza-se **Node.js 22+** com um polyfill da API do Bun.

## Início Rápido

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Após a compilação:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Escreva um bubble sort"
./dist-riscv/bin/opencode serve
```

## Estado das Funcionalidades

| Funcionalidade | Estado |
|----------------|--------|
| `opencode run` modo não interativo | ✅ |
| `opencode serve` servidor API | ✅ |
| `opencode session` gestão de sessões | ✅ |
| `opencode mcp` protocolo MCP | ✅ |
| `opencode --mini` interface TUI | ❌ Requer Bun |

## Plataforma Alvo

- Arquitetura: riscv64
- SO: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x, etc.)
- Runtime: Node.js 22.12.0 (compilado a partir do código-fonte)

## Licença

MIT — Projeto original por [Anomaly](https://github.com/anomalyco/opencode)
