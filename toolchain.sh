#!/bin/bash

# Build everything relative to IPHONEDEV_DIR
# Default is /home/loginname/iphonedev
IPHONEDEV_DIR="${HOME}/iphonedev"

# You need to download (to ./files/)
IPHONE_SDK="iphone_sdk_for_iphone_os_2.1__final.dmg"

# This is downloaded automatically
FIRMWARE="iPhone1,1_2.1_5F136_Restore.ipsw"

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
# some steps you are asked for your password because we need
# root privileges to loop-mount some .dmg/.img files.
#
# 1. set your prefered IPHONEDEV_DIR. All files and the
#    complete toolchain will reside there.
#
# 2. ./toolchain.sh headers
# 3. ./toolchain.sh system
# 4. ./toolchain.sh darwin_sources APPLE_ID=YourAppleID APPLE_PASSWORD=YourPassword
# 5. ./toolchain.sh build
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
# ./SDKs/iPhoneOS2.{version}.sdk (the extracted SDK from iphone_sdk_final.dmg)
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
#   Results in ready extracted ./SDKs/iPhoneOS2.{version}.sdk 
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
#   These packages should be copied to ./files/darwin_sources
#
#   or use: 
#
# ./toolchain.sh darwin_sources APPLE_ID=xyz APPLE_PASSWORD=xyz
#   Download the darwin sources from http://www.opensource.apple.com.
#   You previously need to register at developer.apple.com.
#

# this is the name with the symlink to the current firmware
# system folder
CURRENT_SYSTEM_DIR="current"

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
FW_DOWNLOAD_1G_210="$FW_DOWNLOAD_URL/061-5202.20080909.gkbEj/iPhone1,1_2.1_5F136_Restore.ipsw"
FW_DOWNLOAD_1G_202="$FW_DOWNLOAD_URL/061-5246.20080818.2V0hO/iPhone1,1_2.0.2_5C1_Restore.ipsw"
FW_DOWNLOAD_1G_201="$FW_DOWNLOAD_URL/061-5135.20080729.Vfgtr/iPhone1,1_2.0.1_5B108_Restore.ipsw"
FW_DOWNLOAD_1G_200="$FW_DOWNLOAD_URL/061-4956.20080710.V50OI/iPhone1,1_2.0_5A347_Restore.ipsw"
FW_DOWNLOAD_3G_210="$FW_DOWNLOAD_URL/061-5198.20080909.K3294/iPhone1,2_2.1_5F136_Restore.ipsw"
FW_DOWNLOAD_3G_202="$FW_DOWNLOAD_URL/061-5241.20080818.t5Fv3/iPhone1,2_2.0.2_5C1_Restore.ipsw"
FW_DOWNLOAD_3G_201="$FW_DOWNLOAD_URL/061-5134.20080729.Q2W3E/iPhone1,2_2.0.1_5B108_Restore.ipsw"
FW_DOWNLOAD_3G_200="$FW_DOWNLOAD_URL/061-5241.20080818.t5Fv3/iPhone1,2_2.0.2_5C1_Restore.ipsw"

APPLE_AUTH_COOKIES="apple_auth_cookies.txt"
SAFARI_USER_AGENT='Mozilla/5.0 (Macintosh; U; Intel Mac OS X 10_5_5; de-de) AppleWebKit/525.18 (KHTML, like Gecko) Version/3.1.2 Safari/525.20.1'

DARWIN_SOURCES_URL="http://www.opensource.apple.com/darwinsource/tarballs"
DARWIN_SOURCES_FILES_DIR="$FILES_DIR/darwin_sources"
DARWIN_SOURCES_APSL="
cctools-667.3.tar.gz
CF-476.10.tar.gz
configd-210.tar.gz
DiskArbitration-183.tar.gz
IOCDStorageFamily-39.tar.gz
IODVDStorageFamily-26.tar.gz
IOGraphics-193.2.2.tar.gz
IOGraphics-233.1.tar.gz
IOHIDFamily-258.1.tar.gz
IOKitUser-388.tar.gz
IOStorageFamily-88.tar.gz
Libc-498.tar.gz
launchd-258.1.tar.gz
libsecurity_authorization-32564.tar.gz
libsecurity_cdsa_client-32432.tar.gz
libsecurity_cdsa_utilities-32432.tar.gz
libsecurity_cms-32521.tar.gz
libsecurity_codesigning-32953.tar.gz
libsecurity_cssm-32993.tar.gz
libsecurityd-32914.tar.gz
libsecurity_keychain-32768.tar.gz
libsecurity_mds-32820.tar.gz
libsecurity_ssl-32463.tar.gz
libsecurity_utilities-32820.tar.gz
xnu-1228.3.13.tar.gz
"

