//
//  JFAExecutor.m
//  2D_SDFGenerator
//
//  Created by Elina Williams on 25/12/2025.
//

#import "SDFExecutor.h"

NS_ASSUME_NONNULL_BEGIN

const int2 offsets[9] = {
    {-1, -1}, {0, -1}, {1, -1},
    {-1, 0},  {0, 0},  {1, 0},
    {-1, 1},  {0, 1},  {1, 1}
};

@implementation SDFExecutor {
    id<MTLDevice> _device;
    id<MTLComputePipelineState> _jfaPipelineState;
    id<MTLComputePipelineState> _combinePipelineState;
    id<MTLComputePipelineState> _downsamplePipelineState;
    
    // Texture for the first pass (exterior distance)
    id<MTLTexture> _exteriorTextureA;
    id<MTLTexture> _exteriorTextureB;
    
    // Texture for the second pass (interior distance)
    id<MTLTexture> _interiorTextureA;
    id<MTLTexture> _interiorTextureB;
    
    // Result texture for combined SDF
    id<MTLTexture> _resultTexture;
    
    // Output texture with lower resolution
    id<MTLTexture> _outputTexture;
    
//    float *_sdfBuffer;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device
                    InputWidth:(NSUInteger)width_i
                   InputHeight:(NSUInteger)height_i
                   OutputWidth:(NSInteger)width_o
                  OutputHeight:(NSInteger)height_o
                        spread:(NSInteger)spread
{
    self = [super init];
    if (self) {
        _device = device;
        _Iwidth  = width_i;
        _Owidth = width_o;
        _Iheight = height_i;
        _Oheight = height_o;
        if(spread > MAX(width_o, height_o)) {
            _spread = MAX(width_o, height_o);
        }
        _spread = spread;
        
        // Create compute pipeline
        if (![self createPipelineState]) {
            return nil;
        }
                
        // Create textures
        if (![self createTextures]) {
            return nil;
        }
    }
    return self;
}


-(BOOL) createPipelineState {
    NSError *error = nil;
    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
        
    if (!defaultLibrary) {
        NSLog(@"Failed to load default Metal library");
        return NO;
    }
        
    // Load JFA kernel function
    id<MTLFunction> jfaFunction = [defaultLibrary newFunctionWithName:@"jfaStep"];
    if (!jfaFunction) {
        NSLog(@"Failed to load jfaStep function");
        return NO;
    }
        
    // Create JFA pipeline state
    _jfaPipelineState = [_device newComputePipelineStateWithFunction:jfaFunction error:&error];
    if (error) {
        NSLog(@"Failed to create pipeline state");
        return NO;
    }
    
    // Load combine kernel function
    id<MTLFunction> combineFunction = [defaultLibrary newFunctionWithName:@"combineSDF"];
    if (!combineFunction) {
        NSLog(@"Failed to create pipeline state");
        return NO;
    }
    
    // Create combine pipeline state
    _combinePipelineState = [_device newComputePipelineStateWithFunction:combineFunction error:&error];
    if (error) {
        NSLog(@"Failed to load jfaStep function");
        return NO;
    }
    
    // Load downsampling kernel function
    id<MTLFunction> samplingFunction = [defaultLibrary newFunctionWithName:@"fastDownsampleSDFAreaAverage"];
    if (!samplingFunction) {
        NSLog(@"Failed to load downsampleSDFMinAbs function");
        return NO;
    }
    
    // Create downsampling pipeline state
    _downsamplePipelineState = [_device newComputePipelineStateWithFunction:samplingFunction error:&error];
    if (error) {
        NSLog(@"Failed to create pipeline state");
        return NO;
    }
    
    return YES;
}

// MARK: Create empty texture A and B with size (_width, _height)
-(BOOL) createTextures {
    MTLTextureDescriptor *textureDescriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA32Float
                                         width:_Iwidth
                                        height:_Iheight
                                     mipmapped:NO];
    
    textureDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
        
    _exteriorTextureA = [_device newTextureWithDescriptor:textureDescriptor];
    _exteriorTextureB = [_device newTextureWithDescriptor:textureDescriptor];
    _interiorTextureA = [_device newTextureWithDescriptor:textureDescriptor];
    _interiorTextureB = [_device newTextureWithDescriptor:textureDescriptor];
    
    // Single Channel texture for SDF
    MTLTextureDescriptor *resultDescriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                 width:_Iwidth
                                height:_Iheight
                             mipmapped:NO];
    resultDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
