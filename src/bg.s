.include "nes.inc"
.include "fizzbuzz.inc"

PF_HT = 5

; Largest set of divisors among 1-100 belongs to 60:
; 1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30, 60
MAX_FACTORS = 12


.segment "ZEROPAGE"
bg_dirty: .res 1

BGUP_JOB_IDLE = $00
BGUP_BOTH_PFS = $02
BGUP_ONE_PF = $04
BGUP_CLS = $06
bgup_jobtype: .res 1

; for tall copies, bgup_progress+1 is y and bgup_copyarg is x
; for wide copies, bgup_progress+1 is y and bgup_copyarg >= $80
; for no copy, bgup_progress > 8
bgup_progress: .res 1
bgup_copyarg: .res 1

num_players: .res 1

; 0-127: digits
; 128: blank, 129: fizz, 130: buzz, 131: fizzbuzz
; each player's symbols at 0+p, 2+p, 4+p, 6+p, 8+p
num_history: .res 2 * PF_HT

; number of tenths to display the "wrong" message
wrongtime: .res 2

; Expected press (0: count, 1: fizz, 2: buzz, 3: fizzbuzz)
; for "wrong" message
expected_press: .res 2
actual_press: .res 2


time_minutes: .res 1
time_seconds: .res 1
time_tenths: .res 1
time_subtenths: .res 1

.segment "CODE"

; Playfield drawing ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;
; Fills one line.
; @param Y line * 2 + player number
.proc bg_gen_line
highdigits = $00
lowdigit = $01
ypos = $05
xpos = $06

  stx xpos
  sty ypos
  tya
  and #$01
  tax
  lda wrongtime,x
  beq not_in_penalty
  jmp draw_penalty

not_in_penalty:
  lda num_history,y
  bmi is_fizzbuzz

  ; it's 1, 2, or 3 digits
  jsr bcd8bit
  sta lowdigit
  lda xpos
  clc
  adc #7
  tax
  lda highdigits
  beq one_digit
  dex
  cmp #$10
  bcc two_digits
  dex
  lda #'1'
  jsr fizz_putchar
two_digits:
  lda highdigits
  ora #'0'
  jsr fizz_putchar
one_digit:
  lda lowdigit
  ora #'0'
  jsr fizz_putchar
  jmp draw_sidebars_if_2p

is_fizzbuzz:
  and #$7F
  tay
  cpy #3
  bne not_2p
  lda num_players
  cmp #2
  bcc not_2p
  iny
not_2p:
  lda xpos
  clc
  adc fizzbuzz_msg_x,y
  tax
  lda fizzbuzz_msg_hi,y
  sta 1
  lda fizzbuzz_msg_lo,y
  sta 0
  jsr fizz_puts_color0
draw_sidebars_if_2p:
  lda ypos
  cmp #2  ; top row (0, 1) use top endcap; others use mid
  lda #$82 >> 1
  rol a  ; glyph id: $82 for line 1, $83 for lines 2+

  ldx xpos
  ldy num_players
  cpy #2
  bne no_2p_sidebars
  inx
  pha
  jsr fizz_putchar
  lda xpos
  clc
  adc #14
  tax
pla_putchar:
  pla
  jmp fizz_putchar

penalty_finish:
  ldx xpos
no_2p_sidebars:

  ; if xpos is 8 (centered 1P), draw sidebars
  ; don't draw for 0 or 16 because those indicate use of tall copy
  cpx #8
  bne no_1p_sidebars
  ldx #6
  pha
  jsr fizz_putchar
  ldx #25
  bne pla_putchar
no_1p_sidebars:

  rts

draw_penalty:
cur_turn = $03
wrong_mask = $04  ; mask to use against expected and actual
wrong_side = $05  ; 0 for fizz, 2 for buzz

  ; Find which button was wrong
  stx cur_turn
  lda expected_press,x
  eor actual_press,x
  and #$02  ; 0 for fizz, 2 for buzz
  sta wrong_side
  bne :+
  lda #1
