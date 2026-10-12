# Shared iOS cross-compilation environment (Linux host, clang + iOS SDK).
# Source this file from the build-*.sh scripts under deps/scripts/.
#
# Everything is cross-compiled against the Theos iPhoneOS SDK, targeting
# arm64 iOS ${IOS_MIN_VERSION}+. Uses clang + the Mach-O flavored lld
# (ld64.lld) and the LLVM binutils (llvm-nm especially: FFmpeg reads the
# symbol prefix from a probe object, which GNU nm cannot parse from Mach-O).
export IOS_SDK_VERSION="${IOS_SDK_VERSION:-16.5}"
export IOS_MIN_VERSION="${IOS_MIN_VERSION:-15.0}"
export IOS_ARCH="${IOS_ARCH:-arm64}"

# Newest SDK whose .tbd files LLVM's ld64.lld can parse on this host.
export SDKROOT="/opt/theos/sdks/iPhoneOS${IOS_SDK_VERSION}.sdk"

# Mach-O toolchain.
export IOS_TRIPLE="arm64-apple-ios${IOS_MIN_VERSION}"
export CC="clang --target=${IOS_TRIPLE} -isysroot ${SDKROOT}"
export CXX="clang++ --target=${IOS_TRIPLE} -isysroot ${SDKROOT}"
export CPP="clang --target=${IOS_TRIPLE} -isysroot ${SDKROOT} -E"
export AR="llvm-ar-22"
export RANLIB="llvm-ranlib-22"
export NM="llvm-nm-22"
export STRIP="llvm-strip-22"

export CFLAGS="-O2 -fPIC -DNDEBUG"
export CXXFLAGS="-O2 -fPIC -DNDEBUG"
export LDFLAGS="-isysroot ${SDKROOT} -fuse-ld=ld64.lld -Wl,-platform_version,ios,${IOS_MIN_VERSION},${IOS_MIN_VERSION}"