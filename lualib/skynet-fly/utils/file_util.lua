---#API
---#content ---
---#content title: file_util file相关
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","工具函数"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [file_util](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/utils/file_util.lua)
local lfs = require "lfs"
local string_util = require "skynet-fly.utils.string_util"

local string = string
local tinsert = table.insert
local tremove = table.remove
local assert = assert
local tostring = tostring
local io = io

local M = {}

---#desc 递归遍历目录
---@param path_url string 路径
---@param max_depth? number|nil 最大深度 nil表示到底
---@return function 遍历函数
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

---#desc skynet_fly luapath 的创建函数
---@param skynet_fly_path string 路径
---@return string lua_path
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

---#desc 读取整个文件内容 
---@param file_path string 文件路径
---@return string content内容
function M.readallfile(file_path)
	local file = io.open(file_path,'r')
	assert(file,"can`t open file_path " .. tostring(file_path))
	local str = file:read("*all")
	file:close()
	return str
end

---#desc 获取当前目录文件夹名称
---@return string 文件夹名称
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

---#desc 路径拼接 
---@param a string 路径1
---@param b string 路径2
---@return string 拼接后路径
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
---#desc gin风格转换成 openapi风格  /users/:name -> /users/{name}
---@param path string 路径
---@return string 转换后路径
function M.convert_path(path)
    path = string.gsub(path, ":([^/]*)", "{%1}")
    path = string.gsub(path, "%*(%w*)", "{*%1}")
    return path
end

---#desc 递归创建文件夹
---@param path string 路径
---@return boolean|nil 结果
---@return string? 失败原因
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

---#desc Linux文件夹风格转成windows
---@param linux_path string 路径
---@return string 路径
function M.convert_linux_to_windows_relative(linux_path)
    -- 替换斜杠为反斜杠
    local windows_path = linux_path:gsub("/", "\\")
    return windows_path
end

---#desc windows文件夹风格转成linux
---@param window_path string 路径
---@return string 路径
function M.convert_windows_to_linux_relative(window_path)
	local linux_path = window_path:gsub("\\", "/")
    return linux_path
end

---#desc 是否windows系统
---@return boolean 结果
function M.is_window()
	return package.config:sub(1, 1) == '\\'
end

---#desc 文件拷贝工具
---@param is_dir? boolean 是否路径
---@return table obj set_source_target = function(source, target)设置来源目标  execute = function()执行拷贝
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

---#desc 删除文件夹
---@param dir_path string 路径
---@return boolean?  suc
---@return exitcode? exitcode
---@return integer?  code
function M.rmdir(dir_path)
	if M.is_window() then
		return os.execute(string.format('rmdir /s /q "%s"', dir_path))
	else
		return os.execute("rm -rf " .. dir_path)
	end
end

return M