;REF
; - TestXRAM = 0FFH, Random, 0
; - TestROM = BCC

CM_TCON_irq	EQU	10101010b
C_BCCAwal	EQU	0FFh		; Paritas Ganjil !
C_BCCROM	EQU	0FFh

$INCLUDE(SCH.DEF)
$INCLUDE(STDIO.DEF)
$INCLUDE(OS.DEF)

C_BeepMCS	EQU	10111000B
C_BeepLCD	EQU	10100000B
C_BeepTRM	EQU	10101000B

;C_BeepROM	EQU	11001100B
;C_BeepVRAM	EQU	11001100B


EXTRN	BIT	(F_PT_AdaTombol)
EXTRN	CODE	(LCD_Init, PPI_Init, PB_Init)
EXTRN	CODE	(PCF_POST, RTC_Init)
EXTRN	CODE	(TerminalSiap)
EXTRN	CODE	(LCD_TulisCStr, LCD_TulisChr)
EXTRN	CODE	(LCD_TlsCStrIni, LCD_SetXY)
EXTRN	CODE	(LCD_RepTlsChr, LCD_KursorBlok)
EXTRN	CODE	(ByteKeHexAsc)
EXTRN	CODE	(PT_Reset, PT_AmbilTombol)
EXTRN	CODE	(JMB_InitDasar, JmpWOffset)
EXTRN	NUMBER	(C_PT_Ya)

ISTACK		SEGMENT	DATA
		RSEG	ISTACK
		DS	0

SegNV8		SEGMENT	XDATA
		RSEG	SegNV8
		DS	0

SegV8		SEGMENT	XDATA
		RSEG	SegV8
		DS	0

SegNV16		SEGMENT	XDATA
		RSEG	SegNV16
		DS	0

XSTACK		SEGMENT	XDATA
		RSEG	XSTACK
		DS	0

EXTRN	DATA	(XSPL, XSPH)

	CSEG	AT	0
	LJMP	Inisialisasi


SegC_RST	SEGMENT	CODE
		RSEG	SegC_RST

Inisialisasi:

;CM_IE	EQU	10011111B
;CM_IP	EQU	00011111B
;	CLR	P_Alarm
;	JNZ	$+0
;	XCH	A,PSW
;	JNZ	$+0
;	XCH	A,IE
;	ANL	A,#CM_IE
;	JNZ	$+0
;	;;SETB	EA
;	XCH	A,IP
;	ANL	A,#CM_IP
;	JNZ	$+0
;	MOV	A,#ISTACK		; 1 byte dipergunakan untuk #init
;	XCH	A,SP
;	CJNE	A,#7,$+0
;;*
;	;MOV	A,#11111011B		; P_alarm = 0
;	;XCH	A,P1
;	;CJNE	A,#11111011B,$
;	;MOV	A,#0FFH
;	;XCH	A,P3
;	;CJNE	A,#0FFH,$
;;*
;	;MOV	0,#0			; R0 bank 0 <- 0
;	;CJNE	R0,#0,$+00
;	;CJNE	@R0,#0,$+00
;	;MOV	0,#7FH
;	;CJNE	R0,#7FH,$+00		; bank 0 ?
;
;

	CLR	A
	MOV	PSW,A
	MOV	IE,A
	MOV	IP,A
	CPL	A
	MOV	P1,A
	MOV	P3,A
	CLR	P_Alarm
	MOV	SP,#ISTACK		; 1 byte dipergunakan untuk #init
	MOV	R0,#7FH
_InitIRam:
	MOV	@R0,#0FFH
	CJNE	@R0,#0FFH,_IRamGagal
	MOV	@R0,#0
	CJNE	@R0,#0,_IRamGagal
	DJNZ	R0,_InitIRam
	MOV	XSPL,#LOW  (XSTACK-1)
	MOV	XSPH,#HIGH (XSTACK-1)

	LCALL	LCD_Init		; #0
	JZ	RST_POST
_LCDGagal:
	MOV	A,#C_BeepLCD
	AJMP	RST_BeepGagal
_IRamGagal:
	MOV	A,#C_BeepMCS
	AJMP	RST_BeepGagal

