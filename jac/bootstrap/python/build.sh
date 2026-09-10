#!/bin/sh
# Native release builds: every C translation and archive uses the pinned Zig.
set -eu
platform=$1
work=$2
zig=$3
recipe=$4
jobs=${JAC_PYTHON_JOBS:-4}
case "$jobs" in ''|*[!0-9]*|0) echo 'JAC_PYTHON_JOBS must be a positive integer' >&2; exit 1;; esac
case "$platform" in
    linux-x86_64) target=x86_64-linux-gnu.2.17; openssl_target=linux-x86_64 ;;
    linux-aarch64) target=aarch64-linux-gnu.2.17; openssl_target=linux-aarch64 ;;
    macos-x86_64) target=x86_64-macos.12.0; openssl_target=darwin64-x86_64-cc ;;
    macos-aarch64) target=aarch64-macos.11.0; openssl_target=darwin64-arm64-cc ;;
    *) echo "Unsupported Python release platform: $platform" >&2; exit 1 ;;
esac
for tool in make perl patch; do
    command -v "$tool" >/dev/null || { echo "Source Python builds require $tool" >&2; exit 1; }
done
prefix=$work/python/install
deps=$work/deps
src=$work/src
mkdir -p "$prefix" "$deps/lib" "$deps/include" "$work/bin" "$work/logs"
export JAC_PYTHON_ZIG="$zig" JAC_PYTHON_TARGET="$target"
case "$platform" in
    macos-*)
        JAC_PYTHON_SDK=$(xcrun --sdk macosx --show-sdk-path)
        export JAC_PYTHON_SDK
        case "$platform" in
            macos-x86_64) export MACOSX_DEPLOYMENT_TARGET=12.0 ;;
            macos-aarch64) export MACOSX_DEPLOYMENT_TARGET=11.0 ;;
        esac
        ;;
    *) unset JAC_PYTHON_SDK || true ;;
esac
cat > "$work/bin/cc" <<'SH'
#!/bin/sh
if [ -n "${JAC_PYTHON_SDK:-}" ]; then
    exec "$JAC_PYTHON_ZIG" cc -target "$JAC_PYTHON_TARGET" -isysroot "$JAC_PYTHON_SDK" -isystem "$JAC_PYTHON_SDK/usr/include" -F "$JAC_PYTHON_SDK/System/Library/Frameworks" -Wno-unused-command-line-argument "$@"
fi
exec "$JAC_PYTHON_ZIG" cc -target "$JAC_PYTHON_TARGET" -Wno-unused-command-line-argument "$@"
SH
cat > "$work/bin/ar" <<'SH'
#!/bin/sh
exec "$JAC_PYTHON_ZIG" ar "$@"
SH
cat > "$work/bin/ranlib" <<'SH'
#!/bin/sh
exec "$JAC_PYTHON_ZIG" ranlib "$@"
SH
chmod +x "$work/bin/cc" "$work/bin/ar" "$work/bin/ranlib"
export CC="$work/bin/cc" AR="$work/bin/ar" RANLIB="$work/bin/ranlib"
# The completed SDK is cached separately. Keep transient C compilation caches
# in this build tree so dependency objects cannot exhaust release-runner disks.
export ZIG_LOCAL_CACHE_DIR="$work/cc-cache" ZIG_GLOBAL_CACHE_DIR="$work/cc-cache"
export SOURCE_DATE_EPOCH=0
# Zig's tar extractor does not preserve mtimes. Equalize the released source
# inputs so make uses the shipped generated files instead of invoking Autotools.
TZ=UTC0 find "$src" -exec touch -t 200001010000.00 {} +
export CFLAGS='-O2 -fPIC' CPPFLAGS="-I$deps/include" LDFLAGS="-L$deps/lib"
# Do not discover libraries from the runner's package manager.
export PKG_CONFIG=false PKG_CONFIG_PATH= PKG_CONFIG_LIBDIR="$deps/lib/pkgconfig"
unset CXXFLAGS CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH LD_LIBRARY_PATH DYLD_LIBRARY_PATH || true

