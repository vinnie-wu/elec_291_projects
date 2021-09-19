; LCD_test_4bit.asm: Initializes and uses an LCD in 4-bit mode
; using the most common procedure found on the internet.
$NOLIST
$MODEFM8LB1
$LIST

org 0000H

;---------------------------------;
; Main loop.  Initialize stack,   ;
; ports, LCD, and displays        ;
; letters on the LCD              ;
;---------------------------------;
myprogram:
    ; DISABLE WDT: provide Watchdog disable keys
	mov	WDTCN,#0xDE ; First key
	mov	WDTCN,#0xAD ; Second key

    mov SP, #7FH ; Initialize stack
    ; Enable crossbar and weak pull-ups
	mov	XBR0,#0x00
	mov	XBR1,#0x00
	mov	XBR2,#0x40

    lcall LCD_4BIT
	
	MOV R4,#0x80; Line 1 column 1, permanent address
	MOV R5,#0xC2; LINE 2 column 3, permanent address
	MOV dptr, #200H
	
CUTE_CHARM:
	INC R4
	mov a, R4
	clr a
	movc a, @a+dptr
	jnz STILL_CHARMING
	sjmp WELCOME_ADDRESS_INIT
STILL_CHARMING:
	lcall WriteData
	MOV R2,#1
	lcall WaitTenthSecond
	inc dptr
	sjmp CUTE_CHARM	
	
WELCOME_ADDRESS_INIT:
	mov dptr,#400H
	
WELCOME_ADDRESS:
	INC R5
	mov a, R5
	lcall WriteCommand
	clr a
	movc a, @a+dptr
	jnz STILL_WELCOMING
	sjmp LOOP_01_INIT
STILL_WELCOMING:
	lcall WriteData
	MOV R2, #1
	lcall WaitTenthSecond
	inc dptr
	sjmp WELCOME_ADDRESS	
	
	
LOOP_01_INIT:

	; Waits for around ~3 seconds
	; Clears up the screen
	; Re-position cursers
	; Outputs new code :D
	Mov R2, #30
	lcall WaitTenthSecond
	mov a, #0x01 ;  Clear screen command (takes some time)
    lcall WriteCommand
    mov R2, #2
    lcall WaitmilliSec ; Cleaning FINISHED -- now writing
	
	MOV R4,#0x80; REPOSITION LINE-1
	MOV R5,#0xC2; REPOSITION LINE-2
	MOV dptr,#600H

LOOP_01:
    INC R4
	mov a, R4 ; Move cursor to line 1 column 1
    lcall WriteCommand
    clr a
    movc a, @a+dptr
    jnz STILL_WRITING_NAME ; TERMINATE if dptr reached the end.
	sjmp row_2
STILL_WRITING_NAME:
    lcall WriteData
    MOV R2,#1
    lcall WaitTenthSecond
    inc dptr
    sjmp LOOP_01
    
row_2:
		dec r5
		dec r5 ; Starting position = line 2, column 1.
		mov dptr,#800H
row_2a:	
	INC R5
    mov a, R5 ; Move cursor to line 2 column 3
    lcall WriteCommand
    clr a
    movc a, @a+dptr
    jnz STILL_WRITING_NUMBERS
    ljmp forever
STILL_WRITING_NUMBERS:    
    lcall WriteData
    MOV R2,#2
    lcall WaitTenthSecond
    inc dptr
    sjmp row_2a
    
ORG 200H
DB 'o','(','^','O','^',')','o',0;
ORG 400H
DB 'W','e','l','c','o','m','e','!','!',0;
ORG 600H
DB 'W','E','I','N','I','N','G',' ','W','U',0;
ORG 800H
DB '5','0','3','9','1','8','0','4',0;


; These 'equ' must match the hardware wiring
LCD_RS equ P2.0
LCD_RW equ P1.7  ; Not used in this code but must be set to zero
LCD_E  equ P1.6
LCD_D4 equ P1.1
LCD_D5 equ P1.0
LCD_D6 equ P0.7
LCD_D7 equ P0.6

