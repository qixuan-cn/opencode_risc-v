<h1 align="center">OpenCode για RISC-V</h1>

<p align="center">Μεταφορά RISC-V του <a href="https://github.com/anomalyco/opencode">OpenCode</a> από την <a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a></p>
<p align="center">Ανοιχτού κώδικα βοηθός προγραμματισμού AI για συστήματα Linux RISC-V</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.gr.md">Ελληνικά</a>
</p>

---

## Επισκόπηση

Αυτό το έργο μεταφέρει το [OpenCode](https://github.com/anomalyco/opencode) στο **riscv64 Linux**. Επειδή το αρχικό runtime [Bun](https://bun.sh) δεν υποστηρίζει RISC-V, χρησιμοποιείται **Node.js 22+** με polyfill API του Bun.

## Γρήγορη εκκίνηση

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

Μετά την κατασκευή:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "Γράψε αλγόριθμο ταξινόμησης φυσαλίδας"
./dist-riscv/bin/opencode serve
```

## Κατάσταση λειτουργιών

| Λειτουργία | Κατάσταση |
|------------|-----------|
| `opencode run` μη διαδραστική λειτουργία | ✅ |
| `opencode serve` διακομιστής API | ✅ |
| `opencode session` διαχείριση συνεδριών | ✅ |
| `opencode mcp` πρωτόκολλο MCP | ✅ |
| `opencode --mini` διεπαφή TUI | ❌ Απαιτεί Bun |

## Πλατφόρμα στόχος

- Αρχιτεκτονική: riscv64
- ΛΣ: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x κ.λπ.)
- Runtime: Node.js 22.12.0 (μεταγλωττισμένο από πηγαίο κώδικα)

## Άδεια

MIT — Αρχικό έργο από [Anomaly](https://github.com/anomalyco/opencode)
