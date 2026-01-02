//
//  downSampling.metal
//  2D_SDFGenerator
//
//  Created by Elina Williams on 28/12/2025.
//

#include <metal_stdlib>
using namespace metal;

// Happy new year - 2026
kernel void downsampleSDFAreaAverage(
    constant float &spread [[buffer(0)]],
    texture2d<float, access::read> highResSDF [[texture(0)]],
    texture2d<float, access::write> lowResSDF [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint lowWidth = lowResSDF.get_width();
    uint lowHeight = lowResSDF.get_height();
    
    if (gid.x >= lowWidth || gid.y >= lowHeight) return;
    
    uint highWidth = highResSDF.get_width();
    uint highHeight = highResSDF.get_height();
    
    float scaleX = float(highWidth) / float(lowWidth);
    float scaleY = float(highHeight) / float(lowHeight);
    
    uint startX = uint(float(gid.x) * scaleX);
    uint startY = uint(float(gid.y) * scaleY);
    uint endX = uint(float(gid.x + 1) * scaleX);
    uint endY = uint(float(gid.y + 1) * scaleY);
    
    // Calculate average
    float sum = 0.0f;
    uint count = 0;
    
    for (uint hy = startY; hy < endY; ++hy) {
        for (uint hx = startX; hx < endX; ++hx) {
            float dist = highResSDF.read(uint2(hx, hy)).r;
            sum += dist;
            count++;
        }
    }
    
    float avgDist = sum / float(count);
    
    // normalised to [0, spread]
    float normalised = (avgDist + spread) / 2;
    // float normalised = avgDist * 0.5f + 0.5f;
    lowResSDF.write(float4(normalised, 0.0, 0.0, 1.0), gid);
}


kernel void fastDownsampleSDFAreaAverage(
    constant float &spread [[buffer(0)]],
    texture2d<float, access::sample> highResSDF [[texture(0)]],
    texture2d<float, access::write> lowResSDF [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    constexpr sampler bilinearSampler(coord::pixel,
                                      address::clamp_to_edge,
                                      filter::linear);
        
    const float2 lowSize = float2(lowResSDF.get_width(), lowResSDF.get_height());
    const float2 highSize = float2(highResSDF.get_width(), highResSDF.get_height());
        
    const float2 uv = (float2(gid) + 0.5f) / lowSize;
    const float2 samplePos = uv * highSize - 0.5f;
        
    const float sampled = highResSDF.sample(bilinearSampler, samplePos).r;
    // normalised to [0, spread]
    float normalised = (sampled + spread) / 2;
    // float normalised = avgDist * 0.5f + 0.5f;
    lowResSDF.write(float4(normalised, 0.0, 0.0, 1.0), gid);
}
