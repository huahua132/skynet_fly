local field_check_help = require "field_check_help"
local log = require "log"

local function is_table(v)
    return type(v) == 'table'
end

local function is_number(v)
    return type(v) == 'number'
end

local cfg_struct = {
    _begin_func = is_table,
    _map_field = {
        min_limit = {
            _begin_func = is_number,
        },
        max_limit = {
            _begin_func = is_number,
            _keep_update = true,
        },

        player_map = {
            _begin_func = is_table,
            _repeat_field = {
                _begin_func = is_number,
            }
        },

        player_list = {
            _begin_func = is_table,
            _repeat_field = {
                _begin_func = is_number,
            }
        },
    }
}

local function test_map_add()
    local old_t = {
        min_limit = 1,
        max_limit = 2,

        player_map = {
            [10001] = 1,
        },

        player_list = {
            1,2,35,6,
        }
    }

    local new_t = {
        min_limit = 1,
        max_limit = 2,

        player_map = {
            [10001] = 1,
            [20001] = 2,
        },

        player_list = {
            1,2,35,6,
        }
    }

    local _,check_map = field_check_help.check_args(new_t,cfg_struct,nil,'root')
    local is_update = field_check_help.update_args(old_t,new_t,check_map,cfg_struct)
    assert(old_t.player_map[20001] == 2)
    log.info("test_map_add:",old_t)
    return is_update
end

local function test_map_reduce()
    local old_t = {
        min_limit = 1,
        max_limit = 2,

        player_map = {
            [10001] = 1,
            [20001] = 2,
        },

        player_list = {
            1,2,35,6,
        }
    }

    local new_t = {
        min_limit = 1,
        max_limit = 2,

        player_map = {
            [10001] = 1,
        },

        player_list = {
            1,2,35,6,
        }
    }
    local _,check_map = field_check_help.check_args(new_t,cfg_struct,nil,'root')
    local is_update = field_check_help.update_args(old_t,new_t,check_map,cfg_struct)
    assert(old_t.player_map[20001] == nil)
    log.info("test_map_reduce:",old_t)
    return is_update
end

local function test_list_add()
    local old_t = {
        min_limit = 1,
        max_limit = 2,

        player_map = {
            [10001] = 1,
        },

        player_list = {
            1,2,35,6,
        }
    }

    local new_t = {
        min_limit = 1,
        max_limit = 2,

        player_map = {
            [10001] = 1,
        },

        player_list = {
            1,2,35,6,100,
        }
    }

    local _,check_map = field_check_help.check_args(new_t,cfg_struct,nil,'root')
    local is_update = field_check_help.update_args(old_t,new_t,check_map,cfg_struct)
    assert(old_t.player_list[5] == 100)
    log.info("test_list_add:",old_t)
    return is_update
end

local function test_list_reduce()
    local old_t = {
        min_limit = 1,
        max_limit = 2,

        player_map = {
            [10001] = 1,
        },

        player_list = {
            1,2,35,6,
        }
    }

    local new_t = {
        min_limit = 1,
        max_limit = 2,

        player_map = {
            [10001] = 1,
        },

        player_list = {
            1,2,35,
        }
    }

    local _,check_map = field_check_help.check_args(new_t,cfg_struct,nil,'root')
    local is_update = field_check_help.update_args(old_t,new_t,check_map,cfg_struct)
    assert(old_t.player_list[4] == nil)
    log.info("test_list_reduce:",old_t)
    return is_update
end

local function keep_update_test_up()
    local old_t = {
        min_limit = 1,
        max_limit = 2,

        player_map = {
            [10001] = 1,
        },

        player_list = {
            1,2,35,
        }
    }

    local new_t = {
        min_limit = "1",
        max_limit = 10,

        player_map = {
            [10001] = 1,
        },

        player_list = {
            1,2,35,
        }
    }

    local _,check_map = field_check_help.check_args(new_t,cfg_struct,nil,'root')
    local is_update = field_check_help.update_args(old_t,new_t,check_map,cfg_struct)
    assert(old_t.max_limit == 10)
    log.info("keep_update_test_up:",old_t)
    return is_update
end

local function keep_update_test_not_up()
    local old_t = {
        min_limit = 1,
        max_limit = 2,

        player_map = {
            [10001] = 1,
        },

        player_list = {
            1,2,35,
        }
    }

    local new_t = {
        min_limit = 10,
        max_limit = "10",

        player_map = {
            [10001] = 1,
        },

        player_list = {
            1,2,35,
        }
    }

    local _,check_map = field_check_help.check_args(new_t,cfg_struct,nil,'root')
    local is_update = field_check_help.update_args(old_t,new_t,check_map,cfg_struct)
    assert(old_t.min_limit == 1)
    log.info("keep_update_test_not_up:",old_t)
    return is_update
end

local CMD = {}

function CMD.start()
    assert(test_map_add())
    assert(test_map_reduce())
    assert(test_list_add())
    assert(test_list_reduce())
    assert(keep_update_test_up())
    assert(keep_update_test_not_up())
    return true
end

function CMD.exit()

end

return CMD