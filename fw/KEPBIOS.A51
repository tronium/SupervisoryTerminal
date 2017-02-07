RF_KP_Status		EQU	20H
RF_ModusUmum		EQU	21H

$INCLUDE(SCH.DEF)
$INCLUDE(PANTAU.DEF)
$INCLUDE(OS.DEF)

EXTRN	CODE	(CChrCpy, JmlBITAktif)
EXTRN	CODE	(LOG_WaktuSekarang)

EXTRN	BIT	(F_LOG_TakTerekam)
EXTRN	DATA	(D_LOG_Buf_K, D_LOG_Buf_B)
EXTRN	XDATA	(V_LOG_Buf)

PUBLIC	KP_Pantau, KP_Aktifkan
PUBLIC	IRQ_KP, IE_KP, D_KP_DCPantau
PUBLIC	V8_KP_Status, V8_KP_Keaktifan, V8_KP_Perubahan
PUBLIC	NV8_KP_Polar, NV8_KP_Baca, NV8_KP_Alarm
PUBLIC	NV8_KP_TRespon, NV8_KP_ORespon, V8_KP_Keluaran
PUBLIC	NVC_KP_Sifat

PUBLIC	NV_KP_Nama, HW_KP
PUBLIC	F_KP_AlarmLain

PUBLIC	F_KP_Bertambah, F_KP_Berkurang, F_KP_AdaBerubah, F_KP_Alarm
PUBLIC	F_LOG_ModusKEP, F_KP_SuaraTetap, F_KP_SuaraBeda
PUBLIC	F_KP_Selip

SegNV8			SEGMENT	XDATA	PAGE
			RSEG	SegNV8
NV8_KP_Polar:		DS	256		; polaritas masukan 1=-, 0=+
NV8_KP_Baca:		DS	256		; pengacuhan
NV8_KP_TRespon:		DS	256		; tipe respon 1=On/Off, 0=Trg
NV8_KP_ORespon:		DS	256		; respon otomatis
NV8_KP_Alarm:		DS	256		; sifat masukan

;PUBLIC	SegV8
SegV8			SEGMENT	XDATA	PAGE
			RSEG	SegV8
V8_KP_Keluaran:		DS	256		; keluaran titipan
V8_KP_Status:		DS	256		; status sekarang
V8_KP_Keaktifan:	DS	256		; yang pernah aktif
V8_KP_Perubahan:	DS	256		; yang pernah berubah


;----PEMAKSAAN POSISI SEGMENT -------------

SEGV_Umum	SEGMENT	XDATA
		RSEG	SEGV_Umum
		DS	0

XSTACK		SEGMENT	XDATA
		RSEG	XSTACK
		DS	0

SegV16		SEGMENT	XDATA
		RSEG	SegV16
		DS	0

SEGV16_LOG	SEGMENT	XDATA
		RSEG	SEGV16_LOG
		DS	0

;------------------------------------------
PUBLIC	SegNV16, NV_ModusUmum, NVC_Umum, NV_RMT_Modus, NV_RTC_Thn

SegNV16			SEGMENT	XDATA
			RSEG	SegNV16
NV_ModusUmum:		DS	1		;ragam operasi (global)
NV_RMT_Modus:		DS	1
NV_RTC_Thn:		DS	1

SegNVCek		SEGMENT	XDATA
			RSEG	SegNVCek
NVC_KP_Sifat:		DS	1		; paritas
NVC_Umum:		DS	1

SegNV16_Nama		SEGMENT	XDATA
			RSEG	SegNV16_Nama
NV_KP_Nama:		DS	C_KP_PjgNama*C_KP_JmlBernama

			XSEG	AT HW_KP_Dasar
HW_KP:			DS	256

SegD_KP			SEGMENT	DATA
			RSEG	SegD_KP
D_KP_DCPantau:		DS	1
D_KP_NomKartu:		DS	1
DT_KP1:			DS	1		; data temporer
DT_KP2:			DS	1
DT_KP3:			DS	1

			BSEG	AT (RF_KP_Status-20H)*8