RST_POST:
	LCALL	RST_PesanInit
	MOV	A,ISTACK		; pertama kali = #1
	RL	A
	MOV	DPTR,#PTBL_HWPOST-2
	LCALL	JmpWOffset
	JZ	RST_POST
	MOV	R2,ISTACK
	CJNE	R2,#C_NomNVAwal,$+3
	JNC	RST_PeringatanNV
	MOV	R3,A
	AJMP	TerminalGagal

EXTRN	CODE	(SwapPtr16,XPtrCode)
RST_PeringatanNV:
	MOV	DPTR,#PTBL_PemilikNV - (2*C_NomNVAwal)
	MOV	A,ISTACK
	RL	A
	LCALL	XPtrCode
	LCALL	LCD_TlsCStrIni
	DB	FF,'Konfigurasi ',EOS
	LCALL	SwapPtr16
	LCALL	LCD_TulisCStr
	LCALL	LCD_TlsCStrIni
	DB	' cacat !',CR,'[Reset]',EOS

EXTRN	CODE	(Eksklamasi)
_RPI_Eksklamasi:
	LCALL	Eksklamasi
_tunggu_Tya:
	CLR	P_Watchdog
	LCALL	TB_CekIRQRTC			; cek IRQ_RTC dan IRQ_PT
	JNB	F_PT_AdaTombol,_tunggu_Tya
	LCALL	PT_AmbilTombol
	CJNE	A,#C_PT_Ya,_RPI_Eksklamasi
	;SJMP	RST_POST
	AJMP	Inisialisasi

RST_PesanInit:
	LCALL	LCD_TlsCStrIni
	DB	FF,'Inisialisasi Terminal',CR,EOS
	INC	ISTACK
	MOV	R0,ISTACK
	MOV	A,#'.'
	LCALL	LCD_RepTlsChr
	LJMP	LCD_KursorBlok

EXTRN	CODE	(TB_CekIRQRTC)
EXTRN	CODE	(KP_CekNVNama,	KP_CekNVSifat)
PTBL_HWPOST:
	DW	PPI_Init		; #1
	DW	CekBCCROM
	DW	TestVRam
	DW	PB_Init
	DW	JMB_InitDasar
	DW	PT_Reset
	DW	PCF_POST		; #7

;C_NomNVAwal	EQU	($ - (PTBL_HWPOST - 2))/2	; <- ASSEBLER BUG !
C_NomNVAwal	EQU	($ - PTBL_HWPOST + 2)/2		;; tanda () diabaikan

PTBL_NVPOST:
	DW	RTC_Init
	DW	KP_CekNVNama
	DW	KP_CekNVSifat
	DW	TRM_CekNVUmum
	DW	TerminalSiap		; keluar

PTBL_PemilikNV:
	DW	Str_NVWaktu
	DW	Str_NVNama
	DW	Str_NVSifat
	DW	Str_NVUmum

Str_NVNama:	DB	'Nama',EOS

EXTRN	CODE	(Str_NVWaktu, Str_NVSifat, Str_NVUmum)

C_NVUmum_BCCAwal	EQU	0FFH

EXTRN	XDATA	(NV_ModusUmum, NVC_Umum)
EXTRN	CODE	(CChrCpy)

;PUBLIC	TRM_CekNVUmum

TRM_CekNVUmum:
	LCALL	_TRM_BCCUmum
	JZ	_TRM_JemputNVU
	MOV	R6,#LOW  NV_ModusUmum
	MOV	R7,#HIGH NV_ModusUmum
	MOV	DPTR,#DTBL_KfgUmumDef
	MOV	R0,#C_TRM_JmlKfgUmum
	LCALL	CChrCpy
	LCALL	_TRM_BCCUmum
	MOV	A,B
	MOVX	@DPTR,A
	MOV	A,#1
_TRM_JemputNVU:
	MOV	R2,A
	MOV	DPTR,#NV_ModusUmum
	MOVX	A,@DPTR
	ANL	A,#CM_ModusUmum
	ORL	RF_ModusUmum,A
	MOV	A,R2
	RET

