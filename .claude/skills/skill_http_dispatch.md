# 技能：编写 HTTP Web 接口（dispatch文件）

> **适用场景**: 为 skynet_fly 编写 HTTP 服务路由和接口处理
> **关键词**: dispatch, engine_web, HTTP, 路由, middleware, group, static_file, context, req, res, JSON, POST, GET
> **参考示例**: `examples/webapp/apps/webapp_dispatch*.lua`

---

## ⚡ 最简 dispatch 文件

```lua
-- apps/webapp_dispatch.lua
local engine_web  = require "skynet-fly.web.engine_web"
local HTTP_STATUS = require "skynet-fly.web.HTTP_STATUS"

local M   = {}
local app = engine_web:new()          -- ★ 纯净版（不带中间件）

M.dispatch = engine_web.dispatch(app) -- ★ 必须导出 dispatch

function M.init()   -- ★ 必须导出 init
    app:get("/ping", function(c)
        c.res:set_json_rsp({message = "pong"})
    end)

    app:run()   -- ★ 必须在 init 最后调用 run()
end

function M.exit()   -- ★ 必须导出 exit
end

return M
```

---

## ⚠️ 必须遵守的规则

| 规则 | 说明 |
|------|------|
| 必须导出三个接口 | `M.dispatch`、`M.init()`、`M.exit()`，缺一不可 |
| `app:run()` | 必须在 `M.init()` 最后调用，路由才生效 |
| `engine_web.dispatch(app)` | 必须在文件顶层调用，不能在 init 里 |

---

## 📋 app 创建方式

```lua
local engine_web  = require "skynet-fly.web.engine_web"
local logger_mid  = require "skynet-fly.web.middleware.logger_mid"

local app = engine_web:new()      -- 纯净版（无中间件）
-- local app = engine_web:default()  -- 默认版（自带 logger 中间件）
```

---

## 📋 路由注册

### GET / POST / PUT / DELETE

```lua
app:get("/path", handler)
app:post("/path", handler)
-- PUT/DELETE 同理
```

### 路由参数（`:name`）

```lua
-- 访问 /user/123 时，params.id = "123"
app:get("/user/:id", function(c)
    local id = c.params.id
    c.res:set_json_rsp({id = id})
end)

-- 通配符（* 匹配任意后续路径）
app:get("/login/:player_id/*", function(c)
    local player_id = c.params.player_id
    -- c.req.path 是完整路径
    c.res:set_rsp("hello " .. player_id, HTTP_STATUS.OK)
end)
```

### 路由组（group）

```lua
local v1 = app:group("v1")    -- 路径前缀 /v1
v1:get("/login",  function(c) ... end)   -- 匹配 /v1/login
v1:get("/logout", function(c) ... end)   -- 匹配 /v1/logout

local v2 = app:group("v2")
v2:get("/login",  function(c) ... end)   -- 匹配 /v2/login
```

### 静态文件

```lua
app:static_file("/favicon.ico", "./static/favicon.ico")  -- 单个文件
app:static_dir("/static", "./static/imgs/")               -- 整个目录
-- 访问: /static/1.jpg → ./static/imgs/1.jpg
```

### 404 处理

```lua
app:set_no_route(
    function(c)
        log.error("no route:", c.req.path, c.req.method)
        c:next()  -- 继续下一个no_route处理
    end,
    function(c)
        c.res:set_error_rsp(HTTP_STATUS.Not_Found)
    end
)
```

---

## 📋 请求对象（c.req）速查

| 字段/方法 | 说明 |
|----------|------|
| `c.req.path` | 请求路径，如 `/api/login` |
| `c.req.method` | 请求方法，如 `GET` / `POST` |
| `c.req.query` | URL查询参数（table），如 `?id=1&name=foo` → `{id="1", name="foo"}` |
| `c.req.body` | 请求体（自动解析：JSON→table，form→table，其他→string） |
| `c.req.body_raw` | 原始请求体（未解析的字符串） |
| `c.req.header` | 请求头（table） |
| `c.params` | 路由参数（table），如 `:id` → `c.params.id` |

### 请求体自动解析规则

| Content-Type | `c.req.body` 类型 |
|-------------|-----------------|
| `application/json` | Lua table（自动 json.decode） |
| `application/x-www-form-urlencoded` | Lua table（自动 parse_query） |
| 无 Content-Type 或 POST body | Lua table（按 form 解析） |

---

## 📋 响应对象（c.res）速查

| 方法 | 说明 |
|------|------|
| `c.res:set_rsp(text, status, content_type?)` | 返回文本响应 |
| `c.res:set_json_rsp(lua_table)` | 返回 JSON 响应（自动编码，status=200） |
| `c.res:set_error_rsp(status)` | 返回错误状态码 |
| `c.res:set_header(key, value)` | 设置响应头 |
| `c.res:set_content_type(ct)` | 设置 Content-Type |

### HTTP_STATUS 常量

```lua
local HTTP_STATUS = require "skynet-fly.web.HTTP_STATUS"
-- 常用:
-- HTTP_STATUS.OK           = 200
-- HTTP_STATUS.Not_Found    = 404
-- HTTP_STATUS.Bad_Request  = 400
-- HTTP_STATUS.Unauthorized = 401
-- HTTP_STATUS.Internal_Server_Error = 500
```

---

## 📋 中间件

### 全局中间件

