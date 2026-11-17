# DMC5DLSS 1.1.0

ReShade add-on for **Devil May Cry 5** (DirectX 12) that replaces the game's TAA with
**NVIDIA DLSS** or **AMD FSR 3.1 / FSR 4**, and adds **DLSS frame generation**. The game has no
upscaler of its own; this gives it native anti-aliasing (DLAA) and upscaling from Quality to
Performance, with the game's bloom, depth of field, tonemapping (and RenoDX HDR) on top of the
upscaled image.

DLSS: NVIDIA RTX graphics card (frame generation: RTX 40/50). FSR 3.1: any DirectX 12 graphics
card; FSR 4: Radeon cards that support it (AMD's runtime picks). ReShade 6.8 or later with add-on
support, and REFramework for the render resolution dropdown.

## What it does

- **DLSS or FSR 3/4 in place of TAA** (F9 to switch on and off): DLSS Super Resolution 310.9.16,
  or AMD FSR (SDK 2.4.0: FSR 4 where the GPU supports it, FSR 3.1 elsewhere), takes the game's own
  colour, depth, motion vectors and camera jitter.
- **Correct motion vectors** (1.1.0): Devil May Cry 5 keeps its motion vectors in different channels
  from the Resident Evil games; 1.0.0 handed them to DLSS, FSR and frame generation as they were,
  so the motion they got was wrong (DLSS found almost no usable history). They're now converted,
  and the camera jitter the game leaves in them is taken out, as DLSS and FSR expect (Advanced tab,
  "Motion vectors without the camera jitter", on).
- **DLSS mode matches the render resolution** (1.1.0): DLSS was created in Quality mode at every
  render resolution; Balanced and Performance now run as Balanced and Performance.
- **Upscaler**: Auto (default: DLSS on RTX cards, FSR otherwise), DLSS, or FSR 3.1 / FSR 4.
- **Render resolution**: Native (100%: DLAA, or FSR's native anti-aliasing), Quality (67%),
  Balanced (58%) or Performance (50%) set the game's render scale (its Image Quality setting) while
  upscaling is on, and keep it there if the in-game slider moves. "Game's Image Quality slider"
  leaves it to the menu. This needs REFramework: the bundled script
  `reframework\autorun\DMC5DLSS.lua` sets the render scale.
- **Upscaling**: below 100%, DLSS/FSR render the full output resolution, and the game's bloom,
  glare, cutscene depth of field and tonemapping (and RenoDX's HDR, if installed) run on it at full
  resolution. The HUD and the game's own sharpening are drawn at full resolution as usual.
- **Frame generation**: Off (default) or DLSS 2x / 3x / 4x / Dynamic (NVIDIA Streamline 2.14.16,
  RTX 40/50; 3x and 4x need an RTX 50; with NVIDIA Reflex). It uses the game's depth, motion
  vectors and camera, works with either upscaler, and gets the picture without the HUD so the HUD
  doesn't warp. Exclusive full screen (and HDR) works. Switching it on takes a game restart. (FSR
  frame generation isn't offered in this game yet: its picture came out wrong.)
- **Sharper textures at lower render sizes** (on by default): a mip bias of log2(render scale) on
  the game's material textures, as NVIDIA recommends. It follows the render resolution as it
  changes, without a restart.
- **DLSS model**: Automatic (default: K, M at Performance, as NVIDIA recommends), or K, J, L or M
  (DLSS 4.5) at every resolution, or NVIDIA's default.
- **Sharpening** (Settings tab, off by default): extra contrast-adaptive sharpening of the upscaled
  image (AMD's RCAS): after DLSS, or FSR's own for FSR.
- **Game exposure** (off by default, Advanced tab): gives DLSS and FSR 3.1 the picture's real
  exposure instead of letting them estimate it.
- **Effect mask** (experimental, off by default, Advanced tab; 1.1.0): the game's anti-aliasing has
  no mask for particles and effects, so the add-on can make one from the picture before and after
  the game draws its effects, for DLSS and FSR to trust the current frame more there. It's off
  because the game also draws ambient mist as particles, which the mask then covers too.

Settings are in ReShade's Add-ons tab (Home key) under DMC5DLSS: what's running at the top, then
Settings, Status and Advanced tabs. They're saved in `ReShade.ini` under `[DMC5DLSS]`.

## Install

**With Fluffy Mod Manager**: put `DMC5DLSS-1.1.0.zip` in Fluffy Mod Manager's Devil May Cry 5
`Mods` folder (or drag it onto the manager) and enable it. It installs into the game folder:

- `DMC5DLSS.addon64` (the add-on) and `nvngx_dlss.dll` (NVIDIA's DLSS runtime, 310.9.16)
- `streamline\` (NVIDIA's frame generation runtime, Streamline 2.14.16, with a copy of
  `nvngx_dlss.dll`)
- `amd_fidelityfx_loader_dx12.dll`, `amd_fidelityfx_upscaler_dx12.dll` and
  `amd_fidelityfx_framegeneration_dx12.dll` (AMD's FSR runtime, SDK 2.4.0)
- `reframework\autorun\DMC5DLSS.lua` (sets the render scale for the render resolution dropdown)
- `DMC5DLSS-README.md`, `DMC5DLSS-THIRD_PARTY_NOTICES.txt`, `DMC5DLSS-licenses\`

**By hand**: copy the contents of the zip's `DMC5DLSS` folder into the game folder (where
`DevilMayCry5.exe` is), leaving out `modinfo.ini`.

Then:

1. ReShade 6.8 or later with full add-on support must be installed for `DevilMayCry5.exe`
   (DirectX 12).
2. REFramework must be installed for the render resolution dropdown (without it, use the game's
   Image Quality slider: 0.67 = Quality, 0.58 = Balanced, 0.5 = Performance).
3. In the game, keep the DirectX 12 renderer and Anti-Aliasing on TAA (DLSS/FSR replace that pass).
4. Open ReShade (Home), Add-ons tab, DMC5DLSS: upscaling is on by default (DLSS on RTX cards, FSR
   otherwise); pick a render resolution and, if you like, frame generation.

If the NVIDIA App has a DLSS model override for the game, it takes precedence over the model here.

## Notes

- Tested at 3840x2160 with HDR (RenoDX) in exclusive full screen on an NVIDIA RTX card, with
  REFramework: DLAA and DLSS Quality / Balanced / Performance in gameplay, the title menu and
  cutscenes; FSR 3.1 upscaling at every render resolution; DLSS frame generation 2x. Also tested
  with RenoDX off.
- FSR 3.1/4 through this add-on is untested on Radeon cards so far.
- 1.1.0 was tested at 3840x2160 with DLSS at DLAA, Quality, Balanced and Performance and DLSS frame
  generation.
- Bloom looks a little stronger at low render resolutions; the game does the same with its own
  upscaling (F9 off), so that's expected.
- A few frames during loading may show the game's own upscaling; that's expected.
- The render scale the dropdown sets is the game's Image Quality setting, so the game saves it in
  `dmc5config.ini`. With upscaling off (F9) or the dropdown on "Game's Image Quality slider", the
  script puts the game's previous value back.
- `DMC5DLSS.log` next to `DevilMayCry5.exe` records what the add-on did and why it fell back, if
  it did; `streamline\sl.log` is NVIDIA's frame generation log.

## Building

`build.ps1` builds `bin\DMC5DLSS.addon64` with Visual Studio 2022's C++ tools (MSVC): `-Install`
copies it, the NVIDIA and AMD runtimes and the REFramework script into the game folder;
`-Package` makes the Fluffy Mod Manager zip in `bin\release`. The runtimes aren't in the
repository: put NVIDIA's signed `nvngx_dlss.dll` 310.9.16 in `third_party\bin`, the Streamline
2.14.16 release's `bin\x64` in `third_party\streamline\bin\x64`, and AMD's signed FSR SDK 2.4.0 DLLs
(`Kits\FidelityFX\signedbin`) in `third_party\fidelityfx\bin`. `docs\FINDINGS.md` describes how the
game renders and what the add-on changes (forked from RE2DLSS; its analysis is in
`docs\RE2-FINDINGS.md`); `docs\FRAMEGEN.md` covers FSR and frame generation.

## Licence

MIT (see `LICENSE`). Third-party code and NVIDIA's and AMD's runtimes: `THIRD_PARTY_NOTICES.txt`.
