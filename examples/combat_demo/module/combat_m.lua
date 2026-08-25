-- combat_m 战斗示例服务模块（可热更）
-- 玩法：2 名玩家进入房间并先后请求准备 → 满员即创建 fight_world 并开始战斗，
--       每名玩家生成 2 名英雄（随机位置/随机属性），英雄 AI 随机锁定敌方后追击并攻击。
-- 对外命令：
--   request_ready(player_id)  玩家请求准备（足额后自动开局）
--   get_state()               查询当前战斗状态
--   stop_room()               手动停止房间
-- 本例为演示起见，CMD.start 里内置一个演示驱动：先放 1 号玩家准备，1 秒后放 2 号玩家准备，
-- 若外接客户端接入则可删除 g_demo 演示驱动，改由外部依次调用 request_ready。
local MODULE_NAME = "combat_demo"

local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"
local combat_world = require "combat.combat_world"

local g_room = nil            -- combat_world 实例（单房间演示）
local g_demo_timers = {}      -- 演示驱动定时器（供 exit 清理）
local g_auto_start = true     -- true=启动后自动演示两名玩家 prepared

local CMD = {}

-- 房间/战斗配置
local function new_room()
    return combat_world.new(
        1,                       -- room_id
        2,                       -- player_num（2名玩家）
        {
            map_size = 10,       -- 10×10 地图
            hero_per_player = 2, -- 每名玩家 2 名英雄
            attack_range = 0.5,  -- 攻击距离 0.5
            attack_cd = 5,       -- 攻击 CD 5秒
        },
        20240101                 -- 随机种子（可复现）
    )
end

function CMD.start(config)
    log.info(string.format("[%s] 战斗示例服务启动，config=%s", MODULE_NAME, tostring(config)))
    g_room = new_room()
    -- 两名玩家进入房间
    g_room:add_player(1)
    g_room:add_player(2)

    if g_auto_start then
        -- 演示驱动：1号玩家立刻准备，1秒后2号玩家准备 → 两方就绪自动开局
        local t1 = timer:new(timer.second, 1, function()
            g_room:request_ready(1)
        end)
        local t2 = timer:new(timer.second * 2, 1, function()
            g_room:request_ready(2)
        end)
        g_demo_timers[#g_demo_timers + 1] = t1
        g_demo_timers[#g_demo_timers + 1] = t2
    end
    return true   -- ★ 必须返回 true
end

function CMD.exit()
    for _, t in ipairs(g_demo_timers) do
        t:cancel()
    end
    g_demo_timers = {}
    if g_room and g_room.world then
        g_room.world:stop()
    end
    log.info(string.format("[%s] 战斗示例服务退出", MODULE_NAME))
    return true
end

-- 玩家请求准备（外接客户端调用；足额后自动开局）
function CMD.request_ready(player_id)
    if not g_room then
        return false, "room not ready"
    end
    local ok, err = g_room:request_ready(player_id)
    return ok, err
end

-- 查询当前状态（含英雄列表）
function CMD.get_state()
    if not g_room then return nil end
    return g_room:get_state()
end

-- 停止房间
function CMD.stop_room()
    if not g_room then return false end
    if g_room.world then
        g_room.world:stop()
    end
    g_room.state = "finished"
    return true
end

return CMD
