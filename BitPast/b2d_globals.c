/*
 * b2d_globals.c
 * Definitions for all global variables declared in b2d.h
 * 
 * This file MUST be the only one that defines these variables.
 * We define B2D_IMPLEMENTATION to tell b2d.h we're creating the actual definitions here.
 */

#define B2D_IMPLEMENTATION 1
#include "b2d.h"

/* Output buffers */
uchar *dhrbuf = NULL;
uchar *hgrbuf = NULL;

/* Static structures for processing */
BITMAPFILEHEADER bfi;
BITMAPINFOHEADER bmi;
BMPHEADER mybmp, maskbmp;
RGBQUAD sbmp[256], maskpalette[256];

/* Overlay file for screen titling and framing */
FILE *fpmask = NULL;
unsigned char remap[256];

/* File names */
char bmpfile[MAXF], dibfile[MAXF], scaledfile[MAXF], previewfile[MAXF];
char reformatfile[MAXF], maskfile[MAXF], fmask[MAXF];
char spritefile[MAXF], mainfile[MAXF], auxfile[MAXF], a2fcfile[MAXF];
char usertextfile[MAXF], vbmpfile[MAXF], fname[MAXF];
char hgrcolor[MAXF], hgrmono[MAXF], hgrwork[MAXF];

/* Flags and settings */
int mono = 0, dosheader = 0, spritemask = 0, tags = 0;
int backgroundcolor = 0, quietmode = 1, diffuse = 0, merge = 0, scale = 0, applesoft = 0, outputtype = BIN_OUTPUT;
int reformat = 0, debug = 0;
int preview = 0, vbmp = 0, hgroutput = 0;
int use_overlay = 0, maskpixel = 0, overcolor = 0, clearcolor = 5;
int xmatrix = 0, ymatrix = 0, threshold = 0;

ushort bmpwidth = 0, bmpheight = 0, spritewidth = 0;

sshort justify = 0, jxoffset = -1, jyoffset = -1;

int doubleblack = 0, doublewhite = 0, doublecolors = 1, ditheroneline = 0;

int globalclip = 0;
int ditherstart = 0;
int bleed = 16;
int paletteclip = 0;

sshort customdivisor;
sshort customdither[3][11];

unsigned char msk[] = {0x80, 0x40, 0x20, 0x10, 0x8, 0x4, 0x2, 0x1};
int reverse = 0;

/* Line buffers */
uchar bmpscanline[1920];
uchar bmpscanline2[1920];
uchar dibscanline1[1920];
uchar dibscanline2[1920];
uchar dibscanline3[1920];
uchar dibscanline4[1920];
uchar previewline[1920];
uchar maskline[560];

/* Floyd-Steinberg Dithering */
uchar dither = 0, errorsum = 0, serpentine = 0;

sshort redDither[640], greenDither[640], blueDither[640];
sshort redSeed[640], greenSeed[640], blueSeed[640];
sshort redSeed2[640], greenSeed2[640], blueSeed2[640];
sshort *colorptr, *seedptr, *seed2ptr, color_error;

int colorbleed = 100;

/* Color HGR dither routines */
sshort redSave[320], greenSave[320], blueSave[320];
sshort OrangeBlueError[320], GreenVioletError[320];
uchar HgrPixelPalette[320];
uchar dither7 = 0, hgrdither = 0;

/* HGR output routines */
unsigned char palettebits[40], hgrpaltype = 255;
unsigned char hgrcolortype = 0;
unsigned char work280[280], buf280[560];

/* Built-in palette options */
uchar kegs32colors[16][3] = {
    {0, 0, 0}, {221, 0, 51}, {0, 0, 153}, {221, 0, 221},
    {0, 119, 0}, {85, 85, 85}, {34, 34, 255}, {102, 170, 255},
    {136, 85, 34}, {255, 102, 0}, {170, 170, 170}, {255, 153, 136},
    {0, 221, 0}, {255, 255, 0}, {0, 255, 153}, {255, 255, 255}
};

uchar ciderpresscolors[16][3] = {
    {0, 0, 0}, {221, 0, 51}, {0, 0, 153}, {221, 34, 221},
    {0, 119, 34}, {85, 85, 85}, {34, 34, 255}, {102, 170, 255},
    {136, 85, 0}, {255, 102, 0}, {170, 170, 170}, {255, 153, 136},
    {17, 221, 0}, {255, 255, 0}, {68, 255, 153}, {255, 255, 255}
};

