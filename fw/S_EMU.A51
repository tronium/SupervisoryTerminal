$NOLIST
$NOMOD51
$INCLUDE(E:\C51\ASM\REG52.INC)
$LIST
; Di PCB Selektor kartu ada pada ACC !
; Reg Terpakai di-PUSH
; Pakai percabangan PUSH
; pengefisiensian kode dan siklus
; ukuran stack dijaga 11+2 byte
; *BUG: -> residu + TxIdle + RxAvail = 2+6+6 !
; penentu hasil FinBuf dipindah ke bagian penyimpan CBuf
; *SALAH: memperpanjang proses RxAvail
; pengurangan 1 byte register brk dengan menggunakan tmpbuf sebacai pencacah
; pengubahan letak percabangan EUT (OK)
; 6. 01:28am 03-11-1999 Modifikasi ringan
;    01:37am 03-14-1999 Modifikasi instruksi bersama
; 7. 01:45am 03-14-1999 EUR tidak memakai @pushjmp; lebih cepat; stack=7+2
;    18:36pm 03-15-1999 EUT juga
;    22:33pm 03-16-1999 KRD hanya diaktifkan oleh EUT; stack = KRD+Reintr=9
;			Tundaan TxIdle \< 1 SDU tercepat
;			CekDCE ditunda jika RxAvail =1, berbagi TimeSlice
;			Modifikasi Pendeteksian Break
;			RxData disimpan dahulu baru CekCBuf
;    05:57am 03-18-1999 finish
; 8. 02:31am 04-18-1999 Modifikasi EUR: paling lama 18 sk
; 9. 02:32am 04-18-1999 Modifikasi EUT: konfig bit Proses (SK+CODE lebih baik)
; 10. 01:40am 04-19-1999 Layanan RI_EU/TI_EU diluar EUART
; 11. 05:39am 05-13-1999 Layanan RI_EU/TI_EU didalam EUART
;
; Proses Rx
; data	start	cek	proses
; 0	0*	0	cari stop
; 0	1	0*	cari start
; 0*	1	1*	cek start
; 1	1*	-	cuplik D0..D6
; 1	0	0*	cuplik D7
; 1*	0	1**	cek paritas
; 0	0*	1*	cek stop

; Proses Tx
; P2	P1	P0	proses
; 0	0*	0	cek DCE
; 0*	1	0	kirim start, P1 -> jml stop
; 1	-	0*	kirim D0..D7, P2 -> keberadaan prts
; 1*	-	1	kirim paritas
; 0	1*	1	kirim stop1
; 0	0	1*	kirim stop2

$INCLUDE(SCH.DEF)
$INCLUDE(REMOTE.DEF)

;TR_JMB		EQU	TR0
;IE_JMB		EQU	ET0
;IP_JMB		EQU	PT0
PUBLIC	IE_EU, TR_EU
TR_EU		EQU	TR0
TF_EU		EQU	TF0
IE_EU		EQU	ET0
IP_EU		EQU	PT0
TH_EU		EQU	TH0
TL_EU		EQU	TL0

EXTRN	XDATA	(HW_PPI_PA)


PUBLIC	BA_JMB_Status

PUBLIC	D_JMB_NomKartu
PUBLIC	D_JMB_RxPtr_K, D_JMB_RxPtr_B
PUBLIC	D_JMB_TxPtr_K, D_JMB_TxPtr_B

SegD_JMB	SEGMENT	DATA
		RSEG	SegD_JMB

D_JMB_NomKartu:	DS	1
D_JMB_RxPtr_K:	DS	1
D_JMB_RxPtr_B:	DS	1
D_JMB_TxPtr_K:	DS	1
D_JMB_TxPtr_B:	DS	1

SegD_EUART	SEGMENT	DATA
		RSEG	SegD_EUART

D_EUR_Intr:	DS	1
D_EUT_Intr:	DS	1
D_EU_RxBuf:	DS	1		; hasil byte lengkap yg diterima
D_EU_TxBuf:	DS	1		; BIT-BIT yg akan dikirim
D_EUT_CchBit:	DS	1


SegBA_EUART	SEGMENT	DATA	BITADDRESSABLE
		RSEG	SegBA_EUART

