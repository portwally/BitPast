/*
 * b2d_wrapper.c
 * Wrapper function to call b2d conversion from Swift
 * DO NOT define B2D_IMPLEMENTATION here
 */

#include "b2d.h"

/**
 * Wrapper function that can be called from Swift
 * This ensures all code paths return a value
 */
int b2d_main_wrapper(int argc, char** argv) {
    // Reset critical global variables before each conversion
    // This ensures consistent behavior between conversions
    dither = 0;  // Reset dither to default (none)
    hgrdither = 0;
    dither7 = 0;
    
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

