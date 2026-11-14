# DMC5DLSS

A ReShade add-on for Devil May Cry 5 (RE Engine, DirectX 12) that will replace the game's TAA with
NVIDIA DLSS (DLAA and upscaling), like RE2DLSS / RE3DLSS / RE7DLSS / VillageDLSS. Forked from
RE2DLSS 1.3.1.

**Status: 0.0.x probe.** The shader ids are not known yet, so the add-on changes nothing in the
game; it only records frames (ReShade overlay → Add-ons → DMC5DLSS → Advanced → Capture frame) to
`DMC5DLSS-frame-N.txt` next to `DevilMayCry5.exe`. Findings go in [docs/FINDINGS.md](docs/FINDINGS.md).

Build: `.\build.ps1 [-Install]` (Visual Studio 2022 C++ tools; game closed for -Install).
