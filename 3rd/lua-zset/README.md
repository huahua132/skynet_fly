## zset
lua的sorted set实现， 其中skiplist的实现基本是从redis源码里面抠出来的, 只有几个接口的约定不太一致。

## build & test 
```
make && lua test_sl.lua && lua test.lua
```

