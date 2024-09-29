#include <lua.h>
#include <lauxlib.h>
#include <string.h>
#include <assert.h>
#include <unistd.h>

#include "skynet.h"


#define FRPCPACK_TEMP_LENGTH 0x8200
#define FRPCPACK_MULTI_PART 0x8000	//32k

const static uint8_t FRPCPACK_FLAG_WHOLE  = 0x01;	//表示整包
const static uint8_t FRPCPACK_FLAG_PART_H = 0x02;	//表示分包头
const static uint8_t FRPCPACK_FLAG_PART_C = 0x04;   //表示分包
const static uint8_t FRPCPACK_FLAG_PART_E = 0x08;   //表示分包尾
const static uint8_t FRPCPACK_FLAG_RSP	  = 0x10;   //表示需要回应
const static uint8_t FRPCPACK_FLAG_MOD	  = 0x20;   //表示需要模除

static void
fill_uint32(uint8_t * buf, uint32_t n) {
	buf[0] = n & 0xff;
	buf[1] = (n >> 8) & 0xff;
	buf[2] = (n >> 16) & 0xff;
	buf[3] = (n >> 24) & 0xff;
}

static inline uint32_t
unpack_uint32(const uint8_t * buf) {
	return buf[0] | buf[1]<<8 | buf[2]<<16 | buf[3]<<24;
}

static void
fill_int64(uint8_t * buf, int64_t n) {
	buf[0] = n & 0xffff;
	buf[1] = (n >> 8)  & 0xffff;
	buf[2] = (n >> 16) & 0xffff;
	buf[3] = (n >> 24) & 0xffff;
	buf[4] = (n >> 32) & 0xffff;
	buf[5] = (n >> 40) & 0xffff;
	buf[6] = (n >> 48) & 0xffff;
	buf[7] = (n >> 56) & 0xffff;
}

static inline int64_t
unpack_int64(const uint8_t * buf) {
    return (int64_t)buf[0] | (int64_t)buf[1] << 8 | (int64_t)buf[2] << 16 | (int64_t)buf[3] << 24 | 
           (int64_t)buf[4] << 32 | (int64_t)buf[5] << 40 | (int64_t)buf[6] << 48 | (int64_t)buf[7] << 56;
}

static void
fill_header(uint8_t *buf, int sz) {
	assert(sz < 0x10000);
	buf[0] = (sz >> 8) & 0xff;
	buf[1] = sz & 0xff;
}

static void
packreq_multi(lua_State *L, uint32_t session, void * msg, uint32_t sz) {
	uint8_t buf[FRPCPACK_TEMP_LENGTH];
	int part = (sz - 1) / FRPCPACK_MULTI_PART + 1;
	int i;
	char *ptr = msg;
	for (i=0;i<part;i++) {
		uint32_t s;
		if (sz > FRPCPACK_MULTI_PART) {
			s = FRPCPACK_MULTI_PART;
			buf[2] = FRPCPACK_FLAG_PART_C;
		} else {
			s = sz;
			buf[2] = FRPCPACK_FLAG_PART_E;	// the last multi part
		}
		fill_header(buf, s+5);
		fill_uint32(buf+3, session);
		memcpy(buf+7, ptr, s);
		lua_pushlstring(L, (const char *)buf, s+7);
		lua_rawseti(L, -2, i+1);
		sz -= s;
		ptr += s;
	}
}

static void
return_buffer(lua_State *L, const char * buffer, int sz) {
	void * ptr = skynet_malloc(sz);
	memcpy(ptr, buffer, sz);
	lua_pushlightuserdata(L, ptr);
	lua_pushinteger(L, sz);
}

