#ifndef DES56_H
#define DES56_H 1
/*
 * Fast implementation of the DES, as described in the Federal Register,
 * Vol. 40, No. 52, p. 12134, March 17, 1975.
 *
 * Stuart Levy, Minnesota Supercomputer Center, April 1988.
 * Currently (2007) slevy@ncsa.uiuc.edu
 * NCSA, University of Illinois Urbana-Champaign
 *
 * Calling sequence:
 *
 * typedef unsigned long keysched[32];
 *
 * fsetkey(key, keysched)	/ * Converts a DES key to a "key schedule" * /
 *	unsigned char	key[8];
 *	keysched	*ks;
 *
 * fencrypt(block, decrypt, keysched)	/ * En/decrypts one 64-bit block * /
 *	unsigned char	block[8];	/ * data, en/decrypted in place * /
 *	int		decrypt;	/ * 0=>encrypt, 1=>decrypt * /
 *	keysched	*ks;		/ * key schedule, as set by fsetkey * /
 *
 * Key and data block representation:
 * The 56-bit key (bits 1..64 including "parity" bits 8, 16, 24, ..., 64)
 * and the 64-bit data block (bits 1..64)
 * are each stored in arrays of 8 bytes.
 * Following the NBS numbering, the MSB has the bit number 1, so
 *  key[0] = 128*bit1 + 64*bit2 + ... + 1*bit8, ... through
 *  key[7] = 128*bit57 + 64*bit58 + ... + 1*bit64.
 * In the key, "parity" bits are not checked; their values are ignored.
 *
*/

/*
===============================================================================
License

des56.c is licensed under the terms of the MIT license reproduced below.
This means that des56.c is free software and can be used for both academic
and commercial purposes at absolutely no cost.
===============================================================================
Copyright (C) 1988 Stuart Levy

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
 */

typedef unsigned long word32;
typedef unsigned char tiny;

typedef struct keysched {
	struct keystage {
		word32 h, l;
	} KS[16];
} keysched;

extern void fsetkey(char key[8], keysched *ks);

extern void fencrypt(char block[8], int decrypt, keysched *ks);

#endif /*DES56_H*/
