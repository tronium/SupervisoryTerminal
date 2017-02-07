LCDStrBerkedip	set	1
;15:35pm 03-30-1999 Pengefisiensian _hapus_ dan _kedip_
name	LCD_plus

EXTRN	CODE	(LCD_TulisChr, LCD_SetXY, SwapPtr16, LCD_HapusChr)

$INCLUDE(STDIO.DEF)

PUBLIC	LCD_TlsNCObj, LCD_TlsNCXObj
PUBLIC	LCD_TlsCStrini, LCD_RepTlsChr
PUBLIC	LCD_TulisXStr, LCD_TulisCStr
PUBLIC	LCD_TlsXYXStr, LCD_TlsXYCStr
PUBLIC	LCD_TlsXYXChr
PUBLIC	LCD_KdpXYCStr, LCD_KdpXYXStr
PUBLIC	LCD_KedipXStr, LCD_KedipXChr
PUBLIC	LCD_FlipKedip, LCD_RstKdpOn, LCD_RstKdpOff
PUBLIC	LCD_RepHpsChr, LCD_RepHpsXYChr

;LCD_TlsXYCChr
;LCD_TulisCChr
;LCD_HpsXYCChr
;LCD_HapusCChr

;+LCD_TlsXYCStrIni
;+LCD_HpsXYXStr
;+LCD_HpsXYCStr
;+LCD_HpsXYXChr
;+LCD_KdpXYXChr

;+LCD_CekFlipKedip
;LCD_KdpX2Chr

;PUBLIC	LCD_KedipCStr
;PUBLIC	LCD_OtoFlipKedip
;PUBLIC	LCD_TulisXChr
;PUBLIC	LCD_HapusCStr
;PUBLIC	LCD_HapusXStr
;PUBLIC	LCD_HapusXChr

IF (LCDStrBerkedip = 1)
;EXTRN	number	(C_LCD_DCKdpOn, C_LCD_DCKdpOff)
$INCLUDE(PEWAKTU.DEF)
PUBLIC	D_LCD_FlipKedip, F_LCD_FlipKedip, F_LCD_PosKedip
ENDIF

IF (LCDStrBerkedip = 1)
SegD_LCDPlus		SEGMENT	DATA
			RSEG	SegD_LCDPlus
D_LCD_FlipKedip:		DS	1

SegB_LCDPlus		SEGMENT	BIT
			RSEG	SegB_LCDPlus
F_LCD_FlipKedip:	DBIT	1
F_LCD_PosKedip:		DBIT	1

ENDIF

SegC_LCD	SEGMENT	CODE	INBLOCK
		RSEG	SegC_LCD

;LCD_TlsCObj:
;	CLR	A
;	MOVC	A,@A+DPTR
;	MOV	R0,A
;	INC	DPTR
; Kegunaan: menulis sejumlah (R0) C_Str lengkap, yang diawali dengan XY
LCD_TlsNCObj:
	ACALL	LCD_TlsCXYStr
	DJNZ	R0,LCD_TlsNCObj
	RET

; Kegunaan: menulis sejumlah (R0) C_Str lengkap yang diawali dengan XY,
;	    dan masing-masing diikuti dengan X_Str

LCD_TlsNCXObj:
	ACALL	LCD_TlsCXYStr
;+	CLR	A
;	MOVC	A,@A+DPTR
;	MOV	R6,A
;	INC	DPTR
;	CLR	A
;	MOVC	A,@A+DPTR
;	MOV	R7,A
;+	INC	DPTR
	LCALL	SwapPtr16
	ACALL	LCD_TulisXStr		; <- stack: 6
	LCALL	SwapPtr16
	DJNZ	R0,LCD_TlsNCXObj
	RET

;------------------------------------
; Kegunaan: menulis x_str lengkap
; Cakupan : LCD_TulisChr
;------------------------------------
LCD_TlsXYXStr:				; tot stack = 6
	ACALL	LCD_SetXY		; <- stack 4
	SJMP	LCD_TulisXStr
__ltxs:
	ACALL	LCD_TulisChr		; <- stack: 4
LCD_TulisXStr:
	MOVX	A,@DPTR
	INC	DPTR
	CJNE	A,#EOS,__ltxs
	RET

;------------------------------------
; Kegunaan: menulis C_str lengkap
; Cakupan : LCD_TulisChr
;------------------------------------
LCD_TlsCXYStr:
	CLR	A
	MOVC	A,@A+DPTR
	INC	DPTR
LCD_TlsXYCStr:
	ACALL	LCD_SetXY
	SJMP	LCD_TulisCStr
