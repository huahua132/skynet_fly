local lfs = require "lfs"

local util = {}
local pairs = pairs
local type = type
local tonumber = tonumber
local tostring = tostring
local string = string
local table = table
local assert = assert
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

	local str = ""
	for line in file:lines() do
		str = str .. line .. '\n';
	end
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

return util