/* This file implements the Lua binding to libbzip2.
 *
 * Copyright (c) 2008, Evan Klitzke <evan@eklitzke.org>
 * Copyright (c) 2012, Thomas Harning Jr <harningt@gmail.com>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

#include <lua.h>
#include <lauxlib.h>

/* This explicit define prevents compat-5.3.h from loading compat-5.3.c */
#define COMPAT53_PREFIX compat53
#include "compat-5.3.h"

#include "lbz2_file_reader.h"
#include "lbz2_file_writer.h"
#include "lbz2_stream.h"

static luaL_Reg lbz2_global[] = {
	{ NULL, NULL }
};

int luaopen_bz2(lua_State *L) {
	luaL_newlib(L, lbz2_global);

	lua_pushliteral(L, "bz2");
	lua_setfield(L, -2, "_NAME");
	lua_pushliteral(L, "0.1");
	lua_setfield(L, -2, "_VERSION");

	register_lbz2_file_reader(L);
	register_lbz2_file_writer(L);
	register_lbz2_stream(L);
	
#if defined(LUA_VERSION_NUM) && LUA_VERSION_NUM == 501
	lua_pushvalue(L, -1);
	lua_setglobal(L, "bz2");
#endif

	return 1;
}
