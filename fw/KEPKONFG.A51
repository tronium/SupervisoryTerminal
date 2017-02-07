PUBLIC	MLihatKfgKEP, MUbahKfgKEP, _MLKP_SwapReg, _MLKP_SwapReg_Ret

$INCLUDE(PANTAU.DEF)
$INCLUDE(STDIO.DEF)

EXTRN	CODE	(KP_StrNomor, KP_TulisNama, KP_TulisSifat)
EXTRN	CODE	(KP_UbahDigit)
EXTRN	CODE	(KP_BacaStrNama, KP_BacaSifat)

EXTRN	CODE	(LCD_SetXY, LCD_KursorBlok, LCD_TulisChr)
EXTRN	CODE	(LCD_KursorGaris, LCD_RstKdpOn)
EXTRN	CODE	(LCD_TulisCStr, LCD_TlsCStrIni)
EXTRN	CODE	(LCD_TulisXStr);, LCD_KedipXStr)
EXTRN	CODE	(LCD_TlsXYXStr);, LCD_KdpXYXStr)
EXTRN	CODE	(XChrCpy, CStrCpy, XStrCpy, __VADD_DPTR_A, DuaPangkatN)
EXTRN	CODE	(SwapIStack)
EXTRN	CODE	(XChrInsert, XChrDelKepala)
EXTRN	CODE	(MgrTugas_OSP)
EXTRN	CODE	(SwapPtr16)

EXTRN	XDATA	(NVC_KP_Sifat)
EXTRN	BIT	(F_LCD_FlipKedip, F_LCD_PosKedip)

;;C_PT_Tdk	EQU	4

;F1	BIT	PSW.1

ISTACK		SEGMENT	DATA
		RSEG	ISTACK
RS_MKK_3L	EQU	0
RS_MKK_8H	EQU	1
RS_MKK_Opsi	EQU	2
RT_MKK_Digit	EQU	3
RT_MKK_Sifat	EQU	4
;RT_MUKK_7an_Dg	EQU	5
;RT_MUKK_7an_3L	EQU	6
;RT_MUKK_7an_8H	EQU	7

C_MKK_JmlRS	EQU	3
C_MKK_JmlRT	EQU	2

SegV16		SEGMENT	XDATA
		RSEG	SegV16

RN_MKK:		DS	C_MKK_JmlRS
CA_MKK_RNAwal	EQU	RN_MKK

SegV_Umum	SEGMENT	XDATA
		RSEG	SegV_Umum
PU_MKK_OfsPakSifat	EQU	0
PU_MKK_PtrStrNomor	EQU	1
PU_MSKP_PtrStr7an	EQU	1+5
PU_MKK_PtrStrKfg	EQU	1+5+5
PU_MKK_OfsChrNama	EQU	1+5+5+2
PU_MKK_OfsStrSifat	EQU	1+5+5+2+C_KP_PjgNama+1


SegC_MKKonfig	SEGMENT	CODE
		RSEG	SegC_MKKonfig

MLihatKfgKEP:
	SETB	C
	LCALL	_MLKP_SwapReg
	MOV	ISTACK+RT_MKK_Digit,#3
_MLKK_Berubah:
	LCALL	MKK_KfgSimpul
_MLKK_Redraw:
	LCALL	_MKK_Redraw
_MLKK_PosKsr:
	MOV	A,#XY_MKK_Nomor
	ADD	A,ISTACK+RT_MKK_Digit
	LCALL	LCD_SetXY
_MLKK_Idle:
	LCALL	MgrTugas_OSP
	SJMP	_MLKK_Redraw
	SJMP	_MLKK_Idle
	SJMP	_MLKK_TArah
	SJMP	_MLKP_SwapReg_Ret		; TTdk
_MLKK_TYa:
	JB	F0,_MLKK_2Ya
;	LCALL	MUbahKfgKEP
	LCALL	_MUKK_CekPosOpsi
	JNB	F0,_MLKK_Berubah
_MLKP_SwapReg_Ret:
	CLR	C

RCcS	EQU	R4
RCcT	EQU	R5

_MLKP_SwapReg:
	MOV	RCcS,#C_MKK_JmlRS
	MOV	RCcT,#C_MKK_JmlRT
	MOV	DPTR,#CA_MKK_RNAwal
	LJMP	SwapIStack			; ...dan keluar

_MLKK_2Ya:
;cetak konfig
	SJMP	_MLKP_SwapReg_Ret

_MLKK_TArah:
	MOV	A,ISTACK+RT_MKK_Digit
	MOV	R2,ISTACK+RS_MKK_3L
	MOV	R3,ISTACK+RS_MKK_8H
	LCALL	KP_UbahDigit
	JB	F0,_MLKK_Nombaru
	MOV	ISTACK+RT_MKK_Digit,A
	SJMP	_MLKK_PosKsr
