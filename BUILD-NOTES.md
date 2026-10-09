# Node.js riscv64 编译踩坑记录

> 平台：ESWIN EIC7x，RockOS（基于 Debian），内核 6.6.138，GCC 14.2.0

---

## 问题一：NodeSource 不支持 riscv64

**现象**
```
Error: Unsupported architecture: riscv64. Only amd64, arm64 are supported.
```

**结论**：NodeSource 官方不提供 riscv64 预编译包，必须从源码编译。

---

## 问题二：OpenSSL 配置用了 x86_64 路径导致 `-m64` 错误（Node.js 22.16.0）

**现象**
```
cc: error: unrecognized command-line option '-m64'
```

**原因**：Node.js 的 OpenSSL configure 脚本未正确识别 riscv64，默认使用了 `linux-x86_64` 的 arch 配置，编译参数里带入了 x86 专用的 `-m64`。

**解决方案**：在 `./configure` 时加 `--openssl-no-asm`，跳过平台汇编优化：
```bash
./configure --prefix=/usr/local --openssl-no-asm
```

---

## 问题三：Node.js 22.12.0 与 GCC 14 libstdc++ 不兼容

**现象**（`heap_utils.cc`）
```
error: cannot convert 'iterator' to '__node_ptr'
../src/heap_utils.cc:93: required from here
```

**原因**：`heap_utils.cc` 中 `_Scoped_node` 的构造函数参数类型在 GCC 14 的 libstdc++ 下推导出错，是 Node.js 22.12.0 源码与 GCC 14 的已知兼容性问题。

**解决方案**：升级到 Node.js **22.14.0**，该版本修复了此问题。

---

## 问题四：GCC 14 在 riscv64 上编译 Node.js 时触发 ICE（Segmentation Fault）

**现象**（多个文件，包括 `instruction-selector.cc`、`node.cc`）
```
internal compiler error: Segmentation fault
```

**原因**：GCC 14 自身的 bug，在 riscv64 架构下编译复杂 C++20 模板代码（V8、Node.js 核心）时，GCC 的 GGC（garbage collection）模块触发 Segfault。与 Node.js 版本无关，与优化级别（-O2/-O3）也无关，是 GCC 14 本身的缺陷。

**解决方案**：使用 **GCC 13** 编译：
```bash
sudo apt-get install -y gcc-13 g++-13
export CC=gcc-13
export CXX=g++-13
./configure --prefix=/usr/local --openssl-no-asm
make -j$(nproc)
sudo make install
```

`build-riscv.sh` 已自动处理：检测到 `gcc-13` 则自动使用，否则先安装再使用。

---

## 最终可用的编译配置

| 项目 | 值 |
|------|-----|
| Node.js 版本 | 22.14.0 |
| 编译器 | GCC 13（`gcc-13` / `g++-13`） |
| 关键 configure 参数 | `--openssl-no-asm` |
| 系统 | RockOS (Debian) riscv64，内核 6.6.x |

**完整编译命令**：
```bash
sudo apt-get install -y gcc-13 g++-13
export CC=gcc-13 CXX=g++-13
curl -fsSL https://nodejs.org/dist/v22.14.0/node-v22.14.0.tar.gz | tar -xz
cd node-v22.14.0
./configure --prefix=/usr/local --openssl-no-asm
make -j$(nproc)
sudo make install
```

---

## 版本演变记录

| 尝试版本 | 结果 | 失败原因 |
|----------|------|----------|
| Node.js 22.16.0 + GCC 14 | ❌ | OpenSSL `-m64` 错误 |
| Node.js 22.12.0 + GCC 14 | ❌ | `heap_utils.cc` 类型错误 + GCC 14 ICE |
| Node.js 22.14.0 + GCC 14 | ❌ | GCC 14 ICE（`node.cc` / `instruction-selector.cc`） |
| Node.js 22.14.0 + GCC 13 | ✅ | 编译通过 |
