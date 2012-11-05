#!/bin/sh -e

# Setup #########################################

[ -e ../configure ] || {
   echo "Please run this from the test/ directory."
   exit 1
}

testing_dir="$PWD"

testing_tree="$testing_dir/testing"
testing_sys_tree="$testing_dir/testing_sys"
testing_tree_copy="$testing_dir/testing_copy"
testing_sys_tree_copy="$testing_dir/testing_sys_copy"
testing_cache="$testing_dir/testing_cache"

[ "$1" ] || rm -f luacov.stats.out
rm -f luacov.report.out
rm -rf /tmp/luarocks_testing
mkdir /tmp/luarocks_testing
rm -rf "$testing_tree"
rm -rf "$testing_sys_tree"
rm -rf "$testing_tree_copy"
rm -rf "$testing_sys_tree_copy"
rm -rf "$testing_cache"

cat <<EOF > $testing_dir/testing_config.lua
rocks_trees = {
   "$testing_tree",
   "$testing_sys_tree",
}
local_cache = "$testing_cache"
upload_server = "testing"
upload_user = "hisham"
upload_servers = {
   testing = {
      rsync = "localhost/tmp/luarocks_testing",
   },
}
EOF
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

luadir="/Programs/Lua/Current"
lua="$luadir/bin/lua"

cd ..
./configure --with-lua="$luadir"
make clean
make src/luarocks/site_config.lua
make dev
cd src

echo $LUA_PATH

luarocks_nocov="$lua $PWD/bin/luarocks"
luarocks="$lua -erequire('luacov.runner')('$testing_dir/luacov.config') $PWD/bin/luarocks"
luarocks_admin="$lua -erequire('luacov.runner')('$testing_dir/luacov.config') $PWD/bin/luarocks-admin"

$luarocks_nocov download luacov

build_environment() {
   rm -rf "$testing_tree"
   rm -rf "$testing_sys_tree"
   rm -rf "$testing_tree_copy"
   rm -rf "$testing_sys_tree_copy"
   mkdir -p "$testing_tree"
   mkdir -p "$testing_sys_tree"
   for package in "$@"
   do
      $luarocks_nocov build --tree="$testing_sys_tree" $package
   done
   eval `$luarocks_nocov path --bin`
   cp -a "$testing_tree" "$testing_tree_copy"
   cp -a "$testing_sys_tree" "$testing_sys_tree_copy"
}

reset_environment() {
   rm -rf "$testing_tree"
   rm -rf "$testing_sys_tree"
   cp -a "$testing_tree_copy" "$testing_tree"
   cp -a "$testing_sys_tree_copy" "$testing_sys_tree"
}

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
fail_new_version_noarg() { $luarocks new_version; }

fail_build_invalid() { $luarocks build invalid; }
fail_download_invalid() { $luarocks download invalid; }
fail_install_invalid() { $luarocks install invalid; }
fail_lint_invalid() { $luarocks lint invalid; }
fail_show_invalid() { $luarocks show invalid; }
fail_new_version_invalid() { $luarocks new_version invalid; }

fail_make_norockspec() { $luarocks make; }

fail_build_blank_arg() { $luarocks build --tree="" lpeg; }
test_build_withpatch() { $luarocks build luadoc; }
test_build_diffversion() { $luarocks build luacov 0.1; }
test_build_command() { $luarocks build stdlib; }
test_build_install_bin() { $luarocks build luarepl; }
fail_build_nohttps() { $luarocks install luasocket && $luarocks download --rockspec validate-args 1.5.4 && $luarocks build ./validate-args-1.5.4-1.rockspec && rm ./validate-args-1.5.4-1.rockspec; }
test_build_https() { $luarocks download --rockspec validate-args 1.5.4 && $luarocks install luasec && $luarocks build ./validate-args-1.5.4-1.rockspec && rm ./validate-args-1.5.4-1.rockspec; }
test_build_supported_platforms() { $luarocks build xctrl; }

