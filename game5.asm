;
; Game5.asm
;
; Created: 4/23/2026 12:31:42 AM
; Author : Dat Truong
; Decs   : Reaction Time Game 
; ----------------------------------------------------------------------

.nolist
.include "m328pdef.inc"
.list

; Pin setup
.equ LED_PIN = 5          ; PORTB bit 5 (digital pin 13)
.equ BTN1_PIN = 3         ; PIND bit 3 (INT1 - digital pin 7) - Player 1
.equ BTN2_PIN = 2         ; PIND bit 2 (INT0 - digital pin 6) - Player 2

; Register Definitions
.def winner = r16
.def temp = r17
.def blink_count = r18
.def random_val = r19
.def counter = r20
.def reaction_time = r21
.def temp2 = r22
.def temp3 = r23
.def button_pressed = r24    ; Flag: 0 = waiting, 1 = button pressed

; ============================================
; Reset Vector and Interrupt Vectors
; ============================================
.cseg
.org 0x0000
    rjmp START
.org INT0addr              ; External Interrupt 0 (PD2 - Player 2 button)
    rjmp ISR_INT0
.org INT1addr              ; External Interrupt 1 (PD3 - Player 1 button)
    rjmp ISR_INT1

.include "lcd1.inc"         ; Include LCD routines 

; ============================================
; Interrupt Service Routines
; ============================================
ISR_INT0:
    ; Player 2 pressed button (PD2)
    push temp
    in temp, SREG           ; Save status register
    push temp
    
    ; Check if we're actually waiting for a button press
    tst button_pressed
    brne INT0_EXIT          ; Already handled, ignore
    
    ldi winner, 2
    ldi button_pressed, 1   ; Set flag
    rcall STOP_TIMER        ; Stop timer immediately
    
INT0_EXIT:
    pop temp
    out SREG, temp          ; Restore status register
    pop temp
    reti

ISR_INT1:
    ; Player 1 pressed button (PD3)
    push temp
    in temp, SREG           ; Save status register
    push temp
    
    ; Check if we're actually waiting for a button press
    tst button_pressed
    brne INT1_EXIT           ; Already handled, ignore
    
    ldi winner, 1
    ldi button_pressed, 1   ; Set flag
    rcall STOP_TIMER        ; Stop timer immediately
    
INT1_EXIT:
    pop temp
    out SREG, temp          ; Restore status register
    pop temp
    reti

; ============================================
; Main Program Start
; ============================================
START:
    ; Setup Stack Pointer
    ldi temp, low(RAMEND)
    out SPL, temp
    ldi temp, high(RAMEND)
    out SPH, temp
    
    ; Setup LED as Output
    sbi DDRB, LED_PIN
    
    ; Setup Buttons as Inputs with Pull-ups
    ; PD2 (INT0) and PD3 (INT1) setup
    cbi DDRD, BTN1_PIN      ; PD3 as input
    sbi PORTD, BTN1_PIN     ; Enable pull-up on PD3
    cbi DDRD, BTN2_PIN      ; PD2 as input
    sbi PORTD, BTN2_PIN     ; Enable pull-up on PD2
    
    ; Setup LCD Pins as Outputs
    sbi DDRB, LCD_RS        ; PB0
    sbi DDRB, LCD_EN        ; PB1
    sbi DDRD, LCD_D4        ; PD4
    sbi DDRD, LCD_D5        ; PD5
    sbi DDRD, LCD_D6        ; PD6
    sbi DDRD, LCD_D7        ; PD7
    
    ; Setup External Interrupts
    ; INT0 (PD2) - Any logical change
    ldi temp, (1<<ISC01)    ; Falling edge trigger for INT0
    sts EICRA, temp
    ; INT1 (PD3) - Any logical change
    ldi temp, (1<<ISC11)    ; Falling edge trigger for INT1
    sts EICRA, temp
    
    ; Enable External Interrupts
    ldi temp, (1<<INT0)|(1<<INT1)
    out EIMSK, temp
    
    ; Initialize LCD
    ldi temp, 200
    rcall DELAY_10MS

    ; LCD INIT SEQUENCE
    ldi temp, 0x30
    out PORTD, temp
    sbi PORTB, LCD_EN
    rcall PULSE
    cbi PORTB, LCD_EN
    rcall DELAY_10MS
    
    ldi temp, 0x30
    out PORTD, temp
    sbi PORTB, LCD_EN
    rcall PULSE
    cbi PORTB, LCD_EN
    rcall DELAY_10MS
    
    ldi temp, 0x30
    out PORTD, temp
    sbi PORTB, LCD_EN
    rcall PULSE
    cbi PORTB, LCD_EN
    rcall DELAY_10MS
    
    ldi temp, 0x20
    out PORTD, temp
    sbi PORTB, LCD_EN
    rcall PULSE
    cbi PORTB, LCD_EN
    rcall DELAY_10MS
    
    ; Function set 
    ldi temp, 0x28
    rcall LCD_CMD
    rcall DELAY_10MS
    
    ; Display ON
    ldi temp, 0x0C
    rcall LCD_CMD
    rcall DELAY_10MS
    
    ; Clear display
    ldi temp, 0x01
    rcall LCD_CMD
    rcall DELAY_50MS
    
    ; Entry mode 
    ldi temp, 0x06
    rcall LCD_CMD
    rcall DELAY_10MS
    
    ; Initialize Timer1 for reaction timing
    clr temp
    sts TCCR1A, temp
    ldi temp, (1<<CS10)     ; No prescaler, run at full speed
    sts TCCR1B, temp
    
    ; Enable global interrupts
    sei

