#!/bin/bash
#https://ftp.gnu.org/gnu/ncurses/ncurses-6.0.tar.gz

VERSION=6.0
VVERSION=$VERSION
SUFFIX=tar.gz
NAME=ncurses
DOWNLOAD_URL=https://ftp.gnu.org/gnu/ncurses/$NAME-$VVERSION.$SUFFIX

. ../../env.sh

BUILD_DIR=$STAGING/$NAME-$VERSION
TARGET=$BUILD_DIR/$NAME
DEB=$BUILD_DIR/$NAME-${VERSION}_kbox4_${DEB_ARCH}.deb


if [ -f $DEB ]; then
  echo $DEB exists -- delete it to rebuild
  exit 0;
fi

if [ ! -d $BUILD_DIR ]; then 
  mkdir -p $STAGING/tarballs
  TARBALL=$STAGING/tarballs/$NAME-$VERSION.$SUFFIX
  if [ ! -f $TARBALL ]; then 
    echo "Downloading $VERSION"
    wget -O $TARBALL $DOWNLOAD_URL 
  else
    echo "Using cached $TARBALL"
  fi 
  mkdir -p $STAGING
  (cd $STAGING; tar xfvz $TARBALL)
else
  echo "Building cached $VERSION"
fi


echo Running Configure for wide char support...


(cd $BUILD_DIR; CC=$CC CFLAGS="-fpie -fpic" LDFLAGS="-pie" ./configure --host=$CONFIG_HOST --prefix=/usr --enable-widec)

if [[ $? -ne 0 ]] ; then
    echo Configure failed ... stopping
    exit 1
fi


echo "Running make"

(cd $BUILD_DIR; make CC=$CC)

echo "Build errors ignored, because the build script is too stupid to understand"
echo "that we are cross-compiling"

mkdir -p $BUILD_DIR/image/


echo "Running make install"
(cd $BUILD_DIR; make DESTDIR=`pwd`/image install)

if [[ $? -ne 0 ]] ; then
    echo make install failed ... stopping
    exit 1
fi

echo Running Configure for narrow char support...


(cd $BUILD_DIR; CC=$CC CFLAGS="-fpie -fpic" LDFLAGS="-pie" ./configure --host=$CONFIG_HOST --prefix=/usr)

if [[ $? -ne 0 ]] ; then
    echo Configure failed ... stopping
    exit 1
fi


echo "Running make"

(cd $BUILD_DIR; make CC=$CC)

echo "Build errors ignored, because the build script is too stupid to understand"
echo "that we are cross-compiling"

mkdir -p $BUILD_DIR/image/


echo "Running make install"
(cd $BUILD_DIR; make DESTDIR=`pwd`/image install)

if [[ $? -ne 0 ]] ; then
    echo make install failed ... stopping
    exit 1
fi


echo "Removing unnecessary terminal definitions"
rm -rf $BUILD_DIR/image/usr/share/terminfo/*
mkdir -p $BUILD_DIR/image/usr/share/terminfo/l
cp linux $BUILD_DIR/image/usr/share/terminfo/l/

echo "Linking shared objects"
#(cd $BUILD_DIR/image/usr/lib; $CC -s -pie -shared -fPIC -o libcurses.so -Wl,-soname,libcurses.so -Wl,--whole-archive libcurses.a -Wl,--no-whole-archive)
(cd $BUILD_DIR/image/usr/lib; for x in *.a ; do r=`echo $x | cut -f 1 -d .`;  echo $r; $CC -s -pie -shared -fPIC -o $r.so -Wl,-soname,$r.so -Wl,--whole-archive $r.a -Wl,--no-whole-archive; done)

echo "Building package"
mkdir -p $BUILD_DIR/out

sed -e s/%ARCH%/$DEB_ARCH/ control | sed -e s/%VERSION%/$VERSION/ > $BUILD_DIR/control

(cd $BUILD_DIR; tar cfz out/data.tar.gz -C image ".") 
(cd $BUILD_DIR; tar cfz out/control.tar.gz ./control) 
echo "2.0" > $BUILD_DIR/out/debian-binary
rm -f $DEB
ar rcs $DEB $BUILD_DIR/out/debian-binary $BUILD_DIR/out/data.tar.gz $BUILD_DIR/out/control.tar.gz 
cp -p $DEB $DIST/ 

echo "Populating compiler sysroot"

mkdir -p $SYSROOT/usr/include/ncurses
(cd $BUILD_DIR; cp -pr image/usr/include/* $SYSROOT/usr/include/ncurses/) 
(cd $BUILD_DIR; cp -pr image/usr/lib/* $SYSROOT/usr/lib/) 


