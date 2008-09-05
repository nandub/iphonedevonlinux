#!/bin/bash

# Build everything relative to IPHONEDEV_DIR
# Default is /home/loginname/iphonedev
IPHONEDEV_DIR="${HOME}/iphonedev"

# You need to download 
IPHONE_SDK="iphone_sdk_final.dmg"
FIRMWARE="iPhone1,1_2.0_5A347_Restore.ipsw"

# this is the name with the symlink to the current firmware
# system folder
CURRENT_SYSTEM_DIR="current"

# Search the web. If this is empty this script
# searches itself on 
# http://www.theiphonewiki.com/wiki/index.php?title=VFDecrypt_Keys
# for the key.
DECRYPTION_KEY_SYSTEM=""

# How to use this script
# ======================
#
# Disclaimer: Use this script on your own risk. I'm not responsible
# for any damage. Please don't use it with your root account. For
# some steps you are asked for your password because the need
# root privileges to loop-mount some .dmg/.img files.
#
# 1. set your prefered IPHONEDEV_DIR. All files and the
#    complete toolchain will reside there.
#
# In general the resulting toolchain has following file layout
# (for better reading I skip $IPHONEDEV_DIR):
#
# ./files
# ./files/iphone_sdk_final.dmg (you have to copy it yourself)
# ./files/fw
# ./files/fw/iPhone1,1_2.0_5A347_Restore.ipsw (and/or other firmware.ipsw)
# ./files/fw/2.0_5A347/system (the extracted rootfs of your favorite fw)
# ./files/fw/current -> symlink to ./files/fw/YourFirmware/system
# ./files/darwin_sources/... (files needed for the saurik toolchain)
# ./files/mnt (we mount temporarily some dmg/img via mount -o loop)
# ./SDKs/iPhoneOS2.0.sdk (the extracted SDK from iphone_sdk_final.dmg)
# ./SDKs/MacOSX10.5.sdk  (extracted SDK from iphone_sdk_final.dmg)
# ./tmp
# ./toolchain/bld   (layout from www.saurik.com/id/4)
# ./toolchain/pre   (all dirs are build by the script)
# ./toolchain/src
# ./toolchain/sys
# ./tools/vfdecrypt... (will automatically downloaded)
# ./tools/xpwn         (will automatically downloaded)
# 
# 
# The first time this script is started the tools in ./tools are
# downloaded and compiled.
#
# source ./toolchain.sh
#   Set the environment to your toolchain. The ready compiled
#   binaries (arm-apple-darwin9-...) are in your path.
#
# ./toolchain.sh headers
#   Extract SDKs from the iphone_sdk.
#   Results in ready extracted ./SDKs/iPhoneOS2.0.sdk 
#   and MacOSX10.5.sdk
#
# ./toolchain.sh system
#   Eventually downloads the firmware you defined in $FIRMWARE above
#   if not copied to ./files/fw/...
#   Now searches for decryptions-keys and tries to extract the
#   root-filesystem of the firmware to ./files/fw/{FirmwareVersion}/system.
#   The symlink ./files/fw/current is automatically set to the
#   extracted system.
#
# ./toolchain.sh build
#   Starts the build process decribed by saurik. This script
#   uses the same paths under $IPHONEDEV_DIR/toolchain/...
#   Please download some needed packages from apple. You have
#   to register yourself as developer on developer.apple.com
#   These packages should copied to ./files/darwin_sources


FILES_DIR="${IPHONEDEV_DIR}/files"
SDKS_DIR="${IPHONEDEV_DIR}/SDKs"
TOOLS_DIR="${IPHONEDEV_DIR}/tools"
XPWN_DIR="${TOOLS_DIR}/xpwn"
MIG_DIR="${TOOLS_DIR}/mig"
MNT_DIR="${FILES_DIR}/mnt"
TMP_DIR="${IPHONEDEV_DIR}/tmp"
FW_DIR="${FILES_DIR}/fw"
FW_FILE="${FW_DIR}/${FIRMWARE}"

IPHONE_SDK_DMG="${FILES_DIR}/${IPHONE_SDK}"
IPHONE_SDK_IMG="${FILES_DIR}/iphone_sdk.img"

DMG="${XPWN_DIR}/dmg/dmg"
VFDECRYPT="${TOOLS_DIR}/vfdecrypt"
MIG="${MIG_DIR}/mig"