:
  sta wrong_mask

  ; Line dispatch
  cpy #4
  bcs not_line12
  cpy #2
  bcs is_line2

  ; line 1: "23 is a" or "23 not a"
  lda cur_num,x
  ldx xpos
  inx
  jsr print_one_number_at_x
  
  ; Decide whether to write "is a" or "not a"
  ldy cur_turn
  lda expected_press,y
  and wrong_mask
  tay
  beq :+
  ldy #2
:
  lda wrongness_isa,y
  sta 0
  lda wrongness_isa+1,y
  sta 1
  jsr fizz_puts0
  jmp penalty_finish
 
is_line2:
  ldy wrong_side
  lda fbtype,y
  asl a
  tay
  lda wrongness_types,y
  sta 0
  lda wrongness_types+1,y
  sta 1
  ldx xpos
  inx
  jsr fizz_puts0
  jmp penalty_finish
  
not_line12:

  ; Line 3:
  ; multiple, factor: "of " fizzvalue
  ; prime, square, fibo: to be decided
  sty $FF
  ldx wrong_side
  lda fbtype,x
  asl a
  adc fbtype,x
  asl a
  sta $07
  tya
  and #%00001110  ; remove player bit
  adc #<-4
  cmp #3*2
  bcs penalty_finish
  adc $07
  tay
  lda linehandlers+1,y
  pha
  lda linehandlers+0,y
  pha
  rts

.pushseg
.segment "RODATA"
linehandlers:
  .addr multiples_line3-1, multiples_line4-1, multiples_line5-1
  .addr factors_line3-1,   factors_line4-1,   factors_line5-1
  .addr primes_line3-1,    penalty_finish-1,  penalty_finish-1
  .addr squares_line3-1,   penalty_finish-1,  penalty_finish-1
  .addr fibo_line3-1,      fibo_line4-1,      penalty_finish-1
.popseg

; At entry to these, X is the fbtype/fbvalue index
; and cur_turn is the player number (0 or 1).

multiples_line3:
factors_line3:
  ldx xpos
  inx
  lda #'o'
  jsr fizz_putchar
  lda #'f'
  jsr fizz_putchar
  inx
  ldy wrong_side
  lda fbvalue,y
  jsr print_one_number_at_x
  lda #'.'
  jsr fizz_putchar
  jmp penalty_finish

multiples_line4:
  lda fbvalue,x
  pha
  ldy cur_turn
  lda cur_num,y
  ldx xpos
  inx
  jmp print_a_over_pull

factors_line4:
  ldy cur_turn
  lda cur_num,y
  pha
  lda fbvalue,x
print_a_over_pull:
  ldx xpos
  inx
  jsr print_one_number_at_x
  lda #'/'
  jsr fizz_putchar
  jmp pull_and_print

multiples_line5:
  lda fbvalue,x
  sta 2
  ldy cur_turn
  lda cur_num,y
  sta 1
  jmp mulfac_print_divmod
  
factors_line5:
  lda fbvalue,x
  sta 1
  ldy cur_turn
  lda cur_num,y
  sta 2
mulfac_print_divmod:
  jsr div1by2
print_equals0ra:
  pha
  ldx xpos
  inx
  inx
  inx
  lda #'='
  jsr fizz_putchar
  lda 0
  jsr print_one_number_at_x
  pla
  beq no_remainder
  pha
  lda #'r'
  jsr fizz_putchar
  pla
  jsr print_one_number_at_x
no_remainder:
  jmp penalty_finish

primes_line3:
  ; Print only for an incorrect prime (composite marked as prime),
  ; not a missed prime (prime marked as composite).
  ldy cur_turn
  lda expected_press,y
  and wrong_mask
  bne primes_nomsg
  
  ; Don't print anything for 1, which is neither prime nor composite.
  lda cur_num,y
  lsr a
  beq primes_nomsg

  ; At this point, A*2+C is composite (greater than 1 and not prime).
  ldx xpos
  inx
  bcs @oddcomposite
  pha
  lda #'2'
  jsr fizz_putchar
  jmp print_times_pull
@oddcomposite:
  asl a  ; A = num - 1
  tay
  lda prime_factorization+1,y
  pha
  lda prime_factorization,y
print_a_times_pull:
  jsr print_one_number_at_x
print_times_pull:
  lda #'x'
  jsr fizz_putchar
