#!/bin/bash

SCRIPT=$(realpath "$0")
SCRIPTDIR=$(dirname "${SCRIPT}")

UPKIE_DOWNLOAD_URL="https://github.com/upkie/upkie/releases/download"

VERSION=5.1.0

SYSTEM=$(uname -s)
ARCH=$(uname -m)

SPINE_ARGS=()
if [ $# -eq 0 ]; then
    SPINE_ARGS=("--show")
else
    SPINE_ARGS=("$@")
fi

for arg in "$@"; do
    if [ "$arg" == "--build" ]; then
        BUILD=1
        break
    fi
done

if [[ "$SYSTEM" == Darwin ]]; then
    echo "macOS system"
    if [[ "$ARCH" == x86_64* ]]; then
        echo "x86-64 architecture"
        SPINE_ARCHIVE="$UPKIE_DOWNLOAD_URL"/v"$VERSION"/darwin_x86_bullet_spine.tar.gz
    elif [[ "$ARCH" == i*86 ]]; then
        echo "x86-32 architecture"
        SPINE_ARCHIVE="$UPKIE_DOWNLOAD_URL"/v"$VERSION"/darwin_x86_bullet_spine.tar.gz
    elif  [[ "$ARCH" == arm* ]]; then
        echo "ARM architecture"
        SPINE_ARCHIVE="$UPKIE_DOWNLOAD_URL"/v"$VERSION"/darwin_arm64_bullet_spine.tar.gz
    else
        echo "Unsupported architecture $ARCH"
    fi
elif  [[ "$SYSTEM" == Linux ]]; then
    echo "Linux system"
    if [[ "$ARCH" == x86_64* ]]; then
        echo "x86-64 architecture"
        SPINE_ARCHIVE="$UPKIE_DOWNLOAD_URL"/v"$VERSION"/linux_amd64_bullet_spine.tar.gz
    else
        echo "Unsupported architecture: $ARCH"
    fi
else
    echo "Unsupported system: $SYSTEM"
fi

if [[ -n "$SPINE_ARCHIVE" ]] && [[ ! -v BUILD ]]; then
    CURL_TAR_RC=0
    if [ ! -f cache/bullet_spine ]; then
        echo "Downloading the simulation spine from $SPINE_ARCHIVE..."
        mkdir -p cache

        # check that the full operation works - use pipefail as it works for bash/zsh
        (set -o pipefail; curl -s -L "$SPINE_ARCHIVE" | tar -C ./cache/ -zxf -)
        CURL_TAR_RC=$?
    fi

    if [[ $CURL_TAR_RC -eq 0 ]]; then
        echo "Simulation spine downloaded successfully or already in cache, let's roll!"
        cd cache || exit
        OUTPUT=$(./bullet_spine "${SPINE_ARGS[@]}" 2>&1)
        SPINE_RC=$?
        # Return code 0 is from Ctrl-C (normal exit)
        # Return code 1 is from closing the simulation GUI
        if [ $SPINE_RC -eq 1 ]; then
            if echo "$OUTPUT" | grep -q "version.*GLIBC"; then
                echo "It seems your GLIBC version is not compatible with the downloaded binary"
                BUILD=1
            fi
        elif [ $SPINE_RC -ne 0 ] && [ $SPINE_RC -ne 1 ]; then
            echo "Simulation spine exited with code $SPINE_RC"
            echo "If this was unexpected, you can also try \`$0 --build\`"
        fi
    else
        BUILD=1
    fi
fi

if [[ -v BUILD ]]; then
    echo "Building the simulation spine from source..."
    (cd "${SCRIPTDIR}" && "${SCRIPTDIR}"/tools/bazelisk run //spines:bullet_spine -- "${SPINE_ARGS[@]}")
fi
