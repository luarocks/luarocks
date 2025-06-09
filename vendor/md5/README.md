# MD5 - Cryptographic Library for Lua

http://keplerproject.github.io/md5/

MD5 offers basic cryptographic facilities for Lua 5.1: a hash (digest)
function, a pair crypt/decrypt based on MD5 and CFB, and a pair crypt/decrypt based
on DES with 56-bit keys.

MD5 current version is 1.2.

Please check the documentation at /doc/us/ for more information.

## Installation

To install using [LuaRocks](https://github.com/keplerproject/luarocks) run:

```
luarocks install md5
```

To install on Linux/OSX/BSD, please edit the config file and then call

```
make
make install
```

The last step may require root privileges.

## History

Version 1.2 [06/Sep/2013]

* Code adapted to compile for Lua 5.0, 5.1 and 5.2

Version 1.1.2 [12/May/2008]

* Fixed bug in 64-bit systems
* Fixed the Windows makefile to accept longer directory names
  (patch by Alessandro Hecht and Ignacio Burgueño).


## License

MD5 is free software and uses the same license as Lua (MIT). 

The DES 56 C library was implemented by Stuart Levy and uses a MIT license too (check the source).