pull_and_print:
  pla
  jsr print_one_number_at_x
primes_nomsg:
  jmp penalty_finish

squares_line3:
  ; Compute floor(sqrt(cur_num)) as floor(next_squaregap/2)
  ; print that and the remainder:
  ; 6*6+11
  txa
  ora cur_turn
  tay
  lda fbprev,y
  pha
  lda fbstate,y
  lsr a
  pha
  ldx xpos
  inx
  jsr print_one_number_at_x
  lda #'x'
  jsr fizz_putchar
  pla
  jsr print_one_number_at_x
  pla
  ldy cur_turn
  sec
  eor #$FF
  adc cur_num,y
  beq squares_noremainder
  pha
  lda #'+'
  jsr fizz_putchar
  pla
  jsr print_one_number_at_x
squares_noremainder:
  jmp penalty_finish

fibo_line3:
  ldy cur_turn
  lda expected_press,y
  and wrong_mask
  cmp #1  ; C = true iff missed
  txa
  ora cur_turn
  tay
  bcs fibo_line3_missed
  lda fbprev,y
  pha
  lda fbstate,y
print_apluspull:
  ldx xpos
  inx
  jsr print_one_number_at_x
  lda #'+'
  jsr fizz_putchar
  pla
  jsr print_one_number_at_x
  jmp penalty_finish

fibo_line3_missed:
  lda fbstate,y
  pha
  eor #$FF
  sec
  adc fbprev,y
  jmp print_apluspull

fibo_line4:
  ldy cur_turn
  lda expected_press,y
  and wrong_mask
  cmp #1  ; C = true iff missed
  txa
  ora cur_turn
  tay
  lda fbprev,y
  bcs fibo_line4_missed
  adc fbstate,y
fibo_line4_missed:
  sta 0
  lda #0
  jmp print_equals0ra

.endproc

.proc print_one_number_at_x
highdigits = $00
  jsr bcd8bit
  pha
  lda highdigits
  beq one_digit
  cmp #16
  bcc two_digits
  lsr a
  lsr a
  lsr a
  lsr a
  ora #'0'
  jsr fizz_putchar
  lda highdigits
  and #$0F
two_digits:
  ora #'0'
  jsr fizz_putchar
one_digit:
  pla
  ora #'0'
  jmp fizz_putchar
.endproc

TOPBAR_CLOCK_X = 12

.proc bg_gen_topbar
highdigits = $00  ; bcd8bit result

  ldx #7
loop:
  lda topbar_attrdata,x
  sta fizz_attrbuf,x
  dex
  bpl loop

  ; Draw the time in gray
  lda time_minutes
  ora #'0'
  ldx #TOPBAR_CLOCK_X
  jsr fizz_putchar
  lda time_tenths
  cmp #5
  bcs no_colon
  lda #':'
  jsr fizz_putchar
no_colon:
  lda time_seconds
  jsr bcd8bit
  pha
  lda highdigits
  ora #'0'
  ldx #TOPBAR_CLOCK_X + 3
  jsr fizz_putchar
  pla
  ora #'0'
  jsr fizz_putchar

  ; TO DO: Draw game rule for fizz and buzz
  ldy fizztype
  lda fizzvalue
  ldx #0
  jsr draw_one_gametype
  ldy buzztype
  lda buzzvalue
  ldx #20

draw_one_gametype:
gametype = $03
gamevalue = $04
  sta gamevalue
  sty gametype
  txa
  clc
  adc gametype_names_x,y
  and #$1F
  tax
  lda gametype_names_x,y
  bpl no_gamevalue_prefix
  
  ; multiples and factors are prefixed with the game value
  lda gamevalue
  jsr bcd8bit
  dex
  pha
  lda highdigits
  beq no_gamevalue_tens
  dex
  ora #'0'
  jsr fizz_putchar
no_gamevalue_tens:
  pla
  ora #'0'
  jsr fizz_putchar

no_gamevalue_prefix:
  ldy gametype
  lda gametype_names_lo,y
  sta 0
  lda gametype_names_hi,y
  sta 1
  jmp fizz_puts0
.endproc

