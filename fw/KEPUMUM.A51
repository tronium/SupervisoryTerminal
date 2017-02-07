;21:58pm 04-07-1999 Subrtn Baca/Tulis sifat lebih ringkas

EXTRN	CODE	(JmlBitAktif, StrDes4D, DuaPangkatN, SwapPtr16, XChrCpy)
EXTRN	CODE	(ChrHex1D, ChrHex2D)
EXTRN	XDATA	(NV8_KP_Polar, NV8_KP_Baca, NV8_KP_Alarm, NV8_KP_ORespon)
EXTRN	XDATA	(NV8_KP_TRespon, V8_KP_Keluaran, NV_KP_Nama)
EXTRN	XDATA	(NVC_KP_Sifat)

$INCLUDE(STDIO.DEF)
$INCLUDE(PANTAU.DEF)

EXTRN	BIT	(F_KP_NotasiDes)
;PUBLIC	KP_GeserDigit
PUBLIC	KP_UbahDigit
PUBLIC	KP_StrNomor, KP_StrNomorNama, KP_BacaStrNama
PUBLIC	KP_TulisNama
;PUBLIC	KP_PtrNVNama

C_PT_TBwh	EQU	1
C_PT_TKi	EQU	2
C_PT_TKa	EQU	3


SegC_KPUmum	SEGMENT	CODE
		RSEG	SegC_KPUmum

;M: R0=tombol, A=PosDigit(0=MSDig)
;K: A dirubah, C:1=berganti kiri-kanan
;S: 2
KP_GeserDigit:
	CJNE	R0,#C_PT_TKa,$+3	; Tmbl < C_PT_TKa -> C=1(kiri)
	RLC	A
	ADD	A,#DTBL_KP_GeserDigDes - $ - 3	; C <- 0 !
	MOVC	A,@A+PC
	RRC	A
	RET
DTBL_KP_GeserDigDes:
;0=LSD	DB	6+1,2,0,4,2,6,4,0+1
	DB	2,6+1,4,0,6,2,0+1,4	; geser_kanan, geser_kiri
;DTBL_KP_GeserDigHex:
;0=LSD	DB	6+1,4,0,4,0,6,4,0+1
	DB	2,6+1,6,0,6,2,0+1,2	; posisi titik dilompati


;M: R0=tombol, A=PosDigit(0=MSDig), R2=3L, R3=8H
;K: F0: 1=NomBaru: R2,A=R3 dirubah, C=carry pada 8H ?
;       0=DigBaru: A (saja) dirubah
;S: 2+1
KP_UbahDigit:
	JB	F_KP_NotasiDes,__UD1
	ADD	A,#4			; = tabel dig_hex
__UD1:	CJNE	R0,#C_PT_Tki,$+3
	MOV	F0,C
	JNC	KP_GeserDigit		; <- F0 = 0
	CJNE	R0,#C_PT_TBwh,__UD2	; Tmbl < C_PT_TBwh -> C=1(atas)
__UD2:	RLC	A
	RL	A
	PUSH	ACC
	ADD	A,#DTBL_KP_UbahDigDes - $ - 3 + 0
	MOVC	A,@A+PC
	;XCH	A,R2
	;ORL	A,#NOT 7
	ADD	A,R2
	MOV	C,ACC.3				; carry 3-BIT
	ANL	A,#7				; 3-BIT saja
	MOV	R2,A
	POP	ACC
	PUSH	PSW
	ADD	A,#DTBL_KP_UbahDigDes - $ - 3 - 2 + 1
	POP	PSW
	MOVC	A,@A+PC
	ADDC	A,R3
	MOV	R3,A
	RET					; RET: status C ?
DTBL_KP_UbahDigDes:	; 3Lo, 8Hi
	DB	(-1000) MOD 8, LOW ((-1000)/8)		; 0: -1000
	DB	1000 MOD 8, 1000/8			; 1: +1000
	DB	(-100) MOD 8, LOW ((-100)/8)		; 2: -100
	DB	100 MOD 8, 100/8			; 3: +100
	DB	(-10) MOD 8, LOW ((-10)/8)		; 4: -10
	DB	10 MOD 8, 10/8				; 5: +10
	DB	(-1) MOD 8, LOW ((-1)/8), 1, 0		; 6,7: -1, +1
;DTBL_KP_UbahDigHex:
	DB	(-128) MOD 8, LOW ((-128)/8)		; 0: -10H.0
	DB	128 MOD 8, 128/8			; 1: +10H.0 (step 128)
	DB	(-8) MOD 8, LOW ((-8)/8)		; 2: -01H.0
	DB	8 MOD 8, 8/8				; 3: +01H.0 (step 8)
	DB	0,0,0,0					; 4,5: diabaikan
	DB	(-1) MOD 8, LOW ((-1)/8), 1, 0		; 6,7: -0H.1, +0H.1

