
DESTDIR =
PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin
LUADIR ?= $(PREFIX)/share/lua/$(LUA_VERSION)

BIN_FILES = luarocks luarocks-admin
LUAROCKS_FILES = fs.lua dir.lua repos.lua command_line.lua upload/api.lua upload/multipart.lua \
admin/index.lua build.lua search.lua fs/win32.lua fs/win32/tools.lua \
fs/unix/tools.lua fs/lua.lua fs/tools.lua fs/unix.lua loader.lua cmd/help.lua \
cmd/unpack.lua cmd/upload.lua cmd/lint.lua cmd/purge.lua cmd/install.lua \
cmd/config.lua cmd/write_rockspec.lua cmd/build.lua cmd/search.lua \
cmd/make.lua cmd/list.lua cmd/show.lua cmd/path.lua cmd/new_version.lua \
cmd/pack.lua cmd/download.lua cmd/doc.lua cmd/remove.lua tools/patch.lua \
tools/zip.lua tools/tar.lua manif/writer.lua build/cmake.lua build/make.lua \
build/command.lua build/builtin.lua fetch.lua path.lua util.lua deps.lua \
pack.lua download.lua core/dir.lua core/path.lua core/util.lua \
core/cfg.lua core/persist.lua core/manif.lua \
type_check.lua persist.lua require.lua manif.lua admin/cache.lua \
admin/cmd/make_manifest.lua admin/cmd/add.lua admin/cmd/remove.lua \
admin/cmd/refresh_cache.lua remove.lua fetch/git_file.lua fetch/sscm.lua \
fetch/cvs.lua fetch/git_https.lua fetch/git_ssh.lua fetch/hg_http.lua \
fetch/git_http.lua fetch/svn.lua fetch/git.lua fetch/hg_ssh.lua \
fetch/hg_https.lua fetch/hg.lua core/vers.lua cmd/which.lua \
fun.lua type/manifest.lua type/rockspec.lua queries.lua results.lua
