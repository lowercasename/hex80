import sys

def reverse_mask(a):
    return (((a & 0x1)  << 7) | ((a & 0x2)  << 5) |
         ((a & 0x4)  << 3) | ((a & 0x8)  << 1) |
         ((a & 0x10) >> 1) | ((a & 0x20) >> 3) |
         ((a & 0x40) >> 5) | ((a & 0x80) >> 7))

with open(sys.argv[1]) as f:
    for index, line in enumerate(f):
        # print("Line {}: {}".format(index, line.strip()))
        b_arr = [reverse_mask(bytes.fromhex(byte[2:].replace(',',''))[0]) for byte in line.strip().split()[1:4]]
        print(f'db {b_arr[0]:#0{4}x}, {b_arr[1]:#0{4}x}, {b_arr[2]:#0{4}x} ; {line.strip().split()[5]}')
        
        

