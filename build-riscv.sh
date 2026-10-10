#!/usr/bin/env bash
# build-riscv.sh — 在 riscv64 Ubuntu/Debian 上构建并运行 opencode
#
# 核心思路：
#   - Bun 不支持 riscv64，改用 Node.js 22+ 直接运行 TypeScript 源码（通过 tsx）
#   - 在入口注入 Bun polyfill，使少量 Bun.* 调用在 Node.js 下工作
#   - @opentui/core（TUI 框架）依赖 Bun 内置 API，interactive --mini 模式不可用
#   - opencode run / opencode serve 等非交互命令完全可用
#
# 用法：bash build-riscv.sh
# 目标：Linux riscv64，Debian/Ubuntu，Node.js >= 20
# 注意：Node.js 22 的 V8 版本过新，Clang 19 和 GCC 13/14 在此平台均有 crash；使用 Node.js 20 LTS

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="$REPO_DIR/dist-riscv"

log()  { printf '\033[1;32m[riscv]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[riscv]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[riscv]\033[0m ERROR: %s\n' "$*" >&2; exit 1; }

# ── 函数定义（必须在调用点之前）──────────────────────────────────────────────

check_node() {
  command -v node &>/dev/null || return 1
  local major
  major=$(node -e "process.stdout.write(String(process.versions.node.split('.')[0]))" 2>/dev/null) || return 1
  (( major >= 20 ))
}

build_node_from_source() {
  # GCC 13/14 在此 riscv64 平台（RockOS/ESWIN）上编译 Node.js 时均触发 ICE（Segmentation Fault）
  # Clang 18/19 在 riscv64 上编译 V8 builtins（CSA 生成代码）时也有 crash bug
  # Clang 17 是目前在此平台编译 V8 最稳定的版本
  if ! command -v clang-17 &>/dev/null; then
    log "未找到 Clang 17，尝试安装..."
    sudo apt-get install -y clang-17 || \
      die "无法安装 Clang 17。请手动执行: sudo apt-get install clang-17"
  fi
  log "使用 Clang 17 编译 Node.js：$(clang-17 --version | head -1)"

  # 用 update-alternatives 把系统 gcc/g++ 指向 clang-17/clang++-17
  # 优先级 99 高于默认 GCC，编译完后恢复
  local clang_bin clangpp_bin
  clang_bin="$(which clang-17)"
  clangpp_bin="$(which clang++-17)"
  sudo update-alternatives --install /usr/bin/gcc gcc "$clang_bin"   99
  sudo update-alternatives --install /usr/bin/g++ g++ "$clangpp_bin" 99
  log "编译器已切换: gcc -> $(gcc --version | head -1)"

  # Node.js 22 的 V8 版本过新，Clang 19 和 GCC 13/14 在 riscv64 上编译时均有 crash bug
  # Node.js 20 LTS（V8 11.x）代码复杂度更低，在 riscv64 上编译稳定
  local ver="20.19.2"
  log "从源码编译 Node.js $ver（预计 60-90 分钟）..."
  local tmp
  tmp="$(mktemp -d)"
  # 无论成功还是失败，退出时都清理临时目录，避免占满磁盘
  trap 'sudo rm -rf "$tmp"' RETURN
  log "下载 Node.js $ver 源码..."
  curl -fsSL "https://nodejs.org/dist/v${ver}/node-v${ver}.tar.gz" | tar -xz -C "$tmp"
  pushd "$tmp/node-v${ver}" > /dev/null
  ./configure --prefix=/usr/local --openssl-no-asm
  make -j"$(nproc)"
  sudo make install
  popd > /dev/null

  # 恢复系统 gcc/g++ 为原来的 GCC
  sudo update-alternatives --remove gcc "$clang_bin"
  sudo update-alternatives --remove g++ "$clangpp_bin"
  log "编译器已恢复: gcc -> $(gcc --version | head -1)"
}

