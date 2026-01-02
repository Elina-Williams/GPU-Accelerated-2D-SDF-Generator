//
//  main.m
//  2D_SDFGenerator
//
//  Created by Elina Williams on 25/12/2025.
//

#import <Foundation/Foundation.h>
#import "SDFExecutor.h"

// Simple PGM image loader
uint8_t* loadPGM(const char* filename, int* width, int* height) {
    FILE* file = fopen(filename, "rb");
    if (!file) return NULL;
    
    char magic[3];
    fscanf(file, "%2s\n", magic);
    if (magic[0] != 'P' || magic[1] != '5') {
        fclose(file);
        return NULL;
    }
    
    // Skip comments
    char ch = getc(file);
    while (ch == '#') {
        while (ch != '\n') ch = getc(file);
        ch = getc(file);
    }
    ungetc(ch, file);
    
    fscanf(file, "%d %d\n", width, height);
    int maxval;
    fscanf(file, "%d\n", &maxval);
    
    size_t size = (*width) * (*height);
    uint8_t* data = (uint8_t*)malloc(size);
    fread(data, 1, size, file);
    
    fclose(file);
    return data;
}

BOOL parseTargetSize(const char *sizeStr, int *w, int *h) {
    if (!sizeStr) return NO;
    
    int components[2] = {64, 64};
    int count = 0;
    
    char *copy = strdup(sizeStr);
    char *token = strtok(copy, ",");
    
    while (token && count < 2) {
        components[count] = atoi(token);
        count++;
        token = strtok(NULL, ",");
    }
    
    free(copy);
    
    if (count < 1) {
        // If only input one number a, we assume the target size is a x a
        *w = *h = components[0];
        return YES;
    }
    
    *w = components[0];
    *h = components[1];
    
    return YES;
}

void printUsage(const char *programName) {
    printf("Usage: %s -i <input.pgm> -o <output_basename> [OPTIONS]\n", programName);
    printf("\nDescription:\n");
    printf("  Generates a Signed Distance Field texture from a binary PGM mask.\n");
    printf("\nRequired Arguments:\n");
    printf("  -i <input.pgm>        Path to the input binary PGM image (8-bit grayscale mask).\n");
    printf("  -o <output_basename>  Base filename for the output SDF texture (extension will be added).\n");
    printf("\nOptions:\n");
    printf("  -m <max_distance>     Maximum distance (spread) in pixels.\n");
    printf("                        Default: min(image_width, image_height) / 4\n");
    printf("  -s <width>[,<height>] Target dimensions for the output SDF texture.\n");
    printf("                        If height is omitted, a square texture is generated.\n");
    printf("                        Default: 64x64\n");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        
        const char *inputFile = NULL;
        const char *outputFile = NULL;
        float max_distance = -1;
        int  targetWidth = 64;
        int targetHeight = 64;
        
        // Parse command line arguments
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-i") == 0 && i + 1 < argc) {
                inputFile = argv[++i];
            } else if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
                outputFile = argv[++i];
            } else if (strcmp(argv[i], "-m") == 0 && i + 1 < argc) {
                max_distance = atoi(argv[++i]);
                if (max_distance <= 0) return 1;
            } else if (strcmp(argv[i], "-s") == 0 && i + 1 < argc) {
                if (!parseTargetSize(argv[++i], &targetWidth, &targetHeight))
                    return EXIT_FAILURE;
            } else if (strcmp(argv[i], "-help") == 0 || strcmp(argv[i], "--help") == 0) {
                printUsage(argv[0]);
                return EXIT_SUCCESS;
            }
        }
        
        // Validate required arguments
        if (!inputFile || !outputFile) {
            printUsage(argv[0]);
            return EXIT_FAILURE;
        }
        
        // Load input image
        int InputWidth, InputHeight;
        uint8_t* imageData = loadPGM(inputFile, &InputWidth, &InputHeight);
        
        // Only scaling with width, height in a same ratio is allowed
        if (InputWidth/targetWidth != InputHeight/targetHeight) {
            printf("Only scaling with width, height in a same ratio is allowed\n");
            return EXIT_FAILURE;
        }
        
        if(max_distance == -1) {
            // Use default value
            max_distance = floor(MAX(InputWidth, InputHeight)/4);
            max_distance = MAX(8, max_distance);
        }
                
        if (!imageData) {
            printf("Failed to load input image: %s\n", argv[1]);
            return EXIT_FAILURE;
        }
                
        printf("Generating SDF from %dx%d image...\n", InputWidth, InputHeight);
                
        // Create Metal device
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            printf("Metal is not supported on this system\n");
            free(imageData);
            return EXIT_FAILURE;
        }
                
        printf("Using Metal device: %s\n", [[device name] UTF8String]);
                
        // Create SDF generator
        NSInteger spread = (int) max_distance;
        SDFExecutor* generator = [[SDFExecutor alloc] initWithDevice:device
                                   InputWidth:InputWidth InputHeight:InputHeight
                                   OutputWidth:targetWidth OutputHeight:targetHeight
                                   spread:spread];
        
        if (!generator) {
            printf("Failed to create SDF generator\n");
            free(imageData);
            return EXIT_FAILURE;
        }
                
        // Allocate output buffer
        float* sdfBuffer = (float*)malloc(targetWidth * targetHeight * sizeof(float));
        if (!sdfBuffer) {
            printf("Failed to allocate output buffer\n");
            free(imageData);
            return EXIT_FAILURE;
        }
                
        // Generate SDF (threshold at 128)
        CFAbsoluteTime startTime = CFAbsoluteTimeGetCurrent();
        BOOL success = [generator generateSDFFromImage:imageData
                                  threshold:128
                                  outputBuffer:sdfBuffer];
                
        if (!success) {
            printf("Failed to generate SDF\n");
            free(imageData);
            free(sdfBuffer);
            return EXIT_FAILURE;
        }
                
        // Save SDF as PFM
        success = [generator saveSDFToPFM:outputFile];
        if (!success) {
            printf("Failed to save SDF to file: %s\n", outputFile);
        } else {
            printf("SDF saved to: %s\n", outputFile);
            CFAbsoluteTime endTime = CFAbsoluteTimeGetCurrent();
            CFTimeInterval executionTime = endTime - startTime;
            NSLog(@"\nExecution time: %.3f seconds\n", executionTime);
        }
                
        // Cleanup
        free(imageData);
        free(sdfBuffer);
        printf("Done!\n");
    }
    return EXIT_SUCCESS;
}
