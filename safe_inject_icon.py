import sys
import os
import struct
import subprocess

def safe_inject_icon(exe_path, icon_path):
    print(f"Injecting {icon_path} into {exe_path} safely...")
    with open(exe_path, 'rb') as f:
        data = f.read()

    pe_offset = struct.unpack_from('<I', data, 0x3c)[0]
    num_sections = struct.unpack_from('<H', data, pe_offset + 6)[0]
    opt_header_size = struct.unpack_from('<H', data, pe_offset + 20)[0]
    sections_offset = pe_offset + 24 + opt_header_size
    
    max_pointer = 0
    for i in range(num_sections):
        section_start = sections_offset + i * 40
        size_raw = struct.unpack_from('<I', data, section_start + 16)[0]
        ptr_raw = struct.unpack_from('<I', data, section_start + 20)[0]
        if ptr_raw + size_raw > max_pointer:
            max_pointer = ptr_raw + size_raw
            
    # There might be some trailing alignment or debug directory after sections.
    # Actually, Windows PE loaders ignore data after sections, but let's be careful.
    # To be perfectly safe, let's look for the warp-packer magic signature if we can.
    # But usually, max_pointer is exactly the end of the PE.
    
    pe_size = max_pointer
    overlay = data[pe_size:]
    print(f"Original PE size: {pe_size}, Overlay size: {len(overlay)}")
    
    temp_pe = exe_path + ".temp.exe"
    with open(temp_pe, 'wb') as f:
        f.write(data[:pe_size])
        
    res = subprocess.run([r".\rcedit.exe", temp_pe, "--set-icon", icon_path])
    if res.returncode != 0:
        print("rcedit failed")
        sys.exit(1)
        
    with open(temp_pe, 'rb') as f:
        mod_pe = f.read()
        
    with open(exe_path, 'wb') as f:
        f.write(mod_pe)
        f.write(overlay)
        
    os.remove(temp_pe)
    print("Done! Re-attached payload.")

if __name__ == '__main__':
    safe_inject_icon(sys.argv[1], sys.argv[2])