/*
	args： 参数
	pack_id(uint8)		 协议号
	module_name(string)  调用模块服务ID
	instance_name(string) 模块服务下的名字
	session_id(uint32)	 标识消息 0表示不需要回应
	mod_num(int64)		 用于模除的num
	msg(userdata)		 skyent.pack 打包好的lua消息
	sz(uint32)			 msg 消息长度
	is_call(uint8)	     是否call调用

	pack:  打包
	sz(uint16)			 包长度
	flag(uint8) 		 0000 0000 	1号位为1表示整包  2号位为1表示分包头  2号位为1表示分包子包 4号位为1表示分包结尾包  5号位为1表示是否需要回应  6号位为1表示是否需要mod_num
	
	1 or 2时
		packid(uint8)	 	协议号
		name_sz(uint8)	 	modulename长度
		module_name(string) 调用模块名
		session_id(uint32)  必传
		mod_num(int64)		需要时打入
		msg(string)			2没有 lua消息内容

	3 or 4 时
		msg(string)			lua消息内容

	1 长度为 (uint16) + (uint8) + (uint8) + (uint8) + (name_sz)
	return:
	msgbuffer(string)    消息包
	parts(table)		 数据分包 没有就说明不需要分包
*/

static int
lpackrequest(lua_State *L) {
	int sz;
	void *msg;
	uint8_t need_free = 0;
	if (lua_type(L, 6) == LUA_TLIGHTUSERDATA) {
		msg = lua_touserdata(L, 6);
		sz = luaL_checkinteger(L, 7);
		need_free = 1;
	} else {
		size_t ssz;
		msg = (void *)luaL_checklstring(L,6,&ssz);
		sz = (int)ssz;
	}

	uint8_t pack_id = (uint8_t)luaL_checkinteger(L, 1);
	size_t module_name_len = 0;
	const char *module_name = lua_tolstring(L, 2, &module_name_len);
	if (module_name == NULL || module_name_len < 0 || module_name_len > 255) {
		if (need_free == 1) {
			skynet_free(msg);
		}
		if (module_name == NULL) {
			luaL_error(L, "module_name is not a string, it's a %s", lua_typename(L, lua_type(L, 2)));
		} else {
			luaL_error(L, "module_name is too long %s", module_name);
		}
	}

	size_t instance_name_len = 0;
	const char *instance_name = lua_tolstring(L, 3, &instance_name_len);
	if (instance_name == NULL || instance_name_len < 0 || instance_name_len > 255) {
		if (need_free == 1) {
			skynet_free(msg);
		}
		if (instance_name == NULL) {
			luaL_error(L, "instance_name is not a string, it's a %s", lua_typename(L, lua_type(L, 2)));
		} else {
			luaL_error(L, "instance_name is too long %s", instance_name);
		}
	}

	int64_t session_id = (int64_t)luaL_checkinteger(L, 4);
	if (session_id <= 0 || session_id > UINT32_MAX) {
		if (need_free == 1) {
			skynet_free(msg);
		}
		return luaL_error(L, "Invalid request session %lld", session_id);
	}

	int64_t mod_num = (int64_t)luaL_checkinteger(L, 5);
	if (mod_num < 0) {
		if (need_free == 1) {
			skynet_free(msg);
		}
		return luaL_error(L, "Invalid request mod_num %lld", mod_num);
	}

	uint8_t is_call = (uint8_t)luaL_checkinteger(L, 8);

	int part = (sz - 1) / FRPCPACK_MULTI_PART + 1;
	uint8_t buf[FRPCPACK_TEMP_LENGTH];
	uint8_t flag = 0;
	if (part == 1) {
		flag = FRPCPACK_FLAG_WHOLE;
	} else {
		flag = FRPCPACK_FLAG_PART_H;
	}
	
	uint32_t bsz = 6 + module_name_len + instance_name_len;    //sz(uint16) + flag(uint8) + pack_id(uint8) + modulenamelen(uint8) + instancenamelen = 6字节
	buf[3] = pack_id;
	buf[4] = module_name_len;
	buf[5] = instance_name_len;
	memcpy(buf + 6, module_name, module_name_len);
	memcpy(buf + 6 + module_name_len, instance_name, instance_name_len);
	fill_uint32(buf + bsz, session_id);
	bsz += 4;
	if (is_call == 1) {	
		flag |= FRPCPACK_FLAG_RSP;
	}
	if (mod_num > 0) {
		fill_int64(buf + bsz, mod_num);
		bsz += 8;
		flag |= FRPCPACK_FLAG_MOD;
	}

	buf[2] = flag;
	
	if (part == 1) {
		memcpy(buf+bsz, msg, sz);
		fill_header(buf, bsz + sz - 2);    //-2 有2字节表示包长
		lua_pushlstring(L, (const char *)buf, bsz + sz);
		if (need_free == 1) {
			skynet_free(msg);
		}
		return 1;
	} else {
		fill_uint32(buf + bsz, sz);
		bsz += 4;
		fill_header(buf, bsz - 2);		  //-2 有2字节表示包长
		lua_pushlstring(L, (const char *)buf, bsz);

		lua_createtable(L, part, 0);
		packreq_multi(L, session_id, msg, sz);
		if (need_free == 1) {
			skynet_free(msg);
		}
		return 2;
	}
}