CV_KP_Perubahan	EQU	0F0H
F_KP_AdaBerubah_p:	DBIT	1	; polling
F_KP_Bertambah_p:	DBIT	1
F_KP_Berkurang_p:	DBIT	1
F_KP_Alarm_p:		DBIT	1
F_KP_AdaBerubah:	DBIT	1	; alarm + non alarm pernah berubah
F_KP_Bertambah:		DBIT	1	; alarm pernah bertambah
F_KP_Berkurang:		DBIT	1	; alarm pernah berkurang
F_KP_Alarm:		DBIT	1	; status alarm final (lokal)

PUBLIC	F_LOG_Dicetak, F_KP_NotasiDes
EXTRN	BIT	(F_LOG_IzinTimpa)

PUBLIC	RF_ModusUmum, CD_ModusUmum, CM_ModusUmum

			BSEG	AT (RF_ModusUmum-20H)*8
CD_ModusUmum		EQU	0FH	; 1EH
CM_ModusUmum		EQU	1FH
F_LOG_Dicetak:		DBIT	1
F_KP_NotasiDes:		DBIT	1
F_LOG_ModusKEP:		DBIT	1	; 1=semua, 0=alarm saja
F_KP_SuaraTetap:	DBIT	1	; 1=ya, 0=tdk
F_KP_SuaraBeda:		DBIT	1	; 1=ya, 0=tdk

F_KP_AlarmLain:		DBIT	1	; tumpangan dari luar

SegB_KP			SEGMENT	BIT
			RSEG	SegB_KP
F_KP_Selip:		DBIT	1
IE_KP:			DBIT	1
IRQ_KP:			DBIT	1

SegC_PsIsr	SEGMENT	CODE
		RSEG	SegC_PsIsr
		DS	0

SegC_PbIsr	SEGMENT	CODE
		RSEG	SegC_PbIsr
		DS	0

SegC_KPIsr	SEGMENT	CODE
		RSEG	SegC_KPIsr

;-----------------------------------------------
; Bagian berikut dijalankan oleh PewaktuBersama
; dengan IE_KP=0
;-----------------------------------------------
KP_Pantau:
	LCALL	_KP_RETI
	PUSH	PSW
	PUSH	DPL
	PUSH	DPH
;_KP_cuplik:
	XCH	A,D_KP_NomKartu		; = PUSH ACC
	MOV	DPL,A			; = # kartu yang akan diproses
	MOV	DPH,#HIGH HW_KP
	MOVX	A,@DPTR
	MOV	DT_KP1,A		; KP1 = C_baru asli
;_KP_Polaritas:
	MOV	DPH,#HIGH NV8_KP_Polar
	MOVX	A,@DPTR
	XRL	DT_KP1,A		; KP1 = C_baru bersifat aktif tinggi
;_KP_pengacuhan:
	MOV	DPH,#HIGH NV8_KP_Baca
	MOVX	A,@DPTR
	ANL	DT_KP1,A		; KP1 = s_baru

;_KP_status:
	MOV	DPH,#HIGH V8_KP_Status
	MOVX	A,@DPTR
	MOV	DT_KP2,A		; KP2 = s_lama
	MOV	A,DT_KP1
	MOVX	@DPTR,A			; simpan s_baru menjadi s_lama
;_KP_tiperespon:
	MOV	DPH,#HIGH NV8_KP_TRespon
	MOVX	A,@DPTR			; = tipe_respon
	ANL	A,DT_KP1		; = t_respon.AND.s_baru
	MOV	DT_KP3,A		; KP3 = hsl_oto sementara
	MOV	A,DT_KP2
	CPL	A
	ANL	A,DT_KP1		; = -s_lama.AND.s_baru
	ORL	DT_KP3,A		; KP3 = hsl_oto akhir
;_KP_Otorespon:
	MOV	DPH,#HIGH NV8_KP_ORespon
	MOVX	A,@DPTR
	ANL	DT_KP3,A		; KP3 = respon = hsl_oto.AND.modus
;_KP_Keluaran:
	MOV	DPH,#HIGH V8_KP_Keluaran
	MOVX	A,@DPTR
	ORL	A,DT_KP3		; keluaran = respon.OR.modus
	MOV	DPH,#HIGH HW_KP
	MOVX	@DPTR,A

;_KP_StatusAlarm:
	MOV	DPH,#HIGH NV8_KP_Alarm
	MOVX	A,@DPTR
	ANL	A,DT_KP1
	JZ	_KP_CekBedaStatus
	SETB	F_KP_Alarm_p
