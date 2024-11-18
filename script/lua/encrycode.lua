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

local file_util = require "skynet-fly.utils.file_util"
local table_util = require "skynet-fly.utils.table_util"
local crypt = require "client.crypt"

local isok, err = file_util.mkdir(targetpath)
assert(isok, err)

targetpath = file_util.path_join(targetpath, '/')

local sfind = string.find
local sgsub = string.gsub
local loadfile = loadfile
local sdump = string.dump
local io = io

local copy_obj = file_util.new_copy_file(true)
copy_obj.set_source_target('./', targetpath)
local isok, err = copy_obj:execute()
if not isok then
    error("cp err ", err)
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
            local isok, err = file_util.mkdir(dir_path)
            if not isok then
                print("create dir_path err ", dir_path, err)
            else
                local newfile = io.open(new_path, "w+b")
                if not newfile then
                    print("can`t openfile >>> ", new_path)
                else
                    local size = string.pack(">I4", #encode_str)
                    newfile:write("skynet-fly-encrycode")
                    newfile:write(size)
                    newfile:write(encode_str)
                    newfile:close()
                    
                    local func,err = loadfile(new_path)                  --测试加载
                    if not func then
                        print("loadfile err ", err)
                    else
                        print("encry file succ:", new_path, #encode_str)
                    end
                end
            end
        end
    end
end