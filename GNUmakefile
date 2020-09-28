
-include config.unix

datarootdir = $(prefix)/share
bindir = $(prefix)/bin
INSTALL = install
INSTALL_DATA = $(INSTALL) -m 644
BINARY_PLATFORM = unix

SHEBANG = \#!$(LUA_BINDIR)/$(LUA_INTERPRETER)
LUA = $(LUA_BINDIR)/$(LUA_INTERPRETER)
luarocksconfdir = $(sysconfdir)/luarocks
luadir = $(datarootdir)/lua/$(LUA_VERSION)
builddir = ./build
buildbinarydir = ./build-binary


LUAROCKS_FILES = $(shell find src/luarocks/ -type f -name '*.lua')

all: build

# ----------------------------------------
# Base build
# ----------------------------------------

build: luarocks luarocks-admin $(builddir)/luarocks $(builddir)/luarocks-admin

config.unix:
	@echo Please run the "./configure" script before building.
	@echo
	@exit 1

$(builddir)/config-$(LUA_VERSION).lua: config.unix
	mkdir -p "$(@D)"
	@(\
	  printf -- '-- LuaRocks configuration\n\n';\
	  printf 'rocks_trees = {\n';\
	  printf '   { name = "user", root = home .. "/.luarocks" };\n';\
	  if [ "$(rocks_tree)" != "$(HOME)/.luarocks" ]; then\
	    root="$(rocks_tree)";\
	    if [ "$(LUA_MSYS2_MINGW_W64)" = "yes" ]; then\
	      root="$$(cygpath --windows "$${root}")";\
	    fi;\
	    printf '   { name = "system", root = [[%s]] };\n' "$${root}";\
	  fi;\
	  printf '}\n';\
	  [ -n "$(LUA_INTERPRETER)" ] &&\
	    printf 'lua_interpreter = [[%s]];\n' "$(LUA_INTERPRETER)";\
	  printf 'variables = {\n';\
	  [ -n "$(LUA_DIR)" ] &&\
	    printf '   LUA_DIR = [[%s]];\n' "$(LUA_DIR)";\
	  [ -n "$(LUA_INCDIR)" ] &&\
	    printf '   LUA_INCDIR = [[%s]];\n' "$(LUA_INCDIR)";\
	  [ -n "$(LUA_BINDIR)" ] &&\
	    printf '   LUA_BINDIR = [[%s]];\n' "$(LUA_BINDIR)";\
	  [ -n "$(LUA_LIBDIR)" ] &&\
	    printf '   LUA_LIBDIR = [[%s]];\n' "$(LUA_LIBDIR)";\
	  printf '}\n';\
	) > $@

luarocks: config.unix $(builddir)/config-$(LUA_VERSION).lua
	mkdir -p .luarocks
	cp $(builddir)/config-$(LUA_VERSION).lua .luarocks/config-$(LUA_VERSION).lua
	rm -f src/luarocks/core/hardcoded.lua
	echo "#!/bin/sh" > luarocks
	echo "unset LUA_PATH LUA_PATH_5_2 LUA_PATH_5_3 LUA_PATH_5_4 LUA_CPATH LUA_CPATH_5_2 LUA_CPATH_5_3 LUA_CPATH_5_4" >> luarocks
	if [ "$(LUA_MSYS2_MINGW_W64)" = "yes" ]; then\
	  echo 'export LUAROCKS_SYSCONFDIR="$$(cygpath --windows "$(luarocksconfdir)")"' >> luarocks;\
	  echo 'export LUA_PATH="$$(cygpath --windows "$(CURDIR)/src/")?.lua"' >> luarocks;\
	  echo 'PROJECT_TREE="$$(cygpath --windows "$(CURDIR)/lua_modules")"' >> luarocks;\
	else\
	  echo 'export LUAROCKS_SYSCONFDIR="$(luarocksconfdir)"' >> luarocks;\
	  echo 'export LUA_PATH="$(CURDIR)/src/?.lua"' >> luarocks;\
	  echo 'PROJECT_TREE="$(CURDIR)/lua_modules"' >> luarocks;\
	fi
	echo 'exec "$(LUA)" "$(CURDIR)/src/bin/luarocks" --project-tree="$${PROJECT_TREE}" "$$@"' >> luarocks
	chmod +rx ./luarocks
	./luarocks init