_MLKK_Nombaru:
	MOV	ISTACK+RS_MKK_3L,R2
	MOV	ISTACK+RS_MKK_8H,R3
	LCALL	MKK_KfgSimpul
	LCALL	_MKK_CtkNomBaru
	SJMP	_MLKK_PosKsr

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
SegC_MUKP	SEGMENT	CODE
		RSEG	SegC_MUKP

MUbahKfgKEP:
	LCALL	MKK_KfgSimpul
_MUKK_CekPosOpsi:
	LCALL	_MKK_CekBernama
	JC	_MUKK_Redraw			;CF: 1=bernama
	MOV	A,ISTACK+RS_MKK_Opsi
	CJNE	A,#C_KP_PjgNama,$+3
	JNC	_MUKK_Redraw			;CF: 0=Diluar XY 'nama'
	MOV	ISTACK+RS_MKK_Opsi,#C_KP_PjgNama
_MUKK_Redraw:
	LCALL	_MKK_Redraw
_MUKK_PosXY:
	MOV	A,ISTACK+RS_MKK_Opsi
	CJNE	A,#C_KP_PjgNama,$+3
	JC	__XYB
	SUBB	A,#C_KP_PjgNama		; = nom sifat
	RL	A
	RL	A				; persifat= 3+1 chr
	ADD	A,#C_KP_PjgNama+1+2		; = isi sifat
__XYB:	ADD	A,#XY_MKK_Kfg+2			; = isi nama
	LCALL	LCD_SetXY			; kursor garis selama Tkedip_on
;+
	LCALL	LCD_KursorGaris
;+
	LCALL	LCD_RstKdpOn
_MUKK_Idle:
;_MUKK_CekKursor:
	JNB	F_LCD_FlipKedip,_MUKK_MT
	JNB	F_LCD_PosKedip,_MUKK_MT
	CLR	F_LCD_PosKedip
	LCALL	LCD_KursorBlok			; super idle -> blok kedip
_MUKK_MT:
	LCALL	MgrTugas_OSP
	SJMP	_MUKK_Redraw
	SJMP	_MUKK_Idle
	SJMP	_MUKK_TArah
	SJMP	_MUKK_TTdk
	;SJMP	_MUKK_TYa
_MUKK_Simpan:
	MOV	R2,ISTACK+RS_MKK_3L
	MOV	R3,ISTACK+RS_MKK_8H
	LCALL	MUKK_TulisKfg
;	JNB	F0,_MUKK_TTdk
;	LCALL	MSalinKfg
;	JNB	F0,MUbahKfgKEP	; kembali lagi (=0) ?
_MUKK_TTdk:
	RET

C_PT_Tki	EQU	2

_MUKK_TArah:
	MOV	A,ISTACK+RS_MKK_Opsi
	CJNE	R0,#C_PT_Tki,$+3
	JC	_MUKK_Ubah

;_MUKK_Geser:
	XCH	A,R0
	RRC	A
	CLR	A
	ADDC	A,#0FFH			; Gj(+1): A=0, C=1; Gn(-1): A=-1, C=0
	ADDC	A,R0
	CJNE	A,#0FFH,__MUG0
	SJMP	__MUG2					; <- C=0
__MUG0:	CJNE	A,#C_KP_PjgNama+C_KP_JmlSifat,__MUG1
	CLR	A					; ka-ke-ki
__MUG1:	XCH	A,R0
	LCALL	_MKK_CekBernama
	JC	__MUG4					;CF: 1= bernama
	CJNE	R0,#C_KP_PjgNama-1,__MUG3
__MUG2:	MOV	R0,#C_KP_PjgNama+C_KP_JmlSifat-1	; ki-ke-ka
__MUG3:	JNC	__MUG4					;CF: 0= diluar 'nama'-1
	MOV	R0,#C_KP_PjgNama			; ka-ke-(nama+1)
__MUG4:	MOV	ISTACK+RS_MKK_Opsi,R0
_MUKK_XYBaru:
	SJMP	_MUKK_PosXY

_MUKK_Ubah:
	CJNE	A,#C_KP_PjgNama,$+3
	JC	_MUKK_Nama
;_MUKK_Sifat:
	SUBB	A,#C_KP_PjgNama
	LCALL	DuaPangkatN
	XRL	ISTACK+RT_MKK_Sifat,A
	MOV	R4,ISTACK+RT_MKK_Sifat
	MOV	DPTR,#SegV_Umum+PU_MKK_OfsStrSifat
	LCALL	KP_StrSifat
_MUKK_KfgBaru:
	LCALL	_MKK_CtkKfg
	SJMP	_MUKK_XYBaru

