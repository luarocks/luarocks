# $Id: Makefile,v 1.30 2008/08/18 14:07:35 hisham Exp $

include config.unix

DESTDIR =
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LUADIR ?= $(PREFIX)/share/lua/5.1/
LUA_DIR ?= /usr/local
LUA_BINDIR ?= $(LUA_DIR)/bin

BIN_FILES = luarocks luarocks-admin
SRC_FILES = luarocks.lua
LUAROCKS_FILES = build/cmake.lua build/command.lua build.lua build/make.lua \
command_line.lua cfg.lua deps.lua fetch.lua fs.lua fs/unix.lua fs/lua.lua \
fs/win32.lua fs/unix/tools.lua fs/win32/tools.lua help.lua install.lua list.lua persist.lua dir.lua \
make_manifest.lua pack.lua path.lua rep.lua require.lua search.lua validate.lua \
type_check.lua util.lua remove.lua build/builtin.lua make.lua manif.lua manif_core.lua unpack.lua \
fetch/cvs.lua fetch/sscm.lua fetch/git.lua tools/zip.lua tools/tar.lua tools/patch.lua

CONFIG_FILE = $(SYSCONFDIR)/config.lua

all:
	for f in $(BIN_FILES) ;\
	do \
	   sed "1d" src/bin/$$f >> src/bin/$$f.bak ;\
	   echo "#!$(LUA_BINDIR)/lua$(LUA_SUFFIX)" > src/bin/$$f ;\
	   echo "package.path = [[$(LUADIR)/?.lua;$(LUADIR)/?/init.lua;]]..package.path" >> src/bin/$$f ;\
	   cat src/bin/$$f.bak >> src/bin/$$f ;\
	   rm src/bin/$$f.bak ;\
	done
	cp src/luarocks/cfg.lua src/luarocks/cfg.lua.bak
	rm src/luarocks/cfg.lua
	if [ -n "$(PREFIX)" ] ;\
	then \
	   echo "local LUAROCKS_PREFIX=[[$(PREFIX)]]" >> src/luarocks/cfg.lua ;\
	fi
	if [ -n "$(LUA_INCDIR)" ] ;\
	then \
	   echo "local LUA_INCDIR=[[$(LUA_INCDIR)]]" >> src/luarocks/cfg.lua ;\
	fi
	if [ -n "$(LUA_LIBDIR)" ] ;\
	then \
	   echo "local LUA_LIBDIR=[[$(LUA_LIBDIR)]]" >> src/luarocks/cfg.lua ;\
	fi
	if [ -n "$(LUA_BINDIR)" ] ;\
	then \
	   echo "local LUA_BINDIR=[[$(LUA_BINDIR)]]" >> src/luarocks/cfg.lua ;\
	fi
	if [ -n "$(LUA_SUFFIX)" ] ;\
	then \
	   echo "local LUA_INTERPRETER=[[lua$(LUA_SUFFIX)]]" >> src/luarocks/cfg.lua ;\
	fi
	if [ -n "$(SYSCONFDIR)" ] ;\
	then \
	   echo "local LUAROCKS_SYSCONFIG=[[$(SYSCONFDIR)/config.lua]]" >> src/luarocks/cfg.lua ;\
	fi
	if [ -n "$(ROCKS_TREE)" ] ;\
	then \
	   echo "local LUAROCKS_ROCKS_TREE=[[$(ROCKS_TREE)]]" >> src/luarocks/cfg.lua ;\
	fi
	if [ -n "$(FORCE_CONFIG)" ] ;\
	then \
	   echo "local LUAROCKS_FORCE_CONFIG=true" >> src/luarocks/cfg.lua ;\
	fi
	echo "local LUAROCKS_UNAME_S=[[$(LUAROCKS_UNAME_S)]]" >> src/luarocks/cfg.lua
	echo "local LUAROCKS_UNAME_M=[[$(LUAROCKS_UNAME_M)]]" >> src/luarocks/cfg.lua
	echo "local LUAROCKS_DOWNLOADER=[[$(LUAROCKS_DOWNLOADER)]]" >> src/luarocks/cfg.lua
	echo "local LUAROCKS_MD5CHECKER=[[$(LUAROCKS_MD5CHECKER)]]" >> src/luarocks/cfg.lua
	cat src/luarocks/cfg.lua.bak >> src/luarocks/cfg.lua
	rm src/luarocks/cfg.lua.bak
	@echo
	@echo "Done. Type 'make install' to install into $(PREFIX)."
	@echo

luadoc:
	rm -rf doc/luadoc
	mkdir -p doc/luadoc
	cd src && luadoc -d ../doc/luadoc --nofiles luarocks/*.lua

check_makefile:
	echo $(BIN_FILES) | tr " " "\n" | sort > makefile_list.txt
	( cd src/bin && ls -d * ) | grep -v "CVS" | sort > luarocks_dir.txt
	echo $(LUAROCKS_FILES) | tr " " "\n" | sort >> makefile_list.txt
	( cd src/luarocks && find * -name "*.lua" ) | sort >> luarocks_dir.txt
	echo $(SRC_FILES) | tr " " "\n" | sort >> makefile_list.txt
	( cd src && ls -d *.lua ) | sort >> luarocks_dir.txt
	diff makefile_list.txt luarocks_dir.txt
	rm makefile_list.txt luarocks_dir.txt
	@echo
	@echo "Makefile is sane."
	@echo

clean:
	for f in $(BIN_FILES) ;\
	do \
	   sed -i.bak "s,^#!.*lua.*,#!/usr/bin/env lua,;/^package.path/d" src/bin/$$f ;\
	   rm src/bin/$$f.bak ;\
	done
	sed -i.bak "/^local LUA/d" src/luarocks/cfg.lua
	rm src/luarocks/cfg.lua.bak

install:
	mkdir -p "$(DESTDIR)$(BINDIR)"
	cd src/bin && cp $(BIN_FILES) "$(DESTDIR)$(BINDIR)"
	mkdir -p "$(DESTDIR)$(LUADIR)"
	cd src && cp $(SRC_FILES) "$(DESTDIR)$(LUADIR)"
	mkdir -p "$(DESTDIR)$(LUADIR)/luarocks"
	cd src/luarocks && for f in $(LUAROCKS_FILES); do d="$(DESTDIR)$(LUADIR)/luarocks"/`dirname "$$f"`; mkdir -p "$$d"; cp "$$f" "$$d"; done
	mkdir -p "$(DESTDIR)$(ROCKS_TREE)"
	if [ ! -f "$(DESTDIR)$(CONFIG_FILE)" ] ;\
	then \
	   mkdir -p `dirname "$(DESTDIR)$(CONFIG_FILE)"` ;\
	   echo 'rocks_servers = {' >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	   echo '   [[http://luarocks.luaforge.net/rocks]]' >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	   echo '}' >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	   echo 'rocks_trees = {' >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	   if  [ ! -n "$(FORCE_CONFIG)" ] ;\
	   then \
	      echo '   home..[[/.luarocks]],' >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	   fi ;\
	   echo '   [[$(ROCKS_TREE)]]' >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	   echo '}' >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	   if [ -n "$(SCRIPTS_DIR)" ] ;\
	   then \
	      echo "scripts_dir = [[$(SCRIPTS_DIR)]]" >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	   fi ;\
	fi