uchar awinoldcolors[16][3] = {
    {0, 0, 0}, {208, 0, 48}, {0, 0, 128}, {255, 0, 255},
    {0, 128, 0}, {128, 128, 128}, {0, 0, 255}, {96, 160, 255},
    {128, 80, 0}, {255, 128, 0}, {192, 192, 192}, {255, 144, 128},
    {0, 255, 0}, {255, 255, 0}, {64, 255, 144}, {255, 255, 255}
};

uchar awinnewcolors[16][3] = {
    {0, 0, 0}, {157, 9, 102}, {42, 42, 229}, {199, 52, 255},
    {0, 118, 26}, {128, 128, 128}, {13, 161, 255}, {170, 170, 255},
    {85, 85, 0}, {242, 94, 0}, {192, 192, 192}, {255, 137, 229},
    {56, 203, 0}, {213, 213, 26}, {98, 246, 153}, {255, 255, 255}
};

uchar wikipedia[16][3] = {
    {0, 0, 0}, {114, 38, 64}, {64, 51, 127}, {228, 52, 254},
    {14, 89, 64}, {128, 128, 128}, {27, 154, 254}, {191, 179, 255},
    {64, 76, 0}, {228, 101, 1}, {128, 128, 128}, {241, 166, 191},
    {27, 203, 1}, {191, 204, 128}, {141, 217, 191}, {255, 255, 255}
};

uchar grpal[16][3] = {
    {0, 0, 0}, {148, 12, 125}, {32, 54, 212}, {188, 55, 255},
    {51, 111, 0}, {126, 126, 126}, {7, 168, 225}, {158, 172, 255},
    {99, 77, 0}, {249, 86, 29}, {126, 126, 126}, {255, 129, 236},
    {67, 200, 0}, {221, 206, 23}, {93, 248, 133}, {255, 255, 255}
};

uchar hgrpal[16][3] = {
    {0x00, 0x00, 0x00}, {0xad, 0x18, 0x28}, {0x55, 0x1b, 0xe1}, {0xe8, 0x2c, 0xf8},
    {0x01, 0x73, 0x63}, {0x7e, 0x82, 0x7f}, {0x34, 0x85, 0xfc}, {0xd1, 0x95, 0xff},
    {0x33, 0x6f, 0x00}, {0xd0, 0x81, 0x01}, {0x7f, 0x7e, 0x77}, {0xfe, 0x93, 0xa3},
    {0x1d, 0xd6, 0x09}, {0xae, 0xea, 0x22}, {0x5b, 0xeb, 0xd9}, {0xff, 0xff, 0xff}
};

uchar SuperConvert[16][3] = {
    {0, 0, 0}, {221, 0, 51}, {0, 0, 153}, {221, 0, 221},
    {0, 119, 0}, {85, 85, 85}, {34, 34, 255}, {102, 170, 255},
    {136, 85, 34}, {255, 102, 0}, {170, 170, 170}, {255, 153, 136},
    {0, 221, 0}, {255, 255, 0}, {0, 255, 153}, {255, 255, 255}
};

uchar Jace[16][3] = {
    {0, 0, 0}, {177, 0, 93}, {32, 41, 255}, {210, 41, 255},
    {0, 127, 34}, {127, 127, 127}, {0, 168, 255}, {160, 168, 255},
    {94, 86, 0}, {255, 86, 0}, {127, 127, 127}, {255, 127, 220},
    {44, 213, 0}, {222, 213, 0}, {77, 255, 161}, {255, 255, 255}
};

uchar Cybernesto[16][3] = {
    {0, 0, 0}, {227, 30, 96}, {96, 78, 189}, {255, 68, 253},
    {0, 163, 96}, {156, 156, 156}, {20, 207, 253}, {208, 195, 255},
    {96, 114, 3}, {255, 106, 60}, {156, 156, 156}, {255, 160, 208},
    {20, 245, 60}, {208, 221, 141}, {114, 255, 208}, {255, 255, 255}
};

sshort pseudocount = 0;
sshort pseudolist[PSEUDOMAX];
ushort pseudowork[16][3];