F_EU_8Bit	EQU	$.0		; 1 = 8-BIT, 0 = 7-BIT
F_EU_2Stop	EQU	$.1		; 1 = 2-BIT Stop
F_EU_Prts	EQU	$.2		; 1 = dengan paritas
F_EU_TPrts	EQU	$.3		; 1 = paritas ganjil
F_EU_Baud	EQU	$.4		; bit 4..7; memungkinkan 16 kecepatan
BA_EU_Konfig:	DS	1

;TI_EU		EQU	$.0		; 1= selesai/siap_untuk mengirim byte
RI_EU		EQU	$.1		; 1= byte telah diterima
F_EUT_Pro0	EQU	$.2
F_EUT_Pro1	EQU	$.3
F_EUT_Pro2	EQU	$.4
F_EUR_ProCek	EQU	$.5
F_EUR_ProStart	EQU	$.6
F_EUR_ProData	EQU	$.7
BA_EU_Proses:	DS	1

BA_EUR_TmpBuf:	DS	1		; olahan sementara

;PUBLIC	F_JMB_TxFull
PUBLIC	F_JMB_RTS, F_JMB_Dsroff, F_JMB_TxTOut

PUBLIC		FM_JMB_Status, FM_JMB_Runtuh

;F_JMB_TxFull:	DBIT	1
;F_JMB_RxBrk:	DBIT	1		; Break _pernah_ terdeteksi
;F_EU_RxPrts:	DBIT	1		; paritas dari byte yg diterima

BA_JMB_Status	EQU	24H
		BSEG	AT	2+((BA_JMB_Status-20H)*8)

F_EU_TxPrts:	DBIT	1		; paritas dari byte yg dikirim
F_JMB_RTS:	DBIT	1		; 1= off = RxCBuf hampir penuh

F_JMB_Dsroff:	DBIT	1		; 1= mati
F_JMB_RxFull:	DBIT	1
F_JMB_TxTOut:	DBIT	1		; 1= DATA mengendap (basi?) di TxCBuf

FM_JMB_RstStat	EQU	01111100B	; bit[2..6]
FM_JMB_Status	EQU	01110000B	; bit[4..6]
FM_JMB_Runtuh	EQU	00010000B	; jika 'status' >/ 'runtuh' -> tutup
					; Hanya 4-BIT tinggi

;SegB_JMB	SEGMENT	BIT
;		RSEG	SegB_JMB
;?F_JMB_RxCBuf:	DBIT	1		; 1= RxCBuf berisi

SegV8		SEGMENT	XDATA
		RSEG	SegV8

PUBLIC	V8_JMB_RxCBuf, V8_JMB_TxCBuf

V8_JMB_RxCBuf:	DS	256
V8_JMB_TxCBuf:	DS	256

		XSEG	AT HW_JMB_Dasar
PUBLIC	HW_JMB
HW_JMB:		DS	256

IVEC_PwtEUART	EQU	0BH	; Tmr0

		CSEG	AT	IVEC_PwtEUART
ISREU:		LJMP	EmulatorUART

		;CSEG	AT	02BH+3		; 3 byte setelah vec intr. T2

SEGC_ISREU	SEGMENT	CODE
		RSEG	SEGC_ISREU

C_EU_Faktor	EQU	3

EmulatorUART:
	DJNZ	D_EUR_Intr,_EUR_Selesai		; sk=6 (2+2+2)

;EU_RxISR:
	JB	F_EUR_ProData,_EUR_BitData
	INC	D_EUR_Intr
	JNB	F_EUR_ProStart,_EUR_CariStop	; sk=+5

_EUR_CariStart:
	JBC	F_EUR_ProCek,_EUR_CekStart	; sk=+7
	JB	P_EU_RxD,_EUR_Selesai		; sk=+9, belum dapat
	SETB	F_EUR_ProCek			; @> cek start
	SJMP	_EUR_Selesai			; sk=+12

; jarak cari start ke cek start = faktor/2 !
_EUR_CekStart:
	JB	P_EU_RxD,_EUR_Selesai		; sk=+9, bukan start
	SETB	F_EUR_ProData			; benar start, @> bit data
	MOV	BA_EUR_TmpBuf,#00010000B	; batas D6
	SJMP	__EUR_PriodeBit			; sk=(+14),(+2)

;Proses Penerimaan bit data:
;D0 ___!____ -> __0_!___ ;MSB..LSB, '_'=0, '!'=1
;D1 __0_!___	__10_!__
;D2 __10_!__	__210_!_
;D3 __210_!_	__3210_!
;D4 __3210_!	!_43210_
;D5 !_43210_	_!543210
;D6 _!543210	_6543210
;D7 _6543210	76543210