static int
unpackmreq_part(lua_State *L, const uint8_t * buf, int sz) {
	if (sz < 5) {
		return luaL_error(L, "Invalid cluster multi part message");
	}
	int padding = (buf[0] == FRPCPACK_FLAG_PART_C);
	uint32_t session = unpack_uint32(buf+1);
	lua_pushnil(L);				//pack_id
	lua_pushnil(L);				//module_name
	lua_pushnil(L);				//instance_name
	lua_pushinteger(L, session); //session_id
	lua_pushnil(L);				 //mod_num
	return_buffer(L, (const char *)buf+5, sz-5);
	lua_pushboolean(L, padding);

	return 8;
}

static int
unpackrequest(lua_State *L, const uint8_t *msg, int sz, uint8_t is_rsp, uint8_t is_mod, uint8_t is_part_h) {
	if (sz < 3) {
		return luaL_error(L, "Invalid frpcpack message (size=%d)", sz);
	}
	uint8_t pack_id = msg[1];
	int module_name_len = msg[2];
	int instance_name_len = msg[3];

	int min_len = 8 + module_name_len + instance_name_len;			// flag + pack_id + module_name_len + instance_name_len + session 
	if (is_mod == FRPCPACK_FLAG_MOD) {
		min_len += 8;			//需要mod多8字节的mod
	}
	if (is_part_h == 1) {
		min_len += 4;			//分包头 多4字节的长度
	}
	if (sz < min_len) {
		return luaL_error(L, "Invalid frpcpack message (size=%d)", sz);
	}

	int offset = 4;		//flag + pack_id + module_name_len + instance_name_len
	lua_pushinteger(L, pack_id);										//返回pack_id
	lua_pushlstring(L, (const char *)msg + offset, module_name_len); 	//返回module_name
	offset += module_name_len;
	lua_pushlstring(L, (const char *)msg + offset, instance_name_len);  //返回instance_name
	offset += instance_name_len;
	uint32_t session = unpack_uint32(msg + offset);
	offset += 4;
	lua_pushinteger(L, (uint32_t)session);								//返回session_id
	if (is_mod == FRPCPACK_FLAG_MOD) {
		int64_t mod_num = unpack_int64(msg + offset);
		offset += 8;
		lua_pushinteger(L, (int64_t)mod_num);							//返回mod_num
	} else {
		lua_pushnil(L);													//返回mod_num
	}

	if (is_part_h == 1) {
		lua_pushnil(L);	                                     			//返回msg
		uint32_t msgsz = unpack_uint32(msg + offset);	 	 			//返回msgsz
		lua_pushinteger(L, (uint32_t)msgsz);
		lua_pushboolean(L, 1);								 			//是否分包
	} else {
		return_buffer(L, (const char *)msg + offset, sz - offset); 		//返回msg msgsz
		lua_pushboolean(L, 0);							     			//是否分包
	}
	
	if (is_rsp == FRPCPACK_FLAG_RSP) {
		lua_pushboolean(L, 1);								 			//是否需要回复
	} else {
		lua_pushboolean(L, 0);								 			//是否需要回复
	}
	return 9;
}