uchar PseudoPalette[16][3] = {
    {0, 0, 0}, {184, 6, 88}, {16, 27, 182}, {204, 27, 238},
    {25, 115, 0}, {105, 105, 105}, {20, 101, 240}, {130, 171, 255},
    {117, 81, 17}, {252, 94, 14}, {148, 148, 148}, {255, 141, 186},
    {33, 210, 0}, {238, 230, 11}, {46, 251, 143}, {255, 255, 255}
};

uchar rgbCanvasArray[16][3];
uchar rgbBmpArray[16][3];
uchar rgbXmpArray[16][3];
uchar rgbVgaArray[16][3];
uchar rgbPcxArray[16][3];

uchar rgbArray[16][3], rgbAppleArray[16][3], rgbPreview[16][3], rgbUser[16][3];
double rgbLuma[16], rgbDouble[16][3];
double rgbOrangeDouble[3][3], rgbGreenDouble[3][3];
double rgbOrangeLuma[3], rgbGreenLuma[3];

double rgbLumaBrighten[16], rgbDoubleBrighten[16][3];
double rgbLumaDarken[16], rgbDoubleDarken[16][3];

unsigned HB[192] = {
    0x2000, 0x2400, 0x2800, 0x2C00, 0x3000, 0x3400, 0x3800, 0x3C00,
    0x2080, 0x2480, 0x2880, 0x2C80, 0x3080, 0x3480, 0x3880, 0x3C80,
    0x2100, 0x2500, 0x2900, 0x2D00, 0x3100, 0x3500, 0x3900, 0x3D00,
    0x2180, 0x2580, 0x2980, 0x2D80, 0x3180, 0x3580, 0x3980, 0x3D80,
    0x2200, 0x2600, 0x2A00, 0x2E00, 0x3200, 0x3600, 0x3A00, 0x3E00,
    0x2280, 0x2680, 0x2A80, 0x2E80, 0x3280, 0x3680, 0x3A80, 0x3E80,
    0x2300, 0x2700, 0x2B00, 0x2F00, 0x3300, 0x3700, 0x3B00, 0x3F00,
    0x2380, 0x2780, 0x2B80, 0x2F80, 0x3380, 0x3780, 0x3B80, 0x3F80,
    0x2028, 0x2428, 0x2828, 0x2C28, 0x3028, 0x3428, 0x3828, 0x3C28,
    0x20A8, 0x24A8, 0x28A8, 0x2CA8, 0x30A8, 0x34A8, 0x38A8, 0x3CA8,
    0x2128, 0x2528, 0x2928, 0x2D28, 0x3128, 0x3528, 0x3928, 0x3D28,
    0x21A8, 0x25A8, 0x29A8, 0x2DA8, 0x31A8, 0x35A8, 0x39A8, 0x3DA8,
    0x2228, 0x2628, 0x2A28, 0x2E28, 0x3228, 0x3628, 0x3A28, 0x3E28,
    0x22A8, 0x26A8, 0x2AA8, 0x2EA8, 0x32A8, 0x36A8, 0x3AA8, 0x3EA8,
    0x2328, 0x2728, 0x2B28, 0x2F28, 0x3328, 0x3728, 0x3B28, 0x3F28,
    0x23A8, 0x27A8, 0x2BA8, 0x2FA8, 0x33A8, 0x37A8, 0x3BA8, 0x3FA8,
    0x2050, 0x2450, 0x2850, 0x2C50, 0x3050, 0x3450, 0x3850, 0x3C50,
    0x20D0, 0x24D0, 0x28D0, 0x2CD0, 0x30D0, 0x34D0, 0x38D0, 0x3CD0,
    0x2150, 0x2550, 0x2950, 0x2D50, 0x3150, 0x3550, 0x3950, 0x3D50,
    0x21D0, 0x25D0, 0x29D0, 0x2DD0, 0x31D0, 0x35D0, 0x39D0, 0x3DD0,
    0x2250, 0x2650, 0x2A50, 0x2E50, 0x3250, 0x3650, 0x3A50, 0x3E50,
    0x22D0, 0x26D0, 0x2AD0, 0x2ED0, 0x32D0, 0x36D0, 0x3AD0, 0x3ED0,
    0x2350, 0x2750, 0x2B50, 0x2F50, 0x3350, 0x3750, 0x3B50, 0x3F50,
    0x23D0, 0x27D0, 0x2BD0, 0x2FD0, 0x33D0, 0x37D0, 0x3BD0, 0x3FD0
};

