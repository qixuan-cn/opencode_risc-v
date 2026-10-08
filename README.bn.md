<h1 align="center">RISC-V এর জন্য OpenCode</h1>

<p align="center"><a href="https://www.qixuan.vip">Qixuan Software (深圳启煊软件)</a> কর্তৃক <a href="https://github.com/anomalyco/opencode">OpenCode</a> এর উপর ভিত্তি করে তৈরি RISC-V সংস্করণ</p>
<p align="center">RISC-V নির্দেশ সেটের Linux সিস্টেমের জন্য ওপেন সোর্স AI প্রোগ্রামিং সহকারী</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.bn.md">বাংলা</a>
</p>

---

## পরিচিতি

এই প্রকল্পটি [OpenCode](https://github.com/anomalyco/opencode) কে **riscv64 Linux** এ পোর্ট করে। মূল [Bun](https://bun.sh) রানটাইম RISC-V সমর্থন না করায়, Bun API পলিফিল সহ **Node.js 22+** ব্যবহার করা হয়।

## দ্রুত শুরু

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

বিল্ডের পর:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "বাবল সর্ট অ্যালগরিদম লিখুন"
./dist-riscv/bin/opencode serve
```

## ফিচার স্ট্যাটাস

| ফিচার | স্ট্যাটাস |
|-------|----------|
| `opencode run` নন-ইন্টারেক্টিভ মোড | ✅ |
| `opencode serve` API সার্ভার | ✅ |
| `opencode session` সেশন ম্যানেজমেন্ট | ✅ |
| `opencode mcp` MCP প্রোটোকল | ✅ |
| `opencode --mini` TUI ইন্টারফেস | ❌ Bun প্রয়োজন |

## লক্ষ্য প্ল্যাটফর্ম

- আর্কিটেকচার: riscv64
- OS: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x ইত্যাদি)
- রানটাইম: Node.js 22.12.0 (সোর্স থেকে কম্পাইল)

## লাইসেন্স

MIT — মূল প্রকল্প [Anomaly](https://github.com/anomalyco/opencode) কর্তৃক
