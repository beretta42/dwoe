;;; See LICENSE GPL3 Copyright 2017, Brett M. Gordon

	import 	dev_init
	import  dev_send
	import  dev_recv


	section	code
	jmp 	start

BUFSIZ equ 576
TYPE   equ $6809

	;; our mac address
mac	.db	$00,$01,$02,$03,$04,$05
	;; server's mac address (broadcast to start)
serv	.db	$ff,$ff,$ff,$ff,$ff,$ff
seqno	.db	0		; current sequence number
bufz	.dw	0		; size of current buffer
buff	zmb	BUFSIZ		; data buffer


putc	jmp	$a282

putn
	anda	#$f
	cmpa	#9
	bhi	a@
	adda	#$30
	bsr	putc
	rts
a@	adda	#'A-10
	bsr	putc
	rts

puth
	pshs	a
	lsra
	lsra
	lsra
	lsra
	bsr	putn
	puls	a
	bsr	putn
	rts

putw	pshs	d
	bsr	puth
	tfr	b,a
	bsr	puth
	puls	d,pc



print	pshs	d,x,y
	tfr	d,y
	bsr	putw
	lda	#32
	bsr	putc
a@	lda	,x+
	bsr	puth
	lda	#32
	bsr	putc
	leay	-1,y
	bne	a@
	puls	d,x,y,pc


start
	ldx	#mac		; initialize NIC card
	jsr	dev_init
	bcs	err
	ldx	#hello@-1	; Print a string
	jsr	$b99c
d@	ldd	#fe-frame	; send handmade frame
	ldx	#frame
	jsr	dev_send
	;; receive any frame
a@	ldx	#buff
	ldd	#BUFSIZ
	jsr	dev_recv
	std	bufz
	beq	a@		; is size 0? no data
	;; Is our ethertype?
	ldd	buff+12
	cmpd	#TYPE
	bne	a@		; nope ...do again
	;; Is it our MAC?
	ldx	#mac
	ldy	#buff
	ldb	#6
b@	lda	,x+
	cmpa	,y+
	bne	a@		; nope ...do again
	decb
	bne	b@
	;; Is it a response?
	ldd	buff+14		; is response?
	anda	#1		;
	beq	a@		; nope ...do again
	;; does sequence match ours?
	cmpb	seqno
	bne	a@		; nope ...do again
	;; print it
c@	ldd	bufz
	ldx	#buff
	bsr	print
	lda	#13
	lbsr	putc
	jsr	$a1b1		; get a key
	bra	d@
	;; return error
err	ldx	#bad@-1		; print bad init
	jsr	$b99c
	rts			; return to BASIC
hello@	fcn	"DWOE"
bad@	fcn	"DEVICE NOT FOUND"

frame	.db	$ff,$ff,$ff,$ff,$ff,$ff ; Broadcast
	.db	$00,$01,$02,$03,$04,$05 ; our MAC (needed?)
	.dw	TYPE                    ; dw ethertype
	.db	$00			; flags (command)
	.db	$00			; sequence
	.dw	1			; size of data
	.db	$23		
fe
