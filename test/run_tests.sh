#!/bin/bash

if [ -e ./run_tests.sh ]
then
   cd ../src
elif [ -d src ]
then
   cd src
elif ! [ -d luarocks ]
then
   echo "Go to the src directory and run this."
   exit 1
fi

if [ ! -d ../rocks ]
then
   echo "Downloading entire rocks repository for tests"
   cd ..
   cp -a ~/.cache/luarocks/rocks .
   cd src
fi

rocks=(
   `ls ../rocks/*.src.rock | grep -v luacom`
)

bin/luarocks-admin make-manifest ../rocks || exit 1

[ "$1" ] && rocks=("$1")

TRY() {
   "$@" || {
      echo "Failed running: $@"
      exit 1
   }
}

list_search() {
   bin/luarocks list $name | grep $version
}

for rock in "${rocks[@]}"
do
   base=`basename $rock`
   baserockspec=`basename $rock .rockspec`
   basesrcrock=`basename $rock .src.rock`
   if [ "$base" != "$baserockspec" ]
   then
      base=$baserockspec
      name=`echo $base | sed 's/\(.*\)-[^-]*-[^-]*$/\1/'`
      version=`echo $base | sed 's/.*-\([^-]*-[^-]*\)$/\1/'`
      TRY bin/luarocks pack $rock
      TRY bin/luarocks build $base.src.rock
      TRY rm $base.src.rock
   else
      base=$basesrcrock
      name=`echo $base | sed 's/\(.*\)-[^-]*-[^-]*$/\1/'`
      version=`echo $base | sed 's/.*-\([^-]*-[^-]*\)$/\1/'`
      TRY bin/luarocks build $rock
   fi
   TRY bin/luarocks pack $name $version
   TRY bin/luarocks install $base.*.rock
   TRY rm $base.*.rock
   TRY list_search $name $version
   bin/luarocks remove $name $version
   # TODO: differentiate between error and dependency block.
done

if bin/luarocks install nonexistant | grep "No results"
then echo "OK, got expected error."
else exit 1
fi

TRY ../test/test_deps.lua
TRY ../test/test_require.lua
