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

## Shader dump (2026-11-14, capture 3: 100%, gameplay with HUD)

`docs/shaders/DMC5DLSS-<id>.cso` + `fxc /dumpbin` listings (`.txt`); capture
`docs/captures/DMC5DLSS-frame-3-dump.txt`. The DumpShaders line has been removed from ReShade.ini again.

- **TAA ps321bf06e** has the same maths as RE2's PreTonemap2_PS, with different registers:
  `t0 ReadonlyDepth` (float), `t1 HDRImage`, `t2 PrevHDRImage`, `t3 Velocity`; `cb0 SceneInfo`,
  `cb1 Tonemap` (preTonemapRange, AABlend used; ResponsiveAARate declared but unused, no mask).
  Colour is multiplied by the VS's `Exposure` (v2.x) and unjittered by
  `projElement[0].zw * screenInverseSize * 0.5`. Velocity is read at the nearest-depth pixel of a
  5-tap cross (reverse Z: min of 1 - depth), and prevUV = uv + (v.x * 0.5, -v.y * 0.5): the same
  mvScale as RE2 (0.5, -0.5).
- **SceneInfo is 512 bytes**, with RE2's layout and offsets. Values in this frame: projElement[0] at
  byte 160 = (1.5697, 2.7906, **jitter 4.56e-5, -1.26e-4** clip), screenSize at 368 = 3840 2160 (render
  size), cameraNearPlane at 392 = 0.2, far 1000. RE2DLSS's kSceneInfoFloats 132 (528 bytes) becomes 128.
- **Stretch psaff99b25**: `t0 ReadonlyDepth`, `t1 SrcImage`, SceneInfo; writes SV_Target + SV_Depth (the
  4K depth the HUD tests against). So it must still run; then our image goes over its colour.
- **Sharpen psae40e1ff**: `t0 HDRImage`, `t1 tUIMask` (r8, written by the HUD draws), SceneInfo only
  (no sharpness value in a cb). It sharpens the scene and leaves pixels under the HUD alone.
- **Output psca880db5** (and tonemap ps25016cc3): the dumped bytecode has no RDEF (these are RenoDX's
  replacements). The output samples only t0, so the render-size t1 in the captures is unused.
- Bloom composite ps629a5b35: `t0 texSrc`, cbSoftBloom / cbCone / cbSoftBloomScale.

### HUD (capture 3)

After the tonemap (into the output-size target #dd009):
1. ps83760deb copies #dd009 to #d294e, which is a **pre-HUD snapshot** (useful for frame generation's HUD-less
   image later).
2. HUD draws (5-index quads) go into #dd009 plus the r8 UI mask #daafb: psb175f8ff, ps146ff5e5,
   pse9a72b8b, ps5225e81f.
3. Sharpen psae40e1ff (t1 = UI mask) writes #25904, ps83760deb copies it back to #dd009, then the
   output pass runs.

The HUD is drawn at output size after the stretch, so it needs nothing from us when upscaling.

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
   r32g8 view. SceneInfo: kSceneInfoFloats 128 (512 bytes); the other offsets stay as RE2's.
   Motion vectors scale (0.5, -0.5) as RE2.
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

## 0.1.0 test (2026-11-14)

DLSS ran with no errors: DLAA 3840x2160 (model K), 2561x1440, 2227x1252 (K), 1920x1080 (M) -> 3840x2160,
switched live via the Lua render resolution dropdown (REFramework TDB 67 build works). RenoDX on.
User: the lighting looks different at Performance. Screenshots (same spot): Performance mean
luma 27.5 vs DLAA 31.1 (~12% darker), bloom present but the scene's lighting lower. Same as
VillageDLSS 1.1.0: in-place bloom left the render-size TAA output without bloom, and the game
reads it again (likely its exposure).

