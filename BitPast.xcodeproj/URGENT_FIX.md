# URGENT FIX - Do This Now! 🚨

## The Problem:
- `tomthumb.h` isn't being included properly by Xcode
- This causes `FILE` and `NULL` to be undefined

## The Solution (Choose ONE):

### OPTION 1: Use the Fixed Header (Recommended) ✅

1. **In Xcode, remove `b2d.h` from your project** (right-click → Delete → Remove Reference)
2. **Rename `b2d_fixed.h` to `b2d.h`**:
   - In Finder, find `b2d_fixed.h`
   - Rename it to `b2d.h`
3. **Add the new `b2d.h` to your project**
4. **Clean and Build**

### OPTION 2: Edit the Existing b2d.h ✏️

Open `b2d.h` in Xcode and find these lines near the top:

```c
#ifndef BMP2SHR_H
   #define BMP2SHR_H 1

/* Prevent curses.h overlay() function from conflicting with our variable */
#define overlay overlay_curses_function

#include "tomthumb.h"

/* Now restore 'overlay' for our own use as a variable */
#undef overlay
```

**REPLACE with this:**

```c
#ifndef BMP2SHR_H
#define BMP2SHR_H 1

/* ===== CRITICAL: Include standard headers FIRST ===== */
#include <stdio.h>      /* For FILE, printf, fprintf, NULL */
#include <stdlib.h>     /* For NULL, malloc, free */
#include <string.h>     /* For string functions */
#include <stddef.h>     /* For size_t, NULL */
```

That's it! Remove the curses workaround and just put the includes directly.

## Then:
1. Product → Clean Build Folder (Shift+Cmd+K)
2. Product → Build (Cmd+B)
3. ✅ Should compile!

## Why This Fixes It:
- Xcode wasn't finding or including `tomthumb.h` properly
- By putting the includes directly in `b2d.h`, we bypass that problem
- `<stdio.h>` defines `FILE`
- `<stdlib.h>` and `<stddef.h>` define `NULL`

Try this now and let me know if it works! 🚀