_EUR_BitData:
	JB	F_EUR_ProStart,_EUR_BitD0D6	; sk=+4
	JNB	F_EUR_ProCek,_EUR_BitD7		; sk=+6
;_EUR_BitPrts:
	CLR	F_EUR_ProData
	;DICADANGKAN ('Parity Err')
	SJMP	__EUR_PriodeBit			; @> cek stop

__EUR_SalahStop:
	;DICADANGKAN ('Framing Err')
	;SJMP	_EUR_Selesai			; @> cari stop

__EUR_Overrun:
	;DICADANGKAN ('Overrun Err')
	SJMP	_EUR_Selesai			; @> cari start

__EUR_BelumStop:
	;DICADANGKAN ('Break Interrupt')
	SJMP	__EUR_PriodeBit

_EUR_CariStop:
	JBC	F_EUR_ProCek,_EUR_CekStop	; sk=+7
	JNB	P_EU_RxD,__EUR_BelumStop	; sk=+9
	SETB	F_EUR_ProStart			; dapat stop, @> cari start
	SJMP	_EUR_Selesai			; sk=+12

_EUR_CekStop:
	JNB	P_EU_RxD,__EUR_SalahStop	; sk=+9
	SETB	F_EUR_ProStart			; @> cari start
	JB	RI_EU,__EUR_Overrun		; RxBuf sudah dijemput ?

	PUSH	ACC
	MOV	A,BA_EUR_TmpBuf
	LCALL	_EUR_Selesai			; sk=+17
;EU_Terima:
	PUSH	IE				; <- dijalankan setelah RETI
	ANL	IE,#80H+(1 SHL (IE_EU MOD 8))
	SETB	RI_EU				; <- tundaan INTR max = 8 sk
	LJMP	_EU_LanjutRx			; bersambung...

_EUR_BitD0D6:
	JBC	BA_EUR_TmpBuf.6,_EUR_BitD6	; posisi bit D6 (=1) ?
	XCH	A,BA_EUR_TmpBuf
	JNB	P_EU_RxD,__EUR_GsrD0D5		; sk=+9
	SETB	ACC.6				; nilai awal = 0
__EUR_GsrD0D5:
	RR	A				; pertama terima -> D0 (lsb)
	XCH	A,BA_EUR_TmpBuf			; simpan data, pulihkan ACC
	SJMP	__EUR_PriodeBit

_EUR_BitD7:
	SETB	F_EUR_ProCek			; @> cek prts
	JNB	P_EU_RxD,__EUR_KePrts		; sk=+9
	SETB	BA_EUR_TmpBuf.7
	SJMP	__EUR_KePrts			; sk=+12

_EUR_BitD6:
	CLR	F_EUR_ProStart			; @> bit D7
	JNB	P_EU_RxD,__EUR_KeD7		; sk=+9
	SETB	BA_EUR_TmpBuf.6
__EUR_KeD7:
	JB	F_EU_8Bit,__EUR_PriodeBit
	SETB	F_EUR_ProCek			; @> cek prts
__EUR_KePrts:
	JB	F_EU_Prts,__EUR_PriodeBit
	CLR	F_EUR_ProData			; @> cek stop
__EUR_PriodeBit:
	MOV	D_EUR_Intr,#C_EU_Faktor		; periode cuplik antar-bit
_EUR_Selesai:
	DJNZ	D_EUT_Intr,__EU_RETI

;==============================================================
;EU_TxISR:
	MOV	D_EUT_Intr,#C_EU_Faktor
	JB	F_EUT_Pro2,_EUT_BitData		; P=1XX -> D0..D6+D7/Prts
	JNB	F_EUT_Pro1,_EUT_Pros00X		; P=00X -> Idle/SP2
	JB	F_EUT_Pro0,_EUT_BitSP1		; P=011 -> SP1

_EUT_BitStart:					; <- P=010
	CLR	P_EU_TxD			; = start (space)
	SETB	F_EUT_Pro2			; P=110 @> D0..D6+D7 (2 SP)
	MOV	D_EUT_CchBit,#7
	JNB	F_EU_8Bit,__EUT_STQ
	INC	D_EUT_CchBit
__EUT_STQ:
	RETI

