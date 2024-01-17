--- HostMatcher

local utils = require "radix-router.utils"

local ipairs = ipairs
local str_byte = string.byte
local starts_with = utils.starts_with
local ends_with = utils.ends_with

local BYTE_ASTERISK = str_byte("*")

local _M = {}

function _M.process(route)
  if route.hosts then
    local hosts = { [0] = 0 }
    for _, host in ipairs(route.hosts) do
      local host_n = #host
      local wildcard_n = 0
      for n = 1, host_n do
        if str_byte(host, n) == BYTE_ASTERISK then
          wildcard_n = wildcard_n + 1
        end
      end
      if wildcard_n > 1 then
        return nil, "invalid host"
      elseif wildcard_n == 1 then
        local n = hosts[0] + 1
        hosts[0] = n
        hosts[n] = host -- wildcard host
      else
        hosts[host] = true
      end
    end
    route.hosts = hosts
  end
end

function _M.match(route, ctx, matched)
  if route.hosts then
    local host = ctx.host
    if not host then
      return false
    end
    if not route.hosts[host] then
      if route.hosts[0] == 0 then
        return false
      end

      local wildcard_match = false
      local host_n = #host
      local wildcard_host, wildcard_host_n
      for i = 1, route.hosts[0] do
        wildcard_host = route.hosts[i]
        wildcard_host_n = #wildcard_host
        if host_n >= wildcard_host_n then
          if str_byte(wildcard_host) == BYTE_ASTERISK then
            -- case *.example.com
            if ends_with(host, wildcard_host, host_n, wildcard_host_n, 1) then
              wildcard_match = true
              break
            end
          else
            -- case example.*
            if starts_with(host, wildcard_host, host_n, wildcard_host_n - 1) then
              wildcard_match = true
              break
            end
          end
        end
      end
      if not wildcard_match then
        return false
      end
      if matched then
        matched.host = wildcard_host
      end
    else
      if matched then
        matched.host = host
      end
    end
  end

  return true
end

return _M