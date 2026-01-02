//
//  SDFRenderer.m
//  SDF_Render
//
//  Created by Elina Williams on 25/12/2025.
//

#import "SDFRenderer.h"
#import <Metal/Metal.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "../PFMTextureLoader.h"
@import CoreGraphics;
@import CoreImage;

@implementation SDFRenderer {
    id<MTLDevice> _device;
    id<MTLComputePipelineState> _renderPipelineState;
    id<MTLTexture> _sdfTexture;
    id<MTLTexture> _outputTextureRGBA;
    
    NSUInteger _inputWidth;
    NSUInteger _inputHeight;
    NSUInteger _outputWidth;
    NSUInteger _outputHeight;
    uint8_t *_pixelBuffer;
    float scaler;
}

- (instancetype) initWithDevice:(id<MTLDevice>)device
                       filePath:(const char *) path
{
    self = [super init];
    if (self) {
        _device = device;
        
        if (![self initialiseTextures:path]) {
            return nil;
        }
        
        _inputWidth  =  _sdfTexture.width;
        _inputHeight = _sdfTexture.height;
        _pixelBuffer = NULL;
        
        if (![self setupMetal]) {
            return nil;
        }
    }
    return self;
}

- (BOOL)setupMetal {
    NSError *error = nil;
    
    // Load Metal library
    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
    if (!defaultLibrary) {
        NSLog(@"Failed to load default Metal library");
        return NO;
    }
    
    // Load render kernel function
    id<MTLFunction> renderFunction = [defaultLibrary newFunctionWithName:@"renderSDFScaled"];
    if (!renderFunction) {
        NSLog(@"Failed to load renderSDFScaled function");
        return NO;
    }
    
    // Create pipeline state
    _renderPipelineState = [_device newComputePipelineStateWithFunction:renderFunction error:&error];
    if (error) {
        NSLog(@"Failed to create render pipeline state: %@", error);
        return NO;
    }
    
    return YES;
}

- (BOOL) initialiseTextures: (const char*) path {
    // Create SDF texture (single channel float)
    NSError *error = nil;
    _sdfTexture = [PFMTextureLoader createTextureFromPath:path device:_device
                                    scaler:&scaler error:&error];
    
    if (error) {
        NSLog(@"Failed to load PFM: %@", error);
    }
    
    return (_sdfTexture != nil);
}

- (void)createOutputTextureWithScale:(float)outputScale
{
    // Calculate output dimensions
    _outputWidth =  (NSUInteger)(_inputWidth  * outputScale);
    _outputHeight = (NSUInteger)(_inputHeight * outputScale);
    
    // Create output texture (RGBA8Unorm for display)
    MTLTextureDescriptor *outputDescriptor = [MTLTextureDescriptor
        texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm
                                     width:_outputWidth
                                    height:_outputHeight
                                 mipmapped:NO];
    
    outputDescriptor.usage = MTLTextureUsageShaderWrite | MTLTextureUsageShaderRead;
    _outputTextureRGBA = [_device newTextureWithDescriptor:outputDescriptor];
}


- (BOOL)renderSDFWithFillColorRed:(float)r
                            green:(float)g
                             blue:(float)b
                            alpha:(float)a
                      outputScale:(float)outputScale
{
    // Create output texture with desired scale
    [self createOutputTextureWithScale:outputScale];
    
    // Create command queue and buffer
    id<MTLCommandQueue> commandQueue = [_device newCommandQueue];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    
    [encoder setComputePipelineState:_renderPipelineState];
    
    Uniforms uniforms;
    uniforms.fillColor = (float4){r, g, b, a};
    uniforms.spread = 1.0f / scaler;
    uniforms.edgeWidth = 2.0f; //px
    
    [encoder setBytes:&uniforms length:sizeof(Uniforms) atIndex:0];
    
    // Set textures
    [encoder setTexture:_sdfTexture atIndex:0];        // Input SDF
    [encoder setTexture:_outputTextureRGBA atIndex:1]; // Output RGBA
    
    // Configure sampler for linear interpolation
    MTLSamplerDescriptor *samplerDesc = [MTLSamplerDescriptor new];
    samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
    samplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
    
    id<MTLSamplerState> sampler = [_device newSamplerStateWithDescriptor:samplerDesc];
    [encoder setSamplerState:sampler atIndex:0];
    
    // Dispatch compute kernel
    NSUInteger threadgroupWidth  = 16;
    NSUInteger threadgroupHeight = 16;
    MTLSize threadgroupSize = MTLSizeMake(threadgroupWidth, threadgroupHeight, 1);
    
    NSUInteger threadgroupCountX = (_outputWidth + threadgroupWidth - 1) / threadgroupWidth;
    NSUInteger threadgroupCountY = (_outputHeight + threadgroupHeight - 1) / threadgroupHeight;
    MTLSize threadgroupCount = MTLSizeMake(threadgroupCountX, threadgroupCountY, 1);
    
    [encoder dispatchThreadgroups:threadgroupCount threadsPerThreadgroup:threadgroupSize];
    
    [encoder endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
    
    // Read result back to CPU
    return [self readOutputToBuffer];
}

- (BOOL) readOutputToBuffer {
    // Allocate pixel buffer
    size_t bufferSize = _outputWidth * _outputHeight * 4;
    _pixelBuffer = (uint8_t *) malloc(bufferSize);
    
    if (!_pixelBuffer) {
        return NO;
    }
    
    // Read from output texture
    MTLRegion region = MTLRegionMake2D(0, 0, _outputWidth, _outputHeight);
    [_outputTextureRGBA getBytes:_pixelBuffer
                     bytesPerRow:_outputWidth * 4
                      fromRegion:region
                     mipmapLevel:0];
    
    return YES;
}

- (BOOL)saveToPNG:(const char *)filename {
    if (!_pixelBuffer) {
        return NO;
    }
    
    // Create CGImage from pixel data
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    if (!colorSpace) {
        return NO;
    }
    
    CGContextRef context = CGBitmapContextCreate(
        _pixelBuffer,
        _outputWidth,
        _outputHeight,
        8, // bits per component
        _outputWidth * 4, // bytes per row
        colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big
    );
    
    if (!context) {
        CGColorSpaceRelease(colorSpace);
        return NO;
    }
    
    CGImageRef imageRef = CGBitmapContextCreateImage(context);
    if (!imageRef) {
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        return NO;
    }
    
    // Write to PNG file
    CFURLRef url = CFURLCreateFromFileSystemRepresentation(
        NULL,
        (const UInt8 *)filename,
        strlen(filename),
        false
    );
    
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL(
        url,
        (__bridge CFStringRef)UTTypePNG.identifier,
        1,
        NULL
    );
    
    if (!destination) {
        CGImageRelease(imageRef);
        CGContextRelease(context);
        CGColorSpaceRelease(colorSpace);
        CFRelease(url);
        return NO;
    }
    
    CGImageDestinationAddImage(destination, imageRef, NULL);
    BOOL success = CGImageDestinationFinalize(destination);
    
    // Cleanup
    CFRelease(destination);
    CGImageRelease(imageRef);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CFRelease(url);
    
    return success;
}

- (void) dealloc
{
    if (_pixelBuffer) {
        free(_pixelBuffer);
    }
}

@end