_TRM_BCCUmum:
	MOV	B,#C_NVUmum_BCCAwal
	MOV	DPTR,#NV_ModusUmum
	MOVX	A,@DPTR
	XRL	B,A
	MOV	DPTR,#NVC_Umum		; Modus Remote tidak disertakan
	MOVX	A,@DPTR
	XRL	A,B
	RET

PUBLIC	TRM_SimpanModusUmum

TRM_SimpanModusUmum:
	MOV	A,RF_ModusUmum
	ANL	A,#CM_ModusUmum
	MOV	DPTR,#NV_ModusUmum
;TRM_UpdateBCCUmum:
	MOV	R2,A
	MOVX	A,@DPTR
	XRL	A,R2
	XCH	A,R2
	MOVX	@DPTR,A
	MOV	DPTR,#NVC_Umum
	MOVX	A,@DPTR
	XRL	A,R2
	MOVX	@DPTR,A
	CLR	A
	RET

EXTRN	NUMBER	(CD_ModusUmum, CM_ModusUmum, CD_RMT_Modus)
EXTRN	DATA	(RF_ModusUmum)

DTBL_KfgUmumDef:
	DB	CD_ModusUmum
	DB	CD_RMT_Modus			; = Modus Remote

C_TRM_JmlKfgUmum	EQU	2
; Meng-halt TRM karena terjadi kegagalan H/W, dengan menampilkan kode pada LCD
; M: R2=kode utama, R3=subkode

TerminalGagal:
	CLR	EA			; lumpuhkan semua intr.
	CLR	P_Alarm			; aktifkan alarm
	MOV	SP,#ISTACK-1
	LCALL	LCD_TlsCStrIni
	DB	FF,'Terminal Gagal !',CR,'Kode : ',EOS
	MOV	A,R2
	LCALL	_Rst_StrHex
	;MOV	A,#'-'
	;LCALL	LCD_TulisChr
	MOV	A,R3
	LCALL	_Rst_StrHex
	MOV	A,#C_BeepTRM

; Meng-halt TRM karena terjadi kegagalan H/W, dengan membunyikan kode kegagalan
; M: A=kode beep
RST_BeepGagal:
	MOV	R0,#0
	;MOV	IE,R0			; lumpuhkan semua intr.
	;CLR	P_Alarm			; aktifkan alarm
_StatusBeep:
	MOV	C,ACC.0
	RL	A
	MOV	R1,#C_DurasiBeep

; 1/F = Hi[512+2] + Lo[(512+2)+2] = 1030sk -> F == 895Hz (Fosc == 11,0592Mhz)
C_DurasiBeep	EQU	224	;== (921600/1030/[4]) -> jml loop untuk 250 ms

_Beep:	DJNZ	R0,$
	MOV	P_Spkr,C
	DJNZ	R0,$
	CLR	P_Spkr
	CPL	P_Watchdog
	DJNZ	R1,_Beep
	SJMP	_StatusBeep		; loop tanpa henti !

; mencetak hex-chr pada LCD
; M: A=hex
_Rst_StrHex:
	LCALL	ByteKeHexAsc
	LCALL	LCD_TulisChr
	MOV	A,R0
	LJMP	LCD_TulisChr

EXTRN	XDATA	(V8_KP_Status)	;, NV_ModusUmum)

TestVRam:
	MOV	DPTR,#SegV8
	MOV	R6,#low  SegNV16
	MOV	R7,#high SegNV16
	;LCALL	TestXRam
	;RET

TestXRam:
	MOV	R4,DPL
	MOV	R5,DPH
__TXR1:	MOV	A,#0FFH
	MOVX	@DPTR,A
	MOVX	A,@DPTR
	CJNE	A,#0FFH,__TXRE			; @XRAM bisa ditulis 0FFH ?
	MOV	A,DPL
	ADD	A,DPH				; A <- Psudo Random
	MOVX	@DPTR,A
	INC	DPTR				; @XRAM selanjutnya
	MOV	A,R6
	CJNE	A,DPL,__TXR1
	MOV	A,R7
	CJNE	A,DPH,__TXR1
	MOV	DPL,R4
	MOV	DPH,R5
