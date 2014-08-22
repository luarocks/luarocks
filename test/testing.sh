#!/bin/bash -e

# Setup #########################################

[ -e ../configure ] || {
   echo "Please run this from the test/ directory."
   exit 1
}

if [ -z "$*" ]
then
   ps aux | grep -q '[s]shd' || {
      echo "Run sudo /bin/sshd in order to perform all tests."
      exit 1
   }
fi

if [ "$1" == "--travis" ]
then
   travis=true
   shift
fi

luaversion=5.1.5

if [ "$1" == "--lua" ]
then
   shift
   luaversion=$1
   shift
fi

testing_dir="$PWD"

testing_tree="$testing_dir/testing-$luaversion"
testing_sys_tree="$testing_dir/testing_sys-$luaversion"
testing_tree_copy="$testing_dir/testing_copy-$luaversion"
testing_sys_tree_copy="$testing_dir/testing_sys_copy-$luaversion"
testing_cache="$testing_dir/testing_cache-$luaversion"
testing_server="$testing_dir/testing_server-$luaversion"


if [ "$1" == "--clean" ]
then
   shift
   rm -rf "$testing_cache"
   rm -rf "$testing_server"
fi

[ "$1" ] || rm -f luacov.stats.out
rm -f luacov.report.out
rm -rf /tmp/luarocks_testing
mkdir /tmp/luarocks_testing
rm -rf "$testing_tree"
rm -rf "$testing_sys_tree"
rm -rf "$testing_tree_copy"
rm -rf "$testing_sys_tree_copy"
rm -rf "$testing_dir/testing_config.lua"
rm -rf "$testing_dir/testing_config_show_downloads.lua"
rm -rf "$testing_dir/testing_config_sftp.lua"
rm -rf "$testing_dir/luacov.config"

mkdir -p "$testing_cache"

[ "$1" = "clean" ] && {
   rm -f luacov.stats.out
   exit 0
}

cat <<EOF > $testing_dir/testing_config.lua
rocks_trees = {
   "$testing_tree",
   { name = "system", root = "$testing_sys_tree" },
}
rocks_servers = {
   "$testing_server"
}
local_cache = "$testing_cache"
upload_server = "testing"
upload_user = "hisham"
upload_servers = {
   testing = {
      rsync = "localhost/tmp/luarocks_testing",
   },
}
external_deps_dirs = {
   "/usr/local",
   "/usr",
   -- These are used for a test that fails, so it
   -- can point to invalid paths:
   {
      prefix = "/opt",
      bin = "bin",
      include = "include",
      lib = { "lib", "lib64" },
   }
}
EOF
(
   cat $testing_dir/testing_config.lua
   echo "show_downloads = true"
) > $testing_dir/testing_config_show_downloads.lua
cat <<EOF > $testing_dir/testing_config_sftp.lua
rocks_trees = {
   "$testing_tree",
   "$testing_sys_tree",
}
local_cache = "$testing_cache"
upload_server = "testing"
upload_user = "hisham"
upload_servers = {
   testing = {
      sftp = "localhost/tmp/luarocks_testing",
   },
}
EOF
cat <<EOF > $testing_dir/luacov.config
return {
  ["configfile"] = ".luacov",
  ["statsfile"] = "$testing_dir/luacov.stats.out",
  ["reportfile"] = "$testing_dir/luacov.report.out",
  runreport = false,
  deletestats = false,
  ["include"] = {},
  ["exclude"] = {
    "luacov$",
    "luacov%.reporter$",
    "luacov%.defaults$",
    "luacov%.runner$",
    "luacov%.stats$",
    "luacov%.tick$",
  },
}
EOF

export LUAROCKS_CONFIG="$testing_dir/testing_config.lua"
export LUA_PATH=
export LUA_CPATH=

if [ "$travis" ]
then
   luadir=/tmp/lua-$luaversion
   pushd /tmp
   if [ ! -e "$luadir/bin/lua" ]
   then
      mkdir -p lua
      echo "Downloading lua $luaversion..."
      wget "http://www.lua.org/ftp/lua-$luaversion.tar.gz" &> /dev/null
      tar zxpf "lua-$luaversion.tar.gz"
      cd "lua-$luaversion"
      echo "Building lua $luaversion..."
      make linux INSTALL_TOP="$luadir" &> /dev/null
      make install INSTALL_TOP="$luadir" &> /dev/null
   fi
   popd
else
   luadir="/Programs/Lua/Current"
