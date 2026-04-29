#!/usr/bin/env luajit

--[[
analyze_ldoc.lua - LDoc Comment Analyzer for lua-openssl

This script analyzes LDoc comments in C source files to check their validity
and provide feedback for documentation improvement.

Usage: luajit .github/shell/analyze_ldoc.lua [OPTIONS] [PATH]

Dependencies: lpeg, lfs
Author: GitHub Copilot Assistant
]]

local lpeg = require("lpeg")
local lfs = require("lfs")

-- LPEG pattern utilities
local P, R, S, V = lpeg.P, lpeg.R, lpeg.S, lpeg.V
local C, Cc, Ct, Cs = lpeg.C, lpeg.Cc, lpeg.Ct, lpeg.Cs

-- Configuration options
local config = {
    verbose = false,
    max_issues_per_file = 50,
    show_undocumented_list = true,
    show_issues = true
}

-- Show help information
local function show_help()
    print("LDoc Documentation Analyzer")
    print("Usage: analyze_ldoc.lua [OPTIONS] [PATH]")
    print("")
    print("Options:")
    print("  -h, --help           Show this help message")
    print("  -v, --verbose        Enable verbose output")
    print("  --max-issues=N       Set maximum issues to show per file (default: 50)")
    print("  --no-issues          Don't show individual issues")
    print("  --no-undocumented    Don't show undocumented function lists")
    print("")
    print("PATH can be a directory (will analyze all .c files) or a specific .c file")
    print("If no PATH is provided, defaults to 'src' directory")
    print("")
    print("Examples:")
    print("  luajit analyze_ldoc.lua                    # Analyze src directory")
    print("  luajit analyze_ldoc.lua src/cipher.c       # Analyze single file")
    print("  luajit analyze_ldoc.lua -v src            # Verbose analysis")
    print("  luajit analyze_ldoc.lua --max-issues=10 src # Limit issues shown")
end

-- Parse command line arguments
local function parse_args(args)
    local path = "src"  -- Default path
    local i = 1

    while i <= #args do
        local arg = args[i]
        if arg == "-h" or arg == "--help" then
            show_help()
            os.exit(0)
        elseif arg == "-v" or arg == "--verbose" then
            config.verbose = true
        elseif arg == "--no-issues" then
            config.show_issues = false
        elseif arg == "--no-undocumented" then
            config.show_undocumented_list = false
        elseif arg:match("^--max%-issues=(%d+)$") then
            config.max_issues_per_file = tonumber(arg:match("^--max%-issues=(%d+)$"))
        elseif not arg:match("^%-") then
            -- This is the path argument
            path = arg
        else
            print("Unknown option: " .. arg)
            show_help()
            os.exit(1)
        end
        i = i + 1
    end

    return path
end

-- ANSI color codes for better output
local colors = {
    reset = "\27[0m",
    red = "\27[31m",
    green = "\27[32m",
    yellow = "\27[33m",
    blue = "\27[34m",
    magenta = "\27[35m",
    cyan = "\27[36m",
    bold = "\27[1m"
}

local function printf(fmt, ...)
    print(string.format(fmt, ...))
end

local function colored(color, text)
    return colors[color] .. text .. colors.reset
end

-- Statistics tracking
local stats = {
    total_files = 0,
    analyzed_files = 0,
    total_functions = 0,
    documented_functions = 0,
    total_comments = 0,
    valid_comments = 0,
    issues = {}
}

-- LPEG pattern utilities and definitions
local P, R, S, C, Ct, Cf, Cc = lpeg.P, lpeg.R, lpeg.S, lpeg.C, lpeg.Ct, lpeg.Cf, lpeg.Cc

-- Define basic LPEG patterns
local nl = P("\n") + P("\r\n") + P("\r")
local alpha = R("az", "AZ")
local digit = R("09")
local alnum = alpha + digit
local comment_start = P("/***")
local comment_end = P("*/")

-- 优化后的 C API 函数定义模式

-- 优化后的 C API 函数定义模式（支持多行和更宽松参数匹配）
local ws = lpeg.S(" \t")^0
local wsp = lpeg.S(" \t")^1
local static_kw = lpeg.P("static") * wsp
local int_kw = lpeg.P("int")
local openssl_prefix = lpeg.P("openssl_")
local identifier = (lpeg.R("az", "AZ") + lpeg.P("_")) * (lpeg.R("az", "AZ", "09") + lpeg.P("_"))^0
local lparen = lpeg.P("(")
-- 参数部分允许有换行和空格，只需包含 lua_State *L

