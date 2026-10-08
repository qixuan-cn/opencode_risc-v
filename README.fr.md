<h1 align="center">OpenCode pour RISC-V</h1>

<p align="center">Portage RISC-V d'<a href="https://github.com/anomalyco/opencode">OpenCode</a> développé par <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Assistant de programmation IA open source pour les systèmes Linux RISC-V</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.fr.md">Français</a>
</p>

---

## Présentation

Ce projet porte [OpenCode](https://github.com/anomalyco/opencode) sur **riscv64 Linux**. Le runtime [Bun](https://bun.sh) d'origine ne supportant pas RISC-V, **Node.js 22+** est utilisé avec un polyfill de l'API Bun.

## Démarrage rapide

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Après la compilation :

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Écris un tri à bulles"
./dist-riscv/bin/opencode serve
```

## État des fonctionnalités

| Fonctionnalité | État |
|----------------|------|
| `opencode run` mode non-interactif | ✅ |
| `opencode serve` serveur API | ✅ |
| `opencode session` gestion de session | ✅ |
| `opencode mcp` protocole MCP | ✅ |
| `opencode --mini` interface TUI | ❌ Nécessite Bun |

## Plateforme cible

- Architecture : riscv64
- OS : Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x, etc.)
- Runtime : Node.js 22.12.0 (compilé depuis les sources)

## Licence

MIT — Projet original par [Anomaly](https://github.com/anomalyco/opencode)
