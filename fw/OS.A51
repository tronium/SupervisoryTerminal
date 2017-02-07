;08:59am 04-06-1999 1st time
;16:26pm 04-06-1999 VCALL & VRET (OK)

XCALL	MACRO	Rutin
	MOV	DPTR,#Rutin
	LCALL	_VCALL
ENDM

XRET	MACRO
	LJMP	_VRET
ENDM

$INCLUDE(OS.DEF)
$INCLUDE(STDIO.DEF)

;;NM_NMIE	EQU	80H+(1 SHL (ET0 MOD 8))	; Non Maskable Intr

;SX_OS	SEGMENT	XDATA
;		RSEG	SX_OS

XSTACK		SEGMENT	XDATA
		RSEG	XSTACK
		DS	256

		PUBLIC	XSPL, XSPH

SegD_OS	SEGMENT	DATA

		RSEG	SegD_OS
XSPL:		DS	1		; xtrn stack ptr
XSPH:		DS	1
;XBPL:		DS	1		; xtrn stack-base ptr
;XBPH:		DS	1
;XMPL:		DS	1		; xtrn linear-mem-base ptr
;XMPH:		DS	1
;IBP:		DS	1		; intrn stack-base ptr

ISTACK		SEGMENT	DATA
		RSEG	ISTACK
		ORG	2*26		; yg telah sukses = 8 + 2*23
		DS	0

SegC_OS	SEGMENT	CODE	INBLOCK
		RSEG	SegC_OS

USING	0

; F: "CALL" subrutin (DPTR) dengan menyimpan alamat ret pada xstack
; Dijalankan dgn instr A/L-CALL
; R: A, B & DPTR

;PUBLIC	_VCALL_DPTR
;_VCALL_DPTR:
;	POP	B			; PCH ret
;	POP	ACC			; PCL ret
;	PUSH	DPL			; PCL sub
;	PUSH	DPH			; PCH sub
;	ACALL	__VMOV_DPTR_XSP
;	INC	DPTR
;	INC	DPTR			;; XSP <- XSP+2
;	ACALL	__VMOV_XSP_DPTR		;; dialokasikan dulu sebelum disimpan
;	MOVX	@DPTR,A			; RPCL
;	ACALL	__VDEC_DPTR		;; LO-HI di'XPUSH' terbalik
;	MOV	A,B
;	MOVX	@DPTR,A			; RPCH
;	RET

; F: Kebalikan dari _VCALL
; Dijanlankan dgn instr S/A/L-JMP !
; R: C, A, DPTR
;PUBLIC	_VRET
;_VRET:
;	ACALL	__VMOV_DPTR_XSP
;	MOVX	A,@DPTR
;	PUSH	ACC			; RPCL
;	ACALL	__VDEC_DPTR
;	MOVX	A,@DPTR
;	ACALL	__VDEC_DPTR
;	PUSH	ACC			; RPCH

; F: XSPTR <- DPTR
; R: EA=1
;;122
__VMOV_XSP_DPTR:
	CLR	EA
	MOV	XSPL,DPL		; <- awal penundaan ISR (jika IRQ=1)
	SETB	EA
	MOV	XSPH,DPH
	RET				; <- Penundaan == 6 sk
					;; == 7-8 jika CLR EA <- setelah RETI

; F: DPTR <-> XSPTR
; R: EA=1
;;1
__VXCH_DPTR_XSP:
	XCH	A,DPL
	CLR	EA
	XCH	A,XSPL			; <- awal penundaan ISR
	XCH	A,DPL
	XCH	A,DPH
	SETB	EA
	XCH	A,XSPH
	XCH	A,DPH			; <- Penundaan == 6 sk
	RET				;; == 7-8 jika CLR EA <- setelah RETI

; F: DPTR <- XSPTR
;1122
__VMOV_DPTR_XSP:
	MOV	DPL,XSPL
	MOV	DPH,XSPH
	RET

; F: DPTR <- DPTR - 1
;;1222
__VDEC_DPTR:
	INC	DPL
	DJNZ	DPL,$+5
	DEC	DPH
	DEC	DPL
	RET

