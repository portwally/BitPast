#!/usr/bin/env python3
"""List files in an Amstrad CPC DSK disk image."""
import sys
import struct

def read_dsk(filename):
    """Read and list contents of a CPC DSK file."""
    with open(filename, 'rb') as f:
        data = f.read()

    # Check disk header
    header = data[:256]

    if header[:8] == b'MV - CPC':
        disk_type = "Standard"
    elif header[:16] == b'EXTENDED CPC DSK':
        disk_type = "Extended"
    else:
        print(f"Unknown disk format: {header[:16]}")
        return

    # Parse header
    creator = header[0x22:0x30].decode('ascii', errors='replace').strip('\x00')
    num_tracks = header[0x30]
    num_sides = header[0x31]
    track_size_header = struct.unpack('<H', header[0x32:0x34])[0]

    print(f"DSK: {filename}")
    print(f"Type: {disk_type}")
    print(f"Creator: {creator}")
    print(f"Tracks: {num_tracks}, Sides: {num_sides}")
    print("-" * 50)

    # For extended format, track sizes are in the header at 0x34
    if disk_type == "Extended":
        track_sizes = []
        for i in range(num_tracks * num_sides):
            size_byte = header[0x34 + i]
            track_sizes.append(size_byte * 256)
    else:
        track_sizes = [track_size_header] * (num_tracks * num_sides)

    # Calculate offset to track 0
    track_offset = 256  # Skip disk header

    # Read track 0 info header
    track_info = data[track_offset:track_offset + 256]

    # Check for Track-Info signature (may have \r\n or \0 padding)
    if not track_info[:10] == b'Track-Info':
        print("Could not find track info header")
        print(f"Found: {track_info[:16]}")
        return

    track_num = track_info[0x10]
    side_num = track_info[0x11]
    sector_size_code = track_info[0x14]
    num_sectors = track_info[0x15]

    sector_size = 128 << sector_size_code  # 0=128, 1=256, 2=512, 3=1024

    print(f"Track 0: {num_sectors} sectors, {sector_size} bytes each")
    print()

    # Parse sector info table (8 bytes per sector starting at offset 0x18)
    sectors = []
    for i in range(num_sectors):
        info_offset = 0x18 + i * 8
        sect_track = track_info[info_offset]
        sect_side = track_info[info_offset + 1]
        sect_id = track_info[info_offset + 2]
        sect_size_code = track_info[info_offset + 3]
        sectors.append((sect_id, 128 << sect_size_code))

    # Data starts after the 256-byte track info header
    data_offset = track_offset + 256

    # Calculate actual sector size from data (may differ from header)
    actual_sector_size = sectors[0][1] if sectors else sector_size

    # Read directory entries (first 4 sectors = 2KB for directory)
    # AMSDOS/CP/M directory format - 64 entries of 32 bytes
    dir_data = data[data_offset:data_offset + 4 * actual_sector_size]

    files = {}

    for i in range(len(dir_data) // 32):
        entry = dir_data[i * 32:(i + 1) * 32]

        user = entry[0]
        if user == 0xE5:  # Deleted entry
            continue
        if user > 31:  # Invalid user number
            continue

        # Filename (8 bytes) + extension (3 bytes)
        name = entry[1:9].decode('ascii', errors='replace').strip()
        ext = entry[9:12].decode('ascii', errors='replace').strip()

        # Clear high bits (used for flags)
        name = ''.join(chr(ord(c) & 0x7F) for c in name).strip()
        ext = ''.join(chr(ord(c) & 0x7F) for c in ext).strip()

        extent = entry[12]
        records = entry[15]  # Number of 128-byte records in this extent

        full_name = f"{name}.{ext}" if ext else name

        # Accumulate size across extents
        if full_name not in files:
            files[full_name] = {'user': user, 'size': 0, 'extents': 0}

        files[full_name]['size'] += records * 128
        files[full_name]['extents'] += 1

    # Display files
    print("Files:")
    total_size = 0
    for name, info in sorted(files.items()):
        size = info['size']
        print(f"  {size:>7} {name}")
        total_size += size

    print("-" * 50)
    print(f"{len(files)} files, {total_size} bytes total")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: dsklist.py <diskimage.dsk>")
        sys.exit(1)

    read_dsk(sys.argv[1])
