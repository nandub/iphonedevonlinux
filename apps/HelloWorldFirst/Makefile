#CC = /path/to/my/toolchain/bin/arm-apple-darwin9-gcc
CC=arm-apple-darwin9-gcc
LD = $(CC)

# We build our first hello world.
# Please copy the resulting HelloWorldFirst to your
# iphone/ipod and (pseudo-)sign it with ldid -S HelloWorldFirst
# 
# $> scp HelloWorldFirst root@192.168.x.y:/var/root/
# $> ssh root@192.168.x.y
# ~ root# ldid -S HelloWorldFirst
# ~ root# ./HelloWorldFirst
# Hello World


LDFLAGS=	-lobjc \
		-bind_at_load \
		-w

all:	HelloWorldFirst

HelloWorld1: HelloWorldFirst.o
	$(LD) $(LDFLAGS) -o $@ $^

%.o:	$(SRC)%.m
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

clean:
	@rm -f *.o
	@rm -Rf HelloWorldFirst

