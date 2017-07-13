#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

#ifdef WITH_CACHE
    int cache_init();
    int cache_install(lua_State *L);
    int cache_loadfile(lua_State *L, const char *filename, const char *tag);
    void cache_gc(int timeout);
    void cache_free();
#else
    #define cache_loadfile(L,f,t) luaL_loadfile(L,f)
#endif
