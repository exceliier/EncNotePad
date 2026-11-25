<#
.SYNOPSIS
    Builds the Flutter Windows Release executable and packages it into a production .msi installer using WiX Toolset v4.

.DESCRIPTION
    Automates the full build lifecycle for EncNotePad:
    1. Validates required build tools (Flutter, WiX Toolset / .NET CLI).
    2. Runs test suite to verify code integrity.
    3. Compiles the release Windows desktop executable via 'flutter build windows --release'.
    4. Packages the binaries, assets, shortcuts, and .enp file associations into an MSI installer.

.PARAMETER SkipTests
    Skips running automated unit tests before building.

.PARAMETER SkipFlutterBuild
    Skips the 'flutter build windows --release' step if the release binaries are already built.

.EXAMPLE
    .\build_msi.ps1
    .\build_msi.ps1 -SkipTests
#>

[CmdletBinding()]
param (
    [switch]$SkipTests,
    [switch]$SkipFlutterBuild
)

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "`n[+] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

Clear-Host
Write-Host "==========================================================" -ForegroundColor DarkCyan
Write-Host "       EncNotePad - Windows MSI Installer Builder        " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor DarkCyan

# 1. Resolve Project Paths
$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path "$RootDir\encnotepad\pubspec.yaml")) {
    if (Test-Path "$RootDir\pubspec.yaml") {
        $RootDir = Split-Path -Parent $RootDir
    } else {
        Write-ErrMsg "Could not locate encnotepad project directory from: $RootDir"
        exit 1
    }
}

$FlutterDir = Join-Path $RootDir "encnotepad"
$InstallerDir = Join-Path $RootDir "installer"
$WxsFile = Join-Path $InstallerDir "Package.wxs"
$ReleaseExe = Join-Path $FlutterDir "build\windows\x64\runner\Release\encnotepad.exe"
$OutputMsi = Join-Path $RootDir "EncNotePad-v1.0.0.msi"

Write-Host "Root Directory    : $RootDir"
Write-Host "Flutter App Dir   : $FlutterDir"
Write-Host "WiX Manifest      : $WxsFile"
Write-Host "Target MSI Output : $OutputMsi"

# 2. Check Flutter Tooling
Write-Step "Checking build prerequisites..."

$FlutterCmd = Get-Command "flutter" -ErrorAction SilentlyContinue
if (-not $FlutterCmd) {
    # Check default tools folder if not in PATH
    if (Test-Path "D:\tools\flutter\bin\flutter.bat") {
        $FlutterExe = "D:\tools\flutter\bin\flutter.bat"
    } else {
        Write-ErrMsg "Flutter SDK was not found in PATH. Please install Flutter or add it to PATH."
        exit 1
    }
} else {
    $FlutterExe = $FlutterCmd.Source
}
Write-Success "Found Flutter: $FlutterExe"

# 3. Check WiX Toolset Tooling
$WixExe = Get-Command "wix" -ErrorAction SilentlyContinue
if (-not $WixExe) {
    $DotnetWixPath = "$env:USERPROFILE\.dotnet\tools\wix.exe"
    if (Test-Path $DotnetWixPath) {
        $WixTool = $DotnetWixPath
    } else {
        $DotnetCmd = Get-Command "dotnet" -ErrorAction SilentlyContinue
        if ($DotnetCmd) {
            Write-WarnMsg "WiX Toolset CLI not found. Attempting to install via dotnet..."
            & dotnet tool install --global wix
            if (Test-Path $DotnetWixPath) {
                $WixTool = $DotnetWixPath
            } else {
                Write-ErrMsg "Failed to install WiX Toolset v4. Run 'dotnet tool install --global wix' manually."
                exit 1
            }
        } else {
            Write-ErrMsg "Neither 'wix' nor 'dotnet' was found. Please install WiX Toolset v4 or .NET SDK."
            exit 1
        }
    }
} else {
    $WixTool = $WixExe.Source
}
Write-Success "Found WiX Toolset: $WixTool"

# Automatically accept WiX v7+ EULA if needed
try {
    & $WixTool eula accept wix7 2>$null | Out-Null
} catch {}

