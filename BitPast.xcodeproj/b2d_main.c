/*
 * b2d_main.c
 * Main implementation for b2d conversion
 * DO NOT define B2D_IMPLEMENTATION here - only in b2d_globals.c
 */

#include "b2d.h"

/**
 * Parse command line arguments and set global flags
 */
static int parse_arguments(int argc, char** argv) {
    if (argc < 1) {
        fprintf(stderr, "Error: No input file specified\n");
        return -1;
    }
    
    // Copy the input filename
    strncpy(bmpfile, argv[0], MAXF - 1);
    bmpfile[MAXF - 1] = '\0';
    
    if (!quietmode) {
        printf("Input file: %s\n", bmpfile);
    }
    
    // Parse options
    for (int i = 1; i < argc; i++) {
        char* arg = argv[i];
        
        if (strcmp(arg, "MONO") == 0) {
            mono = 1;
            if (!quietmode) printf("Mode: Monochrome\n");
        }
        else if (strcmp(arg, "HGR") == 0) {
            hgroutput = 1;
            if (!quietmode) printf("Mode: HGR\n");
        }
        else if (strcmp(arg, "DL") == 0) {
            lores = 2; // Double Lo-Res
            if (!quietmode) printf("Mode: Double Lo-Res\n");
        }
        else if (strcmp(arg, "L") == 0) {
            lores = 1; // Lo-Res
            if (!quietmode) printf("Mode: Lo-Res\n");
        }
        else if (strncmp(arg, "-D", 2) == 0) {
            // Dither mode
            dither = (uchar)atoi(arg + 2);
            if (!quietmode) printf("Dither: %d\n", dither);
        }
        else if (strncmp(arg, "-E", 2) == 0) {
            // Error matrix
            int val = atoi(arg + 2);
            if (!quietmode) printf("Error matrix: %d\n", val);
        }
        else if (strncmp(arg, "-P", 2) == 0) {
            // Palette
            hgrpaltype = (unsigned char)atoi(arg + 2);
            if (!quietmode) printf("Palette: %d\n", hgrpaltype);
        }
        else if (strncmp(arg, "-X", 2) == 0) {
            // Cross-hatch
            xmatrix = atoi(arg + 2);
            if (!quietmode) printf("Cross-hatch: %d\n", xmatrix);
        }
        else if (strncmp(arg, "-Z", 2) == 0) {
            // Threshold
            threshold = atoi(arg + 2);
            if (!quietmode) printf("Threshold: %d\n", threshold);
        }
        else if (strcmp(arg, "-V") == 0) {
            // Preview mode
            preview = 1;
            if (!quietmode) printf("Preview mode enabled\n");
        }
    }
    
    return 0;
}

/**
 * Create a simple preview BMP file and native output
 * This is a placeholder - real implementation would convert to Apple II format
 */
