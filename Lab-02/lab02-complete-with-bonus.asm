; ISR_example.asm: a) Increments/decrements a BCD variable every half second using
; an ISR for timer 2; b) Generates a 440 Hz square wave at pin P3.7 using
; an ISR for timer 0; and c) in the 'main' loop it displays the variable
; incremented/decremented using the ISR for timer 2 on the LCD.  Also resets it to 
; zero if the 'BOOT' pushbutton connected to P3.7 is pressed.
$NOLIST
$MODEFM8LB1
$LIST

CLK           EQU 24000000 ; Microcontroller system crystal frequency in Hz
TIMER0_RATE   EQU 440*2    ; The tone we want out is A major.  Interrupt rate must be twice as fast.
TIMER0_RELOAD EQU ((65536-(CLK/(TIMER0_RATE))))
TIMER2_RATE   EQU 50     ; 50 Hz = 0.02 seconds in code
TIMER2_RELOAD EQU ((65536-(CLK/12/(TIMER2_RATE))))

;---- ADDED Timer 4! -----------
TIMER4_RATE   EQU 250
TIMER4_RELOAD EQU ((65536-(CLK/(TIMER4_RATE))))

BOOT_BUTTON   equ P3.7
SOUND_OUT     equ P2.1
UPDOWN        equ P0.0

LED_LIGHT	equ P3.2

ADD_MINUTES equ P3.1
ADD_HOURS   equ P3.3

ADD_ALARM_HOURS 	equ P2.5
ADD_ALARM_MINUTES 	equ P2.2

; Reset vector
org 0x0000
    ljmp main

; External interrupt 0 vector (not used in this code)
org 0x0003
	reti

; Timer/Counter 0 overflow interrupt vector
org 0x000B
	ljmp Timer0_ISR

; External interrupt 1 vector (not used in this code)
org 0x0013
	reti

; Timer/Counter 1 overflow interrupt vector (not used in this code)
org 0x001B
	reti

; Serial port receive/transmit interrupt vector (not used in this code)
org 0x0023 
	reti
	
; Timer/Counter 2 overflow interrupt vector
org 0x002B
	ljmp Timer2_ISR

; In the 8051 we can define direct access variables starting at location 0x30 up to location 0x7F
dseg at 0x30
Count1ms:     ds 2 ; Used to determine when half second has passed
Count1s:	  ds 3 ; Used to determine if 

BCD_counter:  ds 1 ; The BCD counter incrememted in the ISR and displayed in the main loop
MINUTE_counter: 	 ds 1 ; Minutes incremented in ISR_4.
HOUR_counter:	ds 1

ALARM_hour:		ds 1
ALARM_minute:	ds 1

; In the 8051 we have variables that are 1-bit in size.  We can use the setb, clr, jb, and jnb
; instructions with these variables.  This is how you define a 1-bit variable:
bseg
one_seconds_flag: dbit 1 ; Set to one in the ISR every time 500 ms had passed
AM_or_PM_SELECT: dbit 1
ALARM_AM_or_PM: dbit 1

cseg
; These 'equ' must match the wiring between the microcontroller and the LCD!
LCD_RS equ P2.0
LCD_RW equ P1.7
LCD_E  equ P1.6
LCD_D4 equ P1.1
LCD_D5 equ P1.0
LCD_D6 equ P0.7
LCD_D7 equ P0.6
$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

;                     1234567890123456    <- This helps determine the location of the counter
Initial_Message:  db 'TIME        ', 0
AM_Message: db 'AM', 0
PM_Message: db 'PM', 0
COLON_Message: db ':', 0
ALARM_Message: db 'ALARM', 0
TEST_Message: db '*', 0

;-----------------------------------;
; Routine to initialize the timer 0 ;
;-----------------------------------;
Timer0_Init:
	orl CKCON0, #00000100B ; Timer 0 uses the system clock
	mov a, TMOD
	anl a, #0xf0 ; Clear the bits for timer 0 || LOGICAL "AND"
	orl a, #0x01 ; Configure timer 0 as 16-timer
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret
	

;---------------------------------;
; ISR for timer 0.                ;
;---------------------------------;
Timer0_ISR:
	;clr TF0  ; According to the data sheet this is done for us already.
	; Timer 0 can not autoreload so we need to reload it in the ISR:
	clr TR0 ; start/stop register
	mov TH0, #high(TIMER0_RELOAD) 
	mov TL0, #low(TIMER0_RELOAD)
	setb TR0
	cpl SOUND_OUT ; Toggle the pin connected to the speaker
	reti

