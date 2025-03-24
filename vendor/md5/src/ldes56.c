#include <stdlib.h>
#include <string.h>

#include "des56.h"

#include "lua.h"
#include "lauxlib.h"

#include "compat-5.2.h"
#include "ldes56.h"

static int des56_decrypt( lua_State *L )
{
  char* decypheredText;
  keysched KS;
  int rel_index, abs_index;
  size_t cypherlen;
  const char *cypheredText = 
    luaL_checklstring( L, 1, &cypherlen );
  const char *key = luaL_optstring( L, 2, NULL );
  int padinfo;

  padinfo = cypheredText[cypherlen-1];
  cypherlen--;

  /* Aloca array */
  decypheredText = 
    (char *) malloc( (cypherlen+1) * sizeof(char));
  if(decypheredText == NULL) {
    lua_pushstring(L, "Error decrypting file. Not enough memory.");
    lua_error(L);
  }

  /* Inicia decifragem */
  if (key && strlen(key) >= 8)
  {
    char k[8];
    int i;

    for (i=0; i<8; i++)
      k[i] = (unsigned char)key[i];
    fsetkey(k, &KS);
  } else {
    lua_pushstring(L, "Error decrypting file. Invalid key.");
    lua_error(L);
  }

  rel_index = 0;
  abs_index = 0;

  while (abs_index < (int) cypherlen)
  {
    decypheredText[abs_index] = cypheredText[abs_index];
    abs_index++;
    rel_index++;
    if( rel_index == 8 )
    {
      rel_index = 0;
      fencrypt(&(decypheredText[abs_index - 8]), 1, &KS);
    }
  }
  decypheredText[abs_index] = 0;

  lua_pushlstring(L, decypheredText, (abs_index-padinfo));
  free( decypheredText );
  return 1;
}

static int des56_crypt( lua_State *L )
{
  char *cypheredText;
  keysched KS;
  int rel_index, pad, abs_index;
  size_t plainlen;
  const char *plainText = luaL_checklstring( L, 1, &plainlen );
  const char *key = luaL_optstring( L, 2, NULL );

  cypheredText = (char *) malloc( (plainlen+8) * sizeof(char));
  if(cypheredText == NULL) {
    lua_pushstring(L, "Error encrypting file. Not enough memory."); 
    lua_error(L);
  }

  if (key && strlen(key) >= 8)
  {
    char k[8];
    int i;

    for (i=0; i<8; i++)
      k[i] = (unsigned char)key[i];
    fsetkey(k, &KS);
  } else {
    lua_pushstring(L, "Error encrypting file. Invalid key.");
    lua_error(L);
  }

  rel_index = 0;
  abs_index = 0;
  while (abs_index < (int) plainlen) {
    cypheredText[abs_index] = plainText[abs_index];
    abs_index++;
    rel_index++;
    if( rel_index == 8 ) {
      rel_index = 0;
      fencrypt(&(cypheredText[abs_index - 8]), 0, &KS);
    }
  }

  pad = 0;
  if(rel_index != 0) { /* Pads remaining bytes with zeroes */
    while(rel_index < 8)
    {
      pad++;
      cypheredText[abs_index++] = 0;
      rel_index++;
    }
    fencrypt(&(cypheredText[abs_index - 8]), 0, &KS);
  }
  cypheredText[abs_index] = pad;

  lua_pushlstring( L, cypheredText, abs_index+1 );
  free( cypheredText );
  return 1;
}

/*
** Assumes the table is on top of the stack.
*/
static void set_info (lua_State *L) {
	lua_pushliteral (L, "_COPYRIGHT");
	lua_pushliteral (L, "Copyright (C) 2007-2019 PUC-Rio");
	lua_settable (L, -3);
	lua_pushliteral (L, "_DESCRIPTION");
	lua_pushliteral (L, "DES 56 cryptographic facilities for Lua");
	lua_settable (L, -3);
	lua_pushliteral (L, "_VERSION");
	lua_pushliteral (L, "DES56 1.3");
	lua_settable (L, -3);
}

static const struct luaL_Reg des56lib[] = {
  {"crypt", des56_crypt},
  {"decrypt", des56_decrypt},
  {NULL, NULL},
};

int luaopen_des56 (lua_State *L) {
  lua_newtable(L);
  luaL_setfuncs(L, des56lib, 0);
  set_info (L);
  return 1;
}
