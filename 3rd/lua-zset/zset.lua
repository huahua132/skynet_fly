local skiplist = require "skiplist.c"
local mt = {}
mt.__index = mt

function mt:add(score, member)
    local old = self.tbl[member]
    if old then
        if old == score then
            return
        end
        self.sl:delete(old, member)
    end

    self.sl:insert(score, member)
    self.tbl[member] = score
end

function mt:rem(member)
    local score = self.tbl[member]
    if score then
        self.sl:delete(score, member)
        self.tbl[member] = nil
    end
end

function mt:count()
    return self.sl:get_count()
end

function mt:_reverse_rank(r)
    return self.sl:get_count() - r + 1
end

function mt:limit(count, delete_handler)
    local total = self.sl:get_count()
    if total <= count then
        return 0
    end

    local delete_function = function(member)
        self.tbl[member] = nil
        if delete_handler then
            delete_handler(member)
        end
    end

    return self.sl:delete_by_rank(count+1, total, delete_function)
end

function mt:rev_limit(count, delete_handler)
    local total = self.sl:get_count()
    if total <= count then
        return 0
    end
    local from = self:_reverse_rank(count+1)
    local to   = self:_reverse_rank(total)

    local delete_function = function(member)
        self.tbl[member] = nil
        if delete_handler then
            delete_handler(member)
        end
    end

    return self.sl:delete_by_rank(from, to, delete_function)
end

function mt:rev_range(r1, r2)
    r1 = self:_reverse_rank(r1)
    r2 = self:_reverse_rank(r2)
    return self:range(r1, r2)
end

function mt:range(r1, r2)
    if r1 < 1 then
        r1 = 1
    end

    if r2 < 1 then
        r2 = 1
    end
    return self.sl:get_rank_range(r1, r2)
end

function mt:rev_rank(member)
    local r = self:rank(member)
    if r then
        return self:_reverse_rank(r)
    end
    return r
end

function mt:rank(member)
    local score = self.tbl[member]
    if not score then
        return nil
    end
    return self.sl:get_rank(score, member)
end

function mt:range_by_score(s1, s2)
    return self.sl:get_score_range(s1, s2)
end

function mt:score(member)
    return self.tbl[member]
end

function mt:member_by_rank(r)
    return self.sl:get_member_by_rank(r)
end

function mt:member_by_rev_rank(r)
    r = self:_reverse_rank(r)
    if r > 0 then
        return self.sl:get_member_by_rank(r)
    end
end

function mt:dump()
    self.sl:dump()
end

local M = {}
function M.new()
    local obj = {}
    obj.sl = skiplist()
    obj.tbl = {}
    return setmetatable(obj, mt)
end
return M

