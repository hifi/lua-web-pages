CC          ?= cc
LUA         ?= lua
LUAC        ?= luac
OUTPUT       = lwp-cgi
OBJS         = src/main.o src/redir.o src/cache.o
CFLAGS      ?= -g -O3 -I. -std=c99 -Wall -Wextra -pedantic
CFLAGS      += $(shell pkg-config --cflags lua)
LIBS        += $(shell pkg-config --libs lua) -lfcgi
PREFIX      ?= /usr/local

all: lwp-cgi

%.luac: %.lua
	$(LUAC) -o $@ $<

%.luac.h: %.luac
	$(LUA) xxd.lua $(basename $(basename $@))_lua > $@ < $<

src/redir.o: src/redir.c src/redir.luac.h
src/cache.o: src/cache.c src/cache.luac.h src/lwp.luac.h

etc/lwp-httpd.service: etc/lwp-httpd.service.in
	sed s%@PREFIX@%$(PREFIX)%g $< > $@

lwp-cgi: $(OBJS)
	$(CC) $(CFLAGS) -o $@ $? $(LIBS)

all: lwp-cgi

install: etc/lwp-httpd.service
	install -D -m 0644 cgi.lua $(DESTDIR)$(PREFIX)/share/lua-web-pages/cgi.lua
	install -D -m 0755 lwp-cgi $(DESTDIR)$(PREFIX)/bin/lwp-cgi
	install -D -m 0644 etc/lwp-httpd.socket $(DESTDIR)$(PREFIX)/lib/systemd/system/lwp-httpd.socket
	install -D -m 0644 etc/lwp-httpd.service $(DESTDIR)$(PREFIX)/lib/systemd/system/lwp-httpd.service

clean:
	rm -f $(OUTPUT) $(OBJS) src/*.luac src/*.luac.h etc/lwp-httpd.service
