local lfs = require "lfs"
local string_util = require "skynet-fly.utils.string_util"

local string = string
local tinsert = table.insert
local tremove = table.remove
local assert = assert
local tostring = tostring
local io = io

local M = {}

--递归遍历目录
function M.diripairs(path_url)
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

	local root_info = lfs.attributes(path_url)
	if root_info and root_info.mode == 'directory' then
		push_stack(path_url)
	end

	return function() 
		while #stack > 0 do
			local cur = stack[#stack]
			local file_name = cur.next(cur.meta1,cur.meta2)
			if file_name == '..' or file_name == '.' then
			elseif file_name then
				local file_path = M.path_join(cur.path, '/' .. file_name)
				local file_info, errmsg, errno = lfs.attributes(file_path)
				if file_info and file_info.mode == 'directory' then
					push_stack(file_path)
				end
				return file_name, file_path, file_info, errmsg, errno
			else
				tremove(stack,#stack)
			end
		end
		return nil,nil,nil
	end
end

function M.create_luapath(skynet_fly_path)
	local server_path = './'
	local skynet_path = M.path_join(skynet_fly_path, '/skynet')
	local common_path = '../../commonlualib/'

	--server文件夹
	local lua_path = server_path .. '?.lua;'

	--server 下 ./module文件夹
	lua_path = lua_path .. server_path .. 'module/?.lua;'

	--server上上级目录commonlualib文件夹
	lua_path = lua_path .. common_path .. '?.lua;'

	--server上上级目录commonlualib/module文件夹
	lua_path = lua_path .. common_path .. '/module/?.lua;'

	--skynet_fly lualib文件夹
	lua_path = lua_path .. M.path_join(skynet_fly_path, '/lualib/?.lua;')

	--skyent_fly module文件夹
	lua_path = lua_path .. M.path_join(skynet_fly_path, '/module/?.lua;')

	--skynet lualib文件夹
	lua_path = lua_path .. skynet_path .. '/lualib/?.lua;'

	return lua_path
end

--打开并读取文件
function M.readallfile(file_path)
	local file = io.open(file_path,'r')
	assert(file,"can`t open file_path " .. tostring(file_path))
	local str = file:read("*all")
	file:close()
	return str
end

--获取当前目录文件夹名称
function M.get_cur_dir_name()
	local curdir = lfs.currentdir()
	local strsplit = string_util.split(curdir,'/')
	return strsplit[#strsplit]
end

--路径拼接
function M.path_join(a,b)
    if a:sub(-1) == "/" then
        if b:sub(1, 1) == "/" then
            return a .. b:sub(2)
        end
        return a .. b
    end
    if b:sub(1, 1) == '/' then
        return a .. b
    end
    return string.format("%s/%s", a, b)
end

-- converts gin style to openapi style. /users/:name -> /users/{name}
function M.convert_path(path)
    path = string.gsub(path, ":([^/]*)", "{%1}")
    path = string.gsub(path, "%*(%w*)", "{*%1}")
    return path
end

return M