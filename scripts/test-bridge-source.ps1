$ErrorActionPreference = "Stop"

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$bridgeRoot = Join-Path $repositoryRoot "addons\daedalus_bridge"
$files = @(Get-ChildItem -LiteralPath $bridgeRoot -File -Recurse)
$forbiddenExtensions = @(".uid", ".import", ".dll", ".so", ".dylib", ".a", ".wasm", ".gdextension")
$releaseFiles = @($files | Where-Object { $_.Extension -notin $forbiddenExtensions })
$sourceFiles = @($releaseFiles | Where-Object { $_.Extension -in @(".gd", ".tscn", ".cfg", ".json") })

foreach ($sourceFile in $sourceFiles) {
    $source = Get-Content -LiteralPath $sourceFile.FullName -Raw
    if ($sourceFile.Extension -eq ".gd" -and $source -match '(?m)^class_name\s+') {
        throw "Global script classes are forbidden in the Bridge and can collide with legacy addons: $($sourceFile.FullName)."
    }
    if ($sourceFile.Extension -eq ".gd" -and $source -match '(?m)^\s*for\s+[A-Za-z_][A-Za-z0-9_]*\s*:\s*[^\r\n]+\s+in\s+') {
        throw "Godot 4.2-only typed loop variables remain in $($sourceFile.FullName)."
    }
    if ($source -match '(?:Array|Dictionary)\s*\[') {
        throw "Godot 4.0-incompatible typed containers remain in $($sourceFile.FullName)."
    }
    if ($source -match '(?:\bis\s+|\bas\s+|:\s*)(?:AnimationMixer|TileMapLayer)\b') {
        throw "Post-Godot-4.0 static types remain in $($sourceFile.FullName)."
    }
    if ($source -match 'uid://|addons/daedalus_editor_bridge|daedalus-editor-bridge|Daedalus Editor Bridge') {
        throw "Legacy naming or UID-based references remain in $($sourceFile.FullName)."
    }
    if ($source -match 'chat|provider|composer|session timeline|markdown') {
        throw "Chat-client terminology remains in $($sourceFile.FullName)."
    }
}

$runtimeSource = Get-Content -LiteralPath (Join-Path $bridgeRoot "scripts\bridge_runtime.gd") -Raw
$dockScenePath = Join-Path $bridgeRoot "scenes\bridge_status_dock.tscn"
$dockScriptPath = Join-Path $bridgeRoot "scripts\bridge_status_dock.gd"
if ($runtimeSource -match 'get_node\("(?:Status|Project|Scene|Version|Sync|Capability|Error)') {
    throw "The runtime must communicate through the Dock root script instead of reaching into scene children."
}
if (-not (Test-Path -LiteralPath $dockScenePath -PathType Leaf) -or -not (Test-Path -LiteralPath $dockScriptPath -PathType Leaf)) {
    throw "The status Dock scene or its root script is missing."
}
$dockScene = Get-Content -LiteralPath $dockScenePath -Raw
if ($dockScene -notmatch 'script\s*=\s*ExtResource\("1_dock"\)') {
    throw "The status Dock root must own bridge_status_dock.gd."
}
if ($dockScene -match '\[ext_resource[^\r\n]+\.svg') {
    throw "The status Dock must not depend on an imported SVG resource during plugin startup."
}
$dockScript = Get-Content -LiteralPath $dockScriptPath -Raw
if ($dockScript -notmatch 'icon_image\.load\(ICON_PATH\)') {
    throw "The status Dock must decode its SVG icon without relying on Godot's import cache."
}

$size = ($releaseFiles | Measure-Object -Property Length -Sum).Sum
if ($size -ge 2MB) {
    throw "Bridge source exceeds 2 MiB: $size bytes."
}

Write-Host "Bridge source scan passed ($($releaseFiles.Count) release files, $size bytes)."
