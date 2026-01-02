//
//  render.metal
//  SDF_Render
//
//  Created by Elina Williams on 25/12/2025.
//

#include <metal_stdlib>
#include "ShaderTypes.h"
using namespace metal;

// SDF rendering with resolution scaling
kernel void renderSDFScaled(
    texture2d<float, access::sample> sdfTex [[texture(0)]],
    texture2d<float, access::write> outputTex [[texture(1)]],
    sampler sdfSampler [[sampler(0)]],
    constant Uniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint width = outputTex.get_width();
    uint height = outputTex.get_height();
        
    if (gid.x >= width || gid.y >= height) return;
        
    float2 uv = float2(gid) / float2(width, height);
                
    // Sample SDF
    float sdfValue = sdfTex.sample(sdfSampler, uv).r;
        
    // Convert from [0, spread] to [-spread, +spread]
    sdfValue = 2.0f * sdfValue - uniforms.spread;
    // sdfValue = (sdfValue * 2.0f - 1.0f) * spread;
       
    // Anti-aliasing
    float alpha = 1.0f - smoothstep(0.0f, uniforms.edgeWidth, -sdfValue);
       
    float4 color = uniforms.fillColor;
    color.a *= alpha;
        
    outputTex.write(color, gid);
}
