$INCLUDE(STDIO.DEF)
$INCLUDE(OS.DEF)

PUBLIC	JmlBitAktif
;PUBLIC	Bin16KeBCD
PUBLIC	StrDes4D, ChrHex2D, ChrHex1D, ChrDes12bNZ
;PUBLIC	ChrDes12b, ChrDes12bZL
;StrDes5D:
;ChrDes16b:
PUBLIC	BCDKeByte, ByteKeBCD, ByteKeHexAsc
;ByteKeDesAsc
;	BCD2dKeHex??
;ByteKeDes:
;CariNonZ:
;PerbaikiZLead:
;MundurDptr:
PUBLIC	DuaPangkatN
PUBLIC	XStrTambahChr
;XStrSisipSpasi
;XStrSisipCopy:
;XStrSisipChr:
PUBLIC	XChrInsert, XChrDelKepala
;PUBLIC	XChrDelBuntut

SegC_Umum	SEGMENT	CODE
		RSEG	SegC_Umum

;;+ F: Menyisipkan spasi
;XStrSisipSpasi:
;	MOV	R0,#' '
;	SJMP	XStrSisipChr

;;+ F: Menyisip-gandakan chr pada @DPTR ke @DPTR+1 (tdk periksa @DPTR=@EOS !)
;XStrSisipCopy:
;	MOVX	A,@DPTR
;	MOV	R0,A
	
;;=============================================================================
;;F: Menyisipkan 1 Chr (R0) pada @DPTR, sekaligus mengeser (naik) str pada @DPTR
;;   _TANPA_ mengubah ukuran STR
;;M: R0=Chr sisip, DPTR=@XStr
;;K: R0=Chr terbuang, A=EOS DPTR=@EOS (yang _TIDAK_ digeser)
;;============================================================================
;__xss:	XCH	A,R0
;	MOVX	@DPTR,A
;	INC	DPTR
;XStrSisipChr:
;	MOVX	A,@DPTR			; pertama: batal jika EOS
;	CJNE	A,#EOS,__xss
;	RET

;=============================================================================
;F: Menambahkan 1 Chr (R0) pada @DPTR, sekaligus mengeser (naik) str pada @DPTR
;   _DENGAN_ mengubah ukuran STR (+1)
;M: R0=Chr sisip, DPTR=@XStr
;K: R0=Chr yg ditimpa EOS, A=EOS, DPTR=@EOS (yang _TELAH_ digeser)
;=============================================================================
__xstc:	INC	DPTR
XStrTambahChr:
	MOVX	A,@DPTR
	XCH	A,R0
	MOVX	@DPTR,A
	CJNE	A,#EOS,__xstc
	RET

;F: Menghapus 1 XChr pada @DPTR(kanan) dgn menarik sejumlah (RCcL) XChr
;   kekiri (low); ( 1 ujung kiri ditimpa)
;M: DPTR=kiri
XChrDelKepala:
	XCH	A,DPL
	ADD	A,RCcL
	XCH	A,DPL
	JNC	XChrDelBuntut
	INC	DPH
;M: DPTR=kanan
XChrDelBuntut:					; @DPTR=buntut
	PUSH	B
	;MOV	B,A
	MOV	B,#' '
	INC	RCcL				; <- 1 chr_hapus diujung
__xcd1:	MOVX	A,@DPTR
	XCH	A,B
	MOVX	@DPTR,A
	MOV	A,DPL
	DEC	DPL
	JNZ	__xcd2
	DEC	DPH
__xcd2:	DJNZ	RCcL,__xcd1
	POP	B
	RET

;F: Menduplikasi 1 XChr pada @DPTR ke @DPTR+1 dgn mendorong sejumlah (RCcL) XChr
;   kekanan (high)
XChrInsert:
	PUSH	B
	MOVX	A,@DPTR
	MOV	B,A
	;MOV	B,#' '
	INC	RCcL
__xci:	MOVX	A,@DPTR
	XCH	A,B
	MOVX	@DPTR,A
	INC	DPTR
	DJNZ	RCcL,__xci
	POP	B
	RET

