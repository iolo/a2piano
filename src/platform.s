.setcpu "6502"
.export _read_key, _detect_layout, _video_init
.segment "CODE"
; Byte result in A, X=0. No private zero page. A/X/Y/flags caller-saved.
_read_key:
    ldx #0
    lda $c000
    bmi @key
    lda #0
    rts
@key:
    bit $c010
    and #$7f
    rts
; Main is entered with LC bank 2 readable by cc65. Temporarily expose ROM,
; follow Misc TN #7, then restore LC bank 2. No code executes in LC here.
; 0=old, 1=IIe/later, 2=unknown (UI defaults old with manual choice).
_detect_layout:
    php
    sei
    bit $c082
    sec
    jsr $fe1f
    bcc @new
    lda $fbb3
    cmp #$06
    beq @new
    cmp #$ea
    bne @unknown
    lda $fb1e
    cmp #$ad
    bne @unknown
    lda #0
    beq @done
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