-- LPEG patterns for function detection
local static_kw = P("static") * wsp
local return_types = P("int") + identifier
local pointer = P("*")
local lparen = P("(")
local rparen = P(")")

-- Pattern for single-line function definition
local single_line_func = ws * static_kw^-1 * return_types * wsp * pointer^0 * ws * C(identifier) * ws * lparen

-- Pattern for multi-line function (return type on separate line)
local multiline_return_type = ws * static_kw^-1 * return_types * ws * pointer^0 * ws * (nl + P(-1))
local multiline_func_name = ws * C(identifier) * ws * lparen

-- LPEG pattern for LDoc comment block
local comment_line = P("*") * (1 - nl)^0 * nl^-1
local ldoc_comment_content = (comment_line + (1 - P("*")))^0
local ldoc_comment = comment_start * ldoc_comment_content * comment_end

-- LPEG pattern for @function tag
local at_function = P("@function") * ws * C((1 - nl - P("@"))^0)

-- LPEG pattern for any @tag
local at_tag = P("@") * C(identifier) * ws * C((1 - nl - P("@"))^0)

-- Pattern for lines to skip entirely
local skip_line_patterns = ws * (P("#") + P("//") + P("*") + P("/") + P("return") +
                                P("if") * ws * lparen + P("while") * ws * lparen +
                                P("for") * ws * lparen)

-- LPEG patterns for luaL_Reg structure parsing
local lbrace = P("{")
local rbrace = P("}")
local comma = P(",")
local semicolon = P(";")
local quote = P('"')
local null_entry = ws * lbrace * ws * P("NULL") * ws * comma * ws * P("NULL") * ws * rbrace

-- Pattern to match luaL_Reg function entry: { "name", function_ptr },
local reg_entry = ws * lbrace * ws * quote * C((1 - quote)^0) * quote * ws * comma * ws * C(identifier) * ws * rbrace

-- LDoc tag patterns
local function tag_pattern(tagname)
    return P("@" .. tagname) * ws * (1 - nl - P("@"))^0
end

local ldoc_tags = {
    "module", "function", "tparam", "param", "treturn", "return",
    "usage", "see", "author", "since", "deprecated", "local"
}

-- Parse LDoc comment for tags using LPEG
local function parse_ldoc_comment(comment_text)
    local tags = {}
    local description = ""
    local lines = {}

    -- Split into lines and clean them
    for line in comment_text:gmatch("[^\r\n]+") do
        -- Remove leading * and whitespace using LPEG pattern
        local clean_line_pattern = ws * P("*")^-1 * ws * C((1 - P(-1))^0)
        local cleaned = clean_line_pattern:match(line)
        if cleaned then
            table.insert(lines, cleaned:trim())
        else
            table.insert(lines, line:trim())
        end
    end

    local in_description = true
    local current_tag = nil
    local current_content = {}

    for _, line in ipairs(lines) do
        -- Use LPEG to match @tag patterns
        local tag_name, tag_content = at_tag:match(line)
        if tag_name then
            -- Save previous tag if any
            if current_tag then
                if not tags[current_tag] then
                    tags[current_tag] = {}
                end
                table.insert(tags[current_tag], table.concat(current_content, " "):trim())
                current_content = {}
            end

            in_description = false
            current_tag = tag_name
            if tag_content and tag_content:trim() ~= "" then
                table.insert(current_content, tag_content:trim())
            end
        elseif current_tag then
            -- Continue collecting content for current tag
            if line ~= "" and not line:match("^[-=]+$") then
                table.insert(current_content, line)
            end
        elseif in_description and line ~= "" and not line:match("^[-=]+$") then
            if description ~= "" then
                description = description .. " "
            end
            description = description .. line
        end
    end

    -- Don't forget the last tag
    if current_tag then
        if not tags[current_tag] then
            tags[current_tag] = {}
        end
        table.insert(tags[current_tag], table.concat(current_content, " "):trim())
    end

    return {
        description = description,
        tags = tags,
        raw_lines = lines
    }
end

