
DESTDIR =
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LUADIR ?= $(PREFIX)/share/lua/$(LUA_VERSION)/

BIN_FILES = luarocks luarocks-admin
LUAROCKS_FILES = admin/add.lua admin/cache.lua admin/make_manifest.lua admin/refresh_cache.lua \
admin/remove.lua build.lua build/builtin.lua build/cmake.lua build/command.lua \
build/make.lua command_line.lua config_cmd.lua core/cfg.lua core/deps.lua \
core/dir.lua core/manif.lua core/path.lua core/persist.lua core/type_check.lua \
core/util.lua deps.lua dir.lua doc.lua download.lua fetch.lua fetch/cvs.lua \
fetch/git.lua fetch/git_file.lua fetch/git_http.lua fetch/git_https.lua \
fetch/git_ssh.lua fetch/hg.lua fetch/hg_http.lua fetch/hg_https.lua fetch/hg_ssh.lua \
fetch/sscm.lua fetch/svn.lua fs.lua fs/lua.lua fs/tools.lua fs/unix.lua fs/unix/tools.lua \
fs/win32.lua fs/win32/tools.lua help.lua index.lua install.lua lint.lua list.lua \
loader.lua make.lua manif.lua manif/writer.lua new_version.lua pack.lua path.lua \
path_cmd.lua persist.lua purge.lua remove.lua repos.lua require.lua search.lua \
show.lua tools/patch.lua tools/tar.lua tools/zip.lua type_check.lua unpack.lua \
upload.lua upload/api.lua upload/multipart.lua util.lua write_rockspec.lua