DARWIN_SOURCES_OTHER="
WebCore-5523.15.1.tar.gz
"

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
        $DARWIN_SOURCES_FILES_DIR \
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
    mv $TMP_DIR/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS2.1.sdk ${SDKS_DIR}

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

_download_darwin_file() {
    local URL=$1
    Return_Val=$(wget -U "$SAFARI_USER_AGENT" \
             -P "$DARWIN_SOURCES_FILES_DIR" \
             --server-response \
             --load-cookies "$APPLE_AUTH_COOKIES" \
             "$URL" 2>&1 | awk \
             '/302 Found/ { redirect = 1; } (/Location:.*/ && redirect == 1) { print $2; exit; }')
}

download_darwin_sources() {
    local URL
    local RESPONSE

    # Delete old login files
    for f in $DARWIN_SOURCES_FILES_DIR/login* $DARWIN_SOURCES_FILES_DIR/[01].[01].[01].[01].[01].* ; do
        rm $f
    done


    # This is bad style. Have to generalize download for
    # APSL (apple licensed) and OTHER (other licensed) code.

    for DL in $DARWIN_SOURCES_OTHER ; do
        if [ -r "$DARWIN_SOURCES_FILES_DIR/$DL" ] ; then
            echo "Found file: $DL. Skip this download"
            continue
        else
            echo "try to download: $DL"
        fi

        URL="$DARWIN_SOURCES_URL/other/$DL"
        _download_darwin_file $URL

        if [ -r "$DARWIN_SOURCES_FILES_DIR/$DL" ] ; then
            echo "Download of $DL finished"
        else
            echo "Error: Download of $DL failed. Exit now.";
            exit 1;
        fi

    done

    for DL in $DARWIN_SOURCES_APSL ; do

        if [ -r "$DARWIN_SOURCES_FILES_DIR/$DL" ] ; then
            echo "Found file: $DL. Skip this download"
            continue
        else
            echo "try to download: $DL"
        fi

        URL="$DARWIN_SOURCES_URL/apsl/$DL"
        _download_darwin_file $URL

        if [ "$Return_Val" != "" ] ; then
            LOGIN_FILE=`ls $DARWIN_SOURCES_FILES_DIR/login* 2>/dev/null`
            if [ "$LOGIN_FILE" != "" ] ; then
                echo "try to login as: $APPLE_ID"
                ACTION=$(cat $LOGIN_FILE | awk \
                    'match($0,/action=".*"/) \
                    { print substr($0,RSTART+8, RLENGTH-9); exit; }')

                POSTDATA="theAccountName=$APPLE_ID"
                POSTDATA="${POSTDATA}&theAccountPW=$APPLE_PASSWORD"
                POSTDATA="${POSTDATA}&theAuxValue=1"
                POSTDATA="${POSTDATA}&1.Continue.x=10&1.Continue.y=10"
                RESPONSE=$(wget \
                    --user-agent="$SAFARI_USER_AGENT" \
                    --referer="$RESPONSE" \
                    -P "$DARWIN_SOURCES_FILES_DIR" \
                    --server-response \
                    --save-cookies "$APPLE_AUTH_COOKIES" \
                    --keep-session-cookies \
                    --post-data="$POSTDATA" \
                    "https://daw.apple.com${ACTION}")
                
                # check if login succeeded
                LOGIN_FILE="$DARWIN_SOURCES_FILES_DIR/`basename $ACTION`"
                CHECK=`cat $LOGIN_FILE | \
                    awk \
                    '/Your Apple ID or password was entered incorrectly/ { print "NO"; exit; }'`
                if [ "$CHECK" == "NO" ] ; then
                    echo "LOGIN with your APPLE_ID ($APPLE_ID) not successful"
                    exit 1
                else 
                    echo "LOGIN correct. Try to download $URL again"
                fi

                # try again the download
                _download_darwin_file $URL
            fi
        fi

        if [ -r "$DARWIN_SOURCES_FILES_DIR/$DL" ] ; then
            echo "Download of $DL finished"
        else
            echo "Error: Download of $DL failed. Exit now.";
            exit 1;
        fi
    done
}