;_VPUSH_ACC:
;	ACALL	__VMOV_DPTR_XSP
;	INC	DPTR
;	ACALL	__VMOV_XSP_DPTR
;	MOVX	@DPTR,A
;	RET

;_VPOP_ACC:
;	ACALL	__VMOV_DPTR_XSP
;	MOVX	A,@DPTR
;	ACALL	__VDEC_DPTR
;	AJMP	__VMOV_XSP_DPTR

; @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @

PUBLIC	__VADD_DPTR_A

; F: DPTR <- DPTR + A
; K: PSW: status A+DPL
;11
__VADD_DPTR_A:
	CLR	C

; F: DPTR <- DPTR + A + C
; K: PSW: status A+DPL
;__VADC_DPTR_A:
	XCH	A,DPL
	ADDC	A,DPL
	XCH	A,DPL
	JNC	$+4
	INC	DPH
	RET

; F: DPTR <- DPTR - A
; K: PSW: status A+DPL
;;11
__VSUB_DPTR_A:
	CLR	C

; F: DPTR <- DPTR - A - C
; K: PSW: status A+DPL
;__VSBB_DPTR_A:
	XCH	A,DPL
	SUBB	A,DPL
	XCH	A,DPL
	JNC	$+4
	DEC	DPH
	RET


; Pemakaian stack (teporer) dalam arah master -> slave (CALL):
; Master(?+2) -> SlaveInit(+2) -> VSWAP_CALL(*master=+4; *slave=+2..5) -> ...
; -> SlaveRun(=0)
; * stack master: 8 byte tepakai _sebelum_ SlaveRun dijalankan
; * stack slave : 2..5 byte terpakai untuk _menuju_ SlaveRun
;
; Pemakaian stack (temporer) dalam arah slave -> master (RET):
; SlaveRet(+0) -> VSWAP_RET (*slave=+2..3; *master=+4..5) -> Master(=?)
; * stack slave : 2..3 byte terpakai untuk _memulihkan_ stack master
; * stack master: 4..5 byte terpakai untuk _kembali_ke_ Master

; F: Pengarah Tukar Baru/Lama-IStack berdasarkan isi C
; Masukan:
; C= 1 -> CALL, 0 -> RET
; RCcS=Jml RS ISTK
; RCcT=Jml RT ISTK
; DPTR=@XRS (jika RCcS=0 diabaikan)
; Rusak:
; A, PSW, DPTR, IDP, RCcS, RCcT
; +CALL:  AXPL, AXPH, B

	PUBLIC	SwapIStack
SwapIStack:
	MOV	A,#ISTACK
		;PUSH	PSW
		;ADD	A,#ISTACK
		;POP	PSW
; M: idem + (A=referensi dasar ISTK)
;SwapIStk_Ref:
	JNC	SwapIStk_Ret

;F: Dijalankan oleh SlaveInit (setelah MasterCall) untuk menjalankan SlaveRun
;Proses:
;1. Mem-push ISTK yang terabaikan ([UjungRS+1..SP]) ke xstk
;2. Mem-push SP_Asli pada xstk dan menetapkan SP_Baru (= UjungRT+1)
;1. Men-swap data didalam ISTK ([AwalRS..UjungRS])

SwapIStk_Call:
	POP	AXPH			; alamat return
	POP	AXPL

	MOV	B,A			; referensi istk_baru
	ADD	A,RCcS
	MOV	IDP,A			; IDP <- UjungRS+1
	DEC	A
	ADD	A,RCcT
	XCH	A,RCcT			; RCcT <- SP_baru (ISTK+JmlRN+JmlRT)
					;; (SP_baru >/ UjungRS)

	PUSH	SP			; SP_Asli
	MOV	A,SP
	;CLR	C
	SUBB	A,IDP			; SP - (UjungRS+1)
	JNC	__SSC0			; SP >/ UjungRS+1 (C=0) ?

	CLR	A
	MOV	IDP,SP			; <- hanya SP_Asli yg disimpan

	; Menyimpan isi ISTK yang terabaikan pada XSTACK (sekaligus SP)
