$INCLUDE(OS.DEF)
$INCLUDE(SCH.DEF)
$INCLUDE(PEWAKTU.DEF)

CA_PCF_ctrl	EQU	0
CA_PCF_dtk	EQU	2		;yang pertama = dtk
C_PCF_ctrl	EQU	00000000b	;mask=off

;C_RTC_OfsKabisat	EQU	C_RTC_ThnAwal MOD 4
;C_RTC_MaxTahun	EQU	C_RTC_PjgThn-1
;C_RTC_Thn_Lo	EQU	C_RTC_ThnAwal MOD 100
;C_RTC_Thn_Hi	EQU	C_RTC_ThnAwal / 100

PUBLIC	D_RTC_tgl, D_RTC_bln, D_RTC_thn, D_RTC_jam, D_RTC_mnt, D_RTC_dtk
PUBLIC	RealTimeClock
PUBLIC	RTC_Init, RTC_CekSetWaktu, PCF_JemputWaktu, PCF_SimpanWaktu
PUBLIC	F_RTC_DiTunggu, IE_RTC, IRQ_RTC
PUBLIC	F_WDT_RTC, D_WDT_RTC

EXTRN	BIT	(IE_KP, IE_PB)
EXTRN	CODE	(ByteKeBCD, BCDKeByte)
EXTRN	CODE	(I2CM_TxStop, I2CM_TxInitKata, I2CM_RxInitKata)
EXTRN	CODE	(I2CM_RxByte, I2CM_RxByteAkhir, I2CM_TxByte, I2CM_TxByteAkhir)

SegD_RTC		SEGMENT	DATA
			RSEG	SegD_RTC
; Urutan Penting !
;D_RTC_hari:	DS	1	; 0..6, 0=minggu, 6=sabtu
D_RTC_dtk:	DS	1	; 0..59
D_RTC_mnt:	DS	1	; 0..59
D_RTC_jam:	DS	1	; 0..23
D_RTC_tgl:	DS	1	; 1..31 (maks)
D_RTC_bln:	DS	1	; 1..12
D_RTC_thn:	DS	1	; 0..(C_RTC_ThnAkhir-C_RTC_ThnAwal)

D_WDT_RTC:	DS	1

SegB_RTC	SEGMENT	BIT
		RSEG	SegB_RTC

F_RTC_DiTunggu:	DBIT	1
F_WDT_RTC:	DBIT	1
IRQ_RTC:	DBIT	1
IE_RTC:		DBIT	1

;PUBLIC	NV_RTC_thn
;SegNV16		SEGMENT	XDATA
;		RSEG	SegNV16
;NV_RTC_thn:	DS	1

EXTRN	XDATA	(NV_RTC_thn)


SegC_ISRRTC	SEGMENT	CODE
		RSEG	SegC_ISRRTC

RealTimeClock:
	;PUSH	PSW
	;PUSH	ACC
	;;PUSH	IE
	SETB	F0
	JBC	IE_KP,_rtc_dtk			; cegah KP_LOG membaca waktu
	CLR	F0
_rtc_dtk:
	INC	D_RTC_dtk
	MOV	A,#60
	CJNE	A,D_RTC_dtk,_rtcisr_q
	MOV	D_RTC_dtk,#0
;_rtc_mnt:
	INC	D_RTC_mnt
	;MOV	A,#60
	CJNE	A,D_RTC_mnt,_rtcisr_q
	MOV	D_RTC_mnt,#0
;_rtc_jam:
	INC	D_RTC_jam
	MOV	A,#24
	CJNE	A,D_RTC_jam,_rtcisr_q
	MOV	D_RTC_jam,#0
;_rtc_hari:
;	INC	D_RTC_hari
;	MOV	A,#7
;	CJNE	A,D_RTC_hari,_rtc_TglMaks
;	MOV	D_RTC_hari,#0
;_rtc_TglMaks:
	MOV	A,D_RTC_thn
	ADD	A,#C_RTC_ThnAwal MOD 4
	RRC	A
	ORL	C,ACC.0			; thn MOD 4 = 0 -> kabisat(C=0)
	MOV	A,D_RTC_bln
	LCALL	TanggalMaks
	INC	A
;_rtc_tgl:
	INC	D_RTC_tgl
	CJNE	A,D_RTC_tgl,_rtcisr_q
	MOV	D_RTC_tgl,#1
;_rtc_bln:
	INC	D_RTC_bln
	MOV	A,#13
	CJNE	A,D_RTC_bln,_rtcisr_q
	MOV	D_RTC_bln,#1
;_rtc_thn:
	MOV	A,D_RTC_thn
	INC	A
	CJNE	A,#C_RTC_PjgTahun,_rtc_nvthn
	CLR	A
_rtc_nvthn:
	MOV	D_RTC_thn,A
	;PUSH	DPL
	;PUSH	DPH
	MOV	DPTR,#NV_RTC_thn
	MOVX	@DPTR,A
	;POP	DPH
	;POP	DPL
_rtcisr_q:
	JNB	F0,_rtcisr_qx
	SETB	IE_KP
