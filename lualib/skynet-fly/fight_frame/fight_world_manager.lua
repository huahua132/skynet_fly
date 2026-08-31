local MODULE_NAME = "fight_world_manager"

local log = require "skynet-fly.log"
local state_data = require "skynet-fly.hotfix.state_data"
local world = hotfix_require "skynet-fly.fight_frame.fight_world"
local fight_entity_module = hotfix_require "skynet-fly.fight_frame.modules.fight_entity_module.fight_entity_module"
local fight_event_module = hotfix_require "skynet-fly.fight_frame.modules.fight_event_module.fight_event_module"
local collision_module = hotfix_require "skynet-fly.fight_frame.modules.collision_module.collision_module"
local hash_search_module = hotfix_require "skynet-fly.fight_frame.modules.hash_search_module.hash_search_module"

local M = {}

local _worlds = state_data.alloc_table(MODULE_NAME .. ".worlds")

local _default_modules = state_data.alloc_table(MODULE_NAME .. ".default_modules")
-- 默认模块按插入顺序加载（add_world 按此顺序 add_module → 决定 _update_modules 顺序）
-- 用顺序表保证确定性（pairs 迭代哈希表顺序随机，会让帧模块更新顺序不定）
local _default_module_order = state_data.alloc_table(MODULE_NAME .. ".default_module_order")
local function reg_default(name, module)
    _default_modules[name] = module
    _default_module_order[#_default_module_order + 1] = name
end
reg_default("entity_module", fight_entity_module)
reg_default("event_module", fight_event_module)
reg_default("collision_module", collision_module)
reg_default("hash_search_module", hash_search_module)
local _default_frame_rate = 10

function M.register_default_module(name, module)
    if not _default_modules[name] then
        _default_module_order[#_default_module_order + 1] = name
    end
    _default_modules[name] = module
end


function M.set_default_frame_rate(frame_rate)
    _default_frame_rate = frame_rate
end

function M.add_world(instance)
    local world_id = instance:GetGuid()
    local world = world(world_id, instance)
    _worlds[world_id] = world
    -- 按注册顺序加载默认模块（保证 _update_modules 顺序确定性，勿用 pairs）
    for _, name in ipairs(_default_module_order) do
        world:add_module(name, _default_modules[name])
    end
    world:run(_default_frame_rate)
    log.info(string.format("%s.add_world: world [%d] added", MODULE_NAME, world_id))
    return world
end

function M.remove_world(world_id)
    if not world_id then
        log.error(MODULE_NAME .. ".remove_world: world_id is nil")
        return false
    end
    local world = _worlds[world_id]
    if not world then
        log.warn(string.format("%s.remove_world: world [%s] not found", MODULE_NAME, world_id))
        return false
    end
    world:stop()
    world:remove_all_modules()
    _worlds[world_id] = nil
    log.info(string.format("%s.remove_world: world [%d] removed", MODULE_NAME, world_id))
    return true
end

function M.get_world(world_id)
    if not world_id then
        log.error(MODULE_NAME .. ".get_world: world_id is nil")
        return nil
    end
    return _worlds[world_id]
end

function M.has_world(world_id)
    return _worlds[world_id] ~= nil
end

function M.get_world_count()
    local count = 0
    for _ in pairs(_worlds) do
        count = count + 1
    end
    return count
end

function M.get_all_worlds()
    return _worlds
end

return M