;;-------------------------------------------
;; subrutin konversi biner 8-BIT ke desimal
;; masukan:
;;	A=heksadesimal
;; keluaran
;;	A=ratusan, R1=puluhan, R0=satuan
;;-------------------------------------------
;
;ByteKeDes:
;	MOV	R1,B			;R1 <- org_B
;	MOV	B,#10
;	DIV	AB
;	MOV	R0,B			;R0 <- 1an
;	MOV	B,#10
;	DIV	AB
;	XCH	A,R1			;A <- org_B, R1 <- 100an
;	XCH	A,B			;A <- 10an, B <- org_B
;	XCH	A,R1			;A <- 100an, R1 <- 10an
;	RET				;CF=0
;
;;--------------------------------------------------------
;; subrutin konversi biner 8-BIT ke desimal dalam ASCII
;; masukan:
;;	A=bin 8-BIT
;; keluaran
;;	A=ratusan, R1=puluhan, R0=satuan
;;---------------------------------------------------------
;
;ByteKeDesAsc:
;	MOV	R0,B			;R0 <- org_B
;	MOV	B,#10
;	DIV	AB
;	MOV	R1,B			;R1 <- B1an
;	MOV	B,#10
;	DIV	AB
;	ADD	A,#'0'
;	XCH	A,R0			;A <- org_B, R0 <- A100an
;	XCH	A,B			;A <- B10an, B <- org_B
;	ADD	A,#'0'
;	XCH	A,R1			;A <- B1an, R1 <- A10an
;	ADD	A,#'0'
;	XCH	A,R0			;A <- A100an, R0 <- A1an
;	RET				;CF=0

;---------------------------------------------------------------
; subrutin konversi biner 8-BIT ke heksadesimal dala ASCII
; masukan:
;	A=bin 8-BIT
; keluaran
;	A=nibel tinggi, R0=nibel rendah
;--------------------------------------------------------------

ByteKeHexAsc:
	MOV	R0,A
	ACALL	_b2ha_1
	XCH	A,R0
	SWAP	A
_b2ha_1:
	ANL	A,#0Fh
	ADD	A,#'0'
	CJNE	A,#'9'+1,_b2ha_2		; cf=1 '<', cf=0 '>='
_b2ha_2:
	JC	_b2ha_3
	ADD	A,#'A'-'9'-1
_b2ha_3:
	RET

;----------------------------------------------------------------
; Subrutin konversi bilangan biner 16-BIT ke BCD 5(6?)-digit
;	Hasil = SIGMA { BIT[n] * 2^n }
;	Bin[n] = nilai BIT ke-n (0 atau 1)
;	n = 0..15
; M: R2= 8-lo, R3= 8-hi
; K: R2= satuan & puluhan, R3= ratusan & ribuan, A= puluh_ribuan
; R: bendera, R0(=SP), B?
;-----------------------------------------------------------------
;_RLO		EQU	R1
;_RHI		EQU	R2
;_R10		EQU	R3
;_R1000		EQU	R4
;_R10000	EQU	R5

Bin16KeBCD:				; tot stack = 6
;	MOV	A,R0
;	PUSH	ACC
	;PUSH	B
	MOV	B,#16			;= biner 16-BIT
	CLR	A
	PUSH	ACC
	XCH	A,R3
	PUSH	ACC
	CLR	A
	XCH	A,R2
	PUSH	ACC
_B16B_sigma:
	MOV	R0,SP
	MOV	A,@R0			; 8L
	RLC	A
	MOV	@R0,A
	DEC	R0
	MOV	A,@R0			; 8H
	RLC	A			; cy <- BIT[n] ; msb
	MOV	@R0,A
	MOV	A,R2			; satuan & puluhan dalam bcd
	ADDC	A,R2			; x2 + Bin[n]
	DA	A
	MOV	R2,A
	MOV	A,R3			; ratusan & ribuan dalam bcd
	ADDC	A,R3			; x2 + limpahan_puluhan
	DA	A
	MOV	R3,A
	DEC	R0
	MOV	A,@R0			; puluh_ribuan dalam (pasti) bcd
	ADDC	A,@R0			; x2 + limpahan_ribuan
	MOV	@R0,A
	DJNZ	B,_B16B_sigma
	DEC	R0
	MOV	SP,R0
	;POP	B
;	XCH	A,@R0
;	MOV	R0,A
;	POP	ACC
	RET

;StrDes4D:				; tot stack = 10
	;ACALL	ChrDes12bZL		; <- stack: 8
	;MOV	A,#EOS
	;MOVX	@DPTR,A
	;RET

StrDes4D:				; tot stack = 8/7?
	ACALL	Bin16KeBCD		; <- stack: 6/5?
	CLR	F0
	;MOV	R0,#0
	ACALL	_Chr4Dig
	MOV	A,#EOS
	MOVX	@DPTR,A
	RET

;StrDes5D:
;	ACALL	ChrDes12bZL
;	MOV	A,#EOS
;	MOVX	@DPTR,A
;	RET

; F: Menuliskan Karakter Angka pada XRAM
; M: F0 -> 0 = Zero Leading, 1 = Non Zero Leading
;    R2, R3 = 16 BIT
; K: F0:1=Null, RCcL = jumlah chr, DPTR+
;    R2 = bcd[01], R3 = bcd[23]

ChrDes12bNZ:
	SETB	F0
