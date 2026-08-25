-- 碰撞系统：空间哈希网格 + 单向检测（active 触发 passive，仅对 active 分发事件）
-- 数值采用 skynet-fly.fixed Q16.16 定点数（位置 x/y、半宽 w/半高 h、网格尺寸 cell_size）
local classic = require "skynet-fly.classic"
local fixed = require "skynet-fly.fixed"
local collision = classic:extend()

-- 层碰撞矩阵数值编码基数（layer_a*10+layer_b 作索引，数组替代字符串 key）
local LAYER_KEY_BASE = 10
local LAYER_KEY_SIZE = 100   -- 覆盖 0~9 层

-- 定点坐标 v 所在网格下标（向下取整，确定性整数运算）
local function cell_of(v, cs)
    return fixed.to_int_floor(fixed.div(v, cs))
end

collision.new = function(self, cell_size)
    -- cell_size 性能敏感：默认 8。碰撞盒最大全宽 ~4（建筑 2×2 半宽）< 8 → 只跨 1 格，
    -- 9 邻格扫描覆盖完整；子弹速度 ~2.5 单位/秒，每帧位移 <0.25，无跳格穿透
    -- 基准（span=150，子弹500/建筑500）：64→47ms，8→2.6ms（快18倍）
    cell_size = fixed.from_float(cell_size or 8)
    self._agents = {}
    self._agent_count = 0
    -- 层碰撞矩阵（layer_a*10+layer_b → bool），预分配避免运行时扩容
    self._layer_collision = {}
    for i = 1, LAYER_KEY_SIZE do self._layer_collision[i] = false end
    self._cell_size = cell_size
    self._cell_key_mul = 100000   -- 网格 key 数值编码基数（cell_key = cx*mul + cy）
    self._cells = {}
    self._filter = nil   -- 碰撞对过滤器（开战双方过滤）
    self._id_big = 1000000   -- pair_key 数值编码基数
    -- 主动（碰撞物）专属列表：单向检测下 active-active 必不可能碰撞，check_all 只扫 active
    self._actives = {}
    -- 每帧缓冲表（check_all 复用，避免重建）
    self._pairs = nil
    self._seen = nil
end

-- 设置碰撞对过滤器（返回 true 才检测该对；帧级同步求值）
function collision:set_filter(filter)
    self._filter = filter
end

function collision:add_agent(id, x, y, w, h, layer, passive)
    layer = layer or 0
    -- x/y/w/h 均为 Q16.16 定点数
    -- passive=true 为被碰撞物（只作目标），false 为碰撞物（触发他人）
    -- owner：归属队伍（碰撞过滤用，实体装配后同步）；_owner_epoch：owner 缓存版本（过滤缓存失效）
    local agent = { id = id, x = x, y = y, w = w, h = h, layer = layer, passive = passive or false,
                    owner = 0 }
    self._agents[id] = agent
    self._agent_count = self._agent_count + 1
    if not agent.passive then
        self._actives[id] = agent
    end
    self:_insert_to_grid(agent)
end

function collision:remove_agent(id)
    local agent = self._agents[id]
    if agent then
        self:_remove_from_grid(agent)
        self._agents[id] = nil
        self._agent_count = self._agent_count - 1
        self._actives[id] = nil
    end
end

function collision:update_agent(id, x, y, w, h)
    local agent = self._agents[id]
    if agent then
        -- 同格跳过：新旧包围盒四角格完全一致时省略网格重插
        -- （对比整盒四角比中心格更稳：贴格边界 ±w 跨格时中心格可能未变但覆盖格集合已变）
        local cs = self._cell_size
        local nw = w or agent.w
        local nh = h or agent.h
        local min_cx = cell_of(x, cs)
        local min_cy = cell_of(y, cs)
        local max_cx = cell_of(fixed.add(x, nw), cs)
        local max_cy = cell_of(fixed.add(y, nh), cs)
        local o_min_cx = cell_of(agent.x, cs)
        local o_min_cy = cell_of(agent.y, cs)
        local o_max_cx = cell_of(fixed.add(agent.x, agent.w), cs)
        local o_max_cy = cell_of(fixed.add(agent.y, agent.h), cs)
        local same_cell = min_cx == o_min_cx and min_cy == o_min_cy
            and max_cx == o_max_cx and max_cy == o_max_cy
        if not same_cell then
            self:_remove_from_grid(agent)
        end
        agent.x = x
        agent.y = y
        agent.w = nw
        agent.h = nh
        if not same_cell then
            self:_insert_to_grid(agent)
        end
    end
end

function collision:set_layer_collision(layer_a, layer_b, enabled)
    -- 双向写入：查询方 layer 顺序不定
    self._layer_collision[layer_a * LAYER_KEY_BASE + layer_b] = enabled
    self._layer_collision[layer_b * LAYER_KEY_BASE + layer_a] = enabled
end

