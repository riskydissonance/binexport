# cd C:\Users\robjb\Documents\code\github\binexport
# rmdir -recurse -force build_msvc
# mkdir build_msvc
# cd build_msvc
# cmake .. `
#     -G "Visual Studio 17 2022" `
#     -DCMAKE_BUILD_TYPE=Release `
#     "-DCMAKE_INSTALL_PREFIX=${pwd}" `
#     -DBINEXPORT_ENABLE_BINARYNINJA=ON `
#     -DBINEXPORT_ENABLE_IDAPRO=OFF

# cmake --build . --config Release -- /m /clp:NoSummary^;ForceNoAlign /v:minimal
# ctest --build-config Release --output-on-failure
# cmake --install . --config Release --strip

#!/usr/bin/env pwsh

# Note:
# CMake, Clang, clang-format, Ninja, git, and sed are required to build
# Note that currently there is a bug (https://github.com/google/binexport/issues/117)
# that requires applying this patch. Remove when resolved.


$BE_PATH = "C:\users\robjb\Documents\code\github\binexport"
$BN_USER = ''
$BN_PATH = ''
$BINARY_HASH = ''
$PLUGIN_DEST = ''
$PLUGIN_SRC = ''

if (Test-Path -Path "C:\users\robjb\Appdata\Roaming\Binary Ninja\") {
    $BN_USER = "C:\users\robjb\Appdata\Roaming\Binary Ninja\"
    $BN_PATH = Get-Content "$BN_USER\lastrun"
    $BINARY_HASH = Get-Content "$BN_PATH\api_REVISION.txt" | ForEach-Object { $_ -replace '^.*/', '' }
    $CORES = (Get-WmiObject -Class Win32_ComputerSystem).NumberOfLogicalProcessors
    $PLUGIN_DEST = "$BN_USER\plugins\binexport12_binaryninja.dll"
    $PLUGIN_SRC = "$BE_PATH\build\binaryninja\binexport12_binaryninja.dll"
} else {
    Write-Host "Failed to find appropriate Binary Ninja user directory."
    exit 1
}
$BN_API_PATH = $BE_PATH + "\build\_deps\binaryninjaapi-src"

Write-Host "Configuration:"
Write-Host "  DOWNLOADS: $DOWNLOADS"
Write-Host "  BE_PATH: $BE_PATH"
Write-Host "  BN_API_PATH: $BN_API_PATH"
Write-Host "  BN_PATH: $BN_PATH"
Write-Host "  BINARY_HASH: $BINARY_HASH"

if (-not $BINARY_HASH) {
    Write-Host "Failed to find appropriate hash for Binary Ninja"
    exit 1
}

Write-Host "[+] Cloning BinExport & Binary Ninja API..."
if (Test-Path -Path $BE_PATH) {
    Push-Location $BE_PATH
    git fetch --all
    #git reset --hard origin/main  # Because previous runs of this script will dirty the repo
    Write-Host "BinExport exists, repo updated"
    Pop-Location
} else {
    git clone https://github.com/riskydissonance/binexport.git $BE_PATH # TODO change this back to google once they have regenerate-api-stubs.ps1
}

if (-not (Test-Path -Path $BN_API_PATH)) {
    git clone --recursive --branch dev https://github.com/Vector35/binaryninja-api.git $BN_API_PATH
}

Push-Location $BN_API_PATH
if (git fetch --all) {
    if (git checkout "$BINARY_HASH") {
        git pull
        Write-Host "Binary Ninja API exists, repo updated"
    } else {
        Write-Host "Not a repo or could not match binary hash"
        exit
    }
}
Pop-Location

Write-Host "[+] Updating the git hash to $BINARY_HASH"
(Get-Content "$BE_PATH\cmake\BinExportDeps.cmake") -replace '(59e569906828e91e4884670c2bba448702f5a31d|6e2b374dece03f6fb48a1615fa2bfee809ec2157)', $BINARY_HASH -replace '2023-05-18', '2024-09-24' | Set-Content "$BE_PATH\cmake\BinExportDeps.cmake"

Write-Host "[+] Running regenerate-api-stubs..."
Push-Location "$BE_PATH\binaryninja\stubs"
./regenerate-api-stubs.ps1 $BN_API_PATH
Pop-Location

Push-Location $BE_PATH

if ($args.length -ge 1) {
    if ($args[0] -eq '-clean') {
        Write-Host "Cleaning directory"
    	Remove-Item -Recurse -Force -Path build 2>$null
    	New-Item -ItemType Directory -Force -Path build
    }
}

Write-Host "[+] Building BinExport..."
Push-Location build

cmake .. `
    -G "Visual Studio 17 2022" `
    -DCMAKE_BUILD_TYPE=Release `
    "-DCMAKE_INSTALL_PREFIX=${pwd}" `
    -DBINEXPORT_ENABLE_BINARYNINJA=ON `
    -DCMAKE_CXX_FLAGS="-D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION" `
    -DBINEXPORT_BINARYNINJA_CHANNEL=DEV `
    -DBINEXPORT_ENABLE_IDAPRO=OFF

cmake --build . --config Release -- /m /clp:NoSummary`;ForceNoAlign /v:minimal
ctest --build-config Release --output-on-failure
cmake --install . --config Release --strip

Pop-Location

if (Test-Path -Path $PLUGIN_DEST) {
    Write-Host "[+] Not linking the plugin, file already exists"
} else {
    Write-Host "[+] Linking BinExport plugin to Binary Ninja plugin folder"
    New-Item -ItemType SymbolicLink -Path $PLUGIN_DEST -Target $PLUGIN_SRC
}

Write-Host "[+] Done!"
Pop-Location
