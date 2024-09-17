--- Trie
--
--

local utils = require "radix-router.utils"
local constants = require "radix-router.constants"

local str_sub = string.sub
local lcp = utils.lcp
local type = type

local TOKEN_TYPES = constants.token_types
local TYPES = constants.node_types
local idx = constants.node_indexs

local TrieNode = {}
local mt = { __index = TrieNode }


function TrieNode.new(node_type, path, children, value)
  local pathn = path and #path or 0
  local self = { node_type, path, pathn, children, value }
  return setmetatable(self, mt)
end


function TrieNode:set(value, fn)
  if type(fn) == "function" then
    fn(self)
    return
  end
  self[idx.value] = value
end


local function insert(node, path, value, fn, parser)
  parser:update(path)
  local token, token_type = parser:next()
  while token do
    if token_type == TOKEN_TYPES.variable then
      node[idx.type] = TYPES.variable
      node[idx.pathn] = 0
    elseif token_type == TOKEN_TYPES.catchall then
      node[idx.type] = TYPES.catchall
      node[idx.pathn] = 0
    else
      node[idx.type] = TYPES.literal
      node[idx.path] = token
      node[idx.pathn] = #token
    end

    token, token_type = parser:next()
    if token then
      local child = TrieNode.new()
      if token_type == TOKEN_TYPES.literal then
        local char = str_sub(token, 1, 1)
        node[idx.children] = { [char] = child }
      else
        node[idx.children] = { [token_type] = child }
      end
      node = child
    end
  end

  node:set(value, fn)
end


local function split(node, path, prefix_n)
  local child = TrieNode.new(
    TYPES.literal,
    str_sub(node[idx.path], prefix_n + 1),
    node[idx.children],
    node[idx.value]
  )

  -- update current node
  node[idx.type] = TYPES.literal
  node[idx.path] = str_sub(path, 1, prefix_n)
  node[idx.pathn] = #node[idx.path]
  node[idx.value] = nil
  node[idx.children] = { [str_sub(child[idx.path], 1, 1)] = child }
end


function TrieNode:add(path, value, fn, parser)
  if not self[idx.path] and not self[idx.type] then
    -- insert to current empty node
    insert(self, path, value, fn, parser)
    return
  end

  local node = self
  local token, token_type
  while true do
    local common_prefix_n = lcp(node[idx.path], path)

    if common_prefix_n < node[idx.pathn] then
      split(node, path, common_prefix_n)
    end

    if common_prefix_n < #path then
      if node[idx.type] == TYPES.variable then
        -- token must a variable
        path = str_sub(path, #token + 1)
        if #path == 0 then
          break
        end
      elseif node[idx.type] == TYPES.catchall then
        -- token must a catchall
        -- catchall node matches entire path
        break
      else
        path = str_sub(path, common_prefix_n + 1)
      end

      local child
      if node[idx.children] then
        local first_char = str_sub(path, 1, 1)
        if node[idx.children][first_char] then
          -- found literal child
          child = node[idx.children][first_char]
        else
          parser:update(path)
          token, token_type = parser:next() -- store the next token of path
          if node[idx.children][token_type] then
            -- found either variable or catchall child
            child = node[idx.children][token_type]
          end
        end
      end

      if child then
        node = child
      else
        child = TrieNode.new()
        insert(child, path, value, fn, parser)
        node[idx.children] = node[idx.children] or {}
        if child[idx.type] == TYPES.literal then
          local first_char = str_sub(path, 1, 1)
          node[idx.children][first_char] = child
        else
          node[idx.children][token_type] = child
        end
        return
      end
    else
      break
    end
  end

  node:set(value, fn)
end


return TrieNode
