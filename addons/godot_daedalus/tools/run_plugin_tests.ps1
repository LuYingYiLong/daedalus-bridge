param(
	[Parameter(Mandatory = $true)]
	[string]$GodotExecutable
)

$ErrorActionPreference = "Stop"
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..\..")
$testScripts = @(
	"res://addons/godot_daedalus/tests/variant_codec_test.gd",
	"res://addons/godot_daedalus/tests/editor_domain_contract_test.gd"
)

foreach ($testScript in $testScripts) {
	& $GodotExecutable `
		--headless `
		--log-file (Join-Path $env:TEMP "godot-daedalus-plugin-tests.log") `
		--path $projectRoot `
		--script $testScript
	if ($LASTEXITCODE -ne 0) {
		throw "Godot plugin test failed: $testScript"
	}
}

Write-Host "Godot Daedalus plugin tests passed."
