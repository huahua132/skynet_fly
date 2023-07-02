local skynet = require "skynet"
local lfs = require "lfs"
local os = os
local io = io
local pairs = pairs
local string = string

local ignore_map = {
  ["skynet"] = true,
}

return function(mod_name,loaded)
	local write_dir = "module_info"
	if not os.execute("mkdir -p " .. write_dir) then
		skynet.error("write_module_info mkdir err ")
		return
	end
	local pre_time = os.time()
	local info_file_name = mod_name .. '.required'
	local info_file_dir = write_dir .. '/' .. info_file_name
	local info_file = io.open(info_file_dir,'w+')
	if not info_file then
		skynet.error("write_module_info open file err ",info_file_dir)
		return
	end

	local g_tb = _G
	local package = g_tb.package
	info_file:write("return {\n")

	for f_name in pairs(loaded) do
		if not ignore_map[f_name] then
		local f_dir = package.searchpath(f_name, package.path)
			if f_dir then
				local f_info = lfs.attributes(f_dir)
				if f_info then
				local f_last_change_time = f_info.modification
				info_file:write(string.format("\t['%s'] = {\n",f_name))
				info_file:write(string.format("\t\t['dir'] = '%s',\n",f_dir))
				info_file:write(string.format("\t\t['last_change_time'] = %s,\n",f_last_change_time))
				info_file:write(string.format("\t},\n"))
				skynet.yield()
				end
			end
		end
	end

	info_file:write("}\n")
	info_file:close()
end
