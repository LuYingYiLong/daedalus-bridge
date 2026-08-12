param(
    [string]$OutputDirectory = "release"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$bridgeRoot = Join-Path $repositoryRoot "addons\daedalus_editor_bridge"
$metadataPath = Join-Path $bridgeRoot "daedalus-editor-bridge.json"
$metadata = Get-Content -LiteralPath $metadataPath -Raw | ConvertFrom-Json
$version = [string]$metadata.bridgeVersion
if ($version -notmatch '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$') {
    throw "Bridge version must use semantic versioning: $version"
}
if ([int]$metadata.bridgeProtocolVersion -ne 4) {
    throw "Daedalus Editor Bridge 2.0 requires Bridge Protocol v4."
}
if ([string]$metadata.minGodotVersion -ne "4.0.0") {
    throw "The minimum Godot version must be 4.0.0."
}

$releaseRoot = [IO.Path]::GetFullPath((Join-Path $repositoryRoot $OutputDirectory))
$repositoryPrefix = [IO.Path]::GetFullPath($repositoryRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
if (-not $releaseRoot.StartsWith($repositoryPrefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "OutputDirectory must stay inside the Bridge repository."
}

$stagingRoot = Join-Path $releaseRoot "staging"
$stagedBridgeRoot = Join-Path $stagingRoot "addons\daedalus_editor_bridge"
$archiveName = "daedalus-editor-bridge-v$version.zip"
$manifestName = "daedalus-editor-bridge-v$version.manifest.json"
$archivePath = Join-Path $releaseRoot $archiveName
$manifestPath = Join-Path $releaseRoot $manifestName
$forbiddenExtensions = @(".uid", ".import", ".dll", ".so", ".dylib", ".a", ".wasm", ".gdextension")

Remove-Item -LiteralPath $releaseRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagedBridgeRoot -Force | Out-Null

$bridgePrefix = [IO.Path]::GetFullPath($bridgeRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
$sourceFiles = @(Get-ChildItem -LiteralPath $bridgeRoot -File -Recurse | Where-Object {
    -not $forbiddenExtensions.Contains($_.Extension.ToLowerInvariant()) `
        -and $_.FullName -notmatch '[\\/]\.godot[\\/]' `
        -and $_.FullName -notmatch '[\\/]tests[\\/]'
})

foreach ($sourceFile in $sourceFiles) {
    $fullName = [IO.Path]::GetFullPath($sourceFile.FullName)
    if (-not $fullName.StartsWith($bridgePrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Bridge source path escaped the plugin root: $fullName"
    }
    $relative = $fullName.Substring($bridgePrefix.Length)
    $destination = Join-Path $stagedBridgeRoot $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $sourceFile.FullName -Destination $destination
}

$uncompressedSize = (Get-ChildItem -LiteralPath $stagedBridgeRoot -File -Recurse | Measure-Object -Property Length -Sum).Sum
if ($uncompressedSize -ge 2MB) {
    throw "Bridge release is $uncompressedSize bytes; the uncompressed package must remain below 2 MiB."
}

$files = @(Get-ChildItem -LiteralPath $stagedBridgeRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
    $relative = [IO.Path]::GetFullPath($_.FullName).Substring([IO.Path]::GetFullPath($stagingRoot).TrimEnd('\').Length + 1).Replace('\', '/')
    [ordered]@{
        path = $relative
        size = $_.Length
        sha256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
})

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($archivePath, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        $sourcePath = Join-Path $stagingRoot $file.path.Replace('/', '\')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $sourcePath, $file.path, [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
} finally {
    $archive.Dispose()
}

$archiveInfo = Get-Item -LiteralPath $archivePath
$sourceCommit = (git -c "safe.directory=$($repositoryRoot.Replace('\', '/'))" -C $repositoryRoot rev-parse HEAD).Trim()
$manifest = [ordered]@{
    schemaVersion = 2
    bridgeVersion = $version
    bridgeProtocolVersion = [int]$metadata.bridgeProtocolVersion
    studioVersion = [string]$metadata.studioVersion
    minGodotVersion = [string]$metadata.minGodotVersion
    repository = "daedalus-editor-bridge"
    sourceCommit = $sourceCommit
    publishedAt = [DateTime]::UtcNow.ToString("o")
    archive = [ordered]@{
        fileName = $archiveName
        size = $archiveInfo.Length
        uncompressedSize = $uncompressedSize
        sha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    }
    files = $files
}
[IO.File]::WriteAllText($manifestPath, (($manifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine), [Text.UTF8Encoding]::new($false))
Remove-Item -LiteralPath $stagingRoot -Recurse -Force

Write-Host "Created $archivePath"
Write-Host "Created $manifestPath"
