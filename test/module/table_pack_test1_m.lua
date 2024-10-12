local CMD = {}

function CMD.start()
    return true
end

function CMD.exit()
    return true
end

function CMD.ping()
    return 1,nil,nil,nil,nil,nil,4,nil,nil
end

return CMD