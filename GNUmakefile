
-include config.unix

LUA_ENV_VARS = LUA_INIT LUA_PATH LUA_PATH_5_2 LUA_PATH_5_3 LUA_PATH_5_4 LUA_CPATH LUA_CPATH_5_2 LUA_CPATH_5_3 LUA_CPATH_5_4

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
LUA_VERSION ?= $(shell unset $(LUA_ENV_VARS); $(LUA) -e 'print(_VERSION:match(" (5%.[1234])$$"))')
rocks_tree ?= $(prefix)
luarocksconfdir ?= $(sysconfdir)/luarocks
luadir ?= $(datarootdir)/lua/$(LUA_VERSION)


LUAROCKS_FILES = $(shell find src/luarocks/ -type f -name '*.lua')

all: build

# ----------------------------------------
# Base build
# ----------------------------------------

build: ./build/luarocks ./build/luarocks-admin

./build/config-$(LUA_VERSION).lua:
	mkdir -p "$(@D)"
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

ifneq ($(BUILD_TYPE),binary)

./build/luarocks: src/bin/luarocks
	mkdir -p "$(@D)"
	(printf '$(SHEBANG)\n'\
	'package.loaded["luarocks.core.hardcoded"] = { SYSCONFDIR = [[$(luarocksconfdir)]] }\n'\
	'package.path=[[$(luadir)/?.lua;]] .. package.path\n'; \
	tail -n +2 src/bin/luarocks \
	)> "$@"

./build/luarocks-admin: src/bin/luarocks-admin
	mkdir -p "$(@D)"
	(printf '$(SHEBANG)\n'\
	'package.loaded["luarocks.core.hardcoded"] = { SYSCONFDIR = [[$(luarocksconfdir)]] }\n'\
	'package.path=[[$(luadir)/?.lua;]] .. package.path\n'; \
	tail -n +2 src/bin/luarocks-admin \
	)> "$@"

else

./build/luarocks: src/bin/luarocks $(LUAROCKS_FILES)
	(unset $(LUA_ENV_VARS); \
	"$(LUA)" binary/all_in_one "$<" "$(LUA_DIR)" "^src/luarocks/admin/" "$(luarocksconfdir)" "$(@D)" $(BINARY_PLATFORM) $(CC) $(NM) $(SYSROOT))

./build/luarocks-admin: src/bin/luarocks-admin $(LUAROCKS_FILES)
	(unset $(LUA_ENV_VARS); \
	"$(LUA)" binary/all_in_one "$<" "$(LUA_DIR)" "^src/luarocks/cmd/" "$(luarocksconfdir)" "$(@D)" $(BINARY_PLATFORM) $(CC) $(NM) $(SYSROOT))

endif

# ----------------------------------------
# Regular install
# ----------------------------------------

INSTALL_FILES = $(DESTDIR)$(bindir)/luarocks \
	$(DESTDIR)$(bindir)/luarocks-admin \
	$(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua \
	$(patsubst src/%, $(DESTDIR)$(luadir)/%, $(LUAROCKS_FILES))

install: $(INSTALL_FILES)

install-config: $(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua

$(DESTDIR)$(bindir)/luarocks: ./build/luarocks
	$(INSTALL) -D "$<" "$@"

$(DESTDIR)$(bindir)/luarocks-admin: ./build/luarocks-admin
	$(INSTALL) -D "$<" "$@"

$(DESTDIR)$(luadir)/luarocks/%.lua: src/luarocks/%.lua
	$(INSTALL_DATA) -D "$<" "$@"

$(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua: ./build/config-$(LUA_VERSION).lua
	$(INSTALL_DATA) -D "$<" "$@"

uninstall:
	rm -rf $(INSTALL_FILES)

# ----------------------------------------
# Binary install
# ----------------------------------------

LUAROCKS_CORE_FILES = $(wildcard src/luarocks/core/* src/luarocks/loader.lua)
INSTALL_BINARY_FILES =  $(DESTDIR)$(bindir)/luarocks \
	$(DESTDIR)$(bindir)/luarocks-admin \
	$(patsubst src/%, $(DESTDIR)$(luadir)/%, $(LUAROCKS_CORE_FILES))

install-binary: $(INSTALL_BINARY_FILES)

# ----------------------------------------
# Bootstrap install
# ----------------------------------------

bootstrap: $(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua
	(unset $(LUA_ENV_VARS); \
	LUA_PATH="./src/?.lua;;" \
	LUAROCKS_SYSCONFDIR="$(DESTDIR)$(luarocksconfdir)" \
	"$(LUA)" ./src/bin/luarocks make --tree="$(DESTDIR)$(rocks_tree)")

# ----------------------------------------
# Windows binary build
# ----------------------------------------

windows-binary:
	$(MAKE) -f binary/Makefile.windows windows-binary

windows-clean:
	$(MAKE) -f binary/Makefile.windows windows-clean

# ----------------------------------------
# Clean
# ----------------------------------------

clean: windows-clean
	rm -rf ./config.unix \
		./build/

.PHONY: all build install install-config binary install-binary bootstrap clean windows-binary windows-clean
