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
--max_depth 最大遍历深度 nil表示到底
function M.diripairs(path_url, max_depth)
	local stack = {}
	
	local function push_stack(path, depth)
		local next,meta1,meta2 = lfs.dir(path)
		tinsert(stack,{
			path = path,
			next = next,
			meta1 = meta1,
			meta2 = meta2,
			depth = depth,
		})
	end

	local root_info = lfs.attributes(path_url)
	if root_info and root_info.mode == 'directory' then
		push_stack(path_url, 0)
	end

	return function() 
		while #stack > 0 do
			local cur = stack[#stack]
			local file_name = cur.next(cur.meta1,cur.meta2)
			if file_name == '..' or file_name == '.' then
			elseif file_name then
				local file_path = M.path_join(cur.path, '/' .. file_name)
				local file_info, errmsg, errno = lfs.attributes(file_path)
				local depth = cur.depth
				if file_info and file_info.mode == 'directory' then
					if not max_depth or depth < max_depth then
						push_stack(file_path, depth + 1)
					end
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
	local strsplit = nil
	--window系统下
	if package.config:sub(1, 1) == '\\' then
		strsplit = string_util.split(curdir,'\\')
	else
		strsplit = string_util.split(curdir,'/')
	end

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

--递归创建文件夹
function M.mkdir(path)
    -- 逐层获取并创建每个文件夹
    local current_path = ""

    for part in path:gmatch("([^/\\]+)") do
        current_path = current_path .. part .. "/"

        -- 检查当前路径是否存在
        if lfs.attributes(current_path) == nil then
            -- 如果不存在，则创建目录
            local success, err = lfs.mkdir(current_path)
            if not success then
                return nil, "Error creating directory: " .. current_path .. " - " .. err
            end
        end
    end

    return true
end

function M.convert_linux_to_windows_relative(linux_path)
    -- 替换斜杠为反斜杠
    local windows_path = linux_path:gsub("/", "\\")
    return windows_path
end

function M.convert_windows_to_linux_relative(window_path)
	local linux_path = window_path:gsub("\\", "/")
    return linux_path
end

function M.is_window()
	return package.config:sub(1, 1) == '\\'
end

function M.new_copy_file(is_dir)
	local cmd = nil
	--windows
	local is_window = M.is_window()
	if is_window then
		if is_dir then
			cmd = "xcopy "
		else
			cmd = "copy "
		end
	else
		if is_dir then
			cmd = "cp -r "
		else
			cmd = "cp "
		end
	end

	local list = {}
	return {
		set_source_target = function(source, target)
			if is_window then
				if is_dir then
					table.insert(list, cmd .. M.convert_linux_to_windows_relative(source) .. ' ' .. M.convert_linux_to_windows_relative(target) .. ' /E /I /Y')
				else
					table.insert(list, cmd .. M.convert_linux_to_windows_relative(source) .. ' ' .. M.convert_linux_to_windows_relative(target) .. ' /Y')
				end
			else
				table.insert(list, cmd .. source .. ' ' .. target)
			end
		end,

		execute = function()
			local excute_cmd = nil
			if is_window then
				excute_cmd = table.concat(list, " && ")
			else
				excute_cmd = table.concat(list, ";")
			end

			return os.execute(excute_cmd)
		end
	}
end

--递归删除文件夹
function M.rmdir(dir_path)
	if M.is_window() then
		return os.execute("rmdir /S /Q " .. dir_path)
	else
		return os.execute("rm -rf " .. dir_path)
	end
end

return M