--- Matcher
--

local utils = require "radix-router.utils"

local ipairs = ipairs
local EMPTY = utils.readonly({})

local Matcher = {}
local mt = { __index = Matcher }

local DEFAULTS = {
  ["method"] = require("radix-router.matcher.method"),
  ["host"] = require("radix-router.matcher.host"),
}


function Matcher.new(enabled_names, custom_matchers)
  local chain = {}

  for _, matcher in ipairs(custom_matchers or EMPTY) do
    table.insert(chain, matcher)
  end

  for _, name in ipairs(enabled_names or EMPTY) do
    local matcher = DEFAULTS[name]
    if not matcher then
      return nil, "invalid matcher name: " .. name
    end
    table.insert(chain, matcher)
  end

  return setmetatable({
    chain = chain,
    chain_n = #chain,
  }, mt)
end


function Matcher:process(route)
  for _, matcher in ipairs(self.chain) do
    if type(matcher.process) == "function" then
      local err = matcher.process(route)
      if err then
        return nil, err
      end
    end
  end
  return true
end


function Matcher:match(route, ctx, matched)
  for i = 1, self.chain_n do
    local matcher = self.chain[i]
    if not matcher.match(route, ctx, matched) then
      return false
    end
  end
  return true
end


return Matcher