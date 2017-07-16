#include <stdio.h>
#include <stdlib.h>

#include "config.h"
#include "cache.h"

#ifdef WITH_CACHE

/* embedded luac output */
#ifdef WITH_LWP
    #include "lwp.luac.h"
#endif

#ifndef LUA_OK
#define LUA_OK 0
#endif

#include "cache.luac.h"

static lua_State *cache;

int cache_init()
{
    int ret = 0;

    cache = luaL_newstate();
    luaL_openlibs(cache);

#ifdef WITH_LWP
    if (luaL_loadbuffer(cache, lwp_lua, lwp_lua_len, "lwp.lua") != LUA_OK) {
        fprintf(stderr, "Lua Web Pages library load failed: %s\n", lua_tostring(cache, 1));
        goto error;
    }

    if (lua_pcall(cache, 0, 1, 0) != LUA_OK) {
        fprintf(stderr, "Lua Web Pages library init failed: %s\n", lua_tostring(cache, 1));
        goto error;
    }

    lua_setglobal(cache, "lwp");
#endif

    if (luaL_loadbuffer(cache, cache_lua, cache_lua_len, "cache.lua") != LUA_OK) {
        fprintf(stderr, "Cache library load failed: %s\n", lua_tostring(cache, 1));
        goto error;
    }

    if (lua_pcall(cache, 0, 1, 0) != LUA_OK) {
        fprintf(stderr, "Cache library init failed: %s\n", lua_tostring(cache, 1));
        goto error;
    }

    lua_setglobal(cache, "cache");

    ret = 1;
error:
    if (!ret) {
        lua_close(cache);
        cache = NULL;
    }

    return ret;
}

static int cache_load(lua_State *L, const char *modname, const char *paths, const char *tag)
{
    int ret = LUA_ERRFILE, npop = 2;

    size_t len;
    const char *s;

    if (!cache) return ret;

    lua_getglobal(cache, "cache");
    lua_getfield(cache, -1, "load");
    lua_remove(cache, -2);
    lua_pushstring(cache, modname);
    lua_pushstring(cache, paths);
    lua_pushstring(cache, tag);

    if (lua_pcall(cache, 3, 2, 0) != LUA_OK) {
        lua_pushstring(L, lua_tostring(cache, 1));
        ret = LUA_ERRSYNTAX;
        npop = 1;
        goto error;
    }

    /* return error string in stack */
    if (lua_isnil(cache, 1)) {
        lua_pushstring(L, lua_tostring(cache, 2));
        ret = LUA_ERRSYNTAX;
        goto error;
    }

    s = lua_tolstring(cache, 1, &len);
    if ((ret = luaL_loadbuffer(L, s, len, modname)) != LUA_OK) {
        fprintf(stderr, "loadbuffer failed, has error\n");
        goto error;
    }

    ret = LUA_OK;
error:
    lua_pop(cache, npop);
    return ret;
}

int cache_loadfile(lua_State *L, const char *filename, const char *tag)
{
    int ret = LUA_ERRFILE, npop = 2;

    size_t len;
    const char *s;

    if (!cache) return ret;

    lua_getglobal(cache, "cache");
    lua_getfield(cache, -1, "loadfile");
    lua_remove(cache, -2);
    lua_pushstring(cache, filename);
    lua_pushstring(cache, tag);

    if (lua_pcall(cache, 2, 2, 0) != LUA_OK) {
        lua_pushstring(L, lua_tostring(cache, 1));
        ret = LUA_ERRSYNTAX;
        npop = 1;
        goto error;
    }

    /* return error string in stack */
    if (lua_isnil(cache, 1)) {
        lua_pushstring(L, lua_tostring(cache, 2));
        ret = LUA_ERRSYNTAX;
        goto error;
    }

    s = lua_tolstring(cache, 1, &len);
    if ((ret = luaL_loadbuffer(L, s, len, filename)) != LUA_OK) {
        goto error;
    }

    ret = LUA_OK;
error:
    lua_pop(cache, npop);
    return ret;
}

static int lua_cache_searcher(lua_State *L)
{
    char *data;
    size_t size;
    const char *modname, *paths;
    const char *script;

    modname = lua_tostring(L, -1);

    /* get current package.path */
    lua_getglobal(L, "package");
    lua_getfield(L, -1, "path");
    paths = lua_tostring(L, -1);
    lua_pop(L, 2);

    script = getenv("SCRIPT_FILENAME");

    if (script == NULL)
        script = "<no tag>";

    if (cache_load(L, modname, paths, script) == LUA_OK)
        return 1;

    lua_pop(L, 1); // pop error from stack
    return 0;
}

static int lua_cache_loadfile(lua_State *L)
{
    int nret = 2;
    char *data = NULL;
    size_t size;
    const char *filename;
    const char *script;

    filename = lua_tostring(L, 1);
    // XXX: we are ignoring: mode = lua_tostring(L, 2);

    script = getenv("SCRIPT_FILENAME");

    if (script == NULL)
        script = "<no tag>";

    if (cache_loadfile(L, filename, script) != LUA_OK) {
        /* reorder stack */
        lua_pushnil(L);
        lua_pushvalue(L, -2);
        lua_remove(L, -3);
        goto error;
    }

    nret = 1;
error:
    if (data)
        free(data);

    return nret;
}

int cache_install(lua_State *L)
{
    /* top package.searchers with our cache implementation */
    lua_getglobal(L, "table");
    lua_getfield(L, -1, "insert");
    lua_remove(L, -2);
    lua_getglobal(L, "package");
#if LUA_VERSION_NUM < 502
    lua_getfield(L, -1, "loaders");
#else
    lua_getfield(L, -1, "searchers");
#endif
    lua_remove(L, -2);
    lua_pushinteger(L, 2); // let preload be first
    lua_pushcfunction(L, lua_cache_searcher);
    lua_call(L, 3, 0);

    /* override loadfile() with our cache implementation */
    lua_pushcfunction(L, lua_cache_loadfile);
    lua_setglobal(L, "loadfile");
}

void cache_gc(int timeout)
{
    if (!cache) return;

    lua_getglobal(cache, "cache");
    lua_getfield(cache, -1, "gc");
    lua_remove(cache, -2);
    lua_pushinteger(cache, timeout);
    lua_call(cache, 1, 0);
}

void cache_free()
{
    if (cache) {
        lua_close(cache);
        cache = NULL;
    }
}

#endif
