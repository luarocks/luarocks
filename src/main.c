#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct {
   char* module_name;
   char* source_name;
   int length;
   const unsigned char* code;
} Gen;

#include "gen/gen.h"
#include "gen/libraries.h"

static const char* progname = "luarocks";

/* portable alerts, from srlua */
#ifdef _WIN32
#include <windows.h>
#define alert(message)  MessageBox(NULL, message, progname, MB_ICONERROR | MB_OK)
#define getprogname()   char name[MAX_PATH]; argv[0]= GetModuleFileName(NULL,name,sizeof(name)) ? name : NULL;
#else
#define alert(message)  fprintf(stderr,"%s: %s\n", progname, message)
#define getprogname()
#endif

static int registry_key;

/* fatal error, from srlua */
static void fatal(const char* message) {
   alert(message);
   exit(EXIT_FAILURE);
}

static void load_main(lua_State* L) {
   #include "gen/main.h"

   if (luaL_loadbuffer(L, luarocks_gen_main, sizeof(luarocks_gen_main), progname) != LUA_OK) {
      fatal(lua_tostring(L, -1));
   }
}


static void declare_modules(lua_State* L) {
   lua_settop(L, 0);                                /* */
   lua_newtable(L);                                 /* modules */
   lua_pushlightuserdata(L, (void*) &registry_key); /* modules registry_key */
   lua_pushvalue(L, 1);                             /* modules registry_key modules */
   lua_rawset(L, LUA_REGISTRYINDEX);                /* modules */

   for (int i = 0; GEN[i].module_name; i++) {
      const Gen* entry = &GEN[i];
      luaL_loadbuffer(L, entry->code, entry->length, entry->source_name);
      lua_setfield(L, 1, entry->module_name);
   }
}


/* custom package loader */
static int pkg_loader(lua_State* L) {
   lua_pushlightuserdata(L, (void*) &registry_key); /* modname ? registry_key */
   lua_rawget(L, LUA_REGISTRYINDEX);                /* modname ? modules */
   lua_pushvalue(L, -1);                            /* modname ? modules modules */
   lua_pushvalue(L, 1);                             /* modname ? modules modules modname */
   lua_gettable(L, -2);                             /* modname ? modules mod */
   if (lua_type(L, -1) == LUA_TNIL) {
      lua_pop(L, 1);                                /* modname ? modules */
      lua_pushvalue(L, 1);                          /* modname ? modules modname */
      lua_pushliteral(L, ".init");                  /* modname ? modules modname ".init" */
      lua_concat(L, 2);                             /* modname ? modules modname..".init" */
      lua_gettable(L, -2);                          /* modname ? mod */
   }
   return 1;
}

static void install_pkg_loader(lua_State* L) {
   lua_settop(L, 0);                                /* */
   lua_getglobal(L, "table");                       /* table */
   lua_getfield(L, -1, "insert");                   /* table table.insert */
   lua_getglobal(L, "package");                     /* table table.insert package */
   lua_getfield(L, -1, "searchers");                /* table table.insert package package.searchers */
   if (lua_type(L, -1) == LUA_TNIL) {
      lua_pop(L, 1);
      lua_getfield(L, -1, "loaders");               /* table table.insert package package.loaders */
   }
   lua_copy(L, 4, 3);                               /* table table.insert package.searchers */
   lua_settop(L, 3);                                /* table table.insert package.searchers */
   lua_pushnumber(L, 1);                            /* table table.insert package.searchers 1 */
   lua_pushcfunction(L, pkg_loader);                /* table table.insert package.searchers 1 pkg_loader */
   lua_call(L, 3, 0);                               /* table */
   lua_settop(L, 0);                                /* */
}

/* main script launcher, from srlua */
static int pmain(lua_State *L) {
   int argc = lua_tointeger(L, 1);
   char** argv = lua_touserdata(L, 2);
   int i;
   load_main(L);
   lua_createtable(L, argc, 0);
   for (i = 0; i < argc; i++) {
      lua_pushstring(L, argv[i]);
      lua_rawseti(L, -2, i);
   }
   lua_setglobal(L, "arg");
   luaL_checkstack(L, argc - 1, "too many arguments to script");
   for (i = 1; i < argc; i++) {
      lua_pushstring(L, argv[i]);
   }
   lua_call(L, argc - 1, 0);
   return 0;
}

/* error handler, from luac */
static int msghandler (lua_State *L) {
   /* is error object not a string? */
   const char *msg = lua_tostring(L, 1);
   if (msg == NULL) {
      /* does it have a metamethod that produces a string */
      if (luaL_callmeta(L, 1, "__tostring") && lua_type(L, -1) == LUA_TSTRING) {
         /* then that is the message */
         return 1;
      } else {
         msg = lua_pushfstring(L, "(error object is a %s value)", luaL_typename(L, 1));
      }
   }
   /* append a standard traceback */
   luaL_traceback(L, L, msg, 1);
   return 1;
}

/* main function, from srlua */
int main(int argc, char** argv) {
   lua_State* L;
   getprogname();
   if (argv[0] == NULL) {
      fatal("cannot locate this executable");
   }
   L = luaL_newstate();
   if (L == NULL) {
      fatal("not enough memory for state");
   }
   luaL_openlibs(L);
   install_pkg_loader(L);
   declare_libraries(L);
   declare_modules(L);
   lua_pushcfunction(L, &msghandler);
   lua_pushcfunction(L, &pmain);
   lua_pushinteger(L, argc);
   lua_pushlightuserdata(L, argv);
   if (lua_pcall(L, 2, 0, -4) != 0) {
      fatal(lua_tostring(L, -1));
   }
   lua_close(L);
   return EXIT_SUCCESS;
}