; ============================================
; Main Game Loop
; ============================================
GAME_LOOP:
    ; Turn LED ON
    sbi PORTB, LED_PIN
    
    ; Get random number (2-5 seconds)
    rcall GET_RANDOM
    
    ; Wait random seconds
    mov temp, random_val
    rcall DELAY_SECONDS
    
    ; Prepare for button press
    clr button_pressed       ; Clear button pressed flag
    
    ; Clear timer and turn LED OFF 
    rcall START_TIMER
    cbi PORTB, LED_PIN
    
    ; Wait for button press 
WAIT_LOOP:
    tst button_pressed       ; Check if button was pressed
    breq WAIT_LOOP           ; Keep waiting if not pressed
    
    ; Button was pressed via interrupt
    ; Timer was already stopped in ISR
    
    ; Clear LCD and display results
    rcall LCD_CLEAR
    
    ; Display winner
    rcall DISPLAY_WINNER
    
    ; Move to second line
    ldi temp, 0xC0
    rcall LCD_CMD
    
    ; Display reaction time
    rcall DISPLAY_TIME
    
    ; Show winner with slow, visible blinks
    rcall SHOW_WINNER
    
    ; Pause to read results
    ldi temp, 4
    rcall DELAY_SECONDS
    
    rjmp GAME_LOOP

; ============================================
; Start Timer
; ============================================
START_TIMER:
    push temp
    clr temp
    sts TCNT1H, temp
    sts TCNT1L, temp
    pop temp
    ret

; ============================================
; Stop Timer and Calculate Milliseconds
; ============================================
STOP_TIMER:
    push temp
    
    ; Read Timer1 value
    lds temp, TCNT1L
    mov reaction_time, temp
    
    ; Convert to milliseconds 
    mov temp, reaction_time
    ldi temp2, 100           ; Divide by 100 
    rcall DIVIDE_8BIT
    mov reaction_time, temp2  ; Store result
    
    pop temp
    ret

; ============================================
; 8-bit Division
; ============================================
DIVIDE_8BIT:
    push temp3
    clr temp3
DIV_LOOP:
    cp temp, temp2
    brlo DIV_DONE
    sub temp, temp2
    inc temp3
    rjmp DIV_LOOP
DIV_DONE:
    mov temp2, temp3
    pop temp3
    ret

