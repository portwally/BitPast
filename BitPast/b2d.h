/* ---------------------------------------------------------------------
Bmp2DHR (C) Copyright Bill Buckels 2014.
All Rights Reserved.

Module Name - Description
-------------------------

b2d.h - header file for b2d.c (main program)

Written by: Bill Buckels
Email:      bbuckels@mts.net

Version 1.0 - Modified for Swift Integration
*/

#ifndef BMP2SHR_H
#define BMP2SHR_H 1

/* ===== CRITICAL: Include standard headers FIRST ===== */
#include <stdio.h>      /* For FILE, printf, fprintf, NULL */
#include <stdlib.h>     /* For NULL, malloc, free */
#include <string.h>     /* For string functions */
#include <stddef.h>     /* For size_t, NULL */

/* ***************************************************************** */
/* ========================== defines ============================== */
/* ***************************************************************** */

/* file name length max */
#ifdef MSDOS
#define MAXF 128
#else
#define MAXF 256
#endif

#define SUCCESS 0
#define INVALID -1
#define RETRY 911
#define BIN_OUTPUT 1
#define SPRITE_OUTPUT 2

/* constants for the biCompression field in a BMP header */
#define BI_RGB      0L
#define BI_RLE8     1L
#define BI_RLE4     2L

/* DHGR, DLGR, LGR colors - LGR color order */
#define LOBLACK   	0
#define LORED     	1
#define LODKBLUE 	2
#define LOPURPLE  	3
#define LODKGREEN	4
#define LOGRAY    	5
#define LOMEDBLUE	6
#define LOLTBLUE 	7
#define LOBROWN   	8
#define LOORANGE  	9
#define LOGREY    	10
#define LOPINK    	11
#define LOLTGREEN	12
#define LOYELLOW  	13
#define LOAQUA    	14
#define LOWHITE   	15

/* HGR color constants */
#define	HBLACK 	0
#define HGREEN 	1
#define HVIOLET 2
#define HORANGE 3
#define HBLUE	4
#define HWHITE	5

#define RED    0
#define GREEN  1
#define BLUE   2

#define FLOYDSTEINBERG 1
#define JARVIS 2
#define STUCKI 3
#define ATKINSON 4
#define BURKES 5
#define SIERRA 6
#define SIERRATWO 7
#define SIERRALITE 8
#define BUCKELS 9
#define CUSTOM 10

#define ASCIIZ	0
#define CRETURN 13
#define LFEED	10

#define PSEUDOMAX 100

/* ***************************************************************** */
/* ========================== typedefs ============================= */
/* ***************************************************************** */

typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned long ulong;
typedef short sshort;

/* Bitmap Header structures */
#pragma pack(push, 1)

typedef struct tagBITMAPINFOHEADER
{
    unsigned int   biSize;
    unsigned int   biWidth;
    unsigned int   biHeight;
    unsigned short biPlanes;
    unsigned short biBitCount;
    unsigned int   biCompression;
    unsigned int   biSizeImage;
    unsigned int   biXPelsPerMeter;
    unsigned int   biYPelsPerMeter;
    unsigned int   biClrUsed;
    unsigned int   biClrImportant;
} BITMAPINFOHEADER;

typedef struct tagBITMAPFILEHEADER
{
    unsigned char   bfType[2];
    unsigned int    bfSize;
    unsigned short  bfReserved1;
    unsigned short  bfReserved2;
    unsigned int    bfOffBits;
} BITMAPFILEHEADER;

typedef struct tagBMPHEADER
{
    BITMAPFILEHEADER bfi;
    BITMAPINFOHEADER bmi;
} BMPHEADER;

#pragma pack(pop)

#ifdef MINGW
typedef struct __attribute__((__packed__)) tagRGBQUAD
#else
typedef struct tagRGBQUAD
#endif
{
    unsigned char    rgbBlue;
    unsigned char    rgbGreen;
    unsigned char    rgbRed;
    unsigned char    rgbReserved;
} RGBQUAD;

/* ***************************************************************** */
/* =================== prototypes as required  ===================== */
/* ***************************************************************** */

sshort GetUserTextFile(void);
int dhrgetpixel(int x,int y);

/* Wrapper functions for Swift integration */
int b2d_main_wrapper(int argc, char** argv);
int b2d_actual_main(int argc, char** argv);

/* ***************************************************************** */
/* ========================== globals ============================== */
/* ***************************************************************** */

/* NOTE: These are extern declarations - actual definitions should be in a .c file */
#ifndef B2D_IMPLEMENTATION

extern uchar *dhrbuf;
extern uchar *hgrbuf;

