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
| Godot | 4.7.2.stable.official.ed1daf0bf, official Linux x86_64 release, SHA-512 verified against the release's SHA512-SUMS.txt |
| Git | 2.43.0 |
| Git LFS | Installed |
| GitHub CLI | Installed, token invalid; pushes go through the session's git proxy |
| Python | 3.13 |
| Pillow | 12.3.0 |
| gdtoolkit | 4.5.0 (syntax check only) |
| Blender, Krita, Inkscape | Not installed |

## Optional developer tools

```bash
pip install gdtoolkit   # gdparse, gdlint, gdformat
```