__SSC0:
	INC	A
	PUSH	DPL
	PUSH	DPH

	ACALL	__VMOV_DPTR_XSP		; DPTR <- @Puncak_XSTACK
	ACALL	__VADD_DPTR_A
	ACALL	__VXCH_DPTR_XSP		; alokasikan dahulu
	INC	DPTR

	XCH	A,RCcS
		;PUSH	ACC
	ACALL	__VREPSWAP_IX		; ISTK[UjungRS+1..SP] -> XSTACK[DPTR]
		;POP	ACC
	POP	DPH
	POP	DPL

;__SSC1:
	MOV	SP,RCcT			; UjungRT (== alokasi stack slave)
	PUSH	AXPL
	PUSH	AXPH
	JZ	__SSCQ
	; Mempertukarkan isi Register Swap
	MOV	RCcS,A
	MOV	IDP,B
	ACALL	__VREPSWAP_IX		; ISTK[AwalRS..UjungRS] <-> XRAM[..]
__SSCQ:
	RET

;F: Dijalankan oleh SlaveRet untuk kembali ke MasterCall
; Proses:
;1. Men-swap data didalam ISTK ([AwalRS..UjungRS])
;2. Memulihkan SP_Asli (ada dipuncak xstack)
;3. Mem-pop xstk ke ISTK ([UjungRS+1..SP_Asli])

SwapIStk_Ret:
	;-POP	AXPH
	;-POP	AXPL
	MOV	IDP,A				; IDP <- AwalRS
		;ADD	A,RCcS
		;ADD	A,RCcT
		;DEC	A
		;CJNE	A,SP,STACKDAMAGED	; alokasi sesuai ?
	MOV	A,RCcS
	JZ	__SSR0

	; Mempertukarkan isi Register Swap
	ACALL	__VREPSWAP_IX		; ISTK[AwalRS..UjungRS] <-> XRAM[..]

__SSR0:
	; Disini IDP = UjungRS+1
	ACALL	__VMOV_DPTR_XSP
	MOVX	A,@DPTR			; = SP Asli
		;INC	A
		;CJNE	A,#?? ISTK,$+3
		;JC	STACKDAMAGED		; SP+1 < ISTK (c=1) ?
		;DEC	A
	MOV	SP,A			; <- RT diabaikan
	;-PUSH	AXPL
	;-PUSH	AXPH
	CLR	C
	SUBB	A,IDP
	JNC	__SSR1			; SP >/ IDP (C=0) ?
	ACALL	__VDEC_DPTR
	SJMP	__SSRQ

__SSR1:
	; Memulihkan isi ISTK yang disimpan pada XSTACK
	INC	A
	MOV	RCcS,A
		;PUSH	ACC
	MOV	RCcT,A
	ACALL	__VSUB_DPTR_A
	ACALL	__VREPSWAP_IX		; ISTK[UjungRS+1..SP] <- XSTACK[..]
	MOV	A,RCcT
		;POP	ACC
	INC	A
	ACALL	__VSUB_DPTR_A

__SSRQ:
	ACALL	__VMOV_XSP_DPTR		; bebaskan alokasi XSTACK
	RET

; F: REPEAT { IDATA[IDP] <-> XDATA[DPTR]; IDP++; DPTR++; RCcS-- }
;	UNTIL RCcS=zero
; K: IDP <- IDP+RCcS; DPTR <- DPTR+RCcS); 0=256 !
__VREPSWAP_IX:
	PUSH	ACC
___VRSIX:
	MOVX	A,@DPTR
	XCH	A,@IDP
	MOVX	@DPTR,A
	INC	IDP
	INC	DPTR
	DJNZ	RCcS,___VRSIX
	POP	ACC
	RET

;F: MOV XPTR,CODE[A+DPTR]
;K: XPH=[A+DPTR], XPL=[A+1+DPTR], A=XPH
	PUBLIC	XPtrCode
XPtrCode:
	MOV	XPL,A
	INC	A
	MOVC	A,@A+DPTR
	XCH	A,XPL
	MOVC	A,@A+DPTR
	MOV	XPH,A
	RET


