//
//  ShaderTypes.h
//  2D_SDFGenerator
//
//  Created by Elina Williams on 02/01/2026.
//

#ifndef ShaderTypes_h
#define ShaderTypes_h

#include "simd/simd.h"

typedef struct {
    simd_float4 fillColor;
    float spread;
    float edgeWidth; //px
} Uniforms;

#endif /* ShaderTypes_h */
