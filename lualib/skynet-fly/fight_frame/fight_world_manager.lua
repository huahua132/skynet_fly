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
_default_modules["entity_module"] = fight_entity_module
_default_modules["event_module"] = fight_event_module
_default_modules["collision_module"] = collision_module
_default_modules["hash_search_module"] = hash_search_module
local _default_frame_rate = 10

function M.register_default_module(name, module)
    _default_modules[name] = module
end


function M.set_default_frame_rate(frame_rate)
    _default_frame_rate = frame_rate
end

function M.add_world(instance)
    local world_id = instance:GetGuid()
    local world = world(world_id, instance)
    _worlds[world_id] = world
    for name, module in pairs(_default_modules) do
        world:add_module(name, module)
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
