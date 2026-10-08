<h1 align="center">OpenCode для RISC-V</h1>

<p align="center">Портування <a href="https://github.com/anomalyco/opencode">OpenCode</a> на RISC-V від <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Відкритий ШІ-асистент програмування для Linux-систем на базі RISC-V</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.uk.md">Українська</a>
</p>

---

## Опис

Проєкт портує [OpenCode](https://github.com/anomalyco/opencode) на **riscv64 Linux**. Оскільки середовище виконання [Bun](https://bun.sh) не підтримує RISC-V, використовується **Node.js 22+** з поліфілом API Bun.

## Швидкий старт

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Після збірки:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Напиши сортування бульбашкою"
./dist-riscv/bin/opencode serve
```

## Стан функцій

| Функція | Статус |
|---------|--------|
| `opencode run` неінтерактивний режим | ✅ |
| `opencode serve` API-сервер | ✅ |
| `opencode session` керування сесіями | ✅ |
| `opencode mcp` протокол MCP | ✅ |
| `opencode --mini` TUI-інтерфейс | ❌ Потребує Bun |

## Цільова платформа

- Архітектура: riscv64
- ОС: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x тощо)
- Середовище виконання: Node.js 22.12.0 (зібрано з вихідного коду)

## Ліцензія

MIT — Оригінальний проєкт [Anomaly](https://github.com/anomalyco/opencode)
