<h1 align="center">OpenCode para RISC-V</h1>

<p align="center">Versión RISC-V de <a href="https://github.com/anomalyco/opencode">OpenCode</a> desarrollada por <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Asistente de programación IA de código abierto para sistemas Linux RISC-V</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.es.md">Español</a>
</p>

---

## Descripción

Este proyecto porta [OpenCode](https://github.com/anomalyco/opencode) a **riscv64 Linux**. Como el runtime [Bun](https://bun.sh) original no soporta RISC-V, se utiliza **Node.js 22+** con un polyfill de la API de Bun.

## Inicio rápido

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Tras la compilación:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Escribe un algoritmo de ordenación burbuja"
./dist-riscv/bin/opencode serve
```

## Estado de funcionalidades

| Funcionalidad | Estado |
|---------------|--------|
| `opencode run` modo no interactivo | ✅ |
| `opencode serve` servidor API | ✅ |
| `opencode session` gestión de sesiones | ✅ |
| `opencode mcp` protocolo MCP | ✅ |
| `opencode --mini` interfaz TUI | ❌ Requiere Bun |

## Plataforma objetivo

- Arquitectura: riscv64
- SO: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x, etc.)
- Runtime: Node.js 22.12.0 (compilado desde fuentes)

## Licencia

MIT — Proyecto original de [Anomaly](https://github.com/anomalyco/opencode)
