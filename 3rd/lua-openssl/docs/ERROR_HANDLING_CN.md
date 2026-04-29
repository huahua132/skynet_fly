# lua-openssl 贡献者错误处理指南

## 概述

本文档描述了 lua-openssl 开发的错误处理模式和最佳实践。遵循这些指南可确保一致、可预测的错误处理行为并防止资源泄漏。

## 核心原则

### 1. 使用异常进行输入验证

API 输入参数应使用 Lua 的标准错误检查函数来验证参数：

```c
// 示例：验证参数类型
luaL_argcheck(L, condition, arg_position, "error message");
luaL_checkstring(L, arg_position);
luaL_checkinteger(L, arg_position);
```

**使用场景：** 验证函数参数（错误类型、超出范围等）

**行为：** 抛出 Lua 错误并中止当前操作。

### 2. 运行时错误返回失败值

在 API 处理过程中，如果发生错误，优先返回错误信息而不是抛出异常：

```c
// 示例：通过 openssl_pushresult 返回错误
int ret = EVP_SomeOperation(ctx, ...);
if (ret == 1) {
    // 成功路径
    PUSH_OBJECT(result, "openssl.type");
    return 1;
} else {
    // 错误路径 - 释放资源然后返回错误
    EVP_CTX_free(ctx);
    return openssl_pushresult(L, ret);
}
```

**使用场景：** OpenSSL 操作的运行时错误（失败的加密操作、无效数据等）

**行为：** 向 Lua 返回 `nil, error_message, error_code`，允许调用者处理错误。

**原因：** 这遵循 Lua 约定，在正常操作期间可能合理发生的错误应作为值返回，而不是异常。

### 3. 不可恢复的错误使用异常

对于不需要返回值且遇到不可恢复错误的操作：

```c
// 示例：内存分配失败
buffer = OPENSSL_malloc(size);
if (buffer == NULL) {
    EVP_CTX_free(ctx);  // 首先清理！
    return luaL_error(L, "Memory allocation failed");
}
```

**使用场景：** 真正的异常情况（内存不足、内部状态损坏）。

**行为：** 抛出 Lua 错误并中止当前操作。

## 资源管理

### 关键规则：始终在错误路径上释放资源

每个分配的资源必须在所有错误路径上释放：

```c
// ❌ 错误 - 错误路径上的内存泄漏
EVP_MD_CTX *ctx = EVP_MD_CTX_new();
if (ctx) {
    ret = EVP_DigestInit_ex(ctx, md, e);
    if (ret == 1) {
        PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    } else {
        // 错误：ctx 未被释放！
        ret = openssl_pushresult(L, ret);
    }
}
return ret;

// ✅ 正确 - 所有路径上释放资源
EVP_MD_CTX *ctx = EVP_MD_CTX_new();
if (ctx) {
    ret = EVP_DigestInit_ex(ctx, md, e);
    if (ret == 1) {
        PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    } else {
        EVP_MD_CTX_free(ctx);  // 返回错误前释放资源
        ret = openssl_pushresult(L, ret);
    }
}
return ret;
```

### 常见资源类型和清理函数

| 资源类型 | 分配 | 清理 |
|---------|------|------|
| EVP_MD_CTX | `EVP_MD_CTX_new()` | `EVP_MD_CTX_free(ctx)` |
| EVP_CIPHER_CTX | `EVP_CIPHER_CTX_new()` | `EVP_CIPHER_CTX_free(ctx)` |
| EVP_PKEY_CTX | `EVP_PKEY_CTX_new()` | `EVP_PKEY_CTX_free(ctx)` |
| HMAC_CTX | `HMAC_CTX_new()` | `HMAC_CTX_free(ctx)` |
| EVP_MAC_CTX | `EVP_MAC_CTX_new()` | `EVP_MAC_CTX_free(ctx)` |
| BIO | `BIO_new()` | `BIO_free(bio)` |
| X509 | `X509_new()` | `X509_free(cert)` |
| EVP_PKEY | `EVP_PKEY_new()` | `EVP_PKEY_free(pkey)` |
| 内存 | `malloc()` / `OPENSSL_malloc()` | `free()` / `OPENSSL_free()` |

## openssl_pushresult 函数

位于 `src/misc.c`，此函数标准化错误报告：