;For a 6MHz default clock, one machine cycle takes 1/6.0000MHz=166.666ns

;---------------------------------;
; Wait 40 microseconds            ;
;---------------------------------;
Wait40uSec:
    push AR0
    mov R0, #40
L0: nop
    nop
    djnz R0, L0 ; 1+1+4 cycles->6*166.666ns*40=40us
    pop AR0
    ret

;---------------------------------;
; Wait 'R2' milliseconds          ;
;---------------------------------;
WaitmilliSec:
    push AR0
    push AR1
L3: mov R1, #10
L2: mov R0, #150
L1: djnz R0, L1 ; 4 cycles -> 4*166.666ns*150=100us
    djnz R1, L2 ; 100us*10=1ms
    djnz R2, L3 ; number of milliseconds to wait passed in R2
    pop AR1
    pop AR0
    ret
;-----------------------------;
; Self-implemented Funciton	;
;-------------------------------;
WaitTenthSecond:
    push AR0
    push AR1
    push AR6
L7: mov R6, #10    
L6: mov R1, #100
L5: mov R0, #150
L4: djnz R0, L4 ; 4 cycles -> 4*166.666ns*150=100us
    djnz R1, L5 ; 100us*100=0.01s
    djnz R6, L6 ; 0.01s*10=0.1s
    djnz R2, L7 ; number of TIME_UNIT to wait passed in R2
    pop AR6
    pop AR1
    pop AR0
    ret
;---------------------------------;
; Toggles the LCD's 'E' pin       ;
;---------------------------------;
LCD_pulse:
    setb LCD_E
    lcall Wait40uSec
    clr LCD_E
    ret

;---------------------------------;
; Writes data to LCD              ;
;---------------------------------;
WriteData:
    setb LCD_RS
    ljmp LCD_byte

;---------------------------------;
; Writes command to LCD           ;
;---------------------------------;
WriteCommand:
    clr LCD_RS
    ljmp LCD_byte

;---------------------------------;
; Writes acc to LCD in 4-bit mode ;
;---------------------------------;
LCD_byte:
    ; Write high 4 bits first
    mov c, ACC.7
    mov LCD_D7, c
    mov c, ACC.6
    mov LCD_D6, c
    mov c, ACC.5
    mov LCD_D5, c
    mov c, ACC.4
    mov LCD_D4, c
    lcall LCD_pulse

    ; Write low 4 bits next
    mov c, ACC.3
    mov LCD_D7, c
    mov c, ACC.2
    mov LCD_D6, c
    mov c, ACC.1
    mov LCD_D5, c
    mov c, ACC.0
    mov LCD_D4, c
    lcall LCD_pulse
    ret

;---------------------------------;
; Configure LCD in 4-bit mode     ;
;---------------------------------;
LCD_4BIT:
    clr LCD_E   ; Resting state of LCD's enable is zero
    clr LCD_RW  ; We are only writing to the LCD in this program so LCD_RW must be zero

    ; After power on, wait for the LCD start up time before initializing
    mov R2, #40
    lcall WaitmilliSec

    ; First make sure the LCD is in 8-bit mode and then change to 4-bit mode
    mov a, #0x33
    lcall WriteCommand
    mov a, #0x33
    lcall WriteCommand
    mov a, #0x32 ; change to 4-bit mode
    lcall WriteCommand

    ; Configure the LCD
    mov a, #0x28
    lcall WriteCommand
    mov a, #0x0c
    lcall WriteCommand
    mov a, #0x01 ;  Clear screen command (takes some time)
    lcall WriteCommand

    ;Wait for clear screen command to finish. Usually takes 1.52ms.
    mov R2, #2
    lcall WaitmilliSec
    ret


    
forever:
    sjmp forever
END
