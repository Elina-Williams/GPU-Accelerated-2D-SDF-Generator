//
//  SDFRenderer.h
//  SDF_Render
//
//  Created by Elina Williams on 25/12/2025.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <simd/simd.h>
#import "ShaderTypes.h"
typedef simd_float4 float4;
typedef simd_float2 float2;

NS_ASSUME_NONNULL_BEGIN

@interface SDFRenderer : NSObject

@property (nonatomic, readonly) NSUInteger inputWidth;
@property (nonatomic, readonly) NSUInteger inputHeight;
@property (nonatomic, readonly) NSUInteger outputWidth;
@property (nonatomic, readonly) NSUInteger outputHeight;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                      filePath:(const char *) path;

// Render SDF with parameters
- (BOOL)renderSDFWithFillColorRed:(float)r
                            green:(float)g
                             blue:(float)b
                            alpha:(float)a
                      outputScale:(float)outputScale;

// Save to PNG
- (BOOL)saveToPNG:(const char *)filename;

@end

NS_ASSUME_NONNULL_END
