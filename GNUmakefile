
CC = gcc
MKDIR = mkdir

ZLIB_INCDIR = /usr/include
BZ2_INCDIR = /usr/include
OPENSSL_INCDIR = /usr/include
LIBM_INCDIR = /usr/include

DEPS_LIBS = -L$(ZLIB_INCDIR) -lz -L$(BZ2_INCDIR) -lbz2 -L$(OPENSSL_INCDIR) -lssl -lcrypto -L$(LIBM_INCDIR) -lm

all: luarocks

-include Makefile.vendor

luarocks: src/main.c gen/gen.h gen/libraries.h gen/main.h $(VENDOR_LIBS)
	cd $(VENDOR_LUA_DIR)/src && make
	$(CC) -o luarocks -I. -I$(VENDOR_LUA_DIR)/src src/main.c $(VENDOR_LIBS) $(VENDOR_LUA_DIR)/src/liblua.a $(DEPS_LIBS)

clean:
	cd $(VENDOR_LUA_DIR)/src && make clean
	rm -rf target

realclean: clean
	rm -rf gen

gen: realclean
	./bootstrap.tl

