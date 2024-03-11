#!/bin/sh -e

tarball="$1"

rm -rf smoketestdir
mkdir smoketestdir
cp "$tarball" smoketestdir
cd smoketestdir

tar zxvpf "$(basename "$tarball")"
cd "$(basename "$tarball" .tar.gz)"

if [ "$2" = "binary" ]
then
   ./configure --prefix=foobar
   make binary
   make install-binary
   cd foobar
   bin/luarocks
   bin/luarocks install inspect
   bin/luarocks show inspect
   (
      eval $(bin/luarocks path)
      lua -e 'print(assert(require("inspect")(_G)))'
   )
   cd ..
   rm -rf foobar
   exit 0
fi

################################################################################
# test installation with make install
################################################################################

./configure --prefix=foobar
make
make install
cd foobar
bin/luarocks --verbose
bin/luarocks --verbose install inspect
bin/luarocks --verbose show inspect
(
   eval $(bin/luarocks path)
   lua -e 'print(assert(require("inspect")(_G)))'
)
bin/luarocks --verbose remove inspect
cd ..
rm -rf foobar

################################################################################
# test installation with make bootstrap
################################################################################

./configure --prefix=fooboot
make bootstrap
./luarocks --verbose
./luarocks --verbose install inspect
./luarocks --verbose show inspect
./lua -e 'print(assert(require("inspect")(_G)))'
./luarocks --verbose remove inspect
cd fooboot
bin/luarocks --verbose
bin/luarocks --verbose install inspect
bin/luarocks --verbose show inspect
(
   eval $(bin/luarocks path)
   lua -e 'print(assert(require("inspect")(_G)))'
)
bin/luarocks --verbose remove inspect
cd ..
rm -rf fooboot

################################################################################
# test installation with luarocks install
################################################################################

./configure --prefix=foorock
make bootstrap
./luarocks make --pack-binary-rock
cd foorock
bin/luarocks install ../luarocks-*-1.all.rock
bin/luarocks --verbose
bin/luarocks --verbose install inspect
bin/luarocks --verbose show inspect
bin/luarocks install ../luarocks-*-1.all.rock --tree=../foorock2
bin/luarocks --verbose remove inspect
cd ../foorock2
bin/luarocks --verbose
bin/luarocks --verbose install inspect
bin/luarocks --verbose show inspect
(
   eval $(bin/luarocks path)
   lua -e 'print(assert(require("inspect")(_G)))'
)
bin/luarocks --verbose remove inspect
cd ..
rm -rf foorock
rm -rf foorock2

################################################################################

if [ "$3" = "windows" ]
then
   make windows-binary
fi

cd ..
rm -rf smoketestdir
echo
echo "Full test ran and nothing caught fire!"
echo
