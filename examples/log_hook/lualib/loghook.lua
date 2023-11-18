local log = require "log"
local string = string

return function(msg)
    log.info("loghook >>>>>>>>>>>>>>>>> ",msg)
end