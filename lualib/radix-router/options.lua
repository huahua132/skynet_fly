--- Options Router options
--


local function options(opts)
  opts = opts or {}

  local default = {
    matcher_names = { "method", "host" },
    matchers = {},
    trailing_slash_match = false,
  }

  if opts.trailing_slash_match ~= nil then
    if type(opts.trailing_slash_match) ~= "boolean" then
      return nil, "invalid type trailing_slash_match"
    end
    default.trailing_slash_match = opts.trailing_slash_match
  end

  if opts.matcher_names ~= nil then
    if type(opts.matcher_names) ~= "table" then
      return nil, "invalid type matcher_names"
    end
    default.matcher_names = opts.matcher_names
  end

  if opts.matchers ~= nil then
    for _, matcher in ipairs(opts.matchers) do
      if type(matcher.match) ~= "function" then
        return nil, "invalid type matcher.match"
      end
    end

    default.matchers = opts.matchers
  end

  return default
end


return {
  options = options,
}
