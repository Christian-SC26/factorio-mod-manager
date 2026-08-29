# Factorio Mod Manager (FMM) Windows Installer
$ErrorActionPreference = "Stop"
$InstallDir = "$env:LOCALAPPDATA\factorio-mod-manager"
$BinDir = "$env:USERPROFILE\.local\bin"
$RepoZipUrl = "https://github.com/Christian-SC26/factorio-mod-manager/archive/refs/heads/main.zip"

Write-Host "==> Installing Factorio Mod Manager (FMM)..." -ForegroundColor Cyan

# Check Python 3
$PythonCmd = $null
if (Get-Command "python" -ErrorAction SilentlyContinue) {
    $PythonCmd = "python"
} elseif (Get-Command "python3" -ErrorAction SilentlyContinue) {
    $PythonCmd = "python3"
} elseif (Get-Command "py" -ErrorAction SilentlyContinue) {
    $PythonCmd = "py -3"
} else {
    # Attempt automatic installation via Windows Package Manager (winget)
    if (Get-Command "winget" -ErrorAction SilentlyContinue) {
        Write-Host "==> Python 3 not detected. Installing Python automatically via winget..." -ForegroundColor Yellow
        try {
            winget install Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            if (Get-Command "python" -ErrorAction SilentlyContinue) {
                $PythonCmd = "python"
            } elseif (Get-Command "py" -ErrorAction SilentlyContinue) {
                $PythonCmd = "py -3"
            }
        } catch {
            Write-Host "[WARNING] Automatic Python installation via winget failed." -ForegroundColor Yellow
        }
    }

    if (-not $PythonCmd) {
        Write-Host "`n[ERROR] Python 3 is required to run FMM scripts." -ForegroundColor Red
        Write-Host "Options to install:"
        Write-Host "  1) Install from Microsoft Store (search 'Python 3.12')" -ForegroundColor Cyan
        Write-Host "  2) Download installer from https://www.python.org/downloads/" -ForegroundColor Cyan
        Write-Host "  3) Or download standalone fmm.exe from GitHub Releases" -ForegroundColor Cyan
        exit 1
    }
}

# Create Directories
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $BinDir | Out-Null

# Download and Extract Archive
Write-Host "==> Downloading repository..." -ForegroundColor Cyan
$ZipPath = "$env:TEMP\fmm-main.zip"
$ExtractPath = "$env:TEMP\fmm-extracted"

Invoke-WebRequest -Uri $RepoZipUrl -OutFile $ZipPath -UseBasicParsing
if (Test-Path $ExtractPath) {
    Remove-Item -Path $ExtractPath -Recurse -Force
}
Expand-Archive -Path $ZipPath -DestinationPath $ExtractPath -Force
Copy-Item -Path "$ExtractPath\factorio-mod-manager-main\*" -Destination $InstallDir -Recurse -Force
Remove-Item -Path $ZipPath -Force -ErrorAction SilentlyContinue
Remove-Item -Path $ExtractPath -Recurse -Force -ErrorAction SilentlyContinue

# Create CMD wrapper
$CmdContent = "@echo off`r`n$PythonCmd `"$InstallDir\fmm.py`" %*"
Set-Content -Path "$BinDir\fmm.cmd" -Value $CmdContent -Force
Set-Content -Path "$InstallDir\fmm.cmd" -Value $CmdContent -Force

# Add BinDir to User PATH if not present
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinDir", "User")
    $env:PATH += ";$BinDir"
}

Write-Host "`n[OK] Factorio Mod Manager installed successfully!" -ForegroundColor Green
Write-Host "     Location: $InstallDir"
Write-Host "     Command:  $BinDir\fmm.cmd"
Write-Host "`nRun 'fmm' to start (restart your PowerShell/CMD window if the command is not recognized)." -ForegroundColor Cyan
