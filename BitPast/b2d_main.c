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
    // Note: argv[0] is "b2d" (program name), argv[1] is the actual filename
    if (argc < 2) {
        fprintf(stderr, "Error: No input file specified\n");
        return -1;
    }
    
    // Copy the input filename (skip argv[0] which is "b2d")
    strncpy(bmpfile, argv[1], MAXF - 1);
    bmpfile[MAXF - 1] = '\0';

    // Parse options starting from argv[2]
    for (int i = 2; i < argc; i++) {
        char* arg = argv[i];

        if (strcmp(arg, "MONO") == 0) {
            mono = 1;
        }
        else if (strcmp(arg, "HGR") == 0) {
            hgroutput = 1;
        }
        else if (strcmp(arg, "DL") == 0) {
            lores = 2; // Double Lo-Res
        }
        else if (strcmp(arg, "L") == 0) {
            lores = 1; // Lo-Res
        }
        else if (strncmp(arg, "-D", 2) == 0) {
            dither = (uchar)atoi(arg + 2);
        }
        else if (strncmp(arg, "-E", 2) == 0) {
            int val = atoi(arg + 2);
        }
        else if (strncmp(arg, "-P", 2) == 0) {
            hgrpaltype = (unsigned char)atoi(arg + 2);
        }
        else if (strncmp(arg, "-X", 2) == 0) {
            xmatrix = atoi(arg + 2);
        }
        else if (strncmp(arg, "-Z", 2) == 0) {
            threshold = atoi(arg + 2);
        }
        else if (strcmp(arg, "-V") == 0) {
            preview = 1;
        }
    }
    
    return 0;
}

/**
 * Create a simple preview BMP file and native output
 * This is a placeholder - real implementation would convert to Apple II format
 */
static int create_output_files(const char* input_file) {
    // Extract base name without extension
    char base_name[MAXF];
    strncpy(base_name, input_file, MAXF - 1);
    base_name[MAXF - 1] = '\0';

    // Remove extension
    char* ext = strrchr(base_name, '.');
    if (ext != NULL) {
        *ext = '\0';
    }
    
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

    // Read input BMP
    FILE* fin = fopen(input_file, "rb");
    if (!fin) {
        fprintf(stderr, "ERROR: Cannot open input file: %s\n", input_file);
        return -1;
    }

    // Create preview BMP (copy input for now)
    FILE* fout = fopen(preview_file, "wb");
    if (!fout) {
        fprintf(stderr, "ERROR: Cannot create preview file: %s\n", preview_file);
        fclose(fin);
        return -1;
    }

    // Copy the BMP file
    char buffer[4096];
    size_t bytes;
    while ((bytes = fread(buffer, 1, sizeof(buffer), fin)) > 0) {
        if (fwrite(buffer, 1, bytes, fout) != bytes) {
            fprintf(stderr, "ERROR: Writing preview file\n");
            fclose(fin);
            fclose(fout);
            return -1;
        }
    }

    fclose(fout);
    fseek(fin, 0, SEEK_SET);

    // Create native Apple II file (placeholder)
    FILE* fnative = fopen(native_file, "wb");
    if (!fnative) {
        fprintf(stderr, "ERROR: Cannot create native file: %s\n", native_file);
        fclose(fin);
        return -1;
    }

    // Write placeholder native file
    unsigned char placeholder[8192] = {0};
    fwrite(placeholder, 1, sizeof(placeholder), fnative);

    fclose(fnative);
    fclose(fin);

    return 0;
}

/**
 * Main b2d conversion function
 * This is where the actual BMP to DHR conversion logic goes
 */
int b2d_actual_main(int argc, char** argv) {
    // Parse command line arguments
    if (parse_arguments(argc, argv) != 0) {
        fprintf(stderr, "ERROR: Failed to parse arguments\n");
        return -1;
    }

    // Check if input file exists
    FILE* test = fopen(bmpfile, "rb");
    if (!test) {
        fprintf(stderr, "ERROR: Cannot open input file: %s\n", bmpfile);
        return -1;
    }
    fclose(test);

    // Create output files (preview and native format)
    if (create_output_files(bmpfile) != 0) {
        fprintf(stderr, "ERROR: Failed to create output files\n");
        return -1;
    }

    // TODO: Implement full Apple II conversion
    // This would include:
    // 1. Load and parse BMP file
    // 2. Apply dithering and color reduction
    // 3. Convert to Apple II screen format (HGR/DHGR/LGR/DLGR)
    // 4. Save native Apple II files (.bin, etc.)

    return 0;
}
