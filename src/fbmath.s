;
; Math for FizzBuzz game
;
;
;
;
;
.include "fizzbuzz.inc"

.segment "ZEROPAGE"


; fbtype is multiples, factors, primes, squares, or fibo
; (one of the SEQTYPE_* constants)
; fbvalue is multiple of what or factor of what
; 0: fizz type; 1: fizz value; 2: buzz type; 3: buzz value
; value used only for multiples and factors,
; not squares, primes, or fibo
fbtype:  .res 4

; Numbers that have been counted by each player.
; Starts at 0; win once it reaches MAX_NUMBER.
cur_num: .res 2


; fbprev is previous matching number
; fbstate is a state variable
;   not used in multiples (next is fbprev + fbvalue)
;   not used in factors (division used instead)
;   not used in primes (next has smallest prime factor quotient = 1)
;   in squares, it's 2 * the square root of the next number - 1
;     (next is fbprev + fbstate)
;   in fibo, it's the penult number (next is fbprev + fbstate)
;   factors to be determined
; 0: 1p fizz, 1: 2p fizz, 2: 1p buzz, 3: 2p buzz
fbprev:  .res 4
fbstate: .res 4

.segment "CODE"

; Accept tests ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
; The test for each type shall set

;;
; @param X bit 0: Player (0=left, 1=right) bit 1: category (0=fizz, 2=buzz)
.proc test_multiple
xsave = 0
multiple_of = 1

  stx xsave
  txa
  and #$02
  tax
  lda fbvalue,x
  sta multiple_of
  lda xsave
  and #$01
  tax
  lda cur_num,x
  ldx xsave
  sec
  sbc multiple_of
  cmp fbprev,x
  beq yes_multiple
  clc
yes_multiple:  ; CMP always sets C if it sets Z
  rts
.endproc

.proc test_square
xsave = 0
  stx xsave
  lda fbstate,x
  bne fbstate_is_inited
  inc fbstate,x
fbstate_is_inited:
  txa
  and #$01
  tax
  lda cur_num,x
  ldx xsave
  sec
  sbc fbstate,x
  cmp fbprev,x
  beq yes_square
  clc
  rts
yes_square:
  ; the next square gap is two more than the previous square gap
  inc fbstate,x
  inc fbstate,x
  rts
.endproc

.proc test_fibo
xsave = 0
  stx xsave
  lda fbprev,x
  bne fbprev_is_inited
  inc fbprev,x     ; we jump in at 0, 1, [1], 2, 3, 5, 8, ...
fbprev_is_inited:  ; so make sure the previous is 1
  txa
  and #$01
  tax
  lda cur_num,x
  ldx xsave
  sec
  sbc fbstate,x
  cmp fbprev,x
  beq yes_fibo
  clc
  rts
yes_fibo:
  lda fbprev,x
  sta fbstate,x
  rts
.endproc

.proc test_prime
xsave = 0
  stx xsave
  txa
  and #$01
  tax
  lda cur_num,x
  cmp #2
  bcc have_carry  ; 0, 1: not prime
  beq have_carry  ; 2: is prime
  lsr a
  bcc have_carry  ; other even numbers: not prime
  rol a
  tax
  lda #2
  ; For any odd number x:
  ; prime_factorization[x-1] = smallest prime factor (PF)
  ; prime_factorization[x] = quotient after dividing by smallest PF
  ; If this quotient is 1 and 1 < x < table_size, then x is prime.
  ; Otherwise it's composite, and the quotients form a linked list
  ; of its PFs.  But just the smallest PF and its quotient are enough
  ; to prove a number not prime.
  cmp prime_factorization,x
have_carry:
  ldx xsave
  rts
.endproc

.proc test_factor
xsave = 0
numer = 1
denom = 2
quotient = 0

  stx xsave
  txa
  and #$02
  tax
  lda fbvalue,x
  sta numer
  lda xsave
  and #$01
  tax
  lda cur_num,x
  ldx xsave
  ; A is the denominator
  cmp #1
  beq have_carry  ; 1 is a factor of every positive integer
  cmp numer
  beq have_carry  ; n is a factor of n by definition
  bcs not_factor  ; if denom > numer, denom is not a factor of numer

  ; I tried dividing the numer and denom by powers of 2 and deciding
  ; based on that, but those didn't save much on the worst case of
  ; whether 3 divides 97 (it doesn't). Nor did the smallest prime
  ; factor table help (try it with does 7 divide 63).
  ; So we really need to try dividing numer by A.  Fortunately,
  ; we can use this as the generic division routine to show the
  ; player what the remainder is in factors and multiples modes.
  
div1bya:
  sta denom
div1by2:
  lda #1
  sta quotient
  lsr a

divloop:
  asl numer
  rol a
  bcs already_greater
  cmp denom
  bcc not_greater
already_greater:
  sbc denom
  sec
not_greater:
  rol quotient
  bcc divloop
  ; at this point, A is the remainder
  cmp #0
  beq have_carry
not_factor:
  clc
have_carry:
  rts
.endproc

;;
; @param $0001 dividend (numerator)
; @param A divisor (denominator)
; @return A = remainder, 0 = quotient, C = Z
div1bya = test_factor::div1bya
div1by2 = test_factor::div1by2

;;
; Increments a player's cur_num and finds the correct fizzbuzz value
; for this number.
; @param X player number
; @param bit 0: fizz; bit 1: buzz
.proc inc_cur_num
  inc cur_num,x
  txa
  ora #$02
  tax
  lda buzztype
  jsr fbdispatch
  dex
  dex
  bcc :+
  lda cur_num,x
  sta fbprev+2,x
:
  lda #0
  rol a
  pha
  txa
  and #$01

  tax
  lda fizztype
  jsr fbdispatch
  bcc :+
  lda cur_num,x
  sta fbprev,x
:
  pla
  rol a
  rts

fbdispatch:
  asl a
  tay
  lda fbtests+1,y
  pha
  lda fbtests,y
  pha
  rts

.pushseg
.segment "RODATA"
fbtests:
  .addr test_multiple-1, test_factor-1, test_prime-1
  .addr test_square-1, test_fibo-1
.popseg
.endproc


.segment "RODATA"

numbers_choices_base:

; Numbers suitable for use as fbvalue in multiples rounds.
; Prime numbers have exactly two divisors, 1 and itself:
; d(n) = 2
; This is the set of all largely composite numbers n where
; 3 <= n <= 11.
; 3 because 2 would divide too many (half) of candidate numbers.
; 11 because a period too much larger than square root of the length
; of a round would cause the player to lose his place.
small_primes:
  .byte 3, 5, 7, 11
num_small_primes = * - small_primes
.assert num_small_primes < 256, error, "Way too many small prime numbers"

; Numbers suitable for use as fbvalue in factors rounds.
; The largely composite numbers are those with at least as many
; distinct divisors as all natural numbers smaller than it:
; d(n) >= d(k) for all 1 <= k <= n
; This is the set of all largely composite numbers n where
; 50 <= n <= 255.
; 50 because it's half the length of a round, which is 100, and
; 255 because the 6502 is 8-bit.
; http://oeis.org/A067128
largely_composite:
  .byte 60, 72, 84, 90, 96, 108, 120, 168, 180, 240
num_largely_composite = * - largely_composite
.assert num_largely_composite < 256, error, "Way too many largely composite numbers"

; Primes, squares, and Fibonacci numbers don't use an fbvalue.

