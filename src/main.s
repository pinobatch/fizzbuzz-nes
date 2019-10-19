.include "nes.inc"
.include "fizzbuzz.inc"

OAM = $200
.segment "ZEROPAGE"
nmis: .res 1
oam_used: .res 1
tvSystem: .res 1
round_num: .res 1
; length 16 and overlap keys with music vars when no music is used
; length 36 and no overlaps when music is used
psg_sfx_state: .res 16
cur_keys = psg_sfx_state + 2
new_keys = psg_sfx_state + 6
das_keys = psg_sfx_state + 10
das_timer = psg_sfx_state + 14

; Counting buttons (Down, B, A) that have been pressed together
accum_keys: .res 2
; Nonzero: Ignore counting buttons until none are pressed
need_repress: .res 2

.segment "INESHDR"
  .byte "NES",$1A
  .byte 1  ; PRG ROM in 16 KiB units
  .byte 0  ; 
  .byte $01  ; mapper $x0, AABB mirroring, no battery
  .byte $00  ; mapper $0x

.segment "VECTORS"
  .addr nmi, reset, irq

.segment "CODE"
.proc irq
  rti
.endproc

.proc nmi
  inc nmis
  rti
.endproc

.proc reset
  sei
  cld
  ldx #$00
  stx PPUCTRL
  stx PPUMASK
  dex
  txs
  ; wait #1 for ppu to warm up
:
  bit PPUSTATUS
  bpl :-
  jsr init_sound

  ; wait #2 for ppu to warm up
:
  bit PPUSTATUS
  bpl :-
  
  lda #VBLANK_NMI
  sta PPUCTRL
  jsr getTVSystem
  sta tvSystem

  sta PPUADDR
  sta PPUADDR
  lday #fizzter_zet
  ldx #<(fizzter_chr_size/16)
  jsr zet_decode

  ; copy sprite patterns
  lday #$1000
  sta PPUADDR
  sty PPUADDR
:
  lda objtiles_chr,y
  sta PPUDATA
  iny
  cpy #16
  bcc :-

:
  jsr title_screen
  cmp #2
  bne notHelp
  lda #$00      ; help pages
  jsr show_help
  jmp :-
notHelp:
  adc #1
  sta num_players
  lda #0
  sta round_num
play_round:
  lda round_num
  asl a
  asl a
  tay
  ldx #0

  ; Set seqtypes for test run
initroundloop:
  lda round_defs+0,y
  sta fbtype,x
  iny
  inx
  cpx #4
  bcc initroundloop

  jsr bgprep_init
  jsr reset_player_numbers
  jsr clear_stopwatch
  lda #$80      ; display interstitial
  jsr show_help

  lda #0
  sta accum_keys+0
  sta accum_keys+1

gameloop:
  jsr read_pads
  jsr inc_stopwatch

  ldx #1
playerloop:
  lda cur_num,x
  cmp #100
  bcs no_inc1
  
  lda wrongtime,x
  beq not_in_wrongtime
  lda time_subtenths
  bne no_inc1
  dec wrongtime,x
  bne no_inc1
  lda player_dirty_bit,x
  ora bg_dirty
  sta bg_dirty
  lda #0  ; Clear accumulated keys; otherwise, an incorrect fizzbuzz
  sta accum_keys,x  ; guess will be incorrect twice.
not_in_wrongtime:

  jsr get_counting_keys
  bcc no_inc1
  sta actual_press,x
  
  ; Decided to count

  jsr inc_cur_num
expected_call = 7
pressed_call = 6
cur_turn = 5
  sta expected_press,x
  cmp actual_press,x
  beq is_correct

  ; Wrong: Put player in time out for 5 seconds or so
  lda #WRONG_TIME
  sta wrongtime,x
  lda player_dirty_bit,x
  ora bg_dirty
  sta bg_dirty
  lda #SFX_WRONG

is_correct:
  stx cur_turn
  jsr start_sound
  ldx cur_turn

  lda expected_press,x
  bne is_dig1
  lda cur_num,x
  jmp have_player_number1
is_dig1:
  ora #$80
have_player_number1:
  jsr add_player_number
  lda player_dirty_bit,x
  ora bg_dirty
  sta bg_dirty
no_inc1:
  dex
  bpl playerloop

  jsr bgprep
  lda nmis
:
  cmp nmis
  beq :-
  jsr bgup
  ldx #0
  ldy #8
  lda #VBLANK_NMI|BG_0000|OBJ_1000
  clc
  jsr ppu_screen_on
  jsr update_sound
  jmp gameloop
.endproc

;;
; Check
; @return C=0: no count action; C=1: keys in A
; (0=count, 1=fizz, 2=buzz, 3=fizzbuzz)
.proc get_counting_keys
  ; Check based on gamepad
  lda new_keys,x
  and #KEY_B|KEY_A
  ora accum_keys,x
  sta accum_keys,x

  ; If key is down
  lda new_keys,x
  and #KEY_DOWN
  beq not_down
  lda #0
  sec
  rts
not_down:

  ; Release B or A to fizz or buzz.
  lda cur_keys,x
  and #KEY_B|KEY_A
  bne no_release_count
  lda accum_keys,x
  beq no_count
  pha
  lda #0
  sta accum_keys,x
  pla
  asl a
  rol a
  rol a
  and #$03
  sec
  rts

no_release_count:
  ; Press A+B to fizzbuzz and clear accumulated presses.
  cmp #KEY_B|KEY_A
  bne no_count
  and new_keys,x
  beq no_count
  lda #0
  sta accum_keys,x
  lda #3
  rts

no_count:
  clc
  rts
.endproc

.segment "RODATA"
objtiles_chr: .incbin "obj/nes/objtiles.chr"

round_defs:
  .byte SEQTYPE_MULTIPLES, 3, SEQTYPE_MULTIPLES, 5
