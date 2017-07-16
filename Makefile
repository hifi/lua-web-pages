CC          ?= cc
LUA         ?= lua
LUAC        ?= luac
OUTPUT       = lwp-cgi
OBJS         = src/main.o src/redir.o src/cache.o
CFLAGS      ?= -g -O3 -I. -std=c99 -Wall -Wextra -pedantic
CFLAGS      += $(shell pkg-config --cflags lua)
LIBS        += $(shell pkg-config --libs lua) -lfcgi
PREFIX      ?= /usr/local

# TODO: will be updated once there's a version tag
GIT_VERSION  = 0.0.0
GIT_REVISION = $(shell git rev-list --count HEAD)
GIT_COMMIT   = $(shell git rev-parse --short HEAD)
BUILD_DATE   = $(shell date '+%a %b %d %Y')
BUILD_VERSION= $(GIT_VERSION)-$(GIT_REVISION)-$(GIT_COMMIT)

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

dist: lua-web-pages-$(BUILD_VERSION).tar.gz

lua-web-pages-$(BUILD_VERSION).tar.gz:
	git archive HEAD --prefix=lua-web-pages-$(BUILD_VERSION)/ -o lua-web-pages-$(BUILD_VERSION).tar.gz

lua-web-pages.spec: lua-web-pages.spec.in
	sed -e 's%@VERSION@%$(GIT_VERSION)%g' \
	    -e 's%@REVISION@%$(GIT_REVISION)%g' \
	    -e 's%@COMMIT@%$(GIT_COMMIT)%g' \
	    -e 's%@DATE@%$(BUILD_DATE)%g' \
            $< > $@

srpm: lua-web-pages-$(BUILD_VERSION).src.rpm

lua-web-pages-$(BUILD_VERSION).src.rpm: lua-web-pages-$(BUILD_VERSION).tar.gz lua-web-pages.spec
	rpmbuild --undefine dist -D'_sourcedir $(shell pwd)' -D'_srcrpmdir $(shell pwd)' -bs lua-web-pages.spec

install: etc/lwp-httpd.service
	install -D -m 0644 cgi.lua $(DESTDIR)$(PREFIX)/share/lua-web-pages/cgi.lua
	install -D -m 0755 lwp-cgi $(DESTDIR)$(PREFIX)/bin/lwp-cgi
	install -D -m 0644 etc/lwp-httpd.socket $(DESTDIR)$(PREFIX)/lib/systemd/system/lwp-httpd.socket
	install -D -m 0644 etc/lwp-httpd.service $(DESTDIR)$(PREFIX)/lib/systemd/system/lwp-httpd.service

clean:
	rm -f $(OUTPUT) $(OBJS) src/*.luac src/*.luac.h etc/lwp-httpd.service lua-web-pages.spec
