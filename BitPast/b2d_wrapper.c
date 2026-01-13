/*
 * b2d_wrapper.c
 * Wrapper function to call b2d conversion from Swift
 */

#include "b2d.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Forward declaration of the actual b2d main function
// If your b2d.c has a different main function, adjust this
int b2d_actual_main(int argc, char** argv);

/**
 * Wrapper function that can be called from Swift
 * This ensures all code paths return a value
 */
int b2d_main_wrapper(int argc, char** argv) {
    // Validate input
    if (argc < 1 || argv == NULL) {
        fprintf(stderr, "b2d_main_wrapper: Invalid arguments\n");
        return -1;
    }
    
    // Print debug info
    printf("b2d_main_wrapper called with %d arguments:\n", argc);
    for (int i = 0; i < argc; i++) {
        printf("  argv[%d] = %s\n", i, argv[i]);
    }
    
    // Call the actual b2d conversion function
    int result = b2d_actual_main(argc, argv);
    
    // Always return a value
    return result;
}

/**
 * Placeholder for actual b2d main function
 * Replace this with your actual conversion logic
 */
int b2d_actual_main(int argc, char** argv) {
    printf("b2d_actual_main: Processing %d arguments\n", argc);
    
    // TODO: Add your actual b2d conversion logic here
    // This is where you would:
    // 1. Parse command line arguments
    // 2. Read the input BMP file
    // 3. Convert to Apple II format
    // 4. Write output files
    
    // For now, just return success
    printf("b2d_actual_main: Conversion complete (placeholder)\n");
    
    return 0;  // 0 = success
}
