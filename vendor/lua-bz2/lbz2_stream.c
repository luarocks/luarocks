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

#include "lbz2_stream.h"
#include "lbz2_common.h"

#define LBZ2_STREAM_MT "LBZ2_STREAM_MT"

typedef struct {
	bz_stream bz_stream;
	int isDecompressing;
} lbz2_stream;

static lbz2_stream *lbz2_check_stream(lua_State *L, int index) {
	return (lbz2_stream *)luaL_checkudata(L, index, LBZ2_STREAM_MT);
}

static int lbz2_stream_initCompress(lua_State *L) {
	lbz2_stream *stream;
	int errorCode;
	int blockSize100k = luaL_optinteger(L, 1, 9);
	int verbosity = luaL_optinteger(L, 2, 0);
	int workFactor = luaL_optinteger(L, 3, 0);

	stream = lua_newuserdata(L, sizeof(*stream));
	memset(stream, 0, sizeof(*stream));

	stream->isDecompressing = 0;

	luaL_getmetatable(L, LBZ2_STREAM_MT);
	lua_setmetatable(L, -2);

	errorCode = BZ2_bzCompressInit(&stream->bz_stream, blockSize100k, verbosity, workFactor);

	if (BZ_OK != errorCode) {
		lua_pushnil(L);
		lua_pushstring(L, lbz2_error(errorCode));
		return 2;
	}
	return 1;
}