function collision:_can_collide(layer_a, layer_b)
    return self._layer_collision[layer_a * LAYER_KEY_BASE + layer_b] == true
end

-- AABB 重叠：x/y 为中心，w/h 为半宽/半高（左边界 = x-w，右边界 = x+w）
function collision:_check_aabb_overlap(a, b)
    return a.x - a.w < b.x + b.w
       and a.x + a.w > b.x - b.w
       and a.y - a.h < b.y + b.h
       and a.y + a.h > b.y - b.h
end

-- 网格 key 数值编码 cx*mul + cy（替代字符串拼接）；要求 |cy| < _cell_key_mul
function collision:_cell_key(cx, cy)
    return cx * self._cell_key_mul + cy
end

function collision:_insert_to_grid(agent)
    local cs = self._cell_size
    local min_cx = cell_of(agent.x, cs)
    local min_cy = cell_of(agent.y, cs)
    local max_cx = cell_of(fixed.add(agent.x, agent.w), cs)
    local max_cy = cell_of(fixed.add(agent.y, agent.h), cs)
    for cx = min_cx, max_cx do
        for cy = min_cy, max_cy do
            local key = self:_cell_key(cx, cy)
            local cell = self._cells[key]
            if not cell then
                cell = {}
                self._cells[key] = cell
            end
            cell[agent.id] = agent
        end
    end
end

function collision:_remove_from_grid(agent)
    local cs = self._cell_size
    local min_cx = cell_of(agent.x, cs)
    local min_cy = cell_of(agent.y, cs)
    local max_cx = cell_of(fixed.add(agent.x, agent.w), cs)
    local max_cy = cell_of(fixed.add(agent.y, agent.h), cs)
    for cx = min_cx, max_cx do
        for cy = min_cy, max_cy do
            local key = self:_cell_key(cx, cy)
            local cell = self._cells[key]
            if cell then
                cell[agent.id] = nil
                if not next(cell) then
                    self._cells[key] = nil
                end
            end
        end
    end
end

function collision:check_agent(id, result)
    result = result or {}
    local agent = self._agents[id]
    if not agent then
        return result
    end
    local cs = self._cell_size
    local cx = cell_of(agent.x, cs)
    local cy = cell_of(agent.y, cs)
    local seen = {}
    seen[id] = true
    for dx = -1, 1 do
        for dy = -1, 1 do
            local key = self:_cell_key(cx + dx, cy + dy)
            local cell = self._cells[key]
            if cell then
                for other_id, other in pairs(cell) do
                    if not seen[other_id] and self:_can_collide(agent.layer, other.layer) then
                        seen[other_id] = true
                        if self:_check_aabb_overlap(agent, other) then
                            result[#result + 1] = other
                        end
                    end
                end
            end
        end
    end
    return result
end

-- 检查全部主动碰撞物并返回命中对（每帧调用）；复用 _pairs/_seen 缓冲表
-- pair_key 数值编码 a*BIG+b（a=min,b=max）去重无序对
-- 性能：遍历 _actives，邻格内 active 目标提前短路（active-active 必不可能碰撞）
function collision:check_all()
    if not self._pairs then
        self._pairs = {}
        self._seen = {}
    end
    local _pairs = self._pairs
    local seen = self._seen
    for k in pairs(_pairs) do _pairs[k] = nil end
    for k in pairs(seen) do seen[k] = nil end
    local id_big = self._id_big
    local cells = self._cells
    local cs = self._cell_size
    local layer_collision = self._layer_collision
    local filter = self._filter
    for id, agent in pairs(self._actives) do
        local cx = cell_of(agent.x, cs)
        local cy = cell_of(agent.y, cs)
        for dx = -1, 1 do
            for dy = -1, 1 do
                local key = self:_cell_key(cx + dx, cy + dy)
                local cell = cells[key]
                if cell then
                    for other_id, other in pairs(cell) do
                        -- 跳过自身与 active-active；层检测/AABB 内联免每对方法查找
                        if other_id ~= id and other.passive
                           and layer_collision[agent.layer * LAYER_KEY_BASE + other.layer] == true then
                            local a, b = id, other_id
                            if a > b then a, b = b, a end
                            local pair_key = a * id_big + b
                            if not seen[pair_key] then
                                seen[pair_key] = true
                                -- 帧级过滤（开战双方过滤）：返回 false 跳过该对
                                if not filter or filter(agent, other) then
                                    -- AABB 重叠（内联，x/y 中心 + 半宽/半高）
                                    if agent.x - agent.w < other.x + other.w
                                       and agent.x + agent.w > other.x - other.w
                                       and agent.y - agent.h < other.y + other.h
                                       and agent.y + agent.h > other.y - other.h then
                                        _pairs[#_pairs + 1] = { agent, other }
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return _pairs
end

function collision:clear()
    self._agents = {}
    self._agent_count = 0
    self._actives = {}
    self._cells = {}
    self._pairs = nil
    self._seen = nil
end

return collision
