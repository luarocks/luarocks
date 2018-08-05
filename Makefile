
-include config.unix

all: luarocks luarocks-admin

# ----------------------------------------
# Base build
# ----------------------------------------

build: all

config.unix:
	@echo Please run the "./configure" script before building.
	@echo
	@exit 1

config-$(LUA_VERSION).lua.in: config.unix

luarocks: config.unix config-$(LUA_VERSION).lua.in
	rm -f src/luarocks/core/hardcoded.lua
	echo "#!/bin/sh" > luarocks
	echo "unset LUA_PATH LUA_PATH_5_2 LUA_PATH_5_3 LUA_PATH_5_4" >> luarocks
	echo 'LUAROCKS_SYSCONFDIR="$(luarocksconfdir)" LUA_PATH="$(CURDIR)/src/?.lua;;" exec "$(LUA_BINDIR)/$(LUA_INTERPRETER)" "$(CURDIR)/src/bin/luarocks" --project-tree="$(CURDIR)/lua_modules" "$$@"' >> luarocks
	chmod +rx ./luarocks
	./luarocks init
	cp config-$(LUA_VERSION).lua.in .luarocks/config-$(LUA_VERSION).lua

luarocks-admin: config.unix
	rm -f src/luarocks/core/hardcoded.lua
	echo "#!/bin/sh" > luarocks-admin
	echo "unset LUA_PATH LUA_PATH_5_2 LUA_PATH_5_3 LUA_PATH_5_4" >> luarocks-admin
	echo 'LUAROCKS_SYSCONFDIR="$(luarocksconfdir)" LUA_PATH="$(CURDIR)/src/?.lua;;" exec "$(LUA_BINDIR)/$(LUA_INTERPRETER)" "$(CURDIR)/src/bin/luarocks-admin" --project-tree="$(CURDIR)/lua_modules" "$$@"' >> luarocks-admin
	chmod +rx ./luarocks-admin

# ----------------------------------------
# Regular install
# ----------------------------------------

install: all $(DESTDIR)$(prefix)/bin/luarocks $(DESTDIR)$(prefix)/bin/luarocks-admin $(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua
	mkdir -p "$(DESTDIR)$(prefix)/share/lua/$(LUA_VERSION)/luarocks"
	cp -a src/luarocks/* "$(DESTDIR)$(prefix)/share/lua/$(LUA_VERSION)/luarocks"

$(DESTDIR)$(prefix)/bin/luarocks: src/bin/luarocks config.unix
	mkdir -p "$(@D)"
	(printf '#!$(LUA_BINDIR)/$(LUA_INTERPRETER)\n'\
	'package.loaded["luarocks.core.hardcoded"] = { SYSCONFDIR = [[$(luarocksconfdir)]] }\n'\
	'package.path=[[$(prefix)/share/lua/$(LUA_VERSION)/?.lua;]] .. package.path\n'; \
	tail -n +2 src/bin/luarocks \
	)> "$@"
	chmod +rx $@

$(DESTDIR)$(prefix)/bin/luarocks-admin: src/bin/luarocks-admin config.unix
	mkdir -p "$(@D)"
	(printf '#!$(LUA_BINDIR)/$(LUA_INTERPRETER)\n'\
	'package.loaded["luarocks.core.hardcoded"] = { SYSCONFDIR = [[$(luarocksconfdir)]] }\n'\
	'package.path=[[$(prefix)/share/lua/$(LUA_VERSION)/?.lua;]] .. package.path\n'; \
	tail -n +2 src/bin/luarocks-admin \
	)> "$@"
	chmod +rx $@

$(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua: config-$(LUA_VERSION).lua.in
	mkdir -p "$(DESTDIR)$(luarocksconfdir)"
	cp config-$(LUA_VERSION).lua.in "$(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua"

# ----------------------------------------
# Binary build
# ----------------------------------------

BINARY_TARGET=build-binary

binary: $(BINARY_TARGET)/luarocks.exe $(BINARY_TARGET)/luarocks-admin.exe

$(BINARY_TARGET)/luarocks.exe: luarocks
	LUA_PATH="$(CURDIR)/src/?.lua;;" "$(LUA_BINDIR)/$(LUA_INTERPRETER)" binary/all_in_one "src/bin/luarocks" "$(LUA_DIR)" "^src/luarocks/admin/" "$(luarocksconfdir)" $(BINARY_TARGET) $(BINARY_PLATFORM) $(BINARY_CC) $(BINARY_NM) $(BINARY_SYSROOT)

$(BINARY_TARGET)/luarocks-admin.exe: luarocks
	LUA_PATH="$(CURDIR)/src/?.lua;;" "$(LUA_BINDIR)/$(LUA_INTERPRETER)" binary/all_in_one "src/bin/luarocks-admin" "$(LUA_DIR)" "^src/luarocks/cmd/" "$(luarocksconfdir)" $(BINARY_TARGET) $(BINARY_PLATFORM) $(BINARY_CC) $(BINARY_NM) $(BINARY_SYSROOT)

# ----------------------------------------
# Binary install
# ----------------------------------------

install-binary: build-binary/luarocks.exe build-binary/luarocks-admin.exe
	mkdir -p "$(DESTDIR)$(prefix)/bin"
	cp build-binary/luarocks.exe "$(DESTDIR)$(prefix)/bin/luarocks"
	chmod +rx "$(DESTDIR)$(prefix)/bin/luarocks"
	cp build-binary/luarocks-admin.exe "$(DESTDIR)$(prefix)/bin/luarocks-admin"
	chmod +rx "$(DESTDIR)$(prefix)/bin/luarocks-admin"
	mkdir -p "$(DESTDIR)$(prefix)/share/lua/$(LUA_VERSION)/luarocks/core"
	cp -a src/luarocks/core/* "$(DESTDIR)$(prefix)/share/lua/$(LUA_VERSION)/luarocks/core"
	cp -a src/luarocks/loader.lua "$(DESTDIR)$(prefix)/share/lua/$(LUA_VERSION)/luarocks/"

# ----------------------------------------
# Bootstrap install
# ----------------------------------------

bootstrap: luarocks $(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua
	./luarocks make --tree="$(DESTDIR)$(ROCKS_TREE)"

# ----------------------------------------
# Windows binary build
# ----------------------------------------

windows-binary: luarocks
	make -f binary/Makefile.windows windows-binary

windows-clean:
	make -f binary/Makefile.windows windows-clean

# ----------------------------------------
# Clean
# ----------------------------------------

clean:
	rm -f ./config.unix
	rm -f ./luarocks
	rm -f ./luarocks-admin
	rm -rf build-binary
	rm -rf ./.luarocks
	rm -rf ./lua_modules

.PHONY: all build install binary install-binary bootstrap clean windows-binary windows-clean