; ============================================
; Display Winner 
; ============================================
DISPLAY_WINNER:
    push temp
    
    ; Send "Player "
    ldi temp, 'P'
    rcall LCD_CHAR
    
    ldi temp, 'l'
    rcall LCD_CHAR
    
    ldi temp, 'a'
    rcall LCD_CHAR
    
    ldi temp, 'y'
    rcall LCD_CHAR
    
    ldi temp, 'e'
    rcall LCD_CHAR
    
    ldi temp, 'r'
    rcall LCD_CHAR
    
    ldi temp, ' '
    rcall LCD_CHAR
    
    ; Send player number
    mov temp, winner
    subi temp, -'0'
    rcall LCD_CHAR
    
    ; Send " won"
    ldi temp, ' '
    rcall LCD_CHAR
    
    ldi temp, 'w'
    rcall LCD_CHAR
    
    ldi temp, 'o'
    rcall LCD_CHAR
    
    ldi temp, 'n'
    rcall LCD_CHAR
    
    pop temp
    ret

; ============================================
; Display Time 
; ============================================
DISPLAY_TIME:
    push temp
    
    ; Display reaction time as 3 digits
    mov temp, reaction_time
    rcall DISPLAY_3_DIGIT
    
    ; Display " ms"
    ldi temp, ' '
    rcall LCD_CHAR
    
    ldi temp, 'm'
    rcall LCD_CHAR
    
    ldi temp, 's'
    rcall LCD_CHAR
    
    pop temp
    ret

; ============================================
; Display 3-digit number with leading zeros
; ============================================
DISPLAY_3_DIGIT:
    push temp
    push temp2
    push temp3
    
    ; Hundreds digit
    clr temp2
    mov temp3, temp
HUNDREDS_LOOP:
    cpi temp3, 100
    brlo HUNDREDS_DONE
    subi temp3, 100
    inc temp2
    rjmp HUNDREDS_LOOP
HUNDREDS_DONE:
    mov temp, temp2
    subi temp, -'0'
    rcall LCD_CHAR
    
    ; Tens digit
    clr temp2
TENS_LOOP:
    cpi temp3, 10
    brlo TENS_DONE
    subi temp3, 10
    inc temp2
    rjmp TENS_LOOP
TENS_DONE:
    mov temp, temp2
    subi temp, -'0'
    rcall LCD_CHAR
    
    ; Ones digit
    mov temp, temp3
    subi temp, -'0'
    rcall LCD_CHAR
    
    pop temp3
    pop temp2
    pop temp
    ret

; ============================================
; Get Random Number (2-5 seconds)
; ============================================
GET_RANDOM:
    push counter
    
    lds random_val, RANDOM_COUNT
    inc random_val
    cpi random_val, 6
    brlo SAVE_RANDOM
    ldi random_val, 2
    
SAVE_RANDOM:
    sts RANDOM_COUNT, random_val
    
    pop counter
    ret

; ============================================
; Show Winner Blinks
; ============================================
SHOW_WINNER:
    push blink_count
    push temp
    
    cpi winner, 1
    breq SHOW_PLAYER1
    cpi winner, 2
    breq SHOW_PLAYER2
    rjmp SHOW_DONE

SHOW_PLAYER1:
    ldi blink_count, 2
    rjmp DO_BLINKS

SHOW_PLAYER2:
    ldi blink_count, 3

DO_BLINKS:
    cbi PORTB, LED_PIN
    ldi temp, 1
    rcall DELAY_SECONDS
    
DO_BLINK_LOOP:
    sbi PORTB, LED_PIN
    ldi temp, 1
    rcall DELAY_SECONDS
    cbi PORTB, LED_PIN
    ldi temp, 1
    rcall DELAY_SECONDS
    dec blink_count
    brne DO_BLINK_LOOP

SHOW_DONE:
    pop temp
    pop blink_count
    ret

; ============================================
; Delay Functions
; ============================================
DELAY_SECONDS:
    push temp
DELAY_SEC_LOOP:
    rcall DELAY_1SEC
    dec temp
    brne DELAY_SEC_LOOP
    pop temp
    ret

DELAY_1SEC:
    push r20
    push r21
    push r22
    ldi r20, 46
DELAY_1SEC_OUTER:
    ldi r21, 200
DELAY_1SEC_MID:
    ldi r22, 200
DELAY_1SEC_INNER:
    dec r22
    brne DELAY_1SEC_INNER
    dec r21
    brne DELAY_1SEC_MID
    dec r20
    brne DELAY_1SEC_OUTER
    pop r22 
    pop r21
    pop r20
    ret

; ============================================
; Data Section
; ============================================
.dseg
.org 0x0100
RANDOM_COUNT:
    .byte 1