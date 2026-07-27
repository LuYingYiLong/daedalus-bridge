# Godot Daedalus

Godot Daedalus is an editor plugin that adds an AI assistant panel to Godot. It connects to the TypeScript backend over WebSocket and supports chat, session history, approvals, custom MCP servers, editor context, and Godot project tools.

## Install

Copy this directory to a Godot project:

```text
res://addons/godot_daedalus/
```

Enable the plugin in Godot:

```text
Project > Project Settings > Plugins > GodotDaedalus
```

## Backend

Production installations use the backend executable deployed by Daedalus Studio. The plugin acquires the authenticated shared runtime on demand, so Godot can remain connected after Studio closes. For local backend development, configure the development backend URL and run from the backend repository:

```powershell
npm install
npm run dev
```

The plugin defaults to:

```text
ws://localhost:38180
```

You can change the backend URL from the plugin settings panel.

Published backend versions are installed under `%USERPROFILE%/.daedalus/backend/versions/` and are switched by the manager instead of updating a running `node_modules` directory in place. Older development installs under `%APPDATA%/.godot_daedalus/backend/` are only used as a fallback when present.

## API Key

Open the plugin settings panel and save the DeepSeek API key there. The backend stores secrets with the OS secret store through `keytar`; API keys and custom MCP secrets should not be committed to the project.

## Validation

Useful checks during development:

```powershell
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --check-only --script "res://addons/godot_daedalus/scripts/main.gd"
pwsh -NoProfile -ExecutionPolicy Bypass -File "D:/GodotProjects/example/addons/godot_daedalus/tools/run_plugin_tests.ps1"
```

Targeted checks:

```powershell
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --check-only --script "res://addons/godot_daedalus/scripts/main.gd"
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --quit --scene "res://addons/godot_daedalus/scenes/main.tscn"
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --script "res://addons/godot_daedalus/tests/main_helpers_test.gd"
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --script "res://addons/godot_daedalus/tests/rpc_methods_test.gd"
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --script "res://addons/godot_daedalus/tests/additional_context_item_test.gd"
```

For the public Beta smoke path, start from the backend repository and run:

```powershell
$env:GODOT_EXECUTABLE_PATH = "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe"
$env:GODOT_PROJECT_PATH = "D:/GodotProjects/example"
$env:GODOT_DAEDALUS_PLUGIN_DIR = "D:/GodotProjects/example/addons/godot_daedalus"
npm run smoke:beta
```

Before a public Beta release, also manually verify plugin enablement, backend manager install/start/stop/rollback, provider configuration, model refresh, Ask mode, Agent read tools, write approval approve/reject, diagnostics, session restore, frontend update apply-wait, and rollback.

## Download Package

The Godot example project uses `.gitattributes` with `export-ignore` so generated source archives keep the plugin runtime files and leave out example-only project files, local development notes, tests, and helper scripts.

Public Beta release assets must include `godot-daedalus-plugin-vX.Y.Z.zip` and `godot-daedalus-plugin-vX.Y.Z.manifest.json`. The zip must contain `addons/godot_daedalus/plugin.cfg`; the manifest must include `version`, `tag`, `sha256`, `assetName`, and `minGodotVersion`.