uchar dhrbytes[16][4] = {
    {0x00, 0x00, 0x00, 0x00}, {0x08, 0x11, 0x22, 0x44},
    {0x11, 0x22, 0x44, 0x08}, {0x19, 0x33, 0x66, 0x4C},
    {0x22, 0x44, 0x08, 0x11}, {0x2A, 0x55, 0x2A, 0x55},
    {0x33, 0x66, 0x4C, 0x19}, {0x3B, 0x77, 0x6E, 0x5D},
    {0x44, 0x08, 0x11, 0x22}, {0x4C, 0x19, 0x33, 0x66},
    {0x55, 0x2A, 0x55, 0x2A}, {0x5D, 0x3B, 0x77, 0x6E},
    {0x66, 0x4C, 0x19, 0x33}, {0x6E, 0x5D, 0x3B, 0x77},
    {0x77, 0x6E, 0x5D, 0x3B}, {0x7F, 0x7F, 0x7F, 0x7F}
};

sshort lores = 0, loresoutput = 0, appletop = 0;

unsigned textbase[24] = {
    0x0400, 0x0480, 0x0500, 0x0580, 0x0600, 0x0680, 0x0700, 0x0780,
    0x0428, 0x04A8, 0x0528, 0x05A8, 0x0628, 0x06A8, 0x0728, 0x07A8,
    0x0450, 0x04D0, 0x0550, 0x05D0, 0x0650, 0x06D0, 0x0750, 0x07D0
};

unsigned char dloauxcolor[16] = {
    0, 8, 1, 9, 2, 10, 3, 11, 4, 12, 5, 13, 6, 14, 7, 15
};

uchar mix25to24[24][2] = {
    {24, 1}, {23, 2}, {22, 3}, {21, 4}, {20, 5}, {19, 6},
    {18, 7}, {17, 8}, {16, 9}, {15, 10}, {14, 11}, {13, 12},
    {12, 13}, {11, 14}, {10, 15}, {9, 16}, {8, 17}, {7, 18},
    {6, 19}, {5, 20}, {4, 21}, {3, 22}, {2, 23}, {1, 24}
};

uchar pixel320to280[7][4] = {
    {7, 1, 0, 1}, {6, 2, 1, 2}, {5, 3, 2, 3}, {4, 4, 3, 4},
    {3, 5, 4, 5}, {2, 6, 5, 6}, {1, 7, 6, 7}
};

uchar rgbVBMP[16][3] = {
    {0, 0, 0}, {114, 38, 64}, {64, 51, 127}, {228, 52, 254},
    {14, 89, 64}, {128, 128, 128}, {27, 154, 254}, {191, 179, 255},
    {64, 76, 0}, {228, 101, 1}, {128, 128, 128}, {241, 166, 191},
    {27, 203, 1}, {191, 204, 128}, {141, 217, 191}, {255, 255, 255}
};

unsigned char RemapLoToHi[16] = {
    LOBLACK, LORED, LOBROWN, LOORANGE, LODKGREEN, LOGRAY, LOLTGREEN, LOYELLOW,
    LODKBLUE, LOPURPLE, LOGREY, LOPINK, LOMEDBLUE, LOLTBLUE, LOAQUA, LOWHITE
};

unsigned char mono192[62] = {
    0x42, 0x4D, 0x3E, 0x36, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x3E, 0x00, 0x00, 0x00, 0x28, 0x00,
    0x00, 0x00, 0x30, 0x02, 0x00, 0x00, 0xC0, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x36, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0xFF, 0xFF, 0xFF, 0x00
};

unsigned char mono280[62] = {
    0x42, 0x4D, 0x3E, 0x1B, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x3E, 0x00, 0x00, 0x00, 0x28, 0x00,
    0x00, 0x00, 0x18, 0x01, 0x00, 0x00, 0xC0, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x1B, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0xFF, 0xFF, 0xFF, 0x00
};

uchar dhgr2hgr[16] = {
    HBLACK, HBLACK, HBLACK, HVIOLET, HBLACK, HBLACK, HBLUE, HBLACK,
    HBLACK, HORANGE, HBLACK, HBLACK, HGREEN, HBLACK, HBLACK, HWHITE
};
