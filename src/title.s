.include "nes.inc"
.include "fizzbuzz.inc"

; must match conversion command in makefile
LOGO_FIRST_TILE = 200

.proc title_screen
dstlo = $00
dsthi = $01

  lda #VBLANK_NMI
  sta PPUCTRL
  asl a
  sta PPUMASK
  lday #(LOGO_FIRST_TILE * 16)
  sta PPUADDR
  sty PPUADDR
  lday #title_zet
  ldx #<(title_chr_size / 16)
  jsr zet_decode
  ldx #$20
  jsr ppu_zero_nt
  ldx #$24
  jsr ppu_zero_nt
  lday #$2088
  stay dstlo
  ldx #0
rowloop:
  lda dsthi
  sta PPUADDR
  lda dstlo
  sta PPUADDR
  clc
  adc #32
  sta dstlo
  inccs dsthi
  lda dsthi
  ldy #title_w
tileloop:
  lda title_nam,x
  sta PPUDATA
  inx
  dey
  bne tileloop
  cpx #title_w*title_h
  bcc rowloop
  
  ; draw attributes
  ldy #2
attrloop:
  lda #$23
  sta PPUADDR
  lda title_attrstart,y
  sta PPUADDR
  lda title_attrl,y
  sta PPUDATA
  lda title_attrr,y
  sta PPUDATA
  sta PPUDATA
  sta PPUDATA
  dey
  bpl attrloop
  
  ; now draw text
  lday #title_options
  stay $00
  ldy #4
  sty pageprogress
txtloop:
  jsr fizz_clrline
  ldx #6
  jsr fizz_puts_color0
  stay 0
  ldy pageprogress
  inc pageprogress
  jsr fizz_copyline_wide
  ldy #0
  lda (0),y
  bne txtloop

  lda #$17  ; each 8 frames is 8 pixels and 1 gray level
  sta pageprogress
  ldx #0
  stx pagenum
  jsr ppu_clear_oam

loop:
  ; fade in
  dec pageprogress
  bpl :+
  inc pageprogress

  ; move the dot
  ldy pagenum
  lda title_objy,y
  sta OAM+0
  lda #0
  sta OAM+1
  sta OAM+2
  lda #36
  sta OAM+3
:

  lda nmis
:
  cmp nmis
  beq :-
  lda #>OAM
  sta OAM_DMA
  lda pageprogress
  asl a
  and #$30
  jsr copy_faded_pal
  lda #$3F
  sta PPUADDR
  lda #$11
  sta PPUADDR
  lda #$00
  sta PPUDATA
  lda #$10
  sta PPUDATA
  
  ; turn the screen back on
  lda pageprogress
  clc
  adc #8
  tay
  ldx #0
  lda #VBLANK_NMI|BG_0000|OBJ_1000
  sec
  jsr ppu_screen_on
  jsr read_pads
  jsr update_sound

  ; process input once fully scrolled on
  lda pageprogress
  bne notDown
  lda new_keys
  and #KEY_A|KEY_START
  bne done
  lda new_keys
  and #KEY_UP
  beq notUp
  dec pagenum
  bpl upFinish
  lda #2
  sta pagenum
upFinish:
  lda #SFX_COUNT
  jsr start_sound
notUp:

  lda new_keys
  and #KEY_DOWN|KEY_SELECT
  beq notDown
  ldy pagenum
  iny
  cpy #3
  bcc downHaveY
  ldy #0
downHaveY:
  sty pagenum
  lda #SFX_COUNT
  jsr start_sound
notDown:

  jmp loop

done:
  lda pagenum
  rts
.endproc


.segment "RODATA"
title_options:
  .byte "1p solo",10
  .byte "2p race",10
  .byte "how to play",0

title_attrstart: .byte $CA, $D2, $DA
title_attrl:     .byte $55, $A6, $AA
title_attrr:     .byte $55, $A5, $AA
title_objy:
  .repeat 3, I
    .byte 128+32*I
  .endrepeat
