import sys

output_file = open(sys.argv[2],'wb')

for b in open(sys.argv[1], 'rb').read():
  output_file.write(b'0x%02X,' %b)
output_file.close()