_rtcisr_qx:
	;;POP	IE
	;POP	ACC
	;POP	PSW
	;JBC	F_RTC_SimpanWkt,PCF_SimpanWaktu
	RET

SegC_RTC	SEGMENT	CODE
		RSEG	SegC_RTC

; F: Menjemput nilai Waktu, meresetnya jika cacat
RTC_Init:
	CLR	IRQ_RTC
	SETB	IE_RTC
	MOV	DPTR,#NV_RTC_thn
	MOVX	A,@DPTR
	ADD	A,#-C_RTC_PjgTahun		; 0H..0FFH < 100H (=256) !
	JC	_PCF_RstNV			; nilai thn diizinkan (=0) ?
	LCALL	PCF_JemputWaktu
	JC	_PCF_RstNV
	LCALL	RTC_CekSetWaktu
	JNZ	_PCF_RstNV
	RET

_PCF_RstNV:
	INC	D_RTC_tgl			; tanggal 1
	INC	D_RTC_bln			; bulan januari
	LCALL	PCF_SimpanWaktu
	MOV	A,#1
	RET


; F: Memeriksa akses terhadap PCF dan IRQ 1Hz yang dibangkitkannya
; K: A:	0 = Baik
;	1 = Jalur Bus I2C bermasalah
;	2 = Akses data ke/dari PCF bermasalah
;	3 = Priode (1/F) IRQ < toleransi
;	4 = Priode (1/F) IRQ > toleransi

	PUBLIC	PCF_POST
PCF_POST:
	MOV	R2,#1
	JNB	I2C_SDA,_PCF_Gagal
	JNB	I2C_SCL,_PCF_Gagal

;	MOV	A,#9			; 8-bit data, 1-bit ACK
;__PastikanStop:
;	LCALL	I2CM_TxStop
;	JNC	_PCF_CekAkses
;	DJNZ	ACC,__PastikanStop
;	SJMP	_PCF_Gagal

_PCF_CekAkses:
	INC	R2				; = #2
	MOV	A,#CA_PCF8583
	MOV	B,#CA_PCF_ctrl
	LCALL	I2CM_RxInitKata
	JC	_PCF_Gagal
	LCALL	I2CM_RxByteAkhir
	JC	_PCF_Gagal
	MOV	A,#CA_PCF8583
	MOV	B,#CA_PCF_ctrl
	LCALL	I2CM_TxInitKata
	JC	_PCF_Gagal
	MOV	A,#C_PCF_ctrl
	LCALL	I2CM_TxByteAkhir
	JC	_PCF_Gagal

; Memeriksa periode antan IRQ degan bantuan WDT_RTC (di PewaktuBersama)

;_PCF_CekTIRQ:
	MOV	D_WDT_RTC,#C_WDT_RTCMax		; batas sinkronisasi irq
	MOV	C,IRQ_RTC			; 2 loop jika IRQ pernah aktif
__SinkronWDT:
	CLR	F_WDT_RTC
___SW:	CLR	P_WatchDog
	JBC	IRQ_RTC,__PriodeIRQ		; anggap sudah sinkron jika = 1
	JNB	F_WDT_RTC,___SW
	JNB	IRQ_RTC,___PI4			; WDT=1, IRQ=0 -> T > Tmaks
	CLR	IRQ_RTC
__PriodeIRQ:
	JBC	CY,__SinkronWDT			; pasti sinkron (=0) ?
	CLR	F_WDT_RTC			; <- WDT=0, IRQ=0
___PI1:	CLR	P_WatchDog
	JNB	IRQ_RTC,___PI2
	JB	F_WDT_RTC,___PI3		; WDT=1, IRQ=1 -> T < Tmin
	CLR	A				; WDT=0, IRQ=1 -> mi \< T \< ma
	RET

___PI2:	JNB	F_WDT_RTC,___PI1
	JNB	IRQ_RTC,___PI4
___PI3:	INC	R2
___PI4:	INC	R2				; #3 = lambat, #4 = cepat

_PCF_Gagal:
	MOV	A,R2
	RET	

RDtk	EQU	R2
RMnt	EQU	R3
RJam	EQU	R4
RTgl	EQU	R5
RBln	EQU	R6
RThn	EQU	R7

USING	0

ARDtk	EQU	AR2
ARJam	EQU	AR4
ARTgl	EQU	AR5
ARBln	EQU	AR6
ARThn	EQU	AR7

