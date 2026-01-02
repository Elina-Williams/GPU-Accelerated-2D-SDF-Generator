GPU-Accelerated 2D Signed Distance Field Generator with Metal

Overview

This project implements a high-performance, GPU-accelerated 2D Signed Distance Field (SDF) generator using Apple's Metal framework and the Jump Flooding Algorithm (JFA). It consists of two main components: a SDF generator and a renderer, designed for efficient real-time generation and visualisation of distance fields from input textures. This toolkit is suitable for graphics applications, game development, and visual effects, leveraging Metal's compute capabilities for significant performance gains on supported hardware.

Key Features

GPU Acceleration: Utilises Metal compute shaders for parallel processing, maximising performance on macOS and iOS devices.
Jump Flooding Algorithm (JFA): Implements an efficient algorithm for generating SDFs with high accuracy and minimal iterations.
High Performance: Optimised for large image sizes; tested with 1024×1024 and 2048×2048 inputs.
Two-Tool Suite: Includes both a SDF generator and a renderer for complete workflow support.

Performance Metrics

The following average timings were recorded on supported hardware (e.g., Apple Silicon Macs):

1024×1024 image generating a 64px SDF: 0.029 seconds
2048×2048 image generating an SDF: 0.127 seconds
These results demonstrate the efficiency of the GPU-accelerated approach, enabling rapid generation for real-time applications.

Project Structure

The project contains two main executables:

1. 2D_SDFGenerator

Generates Signed Distance Field textures from binary PGM mask images using the JFA algorithm on GPU.

2. SDF_Renderer

Renders SDF data (stored in PFM format) into PNG images with configurable colours and resolution scaling.

Both tools are compiled from a single Xcode project for ease of use.

Installation

Clone the repository:

bash
git clone https://github.com/yourusername/metal-sdf-generator.git  
Open SDF.xcodeproj in Xcode
Build the project (⌘+B) to compile both tools
The compiled executables will be available in the build directory

Effect Gallery

Below are example visualisations of generated SDFs:
![out2](https://github.com/user-attachments/assets/7bbdf1d5-7bab-47d1-9b4a-316c1fa10d5c)
![outA](https://github.com/user-attachments/assets/fbd35faf-b5bc-48f0-9afb-ae0b30e222ef)

