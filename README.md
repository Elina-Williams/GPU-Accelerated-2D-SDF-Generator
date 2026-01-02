# GPU-Accelerated 2D Signed Distance Field Generator with Metal




## Overview  
This project implements a high-performance, GPU-accelerated 2D Signed Distance Field (SDF) generator using Apple's Metal framework and the Jump Flooding Algorithm (JFA). It consists of two main components: a SDF generator and a renderer, designed for efficient generation and visualisation of distance fields from input textures. This toolkit is suitable for graphics applications, game development, and visual effects, leveraging Metal's compute capabilities for significant performance gains on supported hardware.

## Key Features  
- **GPU Acceleration**: Utilises Metal compute shaders for parallel processing, maximising performance on macOS and iOS devices.  
- **Jump Flooding Algorithm (JFA)**: Implements an efficient algorithm for generating SDFs with high accuracy and minimal iterations.  
- **High Performance**: Optimised for large image sizes; tested with 1024×1024 and 2048×2048 inputs.  
- **Two-Tool Suite**: Includes both a SDF generator and a renderer for complete workflow support.  

## Performance Metrics  
The following average timings were recorded on MacBook Pro M4:  
- **1024×1024 image** generating a 64px SDF: **0.029 seconds**  
- **2048×2048 image** generating an SDF: **0.127 seconds**  

These results demonstrate the efficiency of the GPU-accelerated approach, enabling rapid generation for real-time applications.

## Project Structure
The project contains two main executables:

### 1. `2D_SDFGenerator`
Generates Signed Distance Field textures from binary PGM mask images using the JFA algorithm on GPU.

### 2. `SDF_Renderer`
Renders SDF data (stored in PFM format) into PNG images with configurable colours and resolution scaling.

Both tools are compiled from a single Xcode project for ease of use.

## Effect
Below are example visualisations of generated SDFs:

<table align="center" border="0">
  <tr style="height: 10">  <!-- 设置行高 -->
    <td align="center" style="padding-right: 50px; vertical-align: middle;">
      <img src="Assets/figure1.jpg" alt="Figure 1" width="50%" />
    </td>
    <td align="center" style="vertical-align: middle;">
      <img src="Assets/figure2.jpg" alt="Figure 2" width="50%" />
    </td>
  </tr>
</table>

## Getting Started  

### Prerequisites  
- macOS 10.15+ with Metal support  
- Xcode 12 or later  

### Installation  
1. Clone the repository:  
   ```bash  
   git clone https://github.com/yourusername/metal-sdf-generator.git
2. Open 2D_SDFGenerator.xcodeproj in Xcode
3. Build the project (⌘+B) to compile
4. The compiled executables will be available in the build directory
