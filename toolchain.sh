#!/bin/bash

# Copyright (c) 2008 iphonedevlinux <iphonedevlinux@googlemail.com>
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

# What version of the toolchain are we building?
TOOLCHAIN_VERSION="2.2"

# Build everything relative to IPHONEDEV_DIR
# Default is /home/loginname/iphonedev
IPHONEDEV_DIR="${HOME}/Projects/iphone/toolchain/"

# This is downloaded automatically
FIRMWARE="iPhone1,1_2.2_5G77_Restore.ipsw"

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
SDKS_DIR="${IPHONEDEV_DIR}/sdks"
TOOLS_DIR="${IPHONEDEV_DIR}/tools"
XPWN_DIR="${TOOLS_DIR}/xpwn"
MIG_DIR="${TOOLS_DIR}/mig"
TMP_DIR="${IPHONEDEV_DIR}/tmp"
MNT_DIR="${TMP_DIR}/mnt"
FW_DIR="${FILES_DIR}/firmware"
FW_FILE="${FW_DIR}/${FIRMWARE}"

IPHONE_SDK="iphone_sdk_for_iphone_os_${TOOLCHAIN_VERSION}__final.dmg"
IPHONE_SDK_DMG="${FILES_DIR}/${IPHONE_SDK}"
IPHONE_SDK_IMG="${FILES_DIR}/iphone_sdk.img"

DMG="${TOOLS_DIR}/dmg"
VFDECRYPT="${TOOLS_DIR}/vfdecrypt"
MIG="${MIG_DIR}/mig"

MACOSX_PKG="${MNT_DIR}/Packages/MacOSX10.5.pkg"
IPHONE_PKG="${MNT_DIR}/Packages/iPhoneSDKHeadersAndLibs.pkg"

# Tools
XPWN_GIT="git://github.com/planetbeing/xpwn.git"
MIG_URL="ftp://ftp.gnu.org/gnu/mig/mig-1.3.tar.gz"
#MIG_URL=""
VFDECRYPT_TGZ="vfdecrypt-linux.tar.gz"
VFDECRYPT_URL="http://iphone-elite.googlecode.com/files/${VFDECRYPT_TGZ}"
IPHONEWIKI_KEY_URL="http://www.theiphonewiki.com/wiki/index.php?title=VFDecrypt_Keys"

# Apple (URL's see: http://modmyifone.com/wiki/index.php/IPhone_Firmware_Download_Links)
# Updated to include firmware 2.2 from (http://www.iclarified.com/entry/index.php?enid=750)

FW_DOWNLOAD_URL="http://appldnld.apple.com.edgesuite.net/content.info.apple.com/iPhone"

FW_DOWNLOAD_1G_220="$FW_DOWNLOAD_URL/061-5779.20081120.Pt5yH/iPhone1,1_2.2_5G77_Restore.ipsw"
FW_DOWNLOAD_1G_210="$FW_DOWNLOAD_URL/061-5202.20080909.gkbEj/iPhone1,1_2.1_5F136_Restore.ipsw"
FW_DOWNLOAD_1G_202="$FW_DOWNLOAD_URL/061-5246.20080818.2V0hO/iPhone1,1_2.0.2_5C1_Restore.ipsw"
FW_DOWNLOAD_1G_201="$FW_DOWNLOAD_URL/061-5135.20080729.Vfgtr/iPhone1,1_2.0.1_5B108_Restore.ipsw"
FW_DOWNLOAD_1G_200="$FW_DOWNLOAD_URL/061-4956.20080710.V50OI/iPhone1,1_2.0_5A347_Restore.ipsw"

FW_DOWNLOAD_3G_220="$FW_DOWNLOAD_URL/061-5778.20081120.Aqw4R/iPhone1,2_2.2_5G77_Restore.ipsw"
FW_DOWNLOAD_3G_210="$FW_DOWNLOAD_URL/061-5198.20080909.K3294/iPhone1,2_2.1_5F136_Restore.ipsw"
FW_DOWNLOAD_3G_202="$FW_DOWNLOAD_URL/061-5241.20080818.t5Fv3/iPhone1,2_2.0.2_5C1_Restore.ipsw"
FW_DOWNLOAD_3G_201="$FW_DOWNLOAD_URL/061-5134.20080729.Q2W3E/iPhone1,2_2.0.1_5B108_Restore.ipsw"
FW_DOWNLOAD_3G_200="$FW_DOWNLOAD_URL/061-5241.20080818.t5Fv3/iPhone1,2_2.0.2_5C1_Restore.ipsw"

