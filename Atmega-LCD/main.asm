;
; Atmega-LCD.asm
;
; Created: 14-Dec-19 23:00:10
; Author : Me
;


; Replace with your application code
.def	temp				= r16
.def	halfByte			= r17
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

.macro sendHalfByte
	ldi halfByte, @0				; load input into register
	andi halfByte, 0b00001111		; as we use lower 4 bits, make sure upper ones are cleared
	ori halfByte, lcd_e_mask		; bit for LCD Enable make high

	in temp, PORTC					; copy current state of PORTC, we will copy values fr0m halfByte in temp
	andi temp, 0b11110000			; reset bits 3:0, so we can later set what is sent in halfByte
	or temp, halfByte				; set pins as in halfByte
		
	out PORTC, temp					; set pins
	delay_us 50
	cbi PORTC, lcd_e_pin			; reset enable pin, se data is read
	delay_ms 50
.endmacro

.macro sendByteByParts
	sendHalfByte @0
	sendHalfByte @1
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
	sendHalfByte 0b00000011
	delay_ms 4
	sendHalfByte 0b00000011
	delay_ms 100
	sendHalfByte 0b00000011
	delay_ms 1
	sendHalfByte 0b00000010
	delay_ms 1
	sendHalfByte 0b00000010
	delay_ms 1

	cbi PORTC, lcd_rs_pin			; we are sending commands

	sendByteByParts 0b0000, 0b0000	
	delay_ms 1
	sendByteByParts 0b0011, 0b0000
	delay_ms 1
	sendByteByParts 0b1000, 0b0000
	delay_ms 1
	sendByteByParts 0b01100, 0b1100
	delay_ms 1

	

Main:
    sbi PORTC, lcd_rs_pin			; we are sending data
	sendByteByParts 0b0100, 0b1111	; O
	sendByteByParts 0b0100, 0b1100	; L
	sendByteByParts 0b0100, 0b0101	; E
	sendByteByParts 0b0100, 0b1011	; K
	sendByteByParts 0b0101, 0b0011	; S
	sendByteByParts 0b0100, 0b0001	; A

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