fi

if [ `uname -m` = i686 ]
then
   platform="linux-x86"
else
   platform="linux-x86_64"
fi

lua="$luadir/bin/lua"

version_luasocket=3.0rc1
verrev_luasocket=${version_luasocket}-1
srcdir_luasocket=luasocket-3.0-rc1

version_cprint=0.1
verrev_cprint=0.1-1

version_luacov=0.5
verrev_luacov=0.5-1
version_lxsh=0.8.6
version_validate_args=1.5.4
verrev_validate_args=1.5.4-1
verrev_lxsh=${version_lxsh}-2

luasec=luasec

cd ..
./configure --with-lua="$luadir"
make clean
make src/luarocks/site_config.lua
make dev
cd src
basedir=$PWD
run_lua() {
   if [ "$1" = "--noecho" ]; then shift; noecho=1; else noecho=0; fi
   if [ "$1" = "--nocov" ]; then shift; nocov=1; else nocov=0; fi
   if [ "$noecho" = 0 ]
   then
      echo $*
   fi
   cmd=$1
   shift
   if [ "$nocov" = 0 ]
   then
      "$lua" -e"require('luacov.runner')('$testing_dir/luacov.config')" "$basedir/bin/$cmd" "$@"
   else
      "$lua" "$basedir/bin/$cmd" "$@"
   fi
}
luarocks="run_lua luarocks"
luarocks_nocov="run_lua --nocov luarocks"
luarocks_noecho="run_lua --noecho luarocks"
luarocks_noecho_nocov="run_lua --noecho --nocov luarocks"
luarocks_admin="run_lua luarocks-admin"
luarocks_admin_nocov="run_lua --nocov luarocks-admin"

###################################################

mkdir -p "$testing_server"
(
   cd "$testing_server"
   luarocks_repo="http://luarocks.org/repositories/rocks"
   luarocks_scm_repo="http://luarocks.org/repositories/rocks-scm"
   get() { [ -e `basename "$1"` ] || wget -c "$1"; }
   get "$luarocks_repo/luacov-${verrev_luacov}.src.rock"
   get "$luarocks_repo/luacov-${verrev_luacov}.rockspec"
   get "$luarocks_repo/luadoc-3.0.1-1.src.rock"
   get "$luarocks_repo/lualogging-1.3.0-1.src.rock"
   get "$luarocks_repo/luasocket-${verrev_luasocket}.src.rock"
   get "$luarocks_repo/luasocket-${verrev_luasocket}.rockspec"
   get "$luarocks_repo/luafilesystem-1.6.2-1.src.rock"
   get "$luarocks_repo/stdlib-35-1.src.rock"
   get "$luarocks_repo/luarepl-0.4-1.src.rock"
   get "$luarocks_repo/validate-args-1.5.4-1.rockspec"
   get "$luarocks_scm_repo/luasec-scm-1.rockspec"
   get "$luarocks_repo/luabitop-1.0.2-1.rockspec"
   get "$luarocks_repo/lpty-1.0.1-1.src.rock"
   get "$luarocks_repo/cprint-${verrev_cprint}.src.rock"
   get "$luarocks_repo/cprint-${verrev_cprint}.rockspec"
   get "$luarocks_repo/wsapi-1.6-1.src.rock"
   get "$luarocks_repo/lxsh-${verrev_lxsh}.src.rock"
   get "$luarocks_repo/abelhas-1.0-1.rockspec"
   get "$luarocks_repo/lzlib-0.4.work3-1.src.rock"
   get "$luarocks_repo/lpeg-0.12-1.src.rock"
   get "$luarocks_repo/luaposix-31-1.src.rock"
   get "$luarocks_repo/md5-1.2-1.src.rock"
   get "$luarocks_repo/lrandom-20120430.51-1.src.rock"
   get "$luarocks_repo/lrandom-20120430.52-1.src.rock"
   get "$luarocks_repo/lrandom-20120430.51-1.rockspec"
   get "$luarocks_repo/lrandom-20120430.52-1.rockspec"
)
$luarocks_admin_nocov make_manifest "$testing_server"

###################################################

checksum_path() {
   ( cd "$1"; find . -printf "%s %p\n" | md5sum )
}