_EUT_BitData:					; <- P=1XX
	JB	F_EUT_Pro0,_EUT_BitPrts		; P=1X0 -> D0..D6+D7
	XCH	A,D_EU_TxBuf
	RRC	A				; LSB -> CY (TxDn) -> MSB
	MOV	P_EU_TxD,C
	MOV	C,ACC.7				; pulihkan CY
	DJNZ	D_EUT_CchBit,__EUT_PulihSwap
	SETB	F_EUT_Pro0			; P=1X1 @> Prts
	JB	F_EU_Prts,__EUT_PulihSwap
	CLR	F_EUT_Pro2			; P=0X1 @> SP1/SP2
__EUT_PulihSwap:
	XCH	A,D_EU_TxBuf
__EU_RETI:
	RETI

_EUT_BitPrts:					; <- P=1X1
	JBC	F_EU_TxPrts,__EUT_Prts_1
	CLR	P_EU_TxD
	CLR	F_EUT_Pro2			; P=0X1 @> SP1/SP2
	RETI
__EUT_Prts_1:
	SETB	P_EU_TxD
	CLR	F_EUT_Pro2			; P=0X1 @> SP1/SP2
	RETI

_EUT_Pros00X:
	JBC	F_EUT_Pro0,_EUT_BitSP2		; P=001 @> bit SP2
__EUT_SPQ:
	RETI

_EUT_BitSP1:					; P=011
	SETB	P_EU_TxD			; = stop (mark)
	CLR	F_EUT_Pro1			; P=001 @> bit SP2
	JB	F_EU_2Stop,__EUT_SPQ
	CLR	F_EUT_Pro0			; P=000 @> Idle

_EUT_BitSP2:
	LCALL	__EUT_SPQ			; = RETI

EU_Kirim:
	PUSH	IE
	ANL	IE,#80H+(1 SHL (IE_EU MOD 8))
	PUSH	ACC
	PUSH	PSW
	PUSH	DPL
	PUSH	DPH
	MOV	DPTR,#HW_PPI_PA
	MOVX	A,@DPTR
	ANL	A,#FM_JMB_DceStatus
	JNZ	__JTI_DCETakSiap		; dsr = cts = On (=0) ?
;_JTI_CekCBuf:
	MOV	A,D_JMB_TxPtr_B
	CJNE	A,D_JMB_TxPtr_K,_JTI_JemputCBuf
	SJMP	__JTI_TundaIdle		; = kosong (cts=on)
;__JTI_RMTrts:
	;ADD	A,#255-(C_RMT_RtsOff+1)		; +1 -> anti 'racing'
	;CJNE	A,D_JMB_TxPtr_K,_JTI_JemputCBuf
	;CLR	P_RMT_Rts			; rts -> on
_JTI_JemputCBuf:
	MOV	DPH,#HIGH V8_JMB_TxCBuf
	MOV	DPL,D_JMB_TxPtr_B
	MOVX	A,@DPTR
	INC	D_JMB_TxPtr_B
	MOV	C,P
	JNB	F_EU_TPrts,__JTI_AjukanStart
	CPL	C
__JTI_AjukanStart:
	MOV	F_EU_TxPrts,C
	MOV	D_EU_TxBuf,A
	SETB	F_EUT_ProStart			; @> bit Start
_JTI_Selesai:
	POP	DPH
	POP	DPL
	POP	PSW
	POP	ACC
	POP	IE
	RETI

F_EUT_ProStart	EQU	F_EUT_Pro1		; hanya jika P2=P0=0
F_EUT_ProStop	EQU	F_EUT_Pro0		; hanya jika P2=P1=0

__JTI_DCETakSiap:
	JB	ACC.FP_JMB_Dsr,__JTI_DsrOff	; dsr = off (=1) ?
	MOV	A,D_JMB_TxPtr_B
	CJNE	A,D_JMB_TxPtr_K,__JTI_TundaKirim; berisi (dan cts=off) ?
	;SJMP	__JTI_TundaIdle		; = kosong (cts=off)

C_JMB_TxIdle	EQU	0			; satuan pewaktu EU

__JTI_TundaIdle:
	MOV	D_EUT_Intr,#C_JMB_TxIdle
	SETB	F_EUT_ProStop
	SJMP	_JTI_Selesai

__JTI_TundaKirim:
	DJNZ	D_EUT_CchBit,__JTI_TundaIdle	; TxTOut = 256*TxIdle
	SETB	F_JMB_TxTOut 			;; syarat: D_EUT_CchBit sudah 0
	SJMP	_JTI_Selesai

