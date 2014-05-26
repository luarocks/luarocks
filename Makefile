
include config.unix

.PHONY: all build dev build_bins luadoc check_makefile cleanup_bins clean \
 install_bins install_luas install_site_config write_sysconfig \
 install bootstrap install_rock

DESTDIR =
PREFIX ?= /usr/local
ROCKS_TREE ?= $(PREFIX)
SYSCONFDIR ?= $(PREFIX)/etc/luarocks
BINDIR ?= $(PREFIX)/bin
LUADIR ?= $(PREFIX)/share/lua/$(LUA_VERSION)/
LUA_DIR ?= /usr/local
LUA_BINDIR ?= $(LUA_DIR)/bin

BIN_FILES = luarocks luarocks-admin
LUAROCKS_FILES = fs/unix/tools.lua fs/unix.lua fs/win32/tools.lua fs/win32.lua \
fs/lua.lua persist.lua list.lua require.lua repos.lua dir.lua make_manifest.lua \
command_line.lua install.lua build/command.lua build/cmake.lua build/make.lua \
build/builtin.lua fetch/cvs.lua fetch/git.lua fetch/sscm.lua tools/patch.lua \
fetch/svn.lua tools/zip.lua tools/tar.lua pack.lua type_check.lua make.lua \
remove.lua fs.lua manif.lua add.lua deps.lua build.lua search.lua show.lua \
manif_core.lua fetch.lua unpack.lua validate.lua cfg.lua download.lua \
help.lua util.lua index.lua cache.lua refresh_cache.lua loader.lua \
admin_remove.lua fetch/hg.lua fetch/git_file.lua new_version.lua lint.lua \
purge.lua path.lua path_cmd.lua write_rockspec.lua doc.lua upload.lua \
upload/api.lua upload/multipart.lua fetch/git_http.lua

CONFIG_FILE = $(SYSCONFDIR)/config-$(LUA_VERSION).lua

SAFEPWD=`echo "$$PWD" | sed -e 's/\([][]\)\1/]]..'\''\1\1'\''..[[/g'`

all: 
	@echo "- Type 'make build' and 'make install':"
	@echo "  to install to $(PREFIX) as usual."
	@echo "- Type 'make bootstrap':"
	@echo "  to install LuaRocks in $(PREFIX) as a rock."
	@echo

build: src/luarocks/site_config.lua build_bins
	@echo
	@echo "Done. Type 'make install' to install into $(PREFIX)."
	@echo

src/luarocks/site_config.lua: config.unix
	rm -f src/luarocks/site_config.lua
	echo 'local site_config = {}' >> src/luarocks/site_config.lua
	if [ -n "$(PREFIX)" ] ;\
	then \
	   echo "site_config.LUAROCKS_PREFIX=[[$(PREFIX)]]" >> src/luarocks/site_config.lua ;\
	fi
	if [ -n "$(LUA_INCDIR)" ] ;\
	then \
	   echo "site_config.LUA_INCDIR=[[$(LUA_INCDIR)]]" >> src/luarocks/site_config.lua ;\
	fi
	if [ -n "$(LUA_LIBDIR)" ] ;\
	then \
	   echo "site_config.LUA_LIBDIR=[[$(LUA_LIBDIR)]]" >> src/luarocks/site_config.lua ;\
	fi
	if [ -n "$(LUA_BINDIR)" ] ;\
	then \
	   echo "site_config.LUA_BINDIR=[[$(LUA_BINDIR)]]" >> src/luarocks/site_config.lua ;\
	fi
	if [ -n "$(LUA_SUFFIX)" ] ;\
	then \
	   echo "site_config.LUA_INTERPRETER=[[lua$(LUA_SUFFIX)]]" >> src/luarocks/site_config.lua ;\
	fi
	if [ -n "$(SYSCONFDIR)" ] ;\
	then \
	   echo "site_config.LUAROCKS_SYSCONFDIR=[[$(SYSCONFDIR)]]" >> src/luarocks/site_config.lua ;\
	fi
	if [ -n "$(ROCKS_TREE)" ] ;\
	then \
	   echo "site_config.LUAROCKS_ROCKS_TREE=[[$(ROCKS_TREE)]]" >> src/luarocks/site_config.lua ;\
	fi
	if [ -n "$(FORCE_CONFIG)" ] ;\
	then \
	   echo "site_config.LUAROCKS_FORCE_CONFIG=true" >> src/luarocks/site_config.lua ;\
	fi
	if [ -n "$(LUAROCKS_ROCKS_SUBDIR)" ] ;\
	then \
	   echo "site_config.LUAROCKS_ROCKS_SUBDIR=[[$(LUAROCKS_ROCKS_SUBDIR)]]" >> src/luarocks/site_config.lua ;\
	fi
	if [ "$(LUA_DIR_SET)" = "yes" ] ;\
	then \
	   echo "site_config.LUA_DIR_SET=true" >> src/luarocks/site_config.lua ;\
	fi
	echo "site_config.LUAROCKS_UNAME_S=[[$(LUAROCKS_UNAME_S)]]" >> src/luarocks/site_config.lua
	echo "site_config.LUAROCKS_UNAME_M=[[$(LUAROCKS_UNAME_M)]]" >> src/luarocks/site_config.lua
	echo "site_config.LUAROCKS_DOWNLOADER=[[$(LUAROCKS_DOWNLOADER)]]" >> src/luarocks/site_config.lua
	echo "site_config.LUAROCKS_MD5CHECKER=[[$(LUAROCKS_MD5CHECKER)]]" >> src/luarocks/site_config.lua
	if [ -n "$(MULTIARCH_SUBDIR)" ] ;\
	then \
	   echo 'site_config.LUAROCKS_EXTERNAL_DEPS_SUBDIRS={ bin="bin", lib={ "lib", [[$(MULTIARCH_SUBDIR)]] }, include="include" }' >> src/luarocks/site_config.lua ;\
	   echo 'site_config.LUAROCKS_RUNTIME_EXTERNAL_DEPS_SUBDIRS={ bin="bin", lib={ "lib", [[$(MULTIARCH_SUBDIR)]] }, include="include" }' >> src/luarocks/site_config.lua ;\
	fi
	echo "return site_config" >> src/luarocks/site_config.lua

