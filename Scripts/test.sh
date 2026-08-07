#!/bin/zsh

set -euo pipefail

developer_dir=$(xcode-select -p)
testing_frameworks="$developer_dir/Library/Developer/Frameworks"
testing_libraries="$developer_dir/Library/Developer/usr/lib"

test_arguments=(--enable-swift-testing)

if [[ -d "$testing_frameworks/Testing.framework" ]]; then
    test_arguments+=(
        -Xswiftc -F
        -Xswiftc "$testing_frameworks"
        -Xlinker "-F$testing_frameworks"
        -Xlinker -rpath
        -Xlinker "$testing_frameworks"
    )
fi

if [[ -f "$testing_libraries/lib_TestingInterop.dylib" ]]; then
    test_arguments+=(
        -Xlinker -rpath
        -Xlinker "$testing_libraries"
    )
fi

swift test "${test_arguments[@]}"
