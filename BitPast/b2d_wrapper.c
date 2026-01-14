/*
 * b2d_wrapper.c
 * Wrapper function to call b2d conversion from Swift
 * DO NOT define B2D_IMPLEMENTATION here
 */

#include "b2d.h"
#include <string.h>  // For memset

/**
 * Wrapper function that can be called from Swift
 * This ensures all code paths return a value
 */
int b2d_main_wrapper(int argc, char** argv) {
    // ========================================================================
    // CRITICAL: Reset ALL global variables before each conversion
    // This fixes the bug where mode settings persist between conversions
    // Variables are declared in b2d.h as extern and defined in b2d_globals.c
    // ========================================================================

    // NOTE: Do NOT free dhrbuf/hgrbuf here!
    // b2d.c already frees them at the end of each call (lines 6371-6372).
    // We just need to ensure the pointers are NULL so b2d allocates fresh buffers.
    // The pointers may contain stale addresses from the previous free() in b2d.
    dhrbuf = NULL;
    hgrbuf = NULL;

    // Reset mode flags (these are the ACTUAL variable names from b2d_globals.c)
    hgroutput = 0;        // HGR mode output flag
    mono = 0;             // Monochrome mode flag
    lores = 0;            // Lo-res mode flag
    loresoutput = 0;      // Lo-res output flag
    appletop = 0;         // Apple top flag

    // Reset dither settings
    dither = 0;           // Reset dither to default (none)
    hgrdither = 0;        // Reset HGR dither
    dither7 = 0;          // Reset 7-bit dither
    errorsum = 0;         // Error sum flag
    serpentine = 0;       // Serpentine dither flag
    ditheroneline = 0;    // Single line dither flag
    ditherstart = 0;      // Dither start position

    // Reset palette settings
    hgrpaltype = 255;     // Reset to default (255 = auto-select)
    hgrcolortype = 0;     // Reset HGR color type

    // Reset other important flags that affect output
    preview = 0;          // Preview mode
    vbmp = 0;             // VBMP output mode
    dosheader = 0;        // DOS header flag
    spritemask = 0;       // Sprite mask flag
    tags = 0;             // Tags flag
    debug = 0;            // Debug flag
    quietmode = 1;        // Quiet mode (default is 1)
    outputtype = BIN_OUTPUT;  // Reset output type to default

    // Reset processing flags
    diffuse = 0;          // Diffusion flag
    merge = 0;            // Merge flag
    scale = 0;            // Scale flag
    reformat = 0;         // Reformat flag
    applesoft = 0;        // Applesoft flag
    reverse = 0;          // Reverse flag

    // Reset color/clipping settings
    paletteclip = 0;      // Palette clipping
    globalclip = 0;       // Global clipping
    colorbleed = 100;     // Color bleed (default is 100)
    bleed = 16;           // Bleed value (default is 16)
    backgroundcolor = 0;  // Background color
    clearcolor = 5;       // Clear color (default is 5)

    // Reset overlay settings
    use_overlay = 0;      // Overlay usage flag
    maskpixel = 0;        // Mask pixel
    overcolor = 0;        // Overlay color

    // Close and reset file pointers if open
    if (fpmask != NULL) {
        fclose(fpmask);
        fpmask = NULL;
    }

    // Reset justification
    justify = 0;
    jxoffset = -1;
    jyoffset = -1;

    // Reset double color settings
    doubleblack = 0;
    doublewhite = 0;
    doublecolors = 1;     // Default is 1

    // Reset cross-hatch settings
    xmatrix = 0;
    ymatrix = 0;
    threshold = 0;

    // Reset image dimensions
    bmpwidth = 0;
    bmpheight = 0;
    spritewidth = 0;

    // Reset pseudo palette
    pseudocount = 0;

    // Clear dither buffers to prevent color bleeding from previous conversions
    memset(redDither, 0, sizeof(redDither));
    memset(greenDither, 0, sizeof(greenDither));
    memset(blueDither, 0, sizeof(blueDither));
    memset(redSeed, 0, sizeof(redSeed));
    memset(greenSeed, 0, sizeof(greenSeed));
    memset(blueSeed, 0, sizeof(blueSeed));
    memset(redSeed2, 0, sizeof(redSeed2));
    memset(greenSeed2, 0, sizeof(greenSeed2));
    memset(blueSeed2, 0, sizeof(blueSeed2));

    // Clear HGR-specific buffers
    memset(redSave, 0, sizeof(redSave));
    memset(greenSave, 0, sizeof(greenSave));
    memset(blueSave, 0, sizeof(blueSave));
    memset(OrangeBlueError, 0, sizeof(OrangeBlueError));
    memset(GreenVioletError, 0, sizeof(GreenVioletError));
    memset(HgrPixelPalette, 0, sizeof(HgrPixelPalette));
    memset(palettebits, 0, sizeof(palettebits));
    memset(work280, 0, sizeof(work280));
    memset(buf280, 0, sizeof(buf280));

    // Clear scanline buffers
    memset(bmpscanline, 0, sizeof(bmpscanline));
    memset(bmpscanline2, 0, sizeof(bmpscanline2));
    memset(dibscanline1, 0, sizeof(dibscanline1));
    memset(dibscanline2, 0, sizeof(dibscanline2));
    memset(dibscanline3, 0, sizeof(dibscanline3));
    memset(dibscanline4, 0, sizeof(dibscanline4));
    memset(previewline, 0, sizeof(previewline));
    memset(maskline, 0, sizeof(maskline));

    // Clear filename buffers
    memset(bmpfile, 0, sizeof(bmpfile));
    memset(dibfile, 0, sizeof(dibfile));
    memset(previewfile, 0, sizeof(previewfile));
    memset(mainfile, 0, sizeof(mainfile));
    memset(auxfile, 0, sizeof(auxfile));
    memset(hgrcolor, 0, sizeof(hgrcolor));
    memset(hgrmono, 0, sizeof(hgrmono));
    memset(hgrwork, 0, sizeof(hgrwork));

    // CRITICAL: Reset color palette arrays that get modified by HGR mode
    // When hgroutput==1, b2d.c modifies rgbArray and rgbPreview (line 849-856)
    // setting some colors to black. These must be reset for DHGR to work properly.
    memset(rgbArray, 0, sizeof(rgbArray));
    memset(rgbPreview, 0, sizeof(rgbPreview));
    memset(rgbAppleArray, 0, sizeof(rgbAppleArray));
    memset(rgbVBMP, 0, sizeof(rgbVBMP));
    memset(rgbDouble, 0, sizeof(rgbDouble));
    memset(rgbLuma, 0, sizeof(rgbLuma));
    memset(rgbDoubleBrighten, 0, sizeof(rgbDoubleBrighten));
    memset(rgbLumaBrighten, 0, sizeof(rgbLumaBrighten));
    memset(rgbDoubleDarken, 0, sizeof(rgbDoubleDarken));
    memset(rgbLumaDarken, 0, sizeof(rgbLumaDarken));

    // CRITICAL: Restore grpal to original values!
    // HGR mode permanently modifies grpal (lines 5942-5951 in b2d.c)
    // setting 10 of 16 colors to black. This breaks subsequent DHGR conversions.
    // Original values from b2d_globals.c:
    static const uchar grpal_original[16][3] = {
        {0, 0, 0}, {148, 12, 125}, {32, 54, 212}, {188, 55, 255},
        {51, 111, 0}, {126, 126, 126}, {7, 168, 225}, {158, 172, 255},
        {99, 77, 0}, {249, 86, 29}, {126, 126, 126}, {255, 129, 236},
        {67, 200, 0}, {221, 206, 23}, {93, 248, 133}, {255, 255, 255}
    };
    memcpy(grpal, grpal_original, sizeof(grpal));

    // Validate input
    if (argc < 1 || argv == NULL) {
        fprintf(stderr, "❌ b2d_main_wrapper: Invalid arguments\n");
        return -1;
    }
    
    // Call the actual b2d conversion function
    int result = b2d_actual_main(argc, argv);
    
    // WORKAROUND: If -D0 was passed but dither is still set to 1,
    // this is a b2d bug. Force it back to 0.
    // Check if "-D0" is in the arguments
    int hasDither0 = 0;
    for (int i = 0; i < argc; i++) {
        if (argv[i] != NULL && strcmp(argv[i], "-D0") == 0) {
            hasDither0 = 1;
            break;
        }
    }
    
    // If -D0 was passed but b2d set dither=1 anyway, reset it
    if (hasDither0 && dither != 0) {
        printf("⚠️ WARNING: b2d ignored -D0 flag, dither was set to %d\n", dither);
        printf("   This is a known b2d bug. Dithering will still occur.\n");
    }
    
    return result;
}