build_environment() {
   rm -rf "$testing_tree"
   rm -rf "$testing_sys_tree"
   rm -rf "$testing_tree_copy"
   rm -rf "$testing_sys_tree_copy"
   mkdir -p "$testing_tree"
   mkdir -p "$testing_sys_tree"
   $luarocks_admin_nocov make_manifest "$testing_cache"
   for package in "$@"
   do
      $luarocks_nocov install --only-server="$testing_cache" --tree="$testing_sys_tree" $package || {
         $luarocks_nocov build --tree="$testing_sys_tree" $package
         $luarocks_nocov pack --tree="$testing_sys_tree" $package; mv $package-*.rock "$testing_cache"
      }
   done
   eval `$luarocks_noecho_nocov path --bin`
   cp -a "$testing_tree" "$testing_tree_copy"
   cp -a "$testing_sys_tree" "$testing_sys_tree_copy"
   testing_tree_copy_md5=`checksum_path "$testing_tree_copy"`
   testing_sys_tree_copy_md5=`checksum_path "$testing_sys_tree_copy"`
}

reset_environment() {
   testing_tree_md5=`checksum_path "$testing_tree"`
   testing_sys_tree_md5=`checksum_path "$testing_sys_tree"`
   if [ "$testing_tree_md5" != "$testing_tree_copy_md5" ]
   then
      rm -rf "$testing_tree"
      cp -a "$testing_tree_copy" "$testing_tree"
   fi
   if [ "$testing_sys_tree_md5" != "$testing_sys_tree_copy_md5" ]
   then
      rm -rf "$testing_sys_tree"
      cp -a "$testing_sys_tree_copy" "$testing_sys_tree"
   fi
}

need() {
   echo "Obtaining $1 $2..."
   if $luarocks show $1 &> /dev/null
   then
      echo "Already available"
      return
   fi
   platrock="$1-$2.$platform.rock"
   if [ ! -e "$testing_cache/$platrock" ]
   then
      echo "Building $1 $2..."
      $luarocks_nocov build --pack-binary-rock $1 $2
      mv "$platrock" "$testing_cache"
   fi
   echo "Installing $1 $2..."
   $luarocks_nocov install "$testing_cache/$platrock"
   return
}
need_luasocket() { need luasocket $verrev_luasocket; }

# Tests #########################################

test_version() { $luarocks --version; }

fail_arg_server() { $luarocks --server; }
fail_arg_only_server() { $luarocks --only-server; }
fail_unknown_command() { $luarocks unknown_command; }

test_empty_list() { $luarocks list; }

fail_build_noarg() { $luarocks build; }
fail_download_noarg() { $luarocks download; }
fail_install_noarg() { $luarocks install; }
fail_lint_noarg() { $luarocks lint; }
fail_search_noarg() { $luarocks search; }
fail_show_noarg() { $luarocks show; }
fail_unpack_noarg() { $luarocks unpack; }
fail_remove_noarg() { $luarocks remove; }
fail_doc_noarg() { $luarocks doc; }
fail_new_version_noarg() { $luarocks new_version; }
fail_write_rockspec_noarg() { $luarocks write_rockspec; }

fail_build_invalid() { $luarocks build invalid; }
fail_download_invalid() { $luarocks download invalid; }
fail_install_invalid() { $luarocks install invalid; }
fail_lint_invalid() { $luarocks lint invalid; }
fail_show_invalid() { $luarocks show invalid; }
fail_new_version_invalid() { $luarocks new_version invalid; }

fail_make_norockspec() { $luarocks make; }

fail_build_blank_arg() { $luarocks build --tree="" lpeg; }
test_build_withpatch() { need_luasocket; $luarocks build luadoc; }
test_build_diffversion() { $luarocks build luacov ${version_luacov}; }
test_build_command() { $luarocks build stdlib; }
test_build_install_bin() { $luarocks build luarepl; }
test_build_nohttps() { need_luasocket; $luarocks download --rockspec validate-args ${verrev_validate_args} && $luarocks build ./validate-args-${version_validate_args}-1.rockspec && rm ./validate-args-${version_validate_args}-1.rockspec; }
test_build_https() { need_luasocket; $luarocks download --rockspec validate-args ${verrev_validate_args} && $luarocks install $luasec && $luarocks build ./validate-args-${verrev_validate_args}.rockspec && rm ./validate-args-${verrev_validate_args}.rockspec; }
test_build_supported_platforms() { $luarocks build lpty; }
fail_build_missing_external() { $luarocks build "$testing_dir/testfiles/missing_external-0.1-1.rockspec" INEXISTENT_INCDIR="/invalid/dir"; }