;;Hanya menguntungkan untuk n >/ 3 !!!
;;M: R0=@Dst, DPTR=@Src, B=Jml
;__JNR1:	INC	R0
;	INC	DPTR
;JemputNReg:
;	MOVX	A,@DPTR
;	MOV	@R0,A
;__JNR2:	DJNZ	B,__JNR1
;	RET

;;M: R0=@Dst(=R0!), DPTR=@Src, B=Jml
;JemputNRegR0:
;	MOVX	A,@DPTR
;	PUSH	ACC
;;-	MOV	A,R0
;;-	PUSH	ACC
;	INC	R0
;	INC	DPTR
;	ACALL	__JNR2
;	POP	ACC
;	MOV	R0,A
;;-	POP	ACC
;;-	MOV	@R0,A				; Ke-R0 sendiri
;	RET

;;M: R0=@Src, DPTR=@Dst, B=Jml
;__SNR1:	INC	R0
;	INC	DPTR
;SimpanNReg:
;	MOV	A,@R0
;	MOVX	@DPTR,A
;__SNR2:	DJNZ	B,__SNR1
;	RET

;;M: A=@Src(=R0!), DPTR=@Dst, B=Jml
;SimpanNRegR0:
;	XCH	A,R0
;	MOVX	@DPTR,A
;	SJMP	__SNR2

;Hanya menguntungkan untuk n >/ 2 (untuk N=2 hemat 2 byte)
;M: R0=@IDATA, DPTR=@XRAM, B=Jml
;SwapIXData:
;	;PUSH	B
;	MOV	B,A
;__SIXD:	MOVX	A,@DPTR
;	XCH	A,@R0
;	MOVX	@DPTR,A
;	INC	R0
;	INC	DPTR
;	DJNZ	B,__SIXD
;	;POP	B
;	RET

;------------------------------------------------------------------------------
; Subrutin untuk mentransfer DATA(String) rom-ke-xram dan xram-ke-xram
; *) pada tipe segmen, jika sumber dan/atau tujuan = xram, DPH nilainya tetap !
; masukan:
;	DPTR = sumber, tujuan_DPTR = tujuan, RCcL = jml (tipe var)
; keluaran:
;	[tujuan], DPTR, dan tujuan_DPTR disesuaikan
;------------------------------------------------------------------------------

;CInPageCpy:
;	CLR	A
;	MOVC	A,@A+DPTR
;	ACALL	SwapPtr16Plus
;	MOVX	@DPTR,A
;	INC	DPL		;xseg8
;	ACALL	SwapPtr16
;	DJNZ	RCcL,CInPageCpy
;	RET

	PUBLIC	XInPageCpy
XInPageCpy:
	MOVX	A,@DPTR
	INC	DPL		;xseg8
	ACALL	SwapPtr16
	MOVX	@DPTR,A
	INC	DPL		;xseg8
	ACALL	SwapPtr16
	DJNZ	RCcL,XInPageCpy
	RET

;_cs2xs8:
;	INC	DPL		;xseg8
;	ACALL	SwapPtr16
;CStrCpySeg8:
;	CLR	A
;	MOVC	A,@A+DPTR
;	ACALL	SwapPtr16Plus
;	MOVX	@DPTR,A
;	CJNE	A,#EOS,_cs2xs8
;	AJMP	SwapPtr16	; ptr 7an tidak dinaikkan

;_xs2xs8:
;	INC	DPL		;xseg8
;	ACALL	SwapPtr16
;XStrCpySeg8:
;	MOVX	A,@DPTR
;	INC	DPL		;xseg8
;	ACALL	SwapPtr16
;	MOVX	@DPTR,A
;	CJNE	A,#EOS,_xs2xs8
;	AJMP	SwapPtr16	; ptr 7an tidak dinaikkan


	PUBLIC	CChrCpy
CChrCpy:
	CLR	A
	MOVC	A,@A+DPTR
	ACALL	SwapPtr16Plus
	MOVX	@DPTR,A
	ACALL	SwapPtr16Plus
	DJNZ	RCcL,CChrCpy
	RET

	PUBLIC	XChrCpy
