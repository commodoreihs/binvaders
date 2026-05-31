# binvaders
Original Commodore PET Space Invaders game ported to run on CBM-II hardware (not the p500)

The original Commodore PET Space Invaders was written by Satoshi Matsuoka.

This code is based off my disassembly of the original PET Space Invaders code: https://github.com/commodoreihs/PET_Invaders_Disassembly

My goal for this port was to implement the original PET Space Invaders as close to the original code as possible. Any changes are necessary for the game to run on CBM-II. No changes were made to intentially modify or enhance gameplay. So, while the CBM-II line has 80 column graphics, gameplay is left at the original 40 column, and while the CBM-II machines have a SID chip for sound, which could do super awesome sound stuff, the SID sounds are intended to match the original PET CB2 primitive sounds as closely as possible.

Every change from the original PET code is noted with a PORT comment.

To build:

I included a shell script that should run on any *nix variant. It requires the 64Tass assembler and VICE to be installed, as it uses petcat and c1541 from the VICE distribution.

Dave McMurtrie <dave@commodore.international> 2026-05-31
