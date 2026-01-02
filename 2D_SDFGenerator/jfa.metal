//
//  jfa.metal
//  2D_SDFGenerator
//
//  Created by Elina Williams on 25/12/2025.
//

#include <metal_stdlib>
using namespace metal;

#define INF 1e9
#define THRESHOLD 128

//MARK: JFA Kernel
kernel void jfaStep(
    constant uint& step [[buffer(0)]],
    constant int2 *neighbourOffsets [[buffer(1)]],
    texture2d<float, access::read>  inputTex  [[texture(0)]],
    texture2d<float, access::write> outputTex [[texture(1)]],
    uint2 gid [[thread_position_in_grid]])
{
    uint width = inputTex.get_width();
    uint height = inputTex.get_height();
    
    if (gid.x >= width || gid.y >= height) return;
    
    float2 currentPos = float2(gid);
    float4 currentData = inputTex.read(gid);
    float2 bestPos = currentData.xy;
    float bestDistSq = currentData.z;
    
//    const int2 offsets[9] = {
//        int2(-1, -1), int2(0, -1), int2(1, -1),
//        int2(-1, 0),  int2(0, 0),  int2(1, 0),
//        int2(-1, 1),  int2(0, 1),  int2(1, 1)
//    };
    
    int stepInt = int(step);
    
    // Check 8 neighbours + self
    for (int i = 0; i < 9; ++i) {
        const int2 neighbourCoord = int2(gid) + neighbourOffsets[i] * stepInt;
        
        // Border Ckeck
        if (any(neighbourCoord < 0) ||
                neighbourCoord.x >= int(width) ||
                neighbourCoord.y >= int(height))
        {
            continue;
        }
        
        const float4 candidateData = inputTex.read(uint2(neighbourCoord));
                
        if (candidateData.z >= INF) continue;
                
        const float2 delta = currentPos - candidateData.xy;
        const float distSq = dot(delta, delta);
        
        if (distSq < bestDistSq) {
            bestDistSq = distSq;
            bestPos = candidateData.xy;
        }
    }
    
    // Write result
    outputTex.write(float4(bestPos, bestDistSq, 0.0), gid);
}


// MARK: Combine Kernel
// Combine kernel: merges exterior and interior distances into SDF
kernel void combineSDF(
    constant float &spread [[buffer(0)]],
    texture2d<uint, access::read> originalTex [[texture(0)]],    // Original binary image
    texture2d<float, access::read> exteriorTex [[texture(1)]],   // Exterior distances
    texture2d<float, access::read> interiorTex [[texture(2)]],   // Interior distances
    texture2d<float, access::write> outputTex [[texture(3)]],    // Output SDF
    uint2 gid [[thread_position_in_grid]])
{
    uint width = originalTex.get_width();
    uint height = originalTex.get_height();
    
    if (gid.x >= width || gid.y >= height) return;
    
    // Read original pixel value (0-255)
    uint originalValue = originalTex.read(gid).r;
        
    float exteriorDist = exteriorTex.read(gid).z;
    float interiorDist = interiorTex.read(gid).z;
    exteriorDist = sqrt(exteriorDist);
    interiorDist = sqrt(interiorDist);
                
    // Determine if pixel is inside or outside
    // Convention: white (255) = object, black (0) = background
     bool isInside = (originalValue > THRESHOLD);
        
    // Combine according to SDF convention:
    // - Positive outside object
    // - Negative inside object
    // - Zero at boundary
     float sdfValue = (isInside) ? interiorDist : -exteriorDist;
        
    // Clamp the distance value to [-spread, spread]
    sdfValue = clamp(sdfValue, -spread, spread);
    // sdfValue = sdfValue / spread;
    
    // Write SDF value (single channel)
    outputTex.write(float4(sdfValue, 0.0, 0.0, 1.0), gid);
}