toolchain_download_darwin_sources() {
    if [ -z "$APPLE_ID" ] ; then
        echo "have no APPLE_ID."
        echo "usage: ./toolchain.sh darwin_sources APPLE_ID=MyAppleID APPLE_PASSWORD=MyPassword"
        exit 1;
    fi
    if [ -z "$APPLE_PASSWORD" ] ; then
        echo "have no APPLE_PASSWORD"
        echo "usage: ./toolchain.sh darwin_sources APPLE_ID=MyAppleID APPLE_PASSWORD=MyPassword"
        exit 1;
    fi

    download_darwin_sources
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

    sudo cp -aH $iphonefs/* "${sysroot}"
    sudo chown -R `id -u`:`id -g` "${sysroot}"
    sudo rm -rf usr/include
    
#    mkdir usr/include
#    if [ ! -d usr/include ] ; then
#        echo "failed to create ${sysroot}/usr/include"
#        exit 1
#    fi

    cp -a "${leopardinc}" usr/include
    cd usr/include
    ln -s . System

    cp -af "${iphoneinc}"/* .
    cp -af "${apple}"/xnu-*/osfmk/* .
    cp -af "${apple}"/xnu-*/bsd/* .

    cp -af "${apple}"/cctools-*/include/mach .
    cp -af "${apple}"/cctools-*/include/mach-o .
    cp -af "${iphoneinc}"/mach-o/dyld.h mach-o

    cp -af "${leopardinc}"/mach/machine mach
    cp -af "${leopardinc}"/mach/machine.h mach
    cp -af "${leopardinc}"/machine .
    cp -af "${iphoneinc}"/machine .

    cp -af "${iphoneinc}"/sys/cdefs.h sys
    cp -af "${leopardinc}"/sys/dtrace.h sys

    cp -af "${leopardlib}"/Kernel.framework/Headers/machine/disklabel.h machine
    cp -af "${apple}"/configd-*/dnsinfo/dnsinfo.h .
    cp -a "${apple}"/Libc-*/include/kvm.h .
    cp -a "${apple}"/launchd-*/launchd/src/*.h .

    cp -a i386/disklabel.h arm
    cp -a mach/i386/machine_types.defs mach/arm

    # if you don't have mig, just ignore this for now
    #for defs in clock_reply exc mach_exc notify; do
    #    mig -server /dev/null -user /dev/null -header /dev/null \
    #        -sheader mach/"${defs}"_server.h mach/"${defs}".defs
    #done

    mkdir Kernel
    cp -a "${apple}"/xnu-*/libsa/libsa Kernel

    mkdir Security
    cp -a "${apple}"/libsecurity_authorization-*/lib/*.h Security
    cp -a "${apple}"/libsecurity_cdsa_client-*/lib/*.h Security
    cp -a "${apple}"/libsecurity_cdsa_utilities-*/lib/*.h Security
    cp -a "${apple}"/libsecurity_cms-*/lib/*.h Security
    cp -a "${apple}"/libsecurity_codesigning-*/lib/*.h Security
    cp -a "${apple}"/libsecurity_cssm-*/lib/*.h Security
    cp -a "${apple}"/libsecurity_keychain-*/lib/*.h Security
    cp -a "${apple}"/libsecurity_mds-*/lib/*.h Security
    cp -a "${apple}"/libsecurity_ssl-*/lib/*.h Security
    cp -a "${apple}"/libsecurity_utilities-*/lib/*.h Security
    cp -a "${apple}"/libsecurityd-*/lib/*.h Security

    mkdir DiskArbitration
    cp -a "${apple}"/DiskArbitration-*/DiskArbitration/*.h DiskArbitration

    cp -a "${apple}"/xnu-*/iokit/IOKit .
    cp -a "${apple}"/IOKitUser-*/*.h IOKit

    cp -a "${apple}"/IOGraphics-*/IOGraphicsFamily/IOKit/graphics IOKit
    cp -a "${apple}"/IOHIDFamily-*/IOHIDSystem/IOKit/hidsystem IOKit

    for proj in kext ps pwr_mgt; do
        mkdir -p IOKit/"${proj}"
        cp -a "${apple}"/IOKitUser-*/"${proj}".subproj/*.h IOKit/"${proj}"
    done

    mkdir IOKit/storage
    cp -a "${apple}"/IOStorageFamily-*/*.h IOKit/storage
    cp -a "${apple}"/IOCDStorageFamily-*/*.h IOKit/storage
    cp -a "${apple}"/IODVDStorageFamily-*/*.h IOKit/storage

    mkdir SystemConfiguration
    cp -a "${apple}"/configd-*/SystemConfiguration.fproj/*.h SystemConfiguration

    mkdir WebCore
    cp -a  "${apple}"/WebCore-*/bindings/objc/*.h WebCore

    cp -aH "${leopardlib}"/CoreFoundation.framework/Headers CoreFoundation
    cp -af "${apple}"/CF-*/*.h CoreFoundation
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

    # This is dirty. We patch Availability ourselfs and I'm not sure
    # if this patch is OK. But it compiles our code with 
    # this. Someone (maybe saurik, the original patch is from him and
    # I only modified it to match the newest 2.1 headers) should read
    # against this script because I'm MacOSX newbie.

    patch -p3 <<'EOPATCH'
--- ./usr/include/AvailabilityInternal.h.orig	2008-10-20 14:32:09.000000000 +0200
+++ ./usr/include/AvailabilityInternal.h	2008-10-20 14:39:52.000000000 +0200
@@ -45,6 +45,15 @@
     #else
         #define __AVAILABILITY_INTERNAL__IPHONE_2_0
     #endif
+
+    #if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_1_2
+        #define __AVAILABILITY_INTERNAL__IPHONE_1_2  __AVAILABILITY_INTERNAL_UNAVAILABLE
+    #elif __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_1_2
+        #define __AVAILABILITY_INTERNAL__IPHONE_1_2  __AVAILABILITY_INTERNAL_WEAK_IMPORT
+    #else
+        #define __AVAILABILITY_INTERNAL__IPHONE_1_2
+    #endif
+
     #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_NA     __AVAILABILITY_INTERNAL__IPHONE_2_0
     #define __AVAILABILITY_INTERNAL__IPHONE_2_0_DEP__IPHONE_2_0    __AVAILABILITY_INTERNAL_DEPRECATED
     #if __IPHONE_OS_VERSION_MAX_ALLOWED < __IPHONE_2_1
@@ -63,7 +72,20 @@
     #endif
     #define __AVAILABILITY_INTERNAL__IPHONE_NA                     __AVAILABILITY_INTERNAL_UNAVAILABLE 
     #define __AVAILABILITY_INTERNAL__IPHONE_NA_DEP__IPHONE_NA      __AVAILABILITY_INTERNAL_UNAVAILABLE
-    
+
+    #if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_1_2
+        #define __AVAILABILITY_INTERNAL__IPHONE_1_0_DEP__IPHONE_1_2  __AVAILABILITY_INTERNAL_DEPRECATED
+    #else
+        #define __AVAILABILITY_INTERNAL__IPHONE_1_0_DEP__IPHONE_1_2  __AVAILABILITY_INTERNAL__IPHONE_1_0
+    #endif
+    #if __IPHONE_OS_VERSION_MIN_REQUIRED >= __IPHONE_2_0
+        #define __AVAILABILITY_INTERNAL__IPHONE_1_0_DEP__IPHONE_2_0  __AVAILABILITY_INTERNAL_DEPRECATED
+        #define __AVAILABILITY_INTERNAL__IPHONE_1_2_DEP__IPHONE_2_0  __AVAILABILITY_INTERNAL_DEPRECATED
+    #else
+        #define __AVAILABILITY_INTERNAL__IPHONE_1_0_DEP__IPHONE_2_0  __AVAILABILITY_INTERNAL__IPHONE_1_0
+        #define __AVAILABILITY_INTERNAL__IPHONE_1_2_DEP__IPHONE_2_0  __AVAILABILITY_INTERNAL__IPHONE_1_2
+    #endif
+
 #elif defined(__ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__)
     // compiler for Mac OS X sets __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__
     #define __MAC_OS_X_VERSION_MIN_REQUIRED __ENVIRONMENT_MAC_OS_X_VERSION_MIN_REQUIRED__
EOPATCH

    # In this patch from saurik is also a patch again AvailabilityInternal which will
    # fail here because we previously patched this file.
    #
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
    sudo cp -a *.o "${sysroot}"/usr/lib
    cd "${sysroot}"/usr/lib
    chmod 644 *.o
    sudo cp -af crt1.o crt1.10.5.o
    sudo cp -af dylib1.o dylib1.10.5.o

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

getopt_simple() {
    local tmp
    until [ -z "$1" ]
    do
        tmp=$1               
        parameter=${tmp%%=*}
        value=${tmp##*=}
        eval $parameter=$value
        shift
    done
}

toolchain_env() {
    export TOOLCHAIN="${IPHONEDEV_DIR}/toolchain"
    export apple="${FILES_DIR}/darwin_sources"
    export iphonefs="${FW_DIR}/${CURRENT_SYSTEM_DIR}"
    export target="arm-apple-darwin9"
    export leopardsdk="${SDKS_DIR}/MacOSX10.5.sdk"
    export leopardinc="${leopardsdk}/usr/include"
    export leopardlib="${leopardsdk}/System/Library/Frameworks"
    export iphonesdk="${SDKS_DIR}/iPhoneOS2.1.sdk"
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

APPLE_ID=""
APPLE_PASSWORD=""

while test $# -gt 0 ; do
    case $1 in
        extractheaders | getheaders | headers)
            shift
            echo "getting the headers"
            toolchain_extract_headers
            ;;
        darwin_sources)
            shift
            getopt_simple $1
            shift
            getopt_simple $1
            shift
            echo "download darwin sources from www.opensource.apple.com"
            echo "apple_id:$APPLE_ID apple_password: $APPLE_PASSWORD"
            toolchain_download_darwin_sources
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