//    resultDescriptor.usage = MTLTextureUsageShaderAtomic;
    _resultTexture = [_device newTextureWithDescriptor:resultDescriptor];
    
    // Single Channel texture for output SDF
    MTLTextureDescriptor *outputDescriptor = [MTLTextureDescriptor
            texture2DDescriptorWithPixelFormat:MTLPixelFormatR32Float
                                 width:_Owidth
                                height:_Oheight
                             mipmapped:NO];
    outputDescriptor.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    _outputTexture = [_device newTextureWithDescriptor:outputDescriptor];
        
    return (_exteriorTextureA != nil && _exteriorTextureB != nil &&
            _interiorTextureA != nil && _interiorTextureB != nil &&
            _resultTexture != nil && _outputTexture != nil);
}

// MARK: Initialise textures for JFA pass
- (void)initializeTexture:(id<MTLTexture>)texture
            withImageData:(const uint8_t *)imageData
                threshold:(uint8_t)threshold
                   invert:(BOOL)invert
               isExterior:(BOOL)isExterior
{
    // Allocate CPU buffer for initialisation
    NSUInteger bufferSize = _Iwidth * _Iheight * 4 * sizeof(float); // float4
    float *initialData = (float *)malloc(bufferSize);
    
    float INF = 1e9;
    
    // Initialize texture data
    // For seeds: store their own position (x, y)
    // For non-seeds: store (INF, INF, 0, 0)
    for (NSUInteger y = 0; y < _Iheight; y++) {
        for (NSUInteger x = 0; x < _Iwidth; x++) {
            NSUInteger pixelIndex = y * _Iwidth + x;
            NSUInteger dataIndex = pixelIndex * 4;
                
            // Check if pixel is a seed (white pixel)
            uint8_t pixelValue = imageData[pixelIndex];
            BOOL isSeed = (invert) ? (pixelValue < threshold) : (pixelValue >= threshold);
            // For interior pass: black pixel becomes seeds
                
            if (isSeed) {
                initialData[dataIndex + 0] = (float)x;      // R: seed X
                initialData[dataIndex + 1] = (float)y;      // G: seed Y
                initialData[dataIndex + 2] = 0.0f;          // B: minimum distance
                initialData[dataIndex + 3] = 0.0f;          // A: unused
            } else {
                initialData[dataIndex + 0] = -1.0f;         // R: INVALID
                initialData[dataIndex + 1] = -1.0f;         // G: INVALID
                initialData[dataIndex + 2] = (float)INF;    // B: minimum distance
                initialData[dataIndex + 3] = 0.0f;          // A: unused
            }
        }
    }
    
    // Copy to texture
    MTLRegion region = MTLRegionMake2D(0, 0, _Iwidth, _Iheight);
    NSUInteger bytesPerRow = _Iwidth * 4 * sizeof(float);
        
    [texture replaceRegion:region mipmapLevel:0
             withBytes:initialData bytesPerRow:bytesPerRow];
        
    free(initialData);
}

