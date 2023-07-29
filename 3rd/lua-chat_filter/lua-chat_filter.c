#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "rwlock.h"

#define MAX_NEXT_NODE_COUNT 256

typedef struct Node
{
	unsigned char ch_data;
	char end_flag;
	struct Node *p_next_nodes[MAX_NEXT_NODE_COUNT];
}Node;

static int is_init = 0;
static struct rwlock lock;
static Node* Root_node = NULL;

static int free_node(Node* p_node)
{
	if (NULL == p_node)
	{
		return 0;
	}
	int i = 0;
	for (i = 0; i < MAX_NEXT_NODE_COUNT; i++)
	{
		if (p_node->p_next_nodes[i] != NULL)
		{
			free_node(p_node->p_next_nodes[i]);
		}
	}
	//printf("free:%p %p %c\n",&p_node,p_node,p_node->ch_data);
	free(p_node);
	p_node = NULL;
	return 0;
}

static int
insert_node(Node* p_node, const char* p_line, size_t n_index)
{
	Node* p_find_node = p_node->p_next_nodes[(unsigned char)p_line[n_index]];
	if (p_find_node == NULL)
	{
		p_find_node = (Node *)malloc(sizeof(Node));
		memset(p_find_node, 0, sizeof(Node));
		p_find_node->ch_data = (unsigned char)p_line[n_index];
		p_node->p_next_nodes[p_find_node->ch_data] = p_find_node;
	}
	size_t n_line_size = strlen(p_line);
	if (n_index == n_line_size - 1)
	{
		p_find_node->end_flag = 1;
	}
	n_index++;
	if (n_index < n_line_size)
	{
		insert_node(p_find_node, p_line, n_index);
	}
	return 0;
}

static int
filter_chat(char* pMsg)
{
	//printf("filter_chat:%s\n",pMsg);
  	int ret = 0;
	if (NULL == Root_node)
	{
		return ret;
	}

	static const unsigned char FILL_CHAR = '*';
  	int nMsglen = strlen(pMsg);
	int nTmpMsgLen = 0;
	char * chTmpBuff = (char *)malloc(sizeof(char) * (nMsglen + 1));
	memset(chTmpBuff, 0x00, sizeof(char) * (nMsglen + 1));
	strcpy(chTmpBuff, pMsg);
	char * chTmpWord = (char *)malloc(sizeof(char) * (nMsglen + 1));
	memset(chTmpWord, 0x00, sizeof(char) * (nMsglen + 1));
	int nWordIndex = 0;

	int nStart = -1;

	Node *pNode = Root_node;
	while (nTmpMsgLen < nMsglen)
	{
		unsigned char chTmpValue = pMsg[nTmpMsgLen];
		if (chTmpValue == ' ')
		{
			if (nStart == -1)
			{
				nStart = nTmpMsgLen;
			}
			chTmpWord[nWordIndex] = chTmpValue;
			nWordIndex++;
			nTmpMsgLen++;
			continue;
		}
		pNode = pNode->p_next_nodes[chTmpValue];
		if (pNode == NULL)
		{
			pNode = Root_node;
			nTmpMsgLen = nTmpMsgLen - nWordIndex;
			nWordIndex = 0;
			nStart = -1;
			nTmpMsgLen++;
			continue;
		}
		if (nStart == -1)
		{
			nStart = nTmpMsgLen;
		}
		//printf("filter %s\n",chTmpWord);
		chTmpWord[nWordIndex] = FILL_CHAR;
		if (pNode->end_flag == 1)
		{
      ret = 1;
			memcpy(chTmpBuff + nStart, chTmpWord, nWordIndex + 1);
			nWordIndex = 0;
			nStart = -1;
			pNode = Root_node;
		}
		else
		{
			nWordIndex++;
		}
		nTmpMsgLen++;
	}
	nTmpMsgLen = strlen(chTmpBuff);
	int nRetLen = nMsglen > nTmpMsgLen ? nTmpMsgLen : nMsglen;
	memcpy(pMsg, chTmpBuff, nRetLen);
	free(chTmpBuff);
	free(chTmpWord);
	return ret;
}

static int
command_load_string(lua_State *L)
{
	if (!lua_isstring(L,-1))
	{
		luaL_error(L,"arg_ment #%d err not string",1);
	}
	rwlock_wlock(&lock);
	const char* ch_line = lua_tostring(L,-1);
	if (NULL == Root_node) {
	Root_node = (Node *)malloc(sizeof(Node));
	memset(Root_node, 0, sizeof(Node));
	}

	size_t line_size = strlen(ch_line);
	if (line_size > 0) {
		insert_node(Root_node, ch_line, 0);
	}
		rwlock_wunlock(&lock);
	return 0;
}

static int
command_filter_chat(lua_State *L)
{
    if (!lua_isstring(L,-1))
    {
        luaL_error(L,"arg_ment #%d err not string",1);
    }

    char* str = lua_tostring(L,-1);
    rwlock_rlock(&lock);
    int ret = filter_chat(str);
    rwlock_runlock(&lock);
	lua_pushstring(L,str);
    lua_pushinteger(L,ret);
    return 2;
}

static int
command_release(lua_State *L)
{
  	rwlock_wlock(&lock);
	free_node(Root_node);
	Root_node = NULL;
  	rwlock_wunlock(&lock);
	return 0;
}

static int
command_init(lua_State *L)
{
	int old_val = __sync_val_compare_and_swap(&is_init,0,1);
	if (old_val == 0) {
		rwlock_init(&lock);
	}
	lua_pushinteger(L,old_val);
	return 1;
}

static const struct luaL_Reg cmd[] =
{
    {"filter_chat",command_filter_chat},
	{"release",command_release},
    {"loadstring",command_load_string},
    {"init",command_init},
    {NULL,NULL},
};

int luaopen_chat_filter(lua_State *L)
{
    luaL_newlib(L,cmd);
    return 1;
}