step() {
    label=$1; shift
    echo "build-python: $label"
    ( "$@" ) > "$work/logs/$label.log" 2>&1
    rm -rf "$work/cc-cache"
    case "$label" in
        zlib|bzip2|zstd|sqlite|xz|libffi|mpdecimal|expat|openssl)
            rm -rf "$src/$label"
            ;;
    esac
}
trap 'result=$?; if [ "$result" -ne 0 ] && [ -n "${label:-}" ]; then tail -80 "$work/logs/$label.log" >&2; fi' EXIT
zlib() {
    cd "$src/zlib"
    ./configure --prefix="$deps" --static
    make -j"$jobs"
    make install
}
bzip2() {
    cd "$src/bzip2"
    make -j"$jobs" libbz2.a CC="$CC" AR="$AR" RANLIB="$RANLIB" CFLAGS="$CFLAGS"
    cp libbz2.a "$deps/lib/"
    cp bzlib.h "$deps/include/"
}
zstd() {
    cd "$src/zstd"
    make -C lib -j"$jobs" libzstd.a ZSTD_LEGACY_SUPPORT=0
    cp lib/libzstd.a "$deps/lib/"
    cp lib/zstd.h lib/zdict.h lib/zstd_errors.h "$deps/include/"
}
sqlite() {
    cd "$src/sqlite"
    "$CC" $CFLAGS -DSQLITE_THREADSAFE=1 -DSQLITE_ENABLE_COLUMN_METADATA \
        -DSQLITE_ENABLE_FTS5 -DSQLITE_ENABLE_RTREE -DSQLITE_ENABLE_MATH_FUNCTIONS \
        -c sqlite3.c -o sqlite3.o
    "$AR" rcs "$deps/lib/libsqlite3.a" sqlite3.o
    cp sqlite3.h sqlite3ext.h "$deps/include/"
}
xz() {
    cd "$src/xz"
    ./configure --prefix="$deps" --libdir="$deps/lib" --disable-shared \
        --disable-doc --disable-nls --disable-xz --disable-xzdec \
        --disable-lzmadec --disable-lzmainfo --disable-lzma-links --disable-scripts
    make -j"$jobs"
    make install
}
libffi() {
    cd "$src/libffi"
    ./configure --prefix="$deps" --libdir="$deps/lib" --disable-shared \
        --disable-docs --disable-multi-os-directory
    make -j"$jobs"
    make install
}
mpdecimal() {
    cd "$src/mpdecimal"
    ./configure --prefix="$deps" --libdir="$deps/lib" --disable-shared --disable-cxx
    make -j"$jobs"
    make install
}
expat() {
    cd "$src/expat"
    ./configure --prefix="$deps" --libdir="$deps/lib" --disable-shared \
        --without-docbook --without-examples --without-tests
    make -j"$jobs"
    make install
}
openssl() {
    cd "$src/openssl"
    perl Configure "$openssl_target" --prefix="$deps" --libdir=lib \
        no-shared no-tests no-docs no-apps no-asm -fPIC
    make -j"$jobs" build_libs
    make install_dev
}
cpython() {
    cd "$src/cpython"
    patch -f -F0 -p1 -i "$recipe/compiler-bridge.patch"
    # The shared interpreter must survive relocation into the Jac payload.
    case "$platform" in
        linux-*)
            sed 's/-Wl,-h\$(INSTSONAME)/-Wl,-soname,$(INSTSONAME)/g; s/-Wl,-h\$@/-Wl,-soname,$@/g; s/^INSTSONAME=.*/INSTSONAME= libpython$(LDVERSION).so/' \
                Makefile.pre.in > Makefile.pre.in.new
            mv Makefile.pre.in.new Makefile.pre.in
            cat > "$work/bin/pycc" <<'SH'
#!/bin/sh
exec "$JAC_PYTHON_ZIG" cc -target "$JAC_PYTHON_TARGET" -Wno-unused-command-line-argument -Wno-error=date-time '-Wl,-rpath,$ORIGIN/../lib' "$@"
SH
            ;;
        macos-*)
            cat > "$work/bin/pycc" <<'SH'