static int
lunpackrequest(lua_State *L) {
	int sz;
	const uint8_t *msg;
	if (lua_type(L, 1) == LUA_TLIGHTUSERDATA) {
		msg = (const uint8_t *)lua_touserdata(L, 1);
		sz = luaL_checkinteger(L, 2);
	} else {
		size_t ssz;
		msg = (const uint8_t *)luaL_checklstring(L,1,&ssz);
		sz = (int)ssz;
	}
	if (sz == 0) {
		return luaL_error(L, "Invalid req package. size == 0");
	}

	uint8_t flag = msg[0];
	uint8_t is_rsp = flag & FRPCPACK_FLAG_RSP;
	uint8_t is_mod = flag & FRPCPACK_FLAG_MOD;
	flag &= 0x0f;
	switch (flag) {
		case 1:   //FRPCPACK_FLAG_WHOLE
			return unpackrequest(L, msg, sz, is_rsp, is_mod, 0);
		case 2:	  //FRPCPACK_FLAG_PART_H
			return unpackrequest(L, msg, sz, is_rsp, is_mod, 1);
		case 4:	  //FRPCPACK_FLAG_PART_C
		case 8:	  //FRPCPACK_FLAG_PART_E
			return unpackmreq_part(L, msg, sz);
		default:
		return luaL_error(L, "Invalid req package type %d", flag);
	}
}

static int
lpackresponse(lua_State *L) {
	uint32_t session = (uint32_t)luaL_checkinteger(L,1);
	// frpc_server.lua:command.socket call lpackresponse,
	// and the msg/sz is return by skynet.rawcall , so don't free(msg)
	int ok = lua_toboolean(L,2);
	void * msg;
	size_t sz;
	
	if (lua_type(L,3) == LUA_TSTRING) {
		msg = (void *)lua_tolstring(L, 3, &sz);
	} else {
		msg = lua_touserdata(L,3);
		sz = (size_t)luaL_checkinteger(L, 4);
	}

	if (!ok) {
			if (sz > FRPCPACK_MULTI_PART) {
			// truncate the error msg if too long
			sz = FRPCPACK_MULTI_PART;
		}
	} else {
		if (sz > FRPCPACK_MULTI_PART) {
			int part = (sz - 1) / FRPCPACK_MULTI_PART + 1;
			lua_createtable(L, part+1, 0);
			uint8_t buf[FRPCPACK_TEMP_LENGTH];

			// multi part begin
			fill_header(buf, 9);			//  两字节 sz
			fill_uint32(buf+2, session); 	//4 字节session
			buf[6] = FRPCPACK_FLAG_PART_H;  //1 分包头
			fill_uint32(buf+7, (uint32_t)sz); // 4字节sz
			lua_pushlstring(L, (const char *)buf, 11);
			lua_rawseti(L, -2, 1);

			char * ptr = msg;
			int i;
			for (i=0;i<part;i++) {
				int s;
				if (sz > FRPCPACK_MULTI_PART) {
					s = FRPCPACK_MULTI_PART;
					buf[6] = FRPCPACK_FLAG_PART_C;  //1字节小分包
				} else {
					s = sz;
					buf[6] = FRPCPACK_FLAG_PART_E;  //1字节分包尾
				}
				fill_header(buf, s+5);				//2字节长度
				fill_uint32(buf+2, session);		//4字节session
				memcpy(buf+7,ptr,s);
				lua_pushlstring(L, (const char *)buf, s+7);
				lua_rawseti(L, -2, i+2);
				sz -= s;
				ptr += s;
			}
			return 1;
		}
	}

	uint8_t buf[FRPCPACK_TEMP_LENGTH];
	fill_header(buf, sz+5);			//2字节长度
	fill_uint32(buf+2, session);	//4字节session
	buf[6] = ok;
	memcpy(buf+7,msg,sz);

	lua_pushlstring(L, (const char *)buf, sz+7);

	return 1;
}