__ltcs:
	ACALL	LCD_TulisChr
LCD_TulisCStr:
	CLR	A
	MOVC	A,@A+DPTR
	INC	DPTR
	CJNE	A,#EOS,__ltcs
	RET

;--------------------------------------------
; Kegunaan: menulis C_str sesudah inst. call
; Cakupan : LCD_TulisChr
;--------------------------------------------
;LCD_TlsXYCStrIni:
;	ACALL	LCD_SetXY
LCD_TlsCStrini:
	POP	DPH			;= alamat string 
	POP	DPL
	ACALL	LCD_TulisCStr
	PUSH	DPL			;PUSH alamat RET
	PUSH	DPH
	RET
	
;------------------------------------------------
; Kegunaan: menulis sejumlah (R0) chr dari x_str
; Masukan : R0 = jml chr (0 = tak ada)
; Cakupan : LCD_TulisChr
;------------------------------------------------
LCD_TlsXYXChr:
	ACALL	LCD_SetXY
LCD_TulisXChr:
	CJNE	R0,#0,__ltxc
	RET
__ltxc:
	MOVX	A,@DPTR
	INC	DPTR
	ACALL	LCD_TulisChr
	DJNZ	R0,__ltxc
	RET

;------------------------------------------------
; Kegunaan: menulis sejumlah (R0) chr dari C_str
; Masukan : R0 = jml chr (0 = tak ada)
; Cakupan : LCD_TulisChr
;------------------------------------------------
;LCD_TlsXYCChr:
;	ACALL	LCD_SetXY
;LCD_TulisCChr:
;	CJNE	R0,#0,__ltcc
;	RET
;__ltcc:
;	CLR	A
;	MOVC	A,@A+DPTR
;	INC	DPTR
;	ACALL	LCD_TulisChr
;	DJNZ	R0,__ltcc
;	RET

;----------------------------------------------
; Kegunaan: menulis berulang sejumlah (R0) chr
; Masukan : R0 = jml diTulis (0 = 256)
;----------------------------------------------
LCD_RepHpsXYChr:
	ACALL	LCD_SetXY
LCD_RepHpsChr:
	MOV	A,#' '
LCD_RepTlsChr:
	ACALL	LCD_TulisChr
	DJNZ	R0,LCD_RepTlsChr
	RET

IF (LCDStrBerkedip = 1)

;---------------------------------------------------------
; Kegunaan: menulis kedip x_str
; Cakupan : LCD_TulisXStr, LCD_HapusXStr
;---------------------------------------------------------
LCD_KdpXYXStr:
	ACALL	LCD_SetXY
LCD_KedipXStr:
	ACALL	LCD_OtoFlipKedip
	JNB	F_LCD_PosKedip,LCD_HapusXStr
	SJMP	LCD_TulisXStr

;--------------------------------------
; Kegunaan: menghapus x_str lengkap
; Cakupan : LCD_TulisChr
;--------------------------------------
;LCD_HpsXYXStr:
;	ACALL	LCD_SetXY
LCD_HapusXStr:
	MOVX	A,@DPTR
	INC	DPTR
	CJNE	A,#EOS,__lhxs
	RET
__lhxs:	ACALL	LCD_HapusChr
	SJMP	LCD_HapusXStr

;---------------------------------------------------------
; Kegunaan: menulis kedip C_str
; Cakupan : LCD_TulisCStr, LCD_HapusCStr
;---------------------------------------------------------
LCD_KdpXYCStr:
	ACALL	LCD_SetXY
LCD_KedipCStr:
	ACALL	LCD_OtoFlipKedip
	JNB	F_LCD_PosKedip,LCD_HapusCStr
	SJMP	LCD_TulisCStr

;--------------------------------------
; Kegunaan: menghapus C_str lengkap
; Cakupan : LCD_TulisChr
;--------------------------------------
;LCD_HpsXYCStr:
;	ACALL	LCD_SetXY
LCD_HapusCStr:
	CLR	A
	MOVC	A,@A+DPTR
	INC	DPTR
	CJNE	A,#EOS,__lhcs
	RET
__lhcs:	ACALL	LCD_HapusChr
	SJMP	LCD_HapusCStr

;---------------------------------------------------------
; Kegunaan: menulis kedip sejumlah (R1) chr dari x_str
; Masukan : R0 = offset awal chr yg berkedip
;	    R1 = jml chr yg berkedip
; Cakupan : LCD_TulisXChr, LCD_HapusXChr, LCD_TulisXStr
;---------------------------------------------------------
;LCD_KdpX2Chr:
;	ACALL	LCD_TulisXChr
;	JB	F_LCD_PosKedip,__lkx2
;	MOV	A,R1
;	MOV	R0,A
;	ACALL	LCD_HapusXChr
;__lkx2c:
;	SJMP	LCD_TulisXStr

