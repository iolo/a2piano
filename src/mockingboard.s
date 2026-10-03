.setcpu "6502"
.include "timing.inc"
.importzp ptr1
.export _mb_init, _mb_play, _mb_period
.segment "BSS"
mb_page: .res 1
_mb_period: .res 2
mb_ticks: .res 1
.segment "CODE"
; CC65 fastcall byte slot in A. Validate again before deriving an I/O address.
; Owns ptr1 only during these leaf API calls. A/X/Y/flags caller-saved.
; Only the selected slot is touched, never searched or probed.
_mb_init:
    cmp #1
    bcc invalid
    cmp #8
    bcs invalid
    ora #$c0
    sta mb_page
    php
    sei
    jsr base
    jsr init_chip
    lda #$80
    sta ptr1
    jsr init_chip
    plp
invalid:
    rts
base:
    lda mb_page
    sta ptr1+1
    lda #0
    sta ptr1
    rts
init_chip:
    ldy #$0e
    lda #$7f                 ; Disable all VIA IRQ sources.
    sta (ptr1),y
    ldy #3
    lda #$ff
    sta (ptr1),y             ; Port A all output.
    dey
    lda #7
    sta (ptr1),y             ; Only AY control bits are outputs.
    ldy #0
    lda #0
    sta (ptr1),y             ; Reset AY; all volumes become zero.
    nop
    nop
    lda #4
    sta (ptr1),y
    ldx #7
    lda #$3f                ; All tone/noise disabled (AY bits 0..2=A..C).
    jsr ay_write
    rts
; X=register, A=value. VIA port A data, port B BC1/BDIR/reset.
ay_write:
    pha
    txa
    ldy #1
    sta (ptr1),y
    dey
    lda #7
    sta (ptr1),y             ; Latch register.
    lda #4
    sta (ptr1),y             ; Inactive.
    pla
    iny
    sta (ptr1),y
    dey
    lda #6
    sta (ptr1),y             ; Write data.
    lda #4
    sta (ptr1),y             ; Inactive.
    rts
_mb_play:
    php
    sei
    jsr base
    ldx #8
    lda #0
    jsr ay_write             ; Mute before replacing both period bytes.
    ldx #0
    lda _mb_period
    jsr ay_write
    ldx #1
    lda _mb_period+1
    jsr ay_write
    ldx #7
    lda #$3e                ; Tone A only, all noise and B/C disabled.
    jsr ay_write
    ldy #$0b
    lda #$40                ; T1 continuous, PB7 not driven.
    sta (ptr1),y
    ldy #4
    lda #<MB_TIMER
    sta (ptr1),y
    iny
    lda #>MB_TIMER
    sta (ptr1),y             ; Start T1, clear previous flag.
    lda #MB_TICKS
    sta mb_ticks
    ldx #8
    lda #10                 ; Fixed volume, envelope bit clear.
    jsr ay_write
@poll:
    bit $c000
    bmi @stop
    ldy #$0d
    lda (ptr1),y
    and #$40
    beq @poll
    ldy #4
    lda (ptr1),y             ; Clear T1 interrupt flag without enabling IRQ.
    dec mb_ticks
    bne @poll
@stop:
    ldx #8
    lda #0
    jsr ay_write
    ldy #$0b
    lda #0
    sta (ptr1),y             ; Leave free-running mode.
    ldy #4
    lda (ptr1),y             ; Acknowledge pending T1 flag.
    plp
    rts