# 4. Optional: Run Automated Tests
if (-not $SkipTests) {
    Write-Step "Running automated test suite..."
    Push-Location $FlutterDir
    try {
        & $FlutterExe test
        if ($LASTEXITCODE -ne 0) {
            Write-ErrMsg "Unit tests failed! Resolve test failures before building or pass -SkipTests."
            exit 1
        }
        Write-Success "All unit tests passed successfully."
    } finally {
        Pop-Location
    }
} else {
    Write-WarnMsg "Skipping tests as requested (-SkipTests)."
}

# 5. Build Flutter Windows Release
if (-not $SkipFlutterBuild) {
    Write-Step "Compiling Flutter Windows Release binary (C++ Runner & Engine)..."
    Push-Location $FlutterDir
    try {
        & $FlutterExe build windows --release
        if ($LASTEXITCODE -ne 0) {
            Write-ErrMsg "Flutter Windows build failed!"
            exit 1
        }
    } finally {
        Pop-Location
    }
} else {
    Write-WarnMsg "Skipping Flutter build as requested (-SkipFlutterBuild)."
}

if (-not (Test-Path $ReleaseExe)) {
    Write-ErrMsg "Release binary was not found at: $ReleaseExe"
    exit 1
}
Write-Success "Flutter Release executable verified: $ReleaseExe"

# 6. Ensure Unified Redistributable DLLs (Auto-populated if missing)
$RedistDir = Join-Path $InstallerDir "redist_x64"
if (-not (Test-Path "$RedistDir\ucrtbase.dll") -or -not (Test-Path "$RedistDir\api-ms-win-core-path-l1-1-0.dll")) {
    Write-Step "Auto-populating unified redistributable DLLs for Windows 8.1 / 10 / 11..."
    if (-not (Test-Path $RedistDir)) {
        New-Item -ItemType Directory -Path $RedistDir -Force | Out-Null
    }

    # 1. Copy VC++ Runtime & d3dcompiler
    $MsvcBin = Get-ChildItem -Path "C:\Program Files\Microsoft Visual Studio\2022\*\VC\Tools\MSVC\*\bin\Hostx64\x64" -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($MsvcBin) {
        $vcDlls = @("msvcp140.dll", "msvcp140_1.dll", "msvcp140_2.dll", "msvcp140_atomic_wait.dll", "msvcp140_codecvt_ids.dll", "vcruntime140.dll", "vcruntime140_1.dll", "vcruntime140_threads.dll", "d3dcompiler_47.dll")
        foreach ($dll in $vcDlls) {
            $src = Join-Path $MsvcBin.FullName $dll
            if (Test-Path $src) {
                Copy-Item -Path $src -Destination $RedistDir -Force
            }
        }
    }

    # 2. Copy UCRT DLLs
    $UcrtDirs = Get-ChildItem -Path "C:\Program Files (x86)\Windows Kits\10\Redist\*\ucrt\DLLs\x64" -ErrorAction SilentlyContinue
    if (-not $UcrtDirs) {
        $UcrtDirs = Get-ChildItem -Path "C:\Program Files (x86)\Windows Kits\10\Redist\ucrt\DLLs\x64" -ErrorAction SilentlyContinue
    }
    if ($UcrtDirs) {
        $targetUcrt = $UcrtDirs | Select-Object -Last 1
        Get-ChildItem -Path $targetUcrt.FullName -Filter "*.dll" | ForEach-Object {
            Copy-Item -Path $_.FullName -Destination $RedistDir -Force
        }
    }

    # 3. Compile the api-ms-win-core-path forwarder for Windows 8.1 if missing
    $shimDll = Join-Path $RedistDir "api-ms-win-core-path-l1-1-0.dll"
    if (-not (Test-Path $shimDll) -and $MsvcBin) {
        $clExe = Join-Path $MsvcBin.FullName "cl.exe"
        if (Test-Path $clExe) {
            $shimSrc = @"
#pragma comment(linker, "/export:PathAllocCanonicalize=KERNELBASE.PathAllocCanonicalize")
#pragma comment(linker, "/export:PathAllocCombine=KERNELBASE.PathAllocCombine")
#pragma comment(linker, "/export:PathCchAddBackslash=KERNELBASE.PathCchAddBackslash")
#pragma comment(linker, "/export:PathCchAddBackslashEx=KERNELBASE.PathCchAddBackslashEx")
#pragma comment(linker, "/export:PathCchAddExtension=KERNELBASE.PathCchAddExtension")
#pragma comment(linker, "/export:PathCchAppend=KERNELBASE.PathCchAppend")
#pragma comment(linker, "/export:PathCchAppendEx=KERNELBASE.PathCchAppendEx")
#pragma comment(linker, "/export:PathCchCanonicalize=KERNELBASE.PathCchCanonicalize")
#pragma comment(linker, "/export:PathCchCanonicalizeEx=KERNELBASE.PathCchCanonicalizeEx")
#pragma comment(linker, "/export:PathCchCombine=KERNELBASE.PathCchCombine")
#pragma comment(linker, "/export:PathCchCombineEx=KERNELBASE.PathCchCombineEx")
#pragma comment(linker, "/export:PathCchFindExtension=KERNELBASE.PathCchFindExtension")
#pragma comment(linker, "/export:PathCchIsRoot=KERNELBASE.PathCchIsRoot")
#pragma comment(linker, "/export:PathCchRemoveBackslash=KERNELBASE.PathCchRemoveBackslash")
#pragma comment(linker, "/export:PathCchRemoveBackslashEx=KERNELBASE.PathCchRemoveBackslashEx")
#pragma comment(linker, "/export:PathCchRemoveExtension=KERNELBASE.PathCchRemoveExtension")
#pragma comment(linker, "/export:PathCchRemoveFileSpec=KERNELBASE.PathCchRemoveFileSpec")
#pragma comment(linker, "/export:PathCchRenameExtension=KERNELBASE.PathCchRenameExtension")
#pragma comment(linker, "/export:PathCchSkipRoot=KERNELBASE.PathCchSkipRoot")
#pragma comment(linker, "/export:PathCchStripPrefix=KERNELBASE.PathCchStripPrefix")
#pragma comment(linker, "/export:PathCchStripToRoot=KERNELBASE.PathCchStripToRoot")

int __stdcall _DllMainCRTStartup(void* hinstDLL, unsigned long fdwReason, void* lpvReserved) {
    return 1;
}
"@
            $tempC = Join-Path $InstallerDir "path_shim_temp.c"
            $shimSrc | Out-File -FilePath $tempC -Encoding ascii
            & $clExe /LD /O2 $tempC /link /NODEFAULTLIB /ENTRY:_DllMainCRTStartup /out:$shimDll | Out-Null
            Remove-Item $tempC, "$InstallerDir\path_shim_temp.*" -ErrorAction SilentlyContinue
        }
    }
}
Write-Success "Redistributable DLLs verified in: $RedistDir ($((Get-ChildItem -Path $RedistDir).Count) files)"

