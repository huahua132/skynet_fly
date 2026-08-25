-- fixed.lua : Q16.16 定点数库（源自 https://github.com/tpctm/lua-fixed-point，MIT License）
-- 定位: 确定性战斗/回放/服务端校验/PCG 的纯数据逻辑层数值底座, 零引擎依赖, 服务端裸 Lua 可直接跑
-- 表示: raw = 实际值 * 65536; 值域 [-32768, 32767.99998474); 1 LSB = 1/65536
-- 语法: 仅用 Lua 5.1 语法(无 // << >> bit), 兼容 5.1/5.2/5.3/5.4/LuaJIT
-- 确定性: 加减乘除取整全整数运算; 仅 sin/cos 查表生成与 atan2 用 IEEE754 double
--   math(IEEE754 保证跨平台一致), 运行时查表+插值仍为整数运算
-- 精度边界: mul/lerp 要求 |a*b| <= 2^52(double 精确整上限), 即输入 raw 与结果均
--   落在合法 Q16.16 域内即安全; 高溢出风险处改用 mul_safe(饱和)
-- 命名: API 统一 snake_case(与框架约定一致); 常量大写
-- 序列化: 存档/线格式必须用整型 raw 编码(本项目 Lua 5.5 为 integer), 禁止直接对
--   Lua number 做字节级编码
local fixed = {}

local SHIFT = 16
local ONE = 65536
local HALF = 32768
local INT_MIN = -2147483648
local INT_MAX = 2147483647
local PREC2 = 4503599627370496 -- 2^52
local D2PI = 6.283185307179586

fixed.SHIFT = SHIFT
fixed.ONE = ONE
fixed.HALF = HALF
fixed.MIN = INT_MIN
fixed.MAX = INT_MAX
fixed.EPS = 1
fixed.PI = 205887    -- floor(pi*65536)
fixed.HALF_PI = 102943
fixed.TWO_PI = 411774 -- floor(2pi*65536)

local floor, modf, ceil, abs = math.floor, math.modf, math.ceil, math.abs

-- 算术右移 n 位(向下取整=保持符号); Lua 5.1 无 >> 运算符
local function shr(x, n) return floor(x / (2 ^ n)) end
-- 转 Q16.16: 输入须为 Lua number
local function to_raw(v)
    if type(v) ~= "number" then error("fixed: expects number, got " .. type(v)) end
    return floor(v * ONE + 0.5)
end

fixed.from_float = to_raw
function fixed.from_int(n) return n * ONE end
function fixed.to_float(x) return x / ONE end
function fixed.is_q(x) return type(x) == "number" and x % 1 == 0 end
-- to_str: 高16位整 + 低16位小数, 四位小数, 负数含符号
function fixed.to_str(x)
    local sign = x < 0 and "-" or ""
    local ax = abs(x)
    local i = floor(ax / ONE)
    local f = floor((ax % ONE) * 10000 / ONE + 0.5)
    if f == 10000 then f = 0; i = i + 1 end
    return sign .. i .. "." .. string.format("%04d", f)
end

function fixed.neg(a) return -a end
function fixed.abs(a) return abs(a) end
function fixed.add(a, b) return a + b end
function fixed.sub(a, b) return a - b end
function fixed.mul(a, b) return shr(a * b, SHIFT) end
function fixed.div(a, b)
    if b == 0 then error("fixed.div: divide by zero") end
    return floor(a * ONE / b)
end
-- 带精度检查的乘法: |a*b| 超 2^52 则饱和到 Q16.16 边界
function fixed.mul_safe(a, b)
    local p = a * b
    if abs(p) > PREC2 then
        if a == 0 or b == 0 then return 0 end
        return (a > 0) == (b > 0) and INT_MAX or INT_MIN
    end
    return shr(p, SHIFT)
end
-- 乘除组合: floor(a*b/c), 用于 lerp/比例; 同 mul 要求 |a*b| <= 2^52 下结果精确
function fixed.mul_div(a, b, c)
    if c == 0 then error("fixed.mul_div: divide by zero") end
    return floor(a * b / c)
end
function fixed.mod(a, b) return a % b end -- Lua 语义: 结果符号同 b
-- 与普通整数互乘(结果仍 Q16.16)
function fixed.mul_int(a, n) return a * n end
function fixed.div_int(a, n)
    if n == 0 then error("fixed.div_int: divide by zero") end
    return floor(a / n)
end

function fixed.floor(x) return floor(x / ONE) * ONE end
function fixed.ceil(x) return ceil(x / ONE) * ONE end -- 注意 ceil(MAX)=32768 超域(半开区间设计)
function fixed.trunc(x) return modf(x / ONE) * ONE end
-- round 半值非对称向 +oo: round(-2.5)=-2, round(2.5)=3; 需对称舍入请用 trunc 手动处理
function fixed.round(x) return floor(x / ONE + 0.5) * ONE end
function fixed.to_int(x) return modf(x / ONE) end -- 截断向零
function fixed.to_int_round(x) return floor(x / ONE + 0.5) end
function fixed.to_int_floor(x) return floor(x / ONE) end
function fixed.sign(x) if x > 0 then return ONE elseif x < 0 then return -ONE end return 0 end
function fixed.cmp(a, b) if a > b then return 1 elseif a < b then return -1 end return 0 end
function fixed.frac_part(x) return x - fixed.trunc(x) end

function fixed.min(a, b) return a < b and a or b end
function fixed.max(a, b) return a > b and a or b end
function fixed.clamp(x, lo, hi)
    if x < lo then return lo elseif x > hi then return hi end
    return x
end
-- lerp: a + (b-a)*t, t 为 Q16.16 0~1; 受 mul 精度边界约束
function fixed.lerp(a, b, t) return a + shr((b - a) * t, SHIFT) end

-- 纯整数牛顿 isqrt: 返回 floor(sqrt(n)), n >= 0
local function isqrt(n)
    if n < 2 then return n end
    local x0 = floor(n / 2)
    local x1 = floor((x0 + floor(n / x0)) / 2)
    while x1 < x0 do
        x0 = x1
        x1 = floor((x0 + floor(n / x0)) / 2)
    end
    return x0
end
-- sqrt: x 为 Q16.16, x<<16 <= 2^47 < 2^53 精确
function fixed.sqrt(x)
    if x < 0 then error("fixed.sqrt: negative input") end
    return isqrt(x * ONE)
end
-- 平方根倒数(归一化向量用): 1/sqrt(x); 要求 x >= 1(如长度平方), x<1 时精度下降
function fixed.rsqrt(x)
    if x <= 0 then error("fixed.rsqrt: non-positive input") end
    return floor(ONE * ONE / isqrt(x * ONE))
end

-- 全周期 4096 项 sin 表 + 线性插值, 插值误差 ≈1 LSB; 表生成一次(双精度 double)
local N = 4096
local LUT = {}
do
    local step = D2PI / N
    for i = 0, N do
        LUT[i] = floor(math.sin(i * step) * ONE + 0.5)
    end
end
local function sin_raw(x)
    local f = x / (D2PI * ONE) * N
    local i = floor(f)
    local fr = f - i
    i = i % N
    return LUT[i] + floor((LUT[i + 1] - LUT[i]) * fr + 0.5)
end
function fixed.sin(x) return sin_raw(x) end
function fixed.cos(x) return sin_raw(x + fixed.HALF_PI) end
-- tan: |cos|<1LSB 或结果超域时 error(防奇点产生 2^32 级垃圾值)
function fixed.tan(x)
    local s, c = sin_raw(x), sin_raw(x + fixed.HALF_PI)
    if abs(c) <= 1 then error("fixed.tan: undefined") end
    local t = floor(s * ONE / c)
    if abs(t) > INT_MAX then error("fixed.tan: out of range") end
    return t
end
-- atan2 返回 Q16.16 弧度 [-pi, pi]; math.atan2 在 5.3+ 移除, 用 math.atan(y,x) 兼容
local atan2f = math.atan2 or function(y, x) return math.atan(y, x) end
function fixed.atan2(y, x)
    return floor(atan2f(y / ONE, x / ONE) * ONE + 0.5)
end
-- 每度 raw = pi/180*65536 = 1143.818978587
local D2R = 1143.818978587
function fixed.rad_to_deg(x) return floor(x / D2R + 0.5) end -- 输出普通整数角度
function fixed.deg_to_rad(deg) return floor(deg * D2R + 0.5) end -- 输出 Q16.16 弧度
-- 角度制 sin/cos: deg 为普通整数角度
function fixed.sin_deg(deg) return sin_raw(deg * D2R + 0.5) end
function fixed.cos_deg(deg) return sin_raw(deg * D2R + 0.5 + fixed.HALF_PI) end

-- 整数幂(纯 mul 链); 负指数 = (1/a)^n
function fixed.powi(a, n)
    if n < 0 then return fixed.powi(fixed.div(ONE, a), -n) end
    local r = ONE
    while n > 0 do
        if n % 2 == 1 then r = fixed.mul(r, a) end
        a = fixed.mul(a, a)
        n = floor(n / 2)
    end
    return r
end
function fixed.equals(a, b, eps) return abs(a - b) <= (eps or 0) end

return fixed
