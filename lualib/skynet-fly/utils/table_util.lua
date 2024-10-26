local json = require "cjson"

local tinsert = table.insert
local tremove = table.remove
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

local M = {}

--[[
	函数作用域：M 的成员函数
	函数名称: is_loop_table
	描述:检测表是否有环引用
	参数:
		- check_table (table): 目标表
		- is_route (boolean) ：是否需要返回环路径
]]
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

--[[
	函数作用域：M 的成员函数
	函数名称: dump
	描述:不会死循环的表dump
	参数:
		- tab (table): 目标表
]]
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

--[[
	函数作用域：M 的成员函数
	函数名称: check_def_table
	描述: 检测2张表有什么同
		共有4种不同
		类型不同：typedef
		相对于old_t有新增: add
		相对于old_t有删除: reduce
		值不同：valuedef
	参数:
		- new_t (table): 新表
		- old_t (table): 旧表
]]
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

--[[
	函数作用域：M 的成员函数
	函数名称: def_tostring
	描述:把check_def_table返回值转换成string
	参数:
		- def (table): check_def_table返回值
]]
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

--[[
	函数作用域：M 的成员函数
	函数名称: update_tab_by_def
	描述:根据check_def_table的结果去更新旧值，change_flags表面哪些flag需要更新成新值
	参数:
		- def (table): check_def_table返回值
		- old_t(table)：旧表
		- change_flags(table)：需要更新的flags  可选 typedef add reduce valuedef
]]
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

--通用的排序后遍历
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

--通用的排序后遍历 对比k
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

--写luafile mode = G M
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

--map按 字符编码顺序排序后遍历
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

-- 深拷贝
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

-- 按深度元素转成list
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

--是否在列表中
function M.inlist(list, v)
	for i = 1,#list do
		local vv = list[i]
		if vv == v then
			return true
		end
	end

	return false
end

--查找在表中的位置
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

--统计长度
function M.count(tab)
	local c = 0
	for _,_ in pairs(tab) do
		c = c + 1
	end
	return c
end

--合并table
function M.merge(target, source)
	for k,v in pairs(source) do
		target[k] = v
	end
end

return M
