MAKEFLAGS += --jobs=1

-include config.unix

datarootdir = $(prefix)/share
bindir = $(prefix)/bin
INSTALL = install
INSTALL_DATA = $(INSTALL) -m 644
BINARY_PLATFORM = unix

SHEBANG = \#!$(LUA)
luarocksconfdir = $(sysconfdir)/luarocks
luadir = $(datarootdir)/lua/$(LUA_VERSION)
builddir = ./build
buildbinarydir = ./build-binary

LUAROCKS_FILES = $(shell find src/luarocks/ -type f -name '*.lua')

LUA_ENV_VARS = LUA_PATH LUA_PATH_5_2 LUA_PATH_5_3 LUA_PATH_5_4 LUA_CPATH LUA_CPATH_5_2 LUA_CPATH_5_3 LUA_CPATH_5_4

all: build

# ----------------------------------------
# Base build
# ----------------------------------------

build: config.unix $(builddir)/config-$(LUA_VERSION).lua $(builddir)/luarocks $(builddir)/luarocks-admin

config.unix:
	@echo Please run the "./configure" script before building.
	@echo
	@exit 1

$(builddir)/config-$(LUA_VERSION).lua: config.unix
	mkdir -p "$(@D)"
	@printf -- '-- LuaRocks configuration\n\n'\
	'rocks_trees = {\n'\
	'   { name = "user", root = home .. "/.luarocks" };\n'\
	"$$([ "$(rocks_tree)" != "$(HOME)/.luarocks" ] && printf '   { name = "system", root = "'"$(rocks_tree)"'" };\\n')"\
	'}\n'\
	'variables = {\n'\
	"$$([ -n "$(LUA_DIR)" ] && printf '   LUA_DIR = "%s";\\n' "$(LUA_DIR)")"\
	"$$([ -n "$(LUA_INCDIR)" ] && printf '   LUA_INCDIR = "%s";\\n' "$(LUA_INCDIR)")"\
	"$$([ -n "$(LUA_BINDIR)" ] && printf '   LUA_BINDIR = "%s";\\n' "$(LUA_BINDIR)")"\
	"$$([ -n "$(LUA_LIBDIR)" ] && printf '   LUA_LIBDIR = "%s";\\n' "$(LUA_LIBDIR)")"\
	"$$([ -n "$(LUA_VERSION)" ] && printf '   LUA_VERSION = "%s";\\n' "$(LUA_VERSION)")"\
	"$$([ -n "$(LUA)" ] && printf '   LUA = "%s";\\n' "$(LUA)")"\
	'}\n'\
	> $@

luarocks: config.unix $(builddir)/config-$(LUA_VERSION).lua
	mkdir -p .luarocks
	cp $(builddir)/config-$(LUA_VERSION).lua .luarocks/config-$(LUA_VERSION).lua
	rm -f src/luarocks/core/hardcoded.lua
	echo "#!/bin/sh" > luarocks
	echo "unset $(LUA_ENV_VARS)" >> luarocks
	echo 'LUAROCKS_SYSCONFDIR="$(luarocksconfdir)" LUA_PATH="$(CURDIR)/src/?.lua;;" exec "$(LUA)" "$(CURDIR)/src/bin/luarocks" --project-tree="$(CURDIR)/lua_modules" "$$@"' >> luarocks
	chmod +rx ./luarocks
	./luarocks init

luarocks-admin: config.unix
	rm -f src/luarocks/core/hardcoded.lua
	echo "#!/bin/sh" > luarocks-admin
	echo "unset $(LUA_ENV_VARS)" >> luarocks-admin
	echo 'LUAROCKS_SYSCONFDIR="$(luarocksconfdir)" LUA_PATH="$(CURDIR)/src/?.lua;;" exec "$(LUA)" "$(CURDIR)/src/bin/luarocks-admin" --project-tree="$(CURDIR)/lua_modules" "$$@"' >> luarocks-admin
	chmod +rx ./luarocks-admin

