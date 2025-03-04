
CC = gcc
MKDIR = mkdir
MYLIBS = -llua -lz -lbz2 -lssl -lcrypto

ZLIB_INCDIR = /usr/include
BZ2_INCDIR = /usr/include
OPENSSL_INCDIR = /usr/include

all: luarocks

-include Makefile.vendor

luarocks: src/main.c gen/gen.h gen/libraries.h gen/main.h $(VENDOR_LIBS)
	$(CC) -o luarocks $(MYLIBS) -I. src/main.c $(VENDOR_LIBS)

clean:
	rm -rf gen target

gen: clean
	./bootstrap.tl

