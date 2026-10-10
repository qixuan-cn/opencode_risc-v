# Node.js riscv64 编译踩坑记录

> 平台：ESWIN EIC7x，RockOS（基于 Debian），内核 6.6.138  
> 编译目标：为 opencode 项目提供可用的 Node.js 运行时（Bun 不支持 riscv64）

---

## 问题一：NodeSource 不支持 riscv64

**现象**
```
Error: Unsupported architecture: riscv64. Only amd64, arm64 are supported.
```

**结论**：NodeSource 官方不提供 riscv64 预编译包，必须从源码编译。`build-riscv.sh` 已自动处理：先尝试 NodeSource，失败后转入源码编译流程。

---

## 问题二：OpenSSL 配置用了 x86_64 路径导致 `-m64` 错误

**现象**
```
cc: error: unrecognized command-line option '-m64'
```

**原因**：Node.js 的 OpenSSL configure 脚本未正确识别 riscv64，默认使用了 `linux-x86_64` 的 arch 配置，编译参数里带入了 x86 专用的 `-m64`。

**解决方案**：`./configure` 加 `--openssl-no-asm`，跳过平台汇编优化：
```bash
./configure --prefix=/usr/local --openssl-no-asm
```

---

## 问题三：Node.js 22.12.0 与 GCC 14 libstdc++ 不兼容

**现象**（`heap_utils.cc`）
```
error: cannot convert 'iterator' to '__node_ptr'
```

**原因**：`heap_utils.cc` 中 `_Scoped_node` 构造函数参数类型在 GCC 14 的 libstdc++ 下推导出错，是 Node.js 22.12.0 源码与 GCC 14 的已知兼容性问题。

**解决方案**：升级到 Node.js **22.14.0**，该版本修复了此问题。

---

## 问题四：RockOS 定制 GCC 13/14 均触发 ICE（Segmentation Fault）

**现象**（`streams.cc`、`env.cc`、`instruction-selector.cc` 等多个文件）
```
internal compiler error: Segmentation fault
0x47ec0a ggc_set_mark(void const*)
...
```

**原因**：RockOS/ESWIN 定制的 GCC 包（`gcc-13 13.3.0-6`、`gcc-14 14.2.0-19rockos1`）在 riscv64 上编译复杂 C++20 模板代码时，GCC 的 GGC（garbage collector）模块触发 Segfault。两个版本均受影响，与 Node.js 版本和优化级别无关。

**结论**：放弃 GCC，改用 Clang。

---

## 问题五：Node.js configure (gyp) 不读取 CC/CXX 环境变量

**现象**：设置 `export CC=gcc-13` 后运行 `./configure`，生成的 Makefile 里编译器仍是系统默认 `gcc`（GCC 14），make 时依然触发 ICE。

**原因**：Node.js 的 `./configure` 是 Python/gyp 脚本，有自己的编译器查找逻辑，**完全忽略** shell 环境里的 `CC`/`CXX` 环境变量。

**也不能用 `--cc`/`--cxx` 参数**：gyp 把这两个参数当作配置文件路径处理，不是编译器路径，会报：
```
gyp: --cc=gcc-13 not found (cwd: ...) while trying to load --cc=gcc-13
```

**正确方式**：用 `update-alternatives` 在系统级切换 `gcc`/`g++` 指向 clang，让 gyp 查找到的 `gcc` 就是 clang：
```bash
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/clang-17 99
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/clang++-17 99
```

---

## 问题六：Clang 19.1.7 在 riscv64 上编译 V8 builtins 时 crash

**现象**（`type-assertions-phase.cc`、`builtins-array.cc`、`builtins-array-gen.cc` 等）
```
PLEASE submit a bug report to https://github.com/llvm/llvm-project/issues/
clang frontend command failed with exit code 139
Stack dump:
  llvm::InstCombinePass::run / clang::ASTContext::ReleaseDeclContextMaps ...
```

**原因**：Clang 19.1.7（Debian 包）在 riscv64 上处理 V8 的 CSA（CodeStubAssembler）生成代码和复杂模板时，LLVM 后端（instcombine pass / ASTContext）存在 crash bug。  
**Node.js 20 LTS 也受影响**（`builtins-array-gen.cc`），说明问题在 Clang 19 本身，不在 Node.js 版本。

**结论**：Clang 19 不可用，改用 **Clang 17**。

---

## 问题七：Node.js 版本选择

**Node.js 22 放弃原因**：V8 版本过新（V8 12.x），引入大量 C++20 复杂模板（turboshaft、torque 生成代码），在此平台的 GCC 13/14 和 Clang 18/19 上均触发编译器 crash。

**Node.js 20 LTS 选用原因**：
- V8 版本为 11.x，代码复杂度相对较低
- 满足 `node:sqlite` 需要 22.5+ 的要求吗？—— **不满足**，但 opencode 的 `build-riscv.sh` 方案通过 tsx 直接运行 TypeScript 源码，规避了 sqlite 原生模块的依赖，Node.js 20 足够
- `check_node` 门槛已相应降低为 `>= 20`

**当前使用版本**：Node.js **20.19.2**

---

