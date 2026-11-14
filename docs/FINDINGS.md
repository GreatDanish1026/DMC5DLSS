# DMC5DLSS findings

Devil May Cry 5, Steam build 24901913, `DevilMayCry5.exe`, **DirectX 12** (`dmc5config.ini`:
`Capability=DirectX12`, `TargetPlatform=DirectX12`, `AntiAliasing=TAA`, `ImageQualityRate=1`,
`MotionBlurEnable=false`). REFramework nightly (built 2026-11-12, TDB 67), ReShade 6.8.0,
`renodx-dmc5.addon64` (HDR). No ray tracing on PC.

Also installed: **GITC Uplift** (`gitc-uplift.addon64`, `GITC-Uplift\nvngx_dlssnr.dll` 310.9.16), a
third-party ReShade add-on that hooks `_nvngx.dll` (D3D12/D3D11/Vulkan entry points) and runs its
own NGX "NR" feature at 3840x2160. It may get in the way of our NGX calls, so test 0.1.0 with it on and off.

Base: forked from RE2DLSS 1.3.1 (DX12). 0.0.1 = that code with dummy post shader ids (nothing is
redirected), used for the frame capture.

## Captures (2026-11-14, 3840x2160, RenoDX on, r11g11b10f post chain)

`docs/captures/DMC5DLSS-frame-1.txt` (Image Quality 100%) and `DMC5DLSS-frame-2.txt` (80%,
3072x1728 -> 3840x2160). Both have one complete frame. All graphics work runs on the graphics queue.

DMC5 is on an older RE Engine than the DX12 RE2/RE3 (TDB 67 vs 70): **its post chain matches the
DX11 RE2 build** (RE2DLSS-DX11 docs/FINDINGS.md). It uses the same bloom shaders (pseb1e43cf, psf76db36a,
ps1e144d08, psbbca9350, ps22e6f49d, psba7dcf1c, ps629a5b35), the same stretch psaff99b25, the same copy
ps83760deb and the same VS ids (vs3f48df32, vsa60b7c3f, vs7c24ad34). The TAA, tonemap, sharpen
and output shaders are DMC5's own.

| Pass | Shader | Reads | Writes |
|---|---|---|---|
| lighting / composite | ps938ab36b, ps8148b08f, then particles ps041d96bf / ps77a5021e (5-index quads), psc060a249, ps94445b22 | | #ef595 colour r11g11b10f, render size |
| depth copy | copy | #ef463 depth r32_typeless | #efa5d |
| **TAA** | **ps321bf06e** (vs3f48df32) | **t0 depth #ef463 r32_typeless (as r32f), t1 colour #ef595, t2 history #ef9c4, t3 velocity #ef4fc rgba16snorm**; b0 #219a3 +230912 (SceneInfo?), b1 #2171e +184832 (Tonemap cb?) | **#ef6c7 r11g11b10f, render size** |
| history copy | copy | #ef6c7 | #ef9c4 |
| bloom down/up | pseb1e43cf, psf76db36a x4, ps1e144d08, psbbca9350, ps22e6f49d, psba7dcf1c | #ef6c7 | 1536x864 .. 96x54 |
| bloom composite | ps629a5b35 | t0 bloom 1536x864 | into #ef6c7 (render size) |
| **tonemap** | **ps25016cc3** (vs3f48df32; b4-b10, 32^3 LUTs; RenoDX replaces it: "declarations unknown") | **t0 #ef6c7** | #ef595, render size |
| **stretch** | **psaff99b25** (vsa60b7c3f) | t0 depth #ef463, t1 tonemapped #ef595 | **#54dde 3840x2160** + depth #bb10b 3840x2160 r32_typeless |
| (at 100%: no stretch) | the tonemap writes #54dde (4K) directly | | |
| **sharpen** | **psae40e1ff** (at output size) | t0 #54dde, t1 #57369 r8unorm 4K (mask) | #5706c 4K |
| copy back | ps83760deb | t0 #5706c | #54dde |
| output | psca880db5 (RenoDX-replaced) | t0 #54dde 4K, t1 #ef595 (render size) | back buffer rgb10a2 (colour space 1) |

Notes:
- **TAA registers differ from RE2's** (RE2: t0 mask, t1 depth, t2 colour, t3 history, t4 velocity).
  DMC5 has **no EffectMaskTex**: t0 depth, t1 colour, t2 history, t3 velocity (kTaaMask = -1).
