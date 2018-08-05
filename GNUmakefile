
-include config.unix

# See https://www.gnu.org/software/make/manual/html_node/Makefile-Conventions.html
prefix ?= /usr/local
datarootdir ?= $(prefix)/share
bindir ?= $(prefix)/bin
sysconfdir ?= $(prefix)/etc
INSTALL ?= install
INSTALL_DATA ?= $(INSTALL) -m 644

LUA_INTERPRETER ?= lua
ifdef LUA_BINDIR
LUA = $(LUA_BINDIR)/$(LUA_INTERPRETER)
SHEBANG = \#!$(LUA_BINDIR)/$(LUA_INTERPRETER)
else
LUA = $(LUA_INTERPRETER)
SHEBANG = \#!/usr/bin/env $(LUA_INTERPRETER)
endif
LUA_VERSION ?= $(shell $(LUA) -e 'print(_VERSION:match(" (5%.[1234])$$"))')
rocks_tree ?= $(prefix)
luarocksconfdir ?= $(sysconfdir)/luarocks
luadir ?= $(datarootdir)/lua/$(LUA_VERSION)


LUAROCKS_FILES = $(shell find src/luarocks/ -type f -name '*.lua')

all: build

# ----------------------------------------
# Base build
# ----------------------------------------

build: luarocks luarocks-admin ./build/luarocks ./build/luarocks-admin

config.unix:
	@echo Please run the "./configure" script before building.
	@echo
	@exit 1

config-$(LUA_VERSION).lua.in: config.unix
	@printf -- '-- LuaRocks configuration\n\n'\
	'rocks_trees = {\n'\
	'   { name = "user", root = home .. "/.luarocks" };\n'\
	'   { name = "system", root = "'"$(rocks_tree)"'" };\n'\
	'}\n'\
	"$$([ -n "$(LUA_INTERPRETER)" ] && printf 'lua_interpreter = "%s";\\n' "$(LUA_INTERPRETER)")"\
	'variables = {\n'\
	"$$([ -n "$(LUA_DIR)" ] && printf '   LUA_DIR = "%s";\\n' "$(LUA_DIR)")"\
	"$$([ -n "$(LUA_INCDIR)" ] && printf '   LUA_INCDIR = "%s";\\n' "$(LUA_INCDIR)")"\
	"$$([ -n "$(LUA_BINDIR)" ] && printf '   LUA_BINDIR = "%s";\\n' "$(LUA_BINDIR)")"\
	"$$([ -n "$(LUA_LIBDIR)" ] && printf '   LUA_LIBDIR = "%s";\\n' "$(LUA_LIBDIR)")"\
	'}\n'\
	> $@

luarocks: config.unix config-$(LUA_VERSION).lua.in
	rm -f src/luarocks/core/hardcoded.lua
	echo "#!/bin/sh" > luarocks
	echo "unset LUA_PATH LUA_PATH_5_2 LUA_PATH_5_3 LUA_PATH_5_4" >> luarocks
	echo 'LUAROCKS_SYSCONFDIR="$(luarocksconfdir)" LUA_PATH="$(CURDIR)/src/?.lua;;" exec "$(LUA)" "$(CURDIR)/src/bin/luarocks" --project-tree="$(CURDIR)/lua_modules" "$$@"' >> luarocks
	chmod +rx ./luarocks
	./luarocks init
	cp config-$(LUA_VERSION).lua.in .luarocks/config-$(LUA_VERSION).lua

luarocks-admin: config.unix
	rm -f src/luarocks/core/hardcoded.lua
	echo "#!/bin/sh" > luarocks-admin
	echo "unset LUA_PATH LUA_PATH_5_2 LUA_PATH_5_3 LUA_PATH_5_4" >> luarocks-admin
	echo 'LUAROCKS_SYSCONFDIR="$(luarocksconfdir)" LUA_PATH="$(CURDIR)/src/?.lua;;" exec "$(LUA)" "$(CURDIR)/src/bin/luarocks-admin" --project-tree="$(CURDIR)/lua_modules" "$$@"' >> luarocks-admin
	chmod +rx ./luarocks-admin

./build/luarocks: src/bin/luarocks config.unix
	mkdir -p "$(@D)"
	(printf '$(SHEBANG)\n'\
	'package.loaded["luarocks.core.hardcoded"] = { SYSCONFDIR = [[$(luarocksconfdir)]] }\n'\
	'package.path=[[$(luadir)/?.lua;]] .. package.path\n'; \
	tail -n +2 src/bin/luarocks \
	)> "$@"

