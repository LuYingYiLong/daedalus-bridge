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

The plugin uses `godot-daedalus-manager` for published backend install, update, launch, rollback, and diagnostics. For local backend development, configure the backend source directory in settings and run from the backend repository:

```powershell
npm install
npm run dev
```

The plugin defaults to:

```text
ws://localhost:38180
```

You can change the backend URL from the plugin settings panel.

Published backend versions are installed under `%APPDATA%/.godot_daedalus/backend/versions/` and are switched by the manager instead of updating a running `node_modules` directory in place.

## API Key

Open the plugin settings panel and save the DeepSeek API key there. The backend stores secrets with the OS secret store through `keytar`; API keys and custom MCP secrets should not be committed to the project.

## Validation

Useful checks during development:

```powershell
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --check-only --script "res://addons/godot_daedalus/scripts/main.gd"
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --quit --scene "res://addons/godot_daedalus/scenes/main.tscn"
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --script "res://addons/godot_daedalus/tests/main_helpers_test.gd"
& "D:/Godot_v4.7-stable_win64.exe/Godot_v4.7-stable_win64.exe" --headless --path "D:/GodotProjects/example" --script "res://addons/godot_daedalus/tests/rpc_methods_test.gd"
```

## Download Package

The Godot example project uses `.gitattributes` with `export-ignore` so generated source archives keep the plugin runtime files and leave out example-only project files, local development notes, tests, and helper scripts.
