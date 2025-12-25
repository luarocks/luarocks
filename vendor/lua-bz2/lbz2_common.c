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


#include "lbz2_common.h"
#include <bzlib.h>


const char *lbz2_error(int bzerror) {
	switch (bzerror) {
	case BZ_OK:
		return "OK";
	case BZ_RUN_OK:
		return "RUN_OK";
	case BZ_FLUSH_OK:
		return "FLUSH_OK";
	case BZ_FINISH_OK:
		return "FINISH_OK";
	case BZ_STREAM_END:
		return "STREAM_END";
	case BZ_SEQUENCE_ERROR:
		return "SEQUENCE_ERROR";
	case BZ_PARAM_ERROR:
		return "PARAM_ERROR";
	case BZ_MEM_ERROR:
		return "MEM_ERROR";
	case BZ_DATA_ERROR:
		return "DATA_ERROR";
	case BZ_DATA_ERROR_MAGIC:
		return "DATA_ERROR_MAGIC";
	case BZ_IO_ERROR:
		return "IO_ERROR";
	case BZ_UNEXPECTED_EOF:
		return "UNEXPECTED_EOF";
	case BZ_OUTBUFF_FULL:
		return "OUTBUFF_FULL";
	case BZ_CONFIG_ERROR:
		return "CONFIG_ERROR";
	default:
		return "UNKNOWN";
	}
}
