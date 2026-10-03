.setcpu "6502"
.export _read_key, _detect_layout, _video_init
.export _release_supported, _key_down, _held_key, _pending_key
.segment "BSS"
_release_supported: .res 1
_key_down: .res 1
_held_key: .res 1
_pending_key: .res 1
.segment "CODE"
; Byte result in A, X=0. No private zero page. A/X/Y/flags caller-saved.
_read_key:
    ldx #0
    lda _pending_key
    beq @latch
    stx _pending_key
    jmp @key
@latch:
    lda $c000
    bmi @key
    lda #0
    rts
@key:
    and #$7f
    sta _held_key           ; Raw code, before C normalizes letter case.
    tay
    lda $c010              ; Save AKD while acknowledging this event.
    and #$80
    sta _key_down
    tya
    rts
; Main is entered with LC bank 2 readable by cc65. Temporarily expose ROM,
; follow Misc TN #7, then restore LC bank 2. No code executes in LC here.
; 0=old, 1=IIe/later, 2=unknown (UI defaults old with manual choice).
_detect_layout:
    php
    sei
    lda #0
    sta _release_supported  ; Unknown machines and IIgs retain timed notes.
    bit $c082
    sec
    jsr $fe1f
    bcc @new
    lda $fbb3
    cmp #$06
    beq @akd               ; IIe/IIc keyboard, separate from layout choice.
    cmp #$ea
    bne @unknown
    lda $fb1e
    cmp #$ad
    bne @unknown
    lda #0
    beq @done
@akd:
    lda #1
    sta _release_supported
@new:
    lda #1
    bne @done
@unknown:
    lda #2
@done:
    bit $c080
    ldx #0
    plp
    rts
_video_init:
    pha
    bit $c051
    bit $c054
    pla
    beq @done
    ; Only IIe family hardware gets IIe-only video switches.
    lda #0
    sta $c00c
    sta $c00e
    sta $c000
@done:
    rts
