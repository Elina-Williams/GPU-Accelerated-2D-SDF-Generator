//
//  main.m
//  SDF_Render
//
//  Created by Elina Williams on 25/12/2025.
//

#import <Foundation/Foundation.h>
#import "SDFRenderer.h"

BOOL parseColor(const char *colorStr, float *r, float *g, float *b, float *a) {
    if (!colorStr) return NO;
    
    int components[4] = {255, 255, 255, 255};
    int count = 0;
    
    char *copy = strdup(colorStr);
    char *token = strtok(copy, ",");
    
    while (token && count < 4) {
        components[count] = atoi(token);
        count++;
        token = strtok(NULL, ",");
    }
    
    free(copy);
    
    if (count < 3) return NO;
    
    *r = components[0] / 255.0f;
    *g = components[1] / 255.0f;
    *b = components[2] / 255.0f;
    *a = (count >= 4) ? components[3] / 255.0f : 1.0f;
    
    return YES;
}

void printUsage(const char *programName) {
    printf("SDF-Based Renderer with Resolution Scaling\n");
    printf("===========================================\n");
    printf("Usage: %s -i <input.pfm> -o <output.png> [OPTIONS]\n", programName);
    printf("\nDescription:\n");
    printf("  Renders a Signed Distance Field (SDF) stored in a PFM file into a PNG image,\n");
    printf("  applying a solid fill color and optional resolution scaling.\n");
    printf("\nRequired Arguments:\n");
    printf("  -i <input.pfm>      Path to the input PFM image (32-bit floating-point SDF data).\n");
    printf("  -o <output.png>     Path for the output rendered PNG image.\n");
    printf("\nOptions:\n");
    printf("  -c <R,G,B[,A]>      Fill color and optional alpha (opacity) for the SDF shape.\n");
    printf("                      Values are integers in 0-255 range. Default: 0,0,0,255\n");
    printf("  -r <scale_factor>   Linear scaling factor for the output resolution.\n");
    printf("                      Default: 1.0\n");
}

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Default parameters
        const char *inputFile = NULL;
        const char *outputFile = NULL;
        float fillR = 0.0f, fillG = 0.0f, fillB = 0.0f, fillA = 1.0f;
        float outputScale = 1.0f;
        
        // Parse command line arguments
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-i") == 0 && i + 1 < argc) {
                inputFile = argv[++i];
            } else if (strcmp(argv[i], "-o") == 0 && i + 1 < argc) {
                outputFile = argv[++i];
            } else if (strcmp(argv[i], "-c") == 0 && i + 1 < argc) {
                if (!parseColor(argv[++i], &fillR, &fillG, &fillB, &fillA)) {
                    printf("Error: Invalid color format. Use R,G,B[,A]\n");
                    return EXIT_FAILURE;
                }
            } else if (strcmp(argv[i], "-r") == 0 && i + 1 < argc) {
                outputScale = atof(argv[++i]);
                if (outputScale <= 0) {
                    printf("Error: Output scale must be > 0\n");
                    return EXIT_FAILURE;
                }
            } else if (strcmp(argv[i], "-h") == 0 || strcmp(argv[i], "--help") == 0) {
                printUsage(argv[0]);
                return EXIT_SUCCESS;
            }
        }
        
        // Validate required arguments
        if (!inputFile || !outputFile) {
            printUsage(argv[0]);
            return EXIT_FAILURE;
        }
        
        // Create Metal device
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        if (!device) {
            printf("Error: Metal is not supported on this system\n");
            return EXIT_FAILURE;
        }
        
        printf("Using Metal device: %s\n", [[device name] UTF8String]);
        
        // Create SDF renderer
        SDFRenderer *renderer = [[SDFRenderer alloc] initWithDevice:device filePath:inputFile];
        
        if (!renderer) {
            printf("Error: Failed to create SDF renderer\n");
            return EXIT_FAILURE;
        }
        
        printf("SDF Renderer with Resolution Scaling\n");
        printf("=====================================\n");
        printf("Input SDF:    %s (%ux%u)\n", inputFile,
               (uint32_t)renderer.inputWidth, (uint32_t)renderer.inputHeight);
        printf("Output:       %s (%ux%u, %.1fx scale)\n",
               outputFile, (uint32_t)renderer.outputWidth,
               (uint32_t)renderer.outputHeight, outputScale);
        printf("Fill color:   (%.0f, %.0f, %.0f, %.0f)\n",
               fillR * 255, fillG * 255, fillB * 255, fillA * 255);
        printf("\n");
        
        // Render SDF
        printf("Rendering with %.1fx output scale...\n", outputScale);
        BOOL success = [renderer renderSDFWithFillColorRed:fillR
                                                     green:fillG
                                                      blue:fillB
                                                     alpha:fillA
                                               outputScale:outputScale];
        
        if (!success) {
            printf("Error: Failed to render SDF\n");
            return EXIT_FAILURE;
        }
        
        // Save result
        printf("Saving to %s...\n", outputFile);
        if (![renderer saveToPNG:outputFile]) {
            printf("Error: Failed to save PNG to %s\n", outputFile);
            return EXIT_FAILURE;
        }
        
        printf("\nRender successful!\n");
        printf("Output: %lux%lu (%.1fx scale)\n",
               [renderer outputWidth], [renderer outputHeight], outputScale);
        printf("\nDone!\n");
    }
    return EXIT_SUCCESS;
}