__JTI_DsrOff:
	SETB	F_JMB_Dsroff			; ajukan dsroff
	SJMP	_JTI_Selesai

	;CLR	IE_EU				; matikan intr
	;CLR	P_JMB_RST			; reset kartu
	;SETB	F_JMB_Dsroff			; ajukan dsroff
	;SETB	F_JMB_RTS
	;SJMP	_JTI_Selesai

;=================================
; Lanjutan 'EU_terima'

_EU_LanjutRx:
	PUSH	PSW
	PUSH	DPL
	PUSH	DPH
	MOV	DPL,D_JMB_RxPtr_K
	MOV	DPH,#HIGH V8_JMB_RxCBuf
	MOVX	@DPTR,A			; data disimpan, ptr belum dinaikkan

;__JRI_CekPenuh:
	MOV	A,DPL
	CPL	A
	ADD	A,D_JMB_RxPtr_B		; A <- sisa sebelum ditulis
	JZ	__JRI_CBufPenuh

;__JRI_CekSisa:
	CJNE	A,#1+C_JMB_RtsOff,__JRI_GsrPtrK
	JB	F_JMB_RTS,__JRI_GsrPtrK		; sudah pernah dimatikan (=1) ?
;@PCB	MOV	DPL,D_JMB_NomKartu
	MOV	A,D_JMB_NomKartu
	MOV	DPH,#HIGH HW_JMB
	MOVX	@DPTR,A				; toggle RTS -> off
	CPL	F_JMB_RTS
__JRI_GsrPtrK:
	INC	D_JMB_RxPtr_K
	JBC	F_RMT_TxTidur,___JRI_BangunkanRmtTx

EXTRN	BIT	(F_RMT_TxTidur)

_JRI_Selesai:
	POP	DPH
	POP	DPL
	POP	PSW
	POP	IE
	POP	ACC
	CLR	RI_EU
	RETI

___JRI_BangunkanRmtTx:
	SETB	TI				; bangunkan
	SJMP	_JRI_Selesai

__JRI_CBufPenuh:
	SETB	F_JMB_RxFull			; ajukan rxfull
	SJMP	_JRI_Selesai


;=================================
;=================================

SegC_JMBUmum	SEGMENT	CODE
		RSEG	SegC_JMBUmum

PUBLIC	JMB_InitDasar
;*EXTRN	XDATA	(NV_RMT_Modus)

JMB_InitDasar:
	;*MOV	A,#44H				; Modem, 8N1, 4800 bps
	;*MOV	DPTR,#NV_RMT_Modus
	;*MOVX	@DPTR,A
	ANL	TMOD,#0F0H			; reset Pewaktu0
	ORL	TMOD,#0010B			; abai !int0, pewaktu, 8-BIT
	SETB	IP_EU				; prioritas tinggi
	;MOV	D_JMB_RxPtr_B,D_JMB_RxPtr_K
	;SJMP	JMB_Reset
	CLR	A
	RET

PUBLIC	JMB_Tutup, JMB_Reset
PUBLIC	JMB_Runtuh

; F: Menutup Jembatan jika sudah pernah dibuka
JMB_Tutup:
	CLR	A
	JB	TR_EU,JMB_Runtuh		; sedang dibuka (=1) ?
	MOV	A,#KJ_Ditolak
	RET

JMB_Reset:
	MOV	D_JMB_RxPtr_B,D_JMB_RxPtr_K
	;MOV	D_JMB_TxPtr_B,D_JMB_TxPtr_B

; F: Mematikan EUART dan mereset Kartu, tanpa mereset RxCBuf/TxCBuf
JMB_Runtuh:
	CLR	P_JMB_RST
	;CLR	IE_EU
	CLR	TR_EU
	SETB	P_EU_TxD			; = stop (mark)
	SETB	P_JMB_RST
	RET

PUBLIC	JMB_Buka

RPar0	EQU	R2
RPar1	EQU	R3