# 7. Build MSI Package using WiX v4
Write-Step "Building Windows MSI Installer package using WiX Toolset v4..."

if (-not (Test-Path $WxsFile)) {
    Write-ErrMsg "WiX manifest file not found at: $WxsFile"
    exit 1
}

Push-Location $InstallerDir
try {
    # Delete existing MSI if present to guarantee a fresh artifact
    if (Test-Path $OutputMsi) {
        Remove-Item $OutputMsi -Force
    }

    & $WixTool build "Package.wxs" -o "$OutputMsi"
    if ($LASTEXITCODE -ne 0) {
        Write-ErrMsg "WiX MSI packaging failed!"
        exit 1
    }
} finally {
    Pop-Location
}

# 7. Verification and Summary
if (Test-Path $OutputMsi) {
    $MsiItem = Get-Item $OutputMsi
    $SizeMB = [math]::Round($MsiItem.Length / 1MB, 2)
    Write-Host "`n==========================================================" -ForegroundColor Green
    Write-Host "       BUILD SUCCESSFUL! MSI INSTALLER CREATED           " -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "MSI Package  : $($MsiItem.FullName)" -ForegroundColor White
    Write-Host "File Size    : $SizeMB MB ($($MsiItem.Length) bytes)" -ForegroundColor White
    Write-Host "Modified At  : $($MsiItem.LastWriteTime)" -ForegroundColor White
    Write-Host "`nYou can now double-click the .msi file to install EncNotePad." -ForegroundColor Cyan
} else {
    Write-ErrMsg "Build completed but target MSI was not found at: $OutputMsi"
    exit 1
}
