local log = require "skynet-fly.log"
local frpcpack = require "frpcpack.core"
local skynet = require "skynet"
local netpack = require "skynet.netpack"

local CMD = {}

--测试正常打包解包
local function test1()
    -- args： 参数
	-- pack_id(uint8)		 协议号
	-- module_name(string)  调用模块ID
	-- session_id(uint32)	 标识消息 0表示不需要回应
	-- mod_num(int64)		 用于模除的num
	-- msg(userdata)		 skyent.pack 打包好的lua消息
	-- sz(uint32)			 msg 消息长度
	-- is_call(uint8)	     是否call调用
    local session_id = 0
    local g_svr_name = "frpc_client"
    local g_svr_id = 1
    local msg, sz = skynet.pack(g_svr_name, g_svr_id)
	log.info("pack:", g_svr_name, g_svr_id, msg, sz)
	local req = frpcpack.packrequest(1, "module_name", "instance_name", session_id, 0, msg, sz, 1)
	log.info("pack :", #req)

    local sz = (req:byte(1) << 8) + req:byte(2)
    req =  req:sub(3)
    log.info("msgbuff:", #req)
    local pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall = frpcpack.unpackrequest(req)
    log.info("unpack ret :", pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall)
    log.info("unpack lua msg :", skynet.unpack(msg, sz))
end

--测试正常 打包解包 需要分包的大包
local function test2()
    local pack_id = 88
    local session_id = 5555555
    local module_name = "mmm_modasdj_m"
    local instance_name = "dddxxxx"
    
    local t = {}
    for i = 1, 100000 do
        table.insert(t, i)
    end

    local msg,sz = skynet.pack(t)
    log.info("sz:", sz, sz / 1024)  --超过32k 需要分包

    local msgbuff, padding = frpcpack.packrequest(pack_id, module_name, instance_name, session_id, 20000, msg, sz, 1)
    log.info("msgbuff:", #msgbuff)
    for i, v in ipairs(padding) do
        log.info("padding:", i, #v)
    end

    local sz = (msgbuff:byte(1) << 8) + msgbuff:byte(2)
    msgbuff = msgbuff:sub(3)
    local pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall = frpcpack.unpackrequest(msgbuff)
    log.info("unpack msgbuff:", pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall)

    local req = {module_name = module_name, instance_name = instance_name, iscall = iscall, mod_num = mod_num}
    frpcpack.append(req, msg, sz)

    for i, v in ipairs(padding) do
        local sz = (v:byte(1) << 8) + v:byte(2)
        local msgbuff = v:sub(3)
        local pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall = frpcpack.unpackrequest(msgbuff)
        log.info("unpack padding ", i, ':', pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall)
        frpcpack.append(req, msg, sz)
    end

    local msg,sz = frpcpack.concat(req)
    log.info("concat:", msg, sz)
    local ret = skynet.unpack(msg, sz)
    for i,v in ipairs(ret) do
        log.info("ret:", i, v)
    end
end

--测试打包解包 回应失败
local function test3()
    local session = 58989789
    local msgbuff = frpcpack.packresponse(session, false, "hello frpcpack")
    local sz = (msgbuff:byte(1) << 8) + msgbuff:byte(2)
    msgbuff = msgbuff:sub(3)

    log.info("retmsg:", frpcpack.unpackresponse(msgbuff))
end

--测试打包解包 回应超过
local function test4()
    local msg, sz = skynet.pack("hello", "frpc")
    local session = 589897854329
    local msgbuff = frpcpack.packresponse(session, true, msg, sz)
    local sz = (msgbuff:byte(1) << 8) + msgbuff:byte(2)
    msgbuff = msgbuff:sub(3)

    local session, isok, msg, padding = frpcpack.unpackresponse(msgbuff)
    log.info("retmsg:", session, isok, msg, padding)
    log.info("luamsg:", skynet.unpack(msg))
end

--测试pub推送包
local function test5()
    local msz, luasz = skynet.pack("hello", "frpc")
    local pack_id = 125
    local channel_name = "event_hello"
    local msgbuff = frpcpack.packpubmessage(channel_name, msz, luasz, pack_id)
    local sz = (msgbuff:byte(1) << 8) + msgbuff:byte(2)
    msgbuff = msgbuff:sub(3)
    log.info("msgbuff:", #channel_name, luasz, sz, msgbuff:byte(1))
    local isok, msg, padding = frpcpack.unpackpubmessage(msgbuff)
    log.info("retmsg:", isok, msg:len(), padding)
    local pack_id = msg:byte(1)
    local channel_sz = msg:byte(2)
    local channel_name = msg:sub(3, channel_sz + 2)
    msg = msg:sub(channel_sz + 3)
    log.info("channel_name:", channel_name, pack_id)
    log.info("laumsg:", skynet.unpack(msg))
end

function CMD.start()
    --test1()
    --test2()
    --test3()
    --test4()
    test5()
    return true
end

function CMD.exit()
    return true
end

return CMD