__TXR2:	MOVX	A,@DPTR
	CLR	C
	SUBB	A,DPH
	CJNE	A,DPL,__TXRE			; #random ditulis = terbaca ?
	CLR	A
	MOVX	@DPTR,A
	MOVX	A,@DPTR
	JNZ	__TXRE				; @XRAM bisa ditulis 00H ?
	INC	DPTR
	MOV	A,R6
	CJNE	A,DPL,__TXR2
	MOV	A,R7
	CJNE	A,DPH,__TXR2
	CLR	A
	RET
__TXRE:	MOV	A,#1
	RET

CekBCCROM:
	MOV	B,#C_BCCAwal
	MOV	DPTR,#0
__CBR:	CLR	A
	MOVC	A,@A+DPTR
	XRL	B,A
	INC	DPTR
	MOV	A,#LOW  UjungPrg
	CJNE	A,DPL,__CBR
	MOV	A,#HIGH UjungPrg
	CJNE	A,DPH,__CBR
	;MOV	A,B
	MOV	A,#0				; BCC belum ditetapkan !
	RET


	CSEG	AT	KapasitasROM-1
UjungPrg:
	DB	C_BCCROM


	END
;EndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEnd
;EndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEnd

;EXTRN	NUMBER	(CS_TrmGagal, C_PB_UCFrekIrq, CS_Interupsi)
;EXTRN	BIT	(F_PS_Aktif, F_PS_SUlang)
;EXTRN	CODE	(PembangkitSuara, PS_Reset, PS_SetSulang)
, PT_AmbilTombol, PS_TimpaSuara)
, LCD_SetXY)

RST_PesanNV:
	LCALL	LCD_Cls
	LCALL	LCD_TulisCStr
	MOV	A,#40H	; + 14
	LCALL	LCD_SetXY
	LCALL	LCD_TulisCStr
	MOV	A,#CS_Interupsi
	LCALL	PS_TimpaSuara
	LCALL	LCD_Cls
_tunggu_Tya:
	CLR	P_Watchdog
	JNB	F_PT_AdaTombol,_tunggu_Tya
	LCALL	PT_AmbilTombol
	CJNE	A,#C_PT_Ya,_tunggu_Tya
	LCALL	LCD_Cls
	CLR	C
	RET

STR_RST_Lanjut:
	DB	'<Lanjut>'

TerminalGagal:
	MOV	R7,A
	LCALL	LCD_cls
	MOV	DPTR,#PSN_GGL1
	LCALL	LCD_TulisCStr
	MOV	A,R7
	LCALL	ByteKeDesAsc
	JZ	_tg_10an
	LCALL	LCD_TulisChr
_tg_10an:
	MOV	A,R1
	LCALL	LCD_TulisChr
	MOV	A,R0
	LCALL	LCD_TulisChr
	MOV	DPTR,#PSN_GGL1
	LCALL	LCD_TulisCStr
LCDTakSiap:
BEEP:
	MOV	IE,#0			;lumpuhkan semua intr.
	CLR	P_Alarm
	LCALL	PS_Reset
	MOV	A,#CS_TrmGagal
	LCALL	PS_SetSulang
	SETB	F_PS_SUlang
	MOV	TCON,#0
	MOV	TMOD,#00100010b		;abaikan !int0,pewaktu,8-BIT isi-ulang
	MOV	tl0,#0FFh
	MOV	tl1,tl0
	MOV	th0,#C_PB_UCFrekIrq
	MOV	th1,th0
	MOV	TCON,#01010000b		; tr0 = tr1 = 1
_trmggl:
	MOV	A,tl0
	ADD	A,tl1
	MOV	C,ACC.5
	MOV	P_Watchdog,C
	MOV	A,TCON
	ANL	A,#10100000b		; tf0 & tf1
	JZ	_trmggl
	MOV	TCON,#01010000b
	LCALL	PembangkitSuara
	SJMP	_trmggl
PSN_GGL1:
	DB	'Gangguan internal, kode : ',EOS
PSN_GGL2:
	DB	cr,'Terminal tidak dapat difungsikan !',EOS