rebuild_native_module() {
  local mod="$1"
  local found=0
  for search_dir in \
    "$REPO_DIR/node_modules/$mod" \
    "$REPO_DIR/packages/core/node_modules/$mod" \
    "$REPO_DIR/packages/opencode/node_modules/$mod"
  do
    [[ -f "$search_dir/package.json" ]] || continue
    found=1
    log "  重建 $mod"
    pushd "$search_dir" > /dev/null
    if [[ -f "binding.gyp" ]]; then
      node-gyp rebuild 2>&1 | tail -5 || warn "  $mod 重建失败，该功能将降级"
    fi
    popd > /dev/null
  done
  [[ $found -eq 1 ]] || warn "  $mod 未找到，跳过"
}

# ── 0. 架构检查 ────────────────────────────────────────────────────────────────
[[ "$(uname -m)" == "riscv64" ]] || die "请在 riscv64 机器上运行"

# ── 1. 安装系统依赖 ────────────────────────────────────────────────────────────
log "安装系统依赖..."
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
  curl git ca-certificates unzip \
  build-essential python3 python3-pip \
  libssl-dev libffi-dev libudev-dev libsqlite3-dev \
  pkg-config

# ── 2. 确保 Node.js >= 20 ─────────────────────────────────────────────────────
if check_node; then
  log "已有 Node.js $(node --version)，跳过安装"
else
  log "安装 Node.js 20..."
  # 优先尝试 ESWIN/RockOS 官方仓库的预编译包（esos-base 提供 nodejs 20.17.0 riscv64）
  if apt-cache show nodejs 2>/dev/null | grep -q "Version: 2[0-9]"; then
    log "检测到官方仓库有 Node.js 预编译包，直接安装..."
    sudo apt-get install -y nodejs
    # Debian 的 nodejs 包不附带 npm，需单独安装
    sudo apt-get install -y npm || true
  else
    log "官方仓库无合适版本，尝试 NodeSource..."
    # NodeSource 不支持 riscv64，预期失败，用 || true 吸收错误
    nodesource_ok=0
    if curl -fsSL https://deb.nodesource.com/setup_20.x 2>/dev/null | sudo -E bash - 2>/dev/null; then
      sudo apt-get install -y nodejs 2>/dev/null && check_node && nodesource_ok=1 || true
    fi

    if [[ $nodesource_ok -eq 0 ]]; then
      log "NodeSource 不支持 riscv64，从源码编译..."
      build_node_from_source
    fi
  fi
fi

check_node || die "Node.js >= 20 安装失败，当前: $(node --version 2>/dev/null || echo '未安装')"

# npm 在 Debian 系统里是独立包，Node.js 装好后不一定附带
if ! command -v npm &>/dev/null; then
  log "npm 未找到，安装..."
  sudo apt-get install -y npm || die "npm 安装失败，请手动执行: sudo apt-get install npm"
fi
log "Node.js: $(node --version) | npm: $(npm --version)"

# ── 3. 安装 tsx（TypeScript 直接执行器）─────────────────────────────────────
if ! command -v tsx &>/dev/null; then
  log "全局安装 tsx..."
  sudo npm install -g tsx@latest
fi
log "tsx: $(tsx --version 2>/dev/null || echo 'ok')"

# ── 4. 安装项目依赖 ───────────────────────────────────────────────────────────
cd "$REPO_DIR"
log "安装项目依赖..."

# 项目 packageManager 写死为 bun，pnpm/npm 在项目根目录都会被拦截
# 临时移除 packageManager 字段，用 npm 安装依赖，完成后恢复
log "临时绕过 packageManager 限制..."
node -e "
const fs = require('fs');
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
delete pkg.packageManager;
fs.writeFileSync('package.json.orig', JSON.stringify({packageManager: pkg.packageManager || 'bun@1.3.14'}));
delete pkg.packageManager;
fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2));
" 2>/dev/null || warn "package.json 处理失败，继续尝试..."

npm install \
  --ignore-scripts \
  --legacy-peer-deps \
  --no-audit \
  --no-fund \
  2>&1 | tail -20 || warn "npm install 有部分警告，继续..."

# 恢复 package.json
node -e "
const fs = require('fs');
if (fs.existsSync('package.json.orig')) {
  const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
  const orig = JSON.parse(fs.readFileSync('package.json.orig', 'utf8'));
  if (orig.packageManager) pkg.packageManager = orig.packageManager;
  fs.writeFileSync('package.json', JSON.stringify(pkg, null, 2) + '\n');
  fs.unlinkSync('package.json.orig');
}
" 2>/dev/null || true