;LCD_KdpXYXChr:
;	ACALL	LCD_SetXY
LCD_KedipXChr:
	ACALL	LCD_OtoFlipKedip
	JNB	F_LCD_PosKedip,LCD_HapusXChr
	SJMP	LCD_TulisXChr

;--------------------------------------
; Kegunaan: manghapus sejumlah (R0) chr dari x_str
; Masukan : R0 = jml chr (0 = tak ada)
; Cakupan : LCD_TulisChr
;--------------------------------------
;LCD_HpsXYXChr:
;	ACALL	LCD_SetXY
LCD_HapusXChr:
	CJNE	R0,#0,__lhxc
	RET
__lhxc:	MOVX	A,@DPTR
	INC	DPTR
	ACALL	LCD_HapusChr
	DJNZ	R0,__lhxc
	RET

;LCD_KdpXYCChr:
;	ACALL	LCD_SetXY
;LCD_KedipCChr:
;	ACALL	LCD_OtoFlipKedip
;	JNB	F_LCD_PosKedip,LCD_HapusCChr
;	SJMP	LCD_TulisCChr

;--------------------------------------
; Kegunaan: manghapus sejumlah (R0) chr dari C_str
; Masukan : R0 = jml chr (0 = tak ada)
; Cakupan : LCD_TulisChr
;--------------------------------------
;LCD_HpsXYCChr:
;	ACALL	LCD_SetXY
;LCD_HapusCChr:
;	CJNE	R0,#0,__lhcc
;	RET
;__lhcc:
;	CLR	A
;	MOVC	A,@A+DPTR
;	INC	DPTR
;	ACALL	LCD_HapusChr
;	DJNZ	R0,_lcd_hcchr
;	RET

;-----------------------------------------------------------------------
; Kegunaan: mendapatkan status pewaktu, meresetnya jika terjadi timeout
; Keluaran: cf = status timeout (1 = sudah timeout)
;-----------------------------------------------------------------------
;LCD_CekFlipKedip:
;	MOV	C,F_LCD_FlipKedip
;	JC	LCD_FlipKedip
;	RET

LCD_OtoFlipKedip:
	JNB	F_LCD_FlipKedip,__lofk_RET

;---------------------------------------------------------------------
; Kegunaan: mereset pewaktu dan mengisi cacahannya sesuai
;	    dengan status kedip berikutnya
;---------------------------------------------------------------------
LCD_FlipKedip:
	JBC	F_LCD_PosKedip,_lcd_kdpoff		;sebelumnya on / off ?

;---------------------------------------------------------------
; Kegunaan: mereset pewaktu dengan status kedip = on
;---------------------------------------------------------------
LCD_RstKdpOn:
	SETB	F_LCD_PosKedip
	MOV	D_LCD_FlipKedip,#C_LCD_DCKdpOn
	CLR	F_LCD_FlipKedip
__lofk_RET:
	RET
LCD_RstKdpOff:
	CLR	F_LCD_PosKedip
_lcd_kdpoff:
	MOV	D_LCD_FlipKedip,#C_LCD_DCKdpOff
	CLR	F_LCD_FlipKedip
	RET
ENDIF

	END

IF (LCDStrBerkedip = 1)
EXTRN	D_LCD_FlipKedip, F_LCD_FlipKedip

;========================
;Pewaktu untuk lcd_kedip
;========================
	DJNZ	D_LCD_FlipKedip,$+5	;3
	SETB	F_LCD_FlipKedip		;2
ENDIF

;------------------------------------
; LCD_TulisIStr(R0,DPTR)
; Kegunaan: menulis (C_str+R0) lengkap
; Cakupan : LCD_TulisChr
;------------------------------------
_lcd_cistr:
	ACALL	LCD_TulisChr
LCD_TulisIStr:
	MOV	A,R0
	MOVC	A,@A+DPTR
	INC	R0
	CJNE	A,#EOS,_lcd_cistr
	RET

;------------------------------------
; LCD_HapusIStr(R0,DPTR)
; Kegunaan: menulis (C_str+R0) lengkap
; Cakupan : LCD_TulisChr
;------------------------------------
_lcd_histr:
	ACALL	LCD_TulisChr
LCD_HapusIStr:
	MOV	A,R0
	MOVC	A,@A+DPTR
	INC	R0
	CJNE	A,#EOS,_lcd_histr
	RET