extern BITMAPFILEHEADER bfi;
extern BITMAPINFOHEADER bmi;
extern BMPHEADER mybmp, maskbmp;
extern RGBQUAD sbmp[256], maskpalette[256];

extern FILE *fpmask;
extern unsigned char remap[256];

extern char bmpfile[MAXF], dibfile[MAXF], scaledfile[MAXF], previewfile[MAXF];
extern char reformatfile[MAXF], maskfile[MAXF], fmask[MAXF];
extern char spritefile[MAXF], mainfile[MAXF], auxfile[MAXF], a2fcfile[MAXF];
extern char usertextfile[MAXF], vbmpfile[MAXF], fname[MAXF];
extern char hgrcolor[MAXF], hgrmono[MAXF], hgrwork[MAXF];

extern int mono, dosheader, spritemask, tags;
extern int backgroundcolor, quietmode, diffuse, merge, scale, applesoft, outputtype;
extern int reformat, debug;
extern int preview, vbmp, hgroutput;
extern int use_overlay, maskpixel, overcolor, clearcolor;
extern int xmatrix, ymatrix, threshold;

extern ushort bmpwidth, bmpheight, spritewidth;

extern sshort justify, jxoffset, jyoffset;

extern int doubleblack, doublewhite, doublecolors, ditheroneline;

extern int globalclip;
extern int ditherstart;
extern int bleed;
extern int paletteclip;

extern sshort customdivisor;
extern sshort customdither[3][11];

extern unsigned char msk[8];
extern int reverse;

extern uchar bmpscanline[1920];
extern uchar bmpscanline2[1920];
extern uchar dibscanline1[1920];
extern uchar dibscanline2[1920];
extern uchar dibscanline3[1920];
extern uchar dibscanline4[1920];
extern uchar previewline[1920];
extern uchar maskline[560];

extern uchar dither, errorsum, serpentine;

extern sshort redDither[640], greenDither[640], blueDither[640];
extern sshort redSeed[640], greenSeed[640], blueSeed[640];
extern sshort redSeed2[640], greenSeed2[640], blueSeed2[640];
extern sshort *colorptr, *seedptr, *seed2ptr, color_error;

extern int colorbleed;

extern sshort redSave[320], greenSave[320], blueSave[320];
extern sshort OrangeBlueError[320], GreenVioletError[320];
extern uchar HgrPixelPalette[320];
extern uchar dither7, hgrdither;

extern unsigned char palettebits[40], hgrpaltype;
extern unsigned char hgrcolortype;
extern unsigned char work280[280], buf280[560];

extern uchar kegs32colors[16][3];
extern uchar ciderpresscolors[16][3];
extern uchar awinoldcolors[16][3];
extern uchar awinnewcolors[16][3];
extern uchar wikipedia[16][3];
extern uchar grpal[16][3];
extern uchar hgrpal[16][3];
extern uchar SuperConvert[16][3];
extern uchar Jace[16][3];
extern uchar Cybernesto[16][3];

extern sshort pseudocount;
extern sshort pseudolist[PSEUDOMAX];
extern ushort pseudowork[16][3];

extern uchar PseudoPalette[16][3];

extern uchar rgbCanvasArray[16][3], rgbBmpArray[16][3], rgbXmpArray[16][3];
extern uchar rgbVgaArray[16][3], rgbPcxArray[16][3];

extern uchar rgbArray[16][3], rgbAppleArray[16][3], rgbPreview[16][3], rgbUser[16][3];
extern double rgbLuma[16], rgbDouble[16][3];
extern double rgbOrangeDouble[3][3], rgbGreenDouble[3][3];
extern double rgbOrangeLuma[3], rgbGreenLuma[3];

extern double rgbLumaBrighten[16], rgbDoubleBrighten[16][3];
extern double rgbLumaDarken[16], rgbDoubleDarken[16][3];

extern unsigned HB[192];

extern uchar dhrbytes[16][4];

extern sshort lores, loresoutput, appletop;

extern unsigned textbase[24];

extern unsigned char dloauxcolor[16];

extern uchar mix25to24[24][2];

extern uchar pixel320to280[7][4];

extern uchar rgbVBMP[16][3];

extern unsigned char RemapLoToHi[16];

extern unsigned char mono192[62];
extern unsigned char mono280[62];

extern uchar dhgr2hgr[16];

extern unsigned char tomthumb[256];
extern unsigned char hgrpaltype;
extern unsigned char hgrcolortype;



#endif /* B2D_IMPLEMENTATION */

#endif /* BMP2SHR_H */
