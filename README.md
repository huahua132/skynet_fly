<div align="center">
<img width="512" height="512" alt="bcgpt_103248334_gemini-2 5-flash-image_img2img_605126473_1024x1024" src="https://github.com/user-attachments/assets/87fd9f9c-093a-42d9-a880-ca642a457419" />

**致力于服务端对 skynet 的最佳实践**

[![GitHub stars](https://img.shields.io/github/stars/huahua132/skynet_fly?style=flat-square)](https://github.com/huahua132/skynet_fly/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/huahua132/skynet_fly?style=flat-square)](https://github.com/huahua132/skynet_fly/network)
[![License](https://img.shields.io/github/license/huahua132/skynet_fly?style=flat-square)](LICENSE)

[📖 使用文档](https://huahua132.github.io/2023/02/25/skynet_fly_word/word_1/A_home/) | [🎮 示例项目](https://github.com/huahua132/skynet_fly_demo) | [📚 API文档](https://huahua132.github.io/2023/12/17/skynet_fly_api/module/)

</div>

---

> 💡 **觉得不错，不妨点个 Star 吧！你的 Star 是作者持续创作维护的最大动力！**

## 📋 目录

- [社区交流](#-社区交流)
- [项目简介](#-项目简介)
- [核心特性](#-核心特性)
- [快速开始](#-快速开始)
- [编译安装](#️-编译安装)
- [第三方依赖](#-第三方依赖)
- [项目示例](#-项目示例)

---

## 💬 社区交流

**QQ 交流群：102993581**

📌 **镜像仓库**：[网络不好可以去 Gitee Clone](https://gitee.com/huaa/skynet_fly)

---

## 🎯 项目简介

**skynet_fly** 是基于 [skynet](https://github.com/cloudwu/skynet) 扩展的高性能游戏服务器框架，专注于快速开发 Web 服务、游戏服务器及需要 RPC 调用的分布式系统。

### 🏗️ 技术架构

基于 [skynet](https://github.com/huahua132/skynet.git) 自维护版本，针对服务端开发做了深度优化和扩展。

---

## ✨ 核心特性

### 🔥 热更新系统
- ✅ 支持不停服更新
- ✅ 一键生成配置文件和运维脚本
- ✅ 完善的热更新机制，确保服务平滑过渡

### 🎮 游戏开发
- ✅ Gate/WebSocket Gate 基础设施封装
- ✅ 支持 Protobuf、JSON、Sproto 多种协议
- ✅ 房间匹配系统完整实现
- ✅ 开箱即用的游戏业务框架

### 🗄️ 数据持久化
- ✅ **ORM 对象关系映射**
  - 支持 MySQL、MongoDB 等多种数据库
  - 数据库无缝切换
  - 智能缓存策略，提升性能
  - CRUD 操作简单高效
- ✅ Redis、MySQL、Timer、Log 使用封装

### 🔧 分布式支持
- ✅ 远程 RPC 调用
- ✅ 远程 Sub/Pub 消息订阅
- ✅ 远程 SubSync/PubSync 同步订阅
- ✅ 服务发现机制

### 🌐 HTTP 服务
- ✅ HTTP 长连接支持
- ✅ 路由与中间件模式
- ✅ JWT 鉴权集成

### 🛠️ 开发工具
- ✅ 内置日志分割
- ✅ 时间快进功能（测试神器）
- ✅ 断点调试支持
- ✅ Lua 代码加密

### 📹 **服务录像与重放**
- ✅ 服务行为完整录制
- ✅ 录像重放调试
- ✅ 快速定位复杂 Bug
- ✅ 自动热更记录和共享配置管理

> 📖 [详细了解热更新实现](https://huahua132.github.io/2023/06/30/skynet_fly_ss/%E5%85%B3%E4%BA%8Eskynet_fly%E7%83%AD%E6%9B%B4%E6%96%B0%E5%AE%9E%E7%8E%B0/)  
> 📖 [一键构建服务配置](https://huahua132.github.io/2023/06/30/skynet_fly_ss/%E5%85%B3%E4%BA%8Eskynet_fly%E7%9A%84%E4%B8%80%E9%94%AE%E6%9E%84%E5%BB%BA%E6%9C%8D%E5%8A%A1%E9%85%8D%E7%BD%AE/)

---

## ⚡ 快速开始

### 示例 1：简单热更新服务

运行 `examples/AB_question` 示例，演示 A 服务向 B 服务发送消息并接收回应。

#### 📦 构建服务


```bash
cd examples/AB_question/
sh ../../binshell/make_server.sh ../../

```

#### ▶️ 运行服务


```bash
sh make/script/run.sh load_mods.lua 0

```

#### 📝 代码示例

**A 服务发送消息：**


```lua
function CMD.send_msg_to_b()
    -- 简单轮询负载均衡
    for i = 1, 4 do
        local ret = container_client:instance("B_m"):balance_call("hello")
        log.info("balance_call send_msg_to_b:", i, ret)
    end
    
    -- 模除映射方式（固定服务）
    for i = 1, 4 do
        local ret = container_client:instance("B_m"):set_mod_num(1):mod_call("hello")
        log.info("mod_call send_msg_to_b:", i, ret)
    end
    
    -- 广播到所有 B_m 服务
    local ret = container_client:instance("B_m"):broadcast_call("hello")
    log.info("broadcast_call:", ret)
end

```

**B 服务响应：**


```lua
function CMD.hello()
    return "HELLO A, I am " .. skynet.address(skynet.self())
end

```

#### 🔄 热更新测试

1. 修改 `B_m.lua` 文件
2. 执行热更新脚本：


```bash
sh make/script/check_reload.sh load_mods.lua

```

旧服务将在确认无访问者后优雅退出，新服务无缝接管请求。

---

### 示例 2：房间类游戏

运行 `examples/digitalbomb` 数字炸弹游戏示例。

#### 📦 构建并运行


```bash
cd examples/digitalbomb/
sh ../../binshell/make_server.sh ../../
sh make/script/run.sh load_mods.lua 0

```

#### 🎯 特性展示

- ✅ 基于 TCP 长连接
- ✅ 支持不停服更新
- ✅ 登录、大厅、匹配、游戏模块解耦
- ✅ 内置测试客户端

**可热更新模块：**
- `hall` - 大厅服务
- `alloc` - 分配服务  
- `table` - 桌子服务

---

### 示例 3：HTTP 服务

运行 `examples/webapp` Web 应用示例。

#### 📦 构建服务


```bash
cd examples/webapp/
sh ../../binshell/make_server.sh ../../

```

生成的运维脚本：
- `run.sh` - 启动服务
- `stop.sh` - 停止服务
- `restart.sh` - 重启服务
- `reload.sh` - 热更新模块
- `check_reload.sh` - 检测并热更新
- `fasttime.sh` - 时间快进

#### ▶️ 运行服务


```bash
# 前台运行
sh make/script/run.sh load_mods.lua 0

# 后台运行
sh make/script/run.sh load_mods.lua

```

#### 🌐 访问测试

浏览器打开：`http://x.x.x.x:8688`

#### 🔄 热更新


```bash
# 1. 修改代码
vim webapp/lualib/webapp_dispatch.lua

# 2. 执行热更新
sh make/script/check_reload.sh load_mods.lua

```

---

## 🛠️ 编译安装

### Linux 环境


```bash
# 1. 克隆项目
git clone https://github.com/huahua132/skynet_fly

# 2. 安装依赖（根据系统选择）
sh install_centos.sh
# 或
sh install_ubuntu.sh

# 3. 编译
make linux

```

### Windows 环境

基于 [Visual Studio 2022](https://visualstudio.microsoft.com/zh-hans/downloads/)，需要安装：
- [CMake 模块](https://learn.microsoft.com/en-us/cpp/build/cmake-projects-in-visual-studio?view=msvc-170)
- [Clang 模块](https://learn.microsoft.com/en-us/cpp/build/clang-support-cmake?view=msvc-170)

**OpenSSL 配置：**

如果链接出错，请下载 [OpenSSL](https://slproweb.com/products/Win32OpenSSL.html) 完整版 MSI 安装包，替换 `win3rd/include` 和 `win3rd/lib` 目录。

> 💡 参考 [Pluto 项目](https://github.com/cloudfreexiao/pluto) 的编译方式

---

## 📦 第三方依赖

| 组件 | 版本 | 说明 |
|------|------|------|
| [skynet](https://github.com/huahua132/skynet.git) | latest | 自维护 Fork 版本 |
| [basexx](https://github.com/aiq/basexx) | 0.4.1 | Base 编码 |
| [lua-cjson](https://github.com/cloudwu/lua-cjson) | latest | JSON 解析 |
| [lua-openssl](https://github.com/zhaozg/lua-openssl) | 0.9.1-0 | OpenSSL 绑定 |
| [lua-protobuf](https://github.com/starwing/lua-protobuf) | 0.4.0 | Protobuf 支持 |
| [lua-radix-router](https://github.com/vm-001/lua-radix-router) | latest | 路由器 |
| [luafilesystem](https://github.com/lunarmodules/luafilesystem) | 1.8.0 | 文件系统 |
| [luajwtjitsi](https://github.com/jitsi/luajwtjitsi) | 3.0 | JWT（已适配 lua-openssl）|
| [lzlib](https://github.com/LuaDist/lzlib) | 0.4.3 | 压缩库 |
| [lua-zset](https://github.com/xjdrew/lua-zset) | latest | 有序集合 |
| [lua-snapshot](https://github.com/cloudwu/lua-snapshot) | latest | 快照工具 |
| [lua-socket](https://github.com/lunarmodules/luasocket) | latest | Socket 库 |
| [LuaPanda](https://github.com/Tencent/LuaPanda) | latest | 调试器 |
| [wlua](https://github.com/hanxi/wlua) | latest | Lua 工具 |

---

## 📚 项目示例

### 官方 Demo
🎮 [完整示例项目](https://github.com/huahua132/skynet_fly_demo)

### 完整项目案例
♟️ [中国象棋](https://github.com/huahua132/skynet_fly_demo) - 完整的在线对战游戏实现

---

## 🔗 扩展阅读

### 核心功能详解
- 📖 [ORM 数据映射详解](https://huahua132.github.io/2023/12/24/skynet_fly_ss/orm/)
  - 对象关系映射实现
  - 多数据库适配
  - 缓存策略优化
  
- 📖 [服务录像与重放](https://huahua132.github.io/2024/10/27/skynet_fly_word/word_3/S_record/)
  - 完整录制服务行为
  - 精准重放调试
  - Bug 快速定位

## 📄 License

本项目采用 MIT 协议开源，详见 [LICENSE](LICENSE) 文件。

---

<div align="center">

**如果这个项目对你有帮助，请给个 ⭐ Star 支持一下！**

Made with ❤️ by [huahua132](https://github.com/huahua132)

</div>

## 🙏 贡献者

感谢所有为 skynet_fly 做出贡献的开发者！

### 核心贡献者

<a href="https://github.com/huahua132/skynet_fly/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=huahua132/skynet_fly" />
</a>

### 特别感谢

感谢以下贡献者提交的 Pull Request，让项目变得更好：

- 🌟 所有提交 PR 的朋友
- 🐛 提交 Issue 和 Bug 报告的朋友
- 💡 提供建议和想法的朋友
- 📖 完善文档的朋友

### 如何贡献

我们欢迎所有形式的贡献！

1. 🍴 Fork 本项目
2. 🔨 创建你的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 💾 提交你的修改 (`git commit -m 'Add some AmazingFeature'`)
4. 📤 推送到分支 (`git push origin feature/AmazingFeature`)
5. 🎉 提交 Pull Request

**贡献指南：**
- 遵循项目的代码风格
- 提交前请测试你的代码
- 提供清晰的提交信息
---