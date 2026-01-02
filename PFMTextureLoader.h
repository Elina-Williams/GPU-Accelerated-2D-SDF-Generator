//
//  PFMTextureLoader.h
//  2D_SDFGenerator
//
//  Created by Elina Williams on 30/12/2025.
//

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

// Bridge file for C++
NS_ASSUME_NONNULL_BEGIN

@interface PFMTextureLoader : NSObject

+ (nullable id<MTLTexture>)createTextureFromPath:(const char *)path
                                          device:(id<MTLDevice>)device
                                          scaler:(float *)scaler
                                           error:(NSError **)error;

+ (BOOL) savePFMDataFromTexture:(id<MTLTexture>)texture
                           path:(const char *)path
                         scaler:(float)scaler
                          error:(NSError **)error;



@end

NS_ASSUME_NONNULL_END
