# skynet_fly
---
致力于服务端对skynet的最佳实践

# skynet_fly简介
	skynet_fly是基于skynet扩展的可以快速开发web，游戏，和需要rpc调用的框架。
	使用skynet_fly的好处：
	* 支持不停服更新。
	* 一键生成skynet的配置文件和skynet_fly的配置文件以及配套shell脚本。
	* 对匹配房间类游戏做了gate,ws_gate的基础设施封装以及pb,json协议的支持，开发游戏只需要实现相关业务逻辑。
	* 对redis,mysql,timer,log 使用封装。
	* 后续支持rpc调用，以及服务发现。

* [关于skynet_fly热更新实现](https://huahua132.github.io/2023/06/30/skynet_fly/%E5%85%B3%E4%BA%8Eskynet_fly%E7%83%AD%E6%9B%B4%E6%96%B0%E5%AE%9E%E7%8E%B0/)
* [关于skynet_fly的一键构建服务配置](https://huahua132.github.io/2023/06/30/skynet_fly/%E5%85%B3%E4%BA%8Eskynet_fly%E7%9A%84%E4%B8%80%E9%94%AE%E6%9E%84%E5%BB%BA%E6%9C%8D%E5%8A%A1%E9%85%8D%E7%BD%AE/)

## 关于热更新方案

[热更新方案二的实现](https://huahua132.github.io/2023/05/22/think/reload/)
运行 **examples/hot_module2** 示例
运行 **examples/hot_module3** 示例

[热更新方案三的实现](https://huahua132.github.io/2023/05/22/think/reload/)
运行 **examples/hot_module4** 示例

## 快速开始 http服务 (运行examples/webapp)

1. 编译skynet 参考了涵曦的 [skynet_demo](https://github.com/hanxi/skynet-demo) 
    - `make build`
2. 构建skynet_config, mod_config, webapp运维脚本
    - `cd examples/webapp/`
    - `sh ../../binshell/make_server.sh ../../ webapp 4`
    - 如果一些顺利的话将会生成script文件夹，文件夹下有:
      - `run.sh` 运行并配置日志分割
      - `stop.sh` 停止
      - `restart.sh` 重启
      - `kill_mod.sh` 干掉某个可热更模块(不是强行kill，是通知服务可以退出了)
      - `check_reload.sh` 检查可热更模块是否有文件或者配置修改，有就更新。
    - 还会生成webapp_config.lua，也就是skynet启动用的配置文件。
    - 还有生成mod_config.lua，可热更模块配置文件。（首次生成是拷贝webapp/load_mods.lua，如果mod_config文件存在会对比load_mods和mod_config，将配置值类型不同的，有增加的，有删除的，同步到mod_config，只有值不同不覆盖原本修改的配置）
3. 运行
   - `sh script/run.sh`
4. 访问
   - 浏览器打开 `x.x.x.x:80`
   - 如果一切顺利的话，网页将会显示内容。
5. 热更
    - 修改 `webapp/lualib/webapp_dispatch.lua` 中的任意代码，加个空格什么的，最好是改一下html代码加个文本什么的，能看出来更新了。
    - 之后执行 `sh script/check_reload.sh`
    - 再次访问网站就更新了。
    - 也可以观察webapp/server.log


## 快速开始 游戏服务 (运行examples/digitalbomb)

* **构建服务**
	- `cd examples/digitalbomb/`
	- `sh ../../binshell/make_server.sh ../../ digitalbomb 4`

* **运行服务**
	`sh script/run.sh`


基于tcp长连接实现不停服更新 `digitalbomb` 数字炸弹游戏。
除了登录 `login` 服务不能热更。
`hall` 大厅。
`match` 匹配。
`room` 房间都是可行的。
内置了客户端，可以直接看到效果。

* **业务解耦**
	对**登录**，**大厅**，**匹配**，**游戏**，还有协议都完成了解耦，开发新游戏只需要实现对应的插件接口即可。

* **切换示例**
	把digitalbomb游戏由pb协议转换到跑json协议。

	修改由命令生成好的配置文件 mod_config.lua

client_m 配置的 net_util由`pbnet_util` 改为 `jsonet_util`

room_game_hall_m 配置的 hall_plug由`hall_plug_pb` 改为 `hall_plug_json`

room_game_match_m 配置的 match_plug由`match_plug_pb` 改为 `match_plug_json`

room_game_room_m 配置的 room_plug由`room_plug_pb` 改为 `room_plug_json`

执行 `sh script/restart.sh` 

* **热更新**
	client_m 表写了测试用例，可以用来验证热更新。
	也可以通过`script/reload.sh`的方式，不过你先修改好文件，然后开始执行。

* **游戏热更新原理**
	新服替换旧服务的方案。
	旧连接跟旧服务通信。
	新连接跟新服务通信。
	适合用于玩一把游戏就退出的微服务架构。

## 自己动手，实现一个石头剪刀布游戏
[文档链接](https://huahua132.github.io/2023/07/22/skynet_fly/room_game)