static int lbz2_stream_initDecompress(lua_State *L) {
	lbz2_stream *stream;
	int errorCode;
	int verbosity = luaL_optinteger(L, 1, 0);
	int isSmall = lua_toboolean(L, 2);

	stream = lua_newuserdata(L, sizeof(*stream));
	memset(stream, 0, sizeof(*stream));

	stream->isDecompressing = 1;

	luaL_getmetatable(L, LBZ2_STREAM_MT);
	lua_setmetatable(L, -2);

	errorCode = BZ2_bzDecompressInit(&stream->bz_stream, verbosity, isSmall);

	if (BZ_OK != errorCode) {
		lua_pushnil(L);
		lua_pushstring(L, lbz2_error(errorCode));
		return 2;
	}
	return 1;
}
static int lbz2_stream_close(lua_State *L) {
	lbz2_stream *stream = lbz2_check_stream(L, 1);
	int errorCode = BZ_OK;

	if (stream->bz_stream.state) {
		if (stream->isDecompressing) {
			errorCode = BZ2_bzDecompressEnd(&stream->bz_stream);
		} else {
			errorCode = BZ2_bzCompressEnd(&stream->bz_stream);
		}
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

static int lbz2_stream_perform_compress(lua_State *L, lbz2_stream *stream, int action) {
	int errorCode = BZ_OK;
	luaL_Buffer B;

	luaL_buffinit(L, &B);

	while (1) {
		stream->bz_stream.avail_out = LUAL_BUFFERSIZE;
		stream->bz_stream.next_out = luaL_prepbuffer(&B);
		errorCode = BZ2_bzCompress(&stream->bz_stream, action);

		switch (action) {
		case BZ_RUN:
			if (BZ_RUN_OK != errorCode) {
				goto fail;
			}
			luaL_addsize(&B, LUAL_BUFFERSIZE - stream->bz_stream.avail_out);
			if (stream->bz_stream.avail_in == 0 || stream->bz_stream.avail_out == LUAL_BUFFERSIZE) {
				goto complete;
			}
			break;
		case BZ_FLUSH:
			if (BZ_FLUSH_OK != errorCode && BZ_RUN_OK != errorCode) {
				goto fail;
			}
			luaL_addsize(&B, LUAL_BUFFERSIZE - stream->bz_stream.avail_out);
			if (BZ_RUN_OK == errorCode) {
				goto complete;
			}
			break;
		case BZ_FINISH:
			if (BZ_FINISH_OK != errorCode && BZ_STREAM_END != errorCode) {
				goto fail;
			}
			luaL_addsize(&B, LUAL_BUFFERSIZE - stream->bz_stream.avail_out);
			if (BZ_STREAM_END == errorCode) {
				goto complete;
			}
		}
	}
complete:
	luaL_pushresult(&B);
	return 1;

fail:
	lua_pushnil(L);
	lua_pushstring(L, lbz2_error(errorCode));
	return 2;
}

static int lbz2_stream_perform_decompress(lua_State *L, lbz2_stream *stream) {
	int errorCode = BZ_OK;
	luaL_Buffer B;

	luaL_buffinit(L, &B);

	while (1) {
		stream->bz_stream.avail_out = LUAL_BUFFERSIZE;
		stream->bz_stream.next_out = luaL_prepbuffer(&B);
		errorCode = BZ2_bzDecompress(&stream->bz_stream);

		if (BZ_OK != errorCode && BZ_STREAM_END != errorCode) {
			goto fail;
		}
		luaL_addsize(&B, LUAL_BUFFERSIZE - stream->bz_stream.avail_out);
		/* Stream over with */
		if (errorCode == BZ_STREAM_END) {
			goto completeStream;
		}
		/* No more bytes left this round */
		if (stream->bz_stream.avail_in == 0 && stream->bz_stream.avail_out == LUAL_BUFFERSIZE) {
			goto complete;
		}
	}
complete:
	luaL_pushresult(&B);
	return 1;

completeStream:
	luaL_pushresult(&B);
	/* Report in addition to the data collected, the number of trailing bytes
	 * still available in the input buffer for other use. */
	lua_pushinteger(L, stream->bz_stream.avail_in);
	return 2;

fail:
	lua_pushnil(L);
	lua_pushstring(L, lbz2_error(errorCode));
	return 2;
}
static int lbz2_stream_update(lua_State *L) {
	lbz2_stream *stream = lbz2_check_stream(L, 1);
	size_t dataLength;
	const char *data = luaL_optlstring(L, 2, NULL, &dataLength);

	/* Update the pointers and feed the output buffer while data is available */
	stream->bz_stream.avail_in = dataLength;
	/* Cast away const-ness since input data is never altered */
	stream->bz_stream.next_in = (char *)data;

	/* For compression, need to specially flag finishing state */
	if (!stream->isDecompressing) {
		return lbz2_stream_perform_compress(L, stream, !data ? BZ_FINISH : BZ_RUN);
	} else {
		return lbz2_stream_perform_decompress(L, stream);
	}
}

static int lbz2_stream_flush(lua_State *L) {
	lbz2_stream *stream = lbz2_check_stream(L, 1);
	if (!stream->isDecompressing) {
		return lbz2_stream_perform_compress(L, stream, BZ_FLUSH);
	} else {
		/* Invalid for decompression */
		lua_pushnil(L);
		lua_pushstring(L, lbz2_error(BZ_SEQUENCE_ERROR));
		return 2;
	}
}

static luaL_Reg lbz2_stream_ops[] = {
	{ "update", lbz2_stream_update },
	{ "flush", lbz2_stream_flush },
	{ "close", lbz2_stream_close },
	{ NULL, NULL }
};

static luaL_Reg lbz2_stream_global[] = {
	{ "initCompress", lbz2_stream_initCompress },
	{ "initDecompress", lbz2_stream_initDecompress },
	{ NULL, NULL }
};

void register_lbz2_stream(lua_State *L) {
	luaL_newmetatable(L, LBZ2_STREAM_MT);
	lua_newtable(L);
	luaL_setfuncs(L, lbz2_stream_ops, 0);
	lua_setfield(L, -2, "__index");

	lua_pushcfunction(L, lbz2_stream_close);
	lua_setfield(L, -2, "__gc");
	lua_pop(L, 1);

	luaL_setfuncs(L, lbz2_stream_global, 0);
}

