// bun-polyfill.mjs — 在 Node.js 下模拟 opencode 实际用到的 Bun global API
// 覆盖范围：Bun.stdin.text, Bun.hash, Bun.stringWidth, Bun.file, Bun.env

import { createReadStream } from "node:fs"
import { createHash } from "node:crypto"

if (typeof globalThis.Bun !== "undefined") {
  // 已由真实 Bun 设置，不覆盖
  process.exit(0)
}

// stringWidth: 终端宽度计算（仅 --mini TUI 模式用到，此处同步近似即可）
let _stringWidth = null
async function loadStringWidth() {
  if (_stringWidth) return
  try {
    const mod = await import("string-width")
    _stringWidth = mod.stringWidth ?? mod.default
  } catch {
    _stringWidth = (s) => [...(s ?? "")].length
  }
}
// 启动时异步预加载，不阻塞主流程
loadStringWidth().catch(() => {})

// Bun.hash — opencode 只用它做缓存 key，无密码学要求
function bunHash(input) {
  const hex = createHash("sha256").update(String(input)).digest("hex")
  return BigInt("0x" + hex.slice(0, 16))
}

// Bun.stdin.text() — 在 run.ts 和 tui.ts 的非 TTY 路径下被调用
async function stdinText() {
  if (process.stdin.isTTY) return ""
  const chunks = []
  for await (const chunk of process.stdin) chunks.push(chunk)
  return Buffer.concat(chunks).toString("utf8")
}

globalThis.Bun = {
  version: "0.0.0-riscv-polyfill",

  stdin: {
    text: stdinText,
    stream() { return process.stdin },
  },

  stdout: {
    write(data) { return process.stdout.write(data) },
  },

  // Bun.file() shim — 返回与 BunFile 接口兼容的对象
  file(filePath, _opts) {
    return {
      async text() {
        const { readFile } = await import("node:fs/promises")
        return readFile(filePath, "utf8")
      },
      async json() {
        const { readFile } = await import("node:fs/promises")
        return JSON.parse(await readFile(filePath, "utf8"))
      },
      async exists() {
        const { access } = await import("node:fs/promises")
        return access(filePath).then(() => true, () => false)
      },
      async write(data) {
        const { writeFile } = await import("node:fs/promises")
        return writeFile(filePath, data)
      },
      stream() { return createReadStream(filePath) },
    }
  },

  hash: bunHash,

  // stringWidth — 同步近似；若已加载则用精确值
  stringWidth(s) {
    if (_stringWidth) return _stringWidth(s)
    loadStringWidth().catch(() => {})
    return [...(s ?? "")].length
  },

  env: process.env,
  $: undefined,   // shell tag template，只在构建脚本里用
}