static int
lunpackresponse(lua_State *L) {
	size_t sz;
	const char * buf = luaL_checklstring(L, 1, &sz);
	if (sz < 5) {
		return 0;
	}
	uint32_t session = unpack_uint32((const uint8_t *)buf);
	lua_pushinteger(L, (uint32_t)session);
	switch(buf[4]) {
	case 0:	// error
		lua_pushboolean(L, 0);
		lua_pushlstring(L, buf+5, sz-5);
		return 3;
	case 1:	// FRPCPACK_FLAG_WHOLE
	case 8:	// FRPCPACK_FLAG_PART_E
		lua_pushboolean(L, 1);
		lua_pushlstring(L, buf+5, sz-5);
		return 3;
	case 2:	// FRPCPACK_FLAG_PART_H
		if (sz != 9) {
			return 0;
		}
		sz = unpack_uint32((const uint8_t *)buf+5);
		lua_pushboolean(L, 1);
		lua_pushinteger(L, sz);							//包总长度
		lua_pushboolean(L, 1);							//是否分包
		return 4;
	case 4:	// FRPCPACK_FLAG_PART_C
		lua_pushboolean(L, 1);
		lua_pushlstring(L, buf+5, sz-5);
		lua_pushboolean(L, 1);							//是否分包
		return 4;
	default:
		return 0;
	}
}

//打包pub推送消息
static int
lpackpubmessage(lua_State *L) {
	void * msg;
	size_t sz;
	if (lua_type(L,2) == LUA_TSTRING) {
		msg = (void *)lua_tolstring(L, 2, &sz);
	} else {
		msg = lua_touserdata(L,2);
		sz = (size_t)luaL_checkinteger(L, 3);
	}

	size_t channel_name_len = 0;
	const char *channel_name = lua_tolstring(L, 1, &channel_name_len);
	if (channel_name == NULL || channel_name_len < 0 || channel_name_len > 255) {
		if (channel_name == NULL) {
			luaL_error(L, "channel_name is not a string, it's a %s", lua_typename(L, lua_type(L, 1)));
		} else {
			luaL_error(L, "channel_name is too long %s", channel_name);
		}
	}

	uint8_t pack_id = (uint8_t)luaL_checkinteger(L, 4);
	int64_t session = (int64_t)luaL_checkinteger(L, 5);
	if (session <= 0 || session > UINT32_MAX) {
		return luaL_error(L, "Invalid request session %lld", session);
	}

	if (sz > FRPCPACK_MULTI_PART) {
		int part = (sz - 1) / FRPCPACK_MULTI_PART + 1;
		lua_createtable(L, part+1, 0);
		uint8_t buf[FRPCPACK_TEMP_LENGTH];

		// multi part begin
		fill_header(buf, 11 + channel_name_len);  // 两字节 sz
		buf[2] = FRPCPACK_FLAG_PART_H;  		 // 1 分包头
		fill_uint32(buf + 3, (uint32_t)sz);      // 4字节sz
		buf[7] = pack_id;					     // 1字节PACK_id
		fill_uint32(buf + 8, session);           // 4字节session
		buf[12] = channel_name_len;				 // 1字节名字长度
		memcpy(buf + 13, channel_name, channel_name_len);
		lua_pushlstring(L, (const char *)buf, 13 + channel_name_len);
		lua_rawseti(L, -2, 1);

		char * ptr = msg;
		int i;
		for (i=0;i<part;i++) {
			int s;
			if (sz > FRPCPACK_MULTI_PART) {
				s = FRPCPACK_MULTI_PART;
				buf[2] = FRPCPACK_FLAG_PART_C;  //1字节小分包
			} else {
				s = sz;
				buf[2] = FRPCPACK_FLAG_PART_E;  //1字节分包尾
			}
			fill_header(buf, s+1);				//2字节长度
			memcpy(buf+3,ptr,s);
			lua_pushlstring(L, (const char *)buf, s+3);
			lua_rawseti(L, -2, i+2);
			sz -= s;
			ptr += s;
		}
		return 1;
	}

	uint8_t buf[FRPCPACK_TEMP_LENGTH];
	fill_header(buf, sz + channel_name_len + 7); //2字节长度
	buf[2] = FRPCPACK_FLAG_WHOLE;	//1字节表示整包
	buf[3] = pack_id;
	fill_uint32(buf + 4, session);  //4字节session
	buf[8] = channel_name_len;		//1字节名字长度
	memcpy(buf + 9, channel_name, channel_name_len);
	memcpy(buf + 9 + channel_name_len, msg, sz);

	lua_pushlstring(L, (const char *)buf, sz + 9 + channel_name_len);
	return 1;
}