; F: Membuka Jembatan jika belum dibuka
JMB_Buka:
	MOV	A,#KJ_Ditolak
	JB	TR_EU,__JMB_RET			; masih aktif (=1) ?

	;CLR	?F_JMB_RxCBuf

	ANL	BA_JMB_Status,#NOT FM_JMB_RstStat
	;CLR	F_JMB_RTS			; 0 = aktif
	MOV	D_JMB_RxPtr_B,D_JMB_RxPtr_K
	MOV	D_JMB_TxPtr_K,D_JMB_TxPtr_B	; bagian transfer menulis di-K!

	MOV	D_JMB_NomKartu,RPar0
	MOV	BA_EU_Konfig,RPar1

	CLR	A
	MOV	D_EUT_CchBit,A			; persiapan TundaKirim
	MOV	BA_EU_Proses,A			; EURx = cari stop, EUTx = idle
						;; RI_EU=0
	INC	A				; = 1
	MOV	D_EUR_Intr,A
	;MOV	D_EUT_Intr,A

	MOV	A,RPar1				; BA_EU_Konfig
	ANL	A,#110000b			; #4..7 (2-BIT dicadangkan)
	SWAP	A
	MOV	DPTR,#DTBL_EU_Baud
	MOVC	A,@A+DPTR
	MOV	TH_EU,A				;= peng-isi-ulang
	MOV	TL_EU,A

;@PCB	MOV	DPL,RPar0			; D_JMB_NomKartu
	MOV	A,RPar0				; D_JMB_NomKartu
	MOV	DPH,#HIGH HW_JMB
	MOVX	@DPTR,A				; aktifkan KARTU (1x)
	LCALL	EU_Kirim			; = cek DCE status
	MOV	A,#KJ_Gagal
	JB	F_JMB_DSROff,JMB_Runtuh		; batal jika DSR=Off

	;SETB	IE
	SETB	TF_EU				; ajukan irq pewaktu
	SETB	TR_EU				; aktifkan pewaktu
	SETB	IE_EU				; jalankan ISR

	MOV	A,RPar0				; D_JMB_NomKartu
	MOVX	@DPTR,A				; aktifkan RTS (2x)

	CLR	A
__JMB_RET:
	RET

DTBL_EU_Baud:
	DB	0				; dicadangkan
	DB	0				; 1200
	DB	256-128				; 2400
	DB	256-64				; 4800

	END
;End End End End End End End End End End End End End End End
; End End End End End End End End End End End End End End End
;  End End End End End End End End End End End End End End End

PUBLIC	TESTJMB
TESTJMB:
	LCALL	JMB_InitDasar
	SETB	EA
	MOV	RPar0,#0
	MOV	RPar1,#0FFH				; 4800, 8,O,2
	LCALL	JMB_Buka
	MOV	TL0,#0
	SJMP	$-3



;@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
;--------------
;
;JMB_baca_RxCBuf:
;	MOV	A,D_JMB_RxPtr_B
;	CJNE	A,D_JMB_RxPtr_K,_JMB_cek_rts_off
;	SETB	C				;= kosong
;	RET
;_JMB_cek_rts_off:
;	MOV	A,D_JMB_RxPtr_K
;	ADD	A,#C_JMB_RtsOff+1+1		;+1 untuk anti 'racing'
;	CJNE	A,D_JMB_RxPtr_B,_JMB_jemput_RxCBuf
;	MOV	DPH,#HIGH HW_JMB
;	MOV	DPL,D_JMB_NomKartu
;	MOVX	@DPTR,A				;aktifkan RTS
;	CPL	F_JMB_rts			;=SETB
;_JMB_jemput_RxCBuf:
;	MOV	DPH,#HIGH V8_JMB_RxCBuf
;	MOV	DPL,D_JMB_RxPtr_B
;	MOVX	A,@DPTR
;	INC	D_JMB_RxPtr_B
;	CLR	C				;= ada, di ACC
;	RET
;
;JMB_tulis_TxCBuf:
;	MOV	DPL,A				;pinjam tempat
;	MOV	A,D_JMB_TxPtr_K
;	INC	A
;	CJNE	A,D_JMB_TxPtr_B,_JMB_simpan_TxCBuf
;	SETB	C				;= penuh
;	RET
;_JMB_simpan_TxCBuf:
;	MOV	A,DPL				;kembalikan
;	MOV	DPH,#HIGH V8_JMB_TxCBuf
;	MOV	DPL,D_JMB_TxPtr_K
;	MOVX	@DPTR,A
;	INC	D_JMB_TxPtr_K
;	CLR	C				;= telah ditulis
;	RET

__EUT_MenujuPrts:
	SETB	F_EUT_Pro0			; @> bit prts
	JB	F_EU_Prts,__EUT_PulihSwap
	SETB	F_EUT_Pro0			; @> bit stop (1/2)
