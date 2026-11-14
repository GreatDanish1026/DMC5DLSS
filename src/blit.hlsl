// Copies the output-size image over the game's output target with a full-screen triangle: the
// render target write converts the format (the game's post chain is r11g11b10f at some render
// scales, its output target rgba16f), which a plain GPU copy can't.
// PsDown: the same, into a smaller target (the output-size depth of field image back into the
// game's render-size one, for its bloom): a 4-tap average around each target pixel's footprint.

Texture2D<float4> Source : register(t0);

void VsMain(uint id : SV_VertexID, out float4 pos : SV_Position, out float2 uv : TEXCOORD0) {
    uv = float2((id << 1) & 2, id & 2);
    pos = float4(uv * float2(2, -2) + float2(-1, 1), 0, 1);
}

float4 PsMain(float4 pos : SV_Position) : SV_Target {
    return Source.Load(int3(pos.xy, 0));
}

float4 PsDown(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target {
    float2 dim;
    Source.GetDimensions(dim.x, dim.y);
    const float2 step = dim * float2(ddx(uv.x), ddy(uv.y));  // source texels per target pixel
    const float2 c = uv * dim;
    const float2 o = abs(step) * 0.25;
    const int2 hi = int2(dim) - 1;
    float4 sum = Source.Load(int3(clamp(int2(c + float2(-o.x, -o.y)), 0, hi), 0));
    sum += Source.Load(int3(clamp(int2(c + float2(o.x, -o.y)), 0, hi), 0));
    sum += Source.Load(int3(clamp(int2(c + float2(-o.x, o.y)), 0, hi), 0));
    sum += Source.Load(int3(clamp(int2(c + float2(o.x, o.y)), 0, hi), 0));
    return sum * 0.25;
}
