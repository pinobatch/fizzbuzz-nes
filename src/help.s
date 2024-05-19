.include "nes.inc"
.include "fizzbuzz.inc"
.include "mbyt.inc"

.segment "ZEROPAGE"
PAGENUM_MODEINST = $80
PAGENUM_QUITHELP = $FF

pageprogress: .res 1
pagenum: .res 1  ; $FF: quitting
pagemovedir: .res 1  ; 0: going to next; 1: going to previous
pagesrcaddr: .res 2
pagesrccolor: .res 1

; HELP SCREEN ENGINE ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "CODE"
.proc show_help
ydst = $08
paldst = $09
xscroll_lo = $0A
xscroll_hi = $0B

  sta pagenum
  lda #SFX_FIZZBUZZ
  jsr pently_start_sound
  ldx #$FF
  stx bgup_progress  ; make sure bgprep has nothing to do
  inx
  stx pageprogress
  stx pagemovedir

helploop:
  lda #$FF
  sta ydst
  sta paldst

  ; progress frames
  ; 0: Start new page and load line 1
  ; 1-2: Lines 2-3
  ; 3: Load faded palette
  ; 4-6: Load lines 4-6
  ; 12: Load original palette
  ; Draw even pages (0, ...) to second nametable and odd to first!
  ldy pageprogress
  bne notprogress0
  sty pagesrccolor
  lda pagenum
  bpl load_helppage_addr
  ; Negative: Run dirty 
load_helppage_addr:
  cmp #NUM_HELP_PAGES
  bcc :+
  lda #NUM_HELP_PAGES
:
  asl a
  tay
  lda help_pages,y
  sta pagesrcaddr
  lda help_pages+1,y
  sta pagesrcaddr+1
  ldy #0
notprogress0:
  cpy #7
  bcs no_loadline
  cpy #3
  beq no_loadline
  bcs :+
  iny
:
  lda pagenum
  cmp #PAGENUM_QUITHELP
  beq loadline_done
  ; render even (and dynamic) pages to the odd nametable
  ora #0
  bpl :+
  lda #0  ; force dynamic pages onto the odd table too
:
  lsr a
  tya
  bcs :+
  ora #8
:
  sta ydst

  jsr fizz_clrline
  lda pagenum
  bpl is_normal_helppage
  jsr pagehandler_dispatch
  jmp loadline_done
pagehandler_dispatch:
  asl a
  tax
  lda help_pagehandlers+1,x
  pha
  lda help_pagehandlers+0,x
  pha
  rts
  ; pagehandlers are called with the actual Y (1-6) in Y.
  
is_normal_helppage:
  ldx #2
  lday pagesrcaddr
  stay 0
  lda pagesrccolor
  sta 2
  jsr fizz_puts_color0
  stay pagesrcaddr
  lda 2
  sta pagesrccolor
  jmp loadline_done

no_loadline:
  cpy #16
  bcs noprogressinc
  cpy #3
  bne :+
  lda #$10
  bne have_paldst
:
  cpy #12
  bne loadline_done
  lda #$00
have_paldst:
  sta paldst

loadline_done:
  inc pageprogress
noprogressinc:

  ; If quitting from an interstitial, draw dirty area starting at
  ; frame 5 of the fade+scroll
  lda pageprogress
  cmp #5       ; If pageprogress < 5, things 8px from the side
  bcc nodirty  ; would wrap into visibility
  lda pagenum
  cmp #PAGENUM_QUITHELP
  bne nodirty  ; Not leaving an interstitial
  lda paldst
  and ydst
  bpl nodirty  ; A line or palette is ready to be copied
  jsr bgprep
  
  ; If dirty area isn't ready, hold pageprogress at no more than 8
  ; so that it isn't scrolled in before it's ready
  lda bgup_progress
  bmi nodirty
  lda pageprogress
  cmp #9
  bcc nodirty
  dec pageprogress