## 问题八：磁盘空间不足（`No space left on device`）

**现象**：每次编译失败后 `/tmp/tmp.xxxxx/` 目录残留，每个约 1-3GB，多次累积后磁盘耗尽。

**解决方案**：
```bash
sudo rm -rf /tmp/tmp.*
```

`build-riscv.sh` 已加入 `trap 'sudo rm -rf "$tmp"' RETURN`，无论成功失败均自动清理。

---

## 问题九：ESWIN 官方仓库直接提供 Node.js 20 预编译包

**发现**：花费大量时间尝试从源码编译 Node.js（GCC 13/14 ICE、Clang 17/18/19 各种 crash）之后，查询本机 apt 仓库发现：

```
apt-cache show nodejs
Version: 20.17.0+dfsg-2
Filename: pool/main/n/nodejs/nodejs_20.17.0+dfsg-2_riscv64.deb
```

ESWIN 的 `esos-base` 仓库已经提供了针对 riscv64 的 Node.js 20.17.0 预编译包，**完全不需要从源码编译**。

**解决方案**：
```bash
sudo apt-get install -y nodejs
node --version  # v20.17.0
```

**教训**：在尝试从源码编译之前，应先检查系统仓库是否已有预编译包。`build-riscv.sh` 已更新，优先检测并使用官方仓库包，源码编译作为最后的兜底手段。

**为什么 ESWIN 官方包能编译成功而本机不行？**

ESWIN 官方包是在 x86_64 服务器上**交叉编译**出来的，使用专门为 riscv64 目标配置的上游工具链，编译器质量和测试充分度远高于 RockOS 本机移植的 GCC/Clang 包。本机 native 编译遇到的所有 ICE 和 crash，都是 Debian riscv64 移植版编译器在处理 V8 极端复杂 C++ 模板代码时暴露的 bug，交叉编译环境不存在这些问题。因此**本机 native 编译 Node.js 在此平台目前不可行**，应直接使用官方预编译包。

---

## 当前编译配置（最终有效）

| 项目 | 值 |
|------|-----|
| Node.js 获取方式 | **`apt-get install nodejs`**（esos-base 仓库） |
| Node.js 版本 | **20.17.0** |
| 无需源码编译 | ✅ |
| 系统 | RockOS (Debian) riscv64，内核 6.6.x |

**手动编译命令**（脚本自动执行，无需手动）：
```bash
sudo apt-get install -y clang-17
sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/clang-17 99
sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/clang++-17 99
gcc --version  # 确认显示 clang version 17.x

curl -fsSL https://nodejs.org/dist/v20.19.2/node-v20.19.2.tar.gz | tar -xz
cd node-v20.19.2
./configure --prefix=/usr/local --openssl-no-asm
make -j$(nproc)
sudo make install
node --version  # 预期: v20.19.2

# 编译完恢复系统 gcc
sudo update-alternatives --remove gcc /usr/bin/clang-17
sudo update-alternatives --remove g++ /usr/bin/clang++-17
```

---

## 版本演变完整记录

| 尝试组合 | 结果 | 失败原因 |
|----------|------|----------|
| Node.js 22.16.0 + GCC 14 | ❌ | OpenSSL `-m64` 错误（问题二） |
| Node.js 22.12.0 + GCC 14 | ❌ | `heap_utils.cc` 类型错误（问题三） |
| Node.js 22.14.0 + GCC 14 | ❌ | GCC 14 ggc ICE（问题四） |
| Node.js 22.14.0 + GCC 13 (RockOS) | ❌ | GCC 13 ggc ICE，同问题四 |
| Node.js 22.14.0 + Clang 19（PATH fake-bin） | ❌ | fake-bin 方案未生效，仍用 g++-13 |
| Node.js 22.14.0 + Clang 19（update-alternatives） | ❌ | Clang 19 instcombine crash（问题六） |
| Node.js 20.19.2 + Clang 19（update-alternatives） | ❌ | Clang 19 ASTContext crash，同问题六 |
| Node.js 20.19.2 + Clang 17（update-alternatives） | 🔄 | **进行中** |
| Node.js 20.17.0 + apt 预编译包（esos-base） | ✅ | **直接安装，无需编译** |

---

## 关键教训

1. **`CC`/`CXX` 对 Node.js configure 无效**，必须用 `update-alternatives` 系统级切换编译器
2. **gyp 的 `--cc`/`--cxx` 是文件路径参数**，不是编译器参数，不能传命令名或路径
3. **RockOS 上 GCC 13/14 均不可用于编译 V8**，两个版本都有 ggc crash
4. **Clang 19 在此平台编译 V8 不可用**，应使用 Clang 17
5. **Node.js 22 的 V8 过于复杂**，在此平台编译器均无法稳定处理；Node.js 20 LTS 是更稳妥的选择
6. **编译失败后 `/tmp` 目录不会自动清理**，多次重试前先手动 `sudo rm -rf /tmp/tmp.*`
7. **先查 apt 仓库**：`apt-cache show nodejs` 确认有无预编译包，再考虑源码编译。ESWIN esos-base 仓库已提供 Node.js 20.17.0 riscv64，完全不需要源码编译
