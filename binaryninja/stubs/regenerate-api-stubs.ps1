# Copyright 2011-2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Updates the Binary Ninja API stub file

# Exit on error
$ErrorActionPreference = "Stop"

function canonical_path {
    param (
        [string]$file
    )
    $limit = 0
    while ((Test-Path -Path $file -PathType Leaf) -and ($limit -lt 1000)) {
        $file = (Get-Item $file).Target
        $limit++
    }
    return (Resolve-Path -Path $file).Path
}

$SCRIPT = "${pwd}\regenerate-api-stubs.ps1"
$SCRIPT_DIR = "${pwd}"

if (-not $args[0]) {
    Write-Host "usage: ${SCRIPT} PATH_TO_BINARYNINJA_API"
    exit 1
}

$BINARYNINJA_API_SRC = canonical_path $args[0]

Set-Location -Path $SCRIPT_DIR

$scriptContent = @"
`
#include <cstdint>
#include <cstddef>

// clang-format off
#include "exceptions.h"  // NOLINT
#define BINARYNINJACORE_LIBRARY
#include "binaryninjacore.h"  // NOLINT
// clang-format on

extern "C" {
"@

$binaryCoreHeader = Get-Content -Path "${BINARYNINJA_API_SRC}\binaryninjacore.h" |
    Select-String -NotMatch '^\s*__attribute__' |
    ForEach-Object { $_.Line -replace '//.*$' } |
    ForEach-Object { $_ -replace 'void\n', 'void' } |
    clang-format --style='{BasedOnStyle: Google, Language: Cpp, ColumnLimit: 100000}' |
    Select-String '^BINARYNINJACOREAPI' |
    ForEach-Object {
        $_.Line -replace '(BINARYNINJACOREAPI void .*)\;', '$1 {}' -replace '(BINARYNINJACOREAPI .*)\;', '$1 { return {}; }'
    }

$footerContent = @"
}  // extern "C"
"@

$finalContent = $scriptContent + $binaryCoreHeader + $footerContent
$finalContent | clang-format --style=Google | Set-Content -Path "binaryninjacore.cc"


$func = Get-Content "${BINARYNINJA_API_SRC}\function.cpp" 
$func | foreach { $_ -replace '#include <cstring>', '#include <cstring>`n#define WIN32`n#include <windows.h>`n#define GetObject GetObject'} | Set-Content -Path "${BINARYNINJA_API_SRC}\function.cpp"