luarocks-admin: config.unix
	rm -f src/luarocks/core/hardcoded.lua
	echo "#!/bin/sh" > luarocks-admin
	echo "unset LUA_PATH LUA_PATH_5_2 LUA_PATH_5_3 LUA_PATH_5_4 LUA_CPATH LUA_CPATH_5_2 LUA_CPATH_5_3 LUA_CPATH_5_4" >> luarocks-admin
	if [ "$(LUA_MSYS2_MINGW_W64)" = "yes" ]; then\
	  echo 'export LUAROCKS_SYSCONFDIR="$$(cygpath --windows "$(luarocksconfdir)")"' >> luarocks-admin;\
	  echo 'export LUA_PATH="$$(cygpath --windows "$(CURDIR)/src/")?.lua"' >> luarocks-admin;\
	  echo 'PROJECT_TREE="$$(cygpath --windows "$(CURDIR)/lua_modules")"' >> luarocks-admin;\
	else\
	  echo 'export LUAROCKS_SYSCONFDIR="$(luarocksconfdir)"' >> luarocks-admin;\
	  echo 'export LUA_PATH="$(CURDIR)/src/?.lua"' >> luarocks-admin;\
	  echo 'PROJECT_TREE="$(CURDIR)/lua_modules"' >> luarocks-admin;\
	fi
	echo 'exec "$(LUA)" "$(CURDIR)/src/bin/luarocks-admin" --project-tree="$${PROJECT_TREE}" "$$@"' >> luarocks-admin
	chmod +rx ./luarocks-admin

$(builddir)/luarocks: src/bin/luarocks config.unix
	mkdir -p "$(@D)"
	(SYSCONFDIR="$(luarocksconfdir)";\
	LUADIR="$(luadir)/";\
	if [ "$(LUA_MSYS2_MINGW_W64)" = "yes" ]; then\
	  SYSCONFDIR="$$(cygpath --windows "$${SYSCONFDIR}")";\
	  LUADIR="$$(cygpath --windows "$${LUADIR}")";\
	fi;\
	echo '$(SHEBANG)';\
	printf 'package.loaded["luarocks.core.hardcoded"] = { ';\
	[ -n "$(FORCE_CONFIG)" ] && printf 'FORCE_CONFIG = true, ';\
	echo "SYSCONFDIR = [[$${SYSCONFDIR}]] }";\
	echo "package.path=[[$${LUADIR}?.lua;]] .. package.path";\
	echo "local list = package.searchers or package.loaders; table.insert(list, 1, function(name) if name:match(\"^luarocks%%.\") then return loadfile([[$${LUADIR}]] .. name:gsub([[%%.]], [[/]]) .. [[.lua]]) end end)"; \
	tail -n +2 src/bin/luarocks \
	)> "$@"

$(builddir)/luarocks-admin: src/bin/luarocks-admin config.unix
	mkdir -p "$(@D)"
	(SYSCONFDIR="$(luarocksconfdir)";\
	LUADIR="$(luadir)/";\
	if [ "$(LUA_MSYS2_MINGW_W64)" = "yes" ]; then\
	  SYSCONFDIR="$$(cygpath --windows "$${SYSCONFDIR}")";\
	  LUADIR="$$(cygpath --windows "$${LUADIR}")";\
	fi;\
	echo '$(SHEBANG)';\
	printf 'package.loaded["luarocks.core.hardcoded"] = { ';\
	[ -n "$(FORCE_CONFIG)" ] && printf 'FORCE_CONFIG = true, ';\
	echo "SYSCONFDIR = [[$${SYSCONFDIR}]] }";\
	echo "package.path=[[$${LUADIR}?.lua;]] .. package.path";\
	echo "local list = package.searchers or package.loaders; table.insert(list, 1, function(name) if name:match(\"^luarocks%%.\") then return loadfile([[$${LUADIR}]] .. name:gsub([[%%.]], [[/]]) .. [[.lua]]) end end)"; \
	tail -n +2 src/bin/luarocks-admin \
	)> "$@"

# ----------------------------------------
# Base build
# ----------------------------------------

binary: luarocks $(buildbinarydir)/luarocks.exe $(buildbinarydir)/luarocks-admin.exe