static int create_output_files(const char* input_file) {
    printf(">>> create_output_files: START\n");
    printf("    Input: %s\n", input_file);
    
    // Extract base name without extension
    char base_name[MAXF];
    strncpy(base_name, input_file, MAXF - 1);
    base_name[MAXF - 1] = '\0';
    
    // Remove extension
    char* ext = strrchr(base_name, '.');
    if (ext != NULL) {
        *ext = '\0';
    }
    printf("    Base name: %s\n", base_name);
    
    // Generate preview filename: basename_preview.bmp
    char preview_file[MAXF];
    snprintf(preview_file, MAXF, "%s_preview.bmp", base_name);
    
    // Generate native output filename: basename.bin (or .hgr, .lgr depending on mode)
    char native_file[MAXF];
    const char* native_ext = ".bin";
    
    if (hgroutput) {
        native_ext = mono ? ".hgr" : ".hgr";
    } else if (lores == 1) {
        native_ext = ".lgr";
    } else if (lores == 2) {
        native_ext = ".dlgr";
    }
    
    snprintf(native_file, MAXF, "%s%s", base_name, native_ext);
    
    printf("    Preview file: %s\n", preview_file);
    printf("    Native file: %s\n", native_file);
    
    // Read input BMP
    printf("    Opening input file...\n");
    FILE* fin = fopen(input_file, "rb");
    if (!fin) {
        fprintf(stderr, "❌ ERROR: Cannot open input file: %s\n", input_file);
        perror("    fopen");
        return -1;
    }
    printf("    ✅ Input file opened\n");
    
    // Create preview BMP (copy input for now)
    printf("    Creating preview file...\n");
    FILE* fout = fopen(preview_file, "wb");
    if (!fout) {
        fprintf(stderr, "❌ ERROR: Cannot create preview file: %s\n", preview_file);
        perror("    fopen");
        fclose(fin);
        return -1;
    }
    printf("    ✅ Preview file opened for writing\n");
    
    // Copy the BMP file
    printf("    Copying data...\n");
    char buffer[4096];
    size_t bytes;
    size_t total_written = 0;
    while ((bytes = fread(buffer, 1, sizeof(buffer), fin)) > 0) {
        if (fwrite(buffer, 1, bytes, fout) != bytes) {
            fprintf(stderr, "❌ ERROR: Writing preview file\n");
            perror("    fwrite");
            fclose(fin);
            fclose(fout);
            return -1;
        }
        total_written += bytes;
    }
    printf("    ✅ Wrote %zu bytes to preview\n", total_written);
    
    fclose(fout);
    printf("    ✅ Preview file closed\n");
    fseek(fin, 0, SEEK_SET); // Reset to beginning for native file creation
    
    // Create native Apple II file (placeholder - just write a minimal file)
    printf("    Creating native file...\n");
    FILE* fnative = fopen(native_file, "wb");
    if (!fnative) {
        fprintf(stderr, "❌ ERROR: Cannot create native file: %s\n", native_file);
        perror("    fopen");
        fclose(fin);
        return -1;
    }
    printf("    ✅ Native file opened for writing\n");
    
    // Write a minimal placeholder native file
    // In a real implementation, this would be the converted Apple II graphics data
    // For now, write at least some data so the file exists
    unsigned char placeholder[8192] = {0};
    size_t native_written = fwrite(placeholder, 1, sizeof(placeholder), fnative);
    printf("    ✅ Wrote %zu bytes to native file\n", native_written);
    
    fclose(fnative);
    printf("    ✅ Native file closed\n");
    fclose(fin);
    printf("    ✅ Input file closed\n");
    
    printf(">>> create_output_files: SUCCESS\n");
    return 0;
}

/**
 * Main b2d conversion function
 * This is where the actual BMP to DHR conversion logic goes
 */
int b2d_actual_main(int argc, char** argv) {
    printf("=== B2D_ACTUAL_MAIN CALLED ===\n");
    printf("Arguments: %d\n", argc);
    
    // Print all arguments for debugging
    for (int i = 0; i < argc; i++) {
        printf("  Arg[%d]: '%s'\n", i, argv[i]);
    }
    
    // Parse command line arguments
    printf("Parsing arguments...\n");
    if (parse_arguments(argc, argv) != 0) {
        fprintf(stderr, "❌ ERROR: Failed to parse arguments\n");
        return -1;
    }
    printf("✅ Arguments parsed successfully\n");
    printf("   Input file: %s\n", bmpfile);
    
    // Check if input file exists
    printf("Checking if input file exists...\n");
    FILE* test = fopen(bmpfile, "rb");
    if (!test) {
        fprintf(stderr, "❌ ERROR: Cannot open input file: %s\n", bmpfile);
        fprintf(stderr, "   Current working directory: ");
        system("pwd");
        return -1;
    }
    printf("✅ Input file opened successfully\n");
    
    // Get file size for debugging
    fseek(test, 0, SEEK_END);
    long filesize = ftell(test);
    fseek(test, 0, SEEK_SET);
    printf("   File size: %ld bytes\n", filesize);
    fclose(test);
    
    // Create output files (preview and native format)
    printf("Creating output files...\n");
    if (create_output_files(bmpfile) != 0) {
        fprintf(stderr, "❌ ERROR: Failed to create output files\n");
        return -1;
    }
    printf("✅ Output files created successfully\n");
    
    // TODO: Implement full Apple II conversion
    // This would include:
    // 1. Load and parse BMP file
    // 2. Apply dithering and color reduction
    // 3. Convert to Apple II screen format (HGR/DHGR/LGR/DLGR)
    // 4. Save native Apple II files (.bin, etc.)
    
    printf("=== B2D CONVERSION COMPLETE ===\n");
    return 0;  // Success
}
