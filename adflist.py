#!/usr/bin/env python3
"""List files in an Amiga ADF disk image."""
import sys
import struct

def read_block(data, block_num):
    """Read a 512-byte block from the disk image."""
    offset = block_num * 512
    return data[offset:offset + 512]

def read_int32_be(block, offset):
    """Read big-endian 32-bit signed integer."""
    return struct.unpack('>i', block[offset:offset + 4])[0]

def read_uint32_be(block, offset):
    """Read big-endian 32-bit unsigned integer."""
    return struct.unpack('>I', block[offset:offset + 4])[0]

def get_filename(block):
    """Extract filename from a file header block."""
    name_len = block[432]
    if name_len > 30:
        name_len = 30
    return block[433:433 + name_len].decode('iso-8859-1', errors='replace')

def list_adf(filename):
    """List all files in an ADF disk image."""
    with open(filename, 'rb') as f:
        data = f.read()

    total_sectors = len(data) // 512
    is_hd = total_sectors > 1760
    root_block_num = 1760 if is_hd else 880

    print(f"ADF: {filename}")
    print(f"Size: {len(data)} bytes ({total_sectors} sectors)")
    print(f"Type: {'HD (1.76MB)' if is_hd else 'DD (880KB)'}")
    print(f"Root block: {root_block_num}")
    print()

    root = read_block(data, root_block_num)

    # Get volume name
    vol_name_len = root[432]
    if vol_name_len > 30:
        vol_name_len = 30
    vol_name = root[433:433 + vol_name_len].decode('iso-8859-1', errors='replace')
    print(f"Volume: {vol_name}")
    print("-" * 40)

    # Read hash table (72 entries at offset 24)
    files = []
    for i in range(72):
        entry = read_int32_be(root, 24 + i * 4)
        if entry != 0:
            # Follow the hash chain
            block_num = entry
            while block_num != 0:
                block = read_block(data, block_num)
                block_type = read_int32_be(block, 0)
                sec_type = read_int32_be(block, 508)

                if block_type == 2:  # T_HEADER
                    name = get_filename(block)
                    file_size = read_int32_be(block, 324)

                    if sec_type == -3:  # ST_FILE
                        files.append((name, file_size, 'FILE'))
                    elif sec_type == 2:  # ST_USERDIR
                        files.append((name, 0, 'DIR'))

                # Get hash chain (next entry with same hash)
                block_num = read_int32_be(block, 496)

    # Sort and display files
    files.sort(key=lambda x: x[0].lower())

    total_size = 0
    for name, size, ftype in files:
        if ftype == 'DIR':
            print(f"  [DIR]  {name}")
        else:
            print(f"  {size:>7} {name}")
            total_size += size

    print("-" * 40)
    print(f"{len(files)} files, {total_size} bytes total")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: adflist.py <diskimage.adf>")
        sys.exit(1)

    list_adf(sys.argv[1])