static int
lunpackpubmessage(lua_State *L) {
	size_t sz;
	const char * buf = luaL_checklstring(L, 1, &sz);
	if (sz < 1) {
		return 0;
	}
	
	switch(buf[0]) {
	case 1:	// FRPCPACK_FLAG_WHOLE
		if (sz < 7) {
			return 0;
		}
		lua_pushboolean(L, 1);
		lua_pushlstring(L, buf+1, sz-1);
		return 2;
	case 8:	// FRPCPACK_FLAG_PART_E
		lua_pushboolean(L, 1);
		lua_pushlstring(L, buf+1, sz-1);
		return 2;
	case 2:	// FRPCPACK_FLAG_PART_H
		if (sz < 11) {
			return 0;
		}
		lua_pushboolean(L, 1);
		lua_pushlstring(L, buf+1, sz-1);
		lua_pushboolean(L, 1);							//是否分包
		return 3;
	case 4:	// FRPCPACK_FLAG_PART_C
		lua_pushboolean(L, 1);
		lua_pushlstring(L, buf+1, sz-1);
		lua_pushboolean(L, 1);							//是否分包
		return 3;
	default:
		return 0;
	}
}

static int
lappend(lua_State *L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	int n = lua_rawlen(L, 1);
	if (lua_isnil(L, 2)) {
		lua_settop(L, 3);
		lua_seti(L, 1, n + 1);
		return 0;
	}
	void * buffer = lua_touserdata(L, 2);
	if (buffer == NULL)
		return luaL_error(L, "Need lightuserdata");
	int sz = luaL_checkinteger(L, 3);
	lua_pushlstring(L, (const char *)buffer, sz);
	skynet_free((void *)buffer);
	lua_seti(L, 1, n+1);
	return 0;
}

static int
lconcat(lua_State *L) {
	if (!lua_istable(L,1))
		return 0;
	if (lua_geti(L,1,1) != LUA_TNUMBER)
		return 0;
	int sz = lua_tointeger(L,-1);
	lua_pop(L,1);
	char * buff = skynet_malloc(sz);
	int idx = 2;
	int offset = 0;
	while(lua_geti(L,1,idx) == LUA_TSTRING) {
		size_t s;
		const char * str = lua_tolstring(L, -1, &s);
		if (s+offset > sz) {
			skynet_free(buff);
			return 0;
		}
		memcpy(buff+offset, str, s);
		lua_pop(L,1);
		offset += s;
		++idx;
	}
	if (offset != sz) {
		skynet_free(buff);
		return 0;
	}
	// buff/sz will send to other service, See clusterd.lua
	lua_pushlightuserdata(L, buff);							//这里的消息粘好以后，会发给其他服务消费，其他服务消费完了会释放内存，如果没发，需要释放好内存
	lua_pushinteger(L, sz);
	return 2;
}

LUAMOD_API int
luaopen_frpcpack_core(lua_State *L) {
	luaL_Reg l[] = {
		{ "packrequest", lpackrequest},
		{ "unpackrequest", lunpackrequest},
		{ "packresponse", lpackresponse},
		{ "unpackresponse", lunpackresponse},
		{ "packpubmessage", lpackpubmessage},
		{ "unpackpubmessage", lunpackpubmessage},
		{ "append", lappend },
		{ "concat", lconcat },
		{ NULL, NULL},
	};
	luaL_checkversion(L);
	luaL_newlib(L,l);

	return 1;
}