_KP_CekBedaStatus:
	MOV	A,DT_KP1
	XRL	A,DT_KP2		; perbedaan = s_baru.XOR.s_lama
	JZ	__KP_Keakhir		; 0 -> tidak ada yang berbeda
	SETB	F_KP_AdaBerubah_p
	MOV	DT_KP3,A		; KP3 = perbedaan

;_KP_Perubahan:
	MOV	DPH,#HIGH V8_KP_Perubahan
	MOVX	A,@DPTR
	ORL	A,DT_KP3		; lama + baru
	MOVX	@DPTR,A

;_KP_Keaktifan:
	MOV	DPH,#HIGH V8_KP_Keaktifan
	MOVX	A,@DPTR
	ORL	A,DT_KP1		; lama + baru
	MOVX	@DPTR,A

;_KP_cek_perubahan_Alarm:
	MOV	DPH,#HIGH NV8_KP_Alarm
	MOVX	A,@DPTR
	ANL	A,DT_KP3		; perubahan = modus.AND.perbedaan
	JNZ	_KP_cek_rekam
	JB	F_LOG_ModusKEP,_KP_rekam_perubahan
__KP_Keakhir:
	LJMP	_KP_akhir
_KP_cek_rekam:
	JB	F_LOG_ModusKEP,_KP_cek_berkurang
	MOV	DT_KP3,A		; KP3 = alarm saja
_KP_cek_berkurang:
	XCH	A,DT_KP2		; KP2 <-> perubahan_Alarm
	ANL	A,DT_KP2		; berkurang = s_lama.AND.perubahan
	JZ	_KP_cek_bertambah
	SETB	F_KP_Berkurang_p	; = alarm berkurang
_KP_cek_bertambah:
	MOV	A,DT_KP2
	ANL	A,DT_KP1		; bertambah = perubahan.AND.s_baru
	JZ	_KP_rekam_perubahan
	SETB	F_KP_Bertambah_p	; = alarm bertambah

_KP_rekam_perubahan:
	MOV	A,D_LOG_Buf_K
	INC	A
	CJNE	A,#C_LOG_JmlEntry,_KP_CekLog
	CLR	A
_KP_CekLog:
	CJNE	A,D_LOG_Buf_B,_KP_IsiLog		; k+1=B -> penuh
	JNB	F_LOG_IzinTimpa,_KP_TimpaLog
	SETB	F_LOG_TakTerekam
	SJMP	_KP_akhir
_KP_TimpaLog:
	INC	D_LOG_Buf_B
	MOV	A,#C_LOG_JmlEntry
	CJNE	A,D_LOG_Buf_B,_KP_IsiLog
	MOV	D_LOG_Buf_B,#0

	;MOV	A,D_LOG_Buf_B
	;INC	A
	;CJNE	A,#C_LOG_JmlEntry,__KTL
	;CLR	A
;__KTL:	MOV	D_LOG_Buf_B,A

_KP_IsiLog:
	MOV	A,#C_LOG_PjgEntry

	XCH	A,B
	XCH	A,DPL			; = PUSH B
	MOV	DT_KP2,A
	MOV	A,D_LOG_Buf_K
	MUL	AB

	ADD	A,#LOW V_LOG_Buf
	XCH	A,DPL
	XCH	A,B			; = POP B
	ADDC	A,#HIGH V_LOG_Buf
	MOV	DPH,A

	LCALL	LOG_WaktuSekarang
	MOV	A,DT_KP3		; = perubahan
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,DT_KP2		; = no_kartu
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,DT_KP1		; = s_baru
	MOVX	@DPTR,A
	MOV	DPL,DT_KP2

	;MOV	A,D_LOG_Buf_K
	;INC	A
	;CJNE	A,#C_LOG_JmlEntry,__KIL
	;CLR	A
;__KIL:	MOV	D_LOG_Buf_K,A

	INC	D_LOG_Buf_K
	MOV	A,#C_LOG_JmlEntry
	CJNE	A,D_LOG_Buf_K,_KP_akhir
	MOV	D_LOG_Buf_K,#0
