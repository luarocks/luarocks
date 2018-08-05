.POSIX:

all:
	+gmake -f GNUmakefile all

.DEFAULT:
	+gmake -f GNUmakefile $<
