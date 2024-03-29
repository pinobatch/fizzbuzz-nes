#
# Linker script for fizzbuzz
# Copyright 2010-2014 Damian Yerrick
#
# Copying and distribution of this file, with or without
# modification, are permitted in any medium without royalty
# provided the copyright notice and this notice are preserved.
# This file is offered as-is, without any warranty.
#
MEMORY {
  ZP:     start = $10, size = $f0, type = rw;
  # use first $10 zeropage locations as locals
  HEADER: start = 0, size = $0010, type = ro, file = %O, fill=yes, fillval=$00;
  RAM:    start = $0300, size = $0500, type = rw;
  ROM7:    start = $C000, size = $4000, type = ro, file = %O, fill=yes, fillval=$FF;
}

SEGMENTS {
  ZEROPAGE: load=ZP, type=zp;
  BSS:      load=RAM, type=bss, define=yes, align=$100;
  INESHDR:  load=HEADER, type=ro, align=$10;
  CODE:     load=ROM7, type=ro, align=$100, define=yes;
  RODATA:   load=ROM7, type=ro, align=$100, define=yes;
  VECTORS:  load=ROM7, type=ro, start=$FFFA;
}

# I set "define = yes" on RODATA for automated ROM size meter

FILES {
  %O: format = bin;
}

