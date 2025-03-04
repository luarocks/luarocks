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

#include <assert.h>

/* This explicit define prevents compat-5.3.h from loading compat-5.3.c */
#define COMPAT53_PREFIX compat53
#include "compat-5.3.h"

#include "lbz2_file_writer.h"
#include "lbz2_common.h"

#define LBZ2_FILE_WRITER_MT "LBZ2_FILE_WRITER_MT"

typedef struct {
	BZFILE *bz_stream;
	FILE *f;
} lbz2_file_writer;

static lbz2_file_writer *lbz2_check_file_writer(lua_State *L, int index) {
	return (lbz2_file_writer *)luaL_checkudata(L, index, LBZ2_FILE_WRITER_MT);
}

static int lbz2_file_writer_open(lua_State *L) {
	lbz2_file_writer *writer;
	int errorCode;
	const char *fname = luaL_checkstring(L, 1);
	int blockSize100k = luaL_optinteger(L, 2, 9);
	int verbosity = luaL_optinteger(L, 3, 0);
	int workFactor = luaL_optinteger(L, 4, 0);

	writer = lua_newuserdata(L, sizeof(*writer));
	memset(writer, 0, sizeof(*writer));

	luaL_getmetatable(L, LBZ2_FILE_WRITER_MT);
	lua_setmetatable(L, -2);

	writer->f = fopen(fname, "wb");

	if (writer->f == NULL) {
		return luaL_error(L, "Failed to fopen %s", fname);
	}
	writer->bz_stream = BZ2_bzWriteOpen(&errorCode, writer->f, blockSize100k, verbosity, workFactor);

	if (BZ_OK != errorCode) {
		fclose(writer->f);
		writer->f = NULL;
		lua_pushnil(L);
		lua_pushstring(L, lbz2_error(errorCode));
		return 2;
	}
	return 1;
}

static int lbz2_file_writer_close(lua_State *L) {
	lbz2_file_writer *writer = lbz2_check_file_writer(L, 1);
	int errorCode = BZ_OK;

	if (writer->bz_stream) {
		BZ2_bzWriteClose(&errorCode, writer->bz_stream, 0, NULL, NULL);
		writer->bz_stream = NULL;
	}
	if (writer->f) {
		fclose(writer->f);
		writer->f = NULL;
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

static int lbz2_file_writer_write(lua_State *L) {
	lbz2_file_writer *writer = lbz2_check_file_writer(L, 1);
	int errorCode = BZ_OK;
	size_t dataLength;
	const char *data = luaL_checklstring(L, 2, &dataLength);

	BZ2_bzWrite(&errorCode, writer->bz_stream, (void *)data, dataLength);

	if (BZ_OK != errorCode) {
		lua_pushnil(L);
		lua_pushstring(L, lbz2_error(errorCode));
		return 2;
	}
	lua_pushboolean(L, 1);
	return 1;
}

static luaL_Reg lbz2_file_writer_ops[] = {
	{ "write", lbz2_file_writer_write },
	{ "close", lbz2_file_writer_close },
	{ NULL, NULL }
};

static luaL_Reg lbz2_file_writer_global[] = {
	{ "openWrite", lbz2_file_writer_open },
	{ NULL, NULL }
};

void register_lbz2_file_writer(lua_State *L) {
	luaL_newmetatable(L, LBZ2_FILE_WRITER_MT);
	lua_newtable(L);
	luaL_setfuncs(L, lbz2_file_writer_ops, 0);
	lua_setfield(L, -2, "__index");

	lua_pushcfunction(L, lbz2_file_writer_close);
	lua_setfield(L, -2, "__gc");
	lua_pop(L, 1);

	luaL_setfuncs(L, lbz2_file_writer_global, 0);
}
