#!/bin/bash

### Little Android Build Script
### Copyright 2017, Tab Fitts

# red = errors, cyan = warnings, green = confirmations, blue = informational
# plain for generic text, bold for titles, reset flag at each end of line
CLR_RST=$(tput sgr0)                        ## reset flag
CLR_RED=$CLR_RST$(tput setaf 1)             #  red, plain
CLR_GRN=$CLR_RST$(tput setaf 2)             #  green, plain
CLR_BLU=$CLR_RST$(tput setaf 4)             #  blue, plain
CLR_CYA=$CLR_RST$(tput setaf 6)             #  cyan, plain
CLR_BLD=$(tput bold)                        ## bold flag
CLR_BLD_RED=$CLR_RST$CLR_BLD$(tput setaf 1) #  red, bold
CLR_BLD_GRN=$CLR_RST$CLR_BLD$(tput setaf 2) #  green, bold
CLR_BLD_BLU=$CLR_RST$CLR_BLD$(tput setaf 4) #  blue, bold
CLR_BLD_CYA=$CLR_RST$CLR_BLD$(tput setaf 6) #  cyan, bold

source config.conf
export ANDROID_BUILD_DIR=$(pwd)
chmod a+x otacommit.sh upload-sftp.sh

# Output current config
function showCurrentConfig {
        echo -e "${CLR_BLD_BLU}Sync source: ${CLR_RST}${CLR_CYA}${REPOSYNC}${CLR_RST}${CLR_RST}"
        echo -e "${CLR_BLD_BLU}Make clean: ${CLR_RST}${CLR_CYA}${MAKECLEAN}${CLR_RST}${CLR_RST}"
        echo -e "${CLR_BLD_BLU}Upload build to FTP: ${CLR_RST}${CLR_CYA}${UPLOADFTP}${CLR_RST}${CLR_RST}"
        echo -e "${CLR_BLD_BLU}Update OTA XML: ${CLR_RST}${CLR_CYA}${UPDATEOTAXML}${CLR_RST}${CLR_RST}"
}

showCurrentConfig

# Pick the default thread count (allow overrides from the environment)
if [ -z "$THREADS" ]; then
        if [ "$(uname -s)" = 'Darwin' ]; then
                export THREADS=$(sysctl -n machdep.cpu.core_count)
        else
                export THREADS=$(cat /proc/cpuinfo | grep '^processor' | wc -l)
        fi
fi

# Setup build environment
echo -e "${CLR_BLD_BLU}Setting up the build environment${CLR_RST}"
echo -e ""
. build/envsetup.sh
echo -e ""

source config.conf

# Return value
RETVAL=0

echo -e "${CLR_BLD_BLU}Starting compilation${CLR_RST}"

if [ $MAKECLEAN -eq 1 ]
then
    make clean && brunch $ROMPREFIX_$DEVICECODENAME-userdebug -j"$((THREADS * 2+2))"
else
    make installclean && brunch $ROMPREFIX_$DEVICECODENAME-userdebug -j"$((THREADS * 2+2))"
fi

# Check if the build failed
if [ $RETVAL -ne 0 ]; then
        echo "${CLR_BLD_RED}Build failed!${CLR_RST}"
        echo -e ""
        exit $RETVAL
fi

echo " "
echo "${CLR_BLD_GRN}Build completed.${CLR_RST}"
echo " "

cd $OUT

export FILENAME=$(ls |grep -m 1 $ROMPREFIX*.zip)
export MD5SUMNAME=$(ls |grep -m 1 $ROMPREFIX*.md5sum)
export CHANGELOG=$(ls |grep -m 1 $ROMPREFIX*changelog.txt)
export FILESIZE=$(stat -c%s $FILENAME)
export MD5=$(md5sum $FILENAME | awk '{ print $1 }')
export OTA_VERSION=$(echo ${FILENAME%.*})
export OTA_NUMBER=$(cat $OUT/system/build.prop |grep ro.ota.version=* | awk -F'=' '{print $2}')

cd $ANDROID_BUILD_DIR

if [ $UPLOADFTP -eq 1 ]
then
    echo " "
    echo "${CLR_BLD_BLU}Uploading...${CLR_RST}"
    unset sftpStatus
    sh upload-sftp.sh $FTPUSER@$FTPSERVER:$FTPPATH $OUT/$FILENAME $OUT/$MD5SUMNAME
    sh upload-sftp.sh $FTPUSER@$FTPSERVER:$FTPPATH $OUT/$CHANGELOG ||
    if [ "$sftpStatus" != "" ]
    then
        echo "${CLR_BLD_RED}Upload failed!${CLR_RST}"
        echo -e ""
        exit 1
    fi
    echo " "
    echo "${CLR_BLD_GRN}Upload complete.${CLR_RST}"
    echo " "
else
    echo " "
fi

if [ $UPDATEOTAXML -eq 1 ]
then
    ./otacommit.sh
    cd $ANDROID_BUILD_DIR
fi

echo " "
echo " "
echo "Little Android Build Script Completed!"
