#!/bin/bash

set -e

export GIT_ADVICE_DETACHED_HEAD=false

# ================= 配置区 =================
OPENSSL_VERSION="openssl-3.6.3"
MACOS_TARGET="14.0"
IOS_TARGET="16.0"

WORK_DIR="$(pwd)/xcframework_build"
SOURCE_DIR="${WORK_DIR}/sources"
DEPS_DIR="${WORK_DIR}/deps"
BUILD_DIR="${WORK_DIR}/build"
OUTPUT_DIR="$(pwd)/xcframework"

mkdir -p "${SOURCE_DIR}" "${DEPS_DIR}" "${BUILD_DIR}" "${OUTPUT_DIR}"

# 依赖检查
FOR_CMDS="cmake ninja git curl tar xcodebuild libtool nasm lipo autoconf automake"
for cmd in $FOR_CMDS; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd 未安装，请先安装 (例: brew install cmake ninja nasm autoconf automake libtool)"
        exit 1
    fi
done

# 检查 glibtoolize 或 libtoolize
if ! command -v glibtoolize &> /dev/null && ! command -v libtoolize &> /dev/null; then
    echo "Error: 未找到 libtoolize / glibtoolize，请先执行: brew install libtool"
    exit 1
fi

# ================= 1. 源码下载 (全部采用 Git Clone) =================
echo "==> [1/4] 克隆依赖库与主项目源码..."

if [ ! -d "${SOURCE_DIR}/libvncserver" ]; then
    git clone https://github.com/LibVNC/libvncserver.git "${SOURCE_DIR}/libvncserver"
fi

if [ ! -d "${SOURCE_DIR}/zlib" ]; then
    git clone https://github.com/madler/zlib.git "${SOURCE_DIR}/zlib"
fi

if [ ! -d "${SOURCE_DIR}/openssl" ]; then
    echo "正在克隆 OpenSSL (${OPENSSL_VERSION})..."
    git clone --depth 1 --branch "${OPENSSL_VERSION}" https://github.com/openssl/openssl.git "${SOURCE_DIR}/openssl"
fi

if [ ! -d "${SOURCE_DIR}/jpeg" ]; then
    git clone https://github.com/libjpeg-turbo/libjpeg-turbo.git "${SOURCE_DIR}/jpeg"
fi

if [ ! -d "${SOURCE_DIR}/png" ]; then
    git clone https://github.com/pnggroup/libpng.git "${SOURCE_DIR}/png"
fi



# ================= 2. 编译依赖库 (单架构基础函数) =================
compile_deps_single_arch() {
    local target_id=$1
    local arch=$2
    local sysroot=$3
    local min_flag=$4

    local install_prefix="${DEPS_DIR}/${target_id}"
    mkdir -p "${install_prefix}"

    echo "---> 编译依赖库 [${target_id}]..."

    # 1. Zlib
    if [ ! -f "${install_prefix}/lib/libz.a" ]; then
        local bdir="${BUILD_DIR}/deps_build/${target_id}/zlib"
        cmake -B "${bdir}" -S "${SOURCE_DIR}/zlib" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
            -DCMAKE_OSX_SYSROOT="${sysroot}" \
            -DCMAKE_OSX_ARCHITECTURES="${arch}" \
            -DCMAKE_C_FLAGS="${min_flag}" \
            -DBUILD_SHARED_LIBS=OFF
        cmake --build "${bdir}" --target install
    fi

    # 2. Libjpeg-turbo
    if [ ! -f "${install_prefix}/lib/libjpeg.a" ]; then
        local bdir="${BUILD_DIR}/deps_build/${target_id}/jpeg"
        cmake -B "${bdir}" -S "${SOURCE_DIR}/jpeg" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
            -DCMAKE_OSX_ARCHITECTURES="${arch}" \
            -DCMAKE_C_FLAGS="${min_flag}" \
            -DENABLE_SHARED=OFF \
            -DWITH_SIMD=OFF
        cmake --build "${bdir}" --target install
    fi

    # 3. Libpng
    if [ ! -f "${install_prefix}/lib/libpng.a" ]; then
        local bdir="${BUILD_DIR}/deps_build/${target_id}/png"
        cmake -B "${bdir}" -S "${SOURCE_DIR}/png" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
            -DCMAKE_OSX_SYSROOT="${sysroot}" \
            -DCMAKE_OSX_ARCHITECTURES="${arch}" \
            -DCMAKE_C_FLAGS="${min_flag} -I${install_prefix}/include" \
            -DPNG_SHARED=OFF \
            -DPNG_TESTS=OFF \
            -DPNG_ARM_NEON=off \
            -DZLIB_INCLUDE_DIR="${install_prefix}/include" \
            -DZLIB_LIBRARY="${install_prefix}/lib/libz.a"
        cmake --build "${bdir}" --target install
    fi

    # 4. OpenSSL
    if [ ! -f "${install_prefix}/lib/libssl.a" ]; then
        local sdk_path=$(xcrun --sdk ${sysroot} --show-sdk-path)
        local src_copy="${BUILD_DIR}/deps_build/${target_id}/openssl_src"
        mkdir -p "${src_copy}"
        cp -R "${SOURCE_DIR}/openssl/" "${src_copy}"

        pushd "${src_copy}" > /dev/null
        local os_compiler=""
        case ${target_id} in
            "macos-arm64")       os_compiler="darwin64-arm64-cc" ;;
            "macos-x86_64")      os_compiler="darwin64-x86_64-cc" ;;
            "ios-arm64")         os_compiler="ios64-cross" ;;
            "ios-sim-arm64")     os_compiler="iossimulator-arm64-xcrun" ;;
        esac

        export CFLAGS="${min_flag} -isysroot ${sdk_path}"
        ./Configure ${os_compiler} no-shared no-async no-tests --prefix="${install_prefix}"
        make -j$(sysctl -n hw.ncpu) build_libs
        make install_dev
        popd > /dev/null
    fi

}

