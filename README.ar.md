<h1 align="center">OpenCode لـ RISC-V</h1>

<p align="center">نسخة RISC-V من <a href="https://github.com/anomalyco/opencode">OpenCode</a> طوّرتها <a href="https://www.qixuan.vip">شركة Qixuan Software (深圳启煊软件)</a></p>
<p align="center">مساعد برمجة بالذكاء الاصطناعي مفتوح المصدر لأنظمة Linux المبنية على RISC-V</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.ar.md">العربية</a>
</p>

---

## نظرة عامة

يُرحِّل هذا المشروع [OpenCode](https://github.com/anomalyco/opencode) إلى **riscv64 Linux**. نظرًا لأن بيئة تشغيل [Bun](https://bun.sh) الأصلية لا تدعم RISC-V، يُستخدم **Node.js 22+** مع polyfill لواجهة برمجة Bun.

## البدء السريع

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

بعد البناء:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "اكتب خوارزمية الفرز الفقاعي"
./dist-riscv/bin/opencode serve
```

## حالة الميزات

| الميزة | الحالة |
|--------|--------|
| `opencode run` الوضع غير التفاعلي | ✅ |
| `opencode serve` خادم API | ✅ |
| `opencode session` إدارة الجلسات | ✅ |
| `opencode mcp` بروتوكول MCP | ✅ |
| `opencode --mini` واجهة TUI | ❌ يتطلب Bun |

## المنصة المستهدفة

- المعمارية: riscv64
- نظام التشغيل: Linux (Debian/Ubuntu، RockOS، ESWIN EIC7x، إلخ)
- بيئة التشغيل: Node.js 22.12.0 (مُجمَّعة من المصدر)

## الترخيص

MIT — المشروع الأصلي بواسطة [Anomaly](https://github.com/anomalyco/opencode)
