.include "nes.inc"
.include "fizzbuzz.inc"

;;
; Decodes zero-elimination encoded tiles to video memory.
; @param A:Y address
; @param X length in 16-bit units
.proc zet_decode
srclo = 0
srchi = 1
planesleftlo = 2
planeslefthi = 3
skipbits = 4
  sta srchi
  lda #0
  sta srclo  ; Y indexes through each 256 byte page

  txa
  eor #$FF
  clc
  adc #1  ; A = 256 - length in tiles
  asl a
  sta planesleftlo
  lda #$FE
  adc #0
  sta planeslefthi

planeloop:
  lda (srclo),y
  iny
  inceq srchi
  sec
  rol a
  sta skipbits
byteloop:
  lda #0
  bcs iszerobyte
  lda (srclo),y
  iny
  inceq srchi
iszerobyte:
  sta PPUDATA
  asl skipbits
  bne byteloop  ; once it fills up with zeroes this plane is done
  inc planesleftlo
  bne planeloop
  inc planeslefthi
  bne planeloop
  rts
.endproc

fizz_linebuf = $0100
fizz_attrbuf = $0180
.proc fizz_clrline
  lda #$00
  ldx #$43
loop:
  sta fizz_linebuf,x
  sta fizz_linebuf+$44,x
  dex
  bpl loop
  rts
.endproc

;;
; Copies the line buffer to 32x4 pixels at (0, y), with y in 0-6.
; Does not modify memory
.proc fizz_copyline_wide
  
  ; lines at $2000, $2080, $2100, $2180, $2200, $2280, $2300
  tya
  lsr a
  ora #$20
  sta PPUADDR
  ldx #$00
  txa
  ror a
  sta PPUADDR
loop:
  .repeat 8, I
    lda fizz_linebuf+I,x
    sta PPUDATA
  .endrepeat
  txa
  axs #<-8
  bpl loop

  ; now do the attributes
  tya  ; bit 4-3: nametable id
  lsr a 
  ora #$23
  sta PPUADDR
  lda row_attrstart,y
  sta PPUADDR
attrloop:
  lda fizz_linebuf,x
  sta PPUDATA
  inx
  cpx #$88
  bcc attrloop
  rts
.endproc

;;
; Copies the line buffer to two 16x4 rows: columns 0-15 on top and
; columns 16-31 on bottom.
; Overwrites $03-$04
; @param X starting X coordinate (0, 4, 8, 12, or 16)
; @param Y starting Y coordinate (1-5)
.proc fizz_copyline_tall
dstlo = $03
dsthi = $04
  tya
  lsr a
  ora #$20
  sta dsthi
  txa
  bcc :+
  ora #$80
:
  sta dstlo
  ldx #0
  jsr halfline
  ldx #16
  iny
halfline:
  lda dsthi
  sta PPUADDR
  lda dstlo
  sta PPUADDR
  clc
  adc #32
  sta dstlo
  bcc :+
  inc dsthi
:
  .repeat 16, I
    lda fizz_linebuf+I,x
    sta PPUDATA
  .endrepeat
  txa
  axs #<-32
  bpl halfline

  ; Calculate attribute address
  lda dsthi
  ora #$03
  sta PPUADDR
  lda dstlo
  and #$1C
  lsr a
  lsr a
  ora row_attrstart,y
  sta PPUADDR

  ; Attribute source address
  txa
  and #$10
  lsr a
  lsr a
  tax
  .repeat 4,I
    lda fizz_attrbuf+I,x
    sta PPUDATA
  .endrepeat
  rts
.endproc

;;
; Writes a glyph to the line buffer.
; @return A ASCII value
; @return X horizontal position (0-30)
; @return X new horizontal position
; Trash: $07
.proc fizz_putchar
srcxend = $07
  sec
  sbc #$20
  cmp #fizzter_numglyphs
  bcs noglyph
  tay
  lda fizzter_startoffsets+1,y
  sta srcxend
  lda fizzter_startoffsets,y
  tay  ; Glyph is (srcxend - y) tiles wide
  cpy srcxend
  bcs noglyph
glyphloop:
  .repeat 4, I
    lda fizzter_tilerow0+fizzter_tilerowlen*I,y
    sta fizz_linebuf+$20*I,x
  .endrepeat
  inx
  iny
  cpy srcxend
  bcc glyphloop
noglyph:
  rts
.endproc

;;
; Puts a string to the line buffer.
; In:   AAYY = string base address, stored to $00-$01
;       X = destination X position
; Out:  X = ending X position
;       $00-$01 = END of string (points at null or newline)
;       AAYY = If stopped at $00: End of string
;              If stopped at $01-$1F: Next character
; Trash: $07
.proc fizz_puts
str = $00
  stay str
.endproc
.proc fizz_puts0
str = fizz_puts::str
loop:
  ldy #0
  lda (str),y
  beq done0
  cmp #32
  bcc doneNewline
  jsr fizz_putchar
  inc str
  inceq str+1
  cpx #32
  bcc loop

doneNewline:
  lda #1
done0:
  clc
  adc str
  tay
  lda #0
  adc str+1
  rts
.endproc


;;
; Similar to fizz_puts, but handling ctrl characters $01-$03 for
; color set changes
; @return $02 last used attribute ($00, $55, $AA, $FF)
; Trash: $03, $04, $07
.proc fizz_puts_color
str = $00
curattr = $02
  stay str
  lda #$00
  sta curattr
.endproc
.proc fizz_puts_color0
str = fizz_puts_color::str
curattr = fizz_puts_color::curattr
nextx = $07
prevx = $03
colsleft = $04

loop:
  ldy #0
  lda (str),y
  beq done0
  cmp #32
  bcs isActualChar
  cmp #5
  bcs doneNewline
  tay
  lda attrbytes-1,y
  sta curattr
  bcc nextchar
isActualChar:
  stx prevx
  lsr prevx
  jsr fizz_putchar
  stx nextx
  
  ; Find how many attrib columns to write
  ; From 
  ; From x=7 to x=9 should write in columns 3 and 4
  txa
  lsr a  ; leaves bit 0 in carry so that next ADC/SBC will round half up
  sbc prevx  ; A = number of columns to write minus 1, C = set
  bcc attrdone
  adc #0
  sta colsleft
attrloop:
  lda prevx
  and #1
  tay
  lda prevx
  lsr a
  tax
  lda fizz_attrbuf,x
  eor curattr
  and attrcolmasks,y
  eor curattr
  sta fizz_attrbuf,x
  inc prevx
  dec colsleft
  bne attrloop
attrdone:
  ldx nextx
nextchar:
  inc str
  inceq str+1
  cpx #32
  bcc loop

doneNewline:
  lda #1
done0:
  clc
  adc str
  tay
  lda #0
  adc str+1
  rts
.pushseg
.segment "RODATA"
attrcolmasks: .byte %11001100, %00110011
attrbytes: .byte %00000000, %01010101, %10101010, %11111111
.popseg
.endproc

.segment "RODATA"
row_attrstart:
  .repeat 2
    .repeat 8, I
      .byte $C0 + I * 8
    .endrepeat
  .endrepeat

