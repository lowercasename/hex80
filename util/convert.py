import sys

output_file = open(sys.argv[2],'w')
output_file.write("unsigned char ROM[256] = {")
output_file.close()

output_file = open(sys.argv[2],'ab')
for b in open(sys.argv[1], 'rb').read():
    output_file.write(b'0x%02X,' %b)
output_file.close()

output_file = open(sys.argv[2],'a')
output_file.write("};")
output_file.close()