;M: R2=N3, R3=N8, DPTR=@XRAM
;K: DPTR=@EOS, (R2,R3)=BCD_Nom
;R: A,R0
KP_StrNomor:				; tot stack = 7(Des) atau 5(Hex)
	MOV	A,R3
	JNB	F_KP_NotasiDes,_KP_NomHex
	;MOV	R0,B
	MOV	B,#8
	MUL	AB
	XCH	A,R2
	ANL	A,#7
	ORL	A,R2
	MOV	R2,A
	MOV	R3,B
	;MOV	B,R0
	LJMP	StrDes4D		; <- stack: 7, RET: R0=4
_KP_NomHex:
	LCALL	ChrHex2D		; <- stack: 3
	MOV	A,#'.'
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,R2
	ANL	A,#7
	LCALL	ChrHex1D
	MOV	A,#EOS
	MOVX	@DPTR,A
	RET

;M: R2=N3, R3=8H, DPTR=@XRam
;R: A, R0, R2, R3, R4=N3, R5=N8, (R6:R7)=RetAddr
;K: DPTR=@EOS
;S: 7
KP_StrNomorNama:
	POP	ACC
	MOV	R7,A
	POP	ACC
	MOV	R6,A

	MOV	A,R2
	MOV	R4,A
	MOV	A,R3
	MOV	R5,A
	LCALL	KP_StrNomor		; <- S: 7(D) / 5(H)
	MOV	A,#' '
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,R4
	MOV	R2,A
	MOV	A,R5
	MOV	R3,A

	MOV	A,R6
	PUSH	ACC
	MOV	A,R7
	PUSH	ACC

; Mendapatkan Str Nama masukan KEP
; M: R2=N3, R3=N8, DPTR=Tujuan
; K: DPTR=@EOS
; R: A, R0(=0), R6, R7
KP_BacaStrNama:				; tot stack = 6 (bernama)
	CJNE	R3,#C_KP_Bernama_8H,_KP_TanpaNama
	MOV	A,R2
	ANL	A,#7
	CJNE	A,#C_KP_Bernama_3L,$+3
_KP_TanpaNama:
	JC	_KP_Bernama			; lebih kecil = bernama (C=1)
	MOV	R0,#C_KP_PjgNama
	MOV	A,#'*'
__KNA:	MOVX	@DPTR,A
	INC	DPTR
	DJNZ	R0,__KNA
	MOV	A,#EOS
	MOVX	@DPTR,A
__KTN2:	MOV	A,#KJ_Ditolak
	RET

EXTRN	NUMBER	(KJ_Ditolak)

_KP_Bernama:
	LCALL	SwapPtr16
	;PUSH	DPL
	;PUSH	DPH
	LCALL	KP_PtrNVNama			; <- stack: 3
	MOV	R0,#C_KP_PjgNama
	LCALL	XChrCpy				; <- stack: 4
	;POP	DPH
	;POP	DPL
	LCALL	SwapPtr16
	MOV	A,#EOS
	MOVX	@DPTR,A
	CLR	A
	RET

; M: R2=N3 R3=N8, (R6,R7)=sumber
; K: @DPTR[0..C_KP_PjgNama]=Nama, (R6,R7)+
; R: R0
KP_TulisNama:
	CJNE	R3,#C_KP_Bernama_8H,__KTN1
	MOV	A,R2
	ANL	A,#7
	CJNE	A,#C_KP_Bernama_3L,$+3
__KTN1:	JNC	__KTN2				; CF: 1=bernama
	LCALL	KP_PtrNVNama
	LCALL	SwapPtr16
	MOV	R0,#C_KP_PjgNama
	LCALL	XChrCpy
	CLR	A
	RET

; M: R2=N3 R3=N8
; K: DPTR=@Nama[0]
; Proses: (3_L*PjgNama) + Ptr16Dasar + (PjgNama*8*8_H)
KP_PtrNVNama:
	MOV	A,R2
	ANL	A,#7			; A = 3L
	MOV	DPL,R3
	PUSH	B
	MOV	B,#C_KP_PjgNama
	MUL	AB
	ADD	A,#LOW  NV_KP_Nama
	MOV	DPH,A			; DPH <- lo sementara
;+
	MOV	A,#C_KP_PjgNama	; BUG ?: max = 31 chr !!!
	SWAP	A			; =
	RR	A			; = 3x RL