;---------------------------------;
; Routine to initialize timer 2   ;
;---------------------------------;
Timer2_Init:
	orl CKCON0, #0b00000000 ; Timer 2 uses the PRE-SCALED clock defined in TMR2CN0
	mov TMR2CN0, #0 ; Stop timer/counter.  Autoreload mode. Timer 2 uses systemCLK/12 clock.
	mov TMR2H, #high(TIMER2_RELOAD)
	mov TMR2L, #low(TIMER2_RELOAD)
	; Set the reload value
	mov TMR2RLH, #high(TIMER2_RELOAD)
	mov TMR2RLL, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Enable the timer and interrupts
    setb ET2  ; Enable timer 2 interrupt
    setb TR2  ; Enable timer 2
	ret

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
	clr TF2H  ; Reset Over-flow flag for Timer 2, HIGH byte.
	
	; The two registers used in the ISR must be saved in the stack
	push acc
	push psw
	
	; Increment the 16-bit one mili second counter
	inc Count1ms+0    ; Increment the low 8-bits first
	mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
	jnz Inc_Done	; jump if Accumulator isn't 0
	inc Count1ms+1

Inc_Done:
	; Check if one second has passed
	mov a, Count1ms+0
	cjne a, #low(50), Timer2_ISR_done ; Compare, jump if not equal.
										;Warning: this instruction changes the carry flag!
	mov a, Count1ms+1
	cjne a, #high(50), Timer2_ISR_done
	
	; 500 milliseconds have passed.  Set a flag so the main program knows
	setb one_seconds_flag ; Let the main program know half second had passed
	cpl TR0 ; Enable/disable timer/counter 0. This line creates a beep-silence-beep-silence sound.
	setb SOUND_OUT
	; Reset to zero the milli-seconds counter, it is a 16-bit variable
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Increment the BCD counter
	mov a, BCD_counter
	jnb UPDOWN, Timer2_ISR_decrement ; decrement a (which is BCD_counter) if UPDOWN is 0
	add a, #0x01 ; Increment a
	sjmp Timer2_ISR_da
Timer2_ISR_decrement:
	add a, #0x99 ; Adding the 10-complement of -1 is like subtracting 1.
Timer2_ISR_da:
	da a ; Decimal adjust instruction.  Check datasheet for more details!
	mov BCD_counter, a
	
Timer2_ISR_done:
	pop psw
	pop acc
	reti

;||||||||||||||||||||||||||||||||||||
; --- Self-Declared Functions -----
;||||||||||||||||||||||||||||||||||||

; ============  Timer 4 Initialization ! ===========




;---------------------------------;
; Hardware initialization         ;
;---------------------------------;
Initialize_All:
    ; DISABLE WDT: provide Watchdog disable keys
	mov	WDTCN,#0xDE ; First key
	mov	WDTCN,#0xAD ; Second key

    ; Enable crossbar and weak pull-ups
	mov	XBR0,#0x00
	mov	XBR1,#0x00
	mov	XBR2,#0x40

	mov	P2MDOUT,#0x02 ; make sound output pin (P2.1) push-pull
	
	; Switch clock to 24 MHz
	mov	CLKSEL, #0x00 ; 
	mov	CLKSEL, #0x00 ; Second write to CLKSEL is required according to the user manual (page 77)
	
	; Wait for 24 MHz clock to stabilze by checking bit DIVRDY in CLKSEL
waitclockstable:
	mov a, CLKSEL
	jnb acc.7, waitclockstable 

	; Initialize the two timers used in this program
    lcall Timer0_Init
    lcall Timer2_Init

    lcall LCD_4BIT ; Initialize LCD
    
    setb EA   ; Enable Global interrupts

	ret