_KP_akhir:
	MOV	A,DPL
	INC	A
	JNZ	_KP_QP

	MOV	A,RF_KP_Status
	SWAP	A
	MOV	C,F_KP_Alarm_p
	ORL	A,RF_KP_Status
	ANL	A,#CV_KP_Perubahan
	MOV	RF_KP_Status,A

	MOV	F_KP_Alarm,C		; mutakhirkan alarm lokal
	ORL	C,F_KP_AlarmLain	; sertakan alarm lain
	CPL	C			; jadikan aktif rendah
	MOV	P_Alarm,C		; mutakhirkan ALARM GLOBAL
	CLR	A
_KP_qp:
	XCH	A,D_KP_NomKartu		; = POP ACC
	POP	DPH
	POP	DPL
	POP	PSW
	SETB	IE_KP			; <- almt RETI masih di stack (OV ?!)
_KP_RETI:
	RETI

;=====================================================================
;=====================================================================

PUBLIC	KP_CekNVSifat, KP_CekNVNama

SegC_KPInit	SEGMENT	CODE
		RSEG	SegC_KPInit

;F: Memampukan aktifitas pantau
KP_Aktifkan:
	SETB	P_Alarm			; matikan dahulu
	CLR	IRQ_KP
	;MOV	D_KP_DCPantau,#1	; segera aktif
	SETB	IE_KP
	CLR	F_KP_Selip
	RET

CD_KP_Sifat		EQU	0

EXTRN	CODE	(KP_TulisSifat)

;F: Memeriksa keabsahan konfigurasi SIFAT, meresetnya jika cacat
;K: A=Status (0=sah, tidak direset)
KP_CekNVSifat:
	LCALL	_KP_BCCSifat
	JZ	__KCSQ
	MOV	R3,#0			; N8 = Kartu 0
_KP_SifatDefault:
	MOV	R2,#0			; N3 = BIT 0
__KSD:	MOV	R4,#CD_KP_Sifat
	LCALL	KP_TulisSifat
	INC	R2
	CJNE	R2,#8,__KSD
	INC	R3
	CLR	P_Watchdog
	CJNE	R3,#0,_KP_SifatDefault
	LCALL	_KP_BCCSifat
	MOV	A,B
	MOVX	@DPTR,A
	MOV	A,#1
__KCSQ:	RET

;F: Menghitung BCC konfigurasi SIFAT
;K: A=Status(0=sah), B=BCC
_KP_BCCSifat:
	MOV	B,#C_KP_BCCAwal

	MOV	DPL,#0
	MOV	A,#_N_KBCC_Seg
__KBCC0:
	PUSH	ACC
	MOVC	A,@A+PC
__KBCC1:
	MOV	DPH,A
__KBCC2:
	MOVX	A,@DPTR
	XRL	B,A
	DJNZ	DPL,__KBCC2
	POP	ACC
	INC	A
	CJNE	A,#_N_KBCC_Seg+_N_KBCC_Jml,__KBCC0
	MOV	DPTR,#NVC_KP_Sifat
	MOVX	A,@DPTR
	XRL	A,B
	RET

	_N_KBCC_Seg	EQU	$ - __KBCC1
ATBL_KP_BCC:
	DB	HIGH NV8_KP_Baca
	DB	HIGH NV8_KP_Polar
	DB	HIGH NV8_KP_Alarm
	DB	HIGH NV8_KP_ORespon
	DB	HIGH NV8_KP_TRespon
	;DB	HIGH V8_KP_Keluaran
	_N_KBCC_Jml	EQU	$ - ATBL_KP_BCC

;F: Memeriksa keabsahan konfigurasi NAMA, meresetnya jika cacat
KP_CekNVNama:
	MOV	DPTR,#NV_KP_Nama
__KCN1:	LCALL	KP_CekChrNama
	JC	_KP_NamaDefault
	MOV	A,#LOW  NV_KP_Nama + (C_KP_JmlBernama * C_KP_PjgNama)
	CJNE	A,DPL,__KCN1
	MOV	A,#HIGH NV_KP_Nama + (C_KP_JmlBernama * C_KP_PjgNama)
	CJNE	A,DPH,__KCN1
	CLR	A
	RET

