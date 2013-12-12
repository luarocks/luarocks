#!/bin/bash -ex

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
rm -rf "$testing_dir/testing_config.lua"
rm -rf "$testing_dir/testing_config_show_downloads.lua"
rm -rf "$testing_dir/testing_config_sftp.lua"
rm -rf "$testing_dir/luacov.config"

[ "$1" = "clean" ] && {
   rm -f luacov.stats.out
   exit 0
}

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

luaversion=5.2.3
if [ "$travis" ]
then
   pushd /tmp
   if [ ! -e "lua/bin/lua" ]
   then
      mkdir -p lua
      wget "http://www.lua.org/ftp/lua-$luaversion.tar.gz"
      tar zxvpf "lua-$luaversion.tar.gz"
      cd "lua-$luaversion"
      make linux INSTALL_TOP=/tmp/lua
      make install INSTALL_TOP=/tmp/lua
   fi
   popd
   luadir=/tmp/lua
   platform="linux-x86_64"
else
   luadir="/Programs/Lua/Current"
   platform="linux-x86"
fi
lua="$luadir/bin/lua"

version_luasocket=3.0rc1
verrev_luasocket=${version_luasocket}-1
srcdir_luasocket=luasocket-3.0-rc1

version_luacov=0.3
version_lxsh=0.8.6
version_validate_args=1.5.4
verrev_lxsh=${version_lxsh}-2

# will change to luasec=luasec once LuaSec for Lua 5.2 is released
luasec="http://luarocks.org/repositories/rocks-scm/luasec-scm-1.rockspec"
#luasec=luasec

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


test_unpack_src() { rm -rf ./luasocket-${verrev_luasocket} && $luarocks download --src luasocket && $luarocks unpack ./luasocket-${verrev_luasocket}.src.rock && rm -rf ./luasocket-${verrev_luasocket}; }
test_unpack_rockspec() { rm -rf ./luasocket-${verrev_luasocket} && $luarocks download --rockspec luasocket && $luarocks unpack ./luasocket-${verrev_luasocket}.rockspec && rm -rf ./luasocket-${verrev_luasocket}; }
test_unpack_binary() { rm -rf ./luasocket-${verrev_luasocket} && $luarocks build luasocket && $luarocks pack luasocket && $luarocks unpack ./luasocket-${verrev_luasocket}.${platform}.rock && rm -rf ./luasocket-${verrev_luasocket}; }



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
