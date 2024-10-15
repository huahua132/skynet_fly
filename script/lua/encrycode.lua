local assert = assert
local ARGV = { ... }
local skynet_fly_path = ARGV[1]
local key = ARGV[2]
local targetpath = ARGV[3]
assert(skynet_fly_path, '缺少 skynet_fly_path')
assert(key, "缺少 key")
assert(key:len() == 8, "key 长度不对 ".. key)

local skynet_path = skynet_fly_path .. '/skynet'

package.cpath = skynet_fly_path .. "/luaclib/?.so;" .. skynet_path .. '/luaclib/?.so;'
package.path = './?.lua;' .. skynet_fly_path .. "/lualib/?.lua;"

if not targetpath then
    targetpath = './encrycode/'
end

if not os.execute("mkdir -p " .. targetpath) then
	error("create targetpath err")
end

local file_util = require "skynet-fly.utils.file_util"
local table_util = require "skynet-fly.utils.table_util"
local crypt = require "client.crypt"

targetpath = file_util.path_join(targetpath, '/')

local sfind = string.find
local sgsub = string.gsub
local loadfile = loadfile
local sdump = string.dump
local io = io

local cmd = string.format("cp -r %s %s", './', targetpath)
if not os.execute(cmd) then
    error("cp err ", cmd)
end

for file_name, file_path, file_info in file_util.diripairs('./') do
    if sfind(file_name, '.lua', nil, true) and not sfind(file_path, './encrycode/', nil, true) and not sfind(file_path, './make/', nil, true) then
        local code_func = loadfile(file_path)
        if not code_func then
            print("can`t loadfile >>> ", file_path)
        else
            local code_str = string.dump(code_func)
            local encode_str = crypt.desencode(key, code_str)
            local new_path = sgsub(file_path, './', targetpath, 1)
            local dir_path = sgsub(new_path, file_name, '', 1)
            if not os.execute("mkdir -p " .. dir_path) then
                print("create dir_path err ", dir_path)
            else
                local newfile = io.open(new_path, "w+")
                if not newfile then
                    print("can`t openfile >>> ", new_path)
                else
                    newfile:write(encode_str)
                    newfile:close()
                    print("encry file succ:", new_path)
                    loadfile(new_path)                  --测试加载
                end
            end
        end
    end
end