$(builddir)/luarocks: src/bin/luarocks config.unix
	mkdir -p "$(@D)"
	(printf '$(SHEBANG)\n'\
	'package.loaded["luarocks.core.hardcoded"] = { '\
	"$$([ -n "$(FORCE_CONFIG)" ] && printf 'FORCE_CONFIG = true, ')"\
	'SYSCONFDIR = [[$(luarocksconfdir)]] }\n'\
	'package.path=[[$(luadir)/?.lua;]] .. package.path\n'\
	'local list = package.searchers or package.loaders; table.insert(list, 1, function(name) if name:match("^luarocks%%.") then return loadfile([[$(luadir)/]] .. name:gsub([[%%.]], [[/]]) .. [[.lua]]) end end)\n'; \
	tail -n +2 src/bin/luarocks \
	)> "$@"

$(builddir)/luarocks-admin: src/bin/luarocks-admin config.unix
	mkdir -p "$(@D)"
	(printf '$(SHEBANG)\n'\
	'package.loaded["luarocks.core.hardcoded"] = { '\
	"$$([ -n "$(FORCE_CONFIG)" ] && printf 'FORCE_CONFIG = true, ')"\
	'SYSCONFDIR = [[$(luarocksconfdir)]] }\n'\
	'package.path=[[$(luadir)/?.lua;]] .. package.path\n'\
	'local list = package.searchers or package.loaders; table.insert(list, 1, function(name) if name:match("^luarocks%%.") then return loadfile([[$(luadir)/]] .. name:gsub([[%%.]], [[/]]) .. [[.lua]]) end end)\n'; \
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

INSTALL_FILES =

install: all install-config
	mkdir -p '$(DESTDIR)$(bindir)/'
	$(INSTALL) '$(builddir)/luarocks' '$(DESTDIR)$(bindir)/luarocks'
	$(INSTALL) '$(builddir)/luarocks-admin' '$(DESTDIR)$(bindir)/luarocks-admin'
	find src/luarocks/ -type d | while read f; \
	do \
	   mkdir -p '$(DESTDIR)$(luadir)'/`echo $$f | sed 's,^src/,,'`; \
	done
	find src/luarocks/ -type f -name '*.lua' | while read f; \
	do \
	   $(INSTALL_DATA) "$$f" '$(DESTDIR)$(luadir)'/`echo $$f | sed 's,^src/,,'`; \
	done

install-config:
	mkdir -p '$(DESTDIR)$(luarocksconfdir)/'
	$(INSTALL_DATA)  '$(builddir)/config-$(LUA_VERSION).lua' '$(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua'

uninstall:
	rm -rf $(DESTDIR)$(bindir)/luarocks \
	       $(DESTDIR)$(bindir)/luarocks-admin \
	       $(DESTDIR)$(luarocksconfdir)/config-$(LUA_VERSION).lua \
	       $(patsubst src/%, $(DESTDIR)$(luadir)/%, $(LUAROCKS_FILES))

# ----------------------------------------
# Binary install
# ----------------------------------------

install-binary: binary install-config
	mkdir -p '$(DESTDIR)$(bindir)/'
	$(INSTALL) "$(buildbinarydir)/luarocks.exe" "$(DESTDIR)$(bindir)/luarocks"
	$(INSTALL) "$(buildbinarydir)/luarocks-admin.exe" "$(DESTDIR)$(bindir)/luarocks-admin"
	mkdir -p '$(DESTDIR)$(luadir)/luarocks/core'
	for f in src/luarocks/core/*.lua src/luarocks/loader.lua; \
	do \
	   $(INSTALL_DATA) "$$f" '$(DESTDIR)$(luadir)'/`echo $$f | sed 's,^src/,,'`; \
	done

# ----------------------------------------
# Bootstrap install
# ----------------------------------------

bootstrap: luarocks install-config
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
		./luarocks-admin \
		$(builddir)/ \
		$(buildbinarydir)/ \
		./.luarocks \
		./lua_modules

.PHONY: all build install install-config binary install-binary bootstrap clean windows-binary windows-clean
