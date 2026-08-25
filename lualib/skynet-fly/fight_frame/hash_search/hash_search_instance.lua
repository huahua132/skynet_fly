-- hash_search_instance 空间哈希搜索实例：对象按位置分入网格（CellSize），查询螺旋搜索邻格
-- 用途：AI/防御塔寻敌（注册实体，按位置查询范围内敌方）
-- 数值（位置/距离/半径/角度/朝向向量）统一使用 skynet-fly.fixed Q16.16 定点数，
-- 网格下标/螺旋偏移仍为普通整数，距离与扇形比较全整数确定性运算。

local fixed = require "skynet-fly.fixed"

local CELL_SIZE = 2
local CELL_SIZE_INV = 1 / CELL_SIZE
local SQRT_2 = 1.41421356
local CELL_DIAGONAL = fixed.from_float(CELL_SIZE * SQRT_2)
local MAX_PRECOMPUTE_RADIUS = 50
local ONE = fixed.ONE

-- 预计算螺旋搜索偏移（每半径圈的 offset 列表 + 起始下标 + 数量）
local spiral_offsets = {}
local spiral_radius_start_index = {}
local spiral_radius_count = {}

do
    local temp_offsets = {}
    for radius = 0, MAX_PRECOMPUTE_RADIUS do
        spiral_radius_start_index[radius] = #temp_offsets
        local start_count = #temp_offsets
        if radius == 0 then
            temp_offsets[#temp_offsets + 1] = { 0, 0 }
        else
            -- 螺旋顺序：上边/下边全 x（含角点），左右边 y 跳过角点 → 四角齐全无重复
            for x = -radius, radius do
                temp_offsets[#temp_offsets + 1] = { x, -radius }
                temp_offsets[#temp_offsets + 1] = { x, radius }
            end
            for y = -radius + 1, radius - 1 do
                temp_offsets[#temp_offsets + 1] = { -radius, y }
                temp_offsets[#temp_offsets + 1] = { radius, y }
            end
        end
        spiral_radius_count[radius] = #temp_offsets - start_count
    end
    for i = 1, #temp_offsets do
        spiral_offsets[i] = temp_offsets[i]
    end
end

-- 定点坐标 v 所在网格下标（向下取整；v 为 Q16.16，d 为普通整数格尺寸）
local function grid_cell(v, d)
    return fixed.to_int_floor(fixed.div_int(v, d))
end

-- 网格 key：加法混合哈希（无按位异或；x/y 异质大质数乘积和，碰撞由 Lua table 处理）
local function get_grid_key(px, py)
    local coord_x = grid_cell(px, CELL_SIZE)
    local coord_y = grid_cell(py, CELL_SIZE)
    return coord_x * 73856093 + coord_y * 83492791
end

local function get_cell_coord(px, py)
    return grid_cell(px, CELL_SIZE), grid_cell(py, CELL_SIZE)
end

local function hash_cell_coord(x, y)
    return x * 73856093 + y * 83492791
end

local classic = require "skynet-fly.classic"
local hash_search_instance = classic:extend()

hash_search_instance.new = function(self)
    self._hash_map = {}          -- id → grid_key（对象当前网格）
    self._search_obj_dict = {}    -- grid_key → { [id] = search_obj }
    self._all_search_obj_dict = {} -- id → search_obj（全部对象）
    self._count = 0             -- 对象计数（增量维护，供 _should_use_direct_search，避免每次全量统计）
    self._cached_radius = -1
    self._cached_radius_sq = -1
    self._cached_grid_radius = -1
    self._cached_radius_plus_diagonal = -1
    self._cached_radius_plus_diagonal_sq = -1
end

-- 更新半径相关缓存（radius 变化时）；radius 为 Q16.16
function hash_search_instance:_update_radius_cache(radius)
    if self._cached_radius == radius then return end
    self._cached_radius = radius
    self._cached_radius_sq = fixed.mul(radius, radius)
    -- 覆盖半径所需网格圈数 = ceil(radius/CELL_SIZE)（确定性整数运算）
    local rx = fixed.div_int(radius, CELL_SIZE)
    self._cached_grid_radius = math.min(fixed.to_int_floor(fixed.add(rx, ONE - 1)), MAX_PRECOMPUTE_RADIUS)
    self._cached_radius_plus_diagonal = fixed.add(radius, CELL_DIAGONAL)
    self._cached_radius_plus_diagonal_sq = fixed.mul(self._cached_radius_plus_diagonal, self._cached_radius_plus_diagonal)
end

-- 是否用直接搜索（对象数 < 网格数时全量遍历更快）
function hash_search_instance:_should_use_direct_search(radius)
    self:_update_radius_cache(radius)
    local grid_count = (2 * self._cached_grid_radius + 1) * (2 * self._cached_grid_radius + 1)
    return self._count < grid_count
end

-- ============ 注册/注销/更新 ============

-- 注册搜索对象（search_obj: { id=n, get_pos=function() return x,y end }，x/y 为 Q16.16）
function hash_search_instance:register_search_obj(search_obj)
    if not search_obj or not search_obj.id then return end
    if self._all_search_obj_dict[search_obj.id] then return end

    local px, py = search_obj:get_pos()
    local grid_key = get_grid_key(px, py)

    self._all_search_obj_dict[search_obj.id] = search_obj
    self._hash_map[search_obj.id] = grid_key
    self._count = self._count + 1

    local grid_dict = self._search_obj_dict[grid_key]
    if not grid_dict then
        grid_dict = {}
        self._search_obj_dict[grid_key] = grid_dict
    end
    grid_dict[search_obj.id] = search_obj
end

function hash_search_instance:unregister_search_obj(search_obj)
    if not search_obj or not search_obj.id then return end
    if not self._all_search_obj_dict[search_obj.id] then return end

    local grid_key = self._hash_map[search_obj.id]

    self._all_search_obj_dict[search_obj.id] = nil
    self._hash_map[search_obj.id] = nil
    self._count = self._count - 1

    local grid_dict = self._search_obj_dict[grid_key]
    if grid_dict then
        grid_dict[search_obj.id] = nil
        if not next(grid_dict) then
            self._search_obj_dict[grid_key] = nil
        end
    end
end

-- 位置变化时更新对象网格（跨格才迁移，同格返回 false）
function hash_search_instance:update_search_obj(search_obj)
    if not search_obj or not search_obj.id then return false end
    if not self._all_search_obj_dict[search_obj.id] then return false end

    local px, py = search_obj:get_pos()
    local grid_key = get_grid_key(px, py)
    local old_grid_key = self._hash_map[search_obj.id]
    if grid_key == old_grid_key then return false end

    local old_grid_dict = self._search_obj_dict[old_grid_key]
    if old_grid_dict then
        old_grid_dict[search_obj.id] = nil
        if not next(old_grid_dict) then
            self._search_obj_dict[old_grid_key] = nil
        end
    end

    local new_grid_dict = self._search_obj_dict[grid_key]
    if not new_grid_dict then
        new_grid_dict = {}
        self._search_obj_dict[grid_key] = new_grid_dict
    end
    new_grid_dict[search_obj.id] = search_obj
    self._hash_map[search_obj.id] = grid_key
    return true
end

-- 批量更新所有对象网格
function hash_search_instance:update()
    for id, search_obj in pairs(self._all_search_obj_dict) do
        self:update_search_obj(search_obj)
    end
end

-- ============ 查询 ============

-- 是否范围内有对象（angle>0 启用扇形朝向检测）；pos/radius 为 Q16.16，angle 为普通角度数字
function hash_search_instance:is_have_in_range(pos_x, pos_y, radius, angle, forward_x, forward_z)
    if radius <= 0 or not next(self._all_search_obj_dict) then return false end
    self:_update_radius_cache(radius)
    local check_angle, fwd_x, fwd_z, cos_half_angle = self:_prepare_angle(angle, forward_x, forward_z)

    if self:_should_use_direct_search(radius) then
        return self:_direct_search_have_in_range(pos_x, pos_y, self._cached_radius_sq, check_angle, fwd_x, fwd_z, cos_half_angle)
    else
        return self:_grid_search_have_in_range(pos_x, pos_y, self._cached_radius_sq, check_angle, fwd_x, fwd_z, cos_half_angle)
    end
end

-- 获取最近对象
-- hint_obj: 最近候选种子（hash_search_module 缓存传入）。种子作为初始候选参与距离比较，精度不变；
--   种子命中 → 螺旋扫描提前截断/直接返回，省大部分网格遍历。调用方保证种子在桶内，否则退回全量搜索。
function hash_search_instance:get_nearest(pos_x, pos_y, radius, angle, forward_x, forward_z, hint_obj)
    if radius <= 0 or not next(self._all_search_obj_dict) then return nil end
    self:_update_radius_cache(radius)
    local check_angle, fwd_x, fwd_z, cos_half_angle = self:_prepare_angle(angle, forward_x, forward_z)
    if check_angle then
        -- 带扇形朝向：hint_obj 无法复用（过滤依赖查询朝向），忽略种子走全量搜索
        hint_obj = nil
    end

    if self:_should_use_direct_search(radius) then
        return self:_direct_search_nearest(pos_x, pos_y, self._cached_radius_sq, check_angle, fwd_x, fwd_z, cos_half_angle, hint_obj)
    else
        return self:_grid_search_nearest(pos_x, pos_y, self._cached_radius_sq, check_angle, fwd_x, fwd_z, cos_half_angle, hint_obj)
    end
end

-- 遍历范围内对象（action(search_obj, dist_sq)，dist_sq 为 Q16.16）
function hash_search_instance:foreach_range(pos_x, pos_y, radius, action, angle, forward_x, forward_z)
    if radius <= 0 or not next(self._all_search_obj_dict) or not action then return end
    self:_update_radius_cache(radius)
    local check_angle, fwd_x, fwd_z, cos_half_angle = self:_prepare_angle(angle, forward_x, forward_z)

    if self:_should_use_direct_search(radius) then
        self:_direct_search_foreach(pos_x, pos_y, self._cached_radius_sq, check_angle, fwd_x, fwd_z, cos_half_angle, action)
    else
        self:_grid_search_foreach(pos_x, pos_y, self._cached_radius_sq, check_angle, fwd_x, fwd_z, cos_half_angle, action)
    end
end

-- ============ 内部搜索实现 ============

-- 准备角度扇形检测参数（angle 普通角度，forward_x/z 为 Q16.16 朝向向量）
function hash_search_instance:_prepare_angle(angle, forward_x, forward_z)
    local check_angle
    if angle and angle > 0 and forward_x and forward_z then
        local fmag = fixed.add(fixed.mul(forward_x, forward_x), fixed.mul(forward_z, forward_z))
        check_angle = fmag > fixed.from_float(0.001)
    end
    local cos_half_angle = ONE
    local fwd_x, fwd_z = 0, 0
    if check_angle then
        -- 半角弧度 = angle*0.5*pi/180，转 Q16.16
        local half_angle_rad = fixed.from_float(angle * 0.5 * (math.pi / 180))
        cos_half_angle = fixed.cos(half_angle_rad)
        local forward_mag = fixed.sqrt(fixed.add(fixed.mul(forward_x, forward_x), fixed.mul(forward_z, forward_z)))
        fwd_x = fixed.div(forward_x, forward_mag)
        fwd_z = fixed.div(forward_z, forward_mag)
    end
    return check_angle, fwd_x, fwd_z, cos_half_angle
end

-- 扇形检测（点积避免开方；全定点整数运算）
local function is_in_sector_fast(delta_x, delta_z, delta_dist_sq, forward_x, forward_z, cos_half_angle)
    if delta_dist_sq == 0 then return true end
    local dot = fixed.add(fixed.mul(delta_x, forward_x), fixed.mul(delta_z, forward_z))
    local delta_dist_inv = fixed.rsqrt(delta_dist_sq)
    local normalized_dot = fixed.mul(dot, delta_dist_inv)
    return normalized_dot >= cos_half_angle
end

function hash_search_instance:_direct_search_have_in_range(pos_x, pos_y, radius_sq, check_angle, forward_x, forward_z, cos_half_angle)
    for id, search_obj in pairs(self._all_search_obj_dict) do
        local ox, oy = search_obj:get_pos()
        local dx = fixed.sub(ox, pos_x)
        local dy = fixed.sub(oy, pos_y)
        local dis_sq = fixed.add(fixed.mul(dx, dx), fixed.mul(dy, dy))
        if dis_sq <= radius_sq then
            if not check_angle or is_in_sector_fast(dx, dy, dis_sq, forward_x, forward_z, cos_half_angle) then
                return true
            end
        end
    end
    return false
end

function hash_search_instance:_grid_search_have_in_range(pos_x, pos_y, radius_sq, check_angle, forward_x, forward_z, cos_half_angle)
    local center_x, center_y = get_cell_coord(pos_x, pos_y)
    for r = 0, self._cached_grid_radius do
        local start_idx = spiral_radius_start_index[r]
        local count = spiral_radius_count[r]
        for i = 1, count do
            local offset = spiral_offsets[start_idx + i]
            local grid_x = center_x + offset[1]
            local grid_y = center_y + offset[2]
            -- 快速距离检查（格中心距 > 半径+对角则跳过）
            local cell_center_x = fixed.from_float((grid_x + 0.5) * CELL_SIZE)
            local cell_center_y = fixed.from_float((grid_y + 0.5) * CELL_SIZE)
            local cell_dx = fixed.sub(pos_x, cell_center_x)
            local cell_dy = fixed.sub(pos_y, cell_center_y)
            local cell_dist_sq = fixed.add(fixed.mul(cell_dx, cell_dx), fixed.mul(cell_dy, cell_dy))
            if cell_dist_sq <= self._cached_radius_plus_diagonal_sq then
                local hash = hash_cell_coord(grid_x, grid_y)
                local grid_dict = self._search_obj_dict[hash]
                if grid_dict then
                    for id, search_obj in pairs(grid_dict) do
                        local ox, oy = search_obj:get_pos()
                        local dx = fixed.sub(ox, pos_x)
                        local dy = fixed.sub(oy, pos_y)
                        local dis_sq = fixed.add(fixed.mul(dx, dx), fixed.mul(dy, dy))
                        if dis_sq <= radius_sq then
                            if not check_angle or is_in_sector_fast(dx, dy, dis_sq, forward_x, forward_z, cos_half_angle) then
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

-- 直接搜索最近对象（全量遍历，hint_obj 仅作初始候选）
function hash_search_instance:_direct_search_nearest(pos_x, pos_y, radius_sq, check_angle, forward_x, forward_z, cos_half_angle, hint_obj)
    local nearest_obj = nil
    local min_distance_sq = math.huge
    if hint_obj then
        local ox, oy = hint_obj:get_pos()
        local dx = fixed.sub(ox, pos_x)
        local dy = fixed.sub(oy, pos_y)
        min_distance_sq = fixed.add(fixed.mul(dx, dx), fixed.mul(dy, dy))
        nearest_obj = hint_obj
    end
    for id, search_obj in pairs(self._all_search_obj_dict) do
        local ox, oy = search_obj:get_pos()
        local dx = fixed.sub(ox, pos_x)
        local dy = fixed.sub(oy, pos_y)
        local distance_sq = fixed.add(fixed.mul(dx, dx), fixed.mul(dy, dy))
        if distance_sq <= radius_sq and distance_sq < min_distance_sq then
            if not check_angle or is_in_sector_fast(dx, dy, distance_sq, forward_x, forward_z, cos_half_angle) then
                nearest_obj = search_obj
                min_distance_sq = distance_sq
            end
        end
    end
    if nearest_obj then
        local ox, oy = nearest_obj:get_pos()
        local dx = fixed.sub(ox, pos_x)
        local dy = fixed.sub(oy, pos_y)
        if fixed.add(fixed.mul(dx, dx), fixed.mul(dy, dy)) > radius_sq then
            nearest_obj = nil   -- 种子不在半径内 → 无命中（后续对象均已比较，无更近候选）
        end
    end
    return nearest_obj
end

-- 网格搜索最近对象（支持提前退出：最近候选距离构成下界，下一圈更远时即停）
-- hint_obj（最近对象缓存种子）的距离即半径下界：外圈任何对象都不可能比 hint 更近，
-- 因此稳态（hint 即最近者）时第 0 圈结束即可 break，避免无谓的螺旋全扫。
-- 无 hint（min_distance_sq=math.huge）时不满足退出条件，行为与原一致（扫满）。
function hash_search_instance:_grid_search_nearest(pos_x, pos_y, radius_sq, check_angle, forward_x, forward_z, cos_half_angle, hint_obj)
    local center_x, center_y = get_cell_coord(pos_x, pos_y)
    local nearest_obj = nil
    local min_distance_sq = math.huge
    if hint_obj then
        local ox, oy = hint_obj:get_pos()
        local dx = fixed.sub(ox, pos_x)
        local dy = fixed.sub(oy, pos_y)
        min_distance_sq = fixed.add(fixed.mul(dx, dx), fixed.mul(dy, dy))
        nearest_obj = hint_obj
    end
    for r = 0, self._cached_grid_radius do
        local start_idx = spiral_radius_start_index[r]
        local count = spiral_radius_count[r]
        for i = 1, count do
            local offset = spiral_offsets[start_idx + i]
            local grid_x = center_x + offset[1]
            local grid_y = center_y + offset[2]
            local cell_center_x = fixed.from_float((grid_x + 0.5) * CELL_SIZE)
            local cell_center_y = fixed.from_float((grid_y + 0.5) * CELL_SIZE)
            local cell_dx = fixed.sub(pos_x, cell_center_x)
            local cell_dy = fixed.sub(pos_y, cell_center_y)
            local cell_dist_sq = fixed.add(fixed.mul(cell_dx, cell_dx), fixed.mul(cell_dy, cell_dy))
            if cell_dist_sq <= self._cached_radius_plus_diagonal_sq then
                local hash = hash_cell_coord(grid_x, grid_y)
                local grid_dict = self._search_obj_dict[hash]
                if grid_dict then
                    for id, search_obj in pairs(grid_dict) do
                        local ox, oy = search_obj:get_pos()
                        local dx = fixed.sub(ox, pos_x)
                        local dy = fixed.sub(oy, pos_y)
                        local distance_sq = fixed.add(fixed.mul(dx, dx), fixed.mul(dy, dy))
                        if distance_sq <= radius_sq and distance_sq < min_distance_sq then
                            if not check_angle or is_in_sector_fast(dx, dy, distance_sq, forward_x, forward_z, cos_half_angle) then
                                nearest_obj = search_obj
                                min_distance_sq = distance_sq
                            end
                        end
                    end
                end
            end
        end
        -- 提前退出：min_distance_sq 已有界（hint 距离或已发现更近对象）且下一圈不可能更近
        if min_distance_sq ~= math.huge and r < self._cached_grid_radius then
            local next_ring_min_dist = (r + 1) * CELL_SIZE
            if min_distance_sq < fixed.from_int(next_ring_min_dist * next_ring_min_dist) then
                break
            end
        end
    end
    if nearest_obj then
        local ox, oy = nearest_obj:get_pos()
        local dx = fixed.sub(ox, pos_x)
        local dy = fixed.sub(oy, pos_y)
        if fixed.add(fixed.mul(dx, dx), fixed.mul(dy, dy)) > radius_sq then
            nearest_obj = nil
        end
    end
    return nearest_obj
end

function hash_search_instance:_direct_search_foreach(pos_x, pos_y, radius_sq, check_angle, forward_x, forward_z, cos_half_angle, action)
    for id, search_obj in pairs(self._all_search_obj_dict) do
        local ox, oy = search_obj:get_pos()
        local dx = fixed.sub(ox, pos_x)
        local dy = fixed.sub(oy, pos_y)
        local distance_sq = fixed.add(fixed.mul(dx, dx), fixed.mul(dy, dy))
        if distance_sq <= radius_sq then
            if not check_angle or is_in_sector_fast(dx, dy, distance_sq, forward_x, forward_z, cos_half_angle) then
                action(search_obj, distance_sq)
            end
        end
    end
end

function hash_search_instance:_grid_search_foreach(pos_x, pos_y, radius_sq, check_angle, forward_x, forward_z, cos_half_angle, action)
    local center_x, center_y = get_cell_coord(pos_x, pos_y)
    for r = 0, self._cached_grid_radius do
        local start_idx = spiral_radius_start_index[r]
        local count = spiral_radius_count[r]
        for i = 1, count do
            local offset = spiral_offsets[start_idx + i]
            local grid_x = center_x + offset[1]
            local grid_y = center_y + offset[2]
            local cell_center_x = fixed.from_float((grid_x + 0.5) * CELL_SIZE)
            local cell_center_y = fixed.from_float((grid_y + 0.5) * CELL_SIZE)
            local cell_dx = fixed.sub(pos_x, cell_center_x)
            local cell_dy = fixed.sub(pos_y, cell_center_y)
            local cell_dist_sq = fixed.add(fixed.mul(cell_dx, cell_dx), fixed.mul(cell_dy, cell_dy))
            if cell_dist_sq <= self._cached_radius_plus_diagonal_sq then
                local hash = hash_cell_coord(grid_x, grid_y)
                local grid_dict = self._search_obj_dict[hash]
                if grid_dict then
                    for id, search_obj in pairs(grid_dict) do
                        local ox, oy = search_obj:get_pos()
                        local dx = fixed.sub(ox, pos_x)
                        local dy = fixed.sub(oy, pos_y)
                        local distance_sq = fixed.add(fixed.mul(dx, dx), fixed.mul(dy, dy))
                        if distance_sq <= radius_sq then
                            if not check_angle or is_in_sector_fast(dx, dy, distance_sq, forward_x, forward_z, cos_half_angle) then
                                action(search_obj, distance_sq)
                            end
                        end
                    end
                end
            end
        end
    end
end

return hash_search_instance