MACOSX_PKG="${MNT_DIR}/Packages/MacOSX10.5.pkg"
IPHONE_PKG="${MNT_DIR}/Packages/iPhoneSDKHeadersAndLibs.pkg"

# Tools
XPWN_GIT="git://github.com/planetbeing/xpwn.git"
MIG_URL="ftp://ftp.gnu.org/gnu/mig/mig-1.3.tar.gz"
MIG_URL=""
VFDECRYPT_TGZ="vfdecrypt-linux.tar.gz"
VFDECRYPT_URL="http://iphone-elite.googlecode.com/files/${VFDECRYPT_TGZ}"
IPHONEWIKI_KEY_URL="http://www.theiphonewiki.com/wiki/index.php?title=VFDecrypt_Keys"

# Apple (URL's see: http://modmyifone.com/wiki/index.php/IPhone_Firmware_Download_Links)
FW_DOWNLOAD_URL="http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPhone"
FW_DOWNLOAD_1G_202="$FW_DOWNLOAD_URL/061-5246.20080818.2V0hO/iPhone1,1_2.0.2_5C1_Restore.ipsw"
FW_DOWNLOAD_1G_201="$FW_DOWNLOAD_URL/061-5135.20080729.Vfgtr/iPhone1,1_2.0.1_5B108_Restore.ipsw"
FW_DOWNLOAD_1G_200="$FW_DOWNLOAD_URL/061-4956.20080710.V50OI/iPhone1,1_2.0_5A347_Restore.ipsw"
FW_DOWNLOAD_3G_200="$FW_DOWNLOAD_URL/061-5241.20080818.t5Fv3/iPhone1,2_2.0.2_5C1_Restore.ipsw"
FW_DOWNLOAD_3G_201="$FW_DOWNLOAD_URL/061-5134.20080729.Q2W3E/iPhone1,2_2.0.1_5B108_Restore.ipsw"
FW_DOWNLOAD_3G_202="$FW_DOWNLOAD_URL/061-5241.20080818.t5Fv3/iPhone1,2_2.0.2_5C1_Restore.ipsw"

NEEDED_COMMANDS="git-clone git-pull gcc cmake make sudo mount xar cpio tar wget awk unzip"

HERE=`pwd`

command_not_found() {
    echo "Need following command: $1"
}

check_commands() {
    local command
    local found_all=1
    for c in $NEEDED_COMMANDS ; do
        command=$(which $c)
        if [ -z $command ] ; then 
            command_not_found "$c"
            found_all=0
        fi
    done
    if [ $found_all = 0 ] ; then
        echo "Some commands needed. Please install them on your system"
        exit 1
    fi
}

check_dirs() {
    for d in \
        $IPHONEDEV_DIR \
        $FILES_DIR \
        $SDKS_DIR \
        $TOOLS_DIR \
        $MNT_DIR \
        $TMP_DIR \
        $FW_DIR ; do

        [ ! -d $d ] && mkdir $d
    done
}

build_tools() {
    build_xpwn_dmg
    build_vfdecrypt
}


build_xpwn_dmg() {
    [ ! -d $TOOLS_DIR ] && mkdir -p $TOOLS_DIR
    [ -x $DMG ] && return

    # Maybe we have an xpwn clone ?
    if [ -d $XPWN_DIR ] ; then
        if [ -d "$XPWN_DIR/.git" ] ; then
            # we update the current git of XPWN
            echo "update xpwn git"
            cd "$XPWN_DIR"
            git-pull
        else
            echo "There exists an xpwn dir without a checked out git!"
            echo "Please correct this (maybe you should rm -R $XPWN_DIR ?)"
            exit 1
        fi
    else 
        echo "checkout xpwn git"
        git-clone $XPWN_GIT $XPWN_DIR
    fi

    cd $XPWN_DIR

    [ -r Makefile ] && make clean
    cmake CMakeLists.txt
    cd dmg
    make
}

build_vfdecrypt() {
    if [ ! -x $VFDECRYPT ] ; then
        cd $TOOLS_DIR
        [ ! -r $VFDECRYPT_TGZ ] && wget $VFDECRYPT_URL
        tar xfzv $VFDECRYPT_TGZ
        gcc -o vfdecrypt vfdecrypt.c -lssl 
    fi
}

build_mig() {
    if [ ! -x $MIG ] ; then
        cd $TOOLS_DIR
        cvs -z3 -d$MIG_CVS co mig
        cd $MIG_DIR

    fi
}

