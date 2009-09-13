#!/bin/bash

# Copyright (c) 2008,2009 iphonedevlinux <iphonedevlinux@googlemail.com>
# Copyright (c) 2008, 2009 m4dm4n <m4dm4n@gmail.com>
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
TOOLCHAIN_VERSION="3.0"


# Everything is built relative to IPHONEDEV_DIR
IPHONEDEV_DIR="`pwd`"

# Usage
# ======================
#
# Run these commands in order:
# 	./toolchain.sh headers
# 	./toolchain.sh firmware
# 	./toolchain.sh darwin_sources
# 	./toolchain.sh build
#	./toolchain.sh classdump (optional)
#	./toolchain.sh clean
#	OR simply run:
#	./toolchain.sh all
#
#
# Actions
# ======================
#
# ./toolchain.sh all
#   Perform all stages in the order defined below. See each individual
#   stage for details.
#
# ./toolchain.sh headers
#   Extract OSX and iPhone SDK headers from the iPhone SDK image. You
#   will need to have the image available to provide to the script. This
#   is not downloaded automatically. Results extracted to
#   $IPHONEDEV_DIR/SDKs/iPhoneOS2.{version}.sdk and
#   $IPHONEDEV_DIR/SDKs/MacOSX10.5.sdk
#
# ./toolchain.sh firmware
#   Extract iPhone or iPod touch firmware located in
#   $IPHONEDEV_DIR/files/firmware/ or downloads firmware appropriate to the
#   toolchain version automatically using firmware.list. Now searches for
#   decryptions-keys and tries to extract the root-filesystem of the
#   firmware to ./files/fw/{FirmwareVersion}/system. The symlink
#   ./files/fw/current is automatically set to the extracted system.
#
# ./toolchain.sh darwin_sources
#   You will need to register at developer.apple.com or have a valid account.
#   You may specify APPLE_ID and APPLE_PASSWORD environment variables to avoid
#   prompting.
#
# ./toolchain.sh build
#   Starts the build process decribed by saurik in
#   http://www.saurik.com/id/4. This script uses the same paths under
#   $IPHONEDEV_DIR/toolchain/
#
# ./toolchain.sh classdump
#   Runs classdump on a selected iPhone over SSH in order to generate useable
#   Objective-C headers for (mostly) private frameworks.

FILES_DIR="${IPHONEDEV_DIR}/files"
SDKS_DIR="${IPHONEDEV_DIR}/sdks"
TOOLS_DIR="${IPHONEDEV_DIR}/tools"
MIG_DIR="${TOOLS_DIR}/mig"
TMP_DIR="${IPHONEDEV_DIR}/tmp"
MNT_DIR="${FILES_DIR}/mnt"
FW_DIR="${FILES_DIR}/firmware"

IPHONE_SDK="iphone_sdk_*_final.dmg"
[ -z $IPHONE_SDK_DMG ] && IPHONE_SDK_DMG="${FILES_DIR}/${IPHONE_SDK}"

# URLS
DMG2IMG="http://vu1tur.eu.org/tools/download.pl?dmg2img-1.6.1.tar.gz"
IPHONEWIKI_KEY_URL="http://www.theiphonewiki.com/wiki/index.php?title=VFDecrypt_Keys:_3.x"
AID_LOGIN="https://daw.apple.com/cgi-bin/WebObjects/DSAuthWeb.woa/wa/login?appIdKey=D236F0C410E985A7BB866A960326865E7F924EB042FA9A161F6A628F0291F620&path=/darwinsource/tarballs/apsl/cctools-667.8.0.tar.gz"
DARWIN_SOURCES_DIR="$FILES_DIR/darwin_sources"

NEEDED_COMMANDS="git gcc make sudo mount xar cpio zcat tar wget unzip gawk bison flex"

HERE=`pwd`

# Compare two version strings and return a string indicating whether the first version number
# is newer, older or equal to the second. This is quite dumb, but it works.
vercmp() {
	V1=`echo "$1" | sed -e 's/[^0-9]//g' | LANG=C awk '{ printf "%0.10f", "0."$0 }'`
	V2=`echo "$2" | sed -e 's/[^0-9]//g' | LANG=C awk '{ printf "%0.10f", "0."$0 }'`
	[[ $V1 > $V2 ]] && echo "newer"
	[[ $V1 == $V2 ]] && echo "equal"
	[[ $V1 < $V2 ]] && echo "older"
}

