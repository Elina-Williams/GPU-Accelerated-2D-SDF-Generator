//
//  PFMTools.hpp
//  2D_SDFGenerator
//
//  Created by Elina Williams on 30/12/2025.
//

#ifndef PFMTools_hpp
#define PFMTools_hpp

#include <stdio.h>
#include <fstream>
#include <string.h>
#include <format>

// MARK: Main
/// built for monochrome single-channel image only
namespace PFM {

struct PFMData {
    uint32_t width = 0;
    uint32_t height = 0;
    float scaler = 0;
    std::vector<float> pixels;
    
    bool isValid() const { return !pixels.empty(); }
    size_t pixelCount() const { return width * height; }
    size_t dataSize() const { return pixelCount() * sizeof(float); }
};

class Reader {
public:
    static PFMData loadFromFile(const std::string& filepath);
    static bool saveToFile(const std::string& filepath, const PFMData& data);
    static bool saveToFile(const std::string& filepath, const float* pixels,
                           uint32_t width, uint32_t height, float scaler = 1.0f);
    
private:
    static PFMData _load(const void* data, size_t size);
    static std::vector<uint8_t> _createPFMData(const PFMData& data);
};

}

#endif /* PFMTools_hpp */
