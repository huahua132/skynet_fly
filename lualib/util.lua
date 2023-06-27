local lfs = require "lfs"
local json = require "cjson"
local util = {}
local pairs = pairs
local type = type
local tonumber = tonumber
local tostring = tostring
local string = string
local table = table
local assert = assert
local setmetatable = setmetatable
local next = next
local io = io
local tinsert = table.insert
local tremove = table.remove

--map按 字符编码顺序排序后遍历
function util.kvsortipairs(map)
	local list = {}
	local k_type_map = {}
	for k,v in pairs(map) do
		local t = type(k)
		assert(t == 'number' or t == 'string',"k type err")
		local new_k = tostring(k)
		k_type_map[new_k] = t
	  	tinsert(list,new_k)
	end
	table.sort(list)
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

--遍历目录
function util.diripairs(path_url)
	local stack = {}
	
	local function push_stack(path)
		local next,meta1,meta2 = lfs.dir(path)
		tinsert(stack,{
			path = path,
			next = next,
			meta1 = meta1,
			meta2 = meta2,
		})
	end

	push_stack(path_url)
	return function() 
		while #stack > 0 do
			local cur = stack[#stack]
			local file_name = cur.next(cur.meta1,cur.meta2)
			if file_name == '..' or file_name == '.' then
			elseif file_name then
				local file_path = cur.path .. '/' .. file_name
				local file_info = lfs.attributes(file_path)
				if file_info.mode == 'directory' then
					push_stack(file_path)
				end
				return file_name,file_path,file_info
			else
				tremove(stack,#stack)
			end
		end
		return nil,nil,nil
	end
end

--写luafile mode = G M
function util.table_to_luafile(mode,tab)
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
		
			for k,v in util.kvsortipairs(pre_v) do
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
	for k,v in util.kvsortipairs(tab) do
		ret_str = ret_str .. to_file_str(k,v,init_level)
	end
	
	if mode == 'M' then
		ret_str = ret_str .. "}"
	end
	return ret_str
end

--打开并读取文件
function util.readallfile(file_path)
	local file = io.open(file_path,'r')
	assert(file)
	local str = file:read("*all")
	file:close()
	return str
end

--通用的排序后遍历
function util.sort_ipairs(t,comp)
	assert(t)
	assert(type(comp) == 'function')
	local list = {}
	local v_k = {}
	for k,v in pairs(t) do
		tinsert(list,v)
		v_k[v] = k 
	end

	table.sort(list,comp)
	local index = 1
	local len = #list
	return function()
		if index > len then
			return nil
		end

		local v = list[index]
		local k = v_k[v]
		index = index + 1
		return k,v
	end
end

--检查表不同
function util.check_def_table(new_t,old_t)
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
					if not ot[k] then
						des_map[k] = {_flag = "add",_new = v,_old = nil}
					end
				end
	
				for k,v in pairs(ot) do
					if not nt[k] then
						des_map[k] = {_flag = "reduce",_new = nil,_old = v}
					end
				end
	
				for k,v in pairs(nt) do
					if ot[k] then
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

--更新表依赖
function util.update_tab_by_def(def,old_t,change_flags)
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

--不同转成string
function util.def_tostring(def)
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
			if not s1 then
				s1 = "nil"
			elseif type(s1) == 'table' then
				s1 = json.encode(s1)
			end

			if not s2 then
				s2 = "nil"
			elseif type(s2) == 'table' then
				s2 = json.encode(s2)
			end
			ret = ret .. string.format("%s %s[%s:%s] ",dk,flag,s1,s2)
		end
		return ret
	end

	return tstring(nil,def)
end

function util.dump(tab)
	local filter = {}
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
				str = str .. head_str .. tostring(k) .. ' = ' .. tostring(v) .. ' {\n'
			else
				str = str .. head_str .. tostring(v) .. '{\n'
			end
			for kk,vv in pairs(v) do
				if type(vv) == 'table' and filter[vv] then
					str = str .. head_str .. '\t' .. tostring(kk) .. ' = ' .. tostring(vv) .. ',\n'
				else
					str = str .. dp(kk,vv,level + 1)
				end
			end
			str = str .. head_str .. '}\n'
		else
			if k then
				str = str .. head_str .. tostring(k) .. ' = ' .. tostring(v) .. ',\n'
			else
				str = str .. head_str .. tostring(v) .. '\n'
			end
		end

		return str
	end

	return dp(nil,tab,0)
end

--table是否有环
function util.is_loop_table(check_table,is_route)
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

--创建 lua文件 查找规则，优先级 server下非service文件夹 > skynet_fly lualib下所有文件夹 > skynet lualib下所以文件夹
function util.create_luapath(skynet_fly_path)
	local server_path = './'
	local skynet_path = skynet_fly_path .. '/skynet'
	local lua_path = server_path .. '?.lua;'

	for file_name,file_path,file_info in util.diripairs(server_path) do
		if file_info.mode == 'directory' and file_name ~= 'service' then
			lua_path = lua_path .. file_path .. '/?.lua;'
		end
	end

	lua_path = lua_path .. skynet_fly_path .. '/lualib/?.lua;'
	for file_name,file_path,file_info in util.diripairs(skynet_fly_path .. '/lualib') do
		if file_info.mode == 'directory' then
			lua_path = lua_path .. file_path .. '/?.lua;'
		end
	end

	lua_path = lua_path .. skynet_path .. '/lualib/?.lua;'
	for file_name,file_path,file_info in util.diripairs(skynet_path .. '/lualib') do
		if file_info.mode == 'directory' then
			lua_path = lua_path .. file_path .. '/?.lua;'
		end
	end

	return lua_path
end

return util