_MUKK_Nama:
	MOV	DPTR,#SegV_Umum+PU_MKK_OfsChrNama
	LCALL	__VADD_DPTR_A
	JB	F0,_MUKK_Insert
	MOVX	A,@DPTR
	XCH	A,R0
	RRC	A
	SUBB	A,ACC			; Gj(-1): A=-1, C=1; Gn(+1): A=0, C=0
	CPL	C			; Gj(-1): A=-1, C=0; Gn(+1): A=0, C=1
	ADDC	A,R0
	ANL	A,#7FH
	CJNE	A,#' '- 1,__MUN1
	;MOV	A,#' '
	MOV	A,#7FH
__MUN1:	JNC	__MUN2	
	;MOV	A,#7FH
	MOV	A,#' '
__MUN2:	MOVX	@DPTR,A
	SJMP	_MUKK_KfgBaru

_MUKK_Insert:
	;MOV	DPTR,#SegV_Umum+PU_MKK_OfsChrNama
	;LCALL	__VADD_DPTR_A
	MOV	A,ISTACK+RS_MKK_Opsi
	CPL	A
	ADD	A,#C_KP_PjgNama
	XCH	A,R0
	JB	ACC.0,_MUKK_Delete		; ganjil = del
	LCALL	XChrInsert
	SJMP	_MUKK_KfgBaru
_MUKK_Delete:
	LCALL	XChrDelKepala
	SJMP	_MUKK_KfgBaru

;=BUFFER KFG HARUS SUDAH DIISI OLEH PEMANGGIL
;MSalinKfg:
;	MOV	ISTACK+RT_MUKK_7an_Dg,#3
;	MOV	ISTACK+RT_MUKK_7an_3L,R2	;ISTACK+RS_MKK_3L
;	MOV	ISTACK+RT_MUKK_7an_8H,R3	;ISTACK+RS_MKK_8H
;_MSKP_Redraw:
;	LCALL	LCD_TlsCStrIni
;	DB	FF,'Salin Konfigurasi Simpul No 0000 ke',EOS
;XY_MSKP_Asal		EQU	28
;XY_MSKP_7an		EQU	36
;	MOV	A,#XY_MSKP_Asal
;	LCALL	_MKK_CtkNomor
;	MOV	R2,ISTACK+RT_MUKK_7an_3L
;	MOV	R3,ISTACK+RT_MUKK_7an_8H
;_MSKP_Nom7an:
;	MOV	DPTR,#SegV_Umum+PU_MSKP_PtrStr7an
;	LCALL	KP_StrNomor
;	MOV	DPTR,#SegV_Umum+PU_MSKP_PtrStr7an
;	MOV	A,#XY_MSKP_7an
;	LCALL	LCD_TlsXYXStr
;_MSKP_XYDig:
;	MOV	A,#XY_MSKP_7an
;	ADD	A,ISTACK+RT_MUKK_7an_Dg
;	LCALL	LCD_SetXY
;_MSKP_Idle:
;	LCALL	MgrTugas_OSP
;	SJMP	_MSKP_Redraw
;	SJMP	_MSKP_Idle
;	SJMP	_MSKP_TArah
;_MSKP_TTdk:
;	RET
;	NOP
;_MSKP_TYa:
;	MOV	R2,ISTACK+RT_MUKK_7an_3L
;	MOV	R3,ISTACK+RT_MUKK_7an_8H
;	JNB	F0,MUKK_TulisKfg		;Tujuan Menjadi Sumber (=1) ?
;	MOV	ISTACK+RS_MKK_3L,R2
;	MOV	ISTACK+RS_MKK_8H,R3
;	CLR	F0

;M: R2=N3, R3=N8
;R: A=N3
MUKK_TulisKfg:
	MOV	R6,#LOW  SegV_Umum+PU_MKK_OfsChrNama
	MOV	R7,#HIGH SegV_Umum+PU_MKK_OfsChrNama
	MOV	R4,ISTACK+RT_MKK_Sifat
	LCALL	KP_TulisSifat
	LJMP	KP_TulisNama

;_MSKP_TArah:
;	MOV	A,ISTACK+RT_MUKK_7an_Dg
;	MOV	R2,ISTACK+RT_MUKK_7an_3L
;	MOV	R3,ISTACK+RT_MUKK_7an_8H
;	LCALL	KP_UbahDigit
;	JB	F0,_MSKP_7anBaru
;	MOV	ISTACK+RT_MUKK_7an_Dg,A
;	SJMP	_MSKP_XYDig
;_MSKP_7anBaru:
;	MOV	ISTACK+RT_MUKK_7an_3L,R2
;	MOV	ISTACK+RT_MUKK_7an_8H,R3
;	SJMP	_MSKP_Nom7an