; Dirty state machine ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.proc bgprep
  ldx bgup_jobtype
  lda bgprep_procs+1,x
  pha
  lda bgprep_procs,x
  pha
  rts
.pushseg
.segment "RODATA"
bgprep_procs:
  .addr find_whats_dirty-1, update_both_playfields-1, update_one_playfield-1
  .addr clear_next_line-1
.popseg
.endproc

.proc bgprep_init
  lda #DIRTY_TOPBAR|DIRTY_1P|DIRTY_2P
  sta bg_dirty
  lda #BGUP_JOB_IDLE
  sta bgup_jobtype
  rts
.endproc

.proc find_whats_dirty
  lda bg_dirty
  bpl not_cls
  asl bg_dirty
  lsr bg_dirty
  ldy #$FF
  sty bgup_copyarg
  iny
  sty bgup_progress
  lda #BGUP_CLS
  sta bgup_jobtype
  jmp fizz_clrline

not_cls:
  and #DIRTY_TOPBAR
  beq not_topbar
  
  ; Refresh the top bar
  eor bg_dirty
  sta bg_dirty
  ldy #$FF
  sty bgup_copyarg
  iny
  sty bgup_progress
  jsr fizz_clrline
  jmp bg_gen_topbar
not_topbar:
  lda bg_dirty
  and #DIRTY_1P|DIRTY_2P
  beq not_playfields
  cmp #DIRTY_1P|DIRTY_2P
  bne one_playfield
  
  ; Set up wide copy for both playfields
  eor bg_dirty
  sta bg_dirty
  ldy #$FF
  sty bgup_copyarg  
  iny
  sty bgup_progress
  lda #BGUP_BOTH_PFS
  sta bgup_jobtype
  jmp update_both_playfields
  
one_playfield:

  and #DIRTY_2P
  beq :+
  lda #16  ; 0: left, 1: right
:
  ldy num_players
  dey
  bne :+
  lda #8
:
  ; at this point, A=8 for one player, 0 for left, 16 for right
  ; Set up a fast and tall copy
  sta bgup_copyarg
  lda #<~(DIRTY_1P|DIRTY_2P)
  and bg_dirty
  sta bg_dirty
  lda #0
  sta bgup_progress
  lda #BGUP_ONE_PF
  sta bgup_jobtype
  jmp update_one_playfield

not_playfields:
  lda #$FF
  sta bgup_progress  ; disable copying
  rts
.endproc

.proc update_both_playfields
  jsr fizz_clrline
  lda num_players
  cmp #2
  bcs is_2p
  ldx #8
  jmp do_1p_at_x

is_2p:
  ldx #16
  lda bgup_progress
  asl a
  tay
  iny
  jsr bg_gen_line
  ldx #0

do_1p_at_x:
  lda bgup_progress
  asl a
  tay
  jsr bg_gen_line
incline:
  inc bgup_progress
  lda bgup_progress
  cmp #PF_HT
  bcc not_reached_bottom
set_idle:
  lda #BGUP_JOB_IDLE
  sta bgup_jobtype
not_reached_bottom:
  rts
.endproc

.proc clear_next_line
  jsr fizz_clrline
  jmp update_both_playfields::incline
.endproc

.proc update_one_playfield
  lda bgup_progress
  beq noinc  ; ensure the top line is written
  cmp #PF_HT - 2
  beq noinc
  bcs update_both_playfields::set_idle  ; don't write off the bottom
  inc bgup_progress  ; otherwise step by 2
noinc:

  jsr fizz_clrline
  ldx bgup_copyarg
  cpx #16  ; X=0 or 8: player 1; X=16: player 2
  ldx #0
  lda bgup_progress
  rol a
  tay
  pha
  jsr bg_gen_line
  pla
  cmp #PF_HT * 2 - 2
  bcs no_second_line
  adc #2
  tay
  ldx #16
  jsr bg_gen_line
no_second_line:
  jmp update_both_playfields::incline
.endproc


.proc bgup
  ldy bgup_progress
  bmi nocopy
  iny  ; skip intentional blank row at top
  ldx bgup_copyarg
  bmi widecopy
  jmp fizz_copyline_tall
