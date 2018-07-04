#!/bin/sh -e

tarball="$1"

rm -rf smoketestdir
mkdir smoketestdir
cp "$tarball" smoketestdir
cd smoketestdir

tar zxvpf "$(basename "$tarball")"
cd "$(basename "$tarball" .tar.gz)"
./configure --prefix=foobar
make
./luarocks --verbose
./luarocks --verbose install inspect
./luarocks --verbose show inspect
./lua -e 'print(assert(require("inspect")(_G)))'
make install
cd foobar
bin/luarocks --verbose
bin/luarocks --verbose install inspect
bin/luarocks --verbose show inspect
(
   eval $(bin/luarocks path)
   lua -e 'print(assert(require("inspect")(_G)))'
)
cd ..
rm -rf foobar

if [ "$2" = "binary" ]
then
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
fi

if [ "$3" = "windows" ]
then
   make windows-binary
fi

cd ..
rm -rf smoketestdir
echo
echo "Full test ran and nothing caught fire!"
echo