XY_MKK_Nomor		EQU	22
XY_MKK_Kfg		EQU	40H

_MKK_Redraw:
	LCALL	LCD_TlsCStrIni
	DB	FF,'Konfigurasi Simpul No 0000 :',EOS
_MKK_CtkNomBaru:
	MOV	A,#XY_MKK_Nomor
_MKK_CtkNomor:
	MOV	DPTR,#SegV_Umum+PU_MKK_PtrStrNomor
	LCALL	LCD_TlsXYXStr
_MKK_CtkKfg:
	LCALL	LCD_KursorGaris
	MOV	A,#XY_MKK_Kfg
	MOV	DPTR,#SegV_Umum+PU_MKK_PtrStrKfg
	LJMP	LCD_TlsXYXStr

;;KP_CekBernama:
_MKK_CekBernama:
	MOV	A,ISTACK+RS_MKK_8H
	CJNE	A,#C_KP_Bernama_8H,__KCB
	MOV	A,ISTACK+RS_MKK_3L
	;ANL	A,#7			; abaikan 5-BIT msb
	CJNE	A,#C_KP_Bernama_3L,$+3
__KCB:	RET				; CF: 1=bernama (lebih kecil)

MKK_KfgSimpul:
	MOV	R2,ISTACK+RS_MKK_3L
	MOV	R3,ISTACK+RS_MKK_8H
	MOV	DPTR,#SegV_Umum+PU_MKK_PtrStrNomor
	LCALL	KP_StrNomor
	MOV	R2,ISTACK+RS_MKK_3L
	MOV	R3,ISTACK+RS_MKK_8H
	LCALL	KP_BacaSifat
	MOV	ISTACK+RT_MKK_Sifat,R4
	MOV	DPTR,#SegV_Umum+PU_MKK_PtrStrKfg

;Menghasilkan Str Konfigurasi Simpul 
;Bisa dipakai eksternal
;M: R2=lo3, R3=hi8, R4=paksifat, DPTR=@XRam
;K: DPTR=@EOS
;R: A,B,R4,R0
KP_StrKfg:
	MOV	A,#'N'
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,#'='
	MOVX	@DPTR,A
	INC	DPTR
	LCALL	KP_BacaStrNama		; <- B rusak
	MOV	R0,#C_KP_JmlSifat
__KSSi1:
	MOV	A,#' '
	MOVX	@DPTR,A
	INC	DPTR
__KSSi2:
	MOV	A,R0
	ADD	A,#CTBL_KP_JudulSifat - $ - 3 - 1
	MOVC	A,@A+PC
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,#'='
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,R4
	RRC	A
	MOV	R4,A
	MOV	A,R0
	RLC	A
	ADD	A,#CTBL_KP_StatusSifat - $ - 3 - (2*1)
	MOVC	A,@A+PC
	MOVX	@DPTR,A
	INC	DPTR
	DJNZ	R0,__KSSi1
	MOV	A,#EOS
	MOVX	@DPTR,A
	RET

;M: R4=paksifat, DPTR=@XRAM
;R: A, R0, R4
KP_StrSifat:
	MOV	R0,#C_KP_JmlSifat
	SJMP	__KSSi2

CTBL_KP_JudulSifat:
	DB	'KTRAPF'			; dibalik !
CTBL_KP_StatusSifat:
	DB	'01','TO','TY','TY','+-','AB'

C_KP_JmlKfg		EQU	6+1
C_KP_JmlSifat		EQU	6

	END

;EndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEnd
;EndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEnd

KP_StrKfg:
	LCALL	SwapPtr16
	PUSH	DPL
	PUSH	DPH
	MOV	DPTR,#CTBL_KP_JudulNama
	LCALL	CStrCpy
	POP	DPH
	POP	DPL
	LCALL	SwapPtr16
CTBL_KP_JudulNama:
	DB	'N=',EOS

;+	CLR	A
	ADDC	A,#0FFH			; Gj(+1): A=0, C=1; Gn(-1): A=-1, C=0
	ADDC	A,R0

;+	SUBB	A,ACC			; Gj(-1): A=-1, C=1; Gn(+1): A=0, C=0
	CPL	C
	ADDC	A,R0

;+	CLR	A
	ADDC	A,#0FFH			; Gj(+1): A=0, C=1; Gn(-1): A=-1, C=0
	ADD	A,#0			; A=1, C=0; A=-1, C=0
	ADD	A,R0

;+	SUBB	A,ACC			; Gj(-1): A=-1, C=1; Gn(+1): A=0, C=0
	SUBB	A,#0FFH			; A <- A-(-1+C); Gj->A=-1, Gn->A=+1
	ADD	A,R0