convert_dmg_to_img() {
    [ ! -x $DMG ] && echo "$DMG not found/executable." && exit 1

    if [ ! -r $IPHONE_SDK_IMG ] ; then
        $DMG extract $IPHONE_SDK_DMG $IPHONE_SDK_IMG
    fi
}

cleanup_tmp() {
    local pushdir
    pushdir=`pwd`
    cd $TMP_DIR
    rm -fR *
    cd "$pushdir"
}


extract_headers() {
    [ ! -d ${MNT_DIR} ] && mkdir ${MNT_DIR}
    [ ! -d ${SDKS_DIR} ] && mkdir ${SDKS_DIR}

    sudo mount -o loop $IPHONE_SDK_IMG $MNT_DIR
    echo "extract $IPHONE_PKG"

    cleanup_tmp

    cp $IPHONE_PKG $TMP_DIR/iphone.pkg
    cd $TMP_DIR
    xar -xf iphone.pkg Payload
    mv $TMP_DIR/Payload $TMP_DIR/Payload.gz
    gunzip $TMP_DIR/Payload.gz
    cat $TMP_DIR/Payload | cpio -i -d 
    mv $TMP_DIR/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS2.0.sdk ${SDKS_DIR}

    cleanup_tmp

    echo "extract $MACOSX_PKG"

    cp $MACOSX_PKG $TMP_DIR/macosx.pkg
    cd $TMP_DIR 
    xar -xf macosx.pkg Payload
    mv $TMP_DIR/Payload $TMP_DIR/Payload.gz
    gunzip $TMP_DIR/Payload.gz
    cat $TMP_DIR/Payload | cpio -i -d 
    mv $TMP_DIR/SDKs/MacOSX10.5.sdk ${SDKS_DIR}

    cleanup_tmp

    sudo umount $MNT_DIR

}


# This is a hack of a HACK. I need some bash script
# to read Apples .plist files. I found some in IPOD
# developement and I decided to write something small
# without big dependencies to "parse" them.
# 
# Examples:
# 
# Keys
#
# defaults DeviceClass "$DATA" &&  DEVICECLASS="$Return_Val"
# defaults ProductVersion "$DATA"  &&  PRODUCTVERSION="$Return_Val"
# defaults ProductBuildVersion "$DATA" && BUILDVERSION="$Return_Val"
# defaults "RestoreRamDisks User" "$DATA" && RESTORERAMDISK="$Return_Val"
# 
# Arrays
#
# defaults "SupportedProductTypeIDs DFU [] " " $DATA" && SUPPORTED="$Return_Val"
# defaults "DeviceMap [0]" "$DATA" && DEVICEARRAY="$Return_Val"
# defaults "MGPlay [2] []" "$DATA" && MGPLAY="$Return_Val"
# MGPLAYARRAY=(${Return_Array[@]})
#
# Attention: if you use an array index you get back
# the value. The value maybe an <dict>, <array> structure as string
# or a scalar if the value is a <string> or <integer>.
# 
# Using [] you get back the whole array in string representation with
# § as delimiter and in $Return_Array you get a bash array with
# the elements.
# 
# The awk code is nearly unmaintainable. Sorry.

#declare -a Return_Array;
#declare Return_Value;

defaults() {
    local keys="$1"
    local data="$2"

    for k in $keys ; do
        #echo "key: $k  data: $data"
        defaults_parser "$k" "$data" && data=$Return_Val
    done
}

