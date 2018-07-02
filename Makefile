
-include config.unix

all: ./luarocks ./luarocks-admin

# ----------------------------------------
# Base build
# ----------------------------------------

build: all

config.unix:
	@echo Please run the "./configure" script before building.
	@echo
	@exit 1

config-$(LUA_VERSION).lua.in: config.unix

./luarocks: config.unix config-$(LUA_VERSION).lua.in
	rm -f src/luarocks/core/hardcoded.lua
	echo "#!/bin/sh" > luarocks
	echo "unset LUA_PATH LUA_PATH_5_2 LUA_PATH_5_3 LUA_PATH_5_4" >> luarocks
	echo 'LUAROCKS_SYSCONFDIR="$(SYSCONFDIR)" LUA_PATH="$(PWD)/src/?.lua;;" exec "$(LUA_BINDIR)/$(LUA_INTERPRETER)" "src/bin/luarocks" --project-tree="$(PWD)/lua_modules" "$$@"' >> luarocks
	chmod +rx ./luarocks
	./luarocks init
	cp config-$(LUA_VERSION).lua.in .luarocks/config-$(LUA_VERSION).lua

luarocks-admin: config.unix
	rm -f src/luarocks/core/hardcoded.lua
	echo "#!/bin/sh" > luarocks-admin
	echo "unset LUA_PATH LUA_PATH_5_2 LUA_PATH_5_3 LUA_PATH_5_4" >> luarocks-admin
	echo 'LUAROCKS_SYSCONFDIR="$(SYSCONFDIR)" LUA_PATH="$(PWD)/src/?.lua;;" exec "$(LUA_BINDIR)/$(LUA_INTERPRETER)" "src/bin/luarocks-admin" --project-tree="$(PWD)/lua_modules" "$$@"' >> luarocks-admin
	chmod +rx ./luarocks-admin

# ----------------------------------------
# Regular install
# ----------------------------------------

install: all $(PREFIX)/bin/luarocks $(PREFIX)/bin/luarocks-admin $(SYSCONFDIR)/config-$(LUA_VERSION).lua
	mkdir -p "$(PREFIX)/share/lua/$(LUA_VERSION)/luarocks"
	cp -a src/luarocks/* "$(PREFIX)/share/lua/$(LUA_VERSION)/luarocks"

$(PREFIX)/bin/luarocks: src/bin/luarocks config.unix
	mkdir -p "$(PREFIX)/bin"
	echo "#!$(LUA_BINDIR)/$(LUA_INTERPRETER)" > $@
	echo "package.loaded['luarocks.core.hardcoded'] = { SYSCONFDIR = [[$(SYSCONFDIR)]] }" >> $@
	echo "package.path=[[$(PREFIX)/share/lua/$(LUA_VERSION)/?.lua;]] .. package.path" >> $@
	tail -n +2 src/bin/luarocks >> $@
	chmod +rx $@

$(PREFIX)/bin/luarocks-admin: src/bin/luarocks-admin config.unix
	mkdir -p "$(PREFIX)/bin"
	echo "#!$(LUA_BINDIR)/$(LUA_INTERPRETER)" > $@
	echo "package.loaded['luarocks.core.hardcoded'] = { SYSCONFDIR = [[$(SYSCONFDIR)]] }" >> $@
	echo "package.path=[[$(PREFIX)/share/lua/$(LUA_VERSION)/?.lua;]] .. package.path" >> $@
	tail -n +2 src/bin/luarocks-admin >> $@
	chmod +rx $@

$(SYSCONFDIR)/config-$(LUA_VERSION).lua: config-$(LUA_VERSION).lua.in
	mkdir -p "$(SYSCONFDIR)"
	cp config-$(LUA_VERSION).lua.in "$(SYSCONFDIR)/config-$(LUA_VERSION).lua"

# ----------------------------------------
# Binary build
# ----------------------------------------

BINARY_TARGET=build-binary

binary: $(BINARY_TARGET)/luarocks.exe $(BINARY_TARGET)/luarocks-admin.exe

$(BINARY_TARGET)/luarocks.exe: ./luarocks
	LUA_PATH="$(PWD)/src/?.lua;;" "$(LUA_BINDIR)/$(LUA_INTERPRETER)" binary/all_in_one "src/bin/luarocks" "$(LUA_DIR)" "^src/luarocks/admin/" "$(SYSCONFDIR)" $(BINARY_TARGET) $(BINARY_PLATFORM) $(BINARY_CC) $(BINARY_NM) $(BINARY_SYSROOT)

$(BINARY_TARGET)/luarocks-admin.exe: ./luarocks
	LUA_PATH="$(PWD)/src/?.lua;;" "$(LUA_BINDIR)/$(LUA_INTERPRETER)" binary/all_in_one "src/bin/luarocks-admin" "$(LUA_DIR)" "^src/luarocks/cmd/" "$(SYSCONFDIR)" $(BINARY_TARGET) $(BINARY_PLATFORM) $(BINARY_CC) $(BINARY_NM) $(BINARY_SYSROOT)

# ----------------------------------------
# Binary install
# ----------------------------------------

install-binary: build-binary/luarocks.exe build-binary/luarocks-admin.exe
	mkdir -p "$(PREFIX)/bin"
	cp build-binary/luarocks.exe "$(PREFIX)/bin/luarocks"
	chmod +rx "$(PREFIX)/bin/luarocks"
	cp build-binary/luarocks-admin.exe "$(PREFIX)/bin/luarocks-admin"
	chmod +rx "$(PREFIX)/bin/luarocks-admin"
	mkdir -p "$(PREFIX)/share/lua/$(LUA_VERSION)/luarocks/core"
	cp -a src/luarocks/core/* "$(PREFIX)/share/lua/$(LUA_VERSION)/luarocks/core"
	cp -a src/luarocks/loader.lua "$(PREFIX)/share/lua/$(LUA_VERSION)/luarocks/"

# ----------------------------------------
# Bootstrap install
# ----------------------------------------

bootstrap: ./luarocks $(SYSCONFDIR)/config-$(LUA_VERSION).lua
	./luarocks make --tree="$(ROCKS_TREE)"

# ----------------------------------------
# Windows binary build
# ----------------------------------------

windows-binary: ./luarocks
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
