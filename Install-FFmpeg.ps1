# PowerShell 7+ Script: Install-FFmpeg.ps1
# Automated FFmpeg installer for Re-Encode AV1 scripts
# Downloads and extracts FFmpeg binaries to the script directory

param(
    [switch]$Force,
    [string]$InstallPath = (Split-Path -Parent $MyInvocation.MyCommand.Path)
)

Write-Host "=== FFmpeg Installer for Re-Encode AV1 ===" -ForegroundColor Cyan
Write-Host "This script will download FFmpeg." -ForegroundColor Green
Write-Host "Installation directory: $InstallPath" -ForegroundColor Yellow
Write-Host ""

# Configuration
$ProgressPreference = 'SilentlyContinue'  # Speeds up downloads
$ffmpegUrl = "https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip"
$downloadPath = Join-Path $env:TEMP "ffmpeg-download.zip"
$extractPath = Join-Path $env:TEMP "ffmpeg-extract"
$ffmpegExe = Join-Path $InstallPath "ffmpeg.exe"
$ffprobeExe = Join-Path $InstallPath "ffprobe.exe"

# Function to check if FFmpeg is already installed
function Test-FFmpegInstalled {
    return (Test-Path $ffmpegExe) -and (Test-Path $ffprobeExe)
}

# Function to get FFmpeg version
function Get-FFmpegVersion {
    param([string]$ffmpegPath)
    
    try {
        $versionOutput = & $ffmpegPath -version 2>$null | Select-Object -First 1
        if ($versionOutput -match "ffmpeg version ([^\s]+)") {
            return $matches[1]
        }
    } catch {
        return "Unknown"
    }
    return "Unknown"
}

# Check if already installed
if (Test-FFmpegInstalled -and -not $Force) {
    $version = Get-FFmpegVersion $ffmpegExe
    
    Write-Host "FFmpeg is already installed!" -ForegroundColor Green
    Write-Host "Version: $version" -ForegroundColor Cyan
    Write-Host "Location: $ffmpegExe" -ForegroundColor Gray
    Write-Host ""
    Write-Host "You can use the script: Re-Encode AV1.ps1" -ForegroundColor White
    
    $continue = Read-Host "Reinstall anyway? [y/N]"
    if ($continue -ne 'y' -and $continue -ne 'Y') {
        Write-Host "Installation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host "Starting FFmpeg download and installation..." -ForegroundColor Green
Write-Host ""

try {
    # Clean up any previous downloads
    if (Test-Path $downloadPath) { Remove-Item $downloadPath -Force }
    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }

    # Download FFmpeg
    Write-Host "Downloading FFmpeg (this may take a few minutes)..." -ForegroundColor Yellow
    Write-Host "Source: $ffmpegUrl" -ForegroundColor Gray
    
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($ffmpegUrl, $downloadPath)
    
    if (-not (Test-Path $downloadPath)) {
        throw "Download failed - file not found at $downloadPath"
    }
    
    $downloadSize = (Get-Item $downloadPath).Length / 1MB
    Write-Host "Download complete! Size: $([math]::Round($downloadSize, 1)) MB" -ForegroundColor Green

    # Extract the archive
    Write-Host "Extracting FFmpeg..." -ForegroundColor Yellow
    
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, $extractPath)
    
    # Find the extracted ffmpeg.exe and ffprobe.exe
    $ffmpegSource = Get-ChildItem -Path $extractPath -Recurse -Name "ffmpeg.exe" | Select-Object -First 1
    $ffprobeSource = Get-ChildItem -Path $extractPath -Recurse -Name "ffprobe.exe" | Select-Object -First 1
    
    if (-not $ffmpegSource -or -not $ffprobeSource) {
        throw "Could not find ffmpeg.exe or ffprobe.exe in the downloaded archive"
    }
    
    $ffmpegSourcePath = Join-Path $extractPath $ffmpegSource
    $ffprobeSourcePath = Join-Path $extractPath $ffprobeSource
    
    # Copy to installation directory
    Write-Host "Installing to $InstallPath..." -ForegroundColor Yellow
    
    if (-not (Test-Path $InstallPath)) {
        New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    }
    
    Copy-Item $ffmpegSourcePath $ffmpegExe -Force
    Copy-Item $ffprobeSourcePath $ffprobeExe -Force
    
    # Verify installation
    if (-not (Test-Path $ffmpegExe) -or -not (Test-Path $ffprobeExe)) {
        throw "Installation failed - binaries not found after copy"
    }
    
    # Test the installation
    Write-Host "Testing installation..." -ForegroundColor Yellow
    
    $version = Get-FFmpegVersion $ffmpegExe
    
    Write-Host ""
    Write-Host "=== Installation Complete! ===" -ForegroundColor Green
    Write-Host "FFmpeg Version: $version" -ForegroundColor Cyan
    Write-Host "Installed to: $InstallPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "You can use the encoding script: Re-Encode AV1.ps1" -ForegroundColor White
    
    # Update script configuration
    Write-Host ""
    Write-Host "=== Configuration Update ===" -ForegroundColor Cyan
    
    $scriptFiles = @("Re-Encode AV1.ps1")
    $updatedScripts = @()
    
    foreach ($scriptFile in $scriptFiles) {
        $scriptPath = Join-Path $InstallPath $scriptFile
        if (Test-Path $scriptPath) {
            try {
                $content = Get-Content $scriptPath -Raw
                
                # Update ffmpeg paths in the script
                $ffmpegPathPattern = '\$ffmpegPath\s*=\s*[''"]([^''"]*)[''"]'
                $ffprobPathPattern = '\$ffprobePath\s*=\s*[''"]([^''"]*)[''"]'
                
                $newFfmpegPath = "`$ffmpegPath            = '$ffmpegExe'"
                $newFfprobePath = "`$ffprobePath           = '$ffprobeExe'"
                
                $content = $content -replace $ffmpegPathPattern, $newFfmpegPath
                $content = $content -replace $ffprobPathPattern, $newFfprobePath
                
                Set-Content $scriptPath $content -NoNewline
                $updatedScripts += $scriptFile
                Write-Host "Updated $scriptFile configuration" -ForegroundColor Green
            } catch {
                Write-Host "Could not update $scriptFile configuration: $_" -ForegroundColor Yellow
            }
        }
    }
    
    if ($updatedScripts.Count -gt 0) {
        Write-Host ""
        Write-Host "Script configurations have been automatically updated!" -ForegroundColor Green
        Write-Host "The scripts are now ready to use." -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "Manual configuration required:" -ForegroundColor Yellow
        Write-Host "Update the following in your script files:" -ForegroundColor White
        Write-Host "`$ffmpegPath = '$ffmpegExe'" -ForegroundColor Gray
        Write-Host "`$ffprobePath = '$ffprobeExe'" -ForegroundColor Gray
    }

} catch {
    Write-Host ""
    Write-Host "Installation failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "You can try:" -ForegroundColor Yellow
    Write-Host "1. Run the script as Administrator" -ForegroundColor White
    Write-Host "2. Check your internet connection" -ForegroundColor White
    Write-Host "3. Download FFmpeg manually from: https://ffmpeg.org/download.html" -ForegroundColor White
    exit 1
} finally {
    # Clean up
    if (Test-Path $downloadPath) { Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue }
    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue }
    $ProgressPreference = 'Continue'
}

Write-Host ""
Write-Host "Ready to encode! Drag video files onto the launcher to get started." -ForegroundColor Green
Write-Host ""