defaults_parser() {
    local key="$1"
    local data="$2"
    local command_line
    local scalar_mode
    local mode

    Return_Val=""

    if [ "${key#\[*\]}" = "$key" ] ; then 
        mode="scalar"
    else
        mode="array"
        index="${key#\[}"
        index="${index#\]}"
        if [ "$index" = "" ] ; then
            index=0
        else 
            index=$((index+1))
        fi
    fi

    if [ "$mode" = "scalar" ] ; then
        command_line="
        ((level == 0) && (tags)) { exit; } \
        /<key>$key<\/key>/ { foundkey = NR; next; } \
        (foundkey  && (! level) && /<(string)|(integer)>.*<\\/(string)|(integer)>/) \
            { tags = \$1; singlevalue = 1; exit; } \
        /(<array>)|(<dict>)/ && (foundkey > 1) \
            { level+=1; tags = tags \$1 \"\\n\"; next; } \
        /(<\\/array>)|(<\\/dict>)/ && (foundkey > 1) \
            { level-=1; tags = tags \$1 \"\\n\"; next; } \
        level > 0 && foundkey \
            { tags = tags \$1 \"\\n\"; next; } \
        END {   if(singlevalue) { split(tags,t,\"<\"); split(t[2],t,\">\"); print t[2]; } \
                else            { print tags  }\
        }
        "
    else
        command_line="
        /<\\/array>/ && level == 1 { exit; } \
        /<array>/ && (level == 0)  { level = 1; arrayindex = 1; next; } \
        /(<string>)|(<integer>).*(<\\/string)>)|(<\\/integer>)/ && level == 1 \
            { split(\$1,t,\"<\"); split(t[2],t,\">\"); value[arrayindex] = t[2]; arrayindex+=1; next; }  \
        /(<array>)|(<dict>)/  \
            { level+=1; value[arrayindex] = value[arrayindex] \$1 \"\\n\"; next; } \
        /(<\\/array>)|(<\\/dict>)/ \
            { level-=1; value[arrayindex] = value[arrayindex] \$1 \"\\n\"; if(level==1) arrayindex+=1;  next; } \
        level > 1 \
            { value[arrayindex] = value[arrayindex] \$1 \"\\n\"; next;   } \
        END { if($index == 0) { out = \"\"; for(idx in value) {  if(idx > 1) out = out \"§\"; out = out value[idx]; } print out; }  \
              else { print value[$index]; } \
        } \
        "
    fi

    Return_Val=`echo "$data" | awk "$command_line"`

    if [ "$mode" = "array" -a "$index" = 0 ] ; then
        OLDIFS=$IFS
        IFS="§"
        local index=0
        for value in $Return_Val ; do
            Return_Array[$index]="$value"
            index=$((index+1))
        done
        IFS=$OLDIFS
    fi
}

# If we can't find the firmware file we try to download it from the
# apple download urls above.
#
extract_firmware() {
    if [ ! -r "$FW_FILE" ] ; then
        echo "try to download the firmware from apple"
        for dl in ${!FW_DOWNLOAD_*} ; do
            url="${!dl}"
            if [ ! "${url/$FIRMWARE//}" = "$url" ] ; then
                APPLE_DL_URL=$url;
            fi
        done
        if [ ! $APPLE_DL_URL ] ; then
            echo "Can't find a download url for requested firmware $FIRMWARE."
            echo "Please check again. Your file should be found in $FW_DIR."
            echo "Download it manually".
            exit 1;
        else 
            echo "URL: $APPLE_DL_URL"
            cd $TMP_DIR
            wget ${APPLE_DL_URL}
            mv $FIRMWARE $FW_DIR
        fi
    fi
    
    cd "$FW_DIR"
    unzip -d "${TMP_DIR}" -o "${FW_FILE}" Restore.plist
    RESTORE_DATA="`cat "${TMP_DIR}/Restore.plist"`"




    defaults DeviceClass "$RESTORE_DATA" &&  FM_DEVICE_CLASS="$Return_Val"
    defaults ProductVersion "$RESTORE_DATA" && FW_PRODUCT_VERSION="$Return_Val"
    defaults ProductBuildVersion "$RESTORE_DATA" && FW_BUILD_VERSION="$Return_Val"
    defaults "RestoreRamDisks User" "$RESTORE_DATA" && FW_RESTORE_RAMDISK="$Return_Val"
    defaults "SystemRestoreImages User" "$RESTORE_DATA" && FW_RESTORE_SYSTEMDISK="$Return_Val"
    
    echo "unzip $FW_RESTORE_SYSTEMDISK"
    unzip -d "${TMP_DIR}" -o "${FW_FILE}" "${FW_RESTORE_SYSTEMDISK}"

    if [ ! "$DECRYPTION_KEY_SYSTEM" ] ; then
        echo "We need the DECRYPTION_KEY for $FW_RESTORE_SYSTEMDISK."
        echo "I try to fetch it from $IPHONEWIKI_KEY_URL"
        cd "${TMP_DIR}"
        wget $IPHONEWIKI_KEY_URL -O $TMP_DIR/key_page.html
        DECRYPTION_KEY_SYSTEM=`awk --re-interval \
            "BEGIN { IGNORECASE=1; } \
            /name=\"$FW_PRODUCT_VERSION.*$FW_BUILD_VERSION/ { found = 1; next; } \
            /([a-fA-F0-9]){72}/ && found == 1 \
            { split(\\$0,result,\"<p>\"); print toupper(result[2]); exit;  } " key_page.html`

        if [ ! "$DECRYPTION_KEY_SYSTEM" ] ; then
            echo "Sorry, no decryption key for system partition found!"
            exit 1;
        fi
        echo "DECRYPTION_KEY_SYSTEM: $DECRYPTION_KEY_SYSTEM"
    fi

    echo "starting vfdecrypt with DECRYPTION_KEY_SYSTEM: $DECRYPTION_KEY_SYSTEM"
    cd "${TMP_DIR}"
    $VFDECRYPT -i"${FW_RESTORE_SYSTEMDISK}" \
               -o"${FW_RESTORE_SYSTEMDISK}.decrypted"\
               -k"$DECRYPTION_KEY_SYSTEM"

    FW_VERSION_DIR="${FW_DIR}/${FW_PRODUCT_VERSION}_${FW_BUILD_VERSION}"
    FW_SYSTEM_DIR="${FW_VERSION_DIR}/system"
    FW_SYSTEM_DMG="${FW_VERSION_DIR}/root_system.dmg"

    [ ! -d $FW_VERSION_DIR ] && mkdir "${FW_VERSION_DIR}"
    [ ! -d $FW_SYSTEM_DIR  ] && mkdir "${FW_SYSTEM_DIR}"

    if [ ! -r ${FW_SYSTEM_DMG} ] ; then
        $DMG extract "${FW_RESTORE_SYSTEMDISK}.decrypted" ${FW_SYSTEM_DMG}
    fi

    sudo mount -t hfsplus -o loop "${FW_SYSTEM_DMG}" "${MNT_DIR}"
    cd "${MNT_DIR}"
    sudo cp -Ra * "${FW_SYSTEM_DIR}"
    cd ${HERE}
    sudo umount "${MNT_DIR}"
    
    if [ -s "${FW_DIR}/${CURRENT_SYSTEM_DIR}" ] ; then
        rm "${FW_DIR}/${CURRENT_SYSTEM_DIR}";
    fi

    # we want something like this:
    # .../files/fw/current -> .../files/fw/2.0_5A347
    ln -s "${FW_SYSTEM_DIR}" "${FW_DIR}/${CURRENT_SYSTEM_DIR}"
}

toolchain_extract_headers() {
    convert_dmg_to_img
    extract_headers
}

toolchain_system_files() {
    build_vfdecrypt
    extract_firmware
}

# This is more or less copy/paste from www.saurik.com/id/4
#
toolchain_build() {

    [ ! -d "$TOOLCHAIN" ] && mkdir -p "${TOOLCHAIN}"
    [ ! -d "$prefix"    ] && mkdir -p "${prefix}"
    [ ! -d "$sysroot"   ] && mkdir -p "${sysroot}"
    [ ! -d "$cctools"   ] && mkdir -p "${cctools}"
    [ ! -d "$csu"       ] && mkdir -p "${csu}"
    [ ! -d "$build"     ] && mkdir -p "${build}"

    cd "${apple}"
    find . -name '*.tar.gz' -exec tar xfzv {} \;

    mkdir -p "$(dirname "${sysroot}")"
    cd "${sysroot}"

    if [ ! -d $iphonefs ] ; then
        echo "!!!! no iphonefs:($iphonefs) !!!!"
        exit 1
    fi

    cp -aH $iphonefs/* "${sysroot}"
    rm -rf usr/include
    cp -a "${leopardinc}" usr/include
    cd usr/include
    ln -s . System

    cp -af "${iphoneinc}"/* .
    cp -af "${apple}"/xnu-1228.3.13/osfmk/* .
    cp -af "${apple}"/xnu-1228.3.13/bsd/* .

    cp -af "${apple}"/cctools-667.3/include/mach .
    cp -af "${apple}"/cctools-667.3/include/mach-o .
    cp -af "${iphoneinc}"/mach-o/dyld.h mach-o

    cp -af "${leopardinc}"/mach/machine mach
    cp -af "${leopardinc}"/mach/machine.h mach
    cp -af "${leopardinc}"/machine .
    cp -af "${iphoneinc}"/machine .

    cp -af "${iphoneinc}"/sys/cdefs.h sys
    cp -af "${leopardinc}"/sys/dtrace.h sys

    cp -af "${leopardlib}"/Kernel.framework/Headers/machine/disklabel.h machine
    cp -af "${apple}"/configd-210/dnsinfo/dnsinfo.h .
    cp -a "${apple}"/Libc-498/include/kvm.h .
    cp -a "${apple}"/launchd-258.1/launchd/src/*.h .

    cp -a i386/disklabel.h arm
    cp -a mach/i386/machine_types.defs mach/arm

    # if you don't have mig, just ignore this for now
    #for defs in clock_reply exc mach_exc notify; do
    #    mig -server /dev/null -user /dev/null -header /dev/null \
    #        -sheader mach/"${defs}"_server.h mach/"${defs}".defs
    #done

    mkdir Kernel
    cp -a "${apple}"/xnu-1228.3.13/libsa/libsa Kernel

    mkdir Security
    cp -a "${apple}"/libsecurity_authorization-32564/lib/*.h Security
    cp -a "${apple}"/libsecurity_cdsa_client-32432/lib/*.h Security
    cp -a "${apple}"/libsecurity_cdsa_utilities-32432/lib/*.h Security
    cp -a "${apple}"/libsecurity_cms-32521/lib/*.h Security
    cp -a "${apple}"/libsecurity_codesigning-32953/lib/*.h Security
    cp -a "${apple}"/libsecurity_cssm-32993/lib/*.h Security
    cp -a "${apple}"/libsecurity_keychain-32768/lib/*.h Security
    cp -a "${apple}"/libsecurity_mds-32820/lib/*.h Security
    cp -a "${apple}"/libsecurity_ssl-32463/lib/*.h Security
    cp -a "${apple}"/libsecurity_utilities-32820/lib/*.h Security
    cp -a "${apple}"/libsecurityd-32914/lib/*.h Security

    mkdir DiskArbitration
    cp -a "${apple}"/DiskArbitration-183/DiskArbitration/*.h DiskArbitration

    cp -a "${apple}"/xnu-1228.3.13/iokit/IOKit .
    cp -a "${apple}"/IOKitUser-388/*.h IOKit

    cp -a "${apple}"/IOGraphics-193.2.2/IOGraphicsFamily/IOKit/graphics IOKit
    cp -a "${apple}"/IOHIDFamily-258.1/IOHIDSystem/IOKit/hidsystem IOKit

    for proj in kext ps pwr_mgt; do
        mkdir -p IOKit/"${proj}"
        cp -a "${apple}"/IOKitUser-388/"${proj}".subproj/*.h IOKit/"${proj}"
    done

    mkdir IOKit/storage
    cp -a "${apple}"/IOStorageFamily-88/*.h IOKit/storage
    cp -a "${apple}"/IOCDStorageFamily-39/*.h IOKit/storage
    cp -a "${apple}"/IODVDStorageFamily-26/*.h IOKit/storage

    mkdir SystemConfiguration
    cp -a "${apple}"/configd-210/SystemConfiguration.fproj/*.h SystemConfiguration

    mkdir WebCore
    #cp -a "${apple}"/WebCore-4A102/bindings/objc/*.h WebCore
    cp -a  "${apple}"/WebCore-5523.15.1/bindings/objc/*.h WebCore

    cp -aH "${leopardlib}"/CoreFoundation.framework/Headers CoreFoundation
    cp -af "${apple}"/CF-476.10/*.h CoreFoundation
    cp -af "${iphonelib}"/CoreFoundation.framework/Headers/* CoreFoundation

    for framework in AudioToolbox AudioUnit CoreAudio Foundation; do
        cp -aH "${leopardlib}"/"${framework}".framework/Headers "${framework}"
        cp -af "${iphonelib}"/"${framework}".framework/Headers/* "${framework}"
    done

    # UIKit fix (these are only the public framework headers)
    mkdir UIKit
    cp -aH "${iphonelib}"/UIKit.framework/Headers/* UIKit 

    for framework in AppKit Cocoa CoreData CoreVideo JavaScriptCore OpenGL QuartzCore WebKit; do
        cp -aH "${leopardlib}"/"${framework}".framework/Headers "$(basename "${framework}" .framework)"
    done

    cp -aH "${leopardlib}"/ApplicationServices.framework/Headers ApplicationServices
    for service in "${leopardlib}"/ApplicationServices.framework/Frameworks/*.framework; do
        cp -aH "${service}"/Headers "$(basename "${service}" .framework)"
    done

    cp -aH "${leopardlib}"/CoreServices.framework/Headers CoreServices
    for service in "${leopardlib}"/CoreServices.framework/Frameworks/*.framework; do
        cp -aH "${service}"/Headers "$(basename "${service}" .framework)"
    done

    # this step may have a bad hunk in CoreFoundation and thread_status while patching
    # these errors are to be ignored, as these are changes for issues Apple has now fixed
    wget -qO- http://svn.telesphoreo.org/trunk/tool/include.diff | patch -p3
    wget -qO arm/locks.h http://svn.telesphoreo.org/trunk/tool/patches/locks.h

    mkdir GraphicsServices
    cd GraphicsServices
    wget -q http://svn.telesphoreo.org/trunk/tool/patches/GraphicsServices.h

    cd "${sysroot}"
    ln -sf gcc/darwin/4.0/stdint.h usr/include
    ln -s libstdc++.6.dylib usr/lib/libstdc++.dylib

    mkdir -p "${csu}"
    cd "${csu}"
    svn co http://iphone-dev.googlecode.com/svn/trunk/csu .
    cp -a *.o "${sysroot}"/usr/lib
    cd "${sysroot}"/usr/lib
    chmod 644 *.o
    cp -af crt1.o crt1.10.5.o
    cp -af dylib1.o dylib1.10.5.o

    rm -rf "${gcc}"
    git clone git://git.saurik.com/llvm-gcc-4.2 "${gcc}"

    rm -rf "${cctools}"
    svn co http://iphone-dev.googlecode.com/svn/branches/odcctools-9.2-ld "${cctools}"

    mkdir -p "${build}"
    cd "${build}"
    mkdir cctools-iphone
    cd cctools-iphone
    CFLAGS=-m32 LDFLAGS=-m32 "${cctools}"/configure \
        --target="${target}" \
        --prefix="${prefix}" \
        --disable-ld64
    make
    make install


    mkdir -p "${build}"
    cd "${build}"
    mkdir gcc-4.2-iphone
    cd gcc-4.2-iphone
    "${gcc}"/configure \
        --target="${target}" \
        --prefix="${prefix}" \
        --with-sysroot="${sysroot}" \
        --enable-languages=c,c++,objc,obj-c++ \
        --with-as="${prefix}"/bin/"${target}"-as \
        --with-ld="${prefix}"/bin/"${target}"-ld \
        --enable-wchar_t=no \
        --with-gxx-include-dir=/usr/include/c++/4.0.0
    make -j2
    make install

    mkdir -p "${sysroot}"/"$(dirname "${prefix}")"
    ln -s "${prefix}" "${sysroot}"/"$(dirname "${prefix}")"

#    for lib in crypto curses form gcc_s ncurses sqlite3 ssl xml2; do
#        rm -f "${sysroot}"/usr/lib/lib${lib}.*
#    done

}



toolchain_env() {
    export TOOLCHAIN="${IPHONEDEV_DIR}/toolchain"
    export apple="${FILES_DIR}/darwin_sources"
    export iphonefs="${FW_DIR}/${CURRENT_SYSTEM_DIR}"
    export target="arm-apple-darwin9"
    export leopardsdk="${SDKS_DIR}/MacOSX10.5.sdk"
    export leopardinc="${leopardsdk}/usr/include"
    export leopardlib="${leopardsdk}/System/Library/Frameworks"
    export iphonesdk="${SDKS_DIR}/iPhoneOS2.0.sdk"
    export iphoneinc="${iphonesdk}/usr/include"
    export iphonelib="${iphonesdk}/System/Library/Frameworks"

    export prefix="$TOOLCHAIN/pre"
    export sysroot="$TOOLCHAIN/sys"
    export PATH="${prefix}/bin":"${PATH}" 
    export cctools="$TOOLCHAIN/src/cctools"
    export gcc="$TOOLCHAIN/src/gcc"
    export csu="$TOOLCHAIN/src/csu"
    export build="$TOOLCHAIN/bld"
}

toolchain_env
check_commands
check_dirs
build_tools
cleanup_tmp

while test $# -gt 0 ; do
    case $1 in
        extractheaders | getheaders | headers )
            shift
            echo "getting the headers"
            toolchain_extract_headers
            ;;
        firmware | system | rootfs)
            shift
            echo "extract firmware files"
            toolchain_system_files
            ;;
        build )
            shift
            echo "build the toolchain"
            toolchain_build
            ;;
       *)
       break ;;
  esac
done

cd ${HERE}