widecopy:
  jmp fizz_copyline_wide
nocopy:
  rts
.endproc

; Game state updating ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.proc clear_stopwatch
  lda #0
  sta time_minutes
  sta time_seconds
  sta time_tenths
  sta time_subtenths
  sta wrongtime+0
  sta wrongtime+1
  rts
.endproc

.proc inc_stopwatch
  inc time_subtenths
  lda #0
  cmp tvSystem  ; C=1: NTSC, C=0: PAL
  adc #4  ; PAL counts 0-4; NTSC counts 0-5
  cmp time_subtenths
  bcs not_carry
  lda #0
  sta time_subtenths
  inc time_tenths
  lda time_tenths
  cmp #5
  beq set_topbar_dirty  ; at 5 tenths, blink colons
  cmp #10
  bcc not_carry
  lda #0
  sta time_tenths
  inc time_seconds
  lda time_seconds
  cmp #60
  bcc set_topbar_dirty
  lda #0
  sta time_seconds
  inc time_minutes
set_topbar_dirty:
  lda #DIRTY_TOPBAR
  ora bg_dirty
  sta bg_dirty
not_carry:
  rts
.endproc

;;
; Clears the history for both players (to the blank message, $80)
; and resets the next number to 1.
.proc reset_player_numbers
  lda #$80
  ldy #PF_HT * 2 - 1
clrhistloop:
  sta num_history,y
  dey
  bpl clrhistloop

  asl a  ; A = 0
  ldy #9  ; 2 players * 5 bytes of state per player
clrprevloop:
  sta cur_num,y
  dey
  bpl clrprevloop
  rts
.endproc

;;
; Inserts A at the end of player X's history queue.
; A can be a number or a fizzbuzz symbol
.proc add_player_number
  pha
  txa
  tay
loop:
  lda num_history+2,y
  sta num_history+0,y
  iny
  iny
  cpy #PF_HT * 2 - 2
  bcc loop
  pla
  sta num_history+0,y
  rts
.endproc
  

.segment "RODATA"
fizzbuzz_msg_lo:
  .byte <blank_msg, <fizz_msg, <buzz_msg, <fizzbuzz_msg, <fizzbuzz_2p_msg
fizzbuzz_msg_hi:
  .byte >blank_msg, >fizz_msg, >buzz_msg, >fizzbuzz_msg, >fizzbuzz_2p_msg
fizzbuzz_msg_x:
  .byte 0, 5, 4, 1, 2
topbar_attrdata:
  ; 0-11: fizz rule; 12-19: clock; 20-31: buzz rule
  .byte $55,$55,$55,$00,$00,$AA,$AA,$AA

fizz_msg: .byte 2,"fizz"
blank_msg: .byte 0
fizzbuzz_msg: .byte 2,"fizz"
buzz_msg: .byte 3,"buzz",0
; 2-player "fizzbuzz" needs to be condensed
fizzbuzz_2p_msg: .byte 2,"fi",$81,3,$80,$81,0

gametype_names_lo:
  .byte <multiples_msg, <factors_msg, <primes_msg, <squares_msg, <fibo_msg
gametype_names_hi:
  .byte >multiples_msg, >factors_msg, >primes_msg, >squares_msg, >fibo_msg
gametype_names_x:
  .byte $85, $84, $01, $04, $02

multiples_msg: .byte "n",0
factors_msg: .byte "/n",0
primes_msg: .byte "prime",0
squares_msg: .byte "n",$84,0
fibo_msg: .byte "fibo",0

wrongness_isa:
  .addr nota_msg, isa_msg
isa_msg: .byte " is a",0
nota_msg: .byte " not a",0
wrongness_types:
  .addr wrongness_mul_msg, wrongness_fac_msg, wrongness_prime_msg
  .addr wrongness_square_msg, wrongness_fibo_msg
wrongness_mul_msg: .byte "multiple",0
wrongness_fac_msg: .byte "factor",0
wrongness_prime_msg: .byte "prime.",0
wrongness_square_msg: .byte "square.",0
wrongness_fibo_msg: .byte "fibo.",0
  

player_dirty_bit: .byte DIRTY_1P, DIRTY_2P

