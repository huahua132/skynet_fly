--- Default style path parser.
--
-- Parses the path into multiple tokens with patterns.
--
-- patterns
-- - `{name}`: variable parameter
-- - `{*name}`: catch-all parameter

local constants = require "radix-router.constants"

local byte = string.byte
local sub = string.sub

local BYTE_COLON = byte(":")
local BYTE_ASTERISK = byte("*")
local BYTE_LEFT_BRACKET = byte("{")
local BYTE_RIGHT_BRACKET = byte("}")
local BYTE_SLASH = byte("/")

local TOKEN_TYPES = constants.token_types

local _M = {}
local mt = { __index = _M }

local STATES = {
  static = 1,
  variable_start = 2,
  variable_end = 3,
  finish = 4,
}


function _M.new()
  return setmetatable({}, mt)
end


function _M:update(path)
  self.path = path
  self.path_n = #path
  self:reset()
  return self
end


function _M:reset()
  self.anchor = 1
  self.pos = 1
  self.state = nil
end


function _M:next()
  if self.state == STATES.finish then
    return nil
  end

  local char, token, token_type
  while self.pos <= self.path_n do
    char = byte(self.path, self.pos)
    --print("pos: " .. self.pos .. "(" .. string.char(char) .. ")")
    if self.state == nil or self.state == STATES.static then
      if char == BYTE_LEFT_BRACKET then
        if self.state == STATES.static then
          token = sub(self.path, self.anchor, self.pos - 1)
          token_type = self.token_type(token)
          self.anchor = self.pos
        end
        self.state = STATES.variable_start
      else
        self.state = STATES.static
      end
    elseif self.state == STATES.variable_start then
      if char == BYTE_RIGHT_BRACKET then
        self.state = STATES.variable_end
      end
    elseif self.state == STATES.variable_end then
      self.state = STATES.static
      token = sub(self.path, self.anchor, self.pos - 1)
      token_type = self.token_type(token)
      self.anchor = self.pos
    end

    self.pos = self.pos + 1

    if token then
      return token, token_type
    end
  end

  self.state = STATES.finish
  token = sub(self.path, self.anchor, self.pos)
  return token, self.token_type(token)
end

function _M:parse()
  self:reset()

  local tokens = {}
  local n = 0
  local token = self:next()
  while token do
    n = n + 1
    tokens[n] = token
    token = self:next()
  end

  return tokens
end

function _M.token_type(token)
  if byte(token) == BYTE_LEFT_BRACKET and
    byte(token, #token) == BYTE_RIGHT_BRACKET then
    if byte(token, 2) == BYTE_ASTERISK then
      return TOKEN_TYPES.catchall
    end
    return TOKEN_TYPES.variable
  end

  return TOKEN_TYPES.literal
end

function _M.is_dynamic(path)
  local patn_n = #path
  for i = 1, patn_n do
    local char = byte(path, i)
    if char == BYTE_LEFT_BRACKET or char == BYTE_RIGHT_BRACKET then
      return true
    end
  end
  return false
end

function _M:params()
  local param_names_n = 0
  local param_names = {}
  local token, token_type = self:next()
  while token do
    if token_type == TOKEN_TYPES.variable or token_type == TOKEN_TYPES.catchall then
      if byte(token) == BYTE_LEFT_BRACKET and byte(token, #token) == BYTE_RIGHT_BRACKET then
        local param_name = sub(token, 2, #token - 1)
        if byte(param_name) == BYTE_ASTERISK then
          param_name = sub(param_name, 2)
        end
        for i = 1, #param_name do
          if byte(param_name, i) == BYTE_COLON then
            param_name = sub(param_name, 1, i - 1)
            break
          end
        end
        if #param_name > 0 then
          param_names_n = param_names_n + 1
          param_names[param_names_n] = param_name
        end
      end
    end

    token, token_type = self:next()
  end

  return param_names
end


function _M:bind_params(req_path, req_path_n, params, trailing_slash_mode)
  if not params then
    return
  end

  local path = self.path
  local path_n = self.path_n
  local pos, anchor, path_start = 1, 1, 0
  local state, char, param_n
  while pos <= path_n do
    char = byte(path, pos)
    -- local debug = string.char(char)
    if state == nil or state == STATES.static then
      if char == BYTE_LEFT_BRACKET then
        if state == STATES.static then
          anchor = pos
        end
        state = STATES.variable_start
      else
        state = STATES.static
      end
      path_start = path_start + 1
    elseif state == STATES.variable_start then
      if char == BYTE_RIGHT_BRACKET then
        state = STATES.variable_end
      end
    elseif state == STATES.variable_end then
      state = STATES.static
      local param_name = sub(path, anchor + 1, pos - 2)
      param_n = pos - anchor
      if byte(param_name) == BYTE_ASTERISK then
        param_name = sub(param_name, 2)
        param_n = param_n - 1
      end
      for i = 1, param_n do
        if byte(param_name, i) == BYTE_COLON then
          param_name = sub(param_name, 1, i - 1)
          param_n = i - 1
          break
        end
      end
      if param_n > 0 then
        local i = path_start
        while i <= req_path_n and byte(req_path, i) ~= char do
          i = i + 1
        end
        params[param_name] = sub(req_path, path_start, i - 1)
        path_start = i
      end
    end

    pos = pos + 1
  end

  if state == STATES.variable_end then
    local param_name = sub(path, anchor + 1, pos - 2)
    param_n = pos - anchor
    if byte(param_name) == BYTE_ASTERISK then
      param_name = sub(param_name, 2)
      param_n = param_n - 1
    end
    for i = 1, param_n do
      if byte(param_name, i) == BYTE_COLON then
        param_name = sub(param_name, 1, i - 1)
        param_n = i - 1
        break
      end
    end
    if param_n > 0 then
      if trailing_slash_mode and byte(req_path, -1) == BYTE_SLASH then
        params[param_name] = sub(req_path, path_start, path_n - 1)
      else
        params[param_name] = sub(req_path, path_start)
      end
    end
  end
end

return _M
