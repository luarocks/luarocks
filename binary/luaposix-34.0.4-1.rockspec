local _MODREV, _SPECREV = '34.0.4', '-1'

package = 'luaposix'
version = _MODREV .. _SPECREV

description = {
   summary = 'Lua bindings for POSIX',
   detailed = [[
      A library binding various POSIX APIs. POSIX is the IEEE Portable
      Operating System Interface standard. luaposix is based on lposix.
   ]],
   homepage = 'http://github.com/luaposix/luaposix/',
   license = 'MIT/X11',
}

dependencies = {
   'bit32',
   'lua >= 5.1, < 5.4',
   'std.normalize',
}

source = {
   url = 'http://github.com/luaposix/luaposix/archive/v' .. _MODREV .. '.zip',
   dir = 'luaposix-' .. _MODREV,  
}

build = {
   type = 'command',
   build_command = '$(LUA) build-aux/luke'
      .. ' package="' .. package .. '"'
      .. ' version="' .. _MODREV .. '"'
      .. ' PREFIX="$(PREFIX)"'
      .. ' LUA="$(LUA)"'
      .. ' LUA_INCDIR="$(LUA_INCDIR)"'
      .. ' CFLAGS="$(CFLAGS)"'
      .. ' LIBFLAG="$(LIBFLAG)"'
      .. ' LIB_EXTENSION="$(LIB_EXTENSION)"'
      .. ' OBJ_EXTENSION="$(OBJ_EXTENSION)"'
      .. ' INST_LIBDIR="$(LIBDIR)"'
      .. ' INST_LUADIR="$(LUADIR)"'
      ,
   install_command = '$(LUA) build-aux/luke install --quiet'
      .. ' INST_LIBDIR="$(LIBDIR)"'
      .. ' LIB_EXTENSION="$(LIB_EXTENSION)"'
      .. ' INST_LUADIR="$(LUADIR)"'
      ,
}

if _MODREV == 'git' then
   dependencies[#dependencies + 1] = 'ldoc'

   source = {
      url = 'git://github.com/luaposix/luaposix.git',
   }
end