;+
	XCH	A,B			; B <- PjgNama*8
	ADDC	A,#HIGH NV_KP_Nama
	XCH	A,DPL			; DPL <- hi sementara, A <- 8H
	MUL	AB
	ADD	A,DPH
	XCH	A,DPL			; hi-lo dipulihkan
	ADDC	A,B
	MOV	DPH,A
	POP	B
	RET				;CF = 0

;CF_KP_PakBaca		EQU	0
;CF_KP_PakPolar		EQU	1
;CF_KP_PakAlarm		EQU	2
;CF_KP_PakORespon	EQU	3
;CF_KP_PakTRespon	EQU	4
;CF_KP_PakKeluaran	EQU	5

PUBLIC	KP_BacaSifat

; M: R2=N3, R3=N8
; K: A=0, R4=Hasil PakSifat
; R: B(=PosBit), DPL(=N8), DPH

KP_BacaSifat:
	MOV	A,R2
	MOV	DPL,R3
;KP_BacaPakSifat:
	LCALL	DuaPangkatN
	MOV	B,A
	MOV	R4,#0

	MOV	A,#_N_KBS_Seg
__KBS0:
	PUSH	ACC
	MOVC	A,@A+PC
__KBS1:
	MOV	DPH,A
	MOVX	A,@DPTR
	ANL	A,B
	CJNE	A,B,$+3			; BIT <> 0 (C=0) ?
	CPL	C
	MOV	A,R4
	RLC	A
	MOV	R4,A

	POP	ACC
	INC	A
	CJNE	A,#_N_KBS_Seg+_N_KBTS_Jml,__KBS0
	CLR	A
	RET

PUBLIC	KP_TulisSifat

; F: Simpan PakSifat
; M: R2=N3, R3=N8, R4=PakSifat
; K: A=0
; R: R4, B(=posbit), DPTR(=V8_KP_Keluaran)

KP_TulisSifat:
	MOV	A,R2
	MOV	DPL,R3
;KP_TulisPakSifat:
	MOV	B,#0
	LCALL	DuaPangkatN
	MOV	R3,A

	MOV	A,#_N_KBTS_Jml
__KTS0:
	PUSH	ACC
	ADD	A,#_N_KTS_Seg-1
	MOVC	A,@A+PC			; dari almt hi ke lo
__KTS1:
	MOV	DPH,A
	MOV	A,R4
	RRC	A
	MOV	R4,A
	MOVX	A,@DPTR
	XRL	B,A
	ORL	A,R3			; = set
	JC	__KTS2
	XRL	A,R3			; = reset
__KTS2:	MOVX	@DPTR,A
	XRL	B,A

	POP	ACC
	CJNE	A,#2,__KTS3

	PUSH	DPL
	MOV	DPTR,#NVC_KP_Sifat
	MOVX	A,@DPTR
	XRL	A,B
	MOVX	@DPTR,A			; simpan paritas baru
	POP	DPL

	MOV	A,#2
__KTS3:	DJNZ	ACC,__KTS0
	MOV	R3,DPL
	RET

	_N_KBS_Seg	EQU	$-__KBS1
	_N_KTS_Seg	EQU	$-__KTS1
ATBL_KP_Sifat:
	DB	HIGH V8_KP_Keluaran
	DB	HIGH NV8_KP_TRespon
	DB	HIGH NV8_KP_ORespon
	DB	HIGH NV8_KP_Alarm
	DB	HIGH NV8_KP_Polar
	DB	HIGH NV8_KP_Baca

_N_KBTS_Jml	EQU	$ - ATBL_KP_Sifat

	END

DTBL_KP_UbahDigDes:	; Lo, Hi
	DB	8-(1000 MOD 8), NOT (1000/8)		; 0: -1000
	DB	1000 MOD 8, 1000/8			; 1: +1000
	DB	8-(100 MOD 8), NOT (100/8)		; 2: -100
	DB	100 MOD 8, 100/8			; 3: +100
	DB	8-(10 MOD 8), NOT (10/8)		; 4: -10
	DB	10 MOD 8, 10/8				; 5: +10
	DB	7, NOT 0,1,0				; 6,7: -1, +1
;DTBL_KP_UbahDigHex:
	DB	8-(128 MOD 8), NOT (128/8)		; 0: -10H.0
	DB	128 MOD 8, 128/8			; 1: +10H.0 (step 128)
	DB	8-(8 MOD 8), NOT (8/8)			; 2: -01H.0
	DB	8 MOD 8, 8/8				; 3: +01H.0 (step 8)
	DB	0,0,0,0					; 4,5: diabaikan
	DB	7, NOT 0, 1, 0				; 6,7: -0H.1, +0H.1