// MARK: Run JFA algorithm on a texture
- (void)runJFAOnInputTexture:(id<MTLTexture>) inputTexture
               outputTexture:(id<MTLTexture>) outputTexture
              commandEncoder:(id<MTLComputeCommandEncoder>) encoder
{
    [encoder setComputePipelineState:_jfaPipelineState];
    NSUInteger step = _Iwidth / 2;
    NSInteger readIdx = 0;
    // 0 for inputTexture, 1 for outputTexture
    
    // Calculate threadgroup size
    NSUInteger threadgroupWidth = 16;
    NSUInteger threadgroupHeight = 16;
    MTLSize threadgroupSize = MTLSizeMake(threadgroupWidth, threadgroupHeight, 1);
            
    // Calculate threadgroup count
    NSUInteger threadgroupCountX = (_Iwidth + threadgroupWidth - 1) / threadgroupWidth;
    NSUInteger threadgroupCountY = (_Iheight + threadgroupHeight - 1) / threadgroupHeight;
    MTLSize threadgroupCount = MTLSizeMake(threadgroupCountX, threadgroupCountY, 1);
    
    // Run log2(n) passes
    while (step >= 1) {
        [encoder setBytes:&step length:sizeof(NSUInteger) atIndex:0];
        [encoder setBytes:&offsets length:sizeof(offsets) atIndex:1];
        
        // Set input/output textures (Swap target and source texture)
        id<MTLTexture>  currentInput = (readIdx == 0) ? inputTexture : outputTexture;
        id<MTLTexture> currentOutput = (readIdx == 0) ? outputTexture : inputTexture;
        
        [encoder setTexture: currentInput atIndex:0];
        [encoder setTexture:currentOutput atIndex:1];
                
        // Dispatch compute kernel
        [encoder dispatchThreadgroups:threadgroupCount
                 threadsPerThreadgroup:threadgroupSize];
        
        [encoder memoryBarrierWithScope:MTLBarrierScopeTextures];
        
        readIdx = 1 - readIdx;
        step /= 2;
    }
    // One extra round with step = 1 (JFA+1) for better accuracy
    NSInteger finalStep = 1;
    [encoder setBytes:&finalStep length:sizeof(NSUInteger) atIndex:0];
    
    id<MTLTexture>  finalInput = (readIdx == 0) ? inputTexture : outputTexture;
    id<MTLTexture> finalOutput = (readIdx == 0) ? outputTexture : inputTexture;
    
    [encoder setTexture: finalInput atIndex:0];
    [encoder setTexture:finalOutput atIndex:1];
    [encoder dispatchThreadgroups:threadgroupCount
             threadsPerThreadgroup:threadgroupSize];
}

// MARK: Main function
-(BOOL) generateSDFFromImage:(const uint8_t *)imageData
                   threshold:(uint8_t)threshold
                outputBuffer:(float *)outputBuffer
{
    // Create command buffer
    id<MTLCommandQueue> commandQueue = [_device newCommandQueue];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
    
    // ========== PASS 1: Exterior Distances ==========
    // Initialize exterior texture (white pixels as seeds)
    [self initializeTexture:_exteriorTextureA withImageData:imageData
          threshold:threshold invert:NO isExterior:YES];
        
    // Run JFA for exterior distances
    [self runJFAOnInputTexture:_exteriorTextureA
                outputTexture:_exteriorTextureB
                commandEncoder:encoder];
        
    // Insert barrier between passes
    [encoder memoryBarrierWithScope:MTLBarrierScopeTextures];
        
    // ========== PASS 2: Interior Distances ==========
    // Initialize interior texture (inverted: black pixels as seeds)
    [self initializeTexture:_interiorTextureA withImageData:imageData
          threshold:threshold invert:YES isExterior:NO];
        
    // Run JFA for interior distances
    [self runJFAOnInputTexture:_interiorTextureA
                outputTexture:_interiorTextureB
                commandEncoder:encoder];
        
    // ========== COMBINE PASS ==========
    // Create a texture for the original image data
    MTLTextureDescriptor *imageDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
        width:_Iwidth height:_Iheight mipmapped:NO];
        
    imageDesc.usage = MTLTextureUsageShaderRead;
    id<MTLTexture> originalTexture = [_device newTextureWithDescriptor:imageDesc];
        
    // Copy image data to texture
    MTLRegion region = MTLRegionMake2D(0, 0, _Iwidth, _Iheight);
    [originalTexture replaceRegion:region mipmapLevel:0 withBytes:imageData bytesPerRow:_Iwidth];
        
    // Run combine kernel
    [encoder setComputePipelineState:_combinePipelineState];
        
    // Set textures: original, exterior result, interior result, output
    // Note: After JFA, results are in textureB for both passes
    float spread = (float) self.spread;
    [encoder setBytes:&spread length:sizeof(spread) atIndex:0];
    [encoder setTexture:originalTexture atIndex:0];
    [encoder setTexture:_exteriorTextureB atIndex:1]; // Exterior distances
    [encoder setTexture:_interiorTextureB atIndex:2]; // Interior distances
    [encoder setTexture:_resultTexture atIndex:3];    // Combined SDF output
        
    // Dispatch combine kernel
    NSUInteger threadgroupWidth = 16;
    NSUInteger threadgroupHeight = 16;
    MTLSize threadgroupSize = MTLSizeMake(threadgroupWidth, threadgroupHeight, 1);
        
    NSUInteger threadgroupCountX = (_Iwidth + threadgroupWidth - 1) / threadgroupWidth;
    NSUInteger threadgroupCountY = (_Iheight + threadgroupHeight - 1) / threadgroupHeight;
    MTLSize threadgroupCount = MTLSizeMake(threadgroupCountX, threadgroupCountY, 1);
        
    [encoder dispatchThreadgroups:threadgroupCount threadsPerThreadgroup:threadgroupSize];
    [encoder memoryBarrierWithScope:MTLBarrierScopeTextures];
    
    // ========== DOWNSAMPLING PASS ==========
    [encoder setComputePipelineState:_downsamplePipelineState];
    [encoder setBytes:&spread length:sizeof(spread) atIndex:0];
    [encoder setTexture:_resultTexture atIndex:0];
    [encoder setTexture:_outputTexture atIndex:1];
    
    threadgroupCountX = (_Owidth + threadgroupWidth - 1) / threadgroupWidth;
    threadgroupCountY = (_Oheight + threadgroupHeight - 1) / threadgroupHeight;
    threadgroupCount = MTLSizeMake(threadgroupCountX, threadgroupCountY, 1);
    [encoder dispatchThreadgroups:threadgroupCount threadsPerThreadgroup:threadgroupSize];
    
    
    [encoder endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];
        
    return true;
}