dev:
	$(MAKE) build_bins LUADIR=$(PWD)/src

build_bins: cleanup_bins
	for f in $(BIN_FILES) ;\
	do \
	   sed "1d" src/bin/$$f > src/bin/$$f.bak ;\
	   echo "#!$(LUA_BINDIR)/lua$(LUA_SUFFIX)" > src/bin/$$f ;\
	   echo "package.path = [[$(LUADIR)/?.lua;]]..package.path" | sed "s,//,/,g" >> src/bin/$$f ;\
	   cat src/bin/$$f.bak >> src/bin/$$f ;\
	   chmod +x src/bin/$$f ;\
	   rm -f src/bin/$$f.bak ;\
	done

luadoc:
	rm -rf doc/luadoc
	mkdir -p doc/luadoc
	cd src && luadoc -d ../doc/luadoc --nofiles luarocks/*.lua

check_makefile: clean
	echo $(BIN_FILES) | tr " " "\n" | sort > makefile_list.txt
	( cd src/bin && ls -d * ) | sort > luarocks_dir.txt
	echo $(LUAROCKS_FILES) | tr " " "\n" | sort >> makefile_list.txt
	( cd src/luarocks && find * -name "*.lua" ) | sort >> luarocks_dir.txt
	diff makefile_list.txt luarocks_dir.txt
	rm -f makefile_list.txt luarocks_dir.txt
	@echo
	@echo "Makefile is sane."
	@echo

cleanup_bins:
	for f in $(BIN_FILES) ;\
	do \
	   mv src/bin/$$f src/bin/$$f.bak ;\
	   sed "s,^#!.*lua.*,#!/usr/bin/env lua,;/^package.path/d" < src/bin/$$f.bak > src/bin/$$f ;\
	   chmod +x src/bin/$$f ;\
	   rm -f src/bin/$$f.bak ;\
	done

clean: cleanup_bins
	rm -f src/luarocks/site_config.lua

install_bins:
	mkdir -p "$(DESTDIR)$(BINDIR)"
	cd src/bin && for f in $(BIN_FILES); \
	do \
	   cp "$$f" "$(DESTDIR)$(BINDIR)/$$f-$(LUA_VERSION)"; \
	   ln -nfs "$$f-$(LUA_VERSION)" "$(DESTDIR)$(BINDIR)/$$f"; \
	done

install_luas:
	mkdir -p "$(DESTDIR)$(LUADIR)/luarocks"
	cd src/luarocks && for f in $(LUAROCKS_FILES); \
	do \
	   d="$(DESTDIR)$(LUADIR)/luarocks"/`dirname "$$f"` && \
	   mkdir -p "$$d" && \
	   cp "$$f" "$$d" || exit 1; \
	done

install_site_config: src/luarocks/site_config.lua
	mkdir -p "$(DESTDIR)$(LUADIR)/luarocks"
	cp src/luarocks/site_config.lua "$(DESTDIR)$(LUADIR)/luarocks"

write_sysconfig:
	mkdir -p "$(DESTDIR)$(ROCKS_TREE)"
	if [ ! -f "$(DESTDIR)$(CONFIG_FILE)" ] ;\
	then \
	   mkdir -p `dirname "$(DESTDIR)$(CONFIG_FILE)"` ;\
	   echo 'rocks_trees = {' >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	   if  [ ! -n "$(FORCE_CONFIG)" ] ;\
	   then \
	      echo '   { name = [[user]], root = home..[[/.luarocks]] },' >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	   fi ;\
	   echo '   { name = [[system]], root = [[$(ROCKS_TREE)]] }' >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	   echo '}' >> "$(DESTDIR)$(CONFIG_FILE)" ;\
	fi

install: install_bins install_luas install_site_config write_sysconfig

bootstrap: src/luarocks/site_config.lua install_site_config write_sysconfig cleanup_bins
	'$(LUA_BINDIR)/lua$(LUA_SUFFIX)' -e "package.path=[[$(SAFEPWD)/src/?.lua;]]..package.path" src/bin/luarocks make rockspec --tree="$(PREFIX)"

install_rock: install_bins install_luas