;	SJMP	ChrDes12b
;ChrDes12bZL:
;	CLR	F0
;ChrDes12b:				; tot stack = 7 (maks)
	ACALL	Bin16KeBCD		; <- stack: 5
;	SJMP	_Chr4Dig
;ChrDes16b:
;	ACALL	Bin16KeBCD
;	MOV	RCcL,#0
;	ACALL	_Chr1Dig		; 16bit -> 5 digit desimal
_Chr4Dig:
	MOV	RCcL,#0
	MOV	A,R3
	ACALL	_Chr2Dig
	MOV	A,R2
	ACALL	_Chr2Dig
	JZ	__CD2			; Pastikan Digit Satuan tidak null
	RET
_Chr2Dig:
	PUSH	ACC
	SWAP	A
	ACALL	_Chr1Dig
	POP	ACC
_Chr1Dig:
	ANL	A,#0FH
	JNB	F0,__CD2
	JNZ	__CD1
	RET
__CD1:	CLR	F0
__CD2:	ADD	A,#'0'
	MOVX	@DPTR,A
	INC	DPTR
	INC	RCcL
	RET

;CariNonZ:
;	MOVX	A,@DPTR
;	CJNE	A,#'0',_XSNZ
;	INC	DPTR
;	SJMP	CariNonZ

;PerbaikiZLead:
;	MOVX	A,@DPTR
;	CJNE	A,#'0',_XSNZ
;	MOV	A,#' '
;	MOVX	@DPTR,A
;	INC	DPTR
;	SJMP	PerbaikiZLead
;_XSNZ:	RET

ChrHex2D:
	PUSH	ACC
	SWAP	A
	ACALL	ChrHex1D
	POP	ACC
ChrHex1D:
	ANL	A,#0FH
	ADD	A,#'0'
	CJNE	A,#'9'+1,$+3
	JC	__CHex
	ADD	A,#'A'-'9'-1
__CHex:	MOVX	@DPTR,A
	INC	DPTR
	RET

BCDKeByte:
	PUSH	B
	PUSH	ACC
	SWAP	A
	ANL	A,#0Fh
	MOV	B,#10
	MUL	AB
	POP	B
	ANL	B,#0Fh
	ADD	A,B			;hasil = n_tinggi*10 + n_rendah
	POP	B
	RET				;CF=0

ByteKeBCD:				;masukan maksimum = 99d = 63h
	PUSH	B
	MOV	B,#10
	DIV	AB
	SWAP	A
	ADD	A,B			;hasil : n_tinggi = HEX/10
	POP	B			;	 n_rendah = HEX MOD 10
	RET				;CF=0

JmlBitAktif:
	PUSH	B
	MOV	B,A			;= tempat sementara
	ANL	A,#0Fh
	ADD	A,#DTBL_JmlBitAktif - $ - 3
	MOVC	A,@A+pc
	XCH	A,B
	SWAP	A
	ANL	A,#0Fh
	ADD	A,#DTBL_JmlBitAktif - $ - 3
	MOVC	A,@A+pc
	ADD	A,B
	POP	B
	RET				;cf=0
DTBL_JmlBitAktif:
	DB	0,1,1,2		;0000B,0001B,0010B,0011B
	DB	1,2,2,3		;0100B,0101B,0110B,0111B
	DB	1,2,2,3		;1000B,1001B,1010B,1011B
	DB	2,3,3,4		;1100B,0101B,0110B,0111B

DuaPangkatN:
	ANL	A,#7				; N = A MOD 8 (0..7)
	ADD	A,#DTBL_2PangkatN - $ - 3	; CF <- 0
	MOVC	A,@A+pc
	RET
DTBL_2PangkatN:
	DB	1,2,4,8,16,32,64,128		; = 2^N

	END

PUBLIC	CariCStrEOS

: M: A=Jml, DPTR=@XRAM
CariCStrEOS:
	JZ	__CSE2
	MOV	RCcL,A
__CSE1:	CLR	A
	MOVC	A,@A+DPTR
	INC	DPTR
	CJNE	A,#EOS,__CSE1
	DJNZ	RCcL,__CSE1
__CSE2:	RET

;M: A=8H, B=3L, RCcL=N
;K: B=((H*8)+L) MOD N
;Proses: ((H*8)+L) MOD N = [{(H MOD N)*8}+L] MOD N
;Syarat: N \< 32 ; ((N-1)*8)+7 < 256
MKS_NoSimpulModN:
	PUSH	B
	MOV	B,RCcL
	DIV	AB		; B <- 8_Hi MOD N, Maks = N-1
	MOV	A,#8		; 8=2^3
	MUL	AB		; A <- B*8
	POP	B
	ANL	B,#111B
	ADD	A,B		; A <- A + 3_Lo
	MOV	B,RCcL
	DIV	AB		; B <- A MOD N
	RET