;F: Memeriksa Chr NAMA pada @DPTR
;K: CY: 1=cacat
KP_CekChrNama:
	MOV	RCcL,#C_KP_PjgNama
__CCN1:	MOVX	A,@DPTR
	JB	ACC.7,__CCN2		; ascii standar (A < 80H) ?
	ADD	A,#-' '
	JNC	__CCN2			; chr >/ 'spasi' (CF=1) ? 
	INC	DPTR
	DJNZ	RCcL,__CCN1
	CLR	C
	RET

__CCN2:	SETB	C
	RET

_KP_NamaDefault:
	MOV	XPL,#LOW  NV_KP_Nama
	MOV	XPH,#HIGH NV_KP_Nama
__KND:	MOV	RCcL,#C_KP_PjgNama
	MOV	DPTR,#SKP_NamaDef
	LCALL	CChrCpy
	CLR	P_Watchdog
	CJNE	XPL,#LOW  NV_KP_Nama + (C_KP_JmlBernama * C_KP_PjgNama),__KND
	MOV	A,XPH
	CJNE	A,#HIGH NV_KP_Nama + (C_KP_JmlBernama * C_KP_PjgNama),__KND
	MOV	A,#1
	RET

SEGC_STR	SEGMENT	CODE
		RSEG	SEGC_STR
SKP_NamaDef:
	DB	'OriNovanda'

	END

	;DB	'Aktif'
	;DB	'Non aktif'
	;DB	'Alarm'
	;DB	'Normal'

;_KPI_SuaraTetap:
;	MOV	DPTR,#NV_KP_SuaraTetap
;	MOVX	A,@DPTR
;	LCALL	PS_SetSUlang
;	CLR	C
;	RET
;	MOV	DPTR,#OTBL_KP_SuaraTetap
;--------
;catatan
;--------
; Konfigurasi penetapan:
;POLARITAS : (1) = AKTIF TINGGI (0) = AKTIF RENDAH (dibalik dalam s/w)
;ABAIKAN : (Y)A / (T)idak
;;;NOISE: (Y)A / (T)idak
;ALARAM	: (Y)A / (T)idak
;RESPON	: (Y) / (T)
;TIPE RESPON : (T)rigger / (O)n-Off
;KELUARAN : selalu (O)n / (R)respon

;harga default
;CD_KP_Polar		EQU	0	; = aktif tinggi
;CD_KP_Acuh		EQU	000H	; = tak dibaca
;CD_KP_Acuh256		EQU	0
;CD_KP_TRespon		EQU	0
;CD_KP_Otorespon	EQU	0
;CD_KP_Keluaran		EQU	0
;CD_KP_Alarm		EQU	0H
;CD_KP_Alarm256		EQU	0

;KP_RstNVSifat:
;	MOV	A,#CD_KP_Polar
;	MOV	DPTR,#NV8_KP_Polar
;	LCALL	_KP_RstNV8
;	MOV	A,#CD_KP_Acuh
;	MOV	DPTR,#NV8_KP_Baca
;	LCALL	_KP_RstNV8
;	MOV	A,#CD_KP_TRespon
;	MOV	DPTR,#NV8_KP_TRespon
;	LCALL	_KP_RstNV8
;	MOV	A,#CD_KP_Otorespon
;	MOV	DPTR,#NV8_KP_ORespon
;	LCALL	_KP_RstNV8
;	MOV	A,#CD_KP_Keluaran
;	MOV	DPTR,#V8_KP_Keluaran
;	LCALL	_KP_RstNV8
;	MOV	A,#CD_KP_Alarm
;	MOV	DPTR,#NV8_KP_Alarm
;	LCALL	_KP_RstNV8
;	DEC	DPL
;	MOV	A,#CD_KP_Alarm256
;	MOVX	@DPTR,A
;	XRL	B,A
;	MOV	A,#CD_KP_Modus
;	MOV	DPTR,#NV_KP_Modus
;	MOVX	@DPTR,A
;	XRL	A,B
;	MOV	DPTR,#NVC_KP_Sifat
;	MOVX	@DPTR,A
;	CLR	C
;	RET
;_KP_RstNV8:
;	MOVX	@DPTR,A
;	XRL	B,A
;	DJNZ	DPL,_KP_RstNV8
;	CLR	P_Watchdog
;	RET

