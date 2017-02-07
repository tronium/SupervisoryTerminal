XY_MKfg_Info	EQU	40H
XY_MKfg_Mnu	EQU	0

$INCLUDE(STDIO.DEF)
$INCLUDE(OS.DEF)

EXTRN	CODE	(LCD_SetXY, LCD_TulisCStr)
EXTRN	CODE	(LCD_TulisXStr, PS_TimpaSuara, KP_Aktifkan)
EXTRN	CODE	(MultiMenu_OSP, MgrMenu_OSP, MgrTugas_OSP)
;EXTRN	CODE	(LOG_NonKEP, RTC_StrWaktu)
;EXTRN	BIT	(P_Watchdog, F_PS_Aktif)
;EXTRN	DATA	(D_RTC_Dtk)

EXTRN	CODE	(MWaktu, MLihatKfgKEP)


SegV_Umum	SEGMENT	XDATA
		RSEG	SegV_Umum
		DS	0

SegV16		SEGMENT	XDATA
		RSEG	SegV16
V_MKfg_ROpsi:	DS	1
V_MKU_ROpsi:	DS	1

SegC_MKonfig	SEGMENT	CODE
		RSEG	SegC_MKonfig

PUBLIC	MKonfig
MKonfig:
	LCALL	MultiMenu_OSP
;MMTBL_Konfig:
	DB	3, XY_MKfg_Mnu
	DW	V_MKfg_ROpsi
	DW	AnyRet				; Esc
	DW	MKonfig				; Redraw
	DW	MKfg_Info, MKfg_Info, MKU_InfoWkt	; Info
	DW	MLihatKfgKEP, MKfgUmum, MWaktu	; Enter
	DB	'Nama&'
Str_NVSifat:
	DB	'Sifat',EOS
Str_NVUmum:
	DB	'Umum',EOS
Str_NVWaktu:
	DB	'Waktu',EOS			; Teks

PUBLIC	Str_NVSifat, Str_NVUmum, Str_NVWaktu

EXTRN	CODE	(MKU_InfoWkt, LCD_TlsXYCStr, Str_Pencipta)

MKfg_Info:
	JNB	F0,_MKfg_MM
	MOV	A,#XY_MKfg_Info
	MOV	DPTR,#Str_Pencipta
	LCALL	LCD_TlsXYCStr
_MKfg_MM:
	LJMP	MgrMenu_OSP

XY_MKU_Mnu	EQU	0H
XY_MKU_ISI	EQU	40H

MKfgUmum:
	;
MKU_Redraw:
	LCALL	MultiMenu_OSP
;MMTBL_Umum:
	DB	5, XY_MKU_Mnu
	DW	V_MKU_ROpsi
	DW	AnyRet				; Esc
	DW	MKU_Redraw			; Redraw
	DW	MKU_Info, MKU_Info, MKU_Info, MKU_Info, MKU_Info; Info
	DW	MKU_Ubah, MKU_Ubah, MKU_Ubah, MKU_Ubah, MKU_Ubah; Enter
	DB	'Cetak',EOS,'Notasi',EOS,'Log',EOS	; Teks
	DB	'Latar',EOS,'Efek',EOS


;C_MKU_OpsiInduk	EQU	1		; posisi menu dilihat induk
;MKU_Esc:
;	RET

MKU_Info:
	JNB	F0,_MKU_MM
;_MKU_CetakKfg:
	MOV	A,@RPOpsi
	LCALL	DuaPangkatN		; RET: CY=0
	ANL	A,RF_ModusUmum
	JZ	$+2+1
	SETB	C
	MOV	A,@RPOpsi
	RLC	A
	MOV	DPTR,#OTBL_MKU
	LCALL	CariCStrEOS
	MOV	A,#XY_MKU_ISI
	LCALL	LCD_TlsXYCStr
	MOV	R0,#C_MKU_SelisihKolom
	LCALL	LCD_RepHpsChr		; pastikan sisa opsi yg lain dihapus
_MKU_MM:
	LJMP	MgrMenu_OSP

MKU_Ubah:
	;MOV	A,@RPOpsi
	MOV	A,RPOpsi
	LCALL	DuaPangkatN
	XRL	RF_ModusUmum,A
	LCALL	KPFx_UpDateSTetap
	JNB	F_LOG_Dicetak,_MKU_Simpan
	SETB	VIE_PRN			; bangunkan jika tidur
_MKU_Simpan:
	LJMP	TRM_SimpanModusUmum

EXTRN	BIT	(VIE_PRN, F_LOG_Dicetak)
EXTRN	CODE	(DuaPangkatN, LCD_RepHpsChr)
EXTRN	CODE	(TRM_SimpanModusUmum, KPFx_UpDateSTetap)
EXTRN	DATA	(RF_ModusUmum)
;EXTRN	NUMBER	(CM_ModusUmum)

C_MKU_SelisihKolom	EQU	2
OTBL_MKU:
	DB	'T',EOS,'Y',EOS
	DB	'H',EOS,'D',EOS
	DB	'A',EOS,'A+N',EOS
	DB	'T',EOS,'Y',EOS
	DB	'T',EOS,'Y',EOS

CariCStrEOS:
	JZ	__CSE2
	MOV	R0,A
__CSE1:	CLR	A
	MOVC	A,@A+DPTR
	INC	DPTR
	CJNE	A,#EOS,__CSE1
	DJNZ	R0,__CSE1
AnyRet:
__CSE2:	RET

	END