echo "==> [2/4] 构建各架构依赖库..."
compile_deps_single_arch "macos-arm64" "arm64" "macosx" "-mmacosx-version-min=${MACOS_TARGET}"
compile_deps_single_arch "macos-x86_64" "x86_64" "macosx" "-mmacosx-version-min=${MACOS_TARGET}"

compile_deps_single_arch "ios-arm64" "arm64" "iphoneos" "-miphoneos-version-min=${IOS_TARGET}"
compile_deps_single_arch "ios-sim-arm64" "arm64" "iphonesimulator" "-mios-simulator-version-min=${IOS_TARGET}"

# ================= 3. 编译 LibVNCClient 并合并静态库 =================
compile_libvnc_single_arch() {
    local target_id=$1
    local arch=$2
    local sysroot=$3
    local min_flag=$4

    local deps="${DEPS_DIR}/${target_id}"
    local bdir="${BUILD_DIR}/vnc_${target_id}"
    local target_out="${BUILD_DIR}/packaged_${target_id}"

    mkdir -p "${target_out}"

    echo "---> 编译 LibVNCClient [${target_id}]..."

    cmake -B "${bdir}" -S "${SOURCE_DIR}/libvncserver" -G Ninja \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_SYSROOT="${sysroot}" \
        -DCMAKE_OSX_ARCHITECTURES="${arch}" \
        -DCMAKE_C_FLAGS="${min_flag} -I${deps}/include" \
        -DCMAKE_EXE_LINKER_FLAGS="-L${deps}/lib" \
        -DBUILD_SHARED_LIBS=OFF \
        -DWITH_LIBVNCSERVER=OFF \
        -DWITH_LIBVNCCLIENT=ON \
        -DWITH_ZLIB=ON \
        -DZLIB_INCLUDE_DIR="${deps}/include" \
        -DZLIB_LIBRARY="${deps}/lib/libz.a" \
        -DWITH_LZO=OFF \
        -DWITH_JPEG=ON \
        -DJPEG_INCLUDE_DIR="${deps}/include" \
        -DJPEG_LIBRARY="${deps}/lib/libjpeg.a" \
        -DWITH_PNG=ON \
        -DPNG_PNG_INCLUDE_DIR="${deps}/include" \
        -DPNG_LIBRARY="${deps}/lib/libpng.a" \
        -DWITH_OPENSSL=ON \
        -DOPENSSL_INCLUDE_DIR="${deps}/include" \
        -DOPENSSL_CRYPTO_LIBRARY="${deps}/lib/libcrypto.a" \
        -DOPENSSL_SSL_LIBRARY="${deps}/lib/libssl.a" \
        -DWITH_SASL=ON \
        -DWITH_TIGHTVNC_FILETRANSFER=ON \
        -DWITH_WEBSOCKETS=ON \
        -DWITH_24BPP=ON \
        -DWITH_1BPP=ON \
        -DWITH_2BPP=ON \
        -DWITH_4BPP=ON \
        -DWITH_IPv6=ON \
        -DWITH_THREADS=ON \
        -DWITH_GCRYPT=OFF \
        -DWITH_GNUTLS=OFF \
        -DWITH_EXAMPLES=OFF \
        -DWITH_TESTS=OFF \
        -DWITH_SDL=OFF \
        -DWITH_GTK=OFF \
        -DWITH_QT=OFF

    cmake --build "${bdir}" --target vncclient

    libtool -static -o "${target_out}/libvncclient.a" \
        "${bdir}/libvncclient.a" \
        "${deps}/lib/libjpeg.a" \
        "${deps}/lib/libpng.a"
}

