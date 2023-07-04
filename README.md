# skynet_fly
---
致力于服务端对skynet的最佳实践

* 关于skynet_fly热更新实现[https://huahua132.github.io/2023/06/30/skynet_fly/%E5%85%B3%E4%BA%8Eskynet_fly%E7%83%AD%E6%9B%B4%E6%96%B0%E5%AE%9E%E7%8E%B0/]
* 关于skynet_fly的一键构建服务配置[https://huahua132.github.io/2023/06/30/skynet_fly/%E5%85%B3%E4%BA%8Eskynet_fly%E7%9A%84%E4%B8%80%E9%94%AE%E6%9E%84%E5%BB%BA%E6%9C%8D%E5%8A%A1%E9%85%8D%E7%BD%AE/]

关于热更新方案
===

(热更新方案二的实现)[https://huahua132.github.io/2023/05/22/think/reload/]
运行**examples/hot_module2**示例
运行**examples/hot_module3**示例

(热更新方案三的实现)[https://huahua132.github.io/2023/05/22/think/reload/]
运行**examples/hot_module4**示例

快速开始(运行examples/webapp)
===
1. 编译skynet 参考了涵曦的skynet_demo[https://github.com/hanxi/skynet-demo] 
    - `make build`
2. 构建skynet_config,mod_config,webapp运维脚本
    - `cd examples/webapp/`
    - `sh ../../binshell/make_server.sh ../../ webapp 4`
- 如果一些顺利的话将会生成script文件夹，文件夹下有:
- `run.sh` 运行并配置日志分割
- `stop.sh` 停止
- `restart.sh` 重启
- `kill_mod.sh` 干掉某个可热更模块(不是强行kill，是通知服务可以退出了)
- `check_reload.sh` 检查可热更模块是否有文件或者配置修改，有就更新。

- 还会生成webapp_config.lua，也就是skynet启动用的配置文件。
还有生成mod_config.lua，可热更模块配置文件。（首次生成是拷贝webapp/load_mods.lua，如果mod_config文件存在会对比load_mods和mod_config，将配置值类型不同的，有增加的，有删除的，同步到mod_config，只有值不同不覆盖原本修改的配置）

3. 运行
   - `sh script/run.sh`

4. 访问
   - 浏览器打开 `x.x.x.x:80`

 - 如果一切顺利的话，网页将会显示内容。

5. 热更
    - 修改 `webapp/lualib/webapp_dispatch.lua` 中的任意代码，加个空格什么的，最好是改一下html代码加个文本什么的，能看出来更新了
    - 之后执行 `sh script/check_reload.sh`
    - 再次访问网站就更新了。
    - 也可以观察webapp/server.log

**恭喜你成功了**

数字炸弹游戏
==

如果你觉得第一个没意思，可以跑一下hot_module5,他是一个数字炸弹的游戏，简单实验了有状态服务的热更可行性。
执行方式同快速开始。