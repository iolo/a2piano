.setcpu "6502"
.export _speaker_play, _speaker_outer, _speaker_inner, _speaker_count
.export speaker_loop, speaker_end
.segment "BSS"
_speaker_outer: .res 1
_speaker_inner: .res 1
_speaker_count: .res 2
.segment "TIMING"
; Fixed interval: 51 + 1284*outer + 5*inner CPU cycles (outer = 0 or 1).
; Carry-based countdown makes low-byte wrap cost identical to other iterations.
; Keyboard checked each half-period (worst case 2.28 ms). Leave strobe pending
; for the shared dispatcher. No C, ROM calls, I/O other than keyboard/speaker.
_speaker_play:
    php
    sei
    cld                     ; Count in binary; PLP restores caller D/I.
speaker_loop:
    bit $c030                ; 4
    ldx _speaker_outer       ; 4
    beq short_delay          ; 3 (0), 2 (1)
long_delay:
    ldy #0                   ; 2
long_inner:
    dey
    bne long_inner           ; 1279 total
    dex                      ; 2
    bne long_delay           ; 2 (outer=1)
short_delay:
    ldy _speaker_inner       ; 4
short_inner:
    dey
    bne short_inner          ; 5*inner-1
    bit $c000                ; 4
    bmi speaker_end          ; 2, or 3 to stop
    sec                      ; 2
    lda _speaker_count       ; 4
    sbc #1                   ; 2
    sta _speaker_count       ; 4
    lda _speaker_count+1     ; 4
    sbc #0                   ; 2
    sta _speaker_count+1     ; 4
    ora _speaker_count       ; 4
    beq speaker_end          ; 2, or 3 to stop
    jmp speaker_loop         ; 3
speaker_end:
    plp
    rts
.assert >speaker_loop = >speaker_end, lderror, "speaker branches cross page"
