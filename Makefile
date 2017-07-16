CC          ?= cc
LUA         ?= lua
LUAC        ?= luac
OUTPUT       = lwp-cgi
OBJS         = src/main.o src/redir.o src/cache.o
CFLAGS      ?= -O3 -I. -std=c99 -Wall -Wextra -pedantic
CFLAGS      += $(shell pkg-config --cflags lua)
LIBS        += $(shell pkg-config --libs lua) -lfcgi

all: lwp-cgi

%.luac: %.lua
	$(LUAC) -o $@ $<

%.luac.h: %.luac
	$(LUA) xxd.lua $(basename $(basename $@))_lua > $@ < $<

src/redir.o: src/redir.c src/redir.luac.h
src/cache.o: src/cache.c src/cache.luac.h src/lwp.luac.h

lwp-cgi: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $? $(LIBS)

all: lwp-cgi

clean:
	rm -f $(OUTPUT) $(OBJS) src/*.luac src/*.luac.h
