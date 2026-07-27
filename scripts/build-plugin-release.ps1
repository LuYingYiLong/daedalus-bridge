param(
    [string]$OutputDirectory = "release"
)

$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$pluginRoot = Join-Path $repositoryRoot "addons\godot_daedalus"
$pluginConfigPath = Join-Path $pluginRoot "plugin.cfg"
$pluginMetadataPath = Join-Path $pluginRoot "daedalus-plugin.json"
$pluginConfig = Get-Content -LiteralPath $pluginConfigPath -Raw
$versionMatch = [regex]::Match($pluginConfig, '(?m)^\s*version\s*=\s*"([^"]+)"')
if (-not $versionMatch.Success) {
    throw "plugin.cfg does not contain a version."
}

$version = $versionMatch.Groups[1].Value
if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$') {
    throw "plugin.cfg version must use semantic versioning: $version"
}

try {
    $pluginMetadata = Get-Content -LiteralPath $pluginMetadataPath -Raw | ConvertFrom-Json
} catch {
    throw "daedalus-plugin.json is not valid JSON: $($_.Exception.Message)"
}
if ($pluginMetadata.schemaVersion -ne 1) {
    throw "Unsupported daedalus-plugin.json schemaVersion: $($pluginMetadata.schemaVersion)"
}
if ($pluginMetadata.pluginVersion -ne $version) {
    throw "plugin.cfg version $version does not match daedalus-plugin.json pluginVersion $($pluginMetadata.pluginVersion)."
}
$pluginProtocolVersion = 0
if (-not [int]::TryParse([string]$pluginMetadata.pluginProtocolVersion, [ref]$pluginProtocolVersion) -or $pluginProtocolVersion -lt 1) {
    throw "daedalus-plugin.json must contain a positive integer pluginProtocolVersion."
}
if ([string]::IsNullOrWhiteSpace($pluginMetadata.studioVersion) -or [string]::IsNullOrWhiteSpace($pluginMetadata.minGodotVersion)) {
    throw "daedalus-plugin.json must contain studioVersion and minGodotVersion."
}

$releaseRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputDirectory))
$repositoryPrefix = [IO.Path]::GetFullPath($repositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $releaseRoot.StartsWith($repositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must stay inside the plugin repository."
}

$stagingRoot = Join-Path $releaseRoot "staging"
$stagedPluginRoot = Join-Path $stagingRoot "addons\godot_daedalus"
$archiveName = "godot-daedalus-plugin-v$version.zip"
$manifestName = "godot-daedalus-plugin-v$version.manifest.json"
$archivePath = Join-Path $releaseRoot $archiveName
$manifestPath = Join-Path $releaseRoot $manifestName
$pluginPrefix = [IO.Path]::GetFullPath($pluginRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar

function Get-PluginRelativePath([string]$FullName) {
    $normalized = [IO.Path]::GetFullPath($FullName)
    if (-not $normalized.StartsWith($pluginPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Plugin source path escapes the plugin root: $FullName"
    }
    return $normalized.Substring($pluginPrefix.Length).Replace("\", "/")
}

function Test-IncludedPluginPath([string]$RelativePath) {
    return -not $RelativePath.StartsWith("tests/") `
        -and $RelativePath -ne "AGENTS.md" `
        -and $RelativePath -ne "daedalus-integrity.json" `
        -and $RelativePath -ne "assets/icons/normalize_daedalus_icons.py" `
        -and $RelativePath -ne "tools/run_plugin_tests.ps1" `
        -and -not $RelativePath.EndsWith(".pyc") `
        -and -not $RelativePath.Contains("/__pycache__/")
}

function Write-PortableImportMetadata([string]$Path) {
    $content = [IO.File]::ReadAllText($Path)
    # Keep the importer and UID required by static preloads, but exclude local .godot cache locations.
    $content = [regex]::Replace($content, '(?m)^path="[^"]+"\r?\n', '')
    $content = [regex]::Replace($content, '(?ms)^metadata=\{.*?^\}\r?\n?', '')
    $content = [regex]::Replace($content, '(?m)^dest_files=\[[^\r\n]*\]\r?\n', '')
    [IO.File]::WriteAllText($Path, $content, [Text.UTF8Encoding]::new($false))
}

function Get-ReleaseFileManifest([string]$StagedRoot) {
    $files = Get-ChildItem -LiteralPath $StagedRoot -File -Recurse | Sort-Object FullName
    $stagingPrefix = [IO.Path]::GetFullPath($StagingRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    return @($files | ForEach-Object {
        $fullName = [IO.Path]::GetFullPath($_.FullName)
        if (-not $fullName.StartsWith($stagingPrefix, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Staged release file escapes the staging root: $fullName"
        }
        $relative = $fullName.Substring($stagingPrefix.Length).Replace("\", "/")
        [ordered]@{
            path = $relative
            size = $_.Length
            sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        }
    })
}

function Test-ReleaseArchive([string]$Path, [string]$ExpectedPluginConfigPath, [object[]]$ExpectedFiles) {
    Add-Type -AssemblyName System.IO.Compression
    $archive = [IO.Compression.ZipFile]::OpenRead($Path)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
        if ($entryNames.Count -ne $ExpectedFiles.Count) {
            throw "Archive entry count does not match the manifest."
        }
        foreach ($entry in $archive.Entries) {
            if ($entry.FullName.Contains('..') -or -not $entry.FullName.StartsWith('addons/godot_daedalus/')) {
                throw "Archive contains an unsafe entry path: $($entry.FullName)"
            }
        }
        if ($entryNames -notcontains $ExpectedPluginConfigPath) {
            throw "Archive does not contain $ExpectedPluginConfigPath."
        }
        foreach ($file in $ExpectedFiles) {
            if ($entryNames -notcontains $file.path) {
                throw "Archive is missing manifest file $($file.path)."
            }
        }
    } finally {
        $archive.Dispose()
    }
}

function New-PluginArchive([string]$StagedRoot, [string]$Path) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $stagingPrefix = [IO.Path]::GetFullPath($StagedRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $archive = [IO.Compression.ZipFile]::Open($Path, [IO.Compression.ZipArchiveMode]::Create)
    try {
        Get-ChildItem -LiteralPath $StagedRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
            $fullName = [IO.Path]::GetFullPath($_.FullName)
            if (-not $fullName.StartsWith($stagingPrefix, [StringComparison]::OrdinalIgnoreCase)) {
                throw "Staged release file escapes the staging root: $fullName"
            }
            $entryName = $fullName.Substring($stagingPrefix.Length).Replace("\", "/")
            if ($entryName.Contains("..") -or -not $entryName.StartsWith("addons/godot_daedalus/")) {
                throw "Refusing to archive unsafe entry path: $entryName"
            }
            $entry = $archive.CreateEntry($entryName, [IO.Compression.CompressionLevel]::Optimal)
            $source = [IO.File]::OpenRead($fullName)
            $destination = $entry.Open()
            try {
                $source.CopyTo($destination)
            } finally {
                $destination.Dispose()
                $source.Dispose()
            }
        }
    } finally {
        $archive.Dispose()
    }
}

Remove-Item -LiteralPath $releaseRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagedPluginRoot -Force | Out-Null

$sourceFiles = Get-ChildItem -LiteralPath $pluginRoot -File -Recurse | Where-Object {
    if ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        throw "Refusing to package reparse point: $($_.FullName)"
    }
    Test-IncludedPluginPath (Get-PluginRelativePath $_.FullName)
}

foreach ($sourceFile in $sourceFiles) {
    $relative = Get-PluginRelativePath $sourceFile.FullName
    $destination = Join-Path $stagedPluginRoot $relative.Replace("/", "\")
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $sourceFile.FullName -Destination $destination
    if ($relative.EndsWith(".import")) {
        Write-PortableImportMetadata $destination
    }
}

$fileManifest = Get-ReleaseFileManifest $stagedPluginRoot
$integrityManifest = [ordered]@{
    schemaVersion = 1
    pluginVersion = $version
    pluginProtocolVersion = $pluginProtocolVersion
    files = $fileManifest
}
$integrityPath = Join-Path $stagedPluginRoot "daedalus-integrity.json"
$integrityJson = ($integrityManifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine
[IO.File]::WriteAllText($integrityPath, $integrityJson, [Text.UTF8Encoding]::new($false))
$fileManifest = Get-ReleaseFileManifest $stagedPluginRoot

New-PluginArchive $stagingRoot $archivePath
Test-ReleaseArchive $archivePath "addons/godot_daedalus/plugin.cfg" $fileManifest

$archive = Get-Item -LiteralPath $archivePath
$sourceCommit = (git -c "safe.directory=$($repositoryRoot.Replace('\', '/'))" -C $repositoryRoot rev-parse HEAD).Trim()
$manifest = [ordered]@{
    schemaVersion = 1
    pluginVersion = $version
    pluginProtocolVersion = $pluginProtocolVersion
    compatibleStudioVersion = $pluginMetadata.studioVersion
    studioVersion = $pluginMetadata.studioVersion
    minGodotVersion = $pluginMetadata.minGodotVersion
    sourceCommit = $sourceCommit
    sourceTag = "v$version"
    publishedAt = [DateTime]::UtcNow.ToString("o")
    archive = [ordered]@{
        fileName = $archiveName
        size = $archive.Length
        sha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    files = $fileManifest
}
$manifestJson = ($manifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine
[IO.File]::WriteAllText($manifestPath, $manifestJson, [Text.UTF8Encoding]::new($false))
Remove-Item -LiteralPath $stagingRoot -Recurse -Force

Write-Host "Created $archivePath"
Write-Host "Created $manifestPath"
