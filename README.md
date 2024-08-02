# ![skynet_fly(1)](https://github.com/huahua132/skynet_fly/assets/41766775/98633a2d-6e52-4cc7-aaaf-c82b77b41e49)
---
致力于服务端对skynet的最佳实践
[使用文档](https://huahua132.github.io/2023/02/25/skynet_fly_word/word_1/A_home/)

	觉得不错，不妨点个**星星**吧！你的星星是作者持续创作维护的最大动力！

# 技术交流群
QQ群号：102993581

# skynet_fly简介
	skynet_fly是基于skynet扩展的可以快速开发web，游戏，和需要rpc调用的框架。
	使用skynet_fly的好处：
	* 支持不停服更新。
	* 一键生成skynet的配置文件和skynet_fly的配置文件以及配套shell脚本。
	* 对匹配房间类游戏做了gate,ws_gate的基础设施封装以及pb,json协议的支持，开发游戏只需要实现相关业务逻辑。
	* 对redis,mysql,timer,log 使用封装。
	* 支持远程rpc调用、远程sub/pub、远程subsyn/pubsyn。
	* 支持服务发现。
	* 支持http服务长连接。
	* 支持http服务路由，中间件模式。
	* 支持jwt鉴权。
	* 内置日志分割。
	* 支持快进时间。
	* 支持orm（数据关系映射）目前适配了(mysql,mongo),数据库可无缝切换。
	* 支持断点调试。

* [关于skynet_fly热更新实现](https://huahua132.github.io/2023/06/30/skynet_fly_ss/%E5%85%B3%E4%BA%8Eskynet_fly%E7%83%AD%E6%9B%B4%E6%96%B0%E5%AE%9E%E7%8E%B0/)
* [关于skynet_fly的一键构建服务配置](https://huahua132.github.io/2023/06/30/skynet_fly_ss/%E5%85%B3%E4%BA%8Eskynet_fly%E7%9A%84%E4%B8%80%E9%94%AE%E6%9E%84%E5%BB%BA%E6%9C%8D%E5%8A%A1%E9%85%8D%E7%BD%AE/)

## 第三方依赖来源
* [skynet](https://github.com/huahua132/skynet.git) 自己维护的fork版本
* [basexx](https://github.com/aiq/basexx)0.4.1
* [lua-cjson](https://github.com/cloudwu/lua-cjson)latest
* [lua-openssl](https://github.com/zhaozg/lua-openssl)0.9.0-0
* [lua-protobuf](https://github.com/starwing/lua-protobuf)0.4.0
* [lua-radix-router](https://github.com/vm-001/lua-radix-router)latest
* [luafilesystem](https://github.com/lunarmodules/luafilesystem)1.8.0
* [luajwtjitsi](https://github.com/jitsi/luajwtjitsi)3.0  自己适配了lua-openssl
* [lzlib](https://github.com/LuaDist/lzlib)0.4.3
* [lua-zset](https://github.com/xjdrew/lua-zset)latest
* [lua-snapshot](https://github.com/cloudwu/lua-snapshot)latest
* [lua-socket](https://github.com/lunarmodules/luasocket)latest
* [LuaPanda](https://github.com/Tencent/LuaPanda)latest

### [官方示例domo](https://github.com/huahua132/skynet_fly_demo)

### [API 文档](https://huahua132.github.io/2023/12/17/skynet_fly_api/module/)

## 编译
编译skynet 参考了涵曦的 [skynet_demo](https://github.com/hanxi/skynet-demo)
	- `git clone https://github.com/huahua132/skynet_fly`
	- 根据系统安装一些依赖`sh install_centos.sh` 或者 `sh install_ubuntu`
        - 在skynet_fly目录下 `make linux`

## 快速开始 简单可热更服务 (运行examples/AB_question)
* **构建服务**
	- `cd examples/digitalbomb/`
	- `sh ../../binshell/make_server.sh ../../`

* **运行服务**
	`sh script/run.sh load_mods.lua 0`

这个简单的示例是`A服务`向`B服务`发送hello消息，得到回应后打印。

### A服务消息发送内容
```lua 
function CMD.send_msg_to_b()
    for i = 1,4 do
		--简单轮询负载均衡 (假如B有2个服务B_1,B_2 用balance_call调用2次，将分别调用到B1，B2)
        local ret = contriner_client:instance("B_m"):balance_call("hello")                  
        log.info("balance_call send_msg_to_b:", i, ret)
        --对应send发送方式 balance_send
    end
    for i = 1,4 do
		--模除映射方式  (用1模除以B_m的服务数量从而达到映射发送到固定服务的目的,不调用set_mod_num指定mod时，mod默认等于skynet.self()）
        local ret = contriner_client:instance("B_m"):set_mod_num(1):mod_call("hello")
        log.info("mod_call send_msg_to_b:", i, ret)
        --对应send发送方式 mod_send
    end
	--给B_m所有服务发
    local ret = contriner_client:instance("B_m"):broadcast_call("hello")
    log.info("broadcast_call:", ret)
    --对应send发送方式 broadcast

    --by_name方式   相当于提供子名字，有时候相同的服务可能会划分不同的职责，比如一个游戏可能分为A玩法，B玩法。
	--大体逻辑相同，只有很小的区别，这时候可以用子名字，而不用再写一个可热更服务模块了。
    --by_name方式调用我们必须指定`instance_name`，调用API都是在后面加了_by_name

    for i = 1,4 do
		--简单轮询负载均衡 (假如B有2个服务B_1,B_2 用balance_call调用2次，将分别调用到B1，B2)会排除非test_one的服务。
        local ret = contriner_client:instance("B_m", "test_one"):balance_call_by_name("hello")  
        log.info("balance_call_by_name send_msg_to_b test_one:", i, ret)
        --对应send发送方式 balance_send_by_name
    end

    for i = 1,4 do
		--模除映射方式  (用1模除一B_m的服务数量从而达到映射发送到固定服务的目的,不用set_mod_num指定mod,mod默认等于skynet.self()）
        local ret = contriner_client:instance("B_m", "test_two"):set_mod_num(1):mod_call_by_name("hello")       
        log.info("mod_call_by_name send_msg_to_b test_two:", i, ret)
        --对应send发送方式 mod_send_by_name
    end

	--给B_m 子名字为test_two所有服务发
    local ret = contriner_client:instance("B_m", "test_two"):broadcast_call_by_name("hello")                    
    log.info("broadcast_by_name:", ret)
    --对应dend发送方式 broadcast_by_name
end
``` 
### B服务
```lua
function CMD.hello()
    return "HEELO A I am is " .. skynet.address(skynet.self())
end
```

### 执行结果解析

`balance_call` 调用4次分别发给了服务地址为`:0000000f`,`:00000010`,`:00000011`,`:00000012`
`mod_call` 调用4次一直发给服务地址为`:00000010`
`broadcast_call` 调用发给了所有`B_m`服务。
`balance_call_by_name` 调用四次轮询发给了`:0000000f`,`:00000010`,因为`:00000011`,`:00000012`子名字是`test_two`所以排除了。
`mod_call_by_name` 调用四次一直发给了`:00000012`(`B_m`子名字为`test_two`中的一个)。
`broadcast_call_by_name` 调用发给了所有`B_m`子名字为`test_two`的服务中。
```
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:49]"balance_call send_msg_to_b:" 1 "HEELO A I am is :0000000f"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:49]"balance_call send_msg_to_b:" 2 "HEELO A I am is :00000010"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:49]"balance_call send_msg_to_b:" 3 "HEELO A I am is :00000011"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:49]"balance_call send_msg_to_b:" 4 "HEELO A I am is :00000012"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:54]"mod_call send_msg_to_b:" 1 "HEELO A I am is :00000010"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:54]"mod_call send_msg_to_b:" 2 "HEELO A I am is :00000010"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:54]"mod_call send_msg_to_b:" 3 "HEELO A I am is :00000010"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:54]"mod_call send_msg_to_b:" 4 "HEELO A I am is :00000010"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:59]"broadcast_call:" {
        [15] =  {
                [1] = "HEELO A I am is :0000000f",
        }
        [16] =  {
                [1] = "HEELO A I am is :00000010",
        }
        [17] =  {
                [1] = "HEELO A I am is :00000011",
        }
        [18] =  {
                [1] = "HEELO A I am is :00000012",
        }
}

[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:67]"balance_call_by_name send_msg_to_b test_one:" 1 "HEELO A I am is :0000000f"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:67]"balance_call_by_name send_msg_to_b test_one:" 2 "HEELO A I am is :00000010"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:67]"balance_call_by_name send_msg_to_b test_one:" 3 "HEELO A I am is :0000000f"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:67]"balance_call_by_name send_msg_to_b test_one:" 4 "HEELO A I am is :00000010"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:73]"mod_call_by_name send_msg_to_b test_two:" 1 "HEELO A I am is :00000012"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:73]"mod_call_by_name send_msg_to_b test_two:" 2 "HEELO A I am is :00000012"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:73]"mod_call_by_name send_msg_to_b test_two:" 3 "HEELO A I am is :00000012"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:73]"mod_call_by_name send_msg_to_b test_two:" 4 "HEELO A I am is :00000012"
[:0000000e][20240523 17:12:01 70][info][A_m][./module/A_m.lua:78]"broadcast_call_by_name:" {
        [17] =  {
                [1] = "HEELO A I am is :00000011",
        }
        [18] =  {
                [1] = "HEELO A I am is :00000012",
        }
}
```

### 热更
在`B_m.lua`随意加个空格，再执行`sh script/check_reload.sh load_mods.lua`,此时会热更`B_m`服务，旧的`B_m`服务将被通知到可以退出了。
旧的`B_m`将会十分钟检查一次，直到没有访问者，`CMD.check_exit()`也是同意退出的，再调用`CMD.exit()`，如果返回`true`,服务将会在十分钟后调用`skynet.exit()`
而A服务将会切换访问到新启动的`B_m`服务。
```lua
function CMD.check_exit()
    log.error("检查退出")
    return true
end

function CMD.exit()
    log.error("退出")
    return true
end
```
### 结果解析
可以看到热更后访问的服务地址都已经改变了。
```
[:0000000f][20240523 17:14:41 89][error][B_m][./module/B_m.lua:14]"预告退出"
[:00000010][20240523 17:14:41 89][error][B_m][./module/B_m.lua:14]"预告退出"
[:00000011][20240523 17:14:41 89][error][B_m][./module/B_m.lua:14]"预告退出"
[:00000012][20240523 17:14:41 89][error][B_m][./module/B_m.lua:14]"预告退出"
[:00000013][20240523 17:14:41 89]LAUNCH snlua hot_container B_m 1 2024-05-23[17:14:41] 1716455681 2
[:00000014][20240523 17:14:41 90]LAUNCH snlua hot_container B_m 2 2024-05-23[17:14:41] 1716455681 2
[:00000015][20240523 17:14:41 90]LAUNCH snlua hot_container B_m 3 2024-05-23[17:14:41] 1716455681 2
[:00000016][20240523 17:14:41 91]LAUNCH snlua hot_container B_m 4 2024-05-23[17:14:41] 1716455681 2
[:0000000f][20240523 17:14:41 91][error][B_m][./module/B_m.lua:23]"确认要退出"
[:00000010][20240523 17:14:41 91][error][B_m][./module/B_m.lua:23]"确认要退出"
[:00000011][20240523 17:14:41 91][error][B_m][./module/B_m.lua:23]"确认要退出"
[:0000000e][20240523 17:14:41 91][info][A_m][./module/A_m.lua:14]"updated B_m"
[:00000012][20240523 17:14:41 91][error][B_m][./module/B_m.lua:23]"确认要退出"
[:0000000d][20240523 17:14:41 91]127.0.0.1:34774 disconnect
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:49]"balance_call send_msg_to_b:" 1 "HEELO A I am is :00000013"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:49]"balance_call send_msg_to_b:" 2 "HEELO A I am is :00000014"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:49]"balance_call send_msg_to_b:" 3 "HEELO A I am is :00000015"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:49]"balance_call send_msg_to_b:" 4 "HEELO A I am is :00000016"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:54]"mod_call send_msg_to_b:" 1 "HEELO A I am is :00000014"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:54]"mod_call send_msg_to_b:" 2 "HEELO A I am is :00000014"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:54]"mod_call send_msg_to_b:" 3 "HEELO A I am is :00000014"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:54]"mod_call send_msg_to_b:" 4 "HEELO A I am is :00000014"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:59]"broadcast_call:" {
        [21] =  {
                [1] = "HEELO A I am is :00000015",
        }
        [19] =  {
                [1] = "HEELO A I am is :00000013",
        }
        [20] =  {
                [1] = "HEELO A I am is :00000014",
        }
        [22] =  {
                [1] = "HEELO A I am is :00000016",
        }
}

[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:67]"balance_call_by_name send_msg_to_b test_one:" 1 "HEELO A I am is :00000013"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:67]"balance_call_by_name send_msg_to_b test_one:" 2 "HEELO A I am is :00000014"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:67]"balance_call_by_name send_msg_to_b test_one:" 3 "HEELO A I am is :00000013"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:67]"balance_call_by_name send_msg_to_b test_one:" 4 "HEELO A I am is :00000014"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:73]"mod_call_by_name send_msg_to_b test_two:" 1 "HEELO A I am is :00000016"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:73]"mod_call_by_name send_msg_to_b test_two:" 2 "HEELO A I am is :00000016"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:73]"mod_call_by_name send_msg_to_b test_two:" 3 "HEELO A I am is :00000016"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:73]"mod_call_by_name send_msg_to_b test_two:" 4 "HEELO A I am is :00000016"
[:0000000e][20240523 17:14:42 85][info][A_m][./module/A_m.lua:78]"broadcast_call_by_name:" {
        [21] =  {
                [1] = "HEELO A I am is :00000015",
        }
        [22] =  {
                [1] = "HEELO A I am is :00000016",
        }
}
```
### 加速时间
由于我们想测试旧服务退出，又不想改代码，又不想等太久，我们可以利用加速时间的方式来做到。
首先通过`debug_console`调用gc 快速消除对旧服务地址的引用。
`nc 127.0.0.1 8888`
`gc`
`gc`

然后调用快进时间快进1个小时
`sh script/fasttime.sh load_mods.lua '2023:05:23 18:00:00' 1`
然后在用`debug_console`看看还有哪些服务在
`nc 127.0.0.1 8888`
`mem`

```
:00000004       115.50 Kb (snlua cdummy)
:00000006       107.77 Kb (snlua datacenterd)
:00000007       135.83 Kb (snlua service_mgr)
:00000008       109.16 Kb (snlua service_provider)
:00000009       107.21 Kb (snlua service_cell ltls_holder)
:0000000b       121.97 Kb (snlua monitor_exit)
:0000000c       138.60 Kb (snlua contriner_mgr)
:0000000d       219.57 Kb (snlua debug_console 8888)
:0000000e       254.48 Kb (snlua hot_container A_m 1 2024-05-23[17:14:09] 1716455649 1)
:00000013       201.17 Kb (snlua hot_container B_m 1 2024-05-23[17:14:41] 1716455681 2)
:00000014       192.19 Kb (snlua hot_container B_m 2 2024-05-23[17:14:41] 1716455681 2)
:00000015       186.07 Kb (snlua hot_container B_m 3 2024-05-23[17:14:41] 1716455681 2)
:00000016       177.21 Kb (snlua hot_container B_m 4 2024-05-23[17:14:41] 1716455681 2)
```
可以看到，只存在版本二的B_m服务了。
	
## 快速开始 房间类游戏服务 (运行examples/digitalbomb)

* **构建服务**
	- `cd examples/digitalbomb/`
	- `sh ../../binshell/make_server.sh ../../`

* **运行服务**
	`sh script/run.sh load_mods.lua 0`

基于tcp长连接实现不停服更新 `digitalbomb` 数字炸弹游戏。
除了登录 `login` 服不能热更。
`hall` 大厅服。
`alloc` 分配服。
`table` 桌子服都是可行的。
内置了客户端，可以直接看到效果。

* **业务解耦**
	对**登录**，**大厅**，**匹配**，**游戏**，还有协议都完成了解耦，开发新游戏只需要实现对应的插件接口即可。

* **切换示例**
	把digitalbomb游戏由pb协议转换到跑json协议。

	修改配置文件 load_mods.lua

client_m 配置的 net_util由`pbnet_util` 改为 `jsonet_util`

room_game_hall_m 配置的 net_util由`pbnet_util` 改为 `jsonet_util`

room_game_alloc_m 配置的 net_util由`pbnet_util` 改为 `jsonet_util`

room_game_table_m 配置的 net_util由`pbnet_util` 改为 `jsonet_util`

执行 `sh script/restart.sh` 

* **热更新**
	client_m 表写了测试用例，可以用来验证热更新。
	也可以通过`script/check_reload.sh`的方式，不过你先修改好文件，然后开始执行。

* **游戏热更新原理**
	新服替换旧服务的方案。
	旧连接跟旧服务通信。
	新连接跟新服务通信。
	适合用于玩一把游戏就退出的微服务架构。

## 快速开始 http服务 (运行examples/webapp)
1. 构建skynet_config, webapp运维脚本
    - `cd examples/webapp/`
    - `sh ../../binshell/make_server.sh ../../`
    - 如果一些顺利的话将会生成script文件夹，文件夹下有:
      - `run.sh` 运行并配置日志分割
      - `stop.sh` 停止
      - `restart.sh` 重启
      - `reload.sh` 热更某个可热更模块。
      - `kill_mod.sh` 干掉某个可热更模块(不是强行kill，是通知服务可以退出了)
      - `check_reload.sh` 检测可热更模块是否有文件或者配置修改，有就更新。
      - `fasttime.sh` 快进时间。 `sh script/fasttime.sh load_mods.lua "2023:11:19 11:10:59" 1`
      - `try_again_reload.sh` 当热更失败，可以解决相关错误之后进行重试热更。
      - `check_hotfix.sh` 检测刷热更脚本。
      - `hotfix.sh` 刷热更脚本。
    - 还会生成webapp_config.lua，也就是skynet启动用的配置文件。
2. 运行
   - `sh script/run.sh load_mods.lua 0`
   - **load_mods.lua**是指启动用的配置文件。
   - **0**表示不用后台运行。不传就是后台运行。`sh script/run.sh load_mods.lua`。
   - 后台运行，日志会写入log文件。
3. 访问
   - 浏览器打开 `x.x.x.x:8688`
   - 如果一切顺利的话，网页将会显示内容。
4. 热更
    - 修改 `webapp/lualib/webapp_dispatch.lua` 中的任意代码。
    - 之后执行 `sh script/check_reload.sh load_mods.lua`
    - 再次访问网站就更新了。
    - 也可以观察webapp/logs/server.log

## 如何远程rpc调用

具体使用例子可以参照`examples/frpc_client` `examples/frpc_server`

## 完整项目示例
* **[中国象棋](https://github.com/huahua132/skynet_fly_demo)**