XChrCpy:
	MOVX	A,@DPTR
	ACALL	SwapPtr16Plus	; <- stack: 2
	MOVX	@DPTR,A
	ACALL	SwapPtr16Plus
	DJNZ	RCcL,XChrCpy
	RET

	PUBLIC	CStrCpy
_cs2xs16:
	ACALL	SwapPtr16Plus
CStrCpy:
	CLR	A
	MOVC	A,@A+DPTR
	ACALL	SwapPtr16Plus
	MOVX	@DPTR,A
	CJNE	A,#EOS,_cs2xs16
	SJMP	SwapPtr16	; ptr 7an tidak dinaikkan

	PUBLIC	XStrCpy
_xs2xs16:
	ACALL	SwapPtr16Plus
XStrCpy:
	MOVX	A,@DPTR
	ACALL	SwapPtr16Plus
	MOVX	@DPTR,A
	CJNE	A,#EOS,_xs2xs16
	SJMP	SwapPtr16	; ptr 7an tidak dinaikkan

	;PUBLIC	SwapPtr16Plus
SwapPtr16Plus:
	INC	DPTR

	PUBLIC	SwapPtr16
SwapPtr16:
	XCH	A,XPH
	XCH	A,DPH
	XCH	A,XPH
	XCH	A,XPL
	XCH	A,DPL
	XCH	A,XPL
	RET

END

	CSEG	AT 0
TEST:
	MOV	SP,#ISTACK-1
	MOV	XSPL,#LOW XSTACK-1
	MOV	XSPH,#HIGH XSTACK-1

	;MOV	DPTR,#0FFFEH
	;LCALL	Pause
	LCALL	DODOD
	SJMP	TEST

DODOD:
	SETB	C
	LCALL	SWAPREG

	MOV	DPTR,#_VRET
	LCALL	_VCALL_DPTR
	CLR	C
SWAPREG:
	MOV	RCcS,#2
	MOV	RCcS,#2
	MOV	DPTR,#0FF00H
	LJMP	SwapIStack

END

; @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @ @
;Struktur TData

SX_TData	SEGMENT	DATA
		RSEG	SX_TData

STRUC	MACRO	FIELD,NLOC
		FIELD	SET	LOC
		LOC	SET	LOC+NLOC
ENDM	

TaskMax		EQU	5
UraianTugas:

LOC	SET	0
STRUC	TD_Next,2
STRUC	TD_Priori,1
STRUC	TD_Delta,1
STRUC	TD_Konteks,1
STRUC	TD_ISP,1
STRUC	TD_ISData,20
TD_Size		EQU	LOC



SC_KERNEL	SEGMENT	CODE
		RSEG	SC_KERNEL

Pause:
	PUSH	DPL
	PUSH	DPH
	PUSH	ACC
	PUSH	PSW
	PUSH	AR0

	MOV	DPTR,#0

	MOV	A,B
	INC	DPTR
	MOVX	@DPTR,A		; B
	MOV	A,P2
	INC	DPTR
	MOVX	@DPTR,A		; P2

	MOV	R0,#AXPH
?P1:	MOV	A,@R0
	INC	DPTR
	MOVX	@DPTR,A		; R7, R6, R5, R4, R3, R2, R1
	DJNZ	R0,?P1

	MOV	R2,#7
	MOV	R0,SP
?P2:	MOV	A,@R0
	DEC	R0
	INC	DPTR
	MOVX	@DPTR,A		; R0, PSW, ACC, DPH, DPL, PCH, PCL
	DJNZ	R2,?P2

	MOV	A,R0
	INC	DPTR
	MOVX	@DPTR,A		; SP
	;MOV	SP,A

	MOV	A,XSPL
	INC	DPTR
	MOVX	@DPTR,A
	MOV	A,XSPH
	INC	DPTR
	MOVX	@DPTR,A
	CJNE	R0,#ISTACK-1,?P3a
	SJMP	?P3b
?P3a:
	MOV	DPL,XSPL
	MOV	DPH,A