./build/luarocks-admin: src/bin/luarocks-admin config.unix
	mkdir -p "$(@D)"
	(printf '$(SHEBANG)\n'\
	'package.loaded["luarocks.core.hardcoded"] = { SYSCONFDIR = [[$(luarocksconfdir)]] }\n'\
	'package.path=[[$(luadir)/?.lua;]] .. package.path\n'; \
	tail -n +2 src/bin/luarocks-admin \
	)> "$@"

# ----------------------------------------
# Regular install
# ----------------------------------------

INSTALL_FILES = $(DESTDIR)$(bindir)/luarocks \
	$(DESTDIR)$(bindir)/luarocks-admin \
	$(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua \
	$(patsubst src/%, $(DESTDIR)$(luadir)/%, $(LUAROCKS_FILES))

install: $(INSTALL_FILES)

$(DESTDIR)$(bindir)/luarocks: ./build/luarocks
	$(INSTALL) -D "$<" "$@"

$(DESTDIR)$(bindir)/luarocks-admin: ./build/luarocks-admin
	$(INSTALL) -D "$<" "$@"

$(DESTDIR)$(luadir)/luarocks/%.lua: src/luarocks/%.lua
	$(INSTALL_DATA) -D "$<" "$@"

$(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua: config-$(LUA_VERSION).lua.in
	$(INSTALL_DATA) -D "$<" "$@"

uninstall:
	rm -rf $(INSTALL_FILES)

# ----------------------------------------
# Binary build
# ----------------------------------------

binary: build-binary/luarocks.exe build-binary/luarocks-admin.exe

build-binary/luarocks.exe: luarocks
	(unset $(LUA_ENV_VARS); \
	LUA_PATH="./src/?.lua;;" \
	"$(LUA)" binary/all_in_one "src/bin/luarocks" "$(LUA_DIR)" "^src/luarocks/admin/" "$(luarocksconfdir)" "$(@D)" $(BINARY_PLATFORM) $(BINARY_CC) $(BINARY_NM) $(BINARY_SYSROOT))

build-binary/luarocks-admin.exe: luarocks
	(unset $(LUA_ENV_VARS); \
	LUA_PATH="./src/?.lua;;" \
	"$(LUA)" binary/all_in_one "src/bin/luarocks-admin" "$(LUA_DIR)" "^src/luarocks/cmd/" "$(luarocksconfdir)" "$(@D)" $(BINARY_PLATFORM) $(BINARY_CC) $(BINARY_NM) $(BINARY_SYSROOT))

# ----------------------------------------
# Binary install
# ----------------------------------------

install-binary: build-binary/luarocks.exe build-binary/luarocks-admin.exe
	mkdir -p "$(DESTDIR)$(bindir)"
	cp build-binary/luarocks.exe "$(DESTDIR)$(bindir)/luarocks"
	chmod +rx "$(DESTDIR)$(bindir)/luarocks"
	cp build-binary/luarocks-admin.exe "$(DESTDIR)$(bindir)/luarocks-admin"
	chmod +rx "$(DESTDIR)$(bindir)/luarocks-admin"
	mkdir -p "$(DESTDIR)$(luadir)/luarocks/core"
	cp -a src/luarocks/core/* "$(DESTDIR)$(luadir)/luarocks/core"
	cp -a src/luarocks/loader.lua "$(DESTDIR)$(luadir)/luarocks/"

# ----------------------------------------
# Bootstrap install
# ----------------------------------------

bootstrap: luarocks $(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua
	./luarocks make --tree="$(DESTDIR)$(rocks_tree)"

# ----------------------------------------
# Windows binary build
# ----------------------------------------

windows-binary: luarocks
	$(MAKE) -f binary/Makefile.windows windows-binary

windows-clean:
	$(MAKE) -f binary/Makefile.windows windows-clean

# ----------------------------------------
# Clean
# ----------------------------------------

clean: windows-clean
	rm -rf ./config.unix \
		./luarocks \
		./luarocks-admin \
		./build/ \
		build-binary \
		./.luarocks \
		./lua_modules

.PHONY: all build install binary install-binary bootstrap clean windows-binary windows-clean
