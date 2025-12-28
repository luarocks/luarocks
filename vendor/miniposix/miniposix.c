#include <lua.h>
#include <lauxlib.h>

#include <errno.h>
#include <fcntl.h>
#include <pwd.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <sys/types.h>

static int miniposix_chmod(lua_State* L) {
   const char* filename = luaL_checkstring(L, 1);
   const char* permissions = luaL_checkstring(L, 2);
   mode_t mode = 0;

   if (strlen(permissions) != 9) {
      return luaL_error(L, "invalid permissions string (expected \"rwxrwxrwx\" format)");
   }

   if (permissions[0] == 'r') { mode |= S_IRUSR; }
   if (permissions[1] == 'w') { mode |= S_IWUSR; }
   if (permissions[2] == 'x') { mode |= S_IXUSR; }
   if (permissions[3] == 'r') { mode |= S_IRGRP; }
   if (permissions[4] == 'w') { mode |= S_IWGRP; }
   if (permissions[5] == 'x') { mode |= S_IXGRP; }
   if (permissions[6] == 'r') { mode |= S_IROTH; }
   if (permissions[7] == 'w') { mode |= S_IWOTH; }
   if (permissions[8] == 'x') { mode |= S_IXOTH; }

   int err = chmod(filename, mode);

   if (err == 0) {
      lua_pushboolean(L, 1);
      return 1;
   }

   lua_pushboolean(L, 0);
   lua_pushstring(L, strerror(errno));
   return 2;
}

static int miniposix_umask(lua_State* L) {
   mode_t mode = umask(0);
   mode = umask(mode);

   lua_pushinteger(L, mode);
   return 1;
}

static int miniposix_getpwuid(lua_State* L) {
   const char* filename = luaL_checkstring(L, 1);

   struct passwd* data = getpwnam(filename);

   if (!data) {
      lua_pushboolean(L, 0);
      lua_pushstring(L, strerror(errno));
      return 2;
   }

   lua_newtable(L);
   lua_pushstring(L, data->pw_name);
   lua_setfield(L, -2, "pw_name");

   return 1;
}

static int miniposix_geteuid(lua_State* L) {
   lua_pushinteger(L, geteuid());
   return 1;
}

static int miniposix_mkdtemp(lua_State* L) {
   char* template = strdup(luaL_checkstring(L, 1));

   char* updated = mkdtemp(template);

   if (!updated) {
      free(template);
      lua_pushboolean(L, 0);
      lua_pushstring(L, strerror(errno));
      return 2;
   }

   lua_pushstring(L, updated);
   free(updated);
   return 1;
}

static struct luaL_Reg miniposix_lib[] = {
   {"chmod",  miniposix_chmod},
   {"umask", miniposix_umask},
   {"getpwuid", miniposix_getpwuid},
   {"geteuid", miniposix_geteuid},
   {"mkdtemp", miniposix_mkdtemp},
   {NULL, NULL}
};

int luaopen_miniposix(lua_State* L) {
   lua_newtable(L);
   for (int i = 0; miniposix_lib[i].name; i++) {
      lua_pushcfunction(L, miniposix_lib[i].func);
      lua_setfield(L, -2, miniposix_lib[i].name);
   }
   return 1;
}
