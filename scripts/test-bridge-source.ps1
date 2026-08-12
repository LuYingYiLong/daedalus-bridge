$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$bridgeRoot = Join-Path $repositoryRoot "addons\daedalus_editor_bridge"
$files = @(Get-ChildItem -LiteralPath $bridgeRoot -File -Recurse)
$forbiddenExtensions = @(".uid", ".import", ".dll", ".so", ".dylib", ".a", ".wasm", ".gdextension")
$releaseFiles = @($files | Where-Object { $_.Extension -notin $forbiddenExtensions })
$sourceFiles = @($releaseFiles | Where-Object { $_.Extension -in @(".gd", ".tscn", ".cfg", ".json") })
foreach ($sourceFile in $sourceFiles) {
    $source = Get-Content -LiteralPath $sourceFile.FullName -Raw
    if ($sourceFile.Extension -eq ".gd" -and $source -match '(?m)^class_name\s+') { throw "Global script classes are forbidden in the Bridge and can collide with legacy addons: $($sourceFile.FullName)." }
    if ($sourceFile.Extension -eq ".gd" -and $source -match '(?m)^\s*for\s+[A-Za-z_][A-Za-z0-9_]*\s*:\s*[^\r\n]+\s+in\s+') { throw "Godot 4.2-only typed loop variables remain in $($sourceFile.FullName)." }
    if ($source -match '(?:Array|Dictionary)\s*\[') { throw "Godot 4.0-incompatible typed containers remain in $($sourceFile.FullName)." }
    if ($source -match '(?:\bis\s+|\bas\s+|:\s*)(?:AnimationMixer|TileMapLayer)\b') { throw "Post-Godot-4.0 static types remain in $($sourceFile.FullName)." }
    if ($source -match 'uid://|addons/godot_daedalus|Godot Daedalus Plugin') { throw "Legacy or UID-based references remain in $($sourceFile.FullName)." }
    if ($source -match 'chat|provider|composer|session timeline|markdown') { throw "Chat-client terminology remains in $($sourceFile.FullName)." }
}
$runtimeSource = Get-Content -LiteralPath (Join-Path $bridgeRoot "scripts\bridge_runtime.gd") -Raw
if ($runtimeSource -match 'status_dock\s*=\s*VBoxContainer\.new\(\)') { throw "The status Dock must be instantiated from its scene, not generated in code." }
if (-not (Test-Path -LiteralPath (Join-Path $bridgeRoot "scenes\bridge_status_dock.tscn") -PathType Leaf)) { throw "The status Dock scene is missing." }
$size = ($releaseFiles | Measure-Object -Property Length -Sum).Sum
if ($size -ge 2MB) { throw "Bridge source exceeds 2 MiB: $size bytes." }
Write-Host "Bridge source scan passed ($($releaseFiles.Count) release files, $size bytes)."
