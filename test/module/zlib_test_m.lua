local skynet = require "skynet"
local zlib = require "zlib"
local log = require "log"

local assert = assert

local CMD = {}

function CMD.start()
	local data = "dsfdsfdsfdsfdsfdsfdsfdsf"
	local p = zlib.compress(data)
	local dedata = zlib.decompress(p)
	log.info("plen :",data:len(),p:len(),dedata)
	assert(dedata == data)
	
	return true
end

function CMD.exit()

end

return CMD