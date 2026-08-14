import sys
import struct

def make_gui(filepath):
    with open(filepath, 'r+b') as f:
        f.seek(0x3c)
        pe_offset = struct.unpack('<I', f.read(4))[0]
        f.seek(pe_offset)
        sig = f.read(4)
        if sig != b'PE\0\0':
            print("Not a PE file")
            return
        f.seek(pe_offset + 24)
        magic = struct.unpack('<H', f.read(2))[0]
        if magic == 0x10b: # PE32
            subsys_offset = pe_offset + 24 + 68
        elif magic == 0x20b: # PE32+
            subsys_offset = pe_offset + 24 + 68
        else:
            return
        
        f.seek(subsys_offset)
        subsys = struct.unpack('<H', f.read(2))[0]
        print(f"Old subsystem: {subsys}")
        f.seek(subsys_offset)
        f.write(struct.pack('<H', 2)) # 2 = GUI
        print("Set subsystem to 2 (GUI)")

if __name__ == '__main__':
    make_gui(sys.argv[1])
