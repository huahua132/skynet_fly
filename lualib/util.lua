local lfs = require "lfs"

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

--map按 字符编码顺序排序后遍历
function util.kvsortipairs(map)
	local list = {}
	local k_type_map = {}
	for k,v in pairs(map) do
		local t = type(k)
		assert(t == 'number' or t == 'string',"k type err")
		local new_k = tostring(k)
		k_type_map[new_k] = t
	  	table.insert(list,new_k)
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
		table.insert(stack,{
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
				table.remove(stack,#stack)
			end
		end
		return nil,nil,nil
	end
end

--写luatable到文件中
function util.write_table(file_handle,pre_k,pre_v,level)
	local head_str = ""
	for i = 1,level do
		head_str = head_str .. '\t'
	end

	if type(pre_v) == 'table' then
		if pre_k then
			if type(pre_k) == 'number' then
				file_handle:write(head_str .. string.format("%s = {\n",pre_k))
			else
				file_handle:write(head_str .. string.format("'%s' = {\n",pre_k))
			end
		end
  
	  	for k,v in util.kvsortipairs(pre_v) do
			util.write_table(file_handle,k,v,level + 1)
	  	end
		if pre_k then
	  		file_handle:write(head_str .. '},\n')
		end
	else
	  	if type(pre_v) == 'number' or type(pre_v) == 'boolean' then
			file_handle:write(head_str .. string.format("%s = %s,\n",pre_k,pre_v))
	  	else
			file_handle:write(head_str .. string.format("%s = '%s',\n",pre_k,pre_v))
	  	end
	end
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
		table.insert(list,v)
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
function util.check_def_table(new_t,old_t,key)
	local des_map = {}

	local function add_des_map(key,sub_key,flag,new,old)
		if not sub_key then
			des_map[key] = {flag = flag,new = new,old = old}
		else
			if not des_map[key] then
				des_map[key] = {}
			end
			des_map[key][sub_key] = {flag = flag,new = new,old = old}
		end
	end

	local n_type = type(new_t)
	local o_type = type(old_t)
	if n_type ~= o_type then
		add_des_map(key,nil,"typedef",n_type,o_type)
	else
	  	if n_type == 'table' then
			for k,v in pairs(new_t) do
		  		if not old_t[k] then
					add_des_map(key,k,"add",v,nil)
		  		end
			end
  
			for k,v in pairs(old_t) do
				if not new_t[k] then
					add_des_map(key,k,"reduce",nil,v)
				end
			end
  
			for k,v in pairs(new_t) do
				if old_t[k] then
					local temp_des_map = util.check_def_table(new_t[k],old_t[k],k)
					if next(temp_des_map) then
						if not des_map[key] then
							des_map[key] = {}
						end
						des_map[key][k] = temp_des_map[k]
					end
				end
			end
		else
			if new_t ~= old_t then
				add_des_map(key,nil,"valuedef",new_t,old_t)
			end
		end
	end
  
	return des_map
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

return util