?P3:	MOV	A,@R0
	DEC	R0
	INC	DPTR		; (IE?), DPH, DPL, PCH, PCL, ISTACK[top...base]
	MOVX	@DPTR,A
	CJNE	R0,#ISTACK-1,?P3
?P3b:
	MOV	SP,R0

	MOV	DPTR,#0

Resume:
	;MOV	DPTR,#TD_XSP

	MOVX	A,@DPTR
	MOV	XSPL,A		; XSPL
	INC	DPTR
	MOVX	A,@DPTR
	MOV	XSPH,A		; XSPH
	MOV	DPH,A
	MOV	DPL,XSPL

??0:	INC	DPTR
	MOVX	A,@DPTR
	MOV	@R0,A		; (IE?), DPH, DPL, PCH, PCL, ISTACK[top...base]
	DEC	R0
	CJNE	R0,#ISTACK-1,??0

	INC	DPTR
	MOVX	A,@DPTR
	MOV	SP,A		; SP (+)
	MOV	R0,A


	MOV	R0,#AXPH
??1:	INC	DPTR
	MOVX	A,@DPTR
	MOV	@R0,A		; R7, R6, R5, R4, R3, R2, R1
	DJNZ	R0,??1

	INC	DPTR
	MOVX	A,@DPTR
	MOV	B,A		; B
	INC	DPTR
	MOVX	A,@DPTR
	MOV	P2,A		; P2
	INC	DPTR
	MOVX	A,@DPTR
	MOV	R0,A		; R0
	INC	DPTR
	MOVX	A,@DPTR
	MOV	PSW,A		; PSW
	INC	DPTR
	MOVX	A,@DPTR		; ACC
	POP	DPH
	POP	DPL
	;POP	IE
	RET


_VSaveStack:
	MOV	R0,SP
	MOV	R2,A
	INC	DPTR
	MOV	A,@R0
	MOVX	@DPTR,A
	DEC	R0
	CJNE	R0,#ISTACK-1,??
	MOV	SP,R0
	RET

;F: Mem-PUSH sejumlah IDATA ke xstack (POP IDATA -> PUSH xstack)
_VPUSHN:
	MOV	B,A
	ADD	A,R0
	MOV	R0,A
	MOV	DPTR,#XSTACK
	MOVX	A,@DPTR
	ADD	A,B
	MOVX	@DPTR,A			; XSP <- XSP+N
___Vpushn:
	DEC	R0
	MOV	A,@R0
	MOVX	@DPTR,A
	DEC	DPL
	DJNZ	B,___Vpushn
	RET

;F: Mem-POP sejumlah data di xstack ke IDATA (POP xstack -> PUSH IDATA)
_VPOPN:
	MOV	B,A
	MOV	DPTR,#XSTACK
	MOVX	A,@DPTR
	MOV	DPL,A
___Vpopn:
	MOVX	A,@DPTR
	DEC	DPL
	INC	R0
	MOV	@R0,A
	DJNZ	B,___Vpopn
	MOV	A,DPL
	MOV	DPTR,#XSTACK
	MOVX	@DPTR,A			; XSP <- XSP-N
	RET

END
; OK, BUT REG DAN STACK BERADA PADA 1 ALOKASI YG SAMA
Pause:
	PUSH	DPL
	PUSH	DPH
	PUSH	ACC
	PUSH	PSW
	PUSH	AR0

	MOV	DPTR,#0
	MOV	A,XSPL
	MOVX	@DPTR,A
	MOV	R0,A
	MOV	A,XSPH
	INC	DPTR
	MOVX	@DPTR,A
	MOV	DPL,R0
	MOV	DPH,A

	MOV	A,SP
	ADD	A,#-3
	MOV	R0,A
	INC	DPTR
	MOVX	@DPTR,A

?P0:	MOV	A,@R0		; (IE?), DPH, DPL, PCH, PCL, ISTACK[top...base]
	DEC	R0
	INC	DPTR
	MOVX	@DPTR,A
	CJNE	R0,#ISTACK-1,?P0

	MOV	R0,#AXPH
