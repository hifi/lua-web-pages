all:
	luac -o - redir.lua | lua xxd.lua redir_lua > redir_lua.h
	luac -o - cache.lua | lua xxd.lua cache_lua > cache_lua.h
	luac -o - lwp.lua | lua xxd.lua lwp_lua > lwp_lua.h
	gcc -Ofast -o lua-simple-fcgi main.c redir.c cache.c -llua -lfcgi

clean:
	rm -f redir_lua.h cache_lua.h lwp_lua.h lua-simple-fcgi