nodirty:

  ; Translate progress to a scroll position
  lda pageprogress
  cmp #9
  bcc :+
  adc #111 ; 0-16 -> 0-8,121-128
:
  asl a
  sta xscroll_lo
  lda #0
  rol a
  bit pagemovedir
  bpl scroll_notleft
  sta xscroll_hi
  lda #1  ; 1 to compensate for carry clear from rol
  sbc xscroll_lo
  sta xscroll_lo
  lda #2
  sbc xscroll_hi
scroll_notleft:
  sta xscroll_hi
  
  ; Determine the nametable to which we're scrolling
  lda pagenum
  eor #$80
  cmp #$7E
  bcs scroll_notinterstitial
  asl a
scroll_notinterstitial:
  eor xscroll_hi
  and #$01
  ora #VBLANK_NMI
  sta xscroll_hi
  
  lda nmis
:
  cmp nmis
  beq :-
  ldy ydst
  bmi no_copyline
  jsr fizz_copyline_wide
  sec
  ror ydst
  jmp help_vram_done
no_copyline:
  lda paldst
  bmi no_copypal
  jsr copy_faded_pal
  jmp help_vram_done
no_copypal:
  jsr bgup
help_vram_done:
  ldx xscroll_lo
  lda xscroll_hi
  ldy #8

  clc
  jsr ppu_screen_on
  jsr read_pads
  jsr pently_update

  ; Don't allow changing pages while moving
  lda pageprogress
  cmp #16
  bcc notLeft

  lda new_keys
  and #KEY_START
  bne setQuit

  lda new_keys
  and #KEY_A|KEY_RIGHT
  beq notRight
  lda pagenum  ; Only A should work on last or interstitial pages
  cmp #NUM_HELP_PAGES-1
  bcs lastRight
  inc pagenum
  lda #0
  sta pageprogress
  sta pagemovedir
  lda #SFX_COUNT
  jsr pently_start_sound
  jmp notRight
lastRight:
  lda new_keys
  bpl notRight
setQuit:
  lda pagenum
  bmi :+
  ; If leaving help, switch to the blank page with the opposite
  ; polarity ($7E or $7F)
  and #1
  eor #$7F
  bne setQuit_have_pagenum
:
  lda #PAGENUM_QUITHELP
setQuit_have_pagenum:
  sta pagenum
  ldy #0
  sty pageprogress
  sty pagemovedir
  lda #SFX_FIZZBUZZ
  jsr pently_start_sound
notRight:

  lda pagenum  ; Left doesn't work on interstitial pages
  bmi notLeft
  lda new_keys
  and #KEY_LEFT
  beq notLeft
  lda pagenum
  beq notLeft
  dec pagenum
  ldy #0
  sty pageprogress
  dey
  sty pagemovedir
  lda #SFX_COUNT
  jsr pently_start_sound
notLeft:

  ; If the scrolling animation has finished, and the page number
  ; is one of the quitting pages (7E, 7F, FF), stop
  lda pageprogress
  cmp #16
  bcc notQuit
  lda pagenum
  and #$7F
  cmp #$7E
  bcs helpdone1
notQuit:
  jmp helploop

helpdone1:
  rts
.endproc

; HELP PAGE DATA ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "RODATA"
help_pages:
  .addr version_page
  .addr help_page1, help_page2, help_page3, help_page4, help_page5
  .addr help_page6, help_page7, help_page8, help_page9, help_page10
  .addr help_page11
NUM_HELP_PAGES = (* - help_pages) / 2
  .addr known_zero

BUILDDAY = (.TIME / 86400) - 16405
version_page:
  .byte "nes ",2,"fizz",3,"buzz ",1,10
  .byte .sprintf("w.i.p. day %d", BUILDDAY),10
  .byte "copr. 2014",10
  .byte "damian yerrick",10,10
  .byte "press right",0
help_page1:
  .byte "this is a game",10
  .byte "of counting to",10
  .byte "a hundred, but",10
  .byte "with a twist."