test_build_deps_partial_match() { $luarocks build lrandom; }
test_build_show_downloads() { export LUAROCKS_CONFIG="$testing_dir/testing_config_show_downloads.lua" && $luarocks build alien; export LUAROCKS_CONFIG="$testing_dir/testing_config.lua"; }

test_download_all() { $luarocks download --all validate-args && rm validate-args-*; }
test_download_rockspecversion() { $luarocks download --rockspec validate-args ${verrev_validate_args} && rm validate-args-*; }

test_help() { $luarocks help; }

test_install_binaryrock() { $luarocks build --pack-binary-rock cprint && $luarocks install ./cprint-${verrev_cprint}.${platform}.rock && rm ./cprint-${verrev_cprint}.${platform}.rock; }
test_install_with_bin() { $luarocks install wsapi; }
fail_install_notazipfile() { $luarocks install "$testing_dir/testfiles/not_a_zipfile-1.0-1.src.rock"; }

test_lint_ok() { $luarocks download --rockspec validate-args ${verrev_validate_args} && $luarocks lint ./validate-args-${verrev_validate_args}.rockspec && rm ./validate-args-${verrev_validate_args}.rockspec; }
fail_lint_type_mismatch_string() { $luarocks lint "$testing_dir/testfiles/type_mismatch_string-1.0-1.rockspec"; }
fail_lint_type_mismatch_version() { $luarocks lint "$testing_dir/testfiles/type_mismatch_version-1.0-1.rockspec"; }
fail_lint_type_mismatch_table() { $luarocks lint "$testing_dir/testfiles/type_mismatch_table-1.0-1.rockspec"; }

test_list() { $luarocks list; }
test_list_porcelain() { $luarocks list --porcelain; }

test_make_with_rockspec() { rm -rf ./luasocket-${verrev_luasocket} && $luarocks download --src luasocket && $luarocks unpack ./luasocket-${verrev_luasocket}.src.rock && cd luasocket-${verrev_luasocket}/${srcdir_luasocket}  && $luarocks make luasocket-${verrev_luasocket}.rockspec && cd ../.. && rm -rf ./luasocket-${verrev_luasocket}; }
test_make_default_rockspec() { rm -rf ./lxsh-${verrev_lxsh} &&  $luarocks download --src lxsh ${verrev_lxsh} &&  $luarocks unpack ./lxsh-${verrev_lxsh}.src.rock &&  cd lxsh-${verrev_lxsh}/lxsh-${version_lxsh}-1  &&  $luarocks make && cd ../.. && rm -rf ./lxsh-${verrev_lxsh}; }
test_make_pack_binary_rock() { rm -rf ./lxsh-${verrev_lxsh} &&  $luarocks download --src lxsh ${verrev_lxsh} &&  $luarocks unpack ./lxsh-${verrev_lxsh}.src.rock &&  cd lxsh-${verrev_lxsh}/lxsh-${version_lxsh}-1  &&  $luarocks make --deps-mode=none --pack-binary-rock &&  [ -e ./lxsh-${verrev_lxsh}.all.rock ] &&  cd ../.. && rm -rf ./lxsh-${verrev_lxsh}; }
fail_make_which_rockspec() { rm -rf ./luasocket-${verrev_luasocket} && $luarocks download --src luasocket && $luarocks unpack ./luasocket-${verrev_luasocket}.src.rock && cd luasocket-${verrev_luasocket}/${srcdir_luasocket}  && $luarocks make && cd ../.. && rm -rf ./luasocket-${verrev_luasocket}; }

