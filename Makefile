CC          ?= cc
LUA         ?= lua
LUAC        ?= luac
OUTPUT       = lwp-cgi
OBJS         = main.o redir.o cache.o
CFLAGS      ?= -O3
CFLAGS      += $(shell pkg-config --cflags lua)
LIBS        += $(shell pkg-config --libs lua) -lfcgi

all: lwp-cgi

%.luac: %.lua
	$(LUAC) -o $@ $<

%.luac.h: %.luac
	$(LUA) xxd.lua $(basename $(basename $@))_lua > $@ < $<

redir.o: redir.c redir.luac.h
cache.o: cache.c cache.luac.h lwp.luac.h

lwp-cgi: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $? $(LIBS)

all: lwp-cgi

clean:
	rm -f $(OUTPUT) $(OBJS) *.luac *.luac.h
