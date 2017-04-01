;;; See LICENSE GPL3 Copyright 2017, Brett M. Gordon

	import 	dev_init
	import  dev_send
	
	section	code

mac	.db	$00,$01,$02,$03,$04,$05

	
start
	ldx	#mac		; initialize NIC card
	jsr	dev_init
	bcs	err
	ldx	#hello@-1	; Print a string
	jsr	$b99c
	ldd	#fe-frame	; send handmade frame
	ldx	#frame
	jsr	dev_send
	rts			; return to BASIC
	;; return error
err	ldx	#bad@-1		; print bad init
	jsr	$b99c
	rts			; return to BASIC
hello@	fcn	"DWOE"
bad@	fcn	"DEVICE NOT FOUND"

frame	.db	$ff,$ff,$ff,$ff,$ff,$ff ; Broadcast
	.db	$00,$01,$02,$03,$04,$05 ; our MAC (needed?)
	.db	$08,$00                 ; IP supposedly
	.db	$01,$02,$03		; signature
	fill	$42,60
	.db	$01,$02,$03
fe

	
	end	start