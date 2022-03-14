import sys

output_file = open(sys.argv[2],'w')
output_file.write("unsigned char ROM[4096] = {\n")
output_file.close()

output_file = open(sys.argv[2],'ab')
for i, b in enumerate(open(sys.argv[1], 'rb').read()):
    output_file.write(b'0x%02X,' %b)
    if (i + 1) % 16 == 0:
        output_file.write(b'\n')
output_file.close()

output_file = open(sys.argv[2],'a')
output_file.write("\n};\n")
output_file.close()