#!/bin/sh
exec "$JAC_PYTHON_ZIG" cc -target "$JAC_PYTHON_TARGET" -isysroot "$JAC_PYTHON_SDK" -isystem "$JAC_PYTHON_SDK/usr/include" -F "$JAC_PYTHON_SDK/System/Library/Frameworks" -Wno-unused-command-line-argument -Wno-error=date-time '-Wl,-rpath,@loader_path/../lib' "$@"
SH
            # CPython otherwise writes its temporary prefix into the dylib ID.
            sed 's|-Wl,-install_name,$(prefix)/lib/|-Wl,-install_name,@rpath/|' \
                Makefile.pre.in > Makefile.pre.in.new
            mv Makefile.pre.in.new Makefile.pre.in
            ;;
    esac
    chmod +x "$work/bin/pycc"
    export CC="$work/bin/pycc"
    export LIBFFI_CFLAGS="-I$deps/include" LIBFFI_LIBS="$deps/lib/libffi.a"
    export LIBMPDEC_CFLAGS="-I$deps/include" LIBMPDEC_LIBS="$deps/lib/libmpdec.a -lm"
    export LIBSQLITE3_CFLAGS="-I$deps/include" LIBSQLITE3_LIBS="$deps/lib/libsqlite3.a -lm -lpthread"
    export LIBZSTD_CFLAGS="-I$deps/include" LIBZSTD_LIBS="$deps/lib/libzstd.a"
    export ZLIB_CFLAGS="-I$deps/include" ZLIB_LIBS="$deps/lib/libz.a"
    export BZIP2_CFLAGS="-I$deps/include" BZIP2_LIBS="$deps/lib/libbz2.a"
    export LIBLZMA_CFLAGS="-I$deps/include" LIBLZMA_LIBS="$deps/lib/liblzma.a"
    export LIBEXPAT_CFLAGS="-I$deps/include" LIBEXPAT_LIBS="$deps/lib/libexpat.a"
    cat > Modules/Setup.local <<'SETUP'
*disabled*
_tkinter
_testcapi
_testinternalcapi
_testlimitedcapi
_testclinic
_ctypes_test
_gdbm
_dbm
_curses
_curses_panel
readline
SETUP
    ./configure --prefix="$prefix" --enable-shared --without-static-libpython \
        --disable-test-modules --with-ensurepip=no --with-pkg-config=no \
        --with-openssl="$deps" --with-openssl-rpath=no \
        --with-system-expat --with-system-libmpdec --without-readline
    # Embed the same core objects in the executable: venv --copies must run
    # without a libpython next to the copied executable. Jac's launcher still
    # uses the separately built shared library. Neither needs libpython3.so.
    make -j"$jobs" PY3LIBRARY= 'LINK_PYTHON_OBJS=$(LIBRARY_OBJS)'
    make -j"$jobs" PY3LIBRARY= 'LINK_PYTHON_OBJS=$(LIBRARY_OBJS)' install
}
# Preserve notices before discarding each dependency's installed build tree.
mkdir -p "$work/python/licenses"
find "$src" -type f \( -iname 'LICENSE*' -o -iname 'COPYING*' -o -iname 'Copyright*' \) |
while IFS= read -r notice; do
    relative=${notice#"$src/"}
    mkdir -p "$work/python/licenses/$(dirname "$relative")"
    cp "$notice" "$work/python/licenses/$relative"
done
step zlib zlib
step bzip2 bzip2
step zstd zstd
step sqlite sqlite
step xz xz
step libffi libffi
step mpdecimal mpdecimal
step expat expat
step openssl openssl
step cpython cpython
step finalize "$prefix/bin/python3.14" -I "$recipe/finalize.py"
mkdir -p "$work/python/build/lib" "$work/python/licenses"
cp "$deps/lib/"*.a "$work/python/build/lib/"
cp "$src/certifi/certifi/cacert.pem" "$work/python/build/cacert.pem"
step smoke "$prefix/bin/python3.14" -I "$recipe/smoke.py"
# No compiled test modules, docs, or configuration machinery in the runtime.
rm -rf "$prefix/share" "$prefix/lib/python3.14/test" \
    "$prefix/lib/python3.14/idlelib" "$prefix/lib/python3.14/tkinter" \
    "$prefix/lib/python3.14/turtledemo"
echo 'build-python: runtime and native archives ready'
