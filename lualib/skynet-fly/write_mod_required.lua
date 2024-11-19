local skynet = require "skynet"
local lfs = require "lfs"
local log = require "skynet-fly.log"
local file_util = require "skynet-fly.utils.file_util"
local os = os
local io = io 
local pairs = pairs
local string = string

local loadmodsfile = skynet.getenv("loadmodsfile")

return function(headname, mod_name, loaded)
	local write_dir = headname .. "_" .. loadmodsfile:sub(1, #loadmodsfile - 4) --去掉.lua
	local isok, err = file_util.mkdir(write_dir)
	if not isok then
		log.error("write_mod_required mkdir err ", headname, err)
		return
	end
	local info_file_name = mod_name .. '.required'
	local info_file_dir = write_dir .. '/' .. info_file_name
	local info_file = io.open(info_file_dir,'w+')
	if not info_file then
		log.error("write_mod_required open file err ",info_file_dir)
		return
	end

	local g_tb = _G
	local package = g_tb.package
	info_file:write("return {\n")

	for f_name in pairs(loaded) do
		local f_dir = package.searchpath(f_name, package.path)
		if f_dir then
			local f_info, errinfo, errno = lfs.attributes(f_dir)
			if f_info then
				local f_last_change_time = f_info.modification
				info_file:write(string.format("\t['%s'] = {\n",f_name))
				info_file:write(string.format("\t\t['dir'] = '%s',\n",file_util.convert_windows_to_linux_relative(f_dir)))
				info_file:write(string.format("\t\t['last_change_time'] = %s,\n",f_last_change_time))
				info_file:write(string.format("\t},\n"))
				skynet.yield()
			else
				log.error_fmt("write_mod_required can`t get fileinfo filename[%s] errinfo[%s] errno[%s]", f_name, errinfo, errno)
			end
		end
	end

	info_file:write("}\n")
	info_file:close()
end