```lua
local logger_mid = require "skynet-fly.web.middleware.logger_mid"
local cors_mid   = require "skynet-fly.web.middleware.cors_mid"

function M.init()
    app:use(logger_mid())   -- 日志中间件
    app:use(cors_mid())     -- CORS跨域中间件

    -- 自定义全局中间件
    app:use(function(c)
        log.info("request begin:", c.req.path)
        c:next()   -- ★ 继续执行下一个中间件/路由处理
        log.info("request end:", c.req.path, c.res.status)
    end)

    app:get("/", handler)
    app:run()
end
```

### 路由组中间件

```lua
local v1 = app:group("v1")
v1:use(function(c)
    -- 只对 /v1/* 路由生效
    log.info("v1 middleware:", c.req.path)
    c:next()
end)
v1:get("/login", handler)
```

### 中间件中止（验证失败时）

```lua
app:use(function(c)
    local token = c.req.header["authorization"]
    if not token then
        c.res:set_error_rsp(HTTP_STATUS.Unauthorized)
        c:abort()   -- ★ 中止，不再执行后续中间件和路由
        return
    end
    c:next()
end)
```

---

## 📋 完整 dispatch 示例（综合）

```lua
-- apps/webapp_dispatch.lua
local engine_web  = require "skynet-fly.web.engine_web"
local logger_mid  = require "skynet-fly.web.middleware.logger_mid"
local cors_mid    = require "skynet-fly.web.middleware.cors_mid"
local HTTP_STATUS = require "skynet-fly.web.HTTP_STATUS"
local log         = require "skynet-fly.log"
local container_client = require "skynet-fly.client.container_client"

-- 如需访问其他服务，loading阶段注册
container_client:register("my_service_m")

local M   = {}
local app = engine_web:new()

M.dispatch = engine_web.dispatch(app)

function M.init()
    -- 全局中间件（顺序有影响，越先use越先执行）
    app:use(logger_mid())
    app:use(cors_mid())

    -- 鉴权中间件（自定义）
    local function auth_mid(c)
        local token = c.req.header["authorization"]
        if not token or token ~= "Bearer mytoken" then
            c.res:set_error_rsp(HTTP_STATUS.Unauthorized)
            c:abort()
            return
        end
        c:next()
    end

    -- 基础路由
    app:get("/", function(c)
        c.res:set_rsp("hello skynet_fly", HTTP_STATUS.OK)
    end)

    app:get("/ping", function(c)
        c.res:set_json_rsp({message = "pong"})
    end)

    -- GET 路由参数 + 查询参数
    app:get("/user/:id", function(c)
        local user_id  = c.params.id          -- 路由参数
        local nickname = c.req.query.nickname  -- 查询参数 ?nickname=xxx
        c.res:set_json_rsp({id = user_id, nickname = nickname})
    end)

    -- POST JSON 请求
    app:post("/api/login", function(c)
        local body = c.req.body   -- Content-Type: application/json → 自动解码为table
        local account  = body.account
        local password = body.password
        if not account then
            c.res:set_error_rsp(HTTP_STATUS.Bad_Request)
            return
        end
        c.res:set_json_rsp({code = 0, msg = "ok", player_id = 10001})
    end)

    -- POST form 请求
    app:post("/api/register", function(c)
        local name  = c.req.body.name   -- application/x-www-form-urlencoded
        local email = c.req.body.email
        c.res:set_json_rsp({code = 0, name = name})
    end)

    -- 需要鉴权的路由组
    local api = app:group("/api/v1")
    api:use(auth_mid)
    api:get("/profile", function(c)
        -- 调用其他热更服务
        local data = container_client:instance("my_service_m"):balance_call("get_profile")
        c.res:set_json_rsp({code = 0, data = data})
    end)

    -- 静态文件
    app:static_file("/favicon.ico", "./static/favicon.ico")
    app:static_dir("/static", "./static/")

    -- 404
    app:set_no_route(function(c)
        c.res:set_error_rsp(HTTP_STATUS.Not_Found)
    end)

    app:run()  -- ★ 必须最后调用
end

function M.exit()
end

return M
```

---

## 📋 load_mods.lua 配套配置

```lua
web_agent_m = {
    launch_seq = 2,
    launch_num = 8,          -- agent数=并发处理能力
    default_arg = {
        protocol         = 'http',
        dispatch         = 'apps.webapp_dispatch',   -- require路径格式
        keep_alive_time  = 300,                      -- 保活时间（秒）
        second_req_limit = 2000,                     -- 每秒请求数限制
    }
},
web_master_m = {
    launch_seq = 3,
    launch_num = 1,
    default_arg = {
        protocol          = 'http',
        port              = 8688,
        max_client        = 30000,
        second_conn_limit = 30000,
        keep_live_limit   = 30000,
    }
}
```

---

## ⚠️ 常见错误

| 错误 | 正确做法 |
|------|---------|
| 忘记 `app:run()` | `M.init()` 最后必须调用 |
| `engine_web.dispatch(app)` 写在 init 里 | 必须在文件顶层赋给 `M.dispatch` |
| `dispatch` 路径写成文件路径 | 用 require 路径格式：`apps.webapp_dispatch` |
| 中间件忘记调用 `c:next()` | 不调用 next，后续中间件和路由不会执行 |
| 路由参数写成 `c.req.params` | 正确是 `c.params`（不是 req.params） |
| POST body 为 string | 若 Content-Type 是 `application/json`，body 已自动解析为 table |
