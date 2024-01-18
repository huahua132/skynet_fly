# 路由 RadixTree

[lua-rax][lua-rax] 是在 Lua 中实现的自适应 [基数树][基数树] , 基于 [rax][rax] 实现。

用于替换 [wlua][wlua] 框架中的 [lua-r3][lua-r3] 路由库。

规则实现参考 [lua-resty-radixtree][lua-resty-radixtree] 。

## 路径匹配规则

### 1. 完全匹配

```
/blog/foo
```

此时只能匹配 `/blog/foo` 。

### 2. 前缀匹配

```
/blog/bar*
```

它将匹配带有前缀 `/blog/bar` 的路径， 例如： `/blog/bar/a` 、 `/blog/bar/b` 、 `/blog/bar/c/d/e` 、 `/blog/bar` 等。

### 3. 匹配优先级

完全匹配 -> 深度前缀匹配

以下是规则：

```
/blog/foo/*
/blog/foo/a/*
/blog/foo/c/*
/blog/foo/bar
```

| 路径            | 匹配结果       |
|:---------------:|:--------------:|
| /blog/foo/bar   | /blog/foo/bar  |
| /blog/foo/a/b/c | /blog/foo/a/*  |
| /blog/foo/c/d   | /blog/foo/c/*  |
| /blog/foo/gloo  | /blog/foo/*    |
| /blog/bar       |  not match     |

### 4. 参数匹配

示例：

```
/blog/:name
```

会匹配 `/blog/dog` 和 `blog/cat` 。

更多使用方法参考 `test.lua` 。

## 参考

- [lua-rax][lua-rax]
- [基数树][基数树]
- [wlua][wlua]
- [lua-r3][lua-r3]
- [rax][rax]
- [lua-resty-radixtree][lua-resty-radixtree]

[lua-rax]: https://github.com/hanxi/lua-rax
[基数树]: https://zh.wikipedia.org/wiki/%E5%9F%BA%E6%95%B0%E6%A0%91
[wlua]: https://github.com/hanxi/wlua
[lua-r3]: https://github.com/hanxi/lua-r3
[rax]: https://github.com/antirez/rax
[lua-resty-radixtree]: https://github.com/api7/lua-resty-radixtree

