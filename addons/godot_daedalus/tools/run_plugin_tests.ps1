param(
	[string]$GodotExecutablePath = $env:GODOT_EXECUTABLE_PATH,
	[string]$GodotProjectPath = $(if ($env:GODOT_PROJECT_PATH) { $env:GODOT_PROJECT_PATH } else { "D:\GodotProjects\example" }),
	[switch]$IncludeBackendWebSocketSmoke
)

$ErrorActionPreference = "Stop"
chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if ([string]::IsNullOrWhiteSpace($GodotExecutablePath)) {
	$GodotExecutablePath = "D:\Godot_v4.7-stable_win64.exe\Godot_v4.7-stable_win64.exe"
}

if (-not (Test-Path -LiteralPath $GodotExecutablePath -PathType Leaf)) {
	throw "Godot executable was not found: $GodotExecutablePath"
}

if (-not (Test-Path -LiteralPath $GodotProjectPath -PathType Container)) {
	throw "Godot project was not found: $GodotProjectPath"
}

$pluginTestsDir = Join-Path $GodotProjectPath "addons\godot_daedalus\tests"
if (-not (Test-Path -LiteralPath $pluginTestsDir -PathType Container)) {
	throw "Godot Daedalus tests directory was not found: $pluginTestsDir"
}

function Invoke-GodotTestCommand {
	param(
		[string]$Label,
		[string[]]$GodotArguments
	)

	Write-Host "Running $Label"
	$output = & $GodotExecutablePath @GodotArguments 2>&1
	$exitCode = $LASTEXITCODE
	$text = ($output | Out-String)
	if ($text.Trim().Length -gt 0) {
		Write-Host $text
	}

	if ($exitCode -ne 0) {
		throw "$Label failed with exit code $exitCode"
	}

	if ($text -match "SCRIPT ERROR|\bERROR:") {
		throw "$Label emitted Godot errors"
	}
}

Invoke-GodotTestCommand `
	-Label "main.gd check-only" `
	-GodotArguments @(
		"--headless",
		"--path",
		$GodotProjectPath,
		"--check-only",
		"--script",
		"res://addons/godot_daedalus/scripts/main.gd"
	)

$testFiles = Get-ChildItem -LiteralPath $pluginTestsDir -Filter "*.gd" | Sort-Object Name
if (-not $IncludeBackendWebSocketSmoke) {
	$testFiles = $testFiles | Where-Object { $_.Name -ne "backend_websocket_smoke_test.gd" }
}

foreach ($testFile in $testFiles) {
	$resourcePath = "res://addons/godot_daedalus/tests/$($testFile.Name)"
	Invoke-GodotTestCommand `
		-Label $resourcePath `
		-GodotArguments @(
			"--headless",
			"--path",
			$GodotProjectPath,
			"--script",
			$resourcePath
		)
}

Write-Host "Godot Daedalus plugin tests passed."
