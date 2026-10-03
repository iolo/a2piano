.setcpu "6502"
.export _speaker_play, _speaker_outer, _speaker_inner, _speaker_count
.export speaker_loop, speaker_end
.export speaker_held_loop, speaker_held_end
.import _release_supported, _held_key, _pending_key
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
    lda _release_supported
    bne speaker_held_loop
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

; AKD mode: same 51 + 1284*outer + 5*inner cycles as the timed loop.
; Compare the raw latched code before reading C010 (which clears the strobe).
; Same-code auto-repeat is acknowledged without interrupting the oscillator;
; a different code is saved for dispatch, even if an AKD read cleared its
; strobe just as it arrived between the two keyboard reads.
speaker_held_loop:
    bit $c030
    ldx _speaker_outer
    beq held_short_delay
held_long_delay:
    ldy #0
held_long_inner:
    dey
    bne held_long_inner
    dex
    bne held_long_delay
held_short_delay:
    ldy _speaker_inner
held_short_inner:
    dey
    bne held_short_inner
    lda $c000               ; 4
    and #$7f                ; 2
    cmp _held_key           ; 4
    bne held_new_key        ; 2
    bit $c010               ; 4: AKD, and acknowledge same-code repeats.
    bpl speaker_held_end    ; 2
    .repeat 8
        nop                 ; 16: balance the timed loop's countdown.
    .endrepeat
    jmp speaker_held_loop   ; 3
held_new_key:
    sta _pending_key
speaker_held_end:
    plp
    rts
.assert >speaker_held_loop = >speaker_held_end, lderror, "held speaker branches cross page"
