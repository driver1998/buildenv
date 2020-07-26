sudo mv $PWD/$(find llvm-mingw* -maxdepth 1 -type d | head -n 1) /opt/llvm-mingw

export HOST=$ARCH-w64-mingw32
export MINGW_ROOT=/opt/llvm-mingw
export PREFIX=/opt/$HOST
export PATH=$PATH:$MINGW_ROOT/bin:$PREFIX/bin
export PKG_CONFIG_PATH=$PKG_CONFIG_PATH:$PREFIX/lib/pkgconfig

export CFLAGS="-I$PREFIX/include \
     -Wno-unused-function -Wno-unused-lambda-capture -Wno-unused-variable \
     -Wno-ignored-attributes -Wno-inconsistent-missing-override \
     -Wno-inconsistent-dllimport"
export CXXFLAGS=$CFLAGS
export CPPFLAGS="-I$PREFIX/include"
export LDFLAGS="-L$PREFIX/lib"

echo Building for $HOST

sudo mkdir -p $PREFIX/bin
sudo mkdir -p $PREFIX/include
sudo mkdir -p $PREFIX/lib/pkgconfig

# zlib
pushd $(find zlib-* -maxdepth 1 -type d | head -n 1)
make -j $(nproc) -f win32/Makefile.gcc PREFIX=$HOST- || exit 1
sudo make -f win32/Makefile.gcc install \
         SHARED_MODE=1 \
         BINARY_PATH=$PREFIX/bin \
         INCLUDE_PATH=$PREFIX/include \
         LIBRARY_PATH=$PREFIX/lib || exit 1
popd

# libpng
pushd $(find libpng-* -maxdepth 1 -type d | head -n 1)
./configure --prefix=$PREFIX --host=$HOST --disable-static --enable-shared || exit 1
make -j $(nproc)   || exit 1
sudo make install  || exit 1
pushd $PREFIX/lib
sudo ln -s libpng.dll.a libpng.a
popd
popd

# SDL2
pushd $(find SDL2-* -maxdepth 1 -type d | head -n 1)
for a in ../patches/sdl2-*.patch; do patch -p1 < $a; done
aclocal
autoconf
./configure --prefix=$PREFIX --host=$HOST --disable-video-opengl \
            --disable-video-opengles --disable-video-opengles1 \
            --disable-video-opengles2 --disable-video-vulkan \
            --disable-static --enable-shared || exit 1
make -j $(nproc)                   || exit 1
sudo env "PATH=$PATH" make install || exit 1
pushd $PREFIX/lib
sudo ln -s libSDL2.dll.a libSDL2.a
popd
popd

# openal-soft
pushd $(find openal-soft-* -maxdepth 1 -type d | head -n 1)
patch -p1 < ../patches/openal-assume-neon-on-windows-arm.patch
sed -i "s/\/usr\/\${HOST}/$(echo $PREFIX | sed 's/\//\\\//g')/g" XCompile.txt
cmake . -DCMAKE_TOOLCHAIN_FILE=XCompile.txt -DHOST=$HOST \
        -DDSOUND_LIBRARY=$MINGW_ROOT/$HOST/lib \
        -DDSOUND_INCLUDE_DIR=$MINGW_ROOT/$HOST/include || exit 1
make -j $(nproc)   || exit 1
sudo make install  || exit 1
pushd $PREFIX/lib
sudo ln -s libOpenAL32.dll.a libopenal.a
popd
popd

# freetype
pushd $(find freetype-* -maxdepth 1 -type d | head -n 1)
./configure --prefix=$PREFIX --host=$HOST --disable-static --enable-shared || exit 1
make -j $(nproc)   || exit 1
sudo make install  || exit 1
popd


# gmp
pushd $(find gmp* -maxdepth 1 -type d | head -n 1)
./configure --prefix=$PREFIX --host=$HOST --disable-static --enable-shared \
            --disable-cxx --disable-assembly || exit 1
make -j $(nproc)   || exit 1
sudo make install  || exit 1
popd

# nettle
pushd $(find nettle* -maxdepth 1 -type d | head -n 1)
./configure --prefix=$PREFIX --host=$HOST --disable-static --enable-shared --disable-assembler \
            --with-include-path=$PREFIX/include --with-lib-path=$PREFIX/lib || exit 1
make -j $(nproc)   || exit 1
sudo make install  || exit 1
popd

# gnutls
pushd $(find gnutls* -maxdepth 1 -type d | head -n 1)
GMP_CFLAGS="-I$PREFIX/include" GMP_LIBS="-L$PREFIX/lib -lgmp" \
./configure --prefix=$PREFIX --host=$HOST --disable-static --enable-shared --disable-cxx \
            --without-p11-kit --with-included-libtasn1 --with-included-unistring --enable-local-libopts \
            --disable-srp-authentication --disable-dtls-srtp-support --disable-heartbeat-support \
            --disable-psk-authentication --disable-anon-authentication --disable-openssl-compatibility --without-tpm \
            --disable-hardware-acceleration --disable-tools --disable-doc || exit 1
make -j $(nproc)   || exit 1
sudo make install  || exit 1
popd

# sqlite
pushd $(find sqlite* -maxdepth 1 -type d | head -n 1)
./configure --prefix=$PREFIX --host=$HOST --disable-static --enable-shared || exit 1
make              || exit 1
sudo make install || exit 1
popd

PROJECT=$PWD
pushd /opt
tar cJf $PROJECT/buildenv.tar.xz $HOST
popd