__EUT_PulihSwap:
	XCH	A,D_EU_TxBuf			; 1, sk=+6/+8
	RET
_EUT_BitData7:
	XCH	A,D_EU_TxBuf			; 1
	RRC	A				; 1, lsb yang pertama
	MOV	F_EUT_BitTxD,C			; 2, <- BIT TxD yg akan dikirim
	MOV	C,ACC.7				; 1, pulihkan CY
	SJMP	__EUT_MenujuPrts

	;SETB	F_EUT_BitTxD			; 1
	;JB	F_EU_TxPrts,_EUT_Selesai	; 2, sk=+5/+8
	;CLR	F_EUT_BitTxD			; 1
	;SJMP	_EUT_selesai			; 2, sk=+8/+11

;	PUSH	IE				; 2
;	JBC	F_EUT_BitTxD,__Cont0		; 1, BIT yg _akan_ dikirim
;	CLR	P_EU_TxD
;	SJMP	__Cont1
;__Cont0:
;	SETB	P_EU_TxD
;__Cont1:

;=======================
_EUR_CariStop:
	JBC	F_EUR_ProCek,_EUR_CekStop	; (sk=+7)
	JNB	P_EU_RxD,__EUR_CekBreak	; (sk=+9)
	SETB	F_EUR_ProStart		; dapat stop @> cari start
	SJMP	_EUR_Selesai			; sk=+12

__EUR_CekBreak:
	DJNZ	BA_EUR_TmpBuf,_EUR_Selesai	; sk=+11
	SETB	F_JMB_RxBrk			; Break terdeteksi
	MOV	BA_EUR_TmpBuf,D_EUR_Break
	SJMP	_EUR_Selesai			; sk=+16

_EUR_CekStop:
	JB	P_EU_RxD,__EUR_Lengkap		; (sk=+9)
	MOV	BA_EUR_TmpBuf,D_EUR_Break	; bukan stop @> cari stop
	SJMP	_EUR_Selesai			; sk=+13, abaikan DATA

__EUR_Lengkap:
	MOV	D_EU_RxBuf,BA_EUR_TmpBuf
	SETB	F_EUR_ProStart			; @> cari start
	DJNZ	D_EUT_Intr,__EUR_Simpan
	SETB	RI_EU				; sk=+15
	SJMP	JMB_TxISR
__EUR_Simpan:
	PUSH	IE
	LJMP	__JRI_PushReg
;=============
; data	start	cek	proses
; 0	0*	0	cari stop
; 0	1	0*	cari start
; 0*	1	1*	cek start
; 1	1*	-	cuplik D0..D6
; 1	0	0*	cuplik D7
; 1*	0	1**	cek paritas
; 0	0*	1*	cek stop

; P2	P1	P0	proses
; 0	0	0	cek DCE
; 0*	0	1	kirim start, P0 -> jml stop
; 1	0*	-	kirim D0..D7, P2 -> keberadaan prts
; 1+	1	-	kirim paritas
; 0	1	1+	kirim stop1
; 0	1*	0	kirim stop2
;========================================

TES: 8-BIT, P ganjil, 1 Stop, 4800 baud:
Perbandingan pembagian siklus antara DiluarISR : ISR_KEP
Dengan TX selalu mengirim
1. Selalu mencari start = 1:3
2. Selalu mencari stop = 1:5
3. DATA diterima acak (sah/cacat) = 1:2

;	CLR	A
;_JMB_InitStop:
;	JNB	F_EU_2Stop,_JMB_InitPrts
;	ADD	A,#C_EU_Faktor			; 2 BIT-stop
;_JMB_InitPrts:
;	JNB	F_EU_Prts,_JMB_InitJmlBit
;	ADD	A,#C_EU_Faktor			; 1 BIT-paritas
;_JMB_InitJmlBit:
;	JNB	F_EU_8Bit,_JMB_InitCacah
;	ADD	A,#C_EU_Faktor			; 8 BIT-DATA
;_JMB_InitCacah:
;	ADD	A,#(C_EU_Faktor*8)+2		; 2 = 3*(1/3+1/3) = Tbit*(C+D)
;						; 1 ST, 7/8 D, 0/1 P, 1/2 SP
;						; = cacah pada RxData tercepat
;	MOV	D_EUR_Break,A
;	;MOV	BA_EUR_TmpBuf,A

