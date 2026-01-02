//
//  PFMTextureLoader.m
//  2D_SDFGenerator
//
//  Created by Elina Williams on 30/12/2025.
//

#import "PFMTextureLoader.h"
#import "PFMTools.hpp"
#import <string>

NS_ASSUME_NONNULL_BEGIN

// C++ -> Objective-C error convertor
static NSError* _createError(const std::string& domain, int code, const std::string& message)
{
    NSString *nsMessage = [NSString stringWithUTF8String:message.c_str()];
    return [NSError errorWithDomain:[NSString stringWithUTF8String:domain.c_str()]
                               code:code
                           userInfo:@{NSLocalizedDescriptionKey: nsMessage}];
}

// Check suffix
static char* ensure_pfm_suffix(const char* path) {
    if(path == NULL) return strdup("");
    size_t len = strlen(path);
    // length for '.pfm'
    if (len >= 4) {
        const char* suffix = path + len - 4;
        if (strcmp(suffix, ".pfm") == 0) return strdup(path);
    }
    // Check if any extension already exists (traverse backwards)
    const char*  last_dot  = strrchr(path, '.');
    const char* last_slash = strrchr(path, '/');
    // If no dot is found, or the dot is before the last slash (i.e., part of a directory name, not an extension)
    // then treat it as a filename without an extension.
    int has_extension = 0;
    if (last_dot != NULL) {
        // If a slash exists, ensure the dot comes after it
        if (last_slash == NULL) {
            // No slash, dot indicates an existing extension
            has_extension = 1;
        } else if (last_dot > last_slash) {
            // Dot is after the last slash, indicating an existing extension
            has_extension = 1;
        }
    }
    char* result = NULL;
    if(has_extension)
    {
        // Already has a different extension: remove the original and append .pfm
        printf("Invalid suffix, replaced by .pfm automatically\n");
        size_t base_len = last_dot - path;
        result = (char*) malloc(base_len + 4 + 1); // ".pfm" + '\0'
        if (result) snprintf(result, base_len + 5, "%.*s.pfm", (int)base_len, path);
    } else {
        // No extension: directly append .pfm
        result = (char*) malloc(len + 4 + 1);
        if (result) snprintf(result, len + 5, "%s.pfm", path);
    }
    return result;
}


@implementation PFMTextureLoader

+ (nullable id<MTLTexture>)createTextureFromPath:(const char *)path
                                          device:(id<MTLDevice>)device
                                          scaler:(float *)scaler
                                           error:(NSError **)error
{
    if (!path || !device) {
        if (error) *error = _createError("PFMTextureLoader", -1, "Invalid parameters");
        return nil;
    }
    
    try {
        std::string cPath = std::string(ensure_pfm_suffix(path));
        
        PFM::Reader reader;
        PFM::PFMData data = reader.loadFromFile(cPath);
        
        if(!data.isValid()) {
            if (error) *error = _createError("PFMTextureLoader", -3, "Empty PFM data");
            return nil;
        }
        
        *scaler = data.scaler;
               
        MTLTextureDescriptor *descriptor = [MTLTextureDescriptor
                    texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                    width:data.width
                    height:data.height
                    mipmapped:NO];
                
        descriptor.storageMode = MTLStorageModeManaged;
        descriptor.usage = MTLTextureUsageShaderRead;
                
        @try {
            id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
            if (!texture) {
                if (error) *error = _createError("PFMTextureLoader", -6, "Failed to create Metal texture");
                return nil;
            }
            
            [texture replaceRegion:MTLRegionMake2D(0, 0, data.width, data.height)
                       mipmapLevel:0
                         withBytes:data.pixels.data()
                       bytesPerRow:data.width * sizeof(float)];
            
            return texture;
        }
        @catch(NSException *exception) {
            if (error) *error = _createError("PFMTextureLoader", -8,
                                            [[NSString stringWithFormat:@"Metal API error: %@", exception.reason] UTF8String]);
            return nil;
        }
    }
    catch(const std::exception& e) {
        if (error) *error = _createError("PFMTextureLoader", -4, e.what());
        return nil;
    }
    catch (...) {
        if (error) *error = _createError("PFMTextureLoader", -5, "Unknown C++ exception");
        return nil;
    }
}


+ (BOOL) savePFMDataFromTexture:(id<MTLTexture>)texture
                           path:(const char *)path
                         scaler:(float)scaler
                          error:(NSError **)error
{
    
    if (!texture || texture.pixelFormat != MTLPixelFormatR32Float)
    {
        if (error) *error = _createError("PFMError", -5, "Invalid texture format");
        return NO;
    }
    
    try {
        std::string cPath = std::string(ensure_pfm_suffix(path));
        
        NSUInteger width = texture.width;
        NSUInteger height = texture.height;
        
        if (width > UINT32_MAX || height > UINT32_MAX) {
            if (error) {
                *error = _createError("PFMError", -8, "Texture dimensions too large");
            }
            return NO;
        }
        
        NSUInteger bytesPerRow = width * sizeof(float);
//        NSUInteger dataSize = height * bytesPerRow;
        
        std::vector<float> pixels(width * height);
        
        @try {
            [texture getBytes:pixels.data()
                  bytesPerRow:bytesPerRow
                   fromRegion:MTLRegionMake2D(0, 0, width, height)
                  mipmapLevel:0];
        }
        @catch (NSException *exception) {
            if (error) {
                *error = _createError("PFMError", -10,
                                     [[NSString stringWithFormat:@"Metal operation failed: %@", exception.reason] UTF8String]);
            }
            return NO;
        }
        
        PFM::PFMData data = {
            static_cast<uint32_t>(width),
            static_cast<uint32_t>(height),
            scaler,
            std::move(pixels)
        };

        bool success = PFM::Reader::saveToFile(cPath, data);

        return success ? YES : NO;
    }
    catch (const std::exception& e) {
        if (error) *error = _createError("PFMError", -4, e.what());
        return NO;
    }
    catch (...) {
        if (error) *error = _createError("PFMError", -11, "Unknown C++ exception");
        return NO;
    }
}


@end

NS_ASSUME_NONNULL_END