RTC_CekSetWaktu:
	CJNE	RDtk,#60,$+3
	JNC	__RCSWCacat		; dtk < 60 (0-59) ?
	CJNE	RMnt,#60,$+3
	JNC	__RCSWCacat		; mnt < 60 (0-59) ?
	CJNE	RJam,#24,$+3
	JNC	__RCSWCacat		; jam < 24 (0-23) ?
	CJNE	RBln,#0,$+3+2		; bln <> 0 ?
	SJMP	__RCSWCacat
	CJNE	RBln,#13,$+3
	JNC	__RCSWCacat		; bln \< 12 ?
	MOV	A,RThn
	ADD	A,#-C_RTC_PjgTahun	; 00H=256D !
	JC	__RCSWCacat		; thn \< Tahun Akhir (CF=0) ?
	CJNE	RTgl,#0,$+3+2		; tgl <> 0 ?
	SJMP	__RCSWCacat
	LCALL	HariPerbulan		; RET: CF=0, A=PjgHari
	SUBB	A,RTgl
	JC	__RCSWCacat		; tgl \< hari per bulan ?
	MOV	A,RThn
	MOV	DPTR,#NV_RTC_thn
	CLR	IE_PB			; lumpuhkan sumber intr KEP
	MOV	D_RTC_dtk,RDtk
	MOV	D_RTC_mnt,RMnt
	MOV	D_RTC_jam,RJam
	MOV	D_RTC_tgl,RTgl
	MOV	D_RTC_bln,RBln
	MOV	D_RTC_thn,RThn
	SETB	IE_PB			; mampukan sumber intr KEP
	MOVX	@DPTR,A
	CLR	A
	RET
__RCSWCacat:
	MOV	A,#KS_ParamCacat
	RET


EXTRN	NUMBER	(KS_ParamCacat)

; Kedua Subrutin dibawah ini hanya dijalankan pada awal_IRQ 1 Hz

PCF_JemputWaktu:
;	LCALL	I2CM_TxStop
;	JC	__PJWQ
	MOV	A,#CA_PCF8583
	MOV	B,#CA_PCF_dtk
	MOV	R0,#ARDtk
	LCALL	I2CM_RxInitKata
	JC	__PJWQ			; F0=1 -> gagal membuat start
__PJW1:	LCALL	I2CM_RxByte		; baca: dtk, mnt, jam
	CJNE	R0,#ARJam,__PJW2
	ANL	A,#3FH
__PJW2:	LCALL	BCDKeByte
	MOV	@R0,A
	INC	R0
	CJNE	R0,#ARTgl,__PJW1
	LCALL	I2CM_RxByte		; = thn dan tgl
	MOV	RTgl,A
	ANL	A,#3FH			; BIT 0..5 = tgl, BIT 6..7 = 4-thn-an
	LCALL	BCDKeByte
	XCH	A,RTgl
	RL	A
	RL	A
	ADD	A,#-(C_RTC_ThnAwal MOD 4)

	MOV	RThn,A
	MOV	DPTR,#NV_RTC_thn
	MOVX	A,@DPTR			; = thn_lama
	XCH	A,RThn
	CLR	C
	SUBB	A,RThn			; hanya menghitung bit 0..1
	ANL	A,#11b			; Mod 4
	ADD	A,RThn
	MOV	RThn,A			; Thn = lama + (|baru-lama| MOD 4)

	LCALL	I2CM_RxByteAkhir	; = bln
	JC	__PJWQ			; F0=1 -> gagal membuat stop
	ANL	A,#11111b
	LCALL	BCDKeByte
	MOV	RBln,A
__PJWQ:	RET				; CY=1 -> gagal


PCF_SimpanWaktu:
	MOV	A,#CA_PCF8583
	MOV	B,#CA_PCF_Ctrl			; = register kendali
	LCALL	I2CM_TxInitKata
	JC	__PSWQ
;__PSW_StopCacah:
	MOV	A,#C_PCF_ctrl OR 80h
	LCALL	I2CM_TxByteAkhir		; stop pencacah
	MOV	A,#CA_PCF8583
	MOV	B,#CA_PCF_dtk
	LCALL	I2CM_TxInitKata

	MOV	DPTR,#NV_RTC_Thn
	MOV	R0,#D_RTC_dtk
	MOV	R1,#ARDtk
	;CLR	IE_RTC				; lumpuhkan intr. RTC
__PSW1:	MOV	A,@R0
	LCALL	ByteKeBCD
	MOV	@R1,A
	INC	R0
	INC	R1
	CJNE	R0,#D_RTC_Thn,__PSW1
	MOV	A,@R0
	;SETB	IE_RTC				; mampukan intr. RTC
	MOVX	@DPTR,A
	ADD	A,#C_RTC_ThnAwal MOD 4
	ANL	A,#11b				; BIT 0 dan 1 saja
	RR	A
	RR	A				; jadikan th = BIT 6 dan 7
	ORL	ARTgl,A

	MOV	R0,#ARDtk
__PSW2:	MOV	A,@R0
	LCALL	I2CM_TxByte
	INC	R0
	CJNE	R0,#ARBln,__PSW2
	MOV	A,@R0
	LCALL	I2CM_TxByteAkhir

;__PSW_PulihkanCacah:
	MOV	A,#CA_PCF8583
	MOV	B,#CA_PCF_ctrl
	LCALL	I2CM_TxInitKata
	MOV	A,#C_PCF_ctrl AND 7Fh
	LCALL	I2CM_TxByteAkhir		; mampukan pencacah
__PSWQ:	RET					; CY=1 -> gagal

$INCLUDE(RTCPLUS.INC)

	END