# Download information for Apple's open source components
AID_LOGIN="https://daw.apple.com/cgi-bin/WebObjects/DSAuthWeb.woa/wa/login?appIdKey=D236F0C410E985A7BB866A960326865E7F924EB042FA9A161F6A628F0291F620&path=/darwinsource/tarballs/apsl/cctools-667.8.0.tar.gz"
DARWIN_SOURCES_FILES_DIR="$FILES_DIR/darwin_sources"

NEEDED_COMMANDS="git-clone git-pull gcc cmake make sudo mount xar cpio tar wget unzip"
NEEDED_PACKAGES="libssl-dev libbz2-dev gawk gobjc bison flex"

HERE=`pwd`

# Just some internal tracking
# declare -i ERROR_COUNT

# Beautified echo commands
cecho() {
	while [ $# > 1 ]; do
		case $1 in
			red)	echo -n "$(tput setaf 1)";;
			green)	echo -n "$(tput setaf 2)";;
			blue)	echo -n "$(tput setaf 3)";;
			purple)	echo -n "$(tput setaf 4)";;
			cyan)	echo -n "$(tput setaf 5)";;
			grey)	echo -n "$(tput setaf 6)";;
			white)	echo -n "$(tput setaf 7)";;
			bold)	echo -n "$(tput bold)";;
			*) 	break;;
		esac
		shift
	done
	echo "$*$(tput sgr0)"
}

error() {
	ERROR_COUNT=$ERROR_COUNT+1
	cecho red $*
}

message_status() {
	cecho green $*
}

message_action() {
	cecho blue $*
}

check_commands() {
    local command
    local missing
    for c in $NEEDED_COMMANDS ; do
        command=$(which $c)
        if [ -z $command ] ; then 
            missing="$missing $c"
        fi
    done
    if [ "$missing" != "" ] ; then
        error "The following commands are missing:$missing"
        error "You may need to install additional software for them using your package manager."
        exit 1
    fi
}