0.1.1: kBloomAlsoAtRenderSize (Village's fix): bloom drawn into X by us, and the game's own draw still
goes into its render-size image.

## 0.1.1 test (2026-11-14)

Clean log (DLAA, 67%, 50% switched live). User: bloom brighter at Performance than DLAA, but
Performance with DLSS and Performance with F9 off (game's own TAA + stretch at 50%) look the same.
So the stronger bloom at low render scales is the game's own behaviour, and 0.1.1 is right. (The
game's exposure is measured by csc4ba72ae -> cs4b2f7214 from the TAA history copy, which is made
before bloom; the render-size image after bloom is read only by the tonemap.)

## RenoDX / GITC Uplift off (2026-11-14, 0.1.2)

Only DMC5DLSS loaded (RenoDX and GITC Uplift both off). DLAA fine. Upscaling: "tonemap pass not
found": without RenoDX the game's own tonemap has another id (ps25016cc3 is RenoDX's replacement),
so the game's own upscaling was used (looked fine, but no DLSS upscaling). GITC Uplift being off
made no difference to NGX (DLSS also ran with it on).

0.1.3: the tonemap is also recognised by its place in the chain (first full-screen draw after the
bloom composite reading the TAA output at t0); its id is logged once. The fallback log line is
logged once instead of every frame.

0.1.3 test (RenoDX off): tonemap found by place = **ps04c20211** (the game's own); DLSS upscaling
1920x1080 -> 3840x2160 ran with it. One "not found" right at the first 50% frame (a single
fallback frame on the switch). 0.1.4: ps04c20211 added as kTonemapPs2 (the structural match stays
as a fallback).

## FSR test (2026-11-14, 0.1.4, RenoDX on)

FSR 3.1.6 (runtime offers 3.1.6, 2.3.4) ran native AA 3840x2160 and 2561x1440 / 2227x1252 /
1920x1080 -> 3840x2160, no errors; Auto switched back to DLSS. Exposure auto, no reactive mask.

Found in the same log: the 0.1.3 structural tonemap match fired on pseb1e43cf (bloom downsample)
and ps133ccce0, alternating, for ~4 s (some scene where the chain order differs; the pass that
actually tonemaps there wasn't ps25016cc3). 0.1.5: the match must be the full-screen draw right
after the bloom composite, reading the TAA output at t0 and writing another target of its size.
Also one "tonemap not found" fallback earlier in that run.

## Cutscene / title menu (2026-11-14, captures 4-5, Performance, RenoDX on)

`docs/captures/DMC5DLSS-frame-4-menu.txt` (opening cutscene) and `-5-menu.txt` (title menu).
Both use the game's own tonemap **ps04c20211** even with RenoDX on.

- Cutscene: TAA -> #8fa3c, then **depth of field**: cs8be0eec5, csa9210538, csee42d8f1, csc2e129d2,
  csbff83cd3, cs527426e9 (tiles, 960x540 near/far layers) and the composite **ps58dcc2f3** (t2 = TAA
  output, t0/t1 960x540 layers, t3 1920x1080 rgba16f, t4 60x34 tiles, t5 960x540 r8) -> #8fc07. Bloom
  is built from #8fc07 and composited into it, then a **glare** (csa2a251a3, csfe482a42, cs219a69ea on
  1024x512 rgba16f -> **ps8f6eaed0** additive), then the tonemap reads #8fc07.
- Title menu: no depth of field; bloom and glare go into the TAA output, then the tonemap.
- ps133ccce0 runs before the TAA (reads the colour, writes #91356): not a post pass, so 0.1.3's match
  on it was wrong.

0.1.6: the glare is drawn into X as well (like bloom). Frames where the tonemap doesn't read the TAA
output (depth of field) use the game's own upscaling for now (DLAA unaffected). ReShade.ini
DumpShaders set for the DoF passes, glare, ps04c20211, ps133ccce0 (for depth of field at output size).

## 0.1.6 test and depth of field at output size (0.2.0)

0.1.6 log: the cutscene used the fallback, the title menu ran DLSS upscaling with the glare drawn
into X. DoF shaders dumped (docs/shaders): **ps58dcc2f3** = DoF composite: t0 CoC, t1 Image (blurred,
960x540), **t2 HDRImage (TAA output, `ld` at the pixel)**, t3 BlendImage, t4 Neighbor, t5 DOFAImage;
cb0 SceneInfo, cb1 dof. UV = (pixel + 0.5) * SceneInfo.screenInverseSize for everything but t2,
so it runs at output size with an output-size SceneInfo. Glare ps8f6eaed0 samples its 1024x512
texture by texture coordinates (TexturePosScaleFactor).

0.2.0: OnDof draws the DoF composite at output size from X into W (SceneInfo copy, t2 -> X), then
averages W down (blit.hlsl PsDown) into the game's render-size target for its bloom pyramid, and
skips the game's draw. Bloom, glare and the tonemap follow the "scene" image (g_up.scene /
sceneOut: the TAA output or the DoF target). Frames with an unknown pass between TAA and tonemap
still fall back to the game's upscaling.

0.2.0 test (2026-11-14): log "depth of field drawn at output size (3840x2160)", glare into the
scene image, DLSS 1920x1080 -> 3840x2160 through the opening cutscene. User: looked right. Left:
one "unknown pass" fallback during startup (logos/loading at 3728x2097) and the single
"tonemap not found" frame at a scene change.

## Frame generation (0.3.0, 2026-11-14)

DLSS-G: user "everything worked great" (log overwritten by the next run).

FSR FG (FrameGenTech FSR, 2x, after a restart): on screen the picture appeared **three times in
three side-by-side columns**; FG off fixed it. ReShade screenshots look whole (taken before FSR's
swapchain). Log (docs/captures/fsrfg-3columns.log): swapchain made through FSR; FSR FG context
first 3840x2160 format 28 (the game's first back buffer, rgba8), the game then ResizeBuffers to
format 24, briefly to **3840x2097** (render height) and back; contexts recreated each time, last
3840x2160 format 24, "HUD told apart with the picture before the HUD", no errors. Colour space seen
as SDR (ReShade enum 1), so FSR FG was set up SDR. Exclusive fullscreen on. Cause not known yet.
