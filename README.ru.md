<h1 align="center">OpenCode для RISC-V</h1>

<p align="center">Портирование <a href="https://github.com/anomalyco/opencode">OpenCode</a> на RISC-V от <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Открытый ИИ-ассистент программирования для Linux-систем на базе RISC-V</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.ru.md">Русский</a>
</p>

---

## Описание

Проект портирует [OpenCode](https://github.com/anomalyco/opencode) на **riscv64 Linux**. Поскольку среда выполнения [Bun](https://bun.sh) не поддерживает RISC-V, используется **Node.js 22+** с полифилом API Bun.

## Быстрый старт

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

После сборки:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Напиши пузырьковую сортировку"
./dist-riscv/bin/opencode serve
```

## Состояние функций

| Функция | Статус |
|---------|--------|
| `opencode run` неинтерактивный режим | ✅ |
| `opencode serve` API-сервер | ✅ |
| `opencode session` управление сессиями | ✅ |
| `opencode mcp` протокол MCP | ✅ |
| `opencode --mini` TUI-интерфейс | ❌ Требует Bun |

## Целевая платформа

- Архитектура: riscv64
- ОС: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x и др.)
- Среда выполнения: Node.js 22.12.0 (сборка из исходников)

## Лицензия

MIT — Оригинальный проект [Anomaly](https://github.com/anomalyco/opencode)
