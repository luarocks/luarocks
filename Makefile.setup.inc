
DESTDIR =
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LUADIR ?= $(PREFIX)/share/lua/$(LUA_VERSION)/

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
upload/api.lua upload/multipart.lua fetch/git_http.lua fetch/hg_http.lua \
fetch/hg_https.lua fetch/hg_ssh.lua fetch/git_https.lua

