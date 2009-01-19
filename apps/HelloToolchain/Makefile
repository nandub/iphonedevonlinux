#CC = /path/to/my/toolchain/bin/arm-apple-darwin9-gcc
CC=arm-apple-darwin9-gcc
LD = $(CC)

# Here comes your IP of the ipod/iphone.
# If you do a "make bundle" we build our
# application and copy via ssh the files to
# your ipod/iphone and sign them there.
#
# please make sure you have 'ldid' installed on your
# phone: 
#   apt-get install ldid
#

SRC=src/
IMG=img/

LDFLAGS=	-lobjc \
		-bind_at_load \
		-framework Foundation \
		-framework CoreFoundation \
		-framework UIKit \
		-w

all:	HelloToolchain bundle

HelloToolchain: HelloToolchain.o
	$(LD) $(LDFLAGS) -o $@ $^

bundle: HelloToolchain
	@mkdir -p HelloToolchain.app
	@cp HelloToolchain HelloToolchain.app/HelloToolchain_
	@cp ${IMG}* HelloToolchain.app
	@cp Info.plist HelloToolchain.app
	@cp HelloToolchain.sh HelloToolchain.app/HelloToolchain

%.o:	$(SRC)%.m
	$(CC) -c $(CFLAGS) $(CPPFLAGS) $< -o $@

deploy: clean bundle
	@ssh root@$(IP) "cd /Applications/HelloToolchain.app && rm -R * || echo 'not found' "
	@scp -rp HelloToolchain.app root@$(IP):/Applications
	@ssh root@$(IP) "cd /Applications/HelloToolchain.app ; ldid -S HelloToolchain_; killall SpringBoard"

clean:
	@rm -f *.o
	@rm -Rf HelloToolchain.app