known_zero:
  .byte 0
help_page2:
  .byte "for multiples",10
  .byte "of 3, like 3, 6,",10
  .byte "or 21, you ",2,"fizz",1,10
  .byte "instead of",10
  .byte "counting.",10
  .byte "1, 2, ",2,"fizz...",0
help_page3:
  .byte "for multiples",10
  .byte "of 5, like 5, 10,",10
  .byte "or 20, ",3,"buzz.",1,10
  .byte "4, ",3,"buzz, ",2,"fizz, ",1,"7...",0
help_page4:
  .byte "some numbers",10
  .byte "are multiples",10
  .byte "of both 3 and 5,",10
  .byte "like 15 or 30.",10
  .byte "for these,",10
  .byte "you ",2,"fizz",3,"buzz.",1,0
help_page5:
  .byte "down: count",10
  .byte "B: ",2,"fizz   ",1,"A: ",3,"buzz",1,10
  .byte 10
  .byte "get one wrong",10
  .byte "and you'll have",10
  .byte "to wait a while.",0
help_page6:
  .byte "watch out!",10
  .byte "later rounds",10
  .byte "change when to",10
  .byte 2,"fizz ",1,"and ",3,"buzz.",1,10
  .byte "for example:",0
help_page7:
  .byte 2,"fizz 7n ",1,10
  .byte "multiples of 7",10
  .byte "these are",10
  .byte "7, 14, 21, 28, ...",0
help_page8:
  .byte 3,"buzz 60/n",1,10
  .byte "factors of 60",10
  .byte "these are",10
  .byte "1-6, 10, 12, 15,",10
  .byte "20, 30, and 60.",0
help_page9:
  .byte 2,"fizz prime",1,10
roundinstr_tn1pri:
  .byte "only 2 divisors",10
  .byte "these are",10
  .byte "2, 3, 5, 7, 11, 13,",10
  .byte "17, 19, 23, 29, ...",0
help_page10:
  .byte 3,"buzz n",$84,1,10
roundinstr_tn1sq:
  .byte "perfect square",10
  .byte "these are",10
  .byte "1, 4, 9, 16, 25,",10
  .byte "36, 49, 64, 81,",10
  .byte "and 100.",0
help_page11:
  .byte 2,"fizz fibo",1,10
roundinstr_tn1fibo:
  .byte "sum of last 2",10
  .byte "these are",10
  .byte "1, 2, 3, 5, 8,",10
  .byte "13, 21, 34, 55,",10
  .byte "and 89.",0

; PALETTE HANDLER ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "CODE"
;;
; Loads a palette darkened by A (a multiple of $10).
.proc copy_faded_pal
  eor #$FF
  tay
  iny
  ldx #$3F
  stx PPUADDR
  ldx #0
  stx PPUADDR
loop:
  tya
  clc
  adc initial_palette,x
  bpl have_A
  lda #$0F  ; map negative colors to black
have_A:
  sta PPUDATA
  inx
  cpx #12
  bcc loop
  rts
.endproc

.segment "RODATA"
initial_palette:
  mbyt "0f001020 0f1a2a20 0f172720"

; LINE FORMATTERS FOR INTERSTITIAL PAGES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.segment "CODE"
.proc print_line_number
  tya
  ora #'0'
  ldx #2
  jsr fizz_putchar
  rts
.endproc

.proc print_round_instructions
str = $00
cur_fbtype = $02
cur_fbvalue = $03
unused4 = $04
;lineno = $05
unused6 = $06
  dey  ; 0-1: fizz; 2-3: buzz; 4-5: other
;  sty lineno
  cpy #4
  bcc not_bottom_part
  lda roundinstr_neitherlo-4,y
  sta str+0
  lda roundinstr_neitherhi-4,y
  sta str+1
  ldx #2
  jmp fizz_puts0

