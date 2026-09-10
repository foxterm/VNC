#!/bin/bash

set -e

export GIT_ADVICE_DETACHED_HEAD=false

# ================= 配置区 =================
LIBVNC_TAG="LibVNCServer-0.9.15"
OPENSSL_VERSION="3.6.3"
ZLIB_VERSION="1.3.1"
LZO_VERSION="2.10"
JPEG_TURBO_VERSION="3.0.2"
LIBPNG_VERSION="1.6.43"

MACOS_TARGET="14.0"
IOS_TARGET="16.0"

WORK_DIR="$(pwd)/xcframework_build"
SOURCE_DIR="${WORK_DIR}/sources"
DEPS_DIR="${WORK_DIR}/deps"
BUILD_DIR="${WORK_DIR}/build"
OUTPUT_DIR="$(pwd)/xcframework"

mkdir -p "${SOURCE_DIR}" "${DEPS_DIR}" "${BUILD_DIR}" "${OUTPUT_DIR}"

# 依赖检查
for cmd in cmake ninja git curl tar xcodebuild libtool nasm lipo; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd 未安装，请先安装 (例: brew install cmake ninja nasm)"
        exit 1
    fi
done

# ================= 1. 源码下载 =================
echo "==> [1/4] 下载官方源码..."

# if [ ! -d "${SOURCE_DIR}/libvncserver" ]; then
#     git -c advice.detachedHead=false clone --branch ${LIBVNC_TAG} --depth 1 https://github.com/LibVNC/libvncserver.git "${SOURCE_DIR}/libvncserver"
# fi
if [ ! -d "${SOURCE_DIR}/libvncserver" ]; then
    git clone https://github.com/LibVNC/libvncserver.git "${SOURCE_DIR}/libvncserver"
fi

if [ ! -d "${SOURCE_DIR}/zlib" ]; then
    curl -sSL "https://github.com/madler/zlib/archive/refs/tags/v${ZLIB_VERSION}.tar.gz" | tar -xz -C "${SOURCE_DIR}"
    mv "${SOURCE_DIR}/zlib-${ZLIB_VERSION}" "${SOURCE_DIR}/zlib"
fi

if [ ! -d "${SOURCE_DIR}/openssl" ]; then
    curl -sSL "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" | tar -xz -C "${SOURCE_DIR}" || \
    curl -sSL "https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz" | tar -xz -C "${SOURCE_DIR}"
    mv "${SOURCE_DIR}/openssl-${OPENSSL_VERSION}" "${SOURCE_DIR}/openssl"
fi

if [ ! -d "${SOURCE_DIR}/lzo" ]; then
    curl -sSL "https://www.oberhumer.com/opensource/lzo/download/lzo-${LZO_VERSION}.tar.gz" | tar -xz -C "${SOURCE_DIR}"
    mv "${SOURCE_DIR}/lzo-${LZO_VERSION}" "${SOURCE_DIR}/lzo"
fi

if [ ! -d "${SOURCE_DIR}/jpeg" ]; then
    curl -sSL "https://github.com/libjpeg-turbo/libjpeg-turbo/archive/refs/tags/${JPEG_TURBO_VERSION}.tar.gz" | tar -xz -C "${SOURCE_DIR}"
    mv "${SOURCE_DIR}/libjpeg-turbo-${JPEG_TURBO_VERSION}" "${SOURCE_DIR}/jpeg"
fi

if [ ! -d "${SOURCE_DIR}/png" ]; then
    curl -sSL "https://downloads.sourceforge.net/project/libpng/libpng16/${LIBPNG_VERSION}/libpng-${LIBPNG_VERSION}.tar.gz" | tar -xz -C "${SOURCE_DIR}"
    mv "${SOURCE_DIR}/libpng-${LIBPNG_VERSION}" "${SOURCE_DIR}/png"
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

    # 2. LZO
    if [ ! -f "${install_prefix}/lib/liblzo2.a" ]; then
        local bdir="${BUILD_DIR}/deps_build/${target_id}/lzo"
        cmake -B "${bdir}" -S "${SOURCE_DIR}/lzo" -G Ninja \
            -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
            -DCMAKE_OSX_SYSROOT="${sysroot}" \
            -DCMAKE_OSX_ARCHITECTURES="${arch}" \
            -DCMAKE_C_FLAGS="${min_flag}" \
            -DENABLE_SHARED=OFF
        cmake --build "${bdir}" --target install
    fi

    # 3. Libjpeg-turbo
    if [ ! -f "${install_prefix}/lib/libjpeg.a" ]; then
        local bdir="${BUILD_DIR}/deps_build/${target_id}/jpeg"
        cmake -B "${bdir}" -S "${SOURCE_DIR}/jpeg" -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX="${install_prefix}" \
            -DCMAKE_OSX_SYSROOT="${sysroot}" \
            -DCMAKE_OSX_ARCHITECTURES="${arch}" \
            -DCMAKE_C_FLAGS="${min_flag}" \
            -DENABLE_SHARED=OFF \
            -DWITH_SIMD=OFF
        cmake --build "${bdir}" --target install
    fi

    # 4. Libpng
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

    # 5. OpenSSL (仅供 LibVNC 链接编译)
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
        -DWITH_LZO=ON \
        -DLZO_INCLUDE_DIR="${deps}/include" \
        -DLZO_LIBRARIES="${deps}/lib/liblzo2.a" \
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
        -DWITH_WEBSOCKETS=ON \
        -DWITH_24BPP=ON \
        -DWITH_IPv6=ON \
        -DWITH_THREADS=ON \
        -DWITH_SASL=OFF \
        -DWITH_GCRYPT=OFF \
        -DWITH_GNUTLS=OFF \
        -DWITH_EXAMPLES=OFF \
        -DWITH_TESTS=OFF \
        -DWITH_SDL=OFF \
        -DWITH_GTK=OFF \
        -DWITH_QT=OFF

    cmake --build "${bdir}" --target vncclient

    libtool -static -o "${target_out}/libvncclient.a" "${bdir}/libvncclient.a" "${deps}/lib/liblzo2.a" "${deps}/lib/libjpeg.a" "${deps}/lib/libpng.a"
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

# 生成顶层包装头文件，提前引入基础 C 标准库
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

# 修改 module.modulemap 结构
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
echo "完成！已成功构建 XCFramework"
echo "输出文件: ${OUTPUT_DIR}/libvncclient.xcframework"
echo "=========================================="