- Depth is **r32_typeless** (viewed as r32f), like RE7's, not r32g8x24 like RE2's.
- Velocity is the G-buffer's rgba16snorm (as in Village/RE2 DX11). The prevUV maths (scale 0.5 / -0.5)
  still needs confirming from the bytecode.
- The whole chain up to the tonemap runs at render size; **the sharpening is already at output size**
  (unlike RE2, where it runs before the stretch). So when upscaling, only the bloom composite and the
  tonemap need redirecting to output size, then the stretch's colour gets replaced.
- At 100% the tonemap renders straight into the 4K target (#54dde), so DLAA needs nothing after the TAA.
- No HUD draws appear in either frame. Either the HUD was hidden, or it's drawn into another target
  that psca880db5 combines; to check in a gameplay capture. It only matters for frame generation.
- The output pass also reads the render-size tonemapped image (t1). It may only be declared, not
  sampled; check from the bytecode. If it is sampled, upscaling must leave it valid.

## Still to do (before 0.1.0 code)

`ReShade.ini [DMC5DLSS] DumpShaders` is now set (backup `ReShade.ini.bak-dmc5probe`) for
ps321bf06e, ps629a5b35, ps25016cc3, psaff99b25, psae40e1ff, ps83760deb, psca880db5, vs3f48df32 and
vsa60b7c3f. One game run with a capture writes their bytecode (`DMC5DLSS-<id>.cso`) and constant
buffers. These things need confirming from that run:
- the TAA's entry name (PreTonemap2_PS?), its register names, and the velocity / exposure maths;
- the **SceneInfo layout** (the size of b0; projElement[0] jitter at byte 160, screenSize at 368,
  cameraNearPlane at 392 as in RE2), and that jitter is non-zero;
- whether the Tonemap cb (b1) has AABlend / exposure;
- what the stretch's depth output and the output pass's t1 are used for.

## Plan for 0.1.0 (DLSS)

The RE2DLSS (DX12) upscaler with DMC5's id block. This is closest to the RE2DLSS-DX11 0.1.0 flow,
but on D3D12, so it needs no new hook core.
1. Id block: kTaaPs ps321bf06e, kTaaDepth 0, kTaaColor 1, kTaaMotion 3, kTaaMask -1; kBloomPs = the
   bloom composite ps629a5b35 (as in RE2 DX11, RE2 DX12 used NewFinal); kTonemapPs ps25016cc3;
   no kSharpenPs before the stretch (this game's sharpen is after it); kFinalCs → the stretch is a
   **pixel shader** psaff99b25, not RE2's CAS_CS compute. The final-pass hook needs a draw
   variant: let the stretch draw run (it writes 4K depth), then blit DLSS's tonemapped output-size
   image over its colour target, as RE2DLSS-DX11 does. kOutputPs psca880db5.
2. Depth SRV format r32_float for r32_typeless (RE7's RtDepthSrvFormat path), so it's not the
   r32g8 view.
3. DLAA: DLSS → X, then copied into the TAA target #ef6c7. The TAA draw is skipped.
4. Upscaling: DLSS → X at output size, game TAA skipped; bloom composite and tonemap redirected to
   output size (in place, RE2DLSS's design, with a SceneInfo copy whose screenSize is the output size);
   the stretch runs and then our image goes over its colour. The bloom pyramid reads the render-size TAA target, so fill it with
   the DLSS image downsampled (as in RE2 DX11) to keep bloom right.
5. Exposure: own 1x1 = 1.0 or DLSS auto-exposure. Default to **auto-exposure**: the game exposure
   made dithered fades see-through in RE2 DX11. No effect mask.
6. Render resolution dropdown: DMC5DLSS.lua already sets via.render.RenderConfig.ImageQualityRate,
   and the field exists in DMC5 (`[RenderConfig] ImageQualityRate`). Check that it's in TDB 67.
7. Hide the ray tracing / Ray Reconstruction UI (no RT on PC). Leave frame generation and FSR off
   until DLSS works. FSR should then work as-is (D3D12); FG needs the HUD found first.
8. Test in game: DLAA and Quality/Balanced/Performance, with RenoDX on and GITC Uplift on/off.