-- Parse luaL_Reg structures to find exported functions
local function parse_lual_reg_exports(content)
    local exports = {}
    local lines = {}

    -- Split content into lines, skipping empty lines
    for line in content:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local in_reg_struct = false
    local current_reg_name = nil
    local brace_count = 0
    local pending_reg_name = nil  -- For when = { is on separate lines

    for line_num, line in ipairs(lines) do
        -- Look for luaL_Reg structure declarations
        local reg_name = line:match("static%s+.*luaL_Reg%s+([%w_]+)%s*%[%s*%]%s*=%s*{")
        if not reg_name then
            reg_name = line:match("static%s+const%s+luaL_Reg%s+([%w_]+)%s*%[%s*%]%s*=%s*{")
        end
        if not reg_name then
            reg_name = line:match("static%s+luaL_Reg%s+([%w_]+)%s*%[%s*%]%s*=%s*$")
        end
        if not reg_name then
            reg_name = line:match("static%s+luaL_Reg%s+([%w_]+)%s*%[%s*%]%s*$")
        end
        if not reg_name then
            pending_reg_name = line:match("static%s+luaL_Reg%s+([%w_]+)%s*%[%s*%]%s*=%s*$")
        end

        if reg_name then
            in_reg_struct = true
            current_reg_name = reg_name
            exports[reg_name] = {}
            brace_count = 1
        elseif pending_reg_name and line:match("^%s*{%s*$") then
            -- Handle case where opening brace is on separate line
            in_reg_struct = true
            current_reg_name = pending_reg_name
            exports[current_reg_name] = {}
            brace_count = 1
            pending_reg_name = nil
        elseif line:match("^%s*{%s*$") and current_reg_name then
            -- Handle case where opening brace is on separate line
            brace_count = brace_count + 1  -- Increment, don't reset!
            in_reg_struct = true
        elseif in_reg_struct then
            -- Count braces to track structure end
            local open_braces = select(2, line:gsub("{", ""))
            local close_braces = select(2, line:gsub("}", ""))
            brace_count = brace_count + open_braces - close_braces

            -- Parse function entries: { "lua_name", c_function_ptr },
            local lua_name, c_function = line:match('%s*{%s*"([^"]+)"%s*,%s*([%w_]+)%s*}')
            if lua_name and c_function and c_function ~= "NULL" then
                exports[current_reg_name][lua_name] = c_function
            end

            -- End of structure
            if brace_count <= 0 then
                in_reg_struct = false
                current_reg_name = nil
                pending_reg_name = nil
            end
        end
    end

    return exports
end

-- String trim function
function string:trim()
    return self:match("^%s*(.-)%s*$")
end

-- Check if a function is exported in any luaL_Reg structure
local function is_function_exported(func_name, exports)
    for reg_name, reg_exports in pairs(exports) do
        for lua_name, c_function in pairs(reg_exports) do
            if c_function == func_name then
                return true, lua_name, reg_name
            end
        end
    end
    return false, nil, nil
end

-- Analyze a single C file
local function analyze_file(filepath)
    local file = io.open(filepath, "r")
    if not file then
        printf(colored("red", "Error: Cannot open file %s"), filepath)
        return
    end

    local content = file:read("*a")
    file:close()

    stats.total_files = stats.total_files + 1
    stats.analyzed_files = stats.analyzed_files + 1

    printf(colored("cyan", "\n=== Analyzing %s ==="), filepath)

    if config.verbose then
        printf("File size: %d bytes", #content)
    end

    -- Parse luaL_Reg exports to identify actually exported functions
    local lual_reg_exports = parse_lual_reg_exports(content)

    if config.verbose and next(lual_reg_exports) then
        printf("Found luaL_Reg structures:")
        for reg_name, exports in pairs(lual_reg_exports) do
            local count = 0
            for _ in pairs(exports) do count = count + 1 end
            printf("  %s: %d exports", reg_name, count)
        end
    end

    local file_issues = {}
    local comment_count = 0
    local function_count = 0
    local documented_function_count = 0

    -- Find all LDoc comments more carefully to avoid nested comment issues
    local comments = {}
    local pos = 1

    while pos <= #content do
        local start_pos = content:find("/%*%*%*", pos)
        if not start_pos then break end

        -- Find the next */ that closes this comment
        local search_pos = start_pos + 4
        local end_pos = nil

        -- Look for */ while avoiding any new /* starts
        local max_search = math.min(search_pos + 10000, #content)  -- Limit search range
        while search_pos <= max_search do
            local star_pos = content:find("%*/", search_pos)
            if not star_pos then break end

            -- Check if there's a /* between our start and this */
            local intervening_start = content:find("/%*", start_pos + 4, star_pos - 1)
            if not intervening_start then
                -- No intervening /* comment, this */ closes our comment
                end_pos = star_pos
                break
            else
                -- There's an intervening comment, skip past it
                local intervening_end = content:find("%*/", intervening_start + 2)
                if intervening_end then
                    search_pos = intervening_end + 2
                else
                    break
                end
            end
        end

        if end_pos then
            local comment_text = content:sub(start_pos + 4, end_pos - 1)
            table.insert(comments, {
                text = comment_text,
                start_pos = start_pos,
                end_pos = end_pos + 1,
                line_num = select(2, content:sub(1, start_pos):gsub('\n', '\n')) + 1
            })
            comment_count = comment_count + 1
            pos = end_pos + 2
        else
            pos = start_pos + 4
        end
    end

    printf("Found %d LDoc comment blocks", comment_count)
    stats.total_comments = stats.total_comments + comment_count

    -- Improved API function detection with accurate line numbers
    local function find_api_functions(content)
        local api_functions = {}
        local lines = {}

        -- Split content into lines for accurate line number tracking
        -- Fix: Use reliable line splitting that matches system behavior
        local line_start = 1
        while line_start <= #content do
            local line_end = content:find('\n', line_start) or (#content + 1)
            local line = content:sub(line_start, line_end - 1)
            table.insert(lines, line)
            line_start = line_end + 1
        end

        local i = 1
        while i <= #lines do
            local line = lines[i]
            local line_num = i

            -- Match function definitions: static int openssl_xxx(lua_State *L...)
            -- or int openssl_xxx(lua_State *L...)
            -- Handle both single-line and multi-line function definitions
            local static_match = line:match("^%s*static%s+int%s+openssl_([%w_]+)%s*%(")
            local int_match = line:match("^%s*int%s+openssl_([%w_]+)%s*%(")

            -- Also check for multi-line definitions where function name is on next non-empty line
            local multiline_static = false
            local multiline_int = false
            local func_line_num = line_num

            if line:match("^%s*static%s+int%s*$") and i < #lines then
                -- Look for the next non-empty line containing the function name
                for check_line = i + 1, math.min(i + 5, #lines) do
                    local check_line_content = lines[check_line]
                    if check_line_content and check_line_content:match("%S") then -- Non-empty line
                        static_match = check_line_content:match("^%s*openssl_([%w_]+)%s*%(")
                        if static_match then
                            multiline_static = true
                            func_line_num = check_line
                            i = check_line  -- Skip ahead to avoid reprocessing
                            break
                        else
                            break -- Stop if we find a non-empty line that's not a function
                        end
                    end
                end
            elseif line:match("^%s*int%s*$") and i < #lines then
                -- Look for the next non-empty line containing the function name
                for check_line = i + 1, math.min(i + 5, #lines) do
                    local check_line_content = lines[check_line]
                    if check_line_content and check_line_content:match("%S") then -- Non-empty line
                        int_match = check_line_content:match("^%s*openssl_([%w_]+)%s*%(")
                        if int_match then
                            multiline_int = true
                            func_line_num = check_line
                            i = check_line  -- Skip ahead to avoid reprocessing
                            break
                        else
                            break -- Stop if we find a non-empty line that's not a function
                        end
                    end
                end
            end

            local func_name = static_match or int_match
            if func_name then
                -- Check if this line or the next few lines contain lua_State *L
                local has_lua_state = false
                local start_check = func_line_num
                local check_lines = math.min(start_check + 3, #lines) -- Check current + next 3 lines

                for check_line = start_check, check_lines do
                    if lines[check_line]:find("lua_State%s*%*%s*L") then
                        has_lua_state = true
                        break
                    end
                end

                if has_lua_state then
                    table.insert(api_functions, {
                        name = "openssl_" .. func_name,
                        line_num = func_line_num,
                        start_pos = 1 -- Not critical for this analysis
                    })
                end
            end

            i = i + 1
        end

        return api_functions
    end

    -- 找到所有 API 函数定义并过滤为仅导出的函数
    local all_api_functions = find_api_functions(content)

    -- Filter to only include functions that are actually exported in luaL_Reg
    local api_functions = {}
    local internal_functions = {}

    for _, func in ipairs(all_api_functions) do
        local is_exported, lua_name, reg_name = is_function_exported(func.name, lual_reg_exports)
        if is_exported then
            func.lua_name = lua_name
            func.reg_name = reg_name
            table.insert(api_functions, func)
        else
            table.insert(internal_functions, func)
        end
    end

    local function_count = #api_functions
    local total_functions_found = #all_api_functions

    printf("Found %d total API function definitions", total_functions_found)
    printf("Found %d exported API functions (in luaL_Reg)", function_count)
    if config.verbose and #internal_functions > 0 then
        printf("Internal functions (not exported): %d", #internal_functions)
        for _, func in ipairs(internal_functions) do
            printf("  - %s at line %d", func.name, func.line_num)
        end
    end
    stats.total_functions = stats.total_functions + function_count

    if config.verbose then
        printf("Starting comment validation...")
    end

    -- Analyze each comment for quality validation
    for i, comment in ipairs(comments) do
        local parsed = parse_ldoc_comment(comment.text)
        local valid = true
        local comment_issues = {}

        -- Check for required elements
        if not parsed.description or parsed.description:trim() == "" then
            table.insert(comment_issues, "Missing or empty description")
            valid = false
        end

        -- Check for function documentation
        if parsed.tags.module then
            -- Module documentation - should have usage
            if not parsed.tags.usage or (parsed.tags.usage and #parsed.tags.usage > 0 and parsed.tags.usage[1]:trim() == "") then
                table.insert(comment_issues, "Module missing @usage example")
                valid = false
            end
        elseif parsed.tags["function"] then
            -- Basic validation for function documentation
            local has_return = parsed.tags.treturn or parsed.tags["return"]
            if not has_return then
                table.insert(comment_issues, "Function missing @treturn/@return documentation")
                valid = false
            end
        end

        -- Check for common LDoc tag issues
        for tag, values in pairs(parsed.tags) do
            for _, value in ipairs(values) do
                if value:trim() == "" then
                    table.insert(comment_issues, string.format("Empty @%s tag", tag))
                    valid = false
                end
            end
        end

        if valid and #comment_issues == 0 then
            stats.valid_comments = stats.valid_comments + 1
            if config.verbose then
                local out_type, out_name = nil, nil
                if parsed.tags.module and #parsed.tags.module > 0 then
                    out_type = "Module"
                    out_name = parsed.tags.module[1]
                elseif parsed.tags["function"] and #parsed.tags["function"] > 0 then
                    out_type = "Function"
                    out_name = parsed.tags["function"][1]
                elseif parsed.tags.type and #parsed.tags.type > 0 then
                    out_type = "Type"
                    out_name = parsed.tags.type[1]
                end
                if out_type and out_name then
                    printf(colored("green", "✓ %s %s at line %d: Valid"), out_type, out_name, comment.line_num)
                else
                    printf(colored("green", "✓ Comment at line %d: Valid"), comment.line_num)
                end
            end
        else
            if config.verbose then
                printf(colored("yellow", "⚠ Comment at line %d: Issues found"), comment.line_num)
                for _, issue in ipairs(comment_issues) do
                    printf(colored("yellow", "  - %s"), issue)
                end
            end
            for _, issue in ipairs(comment_issues) do
                table.insert(file_issues, string.format("Line %d: %s", comment.line_num, issue))
            end
        end
    end

    -- Improved undocumented function detection with better comment-function association
    local function is_function_documented(func, comments, content_lines)
        -- Check if there's a LDoc comment block immediately before this function
        local func_line = func.line_num

        -- Look backwards from the function line to find the closest LDoc comment
        for line_num = func_line - 1, math.max(1, func_line - 10), -1 do
            local line = content_lines[line_num]
            if not line then break end

            -- Skip empty lines and single-line comments
            local should_continue = false
            if line:match("^%s*$") or line:match("^%s*//") or line:match("^%s*%*%s*$") then
                should_continue = true
            end

            if not should_continue then
                -- If we hit a non-comment line (like another function or code), stop searching
                if not line:match("%*/") and not line:match("^%s*%*") and not line:match("^%s*/[%*]+") then
                    if line:match("%S") then -- Non-empty, non-comment line
                        break
                    end
                end

                -- Check if this line ends a LDoc comment block
                if line:match("%*/") then
                    -- Find the corresponding comment block
                    for _, comment in ipairs(comments) do
                        -- Calculate the end line of this comment
                        local comment_start_line = select(2, content:sub(1, comment.start_pos):gsub('\n', '\n')) + 1
                        local comment_lines_count = select(2, comment.text:gsub('\n', '\n')) + 1
                        local comment_end_line = comment_start_line + comment_lines_count

                        -- If this comment ends close to where we're looking
                        if math.abs(comment_end_line - line_num) <= 2 then
                            local parsed = parse_ldoc_comment(comment.text)
                            -- Check if it has @function tag or if it's positioned right before our function
                            if parsed.tags["function"] or
                               (comment_end_line >= func_line - 5 and comment_end_line < func_line) then
                                return true, parsed.tags["function"] and parsed.tags["function"][1] or "unnamed"
                            end
                        end
                    end
                    break
                end
            end
        end

        -- Also check by function name in all @function tags
        -- For exported functions, check against the Lua export name
        local func_suffix = func.name:match("openssl_(.+)")
        local expected_lua_name = func.lua_name  -- This is set if function is exported

        for _, comment in ipairs(comments) do
            local parsed = parse_ldoc_comment(comment.text)
            if parsed.tags["function"] then
                for _, fname in ipairs(parsed.tags["function"]) do
                    -- For exported functions, prefer exact match with Lua export name
                    if expected_lua_name and fname == expected_lua_name then
                        return true, fname
                    end

                    -- Fallback to original matching patterns for compatibility:
                    -- 1. Exact match with suffix (e.g., "xstore_new" == "xstore_new")
                    -- 2. Exact match with full name (e.g., "openssl_xstore_new" == "openssl_xstore_new")
                    -- 3. Function suffix ends with @function name (e.g., "xstore_new" ends with "new")
                    -- 4. @function name equals the last part after underscore (e.g., "new" matches "xstore_new")
                    if fname == func_suffix or
                       fname == func.name or
                       func_suffix:match("_" .. fname .. "$") or
                       func_suffix:match(fname .. "$") then
                        return true, fname
                    end
                end
            end
        end

        return false, nil
    end

    -- Split content into lines for analysis
    local content_lines = {}
    for line in content:gmatch("[^\r\n]*") do
        table.insert(content_lines, line)
    end

    -- Check each function for documentation
    local undocumented_list = {}
    local documented_function_count = 0

    for _, func in ipairs(api_functions) do
        local is_documented, func_name = is_function_documented(func, comments, content_lines)

        if is_documented then
            documented_function_count = documented_function_count + 1
        else
            -- Skip metamethods and utility functions as requested
            local func_suffix = func.name:match("openssl_(.+)")
            if not (func.name:match("_free$") or func.name:match("_gc$") or
                   func_suffix and (func_suffix:match("^__") or func_suffix == "pushresult" or
                   func_suffix:match("^push_") or func_suffix:match("^get_") or func_suffix:match("^to_"))) then
                table.insert(undocumented_list, string.format("%s at line %d", func.name, func.line_num))
            end
        end
    end

    stats.documented_functions = stats.documented_functions + documented_function_count

    local undocumented = #undocumented_list
    if undocumented > 0 then
        if config.show_undocumented_list then
            printf(colored("red", "⚠ %d functions are undocumented"), undocumented)
            for _, info in ipairs(undocumented_list) do
                printf(colored("red", "  • %s"), info)
            end
        end
        table.insert(file_issues, string.format("%d undocumented functions", undocumented))
    end

    -- Store file issues
    if #file_issues > 0 then
        stats.issues[filepath] = file_issues
    end

    -- Summary for this file - Fixed API coverage calculation
    local total_api_functions = documented_function_count + undocumented
    local api_coverage_percentage = 0

    if total_api_functions > 0 then
        api_coverage_percentage = (documented_function_count / total_api_functions) * 100
        printf("API documentation coverage: %.1f%% (%d functions with @function tags)",
               api_coverage_percentage, documented_function_count)
        if undocumented > 0 then
            printf("Additional functions detected: %d (candidates for @function documentation)", undocumented)
        end
    else
        printf("API documentation coverage: 0.0%% (0 functions with @function tags)")
        printf("Total functions detected: %d (candidates for @function documentation)", function_count)
    end
end

-- Main function to analyze directory
-- Main function to analyze path (file or directory)
local function analyze_path(path)
    printf(colored("bold", "LDoc Comment Analyzer for lua-openssl"))

    -- Check if path exists
    local attr = lfs.attributes(path)
    if not attr then
        printf(colored("red", "Error: Path %s does not exist"), path)
        os.exit(1)
    end

    local c_files = {}

    if attr.mode == "directory" then
        printf("Analyzing directory: %s\n", path)

        -- Scan for C files in directory
        for file in lfs.dir(path) do
            if file:match("%.c$") then
                local filepath = path .. "/" .. file
                table.insert(c_files, filepath)
            end
        end

        table.sort(c_files)

        if #c_files == 0 then
            printf(colored("yellow", "No C files found in directory %s"), path)
            return
        end

    elseif attr.mode == "file" then
        if not path:match("%.c$") then
            printf(colored("red", "Error: %s is not a C source file"), path)
            os.exit(1)
        end

        printf("Analyzing file: %s\n", path)
        table.insert(c_files, path)
    else
        printf(colored("red", "Error: %s is neither a file nor a directory"), path)
        os.exit(1)
    end

    printf("Found %d C file%s to analyze\n", #c_files, #c_files == 1 and "" or "s")

    -- Analyze each file
    for _, filepath in ipairs(c_files) do
        analyze_file(filepath)
    end

    -- Print overall summary
    printf(colored("bold", "\n" .. string.rep("=", 60)))
    printf(colored("bold", "ANALYSIS SUMMARY"))
    printf(colored("bold", string.rep("=", 60)))

    printf("Files analyzed: %d", stats.analyzed_files)
    printf("Total functions detected: %d", stats.total_functions)
    printf("Functions with @function tags: %d", stats.documented_functions)
    printf("Total LDoc comments: %d", stats.total_comments)
    printf("Valid LDoc comments: %d", stats.valid_comments)

    -- Updated API coverage calculation as per @zhaozg feedback
    -- Calculate proper API coverage percentage
    local api_coverage = stats.total_functions > 0 and (stats.documented_functions / stats.total_functions * 100) or 0
    local comment_validity = stats.total_comments > 0 and (stats.valid_comments / stats.total_comments * 100) or 0
    local potential_api_functions = stats.total_functions - stats.documented_functions

    printf(colored("cyan", "API documentation coverage: %.1f%% (%d functions with @function tags)"),
           api_coverage, stats.documented_functions)
    if potential_api_functions > 0 then
        printf(colored("yellow", "Potential API functions: %d (candidates for @function documentation)"),
               potential_api_functions)
    end
    printf(colored("cyan", "Comment validity rate: %.1f%%"), comment_validity)

    -- Report issues by priority
    if config.show_issues and next(stats.issues) then
        printf(colored("yellow", "\nISSUES FOUND:"))
        for filepath, issues in pairs(stats.issues) do
            printf(colored("yellow", "\n%s:"), filepath)
            local issue_count = 0
            for _, issue in ipairs(issues) do
                if issue_count < config.max_issues_per_file then
                    printf(colored("yellow", "  • %s"), issue)
                    issue_count = issue_count + 1
                else
                    local remaining = #issues - issue_count
                    if remaining > 0 then
                        printf(colored("yellow", "  • ... and %d more issues"), remaining)
                    end
                    break
                end
            end
        end
    end

    -- Recommendations - Updated for new API coverage approach
    printf(colored("bold", "\nRECOMMENDATIONS:"))

    if potential_api_functions > 0 then
        printf(colored("yellow", "• Consider adding @function documentation for %d detected functions"), potential_api_functions)
    end

    if comment_validity < 90 then
        printf(colored("red", "• Improve LDoc comment quality (%.1f%% valid). Target: 90%%+"), comment_validity)
    end

    printf(colored("green", "• Use consistent LDoc tags: @module, @function, @tparam, @treturn"))
    printf(colored("green", "• Add @usage examples for all modules"))
    printf(colored("green", "• Ensure all public functions have complete documentation"))

    -- Exit with appropriate code based on comment validity and documentation presence
    if comment_validity < 70 or stats.documented_functions == 0 then
        printf(colored("red", "\nDocumentation quality needs significant improvement!"))
        os.exit(1)
    elseif comment_validity < 90 then
        printf(colored("yellow", "\nDocumentation quality could be improved."))
        os.exit(0)
    else
        printf(colored("green", "\nDocumentation quality is good!"))
        os.exit(0)
    end
end

-- Main execution
local source_path = parse_args(arg)
analyze_path(source_path)