?P1:	MOV	A,@R0		; R7, R6, R5, R4, R3, R2, R1
	INC	DPTR
	MOVX	@DPTR,A
	DJNZ	R0,?P1

	MOV	A,B		; B
	INC	DPTR
	MOVX	@DPTR,A
	MOV	A,P2		; P2
	INC	DPTR
	MOVX	@DPTR,A
	POP	ACC		; R0
	INC	DPTR
	MOVX	@DPTR,A
	POP	ACC		; PSW
	INC	DPTR
	MOVX	@DPTR,A
	POP	ACC		; ACC
	INC	DPTR
	MOVX	@DPTR,A

	MOV	DPTR,#0
Resume:
	;MOV	DPTR,#TD_XSP
	MOVX	A,@DPTR
	MOV	XSPL,A		; XSPL
	INC	DPTR
	MOVX	A,@DPTR
	MOV	XSPH,A		; XSPH
	MOV	DPH,A
	MOV	DPL,XSPL

	INC	DPTR
	MOVX	A,@DPTR
	MOV	SP,A		; SP (+)
	MOV	R0,A

??0:	INC	DPTR
	MOVX	A,@DPTR
	MOV	@R0,A		; (IE?), DPH, DPL, PCH, PCL, ISTACK[top...base]
	DEC	R0
	CJNE	R0,#ISTACK-1,??0

	MOV	R0,#AXPH
??1:	INC	DPTR
	MOVX	A,@DPTR
	MOV	@R0,A		; R7, R6, R5, R4, R3, R2, R1
	DJNZ	R0,??1

	INC	DPTR
	MOVX	A,@DPTR
	MOV	B,A		; B
	INC	DPTR
	MOVX	A,@DPTR
	MOV	P2,A		; P2
	INC	DPTR
	MOVX	A,@DPTR
	MOV	R0,A		; R0
	INC	DPTR
	MOVX	A,@DPTR
	MOV	PSW,A		; PSW
	INC	DPTR
	MOVX	A,@DPTR		; ACC
	POP	DPH
	POP	DPL
	;POP	IE
	RET

;0	0	0	0	0	0	0	0	0	0
_VGETPTR16:
	POP	DPL
	POP	DPL
	CLR	A
	MOVC	A,@A+DPTR
	PUSH	ACC

_VMEMPTR:
	MOV	DPL,?
	MOV	DPH,?
	LJMP	?

_VProcCall:
	ACALL	__VMOV_DPTR_XSP
	MOV	A,#2
	ACALL	__VADD_DPTR_A
	ACALL	__VXCH_DPTR_XSP
	INC	DPTR

	ACALL	__VMOV_XBP_DPTR

	XCH	A,XR0H
	MOV	A,DPL
	ADD	A,XBPL
	MOV	XR0L,A
	MOV	A,DPH
	ADD	A,XBPH
	XCH	A,XR0H


_VProcRret:

_VADD_DPTR_XBPTR:
	XCH	A,DPL
	ADD	A,XBPL
	XCH	A,DPL
	XCH	A,DPH
	ADD	A,XBPH
	XCH	A,DPH
	RET

_VADD_DPTR_XMPTR:
	XCH	A,DPL
	ADD	A,XMPL
	XCH	A,DPL
	XCH	A,DPH
	ADD	A,XMPH
	XCH	A,DPH
	RET

_VADD_DPTR_XSPTR:
	XCH	A,DPL
	ADD	A,XSPL
	XCH	A,DPL
	XCH	A,DPH
	ADD	A,XSPH
	XCH	A,DPH
	RET

_VREPPUSH_IDATA:
_VREPPOP_IDATA:
	MOV	A,EMUIRQ
	ANL	A,EMUIE
	ANL	SWIRQB,SWIEB
	
GantiIStack:
	POP	DPL
	POP	DPH
	CLR	A
	MOVC	@A+DPTR
	MOV	RCcS,A
	MOV	A,#1
	MOVC	@A+DPTR
	MOV	IDP,A
	MOV	A,#2
	MOVC	@A+DPTR
	MOV	IDP,A
	JC	?
	POP	AXPL
	POP	AXPH
?:
