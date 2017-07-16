#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdint.h>
#include <getopt.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define NO_FCGI_DEFINES
#include <fcgi_stdio.h>

#ifndef LUA_OK
#define LUA_OK 0
#endif

/* redir.c */
void redir_install(lua_State *L);

#include "config.h"
#include "cache.h"

static void *l_alloc (void *memory_limit, void *ptr, size_t osize, size_t nsize)
{
    (void)(osize);

    if (nsize == 0) {
	free(ptr);
	return NULL;
    } else if (nsize > (size_t)memory_limit) {
        return NULL;
    }

    return realloc(ptr, nsize);
}

int forkme(int nforks)
{
    while (nforks--) {
        pid_t pid = fork();

        if (pid == 0) {
            int fd_null = open("/dev/null", O_RDWR);

            dup2(fd_null, 1);
            dup2(fd_null, 2);

            for (int i = 3; i <= fd_null; i++)
                close(i);

            return 0;
        } else {
            fprintf(stdout, "lwp-cgi[%d] Worker spawned.\n", pid);
        }
    }

    close(0);

    return 1;
}

int main(int argc, char **argv)
{
    lua_State *L = NULL;
    int debug = 0;
    intptr_t memory_limit = 64 * 1024 * 1024;
    int reuse = 0, nreq = 0;
    int nforks = 0;

    const char *bootstrap_path = NULL;

    int c;

    /* parse options */
    while ((c = getopt(argc, argv, "dm:r:F:")) >= 0) {
        switch (c) {
            case 'd':
                debug = 1;
                break;

            case 'm':
                memory_limit = strtol(optarg, NULL, 10) * 1024 * 1024;
                break;

            case 'r':
                reuse = strtol(optarg, NULL, 10);
                break;

            case 'F':
                nforks = strtol(optarg, NULL, 10);
                if (nforks > 64) nforks = 64;
                if (nforks < 0) nforks = 0;
                break;

            case '?':
            default:
                break;
        }
    }

    if (nforks > 0) {
        if (forkme(nforks)) {
            return 0;
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
            if (memory_limit > 0) {
                L = lua_newstate(l_alloc, (void *)memory_limit);
            } else {
                L = luaL_newstate();
            }

            if (!L) {
                fprintf(stderr, "Failed to initialize Lua, aborting\n");
                break;
            }

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
        }

        /* preload bootstrap script */
        if (bootstrap_path) {
            if (cache_loadfile(L, bootstrap_path, "") != LUA_OK) {
                fprintf(stderr, "Loading bootstrap failed: %s\n", lua_tostring(L, 1));
                break;
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
            if (lua_isstring(L, 1)) {
                FCGI_fprintf(FCGI_stderr, "%s\n", lua_tostring(L, 1));
            } else {
                FCGI_fprintf(FCGI_stderr, "Script call failed badly, what do?\n");
            }

            /* always close state if we get an error (could be OOM) */
            lua_close(L);
            L = NULL;
        }
next:
        nreq++;

        /* flush FCGI request */
        FCGI_Finish();

        if (nreq > reuse && reuse != -1 && L) {
            fprintf(stderr, "throwing away state\n");
            /* free state in-between requests */
            lua_close(L);
            L = NULL;
            nreq = 0;
        }
    }

    if (L) lua_close(L);

#ifdef WITH_CACHE
    cache_free();
#endif

    return 0;
}