echo "==> [3/4] 编译各架构 LibVNCClient 并合并依赖..."
compile_libvnc_single_arch "macos-arm64" "arm64" "macosx" "-mmacosx-version-min=${MACOS_TARGET}"
compile_libvnc_single_arch "macos-x86_64" "x86_64" "macosx" "-mmacosx-version-min=${MACOS_TARGET}"

compile_libvnc_single_arch "ios-arm64" "arm64" "iphoneos" "-miphoneos-version-min=${IOS_TARGET}"
compile_libvnc_single_arch "ios-sim-arm64" "arm64" "iphonesimulator" "-mios-simulator-version-min=${IOS_TARGET}"

echo "---> 打包各 Platform 静态库..."
mkdir -p "${BUILD_DIR}/packaged_macos" "${BUILD_DIR}/packaged_ios-simulator" "${BUILD_DIR}/packaged_ios"

lipo -create \
    "${BUILD_DIR}/packaged_macos-arm64/libvncclient.a" \
    "${BUILD_DIR}/packaged_macos-x86_64/libvncclient.a" \
    -output "${BUILD_DIR}/packaged_macos/libvncclient.a"

cp "${BUILD_DIR}/packaged_ios-sim-arm64/libvncclient.a" "${BUILD_DIR}/packaged_ios-simulator/libvncclient.a"
cp "${BUILD_DIR}/packaged_ios-arm64/libvncclient.a" "${BUILD_DIR}/packaged_ios/libvncclient.a"

# ================= 4. 构建 Headers 及最终 XCFramework =================
echo "==> [4/4] 打包生成 XCFramework..."
HEADERS_ROOT="${BUILD_DIR}/Headers"
HEADERS_DIR="${BUILD_DIR}/Headers/rfb"
mkdir -p "${HEADERS_DIR}"

cp ${SOURCE_DIR}/libvncserver/include/rfb/keysym.h "${HEADERS_DIR}/"
cp ${SOURCE_DIR}/libvncserver/include/rfb/threading.h "${HEADERS_DIR}/"
cp ${SOURCE_DIR}/libvncserver/include/rfb/rfbproto.h "${HEADERS_DIR}/"
cp ${SOURCE_DIR}/libvncserver/include/rfb/rfbregion.h "${HEADERS_DIR}/"
cp ${SOURCE_DIR}/libvncserver/include/rfb/rfbclient.h "${HEADERS_DIR}/"
cp ${BUILD_DIR}/vnc_macos-arm64/include/rfb/rfbconfig.h "${HEADERS_DIR}/"

cat << 'EOF' > "${HEADERS_ROOT}/libvncclient.h"
#ifndef LIBVNCCLIENT_UMBRELLA_H
#define LIBVNCCLIENT_UMBRELLA_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>

#include "rfb/rfbclient.h"
#include "rfb/rfbproto.h"
#include "rfb/rfbregion.h"
#include "rfb/keysym.h"
#include "rfb/threading.h"
#include "rfb/rfbconfig.h"

#endif
EOF

cat << 'EOF' > "${HEADERS_ROOT}/module.modulemap"
module libvncclient {
    umbrella header "libvncclient.h"
    export *
}
EOF

rm -rf "${OUTPUT_DIR}/libvncclient.xcframework"

xcodebuild -create-xcframework \
    -library "${BUILD_DIR}/packaged_macos/libvncclient.a" -headers "${BUILD_DIR}/Headers" \
    -library "${BUILD_DIR}/packaged_ios/libvncclient.a" -headers "${BUILD_DIR}/Headers" \
    -library "${BUILD_DIR}/packaged_ios-simulator/libvncclient.a" -headers "${BUILD_DIR}/Headers" \
    -output "${OUTPUT_DIR}/libvncclient.xcframework"

echo "=========================================="
echo "完成！已成功构建包含 SASL 功能的 XCFramework"
echo "输出文件: ${OUTPUT_DIR}/libvncclient.xcframework"
echo "=========================================="