check_packages() {
	local missing
	for p in $NEEDED_PACKAGES; do
		local package_state=$(dpkg --get-selections | awk "/^$p.*(install)$/ { print \$2; exit }")
		if ! [ "$package_state" == "install" ]; then
			missing="$missing $p"
		fi
	done
	if [ "$missing" != "" ] ; then
		error "The following required packages are missing:$missing"
		error "You may need to install them using your package manager."
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

defaults() {
    local keys="$1"
    local data="$2"

    for k in $keys ; do
        defaults_parser "$k" "$data" && data=$Return_Val
    done
}

defaults_parser() {
    local key="$1"
    local data="$2"
    local command_line
    local scalar_mode
    local mode
    local Return_Val=""

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

build_tools() {
    build_xpwn_dmg
    build_vfdecrypt
}

# Builds the XPWN dmg decryption tools, which we will use later to convert dmgs to
# images, so that we can mount them.
build_xpwn_dmg() {
    [ ! -d $TOOLS_DIR ] && mkdir -p $TOOLS_DIR
    [ -x $DMG ] && return

    # Check for xpwn and try to update it if we're working off the git
    # repo that should have been extracted earlier
    if [ -d $XPWN_DIR ] ; then
        if [ -d "$XPWN_DIR/.git" ] ; then
            message_status "Updating xpwn git..."
            if cd "$XPWN_DIR" && ! git pull $XPWN_GIT master; then
            	error "Failed to pull xpwn git. Check errors."
            	exit 1
            fi
        fi
    else 
        message_status "Checking out xpwn git..."
        if ! git clone $XPWN_GIT $XPWN_DIR; then
        	error "Failed to clone xpwn git. Check errors."
        	exit 1
        fi
    fi

    cd $XPWN_DIR

    message_status "Building xpwn's dmg-to-iso tool..."
    [ -r Makefile ] && make clean
    if cmake CMakeLists.txt && cd dmg && make; then
	message_status "Build finished."
	if cp dmg $DMG; then
		# Get rid of the xpwn stuff, we don't need it anymore
		message_status "Removing xpwn remnants."
		cd $HERE && rm -Rf $XPWN_DIR
	else
		error "Failed to copy xpwn's dmg-to-iso tool to ${DMG}."
		exit 1
	fi
    else
    	error "Failed to make xpwn. Check errors."
    	exit 1
    fi
}

# Retrieve and build vfdecrypt, which is used for decrypting the ipsw firmware images
# which we will download automatically.
build_vfdecrypt() {
    if [ ! -x $VFDECRYPT ] ; then
    	message_status "Downloading and building vfdecrypt..."
        cd $TOOLS_DIR
        
        # Try to locate the tool source or ask the user if we can't find it. As a last
        # resort we can download it.
        if [ ! -r $VFDECRYPT_TGZ ]; then
        	echo "I can't find the VFDecrypt source (`$VFDECRYPT_TGZ`)."
        	read -p "Do you have it (y/N)? "
        	if [ "$REPLY" == "yes" ] || [ "$REPLY" == "y"]; then
        		read -p "Location of VFDecrypt: " VFDECRYPT_TGZ
        	else
        		read -p "Do you want me to download it (Y/n)? "
        		[ "$REPLY" != "no" ] && [ "$REPLY" != "n" ] && wget $VFDECRYPT_URL
        	fi
        fi
        
        if [ -r $VFDECRYPT_TGZ ]; then
        	tar xfzv $VFDECRYPT_TGZ vfdecrypt.c
        	if ! gcc -o vfdecrypt vfdecrypt.c -lssl; then
        		error "Failed to build VFdecrypt! Check errors."
        		exit 1
        	fi
        	rm $VFDECRYPT_TGZ vfdecrypt.c
        else
        	error "I can't find the VFdecrypt source or executable."
        	error "Building the toolchain cannot proceed"
        	exit 1
        fi
    fi
}

convert_dmg_to_img() {
    [ ! -x $DMG ] && error "$DMG not found/executable." && exit 1

    # Look for the DMG and ask the user if is isn't findable. It's probably possible
    # to automate this, however I don't feel it's appropriate at this time considering
    # that the download size would force the user to leave the script running unattended
    # for too long.
    if [ ! -r $IPHONE_SDK_IMG ] && [ ! -r $IPHONE_SDK_DMG ] ; then
    	error "I'm having trouble finding the iPhone SDK. I looked here:"
    	error $IPHONE_SDK_DMG
    	read -p "Do you have the SDK (y/N)? "
    	if [ "$REPLY" != "y" ]; then
    		error "You will need to download the SDK before you can build the toolchain. The"
    		error "required file can be obtained from: http://developer.apple.com/iphone/"
    		exit 1
    	fi
    	echo "Please enter the full path to the dmg containing the SDK:"
    	read IPHONE_SDK_DMG
    	if [ ! -r $IPHONE_SDK_DMG ] ; then
    		error "Sorry, I can't find the file!"
    		error "You will need to download the SDK before you can build the toolchain. The"
    		error "required file can be obtained from: http://developer.apple.com/iphone/"
    		exit 1
    	fi
    fi

    if [ ! -r $IPHONE_SDK_IMG ] ; then
    	message_status "Converting `basename $IPHONE_SDK_DMG` to img format..."
        $DMG extract $IPHONE_SDK_DMG $IPHONE_SDK_IMG
        if [ ! -s $IPHONE_SDK_IMG ]; then
        	error "Failed to extract `basename $IPHONE_SDK_DMG`!"
        	rm $IPHONE_SDK_IMG
        	exit 1
        fi
    fi
}

cleanup_tmp() {
    pushd $TMP_DIR
    rm -fR *
    popd
}

extract_headers() {
    [ ! -d ${MNT_DIR} ] && mkdir ${MNT_DIR}
    [ ! -d ${SDKS_DIR} ] && mkdir ${SDKS_DIR}
    
    # Make sure we don't already have these
    if [ -d "${SDKS_DIR}/iPhoneOS${TOOLCHAIN_VERSION}.sdk" ] && [ -d "${SDKS_DIR}/MacOSX10.5.sdk" ]; then
    	echo "SDKs seem to already be extracted."
    	return
    fi

    # Inform the user why we suddenly need their password
    message_status "Trying to mount the iPhone SDK img..."
    echo "In order to extract `basename $IPHONE_SDK_IMG`, I am going to run:"
    echo -e "\tsudo mount -o loop $IPHONE_SDK_IMG $MNT_DIR"
    
    if ! sudo mount -o loop $IPHONE_SDK_IMG $MNT_DIR ; then
    	error "Failed to mount ${IPHONE_SDK_IMG} at ${MNT_DIR}!"
    	exit 1
    fi
    message_status "Extracting `basename $IPHONE_PKG`..."

    cleanup_tmp

    cp $IPHONE_PKG $TMP_DIR/iphone.pkg
    cd $TMP_DIR
    xar -xf iphone.pkg Payload
    mv Payload Payload.gz
    gunzip Payload.gz
    cat Payload | cpio -i -d 
    mv Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${TOOLCHAIN_VERSION}.sdk ${SDKS_DIR}

    cleanup_tmp

    message_status "Extracting `basename $MACOSX_PKG`..."

    cp $MACOSX_PKG $TMP_DIR/macosx.pkg
    cd $TMP_DIR 
    xar -xf macosx.pkg Payload
    mv Payload Payload.gz
    gunzip Payload.gz
    cat Payload | cpio -i -d 
    mv SDKs/MacOSX10.5.sdk ${SDKS_DIR}

    cleanup_tmp

    message_status "Unmounting iPhone SDK img..."
    sudo umount $MNT_DIR
    message_status "Removing `basename $IPHONE_SDK_IMG`..."
    rm $IPHONE_SDK_IMG
}

# If we can't find the firmware file we try to download it from the
# apple download urls above.
extract_firmware() {
    if [ ! -r "$FW_FILE" ] ; then
    	echo "I can't find the firmware image for iPhone/iPod Touch $TOOLCHAIN_VERSION (`basename $FW_FILE`)."
    	read -p "Do you have it (y/N)?"
    	if [ "$REPLY" != "y" ] && [ "$REPLY" != "yes" ]; then 
	    	read -p "Do you want me to download it (Y/n)?"
	    	if [ "$REPLY" != "n" ] && [ "$REPLY" != "no" ]; then
			message_status "Trying to download the firmware from apple"
			for dl in ${!FW_DOWNLOAD_*} ; do
			    url="${!dl}"
			    if [ ! "${url/$FIRMWARE//}" = "$url" ] ; then
				APPLE_DL_URL=$url;
			    fi
			done
			if [ ! $APPLE_DL_URL ] ; then
			    error "Can't find a download url for requested firmware $FIRMWARE."
			    error "Please check again. Your file should be found in $FW_DIR."
			    error "You may have to download it manually.".
			    exit 1;
			else 
			    message_status "Downloading from: $APPLE_DL_URL"
			    cd $TMP_DIR
			    wget ${APPLE_DL_URL}
			    mv $FIRMWARE $FW_DIR
			fi
		else
			error "I need the firmware image to build the toolchain."
			exit 1
		fi
	else
		while [ ! -a $FW_FILE ] && [ -z $FW_FILE ]; do
			read -p "Location of firmware image: " FW_FILE
			[ ! -a $FW_FILE ] && error "File not found."
		done
		
		if [ ! -a $FW_FILE ]; then
			error "I need the firmware image to build the toolchain."
			exit 1
		fi
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
    
    message_status "Unzipping $FW_RESTORE_SYSTEMDISK..."
    unzip -d "${TMP_DIR}" -o "${FW_FILE}" "${FW_RESTORE_SYSTEMDISK}"

    if [ ! "$DECRYPTION_KEY_SYSTEM" ] ; then
        message_status "We need the DECRYPTION_KEY for $FW_RESTORE_SYSTEMDISK."
        message_status "I'm going to try to fetch it from $IPHONEWIKI_KEY_URL...."
        DECRYPTION_KEY_SYSTEM=$( wget --quiet -O - $IPHONEWIKI_KEY_URL | awk --re-interval \
             "BEGIN { IGNORECASE=1; } \
            /name=\"$FW_PRODUCT_VERSION.*$FW_BUILD_VERSION/ { found = 1; next; } \
            /([a-fA-F0-9]){72}/ && found == 1 \
            { split(\$0,result,\"<p>\"); print toupper(result[2]); exit;  }" )
        if [ ! "$DECRYPTION_KEY_SYSTEM" ] ; then
            error "Sorry, no decryption key for system partition found!"
            exit 1;
        fi
        message_status "I found it!"
    fi

    message_status "Starting vfdecrypt with decryption key $DECRYPTION_KEY_SYSTEM..."
    cd "${TMP_DIR}"
    $( $VFDECRYPT -i"${FW_RESTORE_SYSTEMDISK}" \
                   -o"${FW_RESTORE_SYSTEMDISK}.decrypted"\
                   -k"$DECRYPTION_KEY_SYSTEM" )

    if [ ! -s "${FW_RESTORE_SYSTEMDISK}.decrypted" ]; then
    	error "Decryption of `basename $FW_RESTORE_SYSTEMDISK` failed!"
    	exit 1
    fi
    
    message_status "`basename $FW_RESTORE_SYSTEMDISK` decrypted!"

    FW_VERSION_DIR="${FW_DIR}/${FW_PRODUCT_VERSION}_${FW_BUILD_VERSION}"
    FW_SYSTEM_DIR="${FW_VERSION_DIR}"
    FW_SYSTEM_DMG="${TMP_DIR}/root_system.dmg"

    [ ! -d $FW_VERSION_DIR ] && mkdir "${FW_VERSION_DIR}"
    [ ! -d $FW_SYSTEM_DIR  ] && mkdir "${FW_SYSTEM_DIR}"

    if [ ! -r ${FW_SYSTEM_DMG} ] ; then
    	message_status "Extracting decrypted dmg..."
        $DMG extract "${FW_RESTORE_SYSTEMDISK}.decrypted" ${FW_SYSTEM_DMG}
    fi

    message_status "Trying to mount `basename ${FW_SYSTEM_DMG}`..."
    sudo mount -t hfsplus -o loop "${FW_SYSTEM_DMG}" "${MNT_DIR}"
    cd "${MNT_DIR}"
    message_status "Copying required components of the firmware..."m
    sudo cp -Ra * "${FW_SYSTEM_DIR}"
    sudo chown -R `id --user`:`id --group` $FW_SYSTEM_DIR
    cd ${HERE}
    sudo umount "${MNT_DIR}"
    
    if [ -s "${FW_DIR}/${CURRENT_SYSTEM_DIR}" ] ; then
        rm "${FW_DIR}/${CURRENT_SYSTEM_DIR}";
    fi

    # we want something like this:
    # .../files/fw/current -> .../files/fw/2.0_5A347
    ln -s "${FW_SYSTEM_DIR}" "${FW_DIR}/${CURRENT_SYSTEM_DIR}"
    
    # Remove spurious files
    rm "${TMP_DIR}/$FW_RESTORE_SYSTEMDISK" "${TMP_DIR}/${FW_RESTORE_SYSTEMDISK}.decrypted" \
    	$FW_SYSTEM_DMG "${TMP_DIR}/Restore.plist"
}

toolchain_download_darwin_sources() {
	# Set up the environment
	cd $DARWIN_SOURCES_FILES_DIR

	message_status "Trying to log you in to the Darwin sources repository..."
	# Extract an auto-generated session key to make nice with Apple's login script
	echo -n "Getting session key..."
	LOGIN_URL=$(wget --no-check-certificate --quiet -O - $AID_LOGIN | awk '{
		if(match($0,/\/cgi-bin\/WebObjects\/DSAuthWeb\.woa\/[0-9]+\/wo\/[a-zA-Z0-9]*?\/[^"]*/))
			print substr($0, RSTART, RLENGTH);
	}')

	if [ "$LOGIN_URL" == "" ]; then
		error "Oh dear, I can't seem to log you in! There was a problem"
		error "retrieving the login form session ID. Apple probably"
		error "changed something on their site."
		error "Installation of iPhone Toolchain 2.2 cannot proceed."
		exit 1
	fi

	# Attempt to login
	echo -e "Got the session key."
	echo -ne "Logging in..."
	LOGIN_ERROR=$(wget --quiet --save-cookies=cookies.tmp --keep-session-cookies \
			--post-data="theAccountName=${APPLE_ID}&theAccountPW=${APPLE_PASSWORD}&1.Continue.x=1&1.Continue.y=1&theAuxValue=" \
			--no-check-certificate -O - "https://daw.apple.com${LOGIN_URL}" | awk '{
		if(match($0, /<FONT COLOR="#ff0000" SIZE=1>([^>]*)<\/FONT>/)) {
			$0=substr($0, RSTART, RLENGTH);
			sub(/<FONT COLOR="#ff0000" SIZE=1>/, "", $0);
			sub(/<\/FONT>/, "", $0);
			print $0
		}
	}')

	if [ "$LOGIN_ERROR" != "" ]; then
		error "Error!"
		error "Oh dear, I can't seem to log you in! Apple's login server told me:"
		error "\"${LOGIN_ERROR}\""
		error "Installation of iPhone Toolchain 2.2 cannot proceed."
		exit
	fi

	echo "Login successful."

	# Get what we're here for
	message_status "Attempting to download tool sources..."
	wget --no-clobber --keep-session-cookies --load-cookies=cookies.tmp --input-file=${HERE}/darwin-tools.list
	message_status "Finished downloading!"

	rm cookies.tmp
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
# Modified fairly heavily by m4dm4n for SDK 2.2, fixing some missing
# hadlinks and incorrect patches
toolchain_build() {

    [ ! -d "$TOOLCHAIN" ] && mkdir -p "${TOOLCHAIN}"
    [ ! -d "$prefix"    ] && mkdir -p "${prefix}"
    [ ! -d "$sysroot"   ] && mkdir -p "${sysroot}"
    [ ! -d "$cctools"   ] && mkdir -p "${cctools}"
    [ ! -d "$csu"       ] && mkdir -p "${csu}"
    [ ! -d "$build"     ] && mkdir -p "${build}"

    cd "${apple}"
    message_status "Finding and extracting archives..."
    find ./* -name '*.tar.gz' -exec tar --overwrite -xzof {} \;
    
    # Permissions are being extracted along with the gzipped files. I can't seem to get
    # tar to ignore this, and they are constantly in the way so I'll use this hack.
    chmod -R 755 *

    mkdir -p "$(dirname "${sysroot}")"
    cd "${sysroot}"

    if [ ! -d $iphonefs ] ; then
        error "I couldn't find an iPhone filesystem at: $iphonefs"
        exit 1
    fi

    if [ -d $sysroot ] && [[ `ls -A $sysroot | wc -w` > 0 ]]; then
	    echo "It looks like the iPhone filesystem has already been copied."
	    read -p "Copy again (y/N)? "
	    if [ "${REPLY}" == "y" ]; then
	    	message_status "Copying required iPhone filesystem components..."
	    	# I have tried to avoid copying the permissions (not using -a) because they
	    	# get in the way later down the track. This might be wrong but it seems okay.
	    	cp -rdH $iphonefs/* "${sysroot}"
	    	rm -rf usr/include
	    fi
    else
    	message_status "Copying required iPhone filesystem components..."
    	cp -rdH $iphonefs/* "${sysroot}" # As above
    	rm -rf usr/include
    fi

    # Presently working here and below
    message_status "Copying SDK headers..."
    echo "Leopard"
    cp -a "${leopardinc}" usr/include
    cd usr/include
    ln -s . System

    cp -af "${iphoneinc}"/* .
    cp -af "${apple}"/xnu-*/osfmk/* "${apple}"/xnu-*/bsd/* .

    echo "mach"
    cp -af "${apple}"/cctools-*/include/mach .
    cp -af "${apple}"/cctools-*/include/mach-o .
    cp -af "${iphoneinc}"/mach-o/dyld.h mach-o

    cp -af "${leopardinc}"/mach/machine mach
    cp -af "${leopardinc}"/mach/machine.h mach
    cp -af "${leopardinc}"/machine .
    cp -af "${iphoneinc}"/machine .

    cp -af "${iphoneinc}"/sys/cdefs.h sys
    cp -af "${leopardinc}"/sys/dtrace.h sys

    cp -af "${leopardlib}"/Kernel.framework/Versions/A/Headers/machine/disklabel.h machine
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

    mkdir -p Kernel
    echo "libsa"
    cp -a "${apple}"/xnu-*/libsa/libsa Kernel

    mkdir -p Security
    echo "libsecurity"
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

    mkdir -p DiskArbitration
    echo "DiskArbitration"
    cp -a "${apple}"/DiskArbitration-*/DiskArbitration/*.h DiskArbitration

    echo "iokit"
    cp -a "${apple}"/xnu-*/iokit/IOKit .
    cp -a "${apple}"/IOKitUser-*/*.h IOKit

    cp -a "${apple}"/IOGraphics-*/IOGraphicsFamily/IOKit/graphics IOKit
    cp -a "${apple}"/IOHIDFamily-*/IOHIDSystem/IOKit/hidsystem IOKit

    for proj in kext ps pwr_mgt; do
        mkdir -p IOKit/"${proj}"
        cp -a "${apple}"/IOKitUser-*/"${proj}".subproj/*.h IOKit/"${proj}"
    done

    mkdir -p IOKit/storage
    cp -a "${apple}"/IOStorageFamily-*/*.h IOKit/storage
    cp -a "${apple}"/IOCDStorageFamily-*/*.h IOKit/storage
    cp -a "${apple}"/IODVDStorageFamily-*/*.h IOKit/storage

    mkdir -p SystemConfiguration
    echo "configd"
    cp -a "${apple}"/configd-*/SystemConfiguration.fproj/*.h SystemConfiguration

    mkdir -p WebCore
    echo "WebCore"
    cp -a  "${apple}"/WebCore*/bindings/objc/*.h WebCore

    echo "CoreFoundation"
    mkdir -p CoreFoundation
    cp -a "${leopardlib}"/CoreFoundation.framework/Versions/A/Headers/* CoreFoundation
    cp -af "${apple}"/CF-*/*.h CoreFoundation
    cp -af "${iphonelib}"/CoreFoundation.framework/Headers/* CoreFoundation

    for framework in AudioToolbox AudioUnit CoreAudio QuartzCore Foundation; do
    	echo $framework
    	mkdir -p $framework
        cp -a "${leopardlib}"/"${framework}".framework/Versions/Current/Headers/* "${framework}"
        cp -af "${iphonelib}"/"${framework}".framework/Headers/* "${framework}"
    done

    # UIKit fix (these are only the public framework headers)
    mkdir -p UIKit
    cp -a "${iphonelib}"/UIKit.framework/Headers/* UIKit 

    for framework in AppKit Cocoa CoreData CoreVideo JavaScriptCore OpenGL WebKit; do
    	echo $framework
    	mkdir -p $framework
    	cp -a "${leopardlib}"/"${framework}".framework/Versions/Current/Headers/* $framework
    done

    echo "Application Services"
    mkdir -p ApplicationServices
    cp -a "${leopardlib}"/ApplicationServices.framework/Versions/A/Headers/* ApplicationServices
    for service in "${leopardlib}"/ApplicationServices.framework/Versions/A/Frameworks/*.framework; do
    	echo -e "\t$(basename $service .framework)"
    	mkdir -p "$(basename $service .framework)"
        cp -a $service/Versions/A/Headers/* "$(basename $service .framework)"
    done

    echo "Core Services"
    mkdir -p CoreServices
    cp -a "${leopardlib}"/CoreServices.framework/Versions/A/Headers/* CoreServices
    for service in "${leopardlib}"/CoreServices.framework/Versions/A/Frameworks/*.framework; do
    	mkdir -p "$(basename $service .framework)"
        cp -a $service/Versions/A/Headers/* "$(basename $service .framework)"
    done
    
    message_status "Applying patches..."

    if [ ! -a "${HERE}/include.diff" ]; then
    	error "Missing include.diff! This file is required to merge the OSX and iPhone SDKs."
    	exit 1
    fi

    # this step may have a bad hunk in CoreFoundation and thread_status while patching
    # these errors are to be ignored, as these are changes for issues Apple has now fixed
    # include.diff is a modified version of saurik's patch to support iPhone 2.2 SDK.
    patch -p3 -N < "${HERE}/include.diff"
    wget -qO arm/locks.h http://svn.telesphoreo.org/trunk/tool/patches/locks.h

    mkdir -p GraphicsServices
    cd GraphicsServices
    wget -q http://svn.telesphoreo.org/trunk/tool/patches/GraphicsServices.h

    cd "${sysroot}"
    ln -sf gcc/darwin/4.0/stdint.h usr/include
    ln -s libstdc++.6.dylib usr/lib/libstdc++.dylib

    # Changed some of the below commands from sudo; don't know why they were like that
    message_status "Checking out iphone-dev repo..."
    mkdir -p "${csu}"
    cd "${csu}"
    svn co http://iphone-dev.googlecode.com/svn/trunk/csu .
    cp -a *.o "${sysroot}"/usr/lib
    cd "${sysroot}"/usr/lib
    chmod 644 *.o
    cp -af crt1.o crt1.10.5.o
    cp -af dylib1.o dylib1.10.5.o

    if [ ! -d $gcc ]; then
    	message_status "Checking out saurik's llvm-gcc-4.2..."
    	rm -rf "${gcc}"
    	git clone git://git.saurik.com/llvm-gcc-4.2 "${gcc}"
    else
    	message_status "Updating llvm-gcc-4.2..."
    	pushd $gcc && git pull git://git.saurik.com/llvm-gcc-4.2 master && popd
    fi
    
    message_status "Checking out odcctools..."
    svn co http://iphone-dev.googlecode.com/svn/branches/odcctools-9.2-ld "${cctools}"

    message_status "Building cctools-iphone..."
    echo "Build progress logged to: toolchain/bld/cctools-iphone/make.log"
    mkdir -p "${build}/cctools-iphone"
    cd "${build}/cctools-iphone"
    CFLAGS=-m32 LDFLAGS=-m32 "${cctools}"/configure \
        --target="${target}" \
        --prefix="${prefix}" \
        --disable-ld64
    make clean
    if ! ( make &>make.log && make install &>install.log ); then
    	error "Build & install failed. Check make.log and install.log"
    fi

    message_status "Building gcc-4.2-iphone..."
    echo "Build progress logged to: toolchain/bld/gcc-4.2-iphone/make.log"
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
    make clean
    if ! ( make -j2 &>make.log && make install &>install.log ); then
    	error "Build & install failed. Check make.log and install.log"
    fi

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
    export iphonesdk="${SDKS_DIR}/iPhoneOS${TOOLCHAIN_VERSION}.sdk"
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

message_action "Preparing the environment"
toolchain_env
check_commands
check_packages
check_dirs
build_tools
cleanup_tmp
message_status "Environment is ready"

APPLE_ID=""
APPLE_PASSWORD=""

while test $# -gt 0 ; do
    case $1 in
        extractheaders | getheaders | headers)
            shift
            message_action "Getting the header files"
            toolchain_extract_headers
            ;;
        darwin_sources)
            shift
            getopt_simple $1
            shift
            getopt_simple $1
            shift
            
            # Make sure we have the Apple ID and password
            if [ "$APPLE_ID" == "" ] || [ "$APPLE_PASSWORD" == "" ]; then
    		echo "You're going to need an Apple Developer Connection ID and password."
    		read -p "Apple ID: " APPLE_ID
    		read -p "Password: " PASSWORD
    	    fi
    	    
            if [ "$APPLE_ID" != "" ] && [ "$APPLE_PASSWORD" != "" ]; then
            	message_action "Downloading Darwin sources"
            	echo "Apple ID: $APPLE_ID"
            	echo "Password: $APPLE_PASSWORD"
            	toolchain_download_darwin_sources
            else
            	error "You must provide a valid Apple ID and password combination in order "
            	error "to automatically download the required Darwin sources."
            fi
            
            ;;
        firmware | system | rootfs)
            shift
            message_action "Extracting firmware files"
            toolchain_system_files
            ;;
        build )
            shift
            message_action "Building the toolchain"
            toolchain_build
            ;;
       *)
       break ;;
  esac
done

#if [[ $ERROR_COUNT > 0 ]]; then
#	echo -e "\n\n"
#	cecho bold red "Warning: $ERROR_COUNT errors encountered during operation."
#	cecho bold red "Check output for error messages. Operation did not complete successfully."
#fi

message_action "Done!"
