#!/bin/bash
#
# SPDX-License-Identifier: Apache-2.0

SCRIPT=$(realpath "$0")
SCRIPT_DIR=$(dirname "${SCRIPT}")
CACHE_DIR=${SCRIPT_DIR}/cache

DOWNLOAD_URL="https://github.com/upkie/upkie/releases/download"
VERSION=13.0.0

SYSTEM=$(uname -s)
ARCH=$(uname -m)

# Arguments are forwarded to the spine, except --build which is ours
SPINE_ARGS=()
for arg in "$@"; do
    if [ "$arg" == "--build" ]; then
        REBUILD=1
    else
        SPINE_ARGS+=("$arg")
    fi
done
if [ ${#SPINE_ARGS[@]} -eq 0 ]; then
    SPINE_ARGS=("--show")
fi

if [[ "$SYSTEM" == Linux ]]; then
    echo "🐧 Linux operating system"
    if [[ "$ARCH" == x86_64* ]]; then
        echo "⚙️  x86 64-bit CPU architecture"
        SPINE_ARCHIVE="$DOWNLOAD_URL"/v"$VERSION"/linux_amd64_bullet_spine.tar.gz
    elif [[ -z "${REBUILD}" ]]; then
        echo "❌ No pre-compiled spine for CPU architecture: $ARCH"
        REBUILD=1
    fi
else
    echo "❌ Unsupported operating system: $SYSTEM"
    exit 1
fi

if [[ -n "$SPINE_ARCHIVE" ]] && [[ -z "${REBUILD}" ]]; then
    if [ -f "${CACHE_DIR}/bullet_spine" ]; then
        OUTPUT=$("${CACHE_DIR}/bullet_spine" --version 2>/dev/null)
        CACHE_RC=$?
        if [ "${CACHE_RC}" -eq 0 ]; then
            CACHE_VERSION=$(echo "${OUTPUT}" | awk '/bullet spine/{print $4}')
            if [ "${CACHE_VERSION}" != "${VERSION}" ]; then
                echo "⚠️ Cached version of the simulation spine (${CACHE_VERSION}) is not ${VERSION}"
                rm -rf "${CACHE_DIR}/bullet_spine" "${CACHE_DIR}/bullet_spine.runfiles"
            fi
        fi
    fi

    CURL_TAR_RC=0
    if [ ! -f "${CACHE_DIR}/bullet_spine" ]; then
        echo "📥 Downloading the simulation spine from $SPINE_ARCHIVE..."
        mkdir -p "${CACHE_DIR}"

        # check that the full operation works - use pipefail as it works for bash/zsh
        (set -o pipefail; curl -s -L "$SPINE_ARCHIVE" | tar -C "${CACHE_DIR}" -zxf -)
        CURL_TAR_RC=$?
    fi

    # The v13.0.0 archive ships a runfiles MANIFEST with absolute paths from
    # the machine that built it. Remove it so that the spine finds its robot
    # descriptions in the runfiles directory instead.
    rm -f "${CACHE_DIR}/bullet_spine.runfiles/MANIFEST"

    if [[ $CURL_TAR_RC -eq 0 ]]; then
        echo "✅ Simulation spine downloaded to cache, let's roll!"
        cd "${CACHE_DIR}" || exit 1
        OUTPUT=$(./bullet_spine "${SPINE_ARGS[@]}" 2>&1)
        SPINE_RC=$?
        # Return code 0 is from Ctrl-C (normal exit)
        # Return code 1 is from closing the simulation GUI
        if [ $SPINE_RC -eq 1 ]; then
            if echo "$OUTPUT" | grep -q "version.*GLIBC"; then
                echo "⚠️ It seems your GLIBC version is not compatible with the downloaded binary"
                REBUILD=1
            else
                echo "❌ Spine exited with the following error:"
                echo "${OUTPUT}"
                exit 1
            fi
        elif [ $SPINE_RC -ne 0 ]; then
            echo "⚠️ Simulation spine exited with code $SPINE_RC"
            echo "${OUTPUT}" | tail -n 20
            echo "If this was unexpected, you can also try \`$0 --build\`"
            exit $SPINE_RC
        fi
    else
        echo "❌ Failed to download the simulation spine"
        REBUILD=1
    fi
fi

if [[ -n "${REBUILD}" ]]; then
    echo "You will need to build the simulation spine from the upkie repository:"
    echo ""
    echo "    git clone https://github.com/upkie/upkie"
    echo "    cd upkie && git checkout v${VERSION}"
    echo "    ./tools/bullet_spine --build"
    echo ""
    exit 1
fi