# ── 5. 重建原生 Node 模块 ──────────────────────────────────────────────────────
log "重建原生模块..."
sudo npm install -g node-gyp 2>/dev/null || true

rebuild_native_module "@parcel/watcher"    # 文件监听（可降级）
rebuild_native_module "@lydell/node-pty"   # 终端 PTY（shell 工具需要）
rebuild_native_module "@silvia-odwyer/photon-node"  # 图像处理（可选）

# ── 6. 生成 Bun polyfill ───────────────────────────────────────────────────────
mkdir -p "$OUT_DIR"
cat > "$OUT_DIR/bun-polyfill.mjs" << 'POLYFILL'
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
POLYFILL

log "Bun polyfill: $OUT_DIR/bun-polyfill.mjs"

# ── 7. 安装 string-width（供 polyfill 精确计算宽度）─────────────────────────
# 在 OUT_DIR 下单独安装，避免触发项目根的 catalog 协议限制
node -e "import('string-width')" &>/dev/null 2>&1 || {
  mkdir -p "$OUT_DIR"
  npm install --prefix "$OUT_DIR" string-width --no-save &>/dev/null || true
}

# ── 8. 生成启动脚本 ────────────────────────────────────────────────────────────
mkdir -p "$OUT_DIR/bin"

# 在构建时解析 tsx/esm 的绝对路径，写死到启动脚本，避免运行时路径查找问题
TSX_ESM_PATH="$(node -e "process.stdout.write(require.resolve('tsx/esm'))" 2>/dev/null)" || true
if [[ -z "${TSX_ESM_PATH:-}" ]]; then
  # 全局 tsx 的实际 ESM loader 路径（tsx v4.x 结构）
  TSX_ESM_PATH="$(npm root -g)/tsx/dist/esm/index.mjs"
  warn "tsx/esm 路径自动解析失败，使用兜底路径: $TSX_ESM_PATH"
fi
log "tsx/esm 路径: $TSX_ESM_PATH"

cat > "$OUT_DIR/bin/opencode" << LAUNCHER
#!/bin/bash
# opencode riscv64 launcher — 由 build-riscv.sh 生成
exec node \\
  --experimental-vm-modules \\
  --conditions=node \\
  --import "$OUT_DIR/bun-polyfill.mjs" \\
  --import "$TSX_ESM_PATH" \\
  "$REPO_DIR/packages/opencode/src/index.ts" \\
  "\$@"
LAUNCHER

chmod +x "$OUT_DIR/bin/opencode"
log "启动脚本: $OUT_DIR/bin/opencode"

# 可选全局安装
if [[ "${INSTALL_GLOBAL:-0}" == "1" ]]; then
  sudo ln -sf "$OUT_DIR/bin/opencode" /usr/local/bin/opencode
  log "已链接到 /usr/local/bin/opencode"
fi

# ── 9. 冒烟测试 ────────────────────────────────────────────────────────────────
log "运行冒烟测试..."
if "$OUT_DIR/bin/opencode" --version 2>&1 | grep -qE "[0-9]+\.[0-9]"; then
  log "✓ 冒烟测试通过"
else
  warn "冒烟测试未通过，请检查上方日志"
fi

# ── 10. 完成 ───────────────────────────────────────────────────────────────────
log ""
log "================================================="
log " 构建完成"
log "================================================="
log " 运行："
log "   $OUT_DIR/bin/opencode --help"
log "   $OUT_DIR/bin/opencode run '你的问题'"
log "   $OUT_DIR/bin/opencode serve"
log ""
log " 可用功能："
log "   ✓ run / serve / session / mcp 等非交互命令"
log "   ✗ --mini TUI 交互模式（依赖 Bun，不可用）"
log "   ~ 文件监听（@parcel/watcher 编译失败则降级）"
log ""
log " 全局安装："
log "   INSTALL_GLOBAL=1 bash build-riscv.sh"
log "================================================="