# Beautified echo commands
cecho() {
	while [[ $# > 1 ]]; do
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

# Shorthand method of asking a yes or no question with a default answer
confirm() {
	local YES="Y"
	local NO="n"
	if [ "$1" == "-N" ]; then
		NO="N"
		YES="y"
		shift
	fi
	read -p "$* [${YES}/${NO}] "
	if [ "$REPLY" == "no" ] || [ "$REPLY" == "n" ] || ([ "$NO" == "N" ] && [ -z "$REPLY" ] ); then
		return 1
	fi
	if [ "$REPLY" == "yes" ] || [ "$REPLY" == "y" ] || ([ "$YES" == "Y" ] && [ -z "$REPLY" ] ); then
		return 0
	fi
}

error() {
	cecho red $*
}

message_status() {
	cecho green $*
}

message_action() {
	cecho blue $*
}

# Platform independent mount command for the DMGs used in this script
mount_dmg() {
	# Key provided, we need to decrypt the DMG first
	if [ ! -z $3 ]; then
		message_status "Decrypting `basename $1`..."
		TMP_DECRYPTED=${TMP_DIR}/`basename $1`.decrypted
		if ! ${TOOLS_DIR}/vfdecrypt -i $1 -o $TMP_DECRYPTED -k $3 &> /dev/null; then
			error "Failed to decrypt `basename $1`!"
			exit 1
		fi
		local DMG="${TMP_DECRYPTED}"
	else
		local DMG="$1"
	fi
	if [ "`uname -s`" == "Darwin" ]; then
		echo "In order to extract `basename $1`, I am going to mount it."
		echo "This needs to be done as root."
		sudo hdiutil attach -mountpoint $2 $DMG
	else
		# Convert the DMG to an IMG for mounting
		TMP_IMG=${TMP_DIR}/`basename $DMG .dmg`.img
		${TOOLS_DIR}/dmg2img -v -i $DMG -o $TMP_IMG
		echo "In order to extract `basename $1`, I am going to mount it."
		echo "This needs to be done as root."
		# This is needed for 3.0 sdk and dmg2img 1.6.1
		sudo mount -t hfsplus  -o loop,offset=36864 $TMP_IMG $2
	fi
	if [ ! $? == 0 ]; then
		error "Failed to mount `basename $1`."
		exit 1
	fi
}

# Platform independent umount command for the DMGs used in this script
umount_dmg() {
	if [ "`uname -s`" == "Darwin" ]; then
		sudo hdiutil detach $MNT_DIR
	else
		# shouldn't we have a DEBUG var and only
		# delete the TMP_IMG if DEBUG is not set/true
		sudo umount -fl $MNT_DIR
	fi
	if [ ! $? == 0 ]; then
		error "Failed to unmount."
		exit 1
	fi
	[ -r $TMP_IMG ] && rm -f $TMP_IMG

}

# Takes a plist string and does a very basic lookup of a particular key value,
# given a key name and an XPath style path to the key in terms of dict entries
plist_key() {
	local PLIST_PATH="$2"
	local PLIST_KEY="$1"
	local PLIST_DATA="$3"

	cat "${PLIST_DATA}" | awk '
		/<key>.*<\/key>/ { sub(/^.*<key>/, "", $0); sub(/<\/key>.*$/, "", $0); lastKey = $0; }
		/<dict>/ { path = path lastKey "/"; }
		/<\/dict>/ { sub(/[a-zA-Z0-9]*\/$/, "", path);}
		/<((string)|(integer))>.*<\/((string)|(integer))>/ {
			if(lastKey == "'"${PLIST_KEY}"'" && path == "'"${PLIST_PATH}"'") {
				sub(/^.*<((string)|(integer))>/,"", $0);
				sub(/<\/((string)|(integer))>.*$/,"", $0);
				print $0;
			}
		}'
}

# Builds dmg2img decryption tools and vfdecrypt, which we will use later to convert dmgs to
# images, so that we can mount them.
build_tools() {
	([ -x ${TOOLS_DIR}/dmg2img ] && [ -x ${TOOLS_DIR}/vfdecrypt ]) && return

	mkdir -p $TOOLS_DIR
	mkdir -p $TMP_DIR

	message_status "Retrieving and building dmg2img 1.6.1 ..."

	cd $TMP_DIR
	if ! wget -O - $DMG2IMG | tar -zx; then
		error "Failed to get and extract dmg2img-1.6.1 Check errors."
		exit 1
	fi

	pushd dmg2img-1.6.1

	if ! make; then
		error "Failed to make dmg2img-1.6.1"
		error "Make sure you have libbz2 and libssl available on your system."
		exit 1
	fi

	mv vfdecrypt dmg2img $TOOLS_DIR
	popd
	rm -Rf dmg2img-1.6.1

	message_status "dmg2img is ready!"
}

toolchain_extract_headers() {
	build_tools
	mkdir -p ${MNT_DIR} ${SDKS_DIR} ${TMP_DIR}

	# Make sure we don't already have these
	if [ -d "${SDKS_DIR}/iPhoneOS${TOOLCHAIN_VERSION}.sdk" ] && [ -d "${SDKS_DIR}/MacOSX10.5.sdk" ]; then
		echo "SDKs seem to already be extracted."
		return
	fi

	# Look for the DMG and ask the user if is isn't findable.
	if ! [ -r $IPHONE_SDK_DMG ] ; then
		echo "I'm having trouble finding the iPhone SDK. I looked here:"
		echo $IPHONE_SDK_DMG
		if ! confirm "Do you have the SDK?"; then
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

	# Inform the user why we suddenly need their password
	message_status "Trying to mount the iPhone SDK dmg..."
	mount_dmg $IPHONE_SDK_DMG $MNT_DIR

	# Check the version of the SDK
	# Apple seems to apply a policy of rounding off the last component of the long version number
	# so we'll do the same here
	SDK_VERSION=$(plist_key CFBundleShortVersionString "/" "${MNT_DIR}/iPhone SDK.mpkg/Contents/version.plist" | awk '
		BEGIN { FS="." }
		{
			if(substr($4,1,1) >= 5)
				$3++
			if($3 > 0)	printf "%s.%s.%s", $1, $2, $3
			else		printf "%s.%s", $1, $2
		}')
	echo "SDK is version ${SDK_VERSION}"

	if [ "`vercmp $SDK_VERSION $TOOLCHAIN_VERSION`" == "older" ]; then
		error "We are trying to build toolchain ${TOOLCHAIN_VERSION} but this"
		error "SDK is ${SDK_VERSION}. Please download the latest SDK here:"
		error "http://developer.apple.com/iphone/"
		echo "Unmounting..."
		umount_dmg
		exit 1
	fi

	# Check which PACKAGE we have to extract. Apple does have different
	# namings for it, depending on the SDK version. 
	if [ "${TOOLCHAIN_VERSION}" == "3.0" ] ; then
		PACKAGE="iPhoneSDKHeadersAndLibs.pkg"
	elif [[ "`vercmp $SDK_VERSION $TOOLCHAIN_VERSION`" == "newer" ]]; then
		PACKAGE="iPhoneSDK`echo $TOOLCHAIN_VERSION | sed 's/\./_/g' `.pkg"
	else
		PACKAGE="iPhoneSDKHeadersAndLibs.pkg"
	fi

	if [ ! -r ${MNT_DIR}/Packages/$PACKAGE ]; then
		error "I tried to extract $PACKAGE but I couldn't find it!"
		echo "Unmounting..."
		umount_dmg
		exit 1
	fi

	message_status "Extracting `basename $PACKAGE`..."

	rm -fR $TMP_DIR/*

	cp ${MNT_DIR}/Packages/$PACKAGE $TMP_DIR/iphone.pkg
	cd $TMP_DIR
	xar -xf iphone.pkg Payload
	# zcat on OSX needs .Z suffix
	cat Payload | zcat | cpio -id

	# These folders are version named so the SDK version can be verified
	if [ ! -d Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${TOOLCHAIN_VERSION}.sdk ]; then
		error "I couldn't find the folder iPhoneOS${TOOLCHAIN_VERSION}.sdk. Perhaps this is"
		error "not the right SDK dmg for toolchain ${TOOLCHAIN_VERSION}."
		exit 1
	fi

	mv -f Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS${TOOLCHAIN_VERSION}.sdk ${SDKS_DIR}

	rm -fR $TMP_DIR/*

	message_status "Extracting MacOSX10.5.pkg..."

	cp ${MNT_DIR}/Packages/MacOSX10.5.pkg $TMP_DIR/macosx.pkg
	cd $TMP_DIR 
	xar -xf macosx.pkg Payload
	cat Payload | zcat | cpio -id
	mv -f SDKs/MacOSX10.5.sdk ${SDKS_DIR}

	rm -fR $TMP_DIR/*

	message_status "Unmounting iPhone SDK img..."
	cd $HERE
	umount_dmg
}

toolchain_extract_firmware() {
	build_tools
	mkdir -p $FW_DIR $MNT_DIR $TMP_DIR

	if [ -z "$FW_FILE" ]; then
		FW_FILE=`ls ${FW_DIR}/*${TOOLCHAIN_VERSION}*.ipsw 2>/dev/null`
		if [ ! $? ] && [[ `echo ${FW_FILE} | wc -w` > 1 ]]; then
			error "I attempted to search for the correct firmware version, but"
			error "it looks like you have several ipsw files. Please specify"
			error "one like so:"
			echo -e "\texport FW_FILE=/path/to/firmware/"
			echo -e "\t./toolchain.sh firmware"
			exit 1
		fi
	fi

	# If we can't find the firmware file we try to download it from the
	# apple download urls above.
	if [ ! -r "$FW_FILE" ] ; then
		echo "I can't find the firmware image for iPhone/iPod Touch $TOOLCHAIN_VERSION."
		if ! confirm -N "Do you have it?"; then
			if confirm "Do you want me to download it?"; then
				APPLE_DL_URL=$(cat ${HERE}/firmware.list | awk '$1 ~ /'"^${TOOLCHAIN_VERSION}$"'/ && $2 ~ /^iPhone\(3G\)$/ { print $3; }')
				FW_FILE=`basename "${APPLE_DL_URL}"`
				if [ ! $APPLE_DL_URL ] ; then
					error "Can't find a download url for the toolchain version and platform specified."
					error "You may have to download it manually.".
					exit 1
				else 
					message_status "Downloading: $FW_FILE"
					cd $TMP_DIR
					wget -nc -c $APPLE_DL_URL
					mv $FW_FILE $FW_DIR
					FW_FILE=$FW_DIR/$FW_FILE
				fi
			fi
		else
			while [ ! -r "$FW_FILE" ]; do
				read -p "Location of firmware image: " FW_FILE
				[ ! -a $FW_FILE ] && error "File not found."
			done
		fi
	fi

	cd "$FW_DIR"

	# Sometimes the firmware download is broken. Had this problem while
	# automatically download the firmware with wget above. Is it a problem
	# of wget or does apple have any checks? Maybe we should use wget
	# with an alternative user agent

	sha1cmd=`which sha1sum`
	if [ "x$sha1cmd" != "x" ] ; then
		ff=`basename ${FW_FILE}`
		should=$(cat ${HERE}/firmware.list | \
			awk '$1 ~ /'"^${TOOLCHAIN_VERSION}$"'/ && $3 ~ /'"${ff}"'/ { print $4; }')
		sha1=$(sha1sum ${FW_FILE} | awk ' { print $1; exit; }')
		if [ "x$should" != "x" -a "x$should" != "x" ] ; then
			if [ "$sha1" == "$should" ] ; then 
				cecho green "Checksum of firmware file is valid."
			else
				cecho red "The calculated checksum of the firmware differs "
				cecho red "from the original one. One day I had a problem "
				cecho red "to download a firmware with wget. The file was "
				cecho red "broken. After trying the same download with "
				cecho red "firefox I got a valid firmware file."
				cecho red "If you encounter some problems while extracting "
				cecho red "the firmware please download the file with another "
				cecho red "user agent"
			fi
		fi
	fi

	unzip -d "${TMP_DIR}" -o "${FW_FILE}" Restore.plist

	# Retrieve information from the firmware image we downloaded so we know
	# which file to decrypt and which key to use to decrypt it
	FW_DEVICE_CLASS=$(plist_key DeviceClass "/" "${TMP_DIR}/Restore.plist")
	FW_PRODUCT_VERSION=$(plist_key ProductVersion "/" "${TMP_DIR}/Restore.plist")
	FW_BUILD_VERSION=$(plist_key ProductBuildVersion "/" "${TMP_DIR}/Restore.plist")
	FW_RESTORE_RAMDISK=$(plist_key User "/RestoreRamDisks/" "${TMP_DIR}/Restore.plist")
	FW_RESTORE_SYSTEMDISK=$(plist_key User "/SystemRestoreImages/" "${TMP_DIR}/Restore.plist")
	FW_VERSION_DIR="${FW_DIR}/${FW_PRODUCT_VERSION}_${FW_BUILD_VERSION}"
	HW_BOARD_CONFIG=$(plist_key BoardConfig "/DeviceMap/" "${TMP_DIR}/Restore.plist")

	cecho bold "Firmware Details"
	echo "Device Class: ${FW_DEVICE_CLASS}"
	echo "Product Version: ${FW_PRODUCT_VERSION}"
	echo "Build Version: ${FW_BUILD_VERSION}"
	echo "Restore RamDisk: ${FW_RESTORE_RAMDISK}"
	echo "Restore Image: ${FW_RESTORE_SYSTEMDISK}"
	echo "Board Config: ${HW_BOARD_CONFIG}"

	if [[ $FW_PRODUCT_VERSION != $TOOLCHAIN_VERSION ]]; then
		error "The firmware image is for ${FW_DEVICE_CLASS} version ${FW_PRODUCT_VERSION}, but we are"
		error "building toolchain version ${TOOLCHAIN_VERSION}. These may be incompatible."
		if ! confirm "Proceed?"; then
			error "Firmware extraction will not proceed."
			exit 1
		fi
	fi

	message_status "Unzipping `basename $FW_RESTORE_SYSTEMDISK`..."
	unzip -d "${TMP_DIR}" -o "${FW_FILE}" "${FW_RESTORE_SYSTEMDISK}"

	if [ -z "$DECRYPTION_KEY_SYSTEM" ] ; then
		echo "We need the decryption key for `basename $FW_RESTORE_SYSTEMDISK`."
		echo "I'm going to try to fetch it from $IPHONEWIKI_KEY_URL...."
 
		DECRYPTION_KEY_SYSTEM=$( wget --quiet -O - $IPHONEWIKI_KEY_URL | awk '\
			BEGIN { IGNORECASE = 1; }
			/name="3.0_.28Build_7A341.29"/               { found_3_0 = 1;   }
			/name="Root_Filesystem"/ && found_3_0        { found_root = 1;  }
			/title="'${HW_BOARD_CONFIG}'"/ && found_root { found_phone = 1; }
			/.*<pre>.*$/ && found_phone { 
				sub(/.*<pre>/,"", $0); 
				print toupper($0); exit; }
		')

		if [ ! "$DECRYPTION_KEY_SYSTEM" ] ; then
			error "Sorry, no decryption key for system partition found!"
			exit 1
		fi
		echo "I found it!"
	fi

	message_status "Mounting ${FW_RESTORE_SYSTEMDISK}..."
	mount_dmg "${TMP_DIR}/${FW_RESTORE_SYSTEMDISK}" "${MNT_DIR}" "${DECRYPTION_KEY_SYSTEM}"

	cd "${MNT_DIR}"
	message_status "Copying required components of the firmware..."

	mkdir -p "${FW_VERSION_DIR}"
	sudo cp -R -p * "${FW_VERSION_DIR}"
	sudo chown -R `id -u`:`id -g` $FW_VERSION_DIR
	message_status "Unmounting..."

	cd "${HERE}"
	umount_dmg

	if [ -s "${FW_DIR}/current" ] ; then
		rm "${FW_DIR}/current"
	fi

	ln -s "${FW_VERSION_DIR}" "${FW_DIR}/current"
	rm "${TMP_DIR}/$FW_RESTORE_SYSTEMDISK" "${TMP_DIR}/${FW_RESTORE_SYSTEMDISK}.decrypted" $FW_SYSTEM_DMG "${TMP_DIR}/Restore.plist"
}

# thanks to no.name.11234 for the tip to download the darwin sources
# from http://www.opensource.apple.com/tarballs
toolchain_download_darwin_sources() {
	mkdir -p $DARWIN_SOURCES_DIR && cd $DARWIN_SOURCES_DIR

	# Get what we're here for
	message_status "Attempting to download tool sources..."
	wget --no-clobber --keep-session-cookies --load-cookies=cookies.tmp --input-file=${HERE}/darwin-tools.list
	message_status "Finished downloading!"
	if [ -f cookies.tmp ] ; then
		rm cookies.tmp
	fi
}

# Follows the build routine for the toolchain described by saurik here:
# www.saurik.com/id/4
toolchain_build() {

	local TOOLCHAIN="${IPHONEDEV_DIR}/toolchain"
	local LEOPARD_SDK="${SDKS_DIR}/MacOSX10.5.sdk"
	local LEOPARD_SDK_INC="${LEOPARD_SDK}/usr/include"
	local LEOPARD_SDK_LIBS="${LEOPARD_SDK}/System/Library/Frameworks"
	local IPHONE_SDK="${SDKS_DIR}/iPhoneOS${TOOLCHAIN_VERSION}.sdk"
	local IPHONE_SDK_INC="${IPHONE_SDK}/usr/include"
	local IPHONE_SDK_LIBS="${IPHONE_SDK}/System/Library/Frameworks"
	local CCTOOLS_DIR="$TOOLCHAIN/src/cctools"
	local GCC_DIR="$TOOLCHAIN/src/gcc"
	local CSU_DIR="$TOOLCHAIN/src/csu"
	export PATH="$TOOLCHAIN/pre/bin":"${PATH}"
	local TARGET="arm-apple-darwin9"
	[ ! "`vercmp $TOOLCHAIN_VERSION 2.0`" == "newer" ] && local TARGET="arm-apple-darwin8"

	mkdir -p "${TOOLCHAIN}"

	cd "${DARWIN_SOURCES_DIR}"
	message_status "Finding and extracting archives..."
	ARCHIVES=$(find ./* -name '*.tar.gz')
	for a in $ARCHIVES; do
		basename $a .tar.gz
		tar --overwrite -xzof $a
	done

	# Permissions are being extracted along with the gzipped files. I can't seem to get
	# tar to ignore this, and they are constantly in the way so I'll use this hack.
	chmod -R 755 *

	mkdir -p "$TOOLCHAIN/sys"
	cd "$TOOLCHAIN/sys"

	if [ ! -d "${FW_DIR}/current" ] ; then
		error "I couldn't find an iPhone filesystem at: ${FW_DIR}/current"
		exit 1
	fi

	if [ -d $TOOLCHAIN/sys ] && [[ `ls -A $TOOLCHAIN/sys | wc -w` > 0 ]]; then
		echo "It looks like the iPhone filesystem has already been copied."
		if ! confirm -N "Copy again?"; then
			message_status "Copying required iPhone filesystem components..."
			# I have tried to avoid copying the permissions (not using -a) because they
			# get in the way later down the track. This might be wrong but it seems okay.
			cp -R -p ${FW_DIR}/current/* "$TOOLCHAIN/sys"
			rm -rf usr/include
		fi
	else
		message_status "Copying required iPhone filesystem components..."
		cp -R -p ${FW_DIR}/current/* "$TOOLCHAIN/sys" # As above
		rm -rf usr/include
	fi

	# Presently working here and below
	message_status "Copying SDK headers..."
	echo "Leopard"
	cp -R -p "${LEOPARD_SDK_INC}" usr/include
	cd usr/include
	ln -sf . System

	cp -R -pf "${IPHONE_SDK_INC}"/* .
	cp -R -pf "${DARWIN_SOURCES_DIR}"/xnu-1228.7.58/osfmk/* .
	cp -R -pf "${DARWIN_SOURCES_DIR}"/xnu-1228.7.58/bsd/* . 

	echo "mach"
	cp -R -pf "${DARWIN_SOURCES_DIR}"/cctools-*/include/mach .
	cp -R -pf "${DARWIN_SOURCES_DIR}"/cctools-*/include/mach-o .
	cp -R -pf "${IPHONE_SDK_INC}"/mach-o/dyld.h mach-o

	cp -R -pf "${LEOPARD_SDK_INC}"/mach/machine mach
	cp -R -pf "${LEOPARD_SDK_INC}"/mach/machine.h mach
	cp -R -pf "${LEOPARD_SDK_INC}"/machine .
	cp -R -pf "${IPHONE_SDK_INC}"/machine .

	cp -R -pf "${IPHONE_SDK_INC}"/sys/cdefs.h sys
	cp -R -pf "${LEOPARD_SDK_INC}"/sys/dtrace.h sys

	cp -R -pf "${LEOPARD_SDK_LIBS}"/Kernel.framework/Versions/A/Headers/machine/disklabel.h machine
	cp -R -pf "${DARWIN_SOURCES_DIR}"/configd-*/dnsinfo/dnsinfo.h .
	cp -R -p "${DARWIN_SOURCES_DIR}"/Libc-*/include/kvm.h .
	cp -R -p "${DARWIN_SOURCES_DIR}"/launchd-*/launchd/src/*.h .

	cp -R -p i386/disklabel.h arm
	cp -R -p mach/i386/machine_types.defs mach/arm

	mkdir -p Kernel
	echo "libsa"
	cp -R -p "${DARWIN_SOURCES_DIR}"/xnu-1228.3.13/libsa/libsa Kernel

	mkdir -p Security
	echo "libsecurity"
	cp -R -p "${DARWIN_SOURCES_DIR}"/libsecurity_authorization-*/lib/*.h Security
	cp -R -p "${DARWIN_SOURCES_DIR}"/libsecurity_cdsa_client-*/lib/*.h Security
	cp -R -p "${DARWIN_SOURCES_DIR}"/libsecurity_cdsa_utilities-*/lib/*.h Security
	cp -R -p "${DARWIN_SOURCES_DIR}"/libsecurity_cms-*/lib/*.h Security
	cp -R -p "${DARWIN_SOURCES_DIR}"/libsecurity_codesigning-*/lib/*.h Security
	cp -R -p "${DARWIN_SOURCES_DIR}"/libsecurity_cssm-*/lib/*.h Security
	cp -R -p "${DARWIN_SOURCES_DIR}"/libsecurity_keychain-*/lib/*.h Security
	cp -R -p "${DARWIN_SOURCES_DIR}"/libsecurity_mds-*/lib/*.h Security
	cp -R -p "${DARWIN_SOURCES_DIR}"/libsecurity_ssl-*/lib/*.h Security
	cp -R -p "${DARWIN_SOURCES_DIR}"/libsecurity_utilities-*/lib/*.h Security
	cp -R -p "${DARWIN_SOURCES_DIR}"/libsecurityd-*/lib/*.h Security

	mkdir -p DiskArbitration
	echo "DiskArbitration"
	cp -R -p "${DARWIN_SOURCES_DIR}"/DiskArbitration-*/DiskArbitration/*.h DiskArbitration

	echo "iokit"
	cp -R -p "${DARWIN_SOURCES_DIR}"/xnu-*/iokit/IOKit .
	cp -R -p "${DARWIN_SOURCES_DIR}"/IOKitUser-*/*.h IOKit

	cp -R -p "${DARWIN_SOURCES_DIR}"/IOGraphics-*/IOGraphicsFamily/IOKit/graphics IOKit
	cp -R -p "${DARWIN_SOURCES_DIR}"/IOHIDFamily-*/IOHIDSystem/IOKit/hidsystem IOKit

	for proj in kext ps pwr_mgt; do
		mkdir -p IOKit/"${proj}"
		cp -R -p "${DARWIN_SOURCES_DIR}"/IOKitUser-*/"${proj}".subproj/*.h IOKit/"${proj}"
	done

	ln -s IOKit/kext/bootfiles.h .

	mkdir -p IOKit/storage
	cp -R -p "${DARWIN_SOURCES_DIR}"/IOStorageFamily-*/*.h IOKit/storage
	cp -R -p "${DARWIN_SOURCES_DIR}"/IOCDStorageFamily-*/*.h IOKit/storage
	cp -R -p "${DARWIN_SOURCES_DIR}"/IODVDStorageFamily-*/*.h IOKit/storage

	mkdir DirectoryService
	cp -R -p "${DARWIN_SOURCES_DIR}"/DirectoryService-*/APIFramework/*.h DirectoryService

	mkdir DirectoryServiceCore
	cp -R -p "${DARWIN_SOURCES_DIR}"/DirectoryService-*/CoreFramework/Private/*.h DirectoryServiceCore
	cp -R -p "${DARWIN_SOURCES_DIR}"/DirectoryService-*/CoreFramework/Public/*.h DirectoryServiceCore 

	mkdir -p SystemConfiguration
	echo "configd"
	cp -R -p "${DARWIN_SOURCES_DIR}"/configd-*/SystemConfiguration.fproj/*.h SystemConfiguration

	echo "CoreFoundation"
	mkdir CoreFoundation
	cp -R -p "${LEOPARD_SDK_LIBS}"/CoreFoundation.framework/Versions/A/Headers/* CoreFoundation
	cp -R -pf "${DARWIN_SOURCES_DIR}"/CF-*/*.h CoreFoundation
	cp -R -pf "${IPHONE_SDK_LIBS}"/CoreFoundation.framework/Headers/* CoreFoundation

	for framework in AudioToolbox AudioUnit CoreAudio QuartzCore Foundation; do
		echo $framework
		mkdir -p $framework
		cp -R -p "${LEOPARD_SDK_LIBS}"/"${framework}".framework/Versions/?/Headers/* "${framework}"
		cp -R -pf "${IPHONE_SDK_LIBS}"/"${framework}".framework/Headers/* "${framework}"
	done

	for framework in UIKit AddressBook CoreLocation OpenGLES; do
		echo $framework
		mkdir -p $framework
		cp -R -pf "${IPHONE_SDK_LIBS}"/"${framework}".framework/Headers/* "${framework}"
	done

	for framework in AppKit Cocoa CoreData CoreVideo JavaScriptCore OpenGL WebKit; do
		echo $framework
		mkdir -p $framework
		cp -R -p "${LEOPARD_SDK_LIBS}"/"${framework}".framework/Versions/?/Headers/* $framework
	done
	
	echo "Application Services"
	mkdir -p ApplicationServices
	cp -R -p "${LEOPARD_SDK_LIBS}"/ApplicationServices.framework/Versions/A/Headers/* ApplicationServices
	for service in "${LEOPARD_SDK_LIBS}"/ApplicationServices.framework/Versions/A/Frameworks/*.framework; do
		echo -e "\t$(basename $service .framework)"
		mkdir -p "$(basename $service .framework)"
		cp -R -p $service/Versions/A/Headers/* "$(basename $service .framework)"
	done

	echo "Core Services"
	mkdir -p CoreServices
	cp -R -p "${LEOPARD_SDK_LIBS}"/CoreServices.framework/Versions/A/Headers/* CoreServices
	for service in "${LEOPARD_SDK_LIBS}"/CoreServices.framework/Versions/A/Frameworks/*.framework; do
		mkdir -p "$(basename $service .framework)"
		cp -R -p $service/Versions/A/Headers/* "$(basename $service .framework)"
	done

	mkdir WebCore
	echo "WebCore"
	cp -R -p "${DARWIN_SOURCES_DIR}"/WebCore-*/bindings/objc/*.h WebCore
	cp -R -p "${DARWIN_SOURCES_DIR}"/WebCore-*/bridge/mac/*.h WebCore 
	for subdir in css dom editing history html loader page platform{,/{graphics,text}} rendering; do
		cp -R -p "${DARWIN_SOURCES_DIR}"/WebCore-*/"${subdir}"/*.h WebCore
	done

	cp -R -p "${DARWIN_SOURCES_DIR}"/WebCore-*/css/CSSPropertyNames.in WebCore
	(cd WebCore; perl "${DARWIN_SOURCES_DIR}"/WebCore-*/css/makeprop.pl)

	mkdir kjs
	cp -R -p "${DARWIN_SOURCES_DIR}"/JavaScriptCore-*/kjs/*.h kjs

	mkdir -p wtf/unicode/icu
	cp -R -p "${DARWIN_SOURCES_DIR}"/JavaScriptCore-*/wtf/*.h wtf
	cp -R -p "${DARWIN_SOURCES_DIR}"/JavaScriptCore-*/wtf/unicode/*.h wtf/unicode
	cp -R -p "${DARWIN_SOURCES_DIR}"/JavaScriptCore-*/wtf/unicode/icu/*.h wtf/unicode/icu

	mkdir unicode
	cp -R -p "${DARWIN_SOURCES_DIR}"/JavaScriptCore-*/icu/unicode/*.h unicode
	
	cd "$TOOLCHAIN/sys"
	ln -sf gcc/darwin/4.0/stdint.h usr/include
	ln -sf libstdc++.6.dylib usr/lib/libstdc++.dylib

	message_status "Applying patches..."

	if [ ! -r "${HERE}/include.diff" ]; then
		error "Missing include.diff! This file is required to merge the OSX and iPhone SDKs."
		exit 1
	fi

	# include.diff is a modified version the telesphoreo patches to support iPhone 3.0
	# Some patches could fail if you rerun (rebuild) ./toolchain.sh build

	#wget -qO- http://svn.telesphoreo.org/trunk/tool/include.diff | patch -p3 
	pushd "usr/include"
	patch -p3 -l -N < "${HERE}/include.diff"

	#wget -qO arm/locks.h http://svn.telesphoreo.org/trunk/tool/patches/locks.h 
	svn cat http://svn.telesphoreo.org/trunk/tool/patches/locks.h@679 > arm/locks.h


	mkdir GraphicsServices
	cd GraphicsServices
	svn cat  http://svn.telesphoreo.org/trunk/tool/patches/GraphicsServices.h@357 > GraphicsServices.h

	popd

	# Changed some of the below commands from sudo; don't know why they were like that
	message_status "Checking out iphone-dev repo..."
	mkdir -p "${CSU_DIR}"
	cd "${CSU_DIR}"
	svn co http://iphone-dev.googlecode.com/svn/trunk/csu .
	cp -R -p *.o "$TOOLCHAIN/sys/usr/lib"
	cd "$TOOLCHAIN/sys/usr/lib"
	chmod 644 *.o
	cp -R -pf crt1.o crt1.10.5.o
	cp -R -pf dylib1.o dylib1.10.5.o

	if [ ! -d $GCC_DIR ]; then
		message_status "Checking out saurik's llvm-gcc-4.2..."
		git clone -n git://git.saurik.com/llvm-gcc-4.2 "${GCC_DIR}"
		pushd "${GCC_DIR}" && git checkout b3dd8400196ccb63fbf10fe036f9f8725b2f0a39 && popd
	else
		pushd "${GCC_DIR}"
		git pull 
		# mg; after success nail to a running version
		if ! git pull git://git.saurik.com/llvm-gcc-4.2 || ! git checkout b3dd8400196ccb63fbf10fe036f9f8725b2f0a39; then
			error "Failed to checkout saurik's llvm-gcc-4.2."
			exit 1
		fi
		popd
	fi

	message_status "Checking out odcctools..."
	mkdir -p "${CCTOOLS_DIR}"

	# ATTENTION: need to install ia32-libs, multilibs
	svn co -r287 http://iphone-dev.googlecode.com/svn/branches/odcctools-9.2-ld "${CCTOOLS_DIR}"

	# patch rc/cctools/ld64/src/Options.h (#include <cstring> #include <limits.h>)
	cd "${CCTOOLS_DIR}"
	patch -p0 < "$IPHONEDEV_DIR/ld64_options.patch"

	message_status "Configuring cctools-iphone..."
	mkdir -p "$TOOLCHAIN/pre"
	mkdir -p "$TOOLCHAIN/bld/cctools-iphone"
	cd "$TOOLCHAIN/bld/cctools-iphone"

	CFLAGS="-m32" LDFLAGS="-m32" "${CCTOOLS_DIR}"/configure \
		--target="${TARGET}" \
		--prefix="$TOOLCHAIN/pre" \
		--enable-ld64

	make clean > /dev/null

	message_status "Building cctools-iphone..."
	cecho bold "Build progress logged to: toolchain/bld/cctools-iphone/make.log"
	if ! ( make &>make.log && make install &>install.log ); then
		error "Build & install failed. Check make.log and install.log"
		exit 1
	fi

	# default linker is now ld64
	mv "${TOOLCHAIN}/pre/bin/arm-apple-darwin9-ld" "${TOOLCHAIN}/pre/bin/arm-apple-darwin9-ld_classic"
	ln -s "${TOOLCHAIN}/pre/bin/arm-apple-darwin9-ld64" "${TOOLCHAIN}/pre/bin/arm-apple-darwin9-ld"

	message_status "Configuring gcc-4.2-iphone..."
	mkdir -p "$TOOLCHAIN/bld/gcc-4.2-iphone"
	cd "$TOOLCHAIN/bld/gcc-4.2-iphone"
	"${GCC_DIR}"/configure \
		--target="${TARGET}" \
		--prefix="$TOOLCHAIN/pre" \
		--with-sysroot="$TOOLCHAIN/sys" \
		--enable-languages=c,c++,objc,obj-c++ \
		--with-as="$TOOLCHAIN"/pre/bin/"${TARGET}"-as \
		--with-ld="$TOOLCHAIN"/pre/bin/"${TARGET}"-ld \
		--enable-wchar_t=no \
		--with-gxx-include-dir=/usr/include/c++/4.2.1
	make clean > /dev/null
	message_status "Building gcc-4.2-iphone..."
	cecho bold "Build progress logged to: toolchain/bld/gcc-4.2-iphone/make.log"
	if ! ( make -j2 &>make.log && make install &>install.log ); then
		error "Build & install failed. Check make.log and install.log"
		exit 1
	fi

	mkdir -p "$TOOLCHAIN/sys"/"$(dirname $TOOLCHAIN/pre)"
	ln -sf "$TOOLCHAIN/pre" "$TOOLCHAIN/sys"/"$(dirname $TOOLCHAIN/pre)"
}

class_dump() {

	local IPHONE_SDK_LIBS="${SDKS_DIR}/iPhoneOS${TOOLCHAIN_VERSION}.sdk/System/Library"
	mkdir -p "${TMP_DIR}"

	if [ -z $IPHONE_IP ]; then
		echo "This step will extract Objective-C headers from the iPhone frameworks."
		echo "To do this, you will need SSH access to an iPhone with class-dump"
		echo "installed, which can be done through Cydia."
		read -p "What is your iPhone's IP address? " IPHONE_IP
		[ -z $IPHONE_IP ] && exit 1
	fi
	
	message_status "Selecting required SDK components..."
	[ -d "${SDKS_DIR}/iPhoneOS${TOOLCHAIN_VERSION}.sdk" ] || toolchain_extract_headers
	for type in PrivateFrameworks; do
		for folder in `find ${IPHONE_SDK_LIBS}/${type} -name *.framework`; do
			framework=`basename "${folder}" .framework`
			mkdir -p "${TMP_DIR}/Frameworks/${framework}"
			cp "${folder}/${framework}" "${TMP_DIR}/Frameworks/${framework}/"
		done
	done
	
	message_status "Copying frameworks to iPhone (${IPHONE_IP})..."
	echo "rm -Rf /tmp/Frameworks" | ssh root@$IPHONE_IP
	if ! scp -r "${TMP_DIR}/Frameworks" root@$IPHONE_IP:/tmp/; then
		error "Failed to copy frameworks to iPhone. Check the connection."
		exit 1
	fi
	rm -Rf "${TMP_DIR}/Frameworks"
	
	message_status "Class dumping as root@$IPHONE_IP..."
	ssh root@$IPHONE_IP <<'COMMAND'
		if [ -z `which class-dump` ]; then
			echo "It doesn't look like class-dump is installed. Would you like me"
			read -p "to try to install it (Y/n)? "
			([ "$REPLY" == "n" ] || [ "$REPLY" == "no" ]) && exit 1
			if [ -z `which apt-get` ]; then
				echo "I can't install class-dump without Cydia."
				exit 1
			fi
			apt-get install class-dump
		fi
		
		for folder in /tmp/Frameworks/*; do
			framework=`basename $folder`
			echo $framework
			pushd $folder > /dev/null
			if [ -r "$folder/$framework" ]; then
				class-dump -H $folder/$framework &> /dev/null
				rm -f "$folder/$framework"
			fi
			popd > /dev/null
		done
		exit 0
COMMAND
	if [ $? ]; then
		error "Failed to export iPhone frameworks."
		exit 1
	fi
	
	message_status "Framework headers exported. Copying..."
	scp -r root@$IPHONE_IP:/tmp/Frameworks  "${TMP_DIR}"
	#yes n | cp -R -i "${TMP_DIR}"/Frameworks/* "${IPHONEDEV_DIR}/toolchain/sys/usr/include/"
}

check_environment() {
	[ $TOOLCHAIN_CHECKED ] && return
	message_action "Preparing the environment"
	cecho bold "Toolchain version: ${TOOLCHAIN_VERSION}"
	cecho bold "Building in: ${IPHONEDEV_DIR}"
	if [[ "`vercmp $TOOLCHAIN_VERSION 2.0`" == "older" ]]; then
		error "The toolchain builder is only capable of building toolchains targeting"
		error "iPhone SDK >=2.0. Sorry."
		exit 1
	fi
	
	# Check for required commands
	local command
	local missing
	for c in $NEEDED_COMMANDS ; do
		if [ -z $(which $c) ] ; then 
			missing="$missing $c"
		fi
	done
	if [ "$missing" != "" ] ; then
		error "The following commands are missing:$missing"
		error "You may need to install additional software for them using your package manager."
		exit 1
	fi
	
	# Performs a check for objective-c extensions to gcc
	if [ ! -z "`LANG=C gcc --help=objc 2>&1 | grep \"warning: unrecognized argument to --help\"`" ]; then
		error "GCC does not appear to support Objective-C."
		error "You may need to install support, for example the \"gobjc\" package in debian."
		exit
	fi
	
	message_status "Environment is ready"
}

case $1 in
	all)
		check_environment
		export TOOLCHAIN_CHECKED=1
		( ./toolchain.sh headers && \
		  ./toolchain.sh darwin_sources && \
		  ./toolchain.sh firmware && 
		  ./toolchain.sh build ) || exit 1
		
		confirm "Do you want to clean up the source files used to build the toolchain?" && ./toolchain.sh clean
		message_action "All stages completed. The toolchain is ready."
		unset TOOLCHAIN_CHECKED
		;;
		
	headers)
		check_environment
		message_action "Getting the header files..."
		toolchain_extract_headers
		message_action "Headers extracted."
		;;

	darwin_sources)
		check_environment
		toolchain_download_darwin_sources
		message_action "Darwin sources retrieved."
		;;

	firmware)
		check_environment
		message_action "Extracting firmware files..."
		toolchain_extract_firmware
		message_action "Firmware extracted."
		;;

	build|rebuild)
		check_environment
		message_action "Building the toolchain..."
		# This is more of a debugging tool at the moment
		if [ "$1" == "rebuild" ]; then
			rm -Rf "${IPHONEDEV_DIR}/toolchain/pre/"
			rm -Rf "${IPHONEDEV_DIR}/toolchain/sys/"
			rm -Rf "${IPHONEDEV_DIR}/toolchain/bld/"
		fi
		toolchain_build
		message_action "It seems like the toolchain built!"
		;;
	
	classdump)
		check_environment
		message_action "Preparing to classdump..."
		class_dump
		message_action "Copy completed."
		;;

	clean)
		message_status "Cleaning up..."
		
		for file in ${FW_DIR}/*; do
			[ -d "${file}" ] && rm -Rf "${file}"
		done
		rm -f "${FW_DIR}/current"	
		rm -Rf "${MNT_DIR}"
		rm -Rf "${DARWIN_SOURCES_DIR}"
		rm -Rf "${SDKS_DIR}"
		rm -Rf "${TOOLS_DIR}"
		rm -Rf "${TMP_DIR}"
		rm -Rf "${IPHONEDEV_DIR}/toolchain/src/"
		rm -Rf "${IPHONEDEV_DIR}/toolchain/bld/"
		[ -r $IPHONE_SDK_DMG ] && confirm -N "Do you want me to remove the SDK dmg?" && rm "${IPHONE_SDK_DMG}"
		if confirm -N "Do you want me to remove the firmware image(s)?"; then
			for fw in $FW_DIR/*.ipsw; do rm $fw; done
		fi
		;;

	*)
		# Shows usage information to the user
		BOLD=$(tput bold)
		ENDF=$(tput sgr0)
		echo	"toolchain.sh <action>"
		echo
		echo	"    ${BOLD}all${ENDF}"
		echo -e "    \tPerform all steps in order: headers, darwin_sources,"
		echo -e "    \tfirmware, build and clean."
		echo
		echo	"    ${BOLD}headers${ENDF}"
		echo -e "    \tExtract headers from an iPhone SDK dmg provided by"
		echo -e "    \tthe user in <toolchain>/files/<sdk>.dmg."
		echo
		echo	"    ${BOLD}darwin_sources${ENDF}"
		echo -e "    \tRetrieve required Apple OSS components using a valid"
		echo -e "    \tApple ID and password."
		echo
		echo	"    ${BOLD}firmware${ENDF}"
		echo -e "    \tDownload (optional) and extract iPhone an firmware"
		echo -e "    \timage for the specified toolchain version."
		echo
		echo	"    ${BOLD}build${ENDF}"
		echo -e "    \tAcquire and build the toolchain sources."
		echo
		echo	"    ${BOLD}classdump${ENDF}"
		echo -e "    \tGenerates Objective-C headers using public and private"
		echo -e "    \tframeworks retrieved from an iPhone."
		echo
		echo	"    ${BOLD}clean${ENDF}"
		echo -e "    \tRemove source files, extracted dmgs and ipsws and"
		echo -e "    \ttemporary files, leaving only the compiled toolchain"
		echo -e "    \tand headers."
		;;
esac
