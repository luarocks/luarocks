all: miniposix.a

miniposix.a: miniposix.o
	$(AR) rcu miniposix.a miniposix.o

miniposix.o: miniposix.c
	$(CC) -c miniposix.c

clean:
	rm *.o *.a
