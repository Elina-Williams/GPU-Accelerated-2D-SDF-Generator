//
//  JFAExecutor.h
//  2D_SDFGenerator
//
//  Created by Elina Williams on 25/12/2025.
//

#import <Foundation/Foundation.h>
#import "simd/simd.h"
#include "../PFMTextureLoader.h"
@import Metal;

typedef simd_int2 int2;

NS_ASSUME_NONNULL_BEGIN

@interface SDFExecutor : NSObject

@property (nonatomic, readonly) NSUInteger Iwidth;
@property (nonatomic, readonly) NSUInteger Iheight;
@property (nonatomic, readonly) NSUInteger Owidth;
@property (nonatomic, readonly) NSUInteger Oheight;
@property (nonatomic, readonly) NSUInteger spread;

- (instancetype)initWithDevice:(id<MTLDevice>)device
                    InputWidth:(NSUInteger)width_i
                   InputHeight:(NSUInteger)height_i
                   OutputWidth:(NSInteger)width_o
                  OutputHeight:(NSInteger)height_o
                        spread:(NSInteger)spread;

// Generate SDF from binary image (white pixels = seeds)
- (BOOL)generateSDFFromImage:(const uint8_t *)imageData
                 threshold:(uint8_t)threshold
                outputBuffer:(float *) outputBuffer;

-(BOOL) saveSDFToPFM:(const char *) filename;

@end

NS_ASSUME_NONNULL_END
