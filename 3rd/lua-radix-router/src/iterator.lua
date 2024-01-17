--- Iterator an iterator for iterating radix tree and storing states.
--
--

local utils = require "radix-router.utils"
local constants = require "radix-router.constants"

local starts_with = utils.starts_with
local str_sub = string.sub
local str_char = string.char
local str_byte = string.byte

local BYTE_SLASH = str_byte("/")
local TYPE_VARIABLE = constants.node_types.variable
local TYPE_CATCHALL = constants.node_types.catchall

local _M = {}
local mt = { __index = _M }

--[[ A copy of node indexs
local i_type = 1
local i_path = 2
local i_pathn = 3
local i_children = 4
local i_value = 5
]]

function _M.new(options)
  local self = {
    trailing_slash_match = options.trailing_slash_match,
    stack_node = utils.new_table(4, 0),
    stack_paths = utils.new_table(4, 0),
    stack_pathns = utils.new_table(4, 0),
    stack_n = 0,
    values = utils.new_table(4, 0),
  }

  return setmetatable(self, mt)
end


function _M:push(node, path, path_n)
  local stack_n = self.stack_n + 1
  self.stack_node[stack_n] = node
  self.stack_paths[stack_n] = path
  self.stack_pathns[stack_n] = path_n
  self.stack_n = stack_n
end


function _M:prev()
  if self.stack_n == 0 then
    return nil
  end
  -- pop a state from stack
  local stack_n = self.stack_n
  local path = self.stack_paths[stack_n]
  local path_n = self.stack_pathns[stack_n]
  local node = self.stack_node[stack_n]
  self.stack_n = stack_n - 1
  return node, path, path_n
end


function _M:reset()
  self.stack_n = 0
end


function _M:find(node, path, path_n)
  local child
  local node_path, node_path_n
  local first_char
  local has_variable
  local matched_n = 0
  local trailing_slash_match = self.trailing_slash_match

  -- luacheck: ignore
  while true do
    ::continue::
    if node[1] == TYPE_VARIABLE then
      local not_found = true
      local i = 0
      for n = 1, path_n do
        first_char = str_byte(path, n)
        if first_char == BYTE_SLASH or
          (node[4] and node[4][str_char(first_char)]) then
          break
        end
        i = n
      end
      if i < path_n then
        path = str_sub(path, i + 1)
        path_n = path_n - i
        if trailing_slash_match and path == "/" and node[5] then
          -- matched when path has a extra slash
          matched_n = matched_n + 1
          self.values[matched_n] = node[5]
        end
        if node[4] then
          first_char = str_sub(path, 1, 1)
          child = node[4][first_char]
          if child then
            -- found static node that matches the path
            node = child
            not_found = false
          end
        end
      elseif node[5] then
        -- the path is variable
        matched_n = matched_n + 1
        self.values[matched_n] = node[5]
      end

      -- case1: the node doesn't contians child to match to the path
      -- case2: the path is variable value, but current node doesn't have value
      if not_found then
        if trailing_slash_match and node[4] then
          -- look up the children to see if "/" child with value exists
          child = node[4]["/"]
          if child and child[5] then
            matched_n = matched_n + 1
            self.values[matched_n] = child[5]
          end
        end

        break
      end
    end


    -- the node must be a literal node
    node_path = node[2]
    node_path_n = node[3]

    if path_n > node_path_n then
      if starts_with(path, node_path, path_n, node_path_n) then
        path = str_sub(path, node_path_n + 1)
        path_n = path_n - node_path_n

        child = node[4] and node[4][TYPE_CATCHALL]
        if child then
          matched_n = matched_n + 1
          self.values[matched_n] = child[5]
        end

        has_variable = false
        child = node[4] and node[4][TYPE_VARIABLE]
        if child then
          -- node has a variable child, but we don't know whether
          -- the path can finally match the path.
          -- therefore, record the state(node, path, path_n) to be used later.
          self:push(child, path, path_n)
          has_variable = true
        end

        first_char = str_sub(path, 1, 1)
        child = node[4] and node[4][first_char]
        if child then
          -- found static node that matches the path
          node = child
          goto continue
        end

        if has_variable then
          node = self:prev()
          goto continue
        end

        if trailing_slash_match and path == "/" and node[5] then
          matched_n = matched_n + 1
          self.values[matched_n] = node[5]
        end
      end
    elseif path == node_path then
      -- considers matched if this node has catchall child
      child = node[4] and node[4][TYPE_CATCHALL]
      if child then
        matched_n = matched_n + 1
        self.values[matched_n] = child[5]
      end

      if node[5] then
        matched_n = matched_n + 1
        self.values[matched_n] = node[5]
      end
    else
      -- #path < #node_path
      if trailing_slash_match and path_n == node_path_n - 1
        and str_byte(node_path, node_path_n) == BYTE_SLASH and node[5] then
        matched_n = matched_n + 1
        self.values[matched_n] = node[5]
      end
    end

    break
  end

  if matched_n > 0 then
    return self.values, matched_n
  end

  return nil, 0
end


return _M