// MARK: Save the SDF into PFM image
-(BOOL) saveSDFToPFM:(const char *) filename
{
    NSError *error = nil;
    float scaler = 1.0f / (float) _spread;
    BOOL success = [PFMTextureLoader savePFMDataFromTexture:_outputTexture
                                     path:filename scaler:scaler error:&error];
    
    if (error) {
        NSLog(@"Failed to save PFM: %@", error);
    }
    
    return success;
}

// MARK: (Deprecated) Save the SDF into PGM img
//-(BOOL)saveSDFToPGM:(const char *)filename
//{
//    if (!_sdfBuffer) return NO;
//   
//    FILE *file = fopen(filename, "wb");
//    if (!file) return NO;
//
//    // Write PGM header
//    fprintf(file, "P5\n%lu %lu\n255\n", _Owidth, _Oheight);
//    
//    // Write normalized data
//    for (NSUInteger i = 0; i < _Owidth * _Oheight; i++) {
//        uint8_t pixel = (uint8_t)(_sdfBuffer[i] * 255.0f);
//        fwrite(&pixel, 1, 1, file);
//    }
//   
//    fclose(file);
//    return YES;
//}

//-(BOOL) readResultToBuffer:(float *) outputBuffer
//{
//    if(!outputBuffer) return NO;
//    
//    // Allocate temporary buffer
//    float *textureData = (float *)malloc(_Owidth * _Oheight * sizeof(float));
//    if (!textureData) NO;
//        
//    // Read from result texture
//    MTLRegion region = MTLRegionMake2D(0, 0, _Owidth, _Oheight);
//    [_outputTexture getBytes:textureData
//                    bytesPerRow:_Owidth * sizeof(float)
//                    fromRegion:region
//                    mipmapLevel:0];
//        
//    // Copy to output buffer
//    memcpy(outputBuffer, textureData, _Owidth * _Oheight * sizeof(float));
//        
//    // Store in instance variable for later use
//    _sdfBuffer = textureData;
//        
//    return YES;
//}
//
//-(float *) getSDFResult {
//    return _sdfBuffer;
//}

//- (void)dealloc {
//   if (_sdfBuffer) {
//       free(_sdfBuffer);
//   }
//}
@end

NS_ASSUME_NONNULL_END
