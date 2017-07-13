#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <stdlib.h>

#define NO_FCGI_DEFINES
#include <fcgi_stdio.h>

#ifndef LUA_OK
#define LUA_OK 0
#endif

/* redir.c */
void redir_install(lua_State *L);

#include "config.h"
#include "cache.h"

int main(int argc, char **argv)
{
    lua_State *L = NULL;
    int debug = 0;
    int reuse = 0;
    const char *bootstrap_path = NULL;

    int c;

    /* parse options */
    while ((c = getopt(argc, argv, "dr:")) >= 0) {
        switch (c) {
            case 'd':
                debug = 1;
                break;

            case 'r':
                reuse = strtol(optarg, NULL, 10);
                break;

            case '?':
            default:
                break;
        }
    }

#ifdef WITH_CACHE
    time_t now, last_gc = 0;
    
    /* initialize cache */
    cache_init();
#endif

    if (optind < argc) {
        bootstrap_path = argv[optind];
    }

    while (1) {
        if (!L) {
            L = luaL_newstate();
            luaL_openlibs(L);

#ifdef WITH_CACHE
            /* run gc every minute if we happen to get a request */
            now = time(NULL);
            if (last_gc + 60 < now || debug) {
                cache_gc(-1);
                last_gc = now;
            }

            /* install bytecode cache */
            cache_install(L);
#endif

            /* install I/O redirection */
            redir_install(L);

            /* preload bootstrap script */
            if (bootstrap_path) {
                if (cache_loadfile(L, bootstrap_path, "") != LUA_OK) {
                    fprintf(stderr, "Loading bootstrap failed: %s\n", lua_tostring(L, 1));
                    break;
                }
            }
        }

        /* accept request */
        if (FCGI_Accept() < 0)
            break;

        /* execute target script directly if no bootstrap script */
        if (!bootstrap_path) {
            const char *script_filename = getenv("SCRIPT_FILENAME");

            if (!script_filename) {
                FCGI_printf("Status: 500 Internal Server Error\r\nContent-type: text/plain\r\n\r\n500 - Internal Server Error\r\n\r\nSee server error logs for more information.\r\n");
                FCGI_fprintf(FCGI_stderr, "SCRIPT_FILENAME is empty.\n");
                goto next;
            }

            if (cache_loadfile(L, script_filename, "") != LUA_OK) {
                FCGI_printf("Status: 500 Internal Server Error\r\nContent-type: text/plain\r\n\r\n500 - Internal Server Error\r\n\r\nSee server error logs for more information.\r\n");
                FCGI_fprintf(FCGI_stderr, "Failed to load script '%s' from SCRIPT_FILENAME: %s\n", script_filename, lua_tostring(L, 1));
                goto next;
            }
        }

        /* exec handler (bootstrap or script) */
        if (lua_pcall(L, 0, 0, 0) != LUA_OK) {
            FCGI_fprintf(FCGI_stderr, "%s\n", lua_tostring(L, 1));
        }
next:
        /* flush FCGI request */
        FCGI_Finish();

        // XXX: should be number of requests to process until throwing away the state
        if (!reuse) {
            /* free state in-between requests */
            lua_close(L);
            L = NULL;
        }
    }

    lua_close(L);

#ifdef WITH_CACHE
    cache_free();
#endif

    return 0;
}
