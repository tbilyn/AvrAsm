;
; Atmega-LCD.asm
;
; Created: 14-Dec-19 23:00:10
; Author : Me
;


; Replace with your application code
.def	temp				= r16		; used as temporary storage, should not be used in interrupts, subroutines may change that value
.def	temp2				= r17
.def	delay_ms_overflows	= r18	
.def	delay_ms_val		= r19

.equ	lcd_e_mask		= 0b00100000
.equ	lcd_e_pin		= 5
.equ	lcd_rs_pin		= 4

.macro delay_us
	ldi delay_ms_val, 1
	rcall delay
.endmacro

.macro delay_ms
	ldi delay_ms_val, @0
	rcall delay
.endmacro

.macro sendHalfByteImmidiate
	ldi temp, @0
	push temp						; push function argument into stack
	call sendHalfByteFunc
	pop temp						; remove argument from 
.endmacro

.macro sendByteImmidiate
	ldi temp, @0
	push temp
	call sendByteFunc
	pop temp
.endmacro

.macro sendByteFromRAM				; receives one argument - address of RAM, the byte of which will be send to LCD
	lds temp, @0
	push temp
	call sendByteFunc
	pop temp

.endmacro



	.org 0x0000
	rjmp Init

	.org 0x0020             ; Timer0 overflow handler
	rjmp delay_ms_overflow_handler


Init:
	ldi temp, 0b00000011
	out TCCR0B, temp				; TCNT0 in FCPU/64 mode, 250000 cnts/sec
	ldi temp, 249
	out OCR0A, temp

	ldi temp, 0b00000010
	out TCCR0A, temp				; reset TCNT0 at top of OCR0A
	sts TIMSK0, temp				; Enable Timer Overflow Interrupts
	sei								; enable global interrupts
	
	; PORTC init
	ldi temp, 0xff
	out DDRC, temp		; make port c pins as output
	ldi temp, 0
	out PORTC, temp		; PortC pins low

	; LCD Init
	delay_ms 15
	sendHalfByteImmidiate 0b00000011
	delay_ms 4
	sendHalfByteImmidiate 0b00000011
	delay_ms 100
	sendHalfByteImmidiate 0b00000011
	delay_ms 1
	sendHalfByteImmidiate 0b00000010
	delay_ms 1
	sendHalfByteImmidiate 0b00000010
	delay_ms 1

	cbi PORTC, lcd_rs_pin			; we are sending commands

	sendByteImmidiate 0b00000000	
	delay_ms 1
	sendByteImmidiate 0b00110000
	delay_ms 1
	sendByteImmidiate 0b10000000
	delay_ms 1
	sendByteImmidiate 0b11001100
	delay_ms 1

	

Main:
    sbi PORTC, lcd_rs_pin			; we are sending data

	sendByteImmidiate 0b01001111	; O
	sendByteImmidiate 0b01001100	; L
	sendByteImmidiate 0b01000101	; E
	sendByteImmidiate 0b01001011	; K
	sendByteImmidiate 0b01010011	; S
	sendByteImmidiate 0b01000001	; A

loop:
	nop
    rjmp loop

delay:
	clr delay_ms_overflows
	sec_count:
		cpse delay_ms_overflows, delay_ms_val
	rjmp sec_count
ret

delay_ms_overflow_handler: 
	inc delay_ms_overflows       ; increment 1000 times/sec
reti

sendHalfByteFunc:					; receives argument - byte of data bits 3:0 of which should be sent to LCD
	; push values of register that are going to be used by subroutine into stack
	; so that we can return them back after we are done

	push r30						; keep values in register z
	push r31						;

	in r30, spl
	in r31, sph

	ldd temp2, z+5						; get argument passed to this function
	andi temp2, 0b00001111				; as we use lower 4 bits, make sure upper ones are cleared
	ori temp2, lcd_e_mask		; bit for LCD Enable make high

	in temp, PORTC					; copy current state of PORTC, we will copy values from argument value in temp
	andi temp, 0b11110000			; reset bits 3:0, so we can later set what is sent in halfByte
	or temp, temp2						; set pins as in halfByte

	out PORTC, temp					; set pins
	delay_us 50
	cbi PORTC, lcd_e_pin			; reset enable pin, LCD will read data on pins
	delay_ms 50

	; return values into register as they were before subroutine call
	pop r31							
	pop r30

	ret

sendByteFunc:
	push r30						; keep values in register z
	push r31

	in zh, sph
	in zl, spl

	ldd temp, z+5
	swap temp

	push temp	
	call sendHalfByteFunc
	pop temp

	swap temp

	push temp
	call sendHalfByteFunc
	pop temp

	pop r31
	pop r30

	ret


