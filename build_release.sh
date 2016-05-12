#!/bin/bash
# This is script to create a build for particular release version.
# It will create an archive which will be used to deploy a source code on CDL Gateway.
# It should be run from ts-common-data-lake directory.
#
# example: ./build_release.sh

PWD=$(pwd)

RELEASE=`git describe --exact-match --abbrev=0`

# To create valid release the following 3 conditions should be met:
# 1. The current git version should be tagged as release.
# 2. The current git version should include directory with source code.
# 3. The current git version should include directory for built releases.
 
if [[ $? > 0 ]]; then
    echo "The current git revision do not contain any release tag, please checkout correct revision!"
    exit 1
elif [[ ! -d $PWD/src ]]; then
    echo "The current git revision is broken. It do not have src directory, please checkout correct revision!"
    exit 1
elif [[ ! -d $PWD/releases ]]; then
    echo "The current git revision is broken. It do not have release directory, please checkout correct revision!"
    exit 1
fi

#Save information about this release
touch $PWD/src/release_version.txt
echo $RELEASE >> $PWD/src/release_version.txt

#Do archiving for src
cp $PWD/releases/RELEASES_INFO.txt $PWD/src 
tar -zcvf src-archive-release-$RELEASE.tar.gz src
mv src-archive-release-$RELEASE.tar.gz releases

#Do archiving for test
cp $PWD/releases/RELEASES_INFO.txt $PWD/test
cp $PWD/src/release_version.txt $PWD/test
tar -zcvf test-archive-release-$RELEASE.tar.gz test
mv test-archive-release-$RELEASE.tar.gz releases

#Post-build cleaning operations
rm $PWD/test/release_version.txt
rm $PWD/src/release_version.txt
rm $PWD/test/RELEASES_INFO.txt
rm $PWD/src/RELEASES_INFO.txt 
