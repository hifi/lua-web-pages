#include <stdio.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#define NO_FCGI_DEFINES
#include <fcgi_stdio.h>

#ifndef LUA_OK
#define LUA_OK 0
#endif

/* embedded luac output */
#include "redir_lua.h"

static int lua_fcgi_write_stdout(lua_State *L)
{
    size_t len = 0;
    const char *data;

    if (!lua_isstring(L, 1)) {
        return luaL_error(L, "expected a string");
    }

    data = lua_tolstring(L, 1, &len);
    len = FCGI_fwrite((char *)data, len, 1, FCGI_stdout);

    lua_pushnumber(L, len);
    return 1;
}

static int lua_fcgi_write_stderr(lua_State *L)
{
    size_t len = 0;
    const char *data;

    if (!lua_isstring(L, 1)) {
        return luaL_error(L, "expected a string");
    }

    data = lua_tolstring(L, 1, &len);
    len = FCGI_fwrite((char *)data, len, 1, FCGI_stderr);

    lua_pushnumber(L, len);
    return 1;
}

static inline int min(int a, int b) { return a < b ? a : b; }

static int lua_fcgi_read_stdin(lua_State *L)
{
    size_t len;
    static char data[16384];

    if (!lua_isnumber(L, 1)) {
        return luaL_error(L, "expected a number");
    }

    len = min(sizeof(data), lua_tointeger(L, 1));

    if (len < 1) {
        return 0;
    }

    len = FCGI_fread(&data, 1, len, FCGI_stdin);
    lua_pushlstring(L, (const char *)&data, len);

    return 1;
}

int redir_install(lua_State *L)
{
    /* load I/O redirection */
    if (luaL_loadbuffer(L, redir_lua, redir_lua_len, "redir.lua") != LUA_OK) {
        fprintf(stderr, "redir.lua load failed: %s\n", lua_tostring(L, -1));
        return 0;
    }

    /* init I/O redirection */
    if (lua_pcall(L, 0, 1, 0) != LUA_OK) {
        fprintf(stderr, "redir.lua init failed: %s\n", lua_tostring(L, -1));
        return 0;
    }

    /* install I/O redirection */
    lua_pushcfunction(L, lua_fcgi_read_stdin);
    lua_pushcfunction(L, lua_fcgi_write_stdout);
    lua_pushcfunction(L, lua_fcgi_write_stderr);

    if (lua_pcall(L, 3, 0, 0) != LUA_OK) {
        fprintf(stderr, "redir.lua exec failed: %s\n", lua_tostring(L, -1));
        return 0;
    }

    return 1;
}