$(buildbinarydir)/luarocks.exe: src/bin/luarocks $(LUAROCKS_FILES)
	(unset $(LUA_ENV_VARS); \
	"$(LUA)" binary/all_in_one "$<" "$(LUA_DIR)" "^src/luarocks/admin/" "$(luarocksconfdir)" "$(@D)" "$(FORCE_CONFIG)" $(BINARY_PLATFORM) $(CC) $(NM) $(BINARY_SYSROOT))

$(buildbinarydir)/luarocks-admin.exe: src/bin/luarocks-admin $(LUAROCKS_FILES)
	(unset $(LUA_ENV_VARS); \
	"$(LUA)" binary/all_in_one "$<" "$(LUA_DIR)" "^src/luarocks/cmd/" "$(luarocksconfdir)" "$(@D)" "$(FORCE_CONFIG)" $(BINARY_PLATFORM) $(CC) $(NM) $(BINARY_SYSROOT))

# ----------------------------------------
# Regular install
# ----------------------------------------

INSTALL_FILES = $(DESTDIR)$(bindir)/luarocks \
	$(DESTDIR)$(bindir)/luarocks-admin \
	$(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua \
	$(patsubst src/%, $(DESTDIR)$(luadir)/%, $(LUAROCKS_FILES))

install: $(INSTALL_FILES)

install-config: $(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua

$(DESTDIR)$(bindir)/luarocks: $(builddir)/luarocks
	mkdir -p "$(@D)"
	$(INSTALL) "$<" "$@"

$(DESTDIR)$(bindir)/luarocks-admin: $(builddir)/luarocks-admin
	mkdir -p "$(@D)"
	$(INSTALL) "$<" "$@"

$(DESTDIR)$(luadir)/luarocks/%.lua: src/luarocks/%.lua
	mkdir -p "$(@D)"
	$(INSTALL_DATA) "$<" "$@"

$(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua: $(builddir)/config-$(LUA_VERSION).lua
	mkdir -p "$(@D)"
	$(INSTALL_DATA) "$<" "$@"

uninstall:
	rm -rf $(INSTALL_FILES)

# ----------------------------------------
# Binary install
# ----------------------------------------

LUAROCKS_CORE_FILES = $(wildcard src/luarocks/core/* src/luarocks/loader.lua)
INSTALL_BINARY_FILES = $(patsubst src/%, $(DESTDIR)$(luadir)/%, $(LUAROCKS_CORE_FILES)) \
	$(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua

install-binary: $(INSTALL_BINARY_FILES)
	mkdir -p "$(buildbinarydir)"
	$(INSTALL) "$(buildbinarydir)/luarocks.exe" "$(DESTDIR)$(bindir)/luarocks"
	$(INSTALL) "$(buildbinarydir)/luarocks-admin.exe" "$(DESTDIR)$(bindir)/luarocks-admin"

# ----------------------------------------
# Bootstrap install
# ----------------------------------------

bootstrap: luarocks $(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua
	./luarocks make --tree="$(DESTDIR)$(rocks_tree)"

# ----------------------------------------
# Windows binary build
# ----------------------------------------

windows-binary: windows-binary-32 windows-binary-64

windows-clean: windows-clean-32 windows-clean-64

windows-binary-32: luarocks
	$(MAKE) -f binary/Makefile.windows windows-binary MINGW_PREFIX=i686-w64-mingw32 OPENSSL_PLATFORM=mingw

windows-clean-32:
	$(MAKE) -f binary/Makefile.windows windows-clean MINGW_PREFIX=i686-w64-mingw32 OPENSSL_PLATFORM=mingw

windows-binary-64: luarocks
	$(MAKE) -f binary/Makefile.windows windows-binary MINGW_PREFIX=x86_64-w64-mingw32 OPENSSL_PLATFORM=mingw64

windows-clean-64:
	$(MAKE) -f binary/Makefile.windows windows-clean MINGW_PREFIX=x86_64-w64-mingw32 OPENSSL_PLATFORM=mingw64

# ----------------------------------------
# Clean
# ----------------------------------------

clean: windows-clean
	rm -rf ./config.unix \
		./luarocks \
		./luarocks.bat \
		./luarocks-admin \
		./luarocks-admin.bat \
		$(builddir)/ \
		$(buildbinarydir)/ \
		./.luarocks \
		./lua_modules

.PHONY: all build install binary install-binary bootstrap clean windows-binary windows-clean