test_download_all() { $luarocks download --all validate-args && rm validate-args-*; }
test_download_rockspecversion() { $luarocks download --rockspec validate-args 1.5.4 && rm validate-args-*; }

test_help() { $luarocks help; }

test_install_binaryrock() { $luarocks build luasocket && $luarocks pack luasocket && $luarocks install ./luasocket-2.0.2-5.linux-x86.rock && rm ./luasocket-2.0.2-5.linux-x86.rock; }
test_install_with_bin() { $luarocks install wsapi; }

test_lint_ok() { $luarocks download --rockspec validate-args 1.5.4 && $luarocks lint ./validate-args-1.5.4-1.rockspec && rm ./validate-args-1.5.4-1.rockspec; }

test_list() { $luarocks list; }
test_list_porcelain() { $luarocks list --porcelain; }

test_make() { rm -rf ./luasocket-2.0.2-5 && $luarocks download --src luasocket && $luarocks unpack ./luasocket-2.0.2-5.src.rock && cd luasocket-2.0.2-5/luasocket-2.0.2  && $luarocks make && cd ../.. && rm -rf ./luasocket-2.0.2-5; }
test_make_pack_binary_rock() { rm -rf ./lxsh-0.8.6-1 &&  $luarocks download --src lxsh 0.8.6-1 &&  $luarocks unpack ./lxsh-0.8.6-1.src.rock &&  cd lxsh-0.8.6-1/lxsh-0.8.6-1  &&  $luarocks make --deps-mode=none --pack-binary-rock &&  [ -e ./lxsh-0.8.6-1.all.rock ] &&  cd ../.. && rm -rf ./lxsh-0.8.6-1; }

test_new_version() { $luarocks download --rockspec luacov 0.1 &&  $luarocks new_version ./luacov-0.1-1.rockspec 0.2 && rm ./luacov-0.*; }

test_pack() { $luarocks list && $luarocks pack luacov && rm ./luacov-*.rock; }
test_pack_src() { $luarocks download --rockspec luasocket && $luarocks pack ./luasocket-2.0.2-5.rockspec && rm ./luasocket-2.0.2-*.rock; }

test_path() { $luarocks path --bin; }

fail_purge_missing_tree() { $luarocks purge --tree="$testing_tree"; }
test_purge() { $luarocks purge --tree="$testing_sys_tree"; }

test_remove() { $luarocks build luacov 0.1 && $luarocks remove luacov 0.1; }
#fail_remove_deps() { $luarocks build luadoc && $luarocks remove luasocket; }

test_search_found() { $luarocks search zlib; }
test_search_missing() { $luarocks search missing_rock; }

test_show() { $luarocks show luacov; }
test_show_modules() { $luarocks show --modules luacov; }
test_show_depends() { $luarocks install luasec && $luarocks show luasec; }
test_show_oldversion() { $luarocks install luacov 0.1 && $luarocks show luacov 0.1; }

test_unpack_download() { rm -rf ./luasocket-2.0.2-5 && $luarocks unpack luasocket && rm -rf ./luasocket-2.0.2-5; }
test_unpack_src() { rm -rf ./luasocket-2.0.2-5 && $luarocks download --src luasocket && $luarocks unpack ./luasocket-2.0.2-5.src.rock && rm -rf ./luasocket-2.0.2-5; }
test_unpack_rockspec() { rm -rf ./luasocket-2.0.2-5 && $luarocks download --rockspec luasocket && $luarocks unpack ./luasocket-2.0.2-5.rockspec && rm -rf ./luasocket-2.0.2-5; }
test_unpack_binary() { rm -rf ./luasocket-2.0.2-5 && $luarocks build luasocket && $luarocks pack luasocket && $luarocks unpack ./luasocket-2.0.2-5.linux-x86.rock && rm -rf ./luasocket-2.0.2-5; }

test_admin_help() { $luarocks_admin help; }

