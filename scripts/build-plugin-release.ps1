param(
    [string]$OutputDirectory = "release"
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$pluginRoot = Join-Path $repositoryRoot "addons\godot_daedalus"
$pluginConfig = Get-Content -LiteralPath (Join-Path $pluginRoot "plugin.cfg") -Raw
$versionMatch = [regex]::Match($pluginConfig, '(?m)^\s*version\s*=\s*"([^"]+)"')
if (-not $versionMatch.Success) {
    throw "plugin.cfg does not contain a version."
}

$version = $versionMatch.Groups[1].Value
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

Remove-Item -LiteralPath $releaseRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $stagedPluginRoot -Force | Out-Null

$sourceFiles = Get-ChildItem -LiteralPath $pluginRoot -File -Recurse | Where-Object {
    $relative = Get-PluginRelativePath $_.FullName
    -not $relative.EndsWith(".import") `
        -and -not $relative.StartsWith("tests/") `
        -and $relative -ne "AGENTS.md" `
        -and $relative -ne "daedalus-integrity.json" `
        -and $relative -ne "assets/icons/normalize_daedalus_icons.py" `
        -and $relative -ne "tools/run_plugin_tests.ps1" `
        -and -not $relative.EndsWith(".pyc") `
        -and -not $relative.Contains("/__pycache__/")
}

$fileManifest = @()
foreach ($sourceFile in $sourceFiles) {
    $relative = Get-PluginRelativePath $sourceFile.FullName
    $destination = Join-Path $stagedPluginRoot $relative.Replace("/", "\")
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $sourceFile.FullName -Destination $destination
    $fileManifest += [ordered]@{
        path = "addons/godot_daedalus/$($relative.Replace('\', '/'))"
        size = $sourceFile.Length
        sha256 = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$integrityManifest = [ordered]@{
    schemaVersion = 1
    pluginVersion = $version
    pluginProtocolVersion = 1
    files = $fileManifest
}
$integrityPath = Join-Path $stagedPluginRoot "daedalus-integrity.json"
$integrityJson = ($integrityManifest | ConvertTo-Json -Depth 8) + [Environment]::NewLine
[IO.File]::WriteAllText($integrityPath, $integrityJson, [Text.UTF8Encoding]::new($false))
$integrityFile = Get-Item -LiteralPath $integrityPath
$fileManifest += [ordered]@{
    path = "addons/godot_daedalus/daedalus-integrity.json"
    size = $integrityFile.Length
    sha256 = (Get-FileHash -LiteralPath $integrityPath -Algorithm SHA256).Hash.ToLowerInvariant()
}

Compress-Archive -LiteralPath (Join-Path $stagingRoot "addons") -DestinationPath $archivePath -CompressionLevel Optimal
$archive = Get-Item -LiteralPath $archivePath
$sourceCommit = (git -c "safe.directory=$($repositoryRoot.Replace('\', '/'))" -C $repositoryRoot rev-parse HEAD).Trim()
$manifest = [ordered]@{
    schemaVersion = 1
    pluginVersion = $version
    pluginProtocolVersion = 1
    compatibleStudioVersion = ">=1.0.3"
    studioVersion = "unbound"
    minGodotVersion = "4.4.0"
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
