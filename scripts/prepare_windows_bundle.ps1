param(
    [string]$ReleaseDir = "build/windows/x64/runner/Release",
    [string]$ConfigSource = "packaging/windows/config.json",
    [string]$FfmpegDownloadUrl = "https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip"
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoPath {
    param([string]$Path)

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".." $Path))
}

$resolvedReleaseDir = Resolve-RepoPath $ReleaseDir
$resolvedConfigSource = Resolve-RepoPath $ConfigSource

if (-not (Test-Path $resolvedReleaseDir)) {
    throw "Release directory not found: $resolvedReleaseDir"
}

if (-not (Test-Path $resolvedConfigSource)) {
    throw "Config template not found: $resolvedConfigSource"
}

$configTargetPath = Join-Path $resolvedReleaseDir 'config.json'
Copy-Item -Path $resolvedConfigSource -Destination $configTargetPath -Force
Write-Host "Copied config.json to $configTargetPath"

$ffmpegTargetDir = Join-Path $resolvedReleaseDir 'ffmpeg'
if (Test-Path $ffmpegTargetDir) {
    Remove-Item -Path $ffmpegTargetDir -Recurse -Force
}
New-Item -ItemType Directory -Path $ffmpegTargetDir | Out-Null

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
$zipPath = Join-Path $tempRoot 'ffmpeg-release-essentials.zip'
$extractRoot = Join-Path $tempRoot 'extract'
New-Item -ItemType Directory -Path $tempRoot | Out-Null
New-Item -ItemType Directory -Path $extractRoot | Out-Null

try {
    Write-Host "Downloading FFmpeg from $FfmpegDownloadUrl"
    Invoke-WebRequest -Uri $FfmpegDownloadUrl -OutFile $zipPath

    Write-Host "Extracting FFmpeg archive"
    Expand-Archive -Path $zipPath -DestinationPath $extractRoot -Force

    $archiveRoots = Get-ChildItem -Path $extractRoot
    if ($archiveRoots.Count -eq 0) {
        throw 'Downloaded archive is empty.'
    }

    $sourceRoot = if ($archiveRoots.Count -eq 1 -and $archiveRoots[0].PSIsContainer) {
        $archiveRoots[0].FullName
    } else {
        $extractRoot
    }

    Copy-Item -Path (Join-Path $sourceRoot '*') -Destination $ffmpegTargetDir -Recurse -Force
    Write-Host "Prepared FFmpeg folder at $ffmpegTargetDir"
}
finally {
    if (Test-Path $tempRoot) {
        Remove-Item -Path $tempRoot -Recurse -Force
    }
}