test_admin_make_manifest() { $luarocks_admin make_manifest; }
test_admin_add_rsync() { $luarocks_admin --server=testing add ./luasocket-2.0.2-5.src.rock; }
test_admin_add_sftp() { export LUAROCKS_CONFIG="$testing_dir/testing_config_sftp.lua" && $luarocks_admin --server=testing add ./luasocket-2.0.2-5.src.rock; export LUAROCKS_CONFIG="$testing_dir/testing_config.lua"; }
fail_admin_add_missing() { $luarocks_admin --server=testing add; }
fail_admin_invalidserver() { $luarocks_admin --server=invalid add ./luasocket-2.0.2-5.src.rock; }
fail_admin_invalidrock() { $luarocks_admin --server=testing add invalid; }
test_admin_refresh_cache() { $luarocks_admin --server=testing refresh_cache; }
test_admin_remove() { $luarocks_admin --server=testing remove luasocket; }
fail_admin_remove_missing() { $luarocks_admin --server=testing remove; }

fail_deps_mode_invalid_arg() { $luarocks remove luacov --deps-mode; }
test_deps_mode_one() { $luarocks build --tree="$testing_sys_tree" lpeg && $luarocks list && $luarocks build --deps-mode=one --tree="$testing_tree" lxsh && [ `$luarocks list --tree="$testing_tree" --porcelain lpeg | wc -l` = 1 ]; }
test_deps_mode_order() { $luarocks build --tree="$testing_sys_tree" lpeg && $luarocks build --deps-mode=order --tree="$testing_tree" lxsh && [ `$luarocks list --tree="$testing_tree" --porcelain lpeg | wc -l` = 0 ]; }
test_deps_mode_order_sys() { $luarocks build --tree="$testing_tree" lpeg && $luarocks build --deps-mode=order --tree="$testing_sys_tree" lxsh && [ `$luarocks list --tree="$testing_sys_tree" --porcelain lpeg | wc -l` = 1 ]; }
test_deps_mode_all_sys() { $luarocks build --tree="$testing_tree" lpeg && $luarocks build --deps-mode=all --tree="$testing_sys_tree" lxsh && [ `$luarocks list --tree="$testing_sys_tree" --porcelain lpeg | wc -l` = 0 ]; }
test_deps_mode_none() { $luarocks build --tree="$testing_tree" --deps-mode=none lxsh; [ `$luarocks list --tree="$testing_tree" --porcelain lpeg | wc -l` = 0 ]; }
test_deps_mode_nodeps_alias() { $luarocks build --tree="$testing_tree" --nodeps lxsh; [ `$luarocks list --tree="$testing_tree" --porcelain lpeg | wc -l` = 0 ]; }
test_deps_mode_make_order() { $luarocks build --tree="$testing_sys_tree" lpeg && rm -rf ./lxsh-0.8.6-1 && $luarocks download --src lxsh 0.8.6-1 && $luarocks unpack ./lxsh-0.8.6-1.src.rock && cd lxsh-0.8.6-1/lxsh-0.8.6-1  && $luarocks make --tree="$testing_tree" --deps-mode=order && cd ../.. && [ `$luarocks list --tree="$testing_tree" --porcelain lpeg | wc -l` = 0 ] && rm -rf ./lxsh-0.8.6-1; }
test_deps_mode_make_order_sys() { $luarocks build --tree="$testing_tree" lpeg && rm -rf ./lxsh-0.8.6-1 && $luarocks download --src lxsh 0.8.6-1 && $luarocks unpack ./lxsh-0.8.6-1.src.rock && cd lxsh-0.8.6-1/lxsh-0.8.6-1  && $luarocks make --tree="$testing_sys_tree" --deps-mode=order && cd ../.. && [ `$luarocks list --tree="$testing_tree" --porcelain lpeg | wc -l` = 1 ] && rm -rf ./lxsh-0.8.6-1; }

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
   build_environment luacov
   run_tests $1
}

run_with_full_environment() {
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

cat $testing_dir/luacov.report.out
