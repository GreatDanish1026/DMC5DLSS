// The game's velocity (NDC offset to the previous position, y up) includes this frame's jitter:
// its velocity pass rebuilds each pixel's position with the jittered viewProjInv and projects it
// with the unjittered prevViewProj. DLSS and FSR want motion without the jitter, in render pixels:
//   motion = velocity * (0.5 w, -0.5 h) + jitter (render pixels, the same sign the upscaler gets).
// Devil May Cry 5 keeps the velocity in .yz (its velocity pass writes (1, x, y, 1) and its TAA reads
// .yz); the RE games in .xy.

cbuffer Params : register(b0) {
    float2 Scale;   // (0.5 w, -0.5 h)
    float2 Offset;  // the jitter in render pixels (0: left in)
    uint2 Size;
    uint YzChannels;  // 1: the velocity is in .yz
    uint Pad;
};

Texture2D<float4> Velocity : register(t0);
RWTexture2D<float2> Motion : register(u0);

[numthreads(8, 8, 1)]
void main(uint2 id : SV_DispatchThreadID) {
    if (any(id >= Size)) return;
    const float4 v = Velocity[id];
    Motion[id] = (YzChannels ? v.yz : v.xy) * Scale + Offset;
}