```c
int openssl_pushresult(lua_State *L, int result)
{
  if (result >= 1) {
    lua_pushboolean(L, 1);
    return 1;
  } else {
    unsigned long val = ERR_get_error();
    lua_pushnil(L);
    if (val) {
      lua_pushstring(L, ERR_reason_error_string(val));
      lua_pushinteger(L, val);
    } else {
      lua_pushstring(L, "UNKNOWN ERROR");
      lua_pushnil(L);
    }
    return 3;
  }
}
```

**返回值：**
- 成功时 (result >= 1): `true` (1 个返回值)
- 失败时: `nil, error_message, error_code` (3 个返回值)

## 常见模式

### 模式 1：上下文创建和初始化

```c
static int openssl_function(lua_State *L)
{
  const EVP_MD *md = get_digest(L, 1, NULL);
  EVP_MD_CTX   *ctx = EVP_MD_CTX_new();
  int           ret = 0;

  if (ctx) {
    ret = EVP_DigestInit_ex(ctx, md, NULL);
    if (ret == 1) {
      PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    } else {
      EVP_MD_CTX_free(ctx);  // ⚠️ 关键：错误时释放
      ret = openssl_pushresult(L, ret);
    }
  }
  return ret;
}
```

### 模式 2：多步操作

```c
static int openssl_function(lua_State *L)
{
  EVP_CIPHER_CTX *c = EVP_CIPHER_CTX_new();
  char           *buffer = NULL;
  int             ret = 0;

  if (!c) return 0;

  ret = EVP_EncryptInit_ex(c, cipher, NULL, key, iv);
  if (ret == 1) {
    buffer = OPENSSL_malloc(size);
    if (!buffer) {
      EVP_CIPHER_CTX_free(c);  // 错误前释放 c
      return luaL_error(L, "Memory allocation failed");
    }
    
    ret = EVP_EncryptUpdate(c, buffer, &len, input, input_len);
    if (ret == 1) {
      ret = EVP_EncryptFinal_ex(c, buffer + len, &len2);
      if (ret == 1) {
        lua_pushlstring(L, buffer, len + len2);
      }
    }
    OPENSSL_free(buffer);  // 始终释放缓冲区
  }
  
  EVP_CIPHER_CTX_free(c);  // 始终释放上下文
  return (ret == 1) ? 1 : openssl_pushresult(L, ret);
}
```

### 模式 3：成功时提前返回

```c
static int openssl_function(lua_State *L)
{
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(pkey, engine);
  
  if (EVP_PKEY_encrypt_init(ctx) == 1) {
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, padding) == 1) {
      byte *buf = malloc(clen);
      if (EVP_PKEY_encrypt(ctx, buf, &clen, data, dlen) == 1) {
        lua_pushlstring(L, (const char *)buf, clen);
        free(buf);
        EVP_PKEY_CTX_free(ctx);
        return 1;  // 成功时提前返回
      }
      free(buf);
    }
  }
  EVP_PKEY_CTX_free(ctx);  // 所有错误路径的清理
  return 0;
}
```

## 测试错误路径

### 手动测试

通过提供无效输入来测试错误路径：

```lua
-- 测试无效的摘要算法
local result, err, code = openssl.digest.new("invalid_algorithm")
assert(result == nil)
assert(type(err) == "string")
assert(type(code) == "number" or code == nil)

-- 测试 nil 密钥
local result, err = openssl.hmac.new("sha256", nil)
assert(result == nil)
assert(err ~= nil)
```

### 内存泄漏检测

使用 Valgrind 或 AddressSanitizer 检测泄漏：

```bash
# 使用 AddressSanitizer 构建
make clean && make asan

# 为 Valgrind 构建
make clean && make valgrind
```

两者都应该报告正确实现的零内存泄漏。

## 代码审查检查清单

审查错误处理代码时，请验证：

- [ ] 所有分配的资源都有相应的释放调用
- [ ] 错误路径在返回前释放资源
- [ ] 输入验证使用 `luaL_argcheck` 或类似函数
- [ ] 运行时错误使用 `openssl_pushresult`
- [ ] 真正的异常错误使用 `luaL_error`
- [ ] 提前返回不跳过清理代码
- [ ] 多步操作在失败时清理部分状态
- [ ] 内存分配检查 NULL
- [ ] 成功路径不泄漏资源

## 参考

- `src/misc.c` - `openssl_pushresult` 的实现
- `src/digest.c` - 正确的摘要上下文处理示例
- `src/cipher.c` - 正确的密码上下文处理示例
- `src/pkey.c` - 正确的密钥上下文处理示例

## 版本历史

- 2025-01-10: 初始版本 - 记录当前错误处理模式
