$INCLUDE(SCH.DEF)
$INCLUDE(PEWAKTU.DEF)

PUBLIC	IE_PB, IRQ_PB
PUBLIC	PB_init

EXTRN	BIT	(F_WDT_RTC, F_PRN_WDT)
EXTRN	DATA	(D_WDT_RTC, D_PRN_WDT)
EXTRN	BIT	(F_KP_Selip)
EXTRN	BIT	(IE_KP, IE_RTC, IE_PT)
EXTRN	BIT	(IRQ_KP, IRQ_PT, IRQ_RTC)
EXTRN	BIT	(F_PS_Aktif, F_RTC_DiTunggu)
EXTRN	BIT	(F_LCD_FlipKedip)
EXTRN	DATA	(D_LCD_FlipKedip)
EXTRN	DATA	(D_PT_DCCuplik, D_KP_DCPantau)
EXTRN	CODE	(PembangkitSuara, RealTimeClock)
EXTRN	CODE	(PapanTombol, KP_Pantau)

;==================================
;vektor interupsi pewaktu_bersama
;==================================

	CSEG	AT	IVec_PB
	LJMP	PembangkitSuara

SegC_PsIsr	SEGMENT	CODE
		RSEG	SegC_PsIsr
		DS	0

PewaktuBersama:

;************************************
; Disini letak rutin PembangkitSuara
;************************************

SegC_PbIsr	SEGMENT	CODE
		RSEG	SegC_PbIsr
		DS	0

;------ F: Menghitung saat pengaktifan ISR_KP
_PB_CekDcKep:
	DJNZ	D_KP_DCPantau,_PB_CekIrqKep
	MOV	D_KP_DCPantau,#C_KP_DCPantau

;------ F: Memeriksa saat dibangkitkannya IRQ_PT dan sub-pewaktu-bersama
	DJNZ	D_PT_DCCuplik,_CekKepSelip
	SETB	IRQ_PT

;------ F: Selalu membuat P_Watchdog = 1
	SETB	P_Watchdog

;------ F: Memeriksa saat dibangkitkannya IRQ_RTC
;_PB_CekIRQRTC:
	JB	P_IRQ_RTC,__PCIR_0ke1
;__PCIR_1ke0:
	JB	F_RTC_Ditunggu,_PB_CekRTCTmax	; sudah 1-ke-0 (=0) ?
	SETB	F_RTC_DiTunggu			; berikutnya tunggu 0-ke-1
	SETB	IRQ_RTC				; = bangkitkan IRQ

;------ F: Memeriksa Tmin IRQ_RTC (relatif terhadap PB/PT_IRQ dan toleransi)
	MOV	D_PT_DCCuplik,PSW		; = PUSH PSW
	XCH	A,D_WDT_RTC			; sekaligus PUSH ACC
	ADD	A,#-(2+C_WDT_RTCMax-C_WDT_RTCMin)
	JNC	___RstWDTRTC
	SETB	F_WDT_RTC			; <- Tirq < Tmin (cepat)
___RstWDTRTC:
	MOV	A,#C_WDT_RTCMax
	XCH	A,D_WDT_RTC			; sekaligus POP ACC
	MOV	PSW,D_PT_DCCuplik		; = POP PSW

;-----	F: Menghitung PRN TOut
	DJNZ	D_PRN_WDT,_PB_RstPTCuplik
	SETB	F_PRN_WDT
	SJMP	_PB_RstPTCuplik

__PCIR_0ke1:
	CLR	F_RTC_DiTunggu			; berikutnya tunggu 1-ke-0

;------ F: Memeriksa Tmax IRQ_RTC (relatif terhadap PB/PT_IRQ dan toleransi)
_PB_CekRTCTmax:
	DJNZ	D_WDT_RTC,_PB_RstPTCuplik
	SETB	F_WDT_RTC			; <- Tirq > Tmax (lambat)
_PB_RstPTCuplik:
	MOV	D_PT_DCCuplik,#C_PT_DCCuplik

;------ F: Memeriksa TxIdle RMT_TxIsr, mengaktifkannya jika TOut
EXTRN	DATA	(D_RMT_AutoTI)
EXTRN	BIT	(F_RMT_TxTidur)

_PB_CekAutoTI:
	;;JBC	F_RMT_TxIdle,___CAT_Q		; sebelumnya sudah 0 ?
	DJNZ	D_RMT_AutoTI,___CAT_Q		; sudah TimeOut ?
	JBC	F_RMT_TxTidur,__PB_AktifkanTI	;; dan memang tidur ?
___CAT_Q:

;------ F: Mengaktikan bendera FlipKedip untuk LCD jika terjadi timeout
_PB_CekFlipKdp:
	DJNZ	D_LCD_FlipKedip,___CFK_Q
	SETB	F_LCD_FlipKedip
___CFK_Q:

;------ F: Memeriksa terjadinya kondisi selip pada ISR_KP
_CekKepSelip:
	JNB	IRQ_KP,_CekIeKep		; IRQ lama sudah dilayani ?
	CLR	IRQ_KP
	SETB	F_KP_Selip			; belum -> nyatakan selip
_CekIeKep:
	JBC	IE_KP,_IsrKep
	SETB	IRQ_KP				; <- tunda
	RETI

;------ F: Menjalankan IRQ_KP yg tertunda, jika IE_KP mengizinkan
_PB_CekIrqKep:
	JBC	IRQ_KP,_CekIeKep
	RETI

