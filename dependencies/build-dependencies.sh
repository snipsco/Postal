#!/bin/sh

pushd "`dirname "$0"`" > /dev/null
scriptpath="`pwd`"
popd > /dev/null

# configuration
url="https://github.com/snipsco/libetpan.git"
rev=6a08017f1c742f0c5817d6c1c71143a37da967be

ios_target="libetpan ios"
macos_target="static libetpan"

xcode_project="libetpan.xcodeproj"


embedded_deps="libsasl-ios"

# prepare vars 
name="libetpan"
ios_library="libetpan-ios.a"
ios_simarchs="i386 x86_64"
ios_devicearchs="armv7 armv7s arm64"
ios_sdkminversion="7.0"
ios_sdkversion="`xcodebuild -showsdks 2>/dev/null | grep iphoneos | sed 's/.*iphoneos\(.*\)/\1/'`"

macos_library="libetpan.a"
macos_sdk="`xcodebuild -showsdks 2>/dev/null | grep macosx | sed 's/.*macosx\(.*\)/\1/'`"
macos_archs="x86_64"
macos_sdkminversion="10.7"

BUILD_TIMESTAMP=`date +'%Y%m%d%H%M%S'`
checkoutdir="$scriptpath/checkouts"
outdir="$scriptpath/build"
ios_resultdir="$outdir/ios"
macos_resultdir="$outdir/macos"
tempbuilddir="$scriptpath/workdir/$BUILD_TIMESTAMP"
srcdir="$tempbuilddir/src"
tmpdir="$tempbuilddir/tmp"

echo "working in $tempbuilddir"

# prepare directories
mkdir -p "$ios_resultdir"
mkdir -p "$macos_resultdir"
mkdir -p "$tmpdir"
mkdir -p "$srcdir"
mkdir -p "$ios_resultdir/lib"
mkdir -p "$ios_resultdir/include"
mkdir -p "$macos_resultdir/lib"
mkdir -p "$macos_resultdir/include"

# checkout git revision
pushd . >/dev/null
mkdir -p "$checkoutdir"
cd "$checkoutdir"
if test -d "$name" ; then
  cd "$name"
  git checkout master
  git pull --rebase
else
  git clone $url "$name"
  cd "$name"
fi

popd >/dev/null

pushd . >/dev/null

# make fresh copy from checkout
cp -R "$checkoutdir/$name" "$srcdir/$name"
cd "$srcdir/$name"
git checkout -q $rev
echo building $name - $rev

# build for ios
BITCODE_FLAGS="-fembed-bitcode"
XCTOOL_OTHERFLAGS='$(inherited)'
XCTOOL_OTHERFLAGS="$XCTOOL_OTHERFLAGS $BITCODE_FLAGS"
XCODE_FLAGS="GCC_PREPROCESSOR_DEFINITIONS=NO_MACROS=1"

cd "$srcdir/$name/build-mac"
sdk="iphoneos$ios_sdkversion"
echo building $sdk
set -o pipefail && xcodebuild -project "$xcode_project" -sdk $sdk -scheme "$ios_target" -configuration Release SYMROOT="$tmpdir/bin" OBJROOT="$tmpdir/obj" ARCHS="$ios_devicearchs" IPHONEOS_DEPLOYMENT_TARGET="$ios_sdkminversion" OTHER_CFLAGS="$XCTOOL_OTHERFLAGS" $XCODE_FLAGS $XCODE_BITCODE_FLAGS | xcpretty
if test x$? != x0 ; then
  echo failed
  exit 1
fi
sdk="iphonesimulator$ios_sdkversion"
echo building $sdk
set -o pipefail && xcodebuild -project "$xcode_project" -sdk $sdk -scheme "$ios_target" -configuration Release SYMROOT="$tmpdir/bin" OBJROOT="$tmpdir/obj" ARCHS="$ios_simarchs" IPHONEOS_DEPLOYMENT_TARGET="$ios_sdkminversion" OTHER_CFLAGS='$(inherited)' $XCODE_FLAGS | xcpretty
if test x$? != x0 ; then
  echo failed
  exit 1
fi

# build for macos
set -o pipefail && xcodebuild -project "$xcode_project" -sdk macosx$macos_sdk -scheme "$macos_target" -configuration Release ARCHS="$macos_archs" SYMROOT="$tmpdir/bin" OBJROOT="$tmpdir/obj" MACOSX_DEPLOYMENT_TARGET="$macos_sdkminversion" $XCODE_FLAGS | xcpretty
if test x$? != x0 ; then
  echo failed
  exit 1
fi

echo finished

# copy outputs to result dirs
cd "$tmpdir/bin"

# copy headers
cp -R Release-iphoneos/include/* "$ios_resultdir/include"
cp -R Release/include/* "$macos_resultdir/include"

# copy libetpan ios static library
lipo -create "Release-iphoneos/$ios_library" \
  "Release-iphonesimulator/$ios_library" \
    -output "$ios_resultdir/lib/$name.a"

# copy libetpan macos static library
cp "Release/$macos_library" "$macos_resultdir/lib/"

# copy ios dependencies static libraries
for dep in $embedded_deps ; do
  cp -R "$srcdir/$name/build-mac/$dep/lib/"* "$ios_resultdir/lib/"
  cp -R "$srcdir/$name/build-mac/$dep/include/"* "$ios_resultdir/include/"
done

echo "$rev"> "$outdir/git-rev"

echo build of $name done

popd >/dev/null

echo cleaning
rm -rf "$tempbuilddir"
