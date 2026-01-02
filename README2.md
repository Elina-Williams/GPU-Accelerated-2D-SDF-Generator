
## Input Format Specifications:
// --------------------------
// The input image is expected to be an 8-bit PGM format, for the following reasons:
// 1. The JFA algorithm only requires binary information to identify boundary seed points.
// 2. 8-bit depth (0–255) is sufficient to provide well-defined shape boundaries.
// 3. Shape information can be extracted via simple thresholding: pixel > 128 ? INSIDE : OUTSIDE.
// 4. The format is straightforward, easy to create and debug using common imaging tools.


## Output Format Specifications:
// ---------------------------
// The PFM (Portable Float Map) format is selected for output, for the following reasons:
// 1. It preserves full 32-bit floating-point precision without quantization loss.
// 2. SDF values will be directly usable in shader operations such as smoothstep interpolation.
// - An 8-bit output with only 256 discrete levels (only 127 levels for each sign)
//   would result in visible stair-stepping artifacts along boundaries.
// 3. The PFM format is simple to implement for both reading and writing.
// 4. It aligns with common practices in high-quality graphics applications.


## PFM Image Format
// ---------------------------
// the format begins with three lines of text specifying the image size and type,
//      and then continues with raw binary image data for the rest of the file.
//
// The text header of a .pfm file takes the following form:
[type]
[xres] [yres]
[scale_factor]
// Each of the three lines of text ends with a 1-byte Unix-style carriage return: 0x0a in hex
// The "[type]" is one of "PF" for a 3-channel RGB color image, or "Pf"
//      for a monochrome single-channel image.
// "[xres] [yres]" indicates the x and y resolutions of the image.
// "[scale_factor]" is a signed floating-point number where:
// - The SIGN indicates byte order: positive = big-endian, negative = little-endian
// - The ABSOLUTE VALUE represents a scale factor (typically 1.0)
// Pixel values in the binary data are multiplied by |scale_factor| to obtain actual intensities

//    -------- Notice --------
// In our implementation, we use this field to encode the normalisation factor:
// 1. The raw pixel values are stored in the range [0, spread]
// 2. We set |scale_factor| = 1.0 / spread
// 3. This ensures that:
//    - When viewed in MacOS Preview: pixel × |scale_factor| = pixel / spread ∈ [0, 1]
//      (avoiding unwanted HDR display)
//    - The original spread value can be recovered: spread = 1.0 / |scale_factor|
//    - The raw pixel values (in [0, spread]) are directly usable in our pipeline
//    ------------------------

// Binary Data Format (follows header):
// - Raw binary IEEE 32-bit floating point values
// - Row-major order, with the pixels in each row ordered left to right
//   and the rows ordered bottom to top. (very strange)
// - No padding between rows
// - For "PF" (RGB): Data is interleaved as [R1 G1 B1 R2 G2 B2 ...] per row
// - For "Pf" (monochrome): Data is single channel values per pixel

// References:
// https://www.pauldebevec.com/Research/HDR/PFM/
// https://netpbm.sourceforge.net/doc/pfm.html