;---------------------------------;
; Main program.                   ;
;---------------------------------;
main:
	; Setup the stack start to the begining of memory only accesible with pointers
    mov SP, #7FH
    
	lcall Initialize_All
	clr AM_or_PM_SELECT ; Initialize to AM first!
    ; For convenience a few handy macros are included in 'LCD_4bit.inc':
	Set_Cursor(1, 1)
    Send_Constant_String(#Initial_Message) ; <--- this is the "BCD_counter: xx" message

	; --- Initialize AM/PM	------------
	jb AM_or_PM_SELECT, INITIALIZE_PM
	Set_Cursor(1,15)
	Send_Constant_String(#AM_Message)
	sjmp DONE_INITIALIZING_AM_PM
INITIALIZE_PM:
	Set_Cursor(1,15)
	Send_Constant_String(#PM_Message)
DONE_INITIALIZING_AM_PM:
	; --- Done initializing AM/PM

	Set_Cursor(1,11)
	Send_Constant_String(#COLON_Message)
	Set_Cursor(1,8)
	Send_Constant_String(#COLON_Message)
	
	; --- Line 2 -----
	Set_Cursor(2,1)
	Send_Constant_String(#ALARM_Message)
	Set_Cursor(2,9)
	Send_Constant_String(#COLON_Message)
	
    setb one_seconds_flag
	clr LED_LIGHT ; Set LED initially to OFF

	mov BCD_counter, #0b01010000 ; BCD for 50 (https://miniwebtool.com/hex-to-bcd-converter/?number=32)
	mov MINUTE_counter, #0b01011001 ; BCD for 59 (https://miniwebtool.com/hex-to-bcd-converter/?number=3B)
	mov HOUR_counter, #0b00010001 ; BCD for 11 (https://miniwebtool.com/hex-to-bcd-converter/?number=B)
	
	mov ALARM_hour, #0b00000010 ; BCD for 2 (https://miniwebtool.com/hex-to-bcd-converter/?number=2)
	mov ALARM_minute, #0b00010101 ; BCD for 15 (https://miniwebtool.com/hex-to-bcd-converter/?number=F)

	clr ALARM_AM_or_PM
	Set_Cursor(2,13)
	Send_Constant_String(#AM_Message)
	; After initialization the program stays in this 'forever' loop
loop:
	jb BOOT_BUTTON, ADJUST_HOURS  ; if the 'BOOT' button is not pressed skip
	Wait_Milli_Seconds(#50)	; Debounce delay.  This macro is also in 'LCD_4bit.inc'
	jb BOOT_BUTTON, ADJUST_HOURS  ; if the 'BOOT' button is not pressed skip
	jnb BOOT_BUTTON, $		; Wait for button release.  The '$' means: jump to same instruction.
	; A valid press of the 'BOOT' button has been detected, reset the BCD counter.
	; But first stop timer 2 and reset the milli-seconds counter, to resync everything.
	clr TR2                 ; Stop timer 2
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	; Now clear the BCD counter
	mov BCD_counter, a
	setb TR2                ; Start timer 2

ADJUST_HOURS:
; --------- Set Hours ----------
	jb ADD_HOURS, ADJUST_MINUTES
	Wait_Milli_Seconds(#50)
	jb ADD_HOURS, ADJUST_MINUTES
	jnb ADD_HOURS, $
	ljmp INCREMENT_HOURS

ADJUST_MINUTES:
; -------- Set Minutes ----------
	jb ADD_MINUTES, ALARM_HOUR_ADJUST
	Wait_Milli_Seconds(#50)
	jb ADD_MINUTES, ALARM_HOUR_ADJUST
	jnb ADD_MINUTES, $
	ljmp INCREMENT_MINUTES


ALARM_HOUR_ADJUST:
	; 1). Show the ALARM hr time
	Set_Cursor(2,7)
	Display_BCD(ALARM_hour)
	jb ADD_ALARM_HOURS, CONTINUE_01
	Wait_Milli_Seconds(#50)
	jb ADD_ALARM_HOURS, CONTINUE_01
	jnb ADD_ALARM_HOURS, $
	mov a, ALARM_hour
	add a, #0x01
	da a
	mov ALARM_hour, a

	; compare if reached 12 --> select AM & PM
	cjne a, #0b00010010, CONTINUE_01 ; BCD value for 12 (https://miniwebtool.com/hex-to-bcd-converter/?number=C)
	cpl ALARM_AM_or_PM
	jb ALARM_AM_or_PM, ALARM_PM_ROUTINE
	Set_Cursor(2,13)
	Send_Constant_String(#AM_Message)
	sjmp CONTINUE_01

ALARM_PM_ROUTINE:
	Set_Cursor(2,13)
	Send_Constant_String(#PM_Message)

CONTINUE_01:
	; 2). 13 --> 1 
	cjne a, #0b00010011, ALARM_HR_ADJUST_COMPLETE; BCD for 13
	clr a
	add a, #0x01
	da a 
	mov ALARM_hour, a

ALARM_HR_ADJUST_COMPLETE:	

ALARM_MINUTE_ADJUST:
	; 1. Show the ALARM minute time
	Set_Cursor(2,10)
	Display_BCD(ALARM_minute)
	jb ADD_ALARM_MINUTES, loop_a
	Wait_Milli_Seconds(#50)
	jb ADD_ALARM_MINUTES, loop_a
	jnb ADD_ALARM_MINUTES, $
	mov a, ALARM_minute
	add a, #0x01
	da a
	mov ALARM_minute, a
	cjne a, #0b01100000, ALARM_MIN_ADJUST_COMPLETE ; BCD for 60 (https://miniwebtool.com/hex-to-bcd-converter/?number=3C)
	clr a
	da a 
	mov ALARM_minute, a

ALARM_MIN_ADJUST_COMPLETE:
	sjmp loop_b             ; Display the new value
loop_a:

NEXT_02:
	sjmp loop_a_content
NEXT_03:
	ljmp loop
loop_a_content:
	jnb one_seconds_flag, NEXT_03

loop_b:
    clr one_seconds_flag ; We clear this flag in the main loop, but it is set in the ISR for timer 2

	; ---- Change seconds to 60 --> 0 once reached.
	mov a, BCD_counter
	sjmp NEXT
	CONTINUE_RUNNING_pre:
	ljmp CONTINUE_RUNNING

NEXT: cjne a, #0b01100000, CONTINUE_RUNNING_pre ;---> Continue to display seconds as seconds <60
	
	clr TR2 ; Stops timer 2
	clr a
	mov BCD_counter, a ; Sets 60 --> 0 seconds
	setb TR2

INCREMENT_MINUTES:
	clr TR2
	clr a	
	mov a, MINUTE_counter	; +1 minute
	add a, #0x01
	da a
	mov MINUTE_counter, a
	setb TR2 ; Start timer 2

	; ---- Change MINUTE 60 --> 0 once reached.	
	clr a
	mov a, MINUTE_counter
	cjne a, #0b01100000, CONTINUE_RUNNING
	clr TR2 ; Stops timer 2
	clr a
	mov MINUTE_counter, a ; Sets 60 --> 0 minutes
	setb TR2

INCREMENT_HOURS:
	clr TR2
	clr a
	mov a, HOUR_counter
	add a, #0x01
	da a
	mov HOUR_counter, a
	setb TR2 ; Start timer 2
	; Increment hours

	; ---- Change 'AM' to 'PM'-----------
	clr a
	mov a, HOUR_counter
	cjne a, #0b00010010, DONE_SETTING_AM_PM ; Continue if <12
	cpl AM_or_PM_SELECT
	jb AM_or_PM_SELECT, CHOOSE_PM
	Set_Cursor(1,15)
	Send_Constant_String(#AM_Message)
	sjmp DONE_SETTING_AM_PM
CHOOSE_PM:
	Set_Cursor(1,15)
	Send_Constant_String(#PM_Message)
DONE_SETTING_AM_PM:
	; ------- AM/PM is set -------

	; ---- Change HOUR 13 --> 1 ONCE REACHED	
	clr a
	mov a, HOUR_counter
	cjne a, #0b00010011, CONTINUE_RUNNING ; continue if <13 		
	clr TR2 ; Stops timer 2
	clr a
	inc a
	da a
	mov HOUR_counter, a ; Sets 13 --> 1 hours
	setb TR2 ; Start timer 2
CONTINUE_RUNNING:
	Set_Cursor(1, 12)     ; the place in the LCD where we want the BCD counter value
	Display_BCD(BCD_counter) ; Display Seconds ------- macro described in 'LCD_4bit.inc'

	Set_Cursor(1,9)
	Display_BCD(MINUTE_counter)

	Set_Cursor(1,6)
	Display_BCD(HOUR_counter)
	; If 60 seconds is up, restart it.
	mov a, ALARM_hour
	cjne a, HOUR_counter, JUMP_TO_LOOP
	mov a, ALARM_minute
	cjne a, MINUTE_counter, JUMP_TO_LOOP
	;just testing...
	setb LED_LIGHT
	Set_Cursor(2,16)
	Send_Constant_String(#TEST_Message)

JUMP_TO_LOOP:    
	ljmp loop


END
