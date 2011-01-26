Building the Toolchain (Modified version from http://code.google.com/p/iphonedevonlinux/wiki/Installation wiki page)

Toolchain for firmware 3.1.3

Checkout and get the files

First create a project directory and check out the latest copy of the toolchain builder. For Example:

mkdir -p ~/Projects/iphone/
cd ~/Projects/iphone/toolchain
git clone git://github.com/nandub/iphonedevonlinux.git

You will need to download the iPhone SDK 3.1.3 from Apple, which can be found here: http://developer.apple.com/iphone/download.action?path=/iphone/iphone_sdk_3.1.3__final/iphone_sdk_3.1.3_with_xcode_3.2.1__snow_leopard__10m2003a.dmg. You can also choose to download the 3.1.3 firmware from Apple at this stage. If you do not, the script will download the firmware automatically.

You can now copy the SDK and Firmware (if you have it) to the toolchain builder's directory:

    cd ~/Projects/iphone/toolchain
    mkdir -p files/firmware
    mv /path/to/iphone_sdk_3.1.3_with_xcode_3.2.1__snow_leopard__10m2003a.dmg files/
    mv /path/to/iPhone1,2_3.1.3_7E18_Restore.ipsw files/firmware

Packages needed to compile the toolchain

Here we provide a list of packages for Debian/Ubuntu

    sudo apt-get install \
      automake \
      bison \
      cpio \
      flex \
      g++ \
      gawk \
      gcc \
      git \
      gobjc \
      gobjc++ \
      gzip \
      libbz2-dev \
      libcurl4-openssl-dev \
      libssl-dev  \
      make \
      mount \
      subversion \
      sudo \
      tar \
      unzip \
      uuid \
      uuid-dev \
      wget \
      xml2 \
      libxml2-dev \
      zlib1g-dev \
      xar

If you are on 64 bit please install:

    sudo apt-get install g++-multilib gcc--multilib gobjc-multilib gobjc++-multilib

Startup and build

Now the environment is set up, you can start the script with:

    sudo ./toolchain.sh all

After all steps, the toolchain is in ./toolchain with the binaries in ./toolchain/pre/bin and the system in ./toolchain/sys/ After a rebuild you may get patch warnings/errors. Ignore them because the build tries to patch already patched files.

With the newest version of the toolchain.sh script you can control the behaviour and the filesystem places of the toolchain file with environment vars:

    BUILD_DIR:
      Build the binaries (gcc, otool etc.) in this dir.
      Default: $TOOLCHAIN/bld

    PREFIX:
      Create the ./bin ./lib dir for the toolchain executables
      under the prefix.
      Default: $TOOLCHAIN/pre

    SRC_DIR:
      Store the sources (gcc etc.) in this dir.
      Default: $TOOLCHAIN/src

    SYS_DIR:
      Put the toolchain sys files (the iphone root system) under this dir.
      Default: $TOOLCHAIN/sys

   example:

    sudo BUILD_DIR="/tmp/bld" SRC_DIR="/tmp/src" PREFIX="/usr/local" SYS_DIR=/usr/local/iphone_sdk_3.x ./toolchain.sh all