not_bottom_part:
  tya
  lsr a  ; carry set iff second line of fizz or buzz instruction
  tya
  and #$02
  tax
  lda fbvalue,x
  sta cur_fbvalue
  lda fbtype,x
  sta cur_fbtype
  bcs second_line

  ; LINE 1
  ; B: fizz 60/n
  ; Three parts: the name of the button, the parameter (only for
  ; multiples and factors), and the short name
  ; This is the only colored line
  lda roundinstr_attrs,x
  ldy #7
colorloop:
  sta fizz_attrbuf,y
  dey
  bpl colorloop
  
  ; Name of the button
  ldy roundinstr_button_names+0,x
  lda roundinstr_button_names+1,x
  ldx #2
  jsr fizz_puts

  ; Multiples and factors parameter
  lda cur_fbtype
  cmp #2
  bcs first_line_no_fbvalue
  lda cur_fbvalue
  jsr print_one_number_at_x
first_line_no_fbvalue:

  ; And the shortname
  ldy cur_fbtype
  lda roundinstr_typenames0lo,y
  sta 0
  lda roundinstr_typenames0hi,y
  sta 1
  jmp fizz_puts0

second_line:
  ; LINE 2
  ; factors of 60
  ; two parts: the parameter (only for multiples and factors),
  ; and a longer description
  tax
  ldy roundinstr_typenames1lo,x
  lda roundinstr_typenames1hi,x
  ldx #2
  jsr fizz_puts
  lda cur_fbtype
  cmp #2
  bcs second_line_no_fbvalue
  lda cur_fbvalue
  jsr print_one_number_at_x
second_line_no_fbvalue:
  rts
.endproc

.segment "RODATA"
help_pagehandlers:
  .addr print_round_instructions-1
  .addr print_line_number-1

roundinstr_neitherlo:
  .byte <roundinstr_neither1, <roundinstr_neither2
roundinstr_neitherhi:
  .byte >roundinstr_neither1, >roundinstr_neither2
roundinstr_button_names:
  .addr roundinstr_bfizz, roundinstr_abuzz
roundinstr_typenames0lo:
  .byte <roundinstr_tn0mul, <roundinstr_tn0fac
  .byte <roundinstr_tn0pri, <roundinstr_tn0sq
  .byte <roundinstr_tn0fibo
roundinstr_typenames0hi:
  .byte >roundinstr_tn0mul, >roundinstr_tn0fac
  .byte >roundinstr_tn0pri, >roundinstr_tn0sq
  .byte >roundinstr_tn0fibo
roundinstr_typenames1lo:
  .byte <roundinstr_tn1mul, <roundinstr_tn1fac
  .byte <roundinstr_tn1pri, <roundinstr_tn1sq
  .byte <roundinstr_tn1fibo
roundinstr_typenames1hi:
  .byte >roundinstr_tn1mul, >roundinstr_tn1fac
  .byte >roundinstr_tn1pri, >roundinstr_tn1sq
  .byte >roundinstr_tn1fibo
roundinstr_attrs:
  .byte $55, $FF, $AA
roundinstr_bfizz:   .byte "B: fizz ",0
roundinstr_abuzz:   .byte "A: buzz ",0
roundinstr_tn0fac:  .byte "/"
roundinstr_tn0mul:  .byte "n",0
roundinstr_tn0pri:  .byte "prime",0
roundinstr_tn0sq:   .byte "n",$84,0
roundinstr_tn0fibo: .byte "fibo",0
roundinstr_tn1mul:  .byte "multiples of ",0
roundinstr_tn1fac:  .byte "factors of ",0
roundinstr_neither1:.byte "down: count",0
roundinstr_neither2:.byte "other numbers",0

.if 0
  .byte 2,"B: fizz 3n",1,10
  .byte "multiples of 3",10
  .byte 3,"A: buzz 5n",1,10
  .byte "multiples of 5",10
  .byte "down: count",10
  .byte "other numbers",0,0
.endif
