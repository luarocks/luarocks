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

#include <bzlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <lua.h>
#include <lauxlib.h>

/* This explicit define prevents compat-5.3.h from loading compat-5.3.c */
#define COMPAT53_PREFIX compat53
#include "compat-5.3.h"

#include "lbz2_file_reader.h"
#include "lbz2_common.h"

#define LBZ2_FILE_READER_MT "LBZ2_FILE_READER_MT"

typedef struct {
	BZFILE *bz_stream;
	FILE *f;
} lbz2_file_reader;

static lbz2_file_reader *lbz2_check_file_reader(lua_State *L, int index) {
	return (lbz2_file_reader *)luaL_checkudata(L, index, LBZ2_FILE_READER_MT);
}

static int lbz2_file_reader_open(lua_State *L) {
	lbz2_file_reader *reader;
	int errorCode;
	const char *fname = luaL_checkstring(L, 1);
	int verbosity = luaL_optinteger(L, 3, 0);
	int small = lua_toboolean(L, 4);

	reader = lua_newuserdata(L, sizeof(*reader));
	memset(reader, 0, sizeof(*reader));

	luaL_getmetatable(L, LBZ2_FILE_READER_MT);
	lua_setmetatable(L, -2);

	reader->f = fopen(fname, "rb");

	if (reader->f == NULL) {
		return luaL_error(L, "Failed to fopen %s", fname);
	}
	reader->bz_stream = BZ2_bzReadOpen(&errorCode, reader->f, verbosity, small, NULL, 0);

	if (BZ_OK != errorCode) {
		fclose(reader->f);
		reader->f = NULL;
		lua_pushnil(L);
		lua_pushstring(L, lbz2_error(errorCode));
		return 2;
	}
	return 1;
}

static int lbz2_file_reader_close(lua_State *L) {
	lbz2_file_reader *reader = lbz2_check_file_reader(L, 1);
	int errorCode = BZ_OK;

	if (reader->bz_stream) {
		BZ2_bzReadClose(&errorCode, reader->bz_stream);
		reader->bz_stream = NULL;
	}
	if (reader->f) {
		fclose(reader->f);
		reader->f = NULL;
	}

	lua_pushnil(L);
	lua_setmetatable(L, 1);

	if (BZ_OK != errorCode) {
		lua_pushnil(L);
		lua_pushstring(L, lbz2_error(errorCode));
		return 2;
	}
	lua_pushboolean(L, 1);
	return 1;
}

static int lbz2_file_reader_read(lua_State *L) {
	lbz2_file_reader *reader = lbz2_check_file_reader(L, 1);
	int errorCode = BZ_OK;
	int dataLength;
	luaL_Buffer B;
	/* If passed a boolean, read a single *chunk* */
	if (lua_isboolean(L, 2)) {
		dataLength = LUAL_BUFFERSIZE;
	} else {
		dataLength = luaL_optinteger(L, 2, -1);
	}

	luaL_buffinit(L, &B);

	/* Pull in chunks until all data read */
	while(dataLength > 0 || dataLength == -1) {
		char *buf = luaL_prepbuffer(&B);
		int nextRead = (dataLength == -1 || dataLength > LUAL_BUFFERSIZE) ? LUAL_BUFFERSIZE : dataLength;
		int read = BZ2_bzRead(&errorCode, reader->bz_stream, buf, nextRead);
		if (read > 0) {
			luaL_addsize(&B, read);
			dataLength -= read;
		}
		if (BZ_OK != errorCode) {
			goto handle_error;
		}
	}
	luaL_pushresult(&B);
	return 1;
handle_error:
	if(BZ_STREAM_END == errorCode) {
		luaL_pushresult(&B);
		lua_pushboolean(L, 1);
		return 2;
	} else {
		lua_pushnil(L);
		lua_pushstring(L, lbz2_error(errorCode));
		return 2;
	}
}

static luaL_Reg lbz2_file_reader_ops[] = {
	{ "read", lbz2_file_reader_read },
	{ "close", lbz2_file_reader_close },
	{ NULL, NULL }
};

static luaL_Reg lbz2_file_reader_global[] = {
	{ "openRead", lbz2_file_reader_open },
	{ NULL, NULL }
};



void register_lbz2_file_reader(lua_State *L) {
	luaL_newmetatable(L, LBZ2_FILE_READER_MT);
	lua_newtable(L);
	luaL_setfuncs(L, lbz2_file_reader_ops, 0);
	lua_setfield(L, -2, "__index");

	lua_pushcfunction(L, lbz2_file_reader_close);
	lua_setfield(L, -2, "__gc");
	lua_pop(L, 1);

	luaL_setfuncs(L, lbz2_file_reader_global, 0);
}