; Bagian dari _PB_CekAutoTI
__PB_AktifkanTI:
	SETB	TI
	SJMP	___CAT_Q


_IsrKep:

SegC_KPIsr	SEGMENT	CODE
		RSEG	SegC_KPIsr
		DS	0

;********************************
; Disini letak rutin Pantau
;********************************


SegC_PbInit	SEGMENT	CODE
		RSEG	SegC_PbInit

;--------------------------------------------------------------------
;F: Menginisialisasi dan Memeriksa penjalanan PewaktuBersama
;   (ditujukan untuk pewaktu eksternal)
;K:  A:	0 = Baik
;	1 = IRQ tidak pernah aktif hingga Tmax+ (Pewaktu/MCS51 gagal)
;	2 = ISR tidak dapat dijalankan (MCS51 gagal)
;	3 = Periode keaktifan IRQ > Tmax (terlalu lambat)
;	4 = Periode keaktifan IRQ < Tmin (terlalu cepat)
;--------------------------------------------------------------------

PB_init:
	MOV	IE,#80h			; hanya EA = 1

IF (MCS = 51)
;pada 8051 pewaktuan bersama berasal dari intr. eksternal 0
IRQ_PB	EQU	ie0
IE_PB	EQU	ex0
	SETB	it0		; penyulut = tebing turun
	;CLR	px0		; perioritas = rendah
ENDIF

IF (MCS = 52)
;pada 8052 pewaktuan bersama berasal dari intr. timer 1
IRQ_PB	EQU	tf1
IE_PB	EQU	et1
	ANL	TMOD,#0Fh
	ORL	TMOD,#0010b*16		; pewaktu internal, 8-BIT, isi-ulang
	MOV	th1,#-(Fcpu/(PB_FrekIrq/100))
					; Fcpu=Fosc/12 (x100Hz !)
	MOV	tl1,TH1
	;CLR	pt1			; perioritas = rendah
	SETB	tr1			; mampukan pewaktu
ENDIF

	MOV	A,#1
	MOV	R0,#((Fcpu/(PB_FrekIrq/100))*(toleransi+100))/200
	CLR	IRQ_PB
_PB_CekIrq:
	DJNZ	R0,_PB_CekIrq
	JNB	IRQ_PB,_PB_HW_Gagal	; gagal jika belum aktif

;_PB_CekIsr:
	MOV	D_PT_DCCuplik,A		; = 1
	MOV	D_KP_DCPantau,A
	CLR	IRQ_KP
	SETB	IE_PB			; mampukan ISR
	INC	A			; <- disini ISR belum jalan
	CLR	IE_PB			; lumpuhkan ISR (yg telah dijalankan)
	JNB	IRQ_KP,_PB_HW_Gagal	; gagal jika ISR tidak dijalankan

	INC	A			; = 3
	MOV	R0,#((Fcpu/(PB_FrekIrq/100))*(toleransi+100))/200 - 1
	CLR	IRQ_PB
_PB_TawalIrq1:
	JNB	IRQ_PB,_PB_TawalIrq1	; sinkronisasi
	CLR	IRQ_PB
_PB_CekTmaks:
	DJNZ	R0,_PB_CekTmaks
	JNB	IRQ_PB,_PB_HW_Gagal	; gagal jika belum aktif (lambat !)

	INC	A			; = 4
	MOV	R0,#((Fcpu/(PB_FrekIrq/100))*(100-toleransi))/200 - 1
	CLR	IRQ_PB
_PB_TawalIrq2:
	JNB	IRQ_PB,_PB_TawalIrq2	; sinkronisasi
	CLR	IRQ_PB
_PB_CekTmin:
	DJNZ	R0,_PB_CekTmin
	JB	IRQ_PB,_PB_HW_Gagal	; gagal jika sudah aktif (cepat !)
	SETB	IE_PB			; mampukan ISR
	CLR	A
_PB_HW_Gagal:
	RET				; A = Status sukses/gagal

	END

;|	X	~	X	|	|	|
;|	X	~<!!!!!!>	|	|	<- daerah kritis Tmin
;|   ?	<---N---~---3--->   N	|  N-1	|  N-2	<- durasi Tmin ( T >/ Tmin)
;|<--?--X---N---~>  3	X   N	|  N-1	|  N-2	<- durasi Tmin ( T >/ Tmin)
;|   ?	<---N---~>  3	X   N	|  N-1	|  N-2	<- gagal mendeteksi T < Tmin
;						   (sementara)
;
;|	X	~	|	|	X	|
;|	X	~	|	|<!!!!!!>	<- daerah kritis Tmaks
;|   ?	<---N---~---3---|---2---|---1--->   N	<- durasi Tmaks ( T \< Tmaks)
;|<--?--X---N---~---3---|---2---|>  1	|   N	<- durasi Tmaks ( T \< Tmaks)
;|<--?--X---N---~---3---|---2---|---1--->   N	<- gagal mendeteksi T > Tmaks
;						   (sementara)
;Ket:	X = Titik terdeteksinya transisi (T)
;	| = Titik pendeteksian transisi
;	~ = Selang waktu sebelum mencapai cacah=3
;	? = Nilai cacahan (yg diizinkan) sebelum transisi ke-X terdeteksi
;	N = nilai cacah awal yang didasarkan Tmaks
;	< = Transisi ke-x yg sebenarnya
;	> = Transisi ke-(x+1) yg sebenarnya
;	Tmin  = Tnom - (1 priode antar deteksi)
;	Tmaks = Tnom + (1 priode antar deteksi)
