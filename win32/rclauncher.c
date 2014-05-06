
/*
** Simple Lua interpreter.
** This program is used to run a Lua file embedded as a resource.
** It creates a Lua state, opens all its standard libraries, and run
** the Lua file in a protected environment just to redirect the error
** messages to stdout and stderr.
**
** $Id: rclauncher.c,v 1.1 2008/06/30 14:29:59 carregal Exp $
*/

#include <string.h>
#include <stdlib.h>

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"
#include <windows.h>
#include <io.h>
#include <fcntl.h>

/*
** Report error message.
** Assumes that the error message is on top of the stack.
*/
static int report (lua_State *L) {
        fprintf (stderr, "lua: fatal error: `%s'\n", lua_tostring (L, -1));
        fflush (stderr);
        printf ("Content-type: text/plain\n\nConfiguration fatal error: see error log!\n");
        printf ("%s", lua_tostring(L, -1));
        return 1;
}

static int runlua (lua_State *L, const char *lua_string, int argc, char *argv[]) {
        int err_func;
        int err;

        lua_getglobal(L, "debug");
        lua_pushliteral(L, "traceback");
        lua_gettable(L, -2);
        err_func = lua_gettop (L);
        err = luaL_loadstring (L, lua_string);
        if(!err) {
          int i;
          // fill global arg table
          lua_getglobal(L, "arg");
          for(i = 1; i < argc; i++)
          {
            lua_pushstring(L, argv[i]);
                lua_rawseti(L, -2, i);
          }
          lua_pop(L, 1);
          // fill parameters (in vararg '...')
          for(i = 1; i < argc; i++)
            lua_pushstring(L, argv[i]);
          return lua_pcall (L, argc - 1, LUA_MULTRET, err_func);
        } else return err;
}

static DWORD GetModulePath( HINSTANCE hInst, LPTSTR pszBuffer, DWORD dwSize )
//
//      Return the size of the path in bytes.
{
        DWORD dwLength = GetModuleFileName( hInst, pszBuffer, dwSize );
        if( dwLength )
        {
                while( dwLength && pszBuffer[ dwLength ] != '.' )
                {
                        dwLength--;
                }

                if( dwLength )
                        pszBuffer[ dwLength ] = '\000';
        }
        return dwLength;
}


/*
** MAIN
*/
int main (int argc, char *argv[]) {
        char name[ MAX_PATH ];
        DWORD dwLength;
        int size;
        luaL_Buffer b;
        int i;
#ifdef UNICODE
        TCHAR lua_wstring[4098];
#endif
        char lua_string[4098];
        lua_State *L = luaL_newstate();
        (void)argc; /* avoid "unused parameter" warning */
        luaL_openlibs(L);
        lua_newtable(L);  // create arg table
        lua_pushstring(L, argv[0]);  // add interpreter to arg table
        lua_rawseti(L, -2, -1);
        dwLength = GetModulePath( NULL, name, MAX_PATH );
        if(dwLength) { /* Optional bootstrap */
          strcat(name, ".lua");
          lua_pushstring(L, name);  // add lua script to arg table
          lua_rawseti(L, -2, 0);
          lua_setglobal(L,"arg");  // set global arg table
          if(!luaL_loadfile (L, name)) {
            if(lua_pcall (L, 0, LUA_MULTRET, 0)) {
              report (L);
              lua_close (L);
              return EXIT_FAILURE;
            }
          }
        }
        else
        {
          lua_pushstring(L, argv[0]);  // no lua script, so add interpreter again, now as lua script
          lua_rawseti(L, -2, 0);
          lua_setglobal(L,"arg");  // set global arg table
        }

        luaL_buffinit(L, &b);
        for(i = 1; ; i++) {
#ifdef UNICODE
          size = LoadString(GetModuleHandle(NULL), i, lua_wstring,
                            sizeof(lua_string)/sizeof(TCHAR));
          if(size > 0) wcstombs(lua_string, lua_wstring, size + 1);
#else
          size = LoadString(GetModuleHandle(NULL), i, lua_string,
                            sizeof(lua_string)/sizeof(char));
#endif
          if(size) luaL_addlstring(&b, lua_string, size); else break;
        }
        luaL_pushresult(&b);
        if (runlua (L, lua_tostring(L, -1), argc, argv)) {
          report (L);
          lua_close (L);
          return EXIT_FAILURE;
        }
        lua_close (L);
        return EXIT_SUCCESS;
}
