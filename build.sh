#!/bin/sh

set -e

64tass --cbm-prg --list init.txt --output init.prg init.asm

64tass --cbm-prg --list init_b15.txt --output init.b15 init_b15.asm

64tass --cbm-prg --long-branch --list game.txt --output game.prg game.asm

# build the BASIC loader stub from start.bas
petcat -w40 -o start.prg -- start.bas

# package everything into a .d80
rm -f binvaders.d80
cat << EOF | c1541
format binvaders,dm d64 binvaders.d64 8
write start.prg start.prg
write init.prg init.prg
write init.b15 init.b15
write game.prg game.prg
EOF

echo "Built binvaders.d64"
