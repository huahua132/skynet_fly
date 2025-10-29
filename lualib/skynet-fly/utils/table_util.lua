---#API
---#content ---
---#content title: table_util table相关
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","工具函数"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [table_util](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/utils/table_util.lua)
local json = require "cjson"

local tinsert = table.insert
local tremove = table.remove
local tunpack = table.unpack
local tsort = table.sort
local type = type
local assert = assert
local pairs = pairs
local tostring = tostring
local string = string
local next = next
local tonumber = tonumber
local setmetatable = setmetatable
local getmetatable = getmetatable

local weak_mt = {__mode = "kv"}

local M = {}

---#desc 检测表是否有环引用
---@param check_table table 目标表
---@param is_route boolean 是否需要返回环路径
---@return boolean 是否出现环引用
---@return string|nil 环路径
---@return string|nil 环路径
function M.is_loop_table(check_table,is_route)
	assert(type(check_table) == 'table')
	local src_dest = {}
	local dest_src = {}
	local t_route = {}

	local function record_route(t,r)
		if not is_route or t_route[t] then
			return
		end
		t_route[t] = r
	end

	local stack = {check_table}
	record_route(check_table,'root')

	while #stack > 0 do
		local src = tremove(stack,#stack)
		
		if not src_dest[src] then
			src_dest[src] = {}
		end

		if not dest_src[src] then
			dest_src[src] = {}
		end

		for k,v in pairs(src) do
			if type(v) == 'table' then
				if not dest_src[v] then
					dest_src[v] = {}
				end
				if is_route then
					record_route(v,t_route[src] .. '.' .. tostring(k))
				end
				if src_dest[v] and src_dest[v][src] then
					return true,t_route[src],t_route[v]
				else
					local dsrc = dest_src[src]
					for s in pairs(dsrc) do
						src_dest[s][v] = true
					end

					dest_src[v][src] = true
					src_dest[src][v] = true
					tinsert(stack,v)
				end				
			end
		end
	end

	return false
end

---#desc 不会死循环的表dump
---@param tab table 目标表
---@return string dump后的内容
function M.dump(tab)
	local filter = {}

	local function string_k(k)
		local t = type(k)
		if t == 'string' then
			return '["' .. k .. '"]'
		else
			return '[' .. tostring(k) .. ']'
		end
	end

	local function string_v(v)
		local t = type(v)
		if t == 'string' then
			return '"' .. v .. '"'
		else
			return tostring(v)
		end
	end

	local function dp(k,v,level)
		local t = type(v)
		local str = ''
		local head_str = ""
		for i = 1,level do
			head_str = head_str .. '\t'
		end
		
		if t == 'table' then
			filter[v] = k or ''
			if k then
				str = str .. head_str .. string_k(k) .. ' = ' .. ' {\n'
			else
				str = str .. head_str .. '{\n'
			end
			for kk,vv in pairs(v) do
				if type(vv) == 'table' and filter[vv] then
					str = str .. head_str .. '\t' .. string_k(kk) .. ' = ' .. string_v(vv) .. ',\n'
				else
					str = str .. dp(kk,vv,level + 1)
				end
			end
			str = str .. head_str .. '}\n'
		else
			if k then
				str = str .. head_str .. string_k(k) .. ' = ' .. string_v(v) .. ',\n'
			else
				str = str .. head_str .. string_v(v)
			end
		end

		return str
	end

	return dp(nil,tab,0)
end

---#desc 检测2张表有什么同  共有4种不同 类型不同：typedef 相对于old_t有新增: add 相对于old_t有删除: reduce 值不同：valuedef
---@param new_t table 新表
---@param old_t table 旧表
---@return table 不同的描述信息
function M.check_def_table(new_t,old_t)
	assert(type(new_t) == 'table' and type(old_t) == 'table')

	local function check_func(nt,ot)
		local des_map = {}
		local n_type = type(nt)
		local o_type = type(ot)
		if n_type ~= o_type then
			return {_flag = "typedef",_new = nt,_old = ot}
		else
			if n_type == 'table' then
				for k,v in pairs(nt) do
					if ot[k] == nil then
						des_map[k] = {_flag = "add",_new = v,_old = nil}
					end
				end
	
				for k,v in pairs(ot) do
					if nt[k] == nil then
						des_map[k] = {_flag = "reduce",_new = nil,_old = v}
					end
				end
	
				for k,v in pairs(nt) do
					if not des_map[k] then
						local temp_des_map = check_func(nt[k],ot[k])
						if next(temp_des_map) then
							des_map[k] = temp_des_map
						end
					end
				end
			else
				if nt ~= ot then
					return {_flag = "valuedef",_new = nt,_old = ot}
				end
			end
		end
		return des_map
	end

	return check_func(new_t,old_t)
end

---#desc 把check_def_table返回值转换成string
---@param def table check_def_table返回值
---@return string string格式
function M.def_tostring(def)
	assert(type(def) == 'table')
	local function tstring(dk,dt)
		
		local ret = ''
		local flag = dt._flag
		if not flag then
			for k,v in pairs(dt) do
				if dk then
					ret = ret .. tstring(dk .. '.' .. k,v)
				else
					ret = ret .. tstring(k,v)
				end
			end
		else
			local s1,s2 = dt._new,dt._old
			if s1 == nil then
				s1 = "nil"
			elseif type(s1) == 'table' then
				s1 = json.encode(s1)
			end

			if s2 == nil then
				s2 = "nil"
			elseif type(s2) == 'table' then
				s2 = json.encode(s2)
			end
			ret = ret .. string.format("%s_%s[%s:%s]",dk,flag,s1,s2)
		end
		return ret
	end

	return tstring(nil,def)
end

---#desc 根据check_def_table的结果去更新旧值，change_flags表面哪些flag需要更新成新值
---@param def table check_def_table返回值
---@param old_t table 旧表
---@param change_flags table 需要更新的flags  可选 typedef add reduce valuedef
---@return table 更新后的表
function M.update_tab_by_def(def,old_t,change_flags)
	assert(type(def) == 'table')
	assert(type(old_t) == 'table')
	assert(type(change_flags) == 'table')

	local function update(dt,ot)
		local flag = dt._flag
		local ret = {}
		if not flag then
			if ot then
				for k,v in pairs(ot) do
					ret[k] = v
				end
			end

			for k,v in pairs(dt) do
				ret[k] = update(v,ot[k])
			end
		else
			if change_flags[flag] then
				return dt._new
			else
				return dt._old
			end
		end
		return ret
	end

	return update(def,old_t)
end

---#desc 通用的排序后遍历 对比v
---@param t table 需要排序的表
---@param comp function|nil 比较函数
---@return function 遍历函数
function M.sort_ipairs(t,comp)
	assert(t)
	assert(not comp or type(comp) == 'function')
	local list = {}
	local v_k = {}
	for k,v in pairs(t) do
		tinsert(list,v)
		v_k[v] = k 
	end

	tsort(list,comp)
	local index = 1
	local len = #list
	return function()
		if index > len then
			return nil
		end

		local v = list[index]
		local k = v_k[v]
		local is_end = index == len
		index = index + 1
		return k,v,is_end
	end
end

---#desc 通用的排序后遍历 对比k
---@param t table 需要排序的表
---@param comp? function|nil 比较函数
---@return function 遍历函数
function M.sort_ipairs_byk(t,comp)
	assert(t)
	assert(not comp or type(comp) == 'function')
	local list = {}
	for k,v in pairs(t) do
		tinsert(list,k)
	end

	tsort(list,comp)
	local index = 1
	local len = #list
	return function()
		if index > len then
			return nil
		end

		local k = list[index]
		local v = t[k]
		local is_end = index == len
		index = index + 1
		return k,v,is_end
	end
end

---#desc table转成lua文件格式的string
---@param mode string G表示全局模式 M表示模块模式
---@return string 转换后的string
function M.table_to_luafile(mode,tab)
	local ret_str = ""
	local function to_file_str(pre_k,pre_v,level)
		local result_str = ""
		local head_str = ""
		for i = 1,level do
			head_str = head_str .. '\t'
		end

		if type(pre_v) == 'table' then
			if level == 0 then
				result_str = result_str .. head_str .. string.format("%s = {\n",pre_k)
			else
				if type(pre_k) == 'number' then
					result_str = result_str .. head_str .. string.format("[%s] = {\n",pre_k)
				else
					result_str = result_str .. head_str .. string.format("['%s'] = {\n",pre_k)
				end
			end
		
			for k,v in M.kvsortipairs(pre_v) do
				result_str = result_str .. to_file_str(k,v,level + 1)
			end
			if level == 0 then
				result_str = result_str .. head_str .. '}\n'
			else
				result_str = result_str .. head_str .. '},\n'
			end
		else
			if type(pre_v) == 'number' or type(pre_v) == 'boolean' then
				if level == 0 then
					result_str = result_str .. head_str .. string.format("%s = %s\n",pre_k,pre_v)
				else
					if type(pre_k) == 'number' then
						result_str = result_str .. head_str .. string.format("[%s] = %s,\n",pre_k,pre_v)
					else
						result_str = result_str .. head_str .. string.format("['%s'] = %s,\n",pre_k,pre_v)
					end
				end
			else
				if level == 0 then
					result_str = result_str .. head_str .. string.format("%s = [[%s]]\n",pre_k,pre_v)
				else
					if type(pre_k) == 'number' then
						result_str = result_str .. head_str .. string.format("[%s] = [[%s]],\n",pre_k,pre_v)
					else
						result_str = result_str .. head_str .. string.format("['%s'] = [[%s]],\n",pre_k,pre_v)
					end
				end
			end
		end
		return result_str
	end

	local init_level = 0
	if mode == 'M' then
		ret_str = "return {\n"
		init_level = 1
	end
	for k,v in M.kvsortipairs(tab) do
		ret_str = ret_str .. to_file_str(k,v,init_level)
	end
	
	if mode == 'M' then
		ret_str = ret_str .. "}"
	end
	return ret_str
end

---#desc map按 字符编码顺序排序后遍历
---@param map table 遍历的表
---@return function 遍历函数
function M.kvsortipairs(map)
	local list = {}
	local k_type_map = {}
	for k,v in pairs(map) do
		local t = type(k)
		assert(t == 'number' or t == 'string',"k type err")
		local new_k = tostring(k)
		k_type_map[new_k] = t
	  	tinsert(list,new_k)
	end
	tsort(list)
	local index = 1
	local len = #list
	return function ()
		if index > len then
			return nil
		end

		local k = list[index]
		if k_type_map[k] == 'number' then
			k = tonumber(k)
		end
		index = index + 1
		return k,map[k]
	end
end

---#desc 深拷贝(考虑原表情况)
---@param orig table
---@return table 拷贝后的表
function M.deep_copy(orig)
    local copies = {}
    local function copy_recursive(orig)
        local orig_type = type(orig)
        local copy
        if orig_type == 'table' then
            if copies[orig] then
                copy = copies[orig]
            else
                copy = {}
                copies[orig] = copy
                for orig_key, orig_value in next, orig, nil do
                    copy[copy_recursive(orig_key)] = copy_recursive(orig_value)
                end
                setmetatable(copy, copy_recursive(getmetatable(orig)))
            end
        else -- number, string, boolean, etc
            copy = orig
        end
        return copy
    end
    return copy_recursive(orig)
end

---#desc 拷贝(不考虑原表)
---@param tab table 表
---@return table 拷贝后的表
function M.copy(tab)
	local t = {}
	for k, v in pairs(tab) do
		if "table" ~= type(v) then
			t[k] = v
		else
			t[k] = M.copy(v)
		end
	end
	return t
end

---#desc 按深度元素转成list
---@param tab table 原数据
---@param depth number 转换深度
---@return table 转换结果表
function M.depth_to_list(tab, depth)
	assert(depth > 0)
	local list1 = {tab}
	local list2 = {}

	for i = 1,depth do
		for _,tt in pairs(list1) do
			for _,t in pairs(tt) do
				tinsert(list2, t)
			end
		end
		list1 = list2
		list2 = {}
	end

	return list1
end

---#desc 是否在列表中
---@param list table 列表
---@param v any 值
---@return boolean 结果
function M.inlist(list, v)
	for i = 1,#list do
		local vv = list[i]
		if vv == v then
			return true
		end
	end

	return false
end

---#desc 查找在表中的位置
---@param list table 列表
---@param v any 值
---@param index number 起始索引
---@return number|nil 存在返回目标位置，不存在返回nil
function M.find_index(list, v, index)
	if index == nil then
		index = 1
	end
	assert(type(index) == 'number', "index is not number")
	assert( index > 0 and index <= #list, "index < 0 or index > #list")
	for i = index,#list do
		local vv = list[i]
		if vv == v then
			return i
		end
	end

	return nil
end

---@desc 统计表长度
---@param tab table 表
---@return number 长度
function M.count(tab)
	local c = 0
	for _,_ in pairs(tab) do
		c = c + 1
	end
	return c
end

---#desc 合并table (source合并进入target)
---@param target table 目标表
---@param source table 来源表
function M.merge(target, source)
	for k,v in pairs(source) do
		target[k] = v
	end
end

---#desc 数组全排列遍历
---@param arr table 数组
---@return talbe
function M.permute_pairs(arr)
    local len = #arr
    if len == 0 then
        return function() end -- 空数组返回空迭代器
    end

    -- 深拷贝原数组避免污染
    local state = {
        stack = {},     -- 模拟递归调用栈
        current = {},   -- 当前路径
        used = {},      -- 记录已用元素
        arr = {tunpack(arr)}, -- 使用 txxx.unpack
        initialized = false
    }

    -- 初始化状态
    local function init()
        for i = 1, len do
            state.current[i] = 0
            state.used[i] = false
        end
        tinsert(state.stack, { depth = 1, selected = nil }) -- 使用 txxx.insert
        state.initialized = true
    end

    -- 返回闭包迭代器
    return function()
        if not state.initialized then init() end

        while #state.stack > 0 do
            local frame = state.stack[#state.stack]
            local depth = frame.depth

            -- 完成一个排列
            if depth > len then
                tremove(state.stack, #state.stack) -- 使用 txxx.remove
                local result = {tunpack(state.current)}
                return result
            end

            -- 回溯时重置前一次使用的元素
            if frame.selected then
                state.used[frame.selected] = false
                frame.selected = nil -- 清除标记
            end

            -- 寻找下一个可用元素
            local start = frame.pos or 1
            for i = start, len do
                if not state.used[i] then
                    -- 记录当前选择
                    frame.selected = i
                    frame.pos = i + 1

                    -- 更新状态
                    state.current[depth] = state.arr[i]
                    state.used[i] = true

                    -- 压入下一层
                    tinsert(state.stack, {
                        depth = depth + 1,
                        selected = nil,
                        pos = 1
                    })
                    break
                else
                    frame.pos = i + 1
                end
            end

            -- 当前层遍历完成，需要回溯
            if not frame.selected then
                tremove(state.stack, #state.stack)
            end
        end

        return nil -- 遍历结束
    end
end

---#desc 组合遍历
---@param arr table 数组
---@param k number 组合数量
function M.combinations_pairs(arr, k)
    local n = #arr
    -- 处理无效的k值
    if k <= 0 or k > n then
        return function() return nil end
	end

    -- 初始化组合索引数组
    local indices = {}
    for i = 1, k do
        indices[i] = i
    end

    -- 返回组合遍历闭包
    return function()
        if not indices then return nil end
        
        -- 生成当前组合
        local result = {}
        for i = 1, k do
            result[i] = arr[indices[i]]
        end

        -- 寻找下一个组合
        local i = k
        -- 从后向前查找可递增的位置
        while i >= 1 and indices[i] == n - k + i do
            i = i - 1
        end

        if i < 1 then
            indices = nil  -- 所有组合已生成完毕
        else
            -- 递增当前位置并重置后续位置
            indices[i] = indices[i] + 1
            for j = i + 1, k do
                indices[j] = indices[j-1] + 1
            end
        end

        return result
    end
end

---#desc 新建一个弱引用表
function M.new_weak_table()
	local t = {}
	setmetatable(t, weak_mt)
	return t
end

return M
