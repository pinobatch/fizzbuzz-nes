.global OAM
.globalzp nmis, oam_used

; help.s
.global show_help, copy_faded_pal
.globalzp pagenum, pageprogress

; pads.s
.global read_pads, autorepeat
.globalzp cur_keys, new_keys, das_keys, das_timer

; tilevwf.s
.global fizz_linebuf, fizz_attrbuf, row_attrstart
.global zet_decode, fizz_clrline, fizz_putchar
.global fizz_puts, fizz_puts0, fizz_puts_color, fizz_puts_color0
.global fizz_copyline_wide, fizz_copyline_tall

; fizztertiles.s
.global fizzter_zet, fizzter_chr_size, fizzter_startoffsets
.global fizzter_tilerow0
.globalzp fizzter_tilerowlen, fizzter_numglyphs

; title.s
.global title_screen

; titletiles.s
.global title_zet, title_chr_size, title_nam
.globalzp title_w, title_h

; bg.s
.globalzp num_players, num_history
.globalzp time_subtenths, time_tenths, time_seconds, time_minutes
WRONG_TIME = 50  ; time in deciseconds to display error messages

DIRTY_1P     = $01  ; draw inside of 1P's window (and 1P's decs in 2P)
DIRTY_2P     = $02  ; draw decs and inside of 2P's window
DIRTY_TOPBAR = $10  ; draw top bar (fizz target, buzz target, time)
DIRTY_CLS    = $80  ; clear the whole screen
; when both DIRTY_1P and DIRTY_2P are set, draw window decs too
.globalzp bgup_jobtype, bg_dirty, bgup_progress
.globalzp wrongtime, actual_press, expected_press

.global bg_gen_line, bg_gen_topbar, print_one_number_at_x
.global bgprep_init, bgprep, bgup, player_dirty_bit
.global clear_stopwatch, inc_stopwatch
.global reset_player_numbers, add_player_number

; bcd.s
.global bcd8bit

; ppuclear.s
.global ppu_zero_nt, ppu_clear_nt, ppu_clear_oam, ppu_screen_on

; paldetect.s
.globalzp tvSystem
.global getTVSystem

; fbmath.s
MAX_NUMBER = 100
SEQTYPE_MULTIPLES = 0
SEQTYPE_FACTORS = 1
SEQTYPE_PRIMES = 2
SEQTYPE_SQUARES = 3
SEQTYPE_FIBO = 4

.globalzp cur_num, fbtype, fbprev, fbstate
fbvalue = fbtype + 1
fizztype = fbtype
fizzvalue = fbtype+1
buzztype = fbtype+2
buzzvalue = fbtype+3
.global inc_cur_num, div1bya, div1by2

; sound.s
.globalzp pently_zp_state
.global pently_init, pently_start_sound, pently_update

; musicseq.s
SFX_COUNT = 0
SFX_FIZZ = 1
SFX_BUZZ = 2
SFX_FIZZBUZZ = 3
SFX_WRONG = 4

; factorall.s
.global prime_factorization

; oh look, here's a macro pack! ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; I have no legs and I must ARM
.macro inceq arg, arg2
.local nope
  bne nope
  .if .paramcount < 2
    inc arg
  .else
    inc arg, arg2
  .endif
nope:
.endmacro

.macro inccs arg, arg2
.local nope
  bcc nope
  .if .paramcount < 2
    inc arg
  .else
    inc arg, arg2
  .endif
nope:
.endmacro

; but let's not leave Z80 out of it
.macro lday arg
  .local argvalue
  .if (.match (.left (1, {arg}), #))
    argvalue = .right(.tcount({arg})-1, {arg})
    lda #>argvalue
    .if .const(argvalue) && (>argvalue = <argvalue)
      tay
    .else
      ldy #<argvalue
    .endif
  .else
    argvalue = arg
    lda arg+1
    ldy arg
  .endif
.endmacro

.macro stay arg
  .local argvalue
  argvalue = arg
  sta arg+1
  sty arg
.endmacro

; unofficial opcodes are so metal
.macro axs arg
  .local argvalue
  .if (.match (.left (1, {arg}), #))
    argvalue = .right(.tcount({arg})-1, {arg})
    .byte $CB, argvalue
  .else
    .error "instruction supports only immediate mode"
  .endif
.endmacro


