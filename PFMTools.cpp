//
//  PFMTools.cpp
//  2D_SDFGenerator
//
//  Created by Elina Williams on 30/12/2025.
//

#include "PFMTools.hpp"

/// All members of a union share the same memory region, with each member providing a different interpretation of that memory.
// Check if the system uses little-endian byte order.
bool isSystemLittleEndian() {
    union {
        uint32_t i;        // 32-bit integer
        char c[4];         // Array of 4 bytes
    } test = {0x01020304}; //
    
    // Little-endian: The least significant byte (LSB, 0x04) is stored at the lowest memory address.
    // Big-endian: The most significant byte (MSB, 0x01) is stored at the lowest memory address.
    return test.c[0] == 0x04;
}

namespace PFM {

// MARK: Implementation - loadFromFile
PFMData Reader::loadFromFile(const std::string& filepath) {
    
    if (!std::filesystem::exists(filepath)) {
        throw std::invalid_argument("file does not exist");
        return {};
    }
    
    std::ifstream file(filepath, std::ios::binary | std::ios::ate);
    if (!file) return {};
    
    size_t size = file.tellg();
    file.seekg(0, std::ios::beg);
    
    std::vector<char> buffer(size);
    if (!file.read(buffer.data(), size)) return {};
    
    return _load(buffer.data(), size);
}

PFMData Reader::_load(const void* data, size_t size)
{
    PFMData result;
    
    if (!data) return result;
    
    const char* ptr = static_cast<const char*>(data);
    
    if (std::strncmp(ptr, "Pf", 2) != 0) return result;
    
    while (*ptr != '\n' && ptr < static_cast<const char*>(data) + size) ptr++;
    if (*ptr != '\n') return result;
    ptr++;
    
    // The second line
    int scanned = std::sscanf(ptr, "%u %u", &result.width, &result.height);
    if (scanned != 2) return result;
    
    // Move to the next line
    while (*ptr != '\n' && ptr < static_cast<const char*>(data) + size) ptr++;
    if (*ptr != '\n') return result;
    ptr++;
    
    // Third line - scaler
    float scale;
    if (std::sscanf(ptr, "%f", &scale) != 1) return result;
    bool isBigEndian = (scale > 0);
    result.scaler = abs(scale);
    
    // Move to the next line
    while (*ptr != '\n' && ptr < static_cast<const char*>(data) + size) ptr++;
    if (*ptr != '\n') return result;
    ptr++;
    
    size_t pixelCount = result.width * result.height;
    size_t expectedSize = pixelCount * sizeof(float);
    const char* dataStart = ptr;
    
    if (dataStart + expectedSize > static_cast<const char*>(data) + size) {
        return result;
    }
    
    result.pixels.resize(pixelCount);
    // NOTICE: Flip Y axis since rows ordered bottom to top
    // std::memcpy(result.pixels.data(), dataStart, expectedSize);
#pragma region FlipY {
    const float* src = reinterpret_cast<const float*>(dataStart);
    for (uint32_t y = 0; y < result.height; ++y)
    {
        uint32_t targetY = result.height - 1 - y;
            
        std::memcpy(
            &result.pixels[targetY * result.width],          // Target
            src + y * result.width,                          // Source
            result.width * sizeof(float)                     // Bytes per row
        );
    }
#pragma endregion FlipY }
    
    static const bool systemIsLittleEndian = isSystemLittleEndian();
    // Convert if the endianness of the PFM file differs from the system's.
    if (isBigEndian != !systemIsLittleEndian) {
        for (size_t i = 0; i < pixelCount; ++i) {
            uint32_t* val = reinterpret_cast<uint32_t*>(&result.pixels[i]);
            *val = __builtin_bswap32(*val);
        }
    }
    
    return result;
}

// MARK: Implementation - SaveToFile
bool Reader::saveToFile(const std::string& filepath,
                        const float* pixels,
                        uint32_t width,
                        uint32_t height,
                        float scaler)
{
    PFMData data;
    data.width = width;
    data.height = height;
    data.scaler = scaler;
    data.pixels.assign(pixels, pixels + width * height);
    
    return saveToFile(filepath, data);
}

bool Reader::saveToFile(const std::string& filepath, const PFMData& data) {
    auto buffer = _createPFMData(data);
    if (buffer.empty()) return false;
    
    std::ofstream file(filepath, std::ios::binary);
    if (!file) return false;
    
    file.write(reinterpret_cast<const char*>(buffer.data()), buffer.size());
    return file.good();
}

std::vector<uint8_t> Reader::_createPFMData(const PFMData& data)
{
    if (!data.isValid()) return {};
    if (data.scaler <= 0) {
        throw std::invalid_argument("scaler must greater than 0");
        return {};
    }
    
    std::string header = "Pf\n";
    header += std::to_string(data.width) + " " + std::to_string(data.height) + "\n";
    header += std::format("-{:f}\n", data.scaler);
    
    size_t headerSize = header.size();
    size_t dataSize = data.dataSize();
    size_t totalSize = headerSize + dataSize;
    
    std::vector<uint8_t> result(totalSize);
    
    // Copy header
    std::memcpy(result.data(), header.data(), headerSize);
    
    // Copy pixel data
    const float* src = data.pixels.data();
    for (uint32_t y = 0; y < data.height; ++y)
    {
        uint32_t targetY = data.height - 1 - y;
        std::memcpy(result.data() + headerSize + targetY * data.width * sizeof(float),
                    src + y * data.width,
                    data.width * sizeof(float));
    }
    // NOTICE: Flip Y axis since rows ordered bottom to top
    // std::memcpy(result.data() + headerSize, data.pixels.data(), dataSize);
    return result;
}

}