test_new_version() { $luarocks download --rockspec luacov ${version_luacov} &&  $luarocks new_version ./luacov-${version_luacov}-1.rockspec 0.2 && rm ./luacov-0.*; }
test_new_version_url() { $luarocks download --rockspec abelhas 1.0 && $luarocks new_version ./abelhas-1.0-1.rockspec 1.1 https://github.com/downloads/ittner/abelhas/abelhas-1.1.tar.gz && rm ./abelhas-*; }

test_pack() { $luarocks list && $luarocks pack luacov && rm ./luacov-*.rock; }
test_pack_src() { $luarocks install $luasec && $luarocks download --rockspec luasocket && $luarocks pack ./luasocket-${verrev_luasocket}.rockspec && rm ./luasocket-${version_luasocket}-*.rock; }

test_path() { $luarocks path --bin; }
test_path_lr_path() { $luarocks path --lr-path; }
test_path_lr_cpath() { $luarocks path --lr-cpath; }
test_path_lr_bin() { $luarocks path --lr-bin; }

fail_purge_missing_tree() { $luarocks purge --tree="$testing_tree"; }
test_purge() { $luarocks purge --tree="$testing_sys_tree"; }

test_remove() { $luarocks build luacov ${version_luacov} && $luarocks remove luacov ${version_luacov}; }
test_remove_force() { need_luasocket; $luarocks build lualogging && $luarocks remove --force luasocket; }
fail_remove_deps() { need_luasocket; $luarocks build lualogging && $luarocks remove luasocket; }
fail_remove_invalid_name() { $luarocks remove invalid.rock; }

test_search_found() { $luarocks search zlib; }
test_search_missing() { $luarocks search missing_rock; }

test_show() { $luarocks show luacov; }
test_show_modules() { $luarocks show --modules luacov; }
test_show_depends() { need_luasocket; $luarocks install $luasec && $luarocks show luasec; }
test_show_oldversion() { $luarocks install luacov ${version_luacov} && $luarocks show luacov ${version_luacov}; }

test_unpack_download() { rm -rf ./cprint-${verrev_cprint} && $luarocks unpack cprint && rm -rf ./cprint-${verrev_cprint}; }
test_unpack_src() { rm -rf ./cprint-${verrev_cprint} && $luarocks download --src cprint && $luarocks unpack ./cprint-${verrev_cprint}.src.rock && rm -rf ./cprint-${verrev_cprint}; }
test_unpack_rockspec() { rm -rf ./cprint-${verrev_cprint} && $luarocks download --rockspec cprint && $luarocks unpack ./cprint-${verrev_cprint}.rockspec && rm -rf ./cprint-${verrev_cprint}; }
test_unpack_binary() { rm -rf ./cprint-${verrev_cprint} && $luarocks build cprint && $luarocks pack cprint && $luarocks unpack ./cprint-${verrev_cprint}.${platform}.rock && rm -rf ./cprint-${verrev_cprint}; }

test_admin_help() { $luarocks_admin help; }

test_admin_make_manifest() { $luarocks_admin make_manifest; }
test_admin_add_rsync() { if [ "$travis" ]; then return; fi; $luarocks_admin --server=testing add "$testing_server/luasocket-${verrev_luasocket}.src.rock"; }
test_admin_add_sftp() { if [ "$travis" ]; then return; fi; export LUAROCKS_CONFIG="$testing_dir/testing_config_sftp.lua" && $luarocks_admin --server=testing add ./luasocket-${verrev_luasocket}.src.rock; export LUAROCKS_CONFIG="$testing_dir/testing_config.lua"; }
fail_admin_add_missing() { $luarocks_admin --server=testing add; }
fail_admin_invalidserver() { $luarocks_admin --server=invalid add "$testing_server/luasocket-${verrev_luasocket}.src.rock"; }
fail_admin_invalidrock() { if [ "$travis" ]; then return 1; fi; $luarocks_admin --server=testing add invalid; }
test_admin_refresh_cache() { if [ "$travis" ]; then return; fi; $luarocks_admin --server=testing refresh_cache; }
test_admin_remove() { if [ "$travis" ]; then return; fi; $luarocks_admin --server=testing remove luasocket-${verrev_luasocket}.src.rock; }
fail_admin_remove_missing() { $luarocks_admin --server=testing remove; }

fail_deps_mode_invalid_arg() { $luarocks remove luacov --deps-mode; }
test_deps_mode_one() { $luarocks build --tree="system" lpeg && $luarocks list && $luarocks build --deps-mode=one --tree="$testing_tree" lxsh && [ `$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg | wc -l` = 1 ]; }
test_deps_mode_order() { $luarocks build --tree="system" lpeg && $luarocks build --deps-mode=order --tree="$testing_tree" lxsh && $luarocks_noecho list --tree="$testing_tree" --porcelain lpeg && [ `$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg | wc -l` = 0 ]; }
test_deps_mode_order_sys() { $luarocks build --tree="$testing_tree" lpeg && $luarocks build --deps-mode=order --tree="$testing_sys_tree" lxsh && [ `$luarocks_noecho list --tree="$testing_sys_tree" --porcelain lpeg | wc -l` = 1 ]; }
test_deps_mode_all_sys() { $luarocks build --tree="$testing_tree" lpeg && $luarocks build --deps-mode=all --tree="$testing_sys_tree" lxsh && [ `$luarocks_noecho list --tree="$testing_sys_tree" --porcelain lpeg | wc -l` = 0 ]; }
test_deps_mode_none() { $luarocks build --tree="$testing_tree" --deps-mode=none lxsh; [ `$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg | wc -l` = 0 ]; }
test_deps_mode_nodeps_alias() { $luarocks build --tree="$testing_tree" --nodeps lxsh; [ `$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg | wc -l` = 0 ]; }
test_deps_mode_make_order() { $luarocks build --tree="$testing_sys_tree" lpeg && rm -rf ./lxsh-${verrev_lxsh} && $luarocks download --src lxsh ${verrev_lxsh} && $luarocks unpack ./lxsh-${verrev_lxsh}.src.rock && cd lxsh-${verrev_lxsh}/lxsh-${version_lxsh}-1  && $luarocks make --tree="$testing_tree" --deps-mode=order && cd ../.. && [ `$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg | wc -l` = 0 ] && rm -rf ./lxsh-${verrev_lxsh}; }
test_deps_mode_make_order_sys() { $luarocks build --tree="$testing_tree" lpeg && rm -rf ./lxsh-${verrev_lxsh} && $luarocks download --src lxsh ${verrev_lxsh} && $luarocks unpack ./lxsh-${verrev_lxsh}.src.rock && cd lxsh-${verrev_lxsh}/lxsh-${version_lxsh}-1  && $luarocks make --tree="$testing_sys_tree" --deps-mode=order && cd ../.. && [ `$luarocks_noecho list --tree="$testing_tree" --porcelain lpeg | wc -l` = 1 ] && rm -rf ./lxsh-${verrev_lxsh}; }

test_write_rockspec() { $luarocks write_rockspec git://github.com/keplerproject/luarocks; }
test_write_rockspec_lib() { $luarocks write_rockspec git://github.com/mbalmer/luafcgi --lib=fcgi --license="3-clause BSD" --lua-version=5.1,5.2; }
test_write_rockspec_fullargs() { $luarocks write_rockspec git://github.com/keplerproject/luarocks --lua-version=5.1,5.2 --license="MIT/X11" --homepage="http://www.luarocks.org" --summary="A package manager for Lua modules"; }
fail_write_rockspec_args() { $luarocks write_rockspec invalid; }
fail_write_rockspec_args_url() { $luarocks write_rockspec http://example.com/invalid.zip; }
test_write_rockspec_http() { $luarocks write_rockspec http://luarocks.org/releases/luarocks-2.1.0.tar.gz --lua-version=5.1; }
test_write_rockspec_basedir() { $luarocks write_rockspec https://github.com/downloads/Olivine-Labs/luassert/luassert-1.2.tar.gz --lua-version=5.1; }

test_doc() { $luarocks install luarepl; $luarocks doc luarepl; }

# Driver #########################################

run_tests() {
   grep "^test_$1.*(" < $testing_dir/testing.sh | cut -d'(' -f1 | while read test
   do
      echo "-------------------------------------------"
      echo "$test"
      echo "-------------------------------------------"
      reset_environment
      if $test
      then echo "OK: Expected success."
      else echo "FAIL: Unexpected failure."; exit 1
      fi
   done
   grep "^fail_$1.*(" < $testing_dir/testing.sh | cut -d'(' -f1 | while read test
   do
      echo "-------------------------------------------"
      echo "$test"
      echo "-------------------------------------------"
      reset_environment
      if $test
      then echo "FAIL: Unexpected success."; exit 1
      else echo "OK: Expected failure."
      fi
   done
}

run_with_minimal_environment() {
   echo "==========================================="
   echo "Running with minimal environment"
   echo "==========================================="
   build_environment luacov
   run_tests $1
}

run_with_full_environment() {
   echo "==========================================="
   echo "Running with full environment"
   echo "==========================================="
   build_environment luacov luafilesystem luasocket luabitop luaposix md5 lzlib
   run_tests $1
}

run_all_tests() {
   run_with_minimal_environment $1
   run_with_full_environment $1
}

run_all_tests $1
#run_with_minimal_environment $1

$testing_sys_tree/bin/luacov -c $testing_dir/luacov.config src/luarocks src/bin

if [ "$travis" ]
then
   grep "Summary" -B1 -A1000 $testing_dir/luacov.report.out
else
   cat "$testing_dir/luacov.report.out"
fi

