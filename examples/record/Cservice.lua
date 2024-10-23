local skynet = require "skynet.manager"

skynet.start(function()
    skynet.register('.Cservice')
end)