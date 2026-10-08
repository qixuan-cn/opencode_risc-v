<h1 align="center">OpenCode RISC-V 버전</h1>

<p align="center"><a href="https://www.qixuan.vip">Qixuan Software(深圳启煊软件)</a>가 <a href="https://github.com/anomalyco/opencode">OpenCode</a> 기반으로 개발한 RISC-V 포팅 버전</p>
<p align="center">RISC-V 명령어 세트 Linux 시스템용 오픈소스 AI 코딩 어시스턴트</p>

<p align="center">
  <a href="README.md">中文</a> | <a href="README.en.md">English</a> | <a href="README.ko.md">한국어</a>
</p>

---

## 개요

[OpenCode](https://github.com/anomalyco/opencode)를 **riscv64 Linux**용으로 포팅한 프로젝트입니다. 원본이 의존하는 [Bun](https://bun.sh) 런타임이 RISC-V를 지원하지 않으므로, **Node.js 22+** 를 사용하고 Bun API 폴리필로 호환성을 유지합니다.

## 빠른 시작

```bash
git clone https://github.com/qixuan-cn/opencode_risc-v.git
cd opencode_risc-v
bash build-riscv.sh
```

빌드 후:

```bash
./dist-riscv/bin/opencode --help
./dist-riscv/bin/opencode run "버블 정렬 코드 작성해줘"
./dist-riscv/bin/opencode serve
```

## 기능 현황

| 기능 | 상태 |
|------|------|
| `opencode run` 비대화형 모드 | ✅ |
| `opencode serve` API 서버 | ✅ |
| `opencode session` 세션 관리 | ✅ |
| `opencode mcp` MCP 프로토콜 | ✅ |
| `opencode --mini` TUI | ❌ Bun 필요 |

## 대상 플랫폼

- 아키텍처: riscv64
- OS: Linux (Debian/Ubuntu, RockOS, ESWIN EIC7x 등)
- 런타임: Node.js 22.12.0 (소스 빌드)

## 라이선스

MIT — 원본 프로젝트: [Anomaly](https://github.com/anomalyco/opencode)
