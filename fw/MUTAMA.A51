$INCLUDE(STDIO.DEF)
$INCLUDE(SCH.DEF)
$INCLUDE(SEGDATA.DEF)

CT_NamaTrm	EQU	3			; detik, lama tampil NamaTrm
XY_MUtm_Wkt	EQU	40H
XY_MUtm_Mnu	EQU	0H

ISTACK		SEGMENT	DATA
RT_MUtm_Dtk	EQU	0

SegV_Umum	SEGMENT	XDATA

SegV16		SEGMENT	XDATA
		RSEG	SegV16
V_MUtm_ROpsi:	DS	1

PUBLIC	STR_KopCetak, STR_Pencipta

SEGC_STR	SEGMENT	CODE
		RSEG	SEGC_STR

STR_NamaTrm:
	DB	FF		; FormFeed
STR_KopCetak:
	DB	'Terminal Multifungsi, Versi H3.1S4.0B',cr
STR_Pencipta:
	DB	'(C) 1998, Ori Novanda, T. Elektro USU',cr,EOS


SegC_MUtama	SEGMENT	CODE
	RSEG	SegC_MUtama

EXTRN	NUMBER	(CS_TrmSiap)
EXTRN	BIT	(F_PS_Aktif)
EXTRN	CODE	(PRN_Init, PS_TimpaSuara, LOG_NonKEP, KP_Aktifkan)

PUBLIC	TerminalSiap

TerminalSiap:
	MOV	SP,#ISTACK+7			; alokasi 8 byte
	LCALL	PRN_Init
	MOV	DPTR,#CS_TrmSiap
	LCALL	PS_TimpaSuara
	LCALL	TampilNamaTrm
__TS_Tunda:
	CLR	P_Watchdog
	JB	F_PS_Aktif,__TS_Tunda		; tunggu selesai dibunyikan
	CLR	A
	MOV	R2,A
	MOV	R3,A				; <- dicadangkan
	LCALL	LOG_NonKEP
	LCALL	KP_Aktifkan
	SJMP	_NT_MT


EXTRN	DATA	(D_RTC_Dtk)
EXTRN	CODE	(LCD_TulisCStr, MgrTugas_OSP)

TampilNamaTrm:
	MOV	DPTR,#STR_NamaTrm
	LCALL	LCD_TulisCStr
	MOV	A,D_RTC_dtk
	ADD	A,#CT_NamaTrm
	MOV	B,#60
	DIV	AB
	MOV	ISTACK+RT_MUtm_Dtk,B
	RET

NamaTerminal:
	LCALL	TampilNamaTrm
_NT_MT:	LCALL	MgrTugas_OSP
	SJMP	MUtama				; ditimpa -> selesai
	SJMP	_NT_CekTOut			; = idle
	SJMP	MUtama				; 'press any key'
	SJMP	MUtama
	SJMP	MUtama
_NT_CekTout:
	MOV	A,D_RTC_dtk			; hitung detik yg tersisa
	CJNE	A,ISTACK+RT_MUtm_Dtk,_NT_MT	;; sebelum menu utama aktif


EXTRN	CODE	(MultiMenu_OSP, MgrMenu_OSP)
EXTRN	CODE	(MKonfig, MKEPSNyata, MKEPSKeaktifan, MenuLog)

MUtama:
	LCALL	MultiMenu_OSP
;MMTBL_Utama:
	DB	4, XY_MUtm_Mnu
	DW	V_MUtm_ROpsi
	DW	NamaTerminal			; Esc
	DW	MUtama				; Redraw
	DW	MUtm_Info, MUtm_Info, MUtm_Info, MUtm_Info; Info
	DW	MKonfig, MKEPSNyata, MKEPSKeaktifan, MenuLog; Enter
	DB	'Konfig',EOS,'Pantau',EOS	; Teks
	DB	'Tangkap',EOS,'Log',EOS


EXTRN	CODE	(LCD_RepHpsXYChr)
EXTRN	CODE	(LCD_SetXY, LCD_TulisXStr)
EXTRN	CODE	(RTC_StrWaktu)

PUBLIC	MKU_InfoWkt

C_JmlChrWkt	EQU	23
MKU_InfoWkt:
	JNB	F0,MUtm_Info
	MOV	A,#40H+C_JmlChrWkt
	MOV	R0,#40-C_JmlChrWkt
	LCALL	LCD_RepHpsXYChr
MUtm_Info:
	MOV	A,D_RTC_dtk
	CJNE	A,ISTACK+RT_MUtm_Dtk,_MUtm_CtkWaktu
	JNB	F0,_MUtm_MM
_MUtm_CtkWaktu:
	MOV	ISTACK+RT_MUtm_Dtk,A
	MOV	A,#XY_MUtm_Wkt
	LCALL	LCD_SetXY
	MOV	DPTR,#SegV_Umum
	LCALL	RTC_StrWaktu
	MOV	DPTR,#SegV_Umum
	LCALL	LCD_TulisXStr
_MUtm_MM:
	LJMP	MgrMenu_OSP

	END
