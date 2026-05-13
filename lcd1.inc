;
; lcd1.inc
;
; Created: 4/23/2026 12:36:24 AM
; Author: Dat Truong
; Desc: library 
; -------------------------------------------------------------------

; LCD Pin Definitions
.equ LCD_RS = 0           ; PORTB bit 0 (digital pin 8)
.equ LCD_EN = 1           ; PORTB bit 1 (digital pin 9)
.equ LCD_D4 = 4           ; PORTD bit 4 (digital pin 4)
.equ LCD_D5 = 5           ; PORTD bit 5 (digital pin 5)
.equ LCD_D6 = 6           ; PORTD bit 6 (digital pin 6)
.equ LCD_D7 = 7           ; PORTD bit 7 (digital pin 7)

; ============================================
; LCD Functions 
; ============================================
LCD_CMD:
    cbi PORTB, LCD_RS
    rcall LCD_BYTE
    ret

LCD_CHAR:
    sbi PORTB, LCD_RS
    rcall LCD_BYTE
    ret

LCD_BYTE:
    push temp
    out PORTD, temp
    sbi PORTB, LCD_EN
    rcall PULSE
    cbi PORTB, LCD_EN
    rcall DELAY_1MS
    swap temp
    out PORTD, temp
    sbi PORTB, LCD_EN
    rcall PULSE
    cbi PORTB, LCD_EN
    rcall DELAY_1MS
    pop temp
    ret

LCD_CLEAR:
    push temp
    ldi temp, 0x01
    rcall LCD_CMD
    rcall DELAY_50MS
    pop temp
    ret

PULSE:
    nop
    nop
    nop
    nop
    ret

; ============================================
; LCD Delay Functions 
; ============================================
DELAY_50MS:
    push temp
    ldi temp, 5
DELAY_50MS_LOOP:
    rcall DELAY_10MS
    dec temp
    brne DELAY_50MS_LOOP
    pop temp
    ret

DELAY_10MS:
    push r20
    push r21
    ldi r20, 2
DELAY_10MS_OUTER:
    ldi r21, 200
DELAY_10MS_INNER:
    dec r21
    brne DELAY_10MS_INNER
    dec r20
    brne DELAY_10MS_OUTER
    pop r21
    pop r20
    ret

DELAY_1MS:
    push r20
    push r21
    ldi r20, 1
DELAY_1MS_OUTER:
    ldi r21, 200
DELAY_1MS_INNER:
    dec r21
    brne DELAY_1MS_INNER
    dec r20
    brne DELAY_1MS_OUTER
    pop r21
    pop r20
    ret