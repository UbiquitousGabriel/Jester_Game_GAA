# Environment Manifest

## Pinned

| Tool | Version | Notes |
| --- | --- | --- |
| Godot | 4.7.2 stable (standard build) | Latest 4.7.x tag as of 2026-11-10. Do not move to dev or beta builds |
| Renderer | GL Compatibility | Widest hardware support for a 2D game |
| Physics tick | 60 Hz | |
| Base viewport | 1920 x 1080 | Stretch mode `canvas_items`, aspect `expand` |

## Build session (2026-11-10, Linux x86_64, Ubuntu 24.04)

| Tool | Found |
| --- | --- |
| Godot | Not installed; download and execution was blocked by the session's security policy |
| Git | 2.43.0 |
| Git LFS | Installed |
| GitHub CLI | Installed, token invalid |
| Python | 3.13 |
| Pillow | 12.3.0 |
| gdtoolkit | 4.5.0 (syntax check only) |
| Blender, Krita, Inkscape | Not installed |

## Optional developer tools

```bash
pip install gdtoolkit   # gdparse, gdlint, gdformat
```
