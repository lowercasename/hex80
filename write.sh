#!/bin/sh

set -e

[ -z "$1" ] && echo "No input file supplied." && exit 1

echo "Compiling $1..."
rasm $1

echo "Writing $1 to ROM..."
minipro -p AT28C64B -w rasmoutput.bin

echo "Done!"
