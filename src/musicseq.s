;
; sound data for FizzBuzz
; copr. 2014 Damian Yerrick
;
.segment "RODATA"
.export psg_sound_table

psg_sound_table:
  .addr sfx_count_data
  .byte $10,$06
  .addr sfx_fizz_data
  .byte $0c,$0e
  .addr sfx_buzz_data
  .byte $1c,$07
  .addr sfx_fizzbuzz_data
  .byte $1c,$0f
  .addr sfx_wrong_data
  .byte $10,$0b

sfx_count_data:
  .byte $87,$2c,$44,$2c,$42,$2c,$87,$33,$44,$33,$42,$33
sfx_fizz_data:
  .byte $83,$06,$86,$03,$89,$04,$8a,$03,$8a,$06,$89,$03,$88,$04,$87,$03
  .byte $86,$06,$85,$03,$84,$04,$83,$03,$82,$06,$81,$03
sfx_buzz_data:
  .byte $05,$0b,$08,$8a,$08,$8a,$08,$8a,$07,$8a,$06,$8a,$05,$8a
sfx_fizzbuzz_data:
  .byte $83,$06,$88,$8a,$88,$8a,$8a,$06,$89,$03,$88,$8a,$88,$8a,$86,$06
  .byte $85,$03,$88,$8a,$88,$8a,$84,$06,$82,$03,$82,$8a,$81,$8a
sfx_wrong_data:
  .byte $88,$13,$8a,$0f,$89,$0c,$88,$09,$88,$07,$48,$07,$08,$07,$08,$07
  .byte $06,$07,$01,$07,$01,$07
