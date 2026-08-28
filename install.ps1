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
} else {
    Write-Host "[ERROR] Python 3 is required. Please install Python from https://www.python.org/ or Microsoft Store." -ForegroundColor Red
    exit 1
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
