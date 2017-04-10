;;; See LICENSE GPL3 Copyright 2017, Brett M. Gordon

	import 	dev_init
	import  dev_send
	import  dev_recv


	section	code
	jmp 	start

BUFSIZ equ 600			; send/recv buffer size
TYPE   equ $6809		; ethertype of DWOE
TO     equ 12			; timeout in clocks jiffies.
RETRY  equ 5			; times to retry

	;; a static output buffer
obuff
serv	.db	$ff,$ff,$ff,$ff,$ff,$ff
mac	.db	$00,$01,$02,$03,$04,$05
	.dw	TYPE		; ethertype
	.db	0		; command flag
seqno	.db	0		; current sequence number
bufz	.dw	1		; size of current buffer
dataptr	rmb	BUFSIZ-(*-obuff) ; reserve rest for data

	;; some send frame state
opos	.dw	dataptr	; packet data pointer
smacflag .db	0		; serv addr is set
timeout	.dw	0		; response timeout
retry	.db	0		; retry
	
	;; a static input buffer
buff	zmb	BUFSIZ		; data buffer



;;;
;;; Debug printing routines - delete when bug free :)
;;; 
	
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


;;; Send command, await result
;;;   takes: nothing
;;;   returns: X = result buffer, D = len, C = timeout
;;;   note: use append routines to add data bytes to packet before using this!
;;;   this waits for up to TO*RETRY seconds for a server reposonse
send
	pshs	y		; save reg
	;;
	;; finalize and send packet/frame
	;;
	ldb	#RETRY		; reset retry count
	stb	retry
again@	ldd	opos
	subd	#dataptr
	std	bufz
	addd	#dataptr-obuff
	ldx	#obuff
	jsr	dev_send
	;; set timer
	ldd	$112
	addd	#TO
	std	timeout
	;;
	;; receive a frame
	;;
a@	ldx	#buff		; get a frame from NIC
	ldd	#BUFSIZ
	jsr	dev_recv
	std	bufz
	bne	d@		; is size 0? no data
	;; test for timeout
	ldd	$112		; timeout?
	cmpd	timeout
	blt	a@		; no, try receive again
	dec	retry		; bump retry counter
	beq	toerr@		; 
	bra	again@		; resend packet 
	;;
	;; Toss out non matching packets/frames
	;;
	;; Is our ethertype?
d@	ldd	buff+12
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
	;;
	;; **** Good packet from here ****
	;;
	;;  grab server MAC
	tst	smacflag
	bne 	c@		; don't need one
	com	smacflag	; set flag
	ldx	#serv		; copy sender's mac
	ldy	#buff+6
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++
	ldd	,y++
	std	,x++
	;; reset the send state
c@	ldd	#dataptr	; reset opos
	std	opos
	inc	seqno		; increment sequence no
	;; load up regs with result
	clra			; clear C
	ldx	#buff+18	
	ldd	buff+16
	puls	y,pc		; return
	;; return with timeout error
toerr@	coma			; set C
	puls	y,pc

;;; Append a byte to output buffer
;;;   takes: B = byte
;;;   returns: nothing
appendb
	pshs	x
	ldx	opos
	stb	,x+
	stx	opos
	puls	x,pc

;;; Append a word (16 bits) to output buffer
;;;   takes: D = word
;;;   returns: nothing
appendw
	pshs	x
	ldx	opos
	std	,x++
	stx	opos
	puls	x,pc

;;; Append a string to output buffer
;;;   takes: X = ptr, D = len
;;;   returns: nothing
appends
	pshs	d,x,y,u
	tfr	d,y
	ldu	opos
a@	ldb	,x+
	stb	,u+
	leay	-1,y
	bne	a@
	stu	opos
	puls	d,x,y,u,pc


start
	ldx	#mac		; initialize NIC card
	jsr	dev_init
	bcs	err@
	ldx	#hello@-1	; Print a string
	jsr	$b99c
	;; loop starts here
d@	ldb	#$23		; send a time command
	jsr	appendb
	jsr	send
	bcs	to@
	;; print the received packet
	lbsr	print
e@	lda	#13		; print a CR
	lbsr	putc
	jsr	$a1b1		; get a key
	bra	d@		; and repeat!
	;; print timeout error
to@	ldx	#tostr@-1
	jsr	$b99c
	bra	e@
	;; return error
err@	ldx	#bad@-1		; print bad init
	jsr	$b99c
	rts			; return to BASIC
hello@	fcn	"DWOE"
bad@	fcn	"DEVICE NOT FOUND"
tostr@	fcn	"TIMEOUT"