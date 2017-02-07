; REV:
; - Memakai Paritas Blok
; - Mengunakan layer yg berbeda antara ISR dengan NonISR
; - Fr_JMB dengan #JMB dan FCS
; - Perbaikan Operasi 'Jembatan'
;22:18pm 04-01-1999 Pemmindahan 3 RegV ke RegD
;03:59am 04-02-1999 Pewaktu AutoTI menggunakan Reg 8-bit
;04:43am 04-02-1999 Modifikasi Inisialisasi
;1. 01:39am 04-22-1999 RMT_RX hanya bertugas mengumpulkan data

$NOLIST
$NOMOD51
$INCLUDE(E:\C51\ASM\REG52.INC)
$LIST

$INCLUDE(SCH.DEF)
$INCLUDE(REMOTE.DEF)
$INCLUDE(STDIO.DEF)

EXTRN	XDATA	(HW_JMB, HW_PPI_PA, HW_PPI_Ctrl)
EXTRN	DATA	(D_JMB_TxPtr_K, D_JMB_TxPtr_B)
EXTRN	DATA	(D_JMB_RxPtr_K, D_JMB_RxPtr_B)
EXTRN	DATA	(D_JMB_NomKartu)
EXTRN	BIT	(IE_EU, TR_EU, F_JMB_DsrOff, F_JMB_TxTOut, F_JMB_RTS)

FM_RMT_Baud		EQU	1111b
FP_RMT_Prts		EQU	4
FP_RMT_TPrts		EQU	5
FP_RMT_InitModem	EQU	6

SegD_RMT	SEGMENT	DATA
		RSEG	SegD_RMT

		PUBLIC	D_RMT_AutoTI

D_RMT_RxPtr_K:	DS	1
D_RMT_RxPtr_B:	DS	1
D_RMT_TxPtr_K:	DS	1
D_RMT_TxPtr_B:	DS	1
D_RTI_JMP:	DS	1
D_RTI_Batas:	DS	1
D_RTI_FCS8:	DS	1
D_RMT_AutoTI:	DS	1

;SWAPABLE
D_CMD_RxPtr_K:	DS	1
D_CMD_RxPtr_B:	DS	1
D_PRR_PtrK:	DS	1
D_PRR_Cch:	DS	1
D_PRR_FCS8:	DS	1


SegB_RMT	SEGMENT	BIT
		RSEG	SegB_RMT

		PUBLIC	F_RMT_TxTidur

F_RMT_Koneksi:	DBIT	1		; status, 1=OnLine (modus frame)
F_RMT_CekCD:	DBIT	1		; 1 = periksa CD
F_RMT_TPrts:	DBIT	1		; 1 = ganjil
F_PRR_P0:	DBIT	1
F_PRR_P1:	DBIT	1
F_PRR_P2:	DBIT	1
F_PRR_EscData:	DBIT	1
F_PRR_TujuanSibuk:	DBIT	1
F_RMT_TxTidur:	DBIT	1		; jika 1: butuh bantuan pengaktifan


EXTRN	XDATA	(V8_JMB_TxCBuf, V8_JMB_RxCBuf)

SegV8		SEGMENT	XDATA
		RSEG	SegV8

V8_RMT_TxCBuf:	DS	256
V8_RMT_RxCBuf:	DS	256
V8_CMD_RxCBuf:	DS	256

;SegNV16	SEGMENT	XDATA
;		RSEG	SegNV16

;NV_RMT_Modus:	DS	1
EXTRN	XDATA	(NV_RMT_Modus)

SegV16		SEGMENT	XDATA
		RSEG	SegV16

;V_RTI_Batas:	DS	1
V_RMT_Aktif:	DS	1			; modus akses yang aktif
V_RTI_EscData:	DS	2			; dengan EscJmp


	CSEG	AT	23H		; vektor intr serial
	LJMP	ISRRemote


SegC_RMTWD	SEGMENT	CODE
SegC_RMTCmd	SEGMENT	CODE
SegC_RMTIsr	SEGMENT	CODE	INBLOCK

		RSEG	SegC_RMTIsr

;PUBLIC	ISRRemote
ISRRemote:
	PUSH	PSW
	PUSH	ACC
	PUSH	DPL
	PUSH	DPH
	JNB	RI,_RRI_Selesai

;RMT_RxIsr:
	MOV	A,SBUF
	CLR	RI				; SBUF telah dibaca
	MOV	DPL,D_RMT_RxPtr_K
	MOV	DPH,#HIGH V8_RMT_RxCBuf
	MOVX	@DPTR,A				; simpan dahulu

	MOV	A,DPL
	CPL	A
	ADD	A,D_RMT_RxPtr_B			; A <- sisa _sebelum_ ditulis
	JZ	_RRI_Selesai			; Abaikan Data ?
	;-ADD	A,#1+C_RMT_RtsOff
	;-MOV	P_RMT_Rts,C
	CJNE	A,#1+C_RMT_RtsOff,_RRI_GsrPtrK
	SETB	P_RMT_Rts			; RTS <- off
_RRI_GsrPtrK:
	INC	D_RMT_RxPtr_K

_RRI_Selesai:
	JBC	TI,RMT_TxISR

_RTI_selesai:
	POP	DPH
	POP	DPL
	POP	ACC
	POP	PSW
	RETI

RMT_TxISR:
	MOV	DPTR,#HW_PPI_PA			;; oleh pewaktu Tombol
	MOVX	A,@DPTR
	ANL	A,#FM_RMT_DCEStatus
	JB	F_RMT_CekCD,_RTI_CekDCE		; periksa CD juga (=1)?
	CLR	ACC.FP_RMT_CD
_RTI_CekDCE:
	JZ	_RTI_JMP			; CTS=DSR=CD = on(=0) ?
	CLR	ACC.FP_RMT_CTS
	JZ	_RTI_Tidur			; hanya CTS=off (=0) ?
;_RTI_DCETakSiap:
	CLR	TR_RMT				; ajukan init
	CLR	F_RMT_Koneksi			; tutup koneksi
_RTI_Pingsan:
	SETB	P_RMT_RTS			; rts -> off
	CLR	ES				; ISR -> off
_RTI_Tidur:
	MOV	D_RMT_AutoTI,#C_RMT_AutoTx	; pengaktifan TI oleh pewaktu
	SETB	F_RMT_TxTidur
	SJMP	_RTI_Selesai

_RTI_JMP:
	MOV	A,D_RTI_JMP
	MOV	DPTR,#TBL_TxJmp
	JMP	@A+DPTR

TBL_TxJmp:
	CJT_InitModem	EQU	$-TBL_TxJmp
	SJMP	RTI_InitModem
	CJT_CekPassword	EQU	$-TBL_TxJmp
	SJMP	RTI_CekPassword
	CJT_DataTRM	EQU	$-TBL_TxJmp
	SJMP	RTI_DataTRM
	CJT_NomJMB	EQU	$-TBL_TxJmp
	SJMP	RTI_NomJMB
	CJT_DataJMB	EQU	$-TBL_TxJmp
	SJMP	RTI_DataJMB
	CJT_TutupFr1	EQU	$-TBL_TxJmp
	;AJMP	RTI_TutupFr1
	CJT_TutupFr2	EQU	$-TBL_TxJmp
	AJMP	RTI_TutupFr2
	CJT_EscData	EQU	$-TBL_TxJmp
	AJMP	RTI_EscData
	CJT_CekSumber	EQU	$-TBL_TxJmp
	;SJMP	RTI_CekSumber


RTI_CekSumber:
	JNB	F_JMB_RTS,__RTIC		; RxCBuf JMB hampir penuh (=1)?
	MOV	A,D_JMB_RxPtr_B			;; atau Jmb telah Runtuh ?
	CJNE	A,D_JMB_RxPtr_K,_RTIC_DariJMB
	CLR	F_JMB_RTS			; <- karena Jmb runtuh
__RTIC:	MOV	A,D_RMT_TxPtr_B
	CJNE	A,D_RMT_TxPtr_K,_RTIC_DariTRM
	MOV	A,D_JMB_RxPtr_B
	CJNE	A,D_JMB_RxPtr_K,_RTIC_DariJMB
	SJMP	_RTI_Tidur
	;SJMP	_RTI_FrMark			; kirim tanpa henti ?

RTI_InitModem:					; <- disini RTS=On, REN=1 !
	MOV	A,D_RMT_TxPtr_B
	CJNE	A,D_RMT_TxPtr_K,_RTIT_Jemput	; = sebelum akses dibuka
	;`MOV	DPTR,#NV_RMT_Modus
	;`MOVX	A,@DPTR
	;`JNB	ACC.FP_RMT_InitModem,RTI_CekPassword
	SETB	F_RMT_CekCD
	MOV	D_RTI_JMP,#CJT_CekPassword
	SJMP	_RTI_Pingsan

RTI_CekPassword:				; DICADANGKAN
	;...
;_RTI_BukaAkses:
	SETB	F_RMT_Koneksi
	SJMP	RTI_TutupFr1

_RTIC_DariTRM:
	MOV	DPL,A
	MOV	DPH,#high V8_RMT_TxCBuf
	MOVX	A,@DPTR				; = PjgCmd (tidak dikirim)
	INC	D_RMT_TxPtr_B
	ADD	A,D_RMT_TxPtr_B		; = @PjgCmd berikutnya
	;MOV	DPTR,#V_RTI_Batas
	;MOVX	@DPTR,A
	MOV	D_RTI_Batas,A
	MOV	D_RTI_JMP,#CJT_DataTRM
_RTIT_Jemput:
	MOV	DPL,D_RMT_TxPtr_B
	MOV	DPH,#high V8_RMT_TxCBuf
	MOVX	A,@DPTR
	INC	D_RMT_TxPtr_B
	SJMP	RTI_HitungFCS

RTI_DataTRM:
	;MOV	DPTR,#V_RTI_Batas
	;MOVX	A,@DPTR
	MOV	A,D_RTI_Batas
	CJNE	A,D_RMT_TxPtr_B,_RTIT_Jemput
_RTI_FCSTutup:
	MOV	D_RTI_JMP,#CJT_TutupFr2
;_RTI_HasilFCS:
	;--------------------------------------
	MOV	A,D_RTI_FCS8		; jemput
	;--------------------------------------
	SJMP	RTI_CekData		; FCS tidak dihitung lagi

_RTIC_DariJMB:
	DEC	A
	;MOV	DPTR,#V_RTI_Batas
	;MOVX	@DPTR,A
	MOV	D_RTI_Batas,A
	MOV	D_RTI_JMP,#CJT_NomJMB
	MOV	A,#CMD_DataJMB			; buka Fr_JMB
	SJMP	RTI_HitungFCS			; perlu tanpa CekData ?

RTI_NomJMB:
	MOV	D_RTI_JMP,#CJT_DataJMB
	MOV	A,D_JMB_NomKartu
	SJMP	RTI_HitungFCS

RTI_DataJMB:
	;MOV	DPTR,#V_RTI_Batas
	;MOVX	A,@DPTR
	;CJNE	A,D_JMB_RxPtr_B,_RTIK_CekFifo	; sudah 255 byte (=) ?
	MOV	A,D_JMB_RxPtr_B
	CJNE	A,D_RTI_Batas,_RTIK_CekFifo	; sudah 255 byte (=) ?
	SJMP	_RTI_FCSTutup

_RTIK_CekFifo:
	;MOV	A,D_JMB_RxPtr_B
	CJNE	A,D_JMB_RxPtr_K,_RTIK_CekRTS
	SJMP	_RTI_FCSTutup

RTI_TutupFr1:
	;MOV	D_RTI_JMP,#CJT_TutupFr2
	;SJMP	_RTI_FrMark
RTI_TutupFr2:
	MOV	D_RTI_JMP,#CJT_CekSumber
	MOV	D_RTI_FCS8,#C_RMT_FCSAwal	; reset
_RTI_FrMark:
	MOV	A,#FrameMark
	SJMP	_RTI_PrtsByte

_RTIK_CekRTS:
	JNB	F_JMB_RTS,_RTIK_Jemput		; belum pernah dimatikan (=0) ?

	ADD	A,#255-C_JMB_RtsOn
	CJNE	A,D_JMB_RxPtr_K,_RTIK_Jemput

	JNB	TR_EU,__RTIK_Toggle		; JMB masih aktif (=1) ?
;@PCB	MOV	DPL,D_JMB_NomKartu
	MOV	A,D_JMB_NomKartu
	MOV	DPH,#HIGH HW_JMB
	MOVX	@DPTR,A				; <- toggle ke on
__RTIK_Toggle:
	CPL	F_JMB_RTS
_RTIK_Jemput:
	MOV	DPL,D_JMB_RxPtr_B
	MOV	DPH,#high V8_JMB_RxCBuf
	MOVX	A,@DPTR
	INC	D_JMB_RxPtr_B

RTI_HitungFCS:

	;--------------------------------------
	; Gantikan ini jika digunakan CRC 8-bit
	XRL	D_RTI_FCS8,A			; A tidak boleh dirusak
	;--------------------------------------

RTI_CekData:
	CJNE	A,#FrameMark,_RTI_CekFrEsc
	SJMP	__RTI_FrEsc

RTI_EscData:
	MOV	DPTR,#V_RTI_EscData
	MOVX	A,@DPTR
	MOV	D_RTI_JMP,A
	INC	DPTR
	MOVX	A,@DPTR
	XCH	A,D_RTI_JMP
	XRL	A,#EscTranspose
	SJMP	_RTI_PrtsByte			; FCS didasarkan pada data asli

_RTI_CekFrEsc:
	CJNE	A,#FrameEsc,_RTI_PrtsByte
__RTI_FrEsc:
	MOV	DPTR,#V_RTI_EscData
	MOVX	@DPTR,A				; <- DATA yg dialihkan
	INC	DPTR
	MOV	A,#CJT_EscData
	XCH	A,D_RTI_JMP
	MOVX	@DPTR,A				; <- sumber_JMP
	MOV	A,#FrameEsc
	;SJMP	_RTI_PrtsByte			; tidak disertakan pada FCS

_RTI_PrtsByte:
	MOV	C,P				; C <- prts peng-genap
	JNB	F_RMT_tprts,__RTI_TulisSBUF
	CPL	C				; C <- prts peng-ganjil
__RTI_TulisSBUF:
	MOV	TB8,C				; diabaikan jika SM0=0
	MOV	SBUF,A
	AJMP	_RTI_selesai

;/ \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \

R_PRR_TmpBuf	EQU	R3
C_PRR_BatasPros	EQU	0		; = 256 byte

; Pro	P2	P1	P0	Proses
; -------------------------------------------------------
; 0	0	0	0	Pengabaian data (Tunggu FrMark)
; 1	0	0	1	KodeCmd
; 2.a	0	1	1	NomHandle (DataCmd)
; 3.a	1	X	1	DataCmd (X: 1=param pertama)
; 2.b	0	1	0	NomJmb (DataCmd !)
; 3.b	1	X	0	DataJmb (X: 1=data pertama)

; Pada Pro #1, jika KodeCmd=KodeJmb -> proses 2.a, selainnya -> proses 2.b
; Pada Pro #1 dan #2 data disimpan (sementara) pada CMD_RxCBuf
; Pemeriksaan FCS (dapat FrMark) dilakukan hanya pada Pro #3
;; Jika FCS sah, data ditransfer ke tujuan yg dimaksud (a/b), jika tdk -> buang
; Jika terdeteksi FrMark pada Pro _selain_ #3, Pro direset ke #0

ProsesRmtRx:
	JBC	F_PRR_TujuanSibuk,PRR_CekSibuk
	MOV	A,D_RMT_RxPtr_B
	CJNE	A,D_RMT_RxPtr_K,_PRR_Batas	; ada data (<>) ?
	RET

_PRR_Batas:
	MOV	D_PRR_Cch,#C_PRR_BatasPros	; batas proses

_PRR_Jemput:
	MOV	DPL,A
	MOV	DPH,#HIGH V8_RMT_RxCBuf
	MOVX	A,@DPTR
	INC	D_RMT_RxPtr_B

	XCH	A,DPL
	CLR	C
	SUBB	A,D_RMT_RxPtr_K		; A <- sisa setelah dijemput
	;-ADD	A,#C_RMT_RtsOn
	;-MOV	P_RMT_Rts,C
	CJNE	A,#C_RMT_RtsOn,_PRR_CekData
	CLR	P_RMT_Rts			; RTS <- on

_PRR_CekData:
	MOV	A,DPL
	JBC	F_PRR_EscData,_PRR_EscData

	CJNE	A,#FrameMark,_PRR_CekFrEsc	; pemisah frame (=FrMark) ?
	MOV	A,#C_RMT_FCSAwal
	XCH	A,D_PRR_FCS8			; jemput dan reset
	JBC	F_PRR_P2,_PRR_CekFCS
	CLR	F_PRR_P1
_PRR_RstPtrK:
	SETB	F_PRR_P0			; Pro #1
	MOV	D_PRR_PtrK,D_CMD_RxPtr_K	; = @PjgCmd
	SJMP	PRR_Lagi

_PRR_CekFCS:
	JBC	F_PRR_P1,_PRR_RstPtrK		; FCS sudah diterima (=1) ?
	JNZ	_PRR_RstPtrK			; FCS sah (=0) ?

; dijalankan dgn Pro=00X
;PRR_Transfer:
	MOV	DPH,#HIGH V8_CMD_RxCBuf
	JB	F_PRR_P0,_PRR_TransferCmd
	SETB	F_PRR_P0			; Pro #1 (tunggu KodeCmd)

;_PRR_TransferJmb:
	MOV	A,D_CMD_RxPtr_K
	ADD	A,#2				; = @NomJmb
	MOV	DPL,A
	MOVX	A,@DPTR
	CJNE	A,D_JMB_NomKartu,_PRR_SalahArah	; NomJmb cocok ?

	MOV	A,D_CMD_RxPtr_K
	XCH	A,D_PRR_PtrK			; jemput dan reset

	JNB	TR_EU,_PRR_SalahArah		; Jmb telah ditutup ?
						; jika Jmb dibuka dipertengahan
						;; SimpanJmb -> ngaco
	MOV	D_JMB_TxPtr_K,A			; ok, semua syarat dipenuhi
	SJMP	PRR_Lagi

; Laporan:
; jika NoJmb cocok -> TelahDitutup, jika tdk -> SalahArah / TelahDitutup

_PRR_SalahArah:
	INC	DPL
	MOV	D_PRR_PtrK,DPL

_PRR_TransferCmd:
	MOV	A,D_CMD_RxPtr_K			; = @PjgCmd
	MOV	DPL,A
	CPL	A
	ADD	A,D_PRR_PtrK			; A <- PjgCmd (murni), >/ 2
	MOVX	@DPTR,A
	MOV	D_CMD_RxPtr_K,D_PRR_PtrK	; ditranfer
	;SJMP	PRR_Lagi

PRR_Lagi:
	DJNZ	D_PRR_Cch,_PRR_Lagi0		; sudah mencapai batas (0) ?
	RET
_PRR_Lagi0:
	MOV	A,D_RMT_RxPtr_B
	CJNE	A,D_RMT_RxPtr_K,_PRR_Jemput	; _masih_ ada data (<>) ?
	RET

_PRR_CekFrEsc:
	CJNE	A,#FrameEsc,_PRR_Proses		; pengalih data (=FrEsc) ?
	SETB	F_PRR_EscData
	SJMP	PRR_Lagi

PRR_CekSibuk:
	JB	F_PRR_P1,PRR_CekSibuk_Cmd
	JNB	F_PRR_P0,PRR_CekSibuk_Jmb	; Pro: dataJmb = 101
PRR_CekSibuk_Cmd:
	MOV	DPL,D_PRR_Cch
	SJMP	_PRR_KodeCMD			; D_PRR_Cch Acak !


;PRR_Polos:
	; DICADANGKAN
	;SETB	F_PRR_EscData
	;SJMP	PRR_Lagi

_PRR_EscData:
	;JNB	F_RMT_Koneksi,PRR_Polos		; akses berframe ?
	XRL	A,#EscTranspose
	MOV	DPL,A

_PRR_Proses:
	;--------------------------------------
	; Gantikan ini jika digunakan CRC 8-bit
	XRL	D_PRR_FCS8,A			; DPL=A, DPL tdk boleh diubah
	;--------------------------------------
	JNB	F_PRR_P2,_PRR_Pro0XX
;_PRR_Pro1XX:
	JB	F_PRR_P0,PRR_DataCMD

; Pro1X0 (#3.a); Pertama jalan: X=1
;PRR_DataJMB:
	JBC	F_PRR_P1,_PRR_AwalJmb
	INC	D_PRR_PtrK			; dinaikkan dahulu !
	MOV	A,D_PRR_PtrK
	CJNE	A,D_JMB_TxPtr_K,_PRR_SimpanJmb	; data+FCS > 256 byte -> buang
	;SETB	F_JMB_TxFull

_PRR_FrameLebih:
	CLR	F_PRR_P0
	CLR	F_PRR_P1
	CLR	F_PRR_P2
	SJMP	PRR_Lagi			; berikutnya -> TungguFrMark

_PRR_AwalJmb:
	MOV	A,D_JMB_TxPtr_K
	MOV	D_PRR_PtrK,A			; mengacu ke CBuf_Jmb

_PRR_SimpanJmb:
	XCH	A,DPL
	MOV	DPH,#high V8_JMB_TxCBuf
	MOVX	@DPTR,A				; data terakhir (FCS) diabaikan

PRR_CekSibuk_Jmb:
	MOV	A,D_PRR_PtrK
	INC	A
	CJNE	A,D_JMB_TxPtr_B,PRR_Lagi	; terlihat penuh ?
	CJNE	A,D_JMB_TxPtr_K,_PRR_JmbSibuk
	SJMP	PRR_Lagi			; <- data ke-256 = FCS
						;; data ke-257 harus FrMark
_PRR_JmbSibuk:
	;JNB	TR_EU,_PRR_FrameLebih		; JMB telah ditutup -> abaikan
	JNB	TR_EU,PRR_Lagi			; JMB telah ditutup -> lapor
						;; kode ditranfer ke CBuf_Cmd
	SETB	F_PRR_TujuanSibuk		; Pro = 100
	RET

_PRR_Pro0XX:
	JNB	F_PRR_P1,_PRR_Pro00X

; Pro #2.a, #2.b
_PRR_Pro01X:
	SETB	F_PRR_P2			; Pro #3.a/#3.b
	SJMP	_PRR_KodeCMD

_PRR_Pro00X:
	JNB	F_PRR_P0,PRR_Lagi		; Pro000 (#0) = TungguFrMark

;F: Menunggu kode Cmd dan menentukan arah penerimaan
; Pro001 (#1)
;PRR_CekKode:
	SETB	F_PRR_P1			; Pro #2.a (CmdSeq)
	MOV	A,DPL
	CJNE	A,#CMD_DataJMB,_PRR_KodeCMD	; selain JMB -> CMD
	CLR	F_PRR_P0			; Pro #2.b (NomJmb)
	SJMP	_PRR_KodeCMD

; Pro1X1 (#3.a); juga bagian dari #1, #2.b, #2.b
PRR_DataCMD:
	CLR	F_PRR_P1
_PRR_KodeCMD:
	MOV	A,D_PRR_PtrK
	INC	A
	CJNE	A,D_CMD_RxPtr_B,_PRR_SimpanCmd

;_PRR_CekPjgCmd:
	CJNE	A,D_CMD_RxPtr_K,_PRR_CmdSibuk	; (@Pjg)+PjgCmd > 255 -> buang
	SJMP	_PRR_FrameLebih			;; (1 byte dipakai sbg @PjgCmd)

_PRR_SimpanCmd:
	INC	D_PRR_PtrK			; dinaikkan dahulu !
	XCH	A,DPL				;; lokasi pertama = @PjgCmd
	MOV	DPH,#HIGH V8_CMD_RxCBuf		;; terakhir = FCS (diabaikan)
	MOVX	@DPTR,A
	AJMP	PRR_Lagi

_PRR_CmdSibuk:
	MOV	D_PRR_Cch,DPL			; disimpan di D_PRR_Cch !
	SETB	F_PRR_TujuanSibuk		; Pro = X1X
	RET

;/ \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \ / \
;END

SegC_RMTData	SEGMENT	CODE
		RSEG	SegC_RMTData

DTBL_RMT_baud:
IF (MCS = 51)
	DB	-192		; 300bps, = 256 - (Fosc/12/16/baud)
	DB	-96		; 600
	DB	-48		; 1200
	DB	-24		; 2400
	DB	-12		; 4800
	DB	-6		; 9600
	DB	-3		; 19200
ENDIF
IF (MCS = 52)
	dw	-1152		; 300, = 65536 - (Fosc/2/16/baud)
	dw	-576		; 600
	dw	-288		; 1200
	dw	-144		; 2400
	dw	-72		; 4800
	dw	-36		; 9600
	dw	-18		; 19200
ENDIF

Str_InitModem:
	DB	'ATZS0=1',CR
Pjg_InitModem	EQU	$-Str_InitModem


		RSEG	SegC_RMTWD

;PUBLIC	RemoteInit

PUBLIC	CD_RMT_Modus
CD_RMT_Modus	EQU	44H				; modem, 8N1, 4800 bps

RemoteInit:
	;CLR	ES
	;SETB	P_RMT_RTS			; rts -> off
	MOV	DPTR,#HW_PPI_Ctrl
	MOV	A,#1 or 2*FP_RMT_DTR
	MOVX	@DPTR,A				; dtr -> off

EXTRN	CODE	(JMB_Reset)
	LCALL	JMB_Reset

	CLR	F_PRR_P0
	CLR	F_PRR_P1
	CLR	F_PRR_P2			; TungguFrMark
	CLR	F_PRR_TujuanSibuk
	CLR	F_PRR_EscData
	CLR	F_RMT_CekCD

	MOV	D_CMD_RxPtr_B,D_CMD_RxPtr_K
	MOV	D_RMT_RxPtr_B,D_RMT_RxPtr_K
	MOV	R6,#0
	MOV	D_RMT_TxPtr_B,R6

	MOV	DPTR,#NV_RMT_Modus
	MOVX	A,@DPTR
	MOV	DPTR,#V_RMT_Aktif
	MOVX	@DPTR,A
	;;MOV	D_RTI_JMP,#CJT_CekPassword
	MOV	D_RTI_JMP,#CJT_InitModem
	JNB	ACC.FP_RMT_InitModem,_RMT_UART
	MOV	R2,A
	MOV	R7,#HIGH V8_RMT_TxCBuf
	MOV	R0,#Pjg_InitModem
	MOV	DPTR,#Str_InitModem
EXTRN	CODE	(CChrCpy)
	LCALL	CChrCpy
	;MOV	DPL,R6
	;MOV	DPH,R7
	;MOV	A,#CR
	;MOVX	@DPTR,A
	;INC	R6
	MOV	A,R2
_RMT_UART:
	MOV	D_RMT_TxPtr_K,R6

	MOV	D_RMT_AutoTI,#C_RMT_DtrOffDly	; tunda pengaktifan DTR
	SETB	F_RMT_TxTidur			;; berdasarkan pewaktu AutoTI
	MOV	SCON,#01000000b			; sm1=1, sm2=0, ren=RI=TI=0

	MOV	C,ACC.FP_RMT_tprts
	MOV	F_RMT_TPrts,C			; 0=ganjil, 1=genap
	MOV	C,ACC.FP_RMT_prts
	MOV	SM0,C				; pakai paritas (=1) = 9-BIT

	ANL	A,#FM_RMT_baud			; = nibel rendah
	CJNE	A,#7,$+3			; = pilihan laju baud
	JC	_RMT_InitPewaktu		; < 7 ?, (7-15 dicadangkan)
	MOV	A,#6				; = 19200bps
_RMT_InitPewaktu:
	MOV	DPTR,#DTBL_RMT_baud

IF (MCS = 51)
TR_RMT	EQU	TR1
	ANL	TMOD,#0Fh		; reset pewaktu 1
	ORL	TMOD,#(0010b*16)	; abaikan !int1,pewaktu,8-BIT isi-ulang
	MOVC	A,@A+DPTR
	MOV	th1,A			; = peng-isi-ulang
	MOV	tl1,A
	ORL	PCON,#80h		; smod=1, faktor 1/16
	;CLR	ET1			; takmampukan interupsi
	SETB	TR1			; aktifkan pewaktu 1
ENDIF

IF (MCS = 52)
TR_RMT	EQU	TR2
	RL	A
	MOV	rcap2h,A
	MOVC	A,@A+DPTR
	MOV	TH2,A
	XCH	A,rcap2h
	INC	A
	MOVC	A,@A+DPTR
	MOV	rcap2l,A
	MOV	TL2,A
	;CLR	ET2			; (IE.5) takmampukan interupsi (EXEN2)
	MOV	t2con,#00111100b	; 1= RCLK(5), TCLK(4), EXEN2(3), TR2(2)
ENDIF
	LJMP	RC_RstOtoKEP


;SegV16		SEGMENT	XDATA
		RSEG	SegV16

;V_RMT_NomKEP:	DS	1
V8_RMT_Param:	DS	12

		RSEG	SegD_RMT
D_RMT_NomKEP:	DS	1

;=====================================================================

;SegC_RMTWD	SEGMENT	CODE
		RSEG	SegC_RMTWD

C_RMT_AutoTx	EQU	2		; = Tmax, Tmin = Cch-1
C_RMT_DtrOffDly	EQU	2		;; dihitung oleh pewaktu tombol (30Hz)
C_RMT_DtrOnDly	EQU	31		;; TI <- 1 jika cch = 1_ke_0

PUBLIC	MgrRemote

MgrRemote:
;----- F: Memeriksa inisialiasi UART dan awal keaktifan akses remote
	JB	F_RMT_Koneksi,RemoteOto		; akses sudah dibuka (=1) ?
	JNB	TR_RMT,RemoteInit		; ada permintaan init (=0) ?
	JB	ES,__RAQ			; ISR aktif (=1) ?
	JNB	TI,__RAQ			; saatnya diaktifkan (=1) ?
	JB	REN,__RA0

	MOV	DPTR,#HW_PPI_Ctrl
	MOV	A,#0 or 2*FP_RMT_dtr
	MOVX	@DPTR,A				; dtr -> on
	MOV	D_RMT_AutoTI,#C_RMT_DtrOnDly	; tunda pengaktifan TI
	SETB	F_RMT_TxTidur			;; oleh pewaktu AutoTI
	CLR	TI
	SETB	REN
	RET

__RA0:	MOV	DPTR,#HW_PPI_PA
	MOVX	A,@DPTR
	ANL	A,#FM_RMT_DCEStatus XOR (1 SHL FP_RMT_CTS)
	JB	F_RMT_CekCD,__RA1		; periksa CD juga (=1)?
	CLR	ACC.FP_RMT_CD

__RA1:	JNZ	__RAQ				; DSR dan CD hidup (=0) ?
	CLR	P_RMT_RTS			; rts -> on
	CLR	RI
	SETB	ES				; <- TxISR dijalankan (REN=1)
__RAQ:	RET

EXTRN	DATA	(BA_JMB_Status)
EXTRN	NUMBER	(FM_JMB_Status)
EXTRN	NUMBER	(FM_JMB_Runtuh)
EXTRN	CODE	(XInPageCpy)
EXTRN	XDATA	(V8_KP_Perubahan, V8_KP_Status)
EXTRN	BIT	(IE_KP)

USING	0		; RegBank 0

EXTRN	CODE	(JMB_Runtuh)

;////////////////////////////////////////////////////////

PJ_OtoKEP	EQU	1+2
PJ_OtoJMB	EQU	1+2

RemoteOto:

;F: Mengirimkan laporan status JMB (jika ada)
;Tx: Nomor8, Status
RMT_OtoJMB:
	JNB	TR_EU,__ROSQ			; JMB aktif (=1) ?
	MOV	A,BA_JMB_Status
	ANL	A,#FM_JMB_Status
	JZ	__ROSQ				; ada laporan status (<>0) ?
	MOV	R2,A
	MOV	R0,#PJ_OtoJMB			; = 3
	LCALL	RMT_CekSisaTx
	JC	__ROSQ				; cukup tempat (=0) ?
	;SETB	B.3
	;MOV	A,D_JMB_TxPtr_B
	;CJNE	A,D_JMB_TxPtr_K,__ROS1
	;CLR	B.3
;__ROS1:
	MOV	A,R2
	CPL	A
	ANL	BA_JMB_Status,A			; hapus yg telah dijemput
	CJNE	R2,#FM_JMB_Runtuh,$+3
	JC	__ROS2
	LCALL	JMB_Runtuh
	SETB	F_JMB_RTS			; ajukan RxCBuf (jika berisi)
__ROS2:	MOV	R1,D_JMB_NomKartu
	MOV	A,#KJ_OtoJMB
	XCH	A,R0
	LCALL	RMT_TulisTx
__ROSQ:	;RET

;F: Mengirimkan status masukan-KEP hasil polling (8-BIT) _jika_ pernah berubah
;Tx: Nomor8, Status8
RMT_OtoKEP:
	;MOV	DPTR,#V_RMT_NomKEP
	;MOVX	A,@DPTR
	MOV	A,D_RMT_NomKEP
	MOV	DPL,A				; = # kartu
	MOV	R1,A
	MOV	DPH,#high V8_KP_Perubahan
	MOVX	A,@DPTR
	JZ	__ROP2				; ada perubahan (<> 0) ?
	;JB	F_RMT_TipeOto,__ROP1
	;MOV	R3,A
	;MOV	DPH,#high NV8_KP_Alarm
	;MOVX	A,@DPTR
	;ANL	A,R3
	;JZ	__ROP2
__ROP1:	MOV	R0,#PJ_OtoKEP
	LCALL	RMT_CekSisaTx
	JC	__ROPQ				; cukup tempat (=0) ?
	MOV	DPH,#high V8_KP_Perubahan
	CLR	A
	;CLR	IE_KP
	MOVX	@DPTR,A
	MOV	DPH,#high V8_KP_Status
	MOVX	A,@DPTR				; hasil polling !
	;SETB	IE_KP
	MOV	R2,A
	MOV	A,#KJ_OtoKEP
	XCH	A,R0
	LCALL	RMT_TulisTx			; reg rusak !
__ROP2:	;MOV	A,R1
	;INC	A
	;MOV	DPTR,#V_RMT_NomKEP
	;MOVX	@DPTR,A
	INC	D_RMT_NomKEP
__ROPQ:	;RET

;////////////////////////////////////////////////////////
;		RSEG	SegC_RMTCmd

;LayananPerintahRmt:
	LCALL	ProsesRmtRx
LPR_Lagi:
	MOV	A,D_CMD_RxPtr_B
	CJNE	A,D_CMD_RxPtr_K,LPR_Layani
__LPRQ:	RET

;SegC_RMTCmd	SEGMENT	CODE
		RSEG	SegC_RMTCmd

PJ_Minimum	EQU	2
PJ_CmdGagal	EQU	1+2
KJ_TakDiKenal	EQU	0C0H
KJ_PjgCacat	EQU	0C1H

PUBLIC	KS_ParamCacat
PUBLIC	KJ_Ditolak, KJ_Gagal

LPR_Layani:
	MOV	DPL,A
	MOV	DPH,#HIGH V8_CMD_RxCBuf
	MOVX	A,@DPTR				; = PjgCmd
	MOV	B,A
	INC	DPL
	MOVX	A,@DPTR				; = KodeCmd
;_LPR_CekKodeCmd:
	CJNE	A,#C_RMT_JmlCmd,$+3
	JC	_LPR_CekPjgJwb			; cmd dikenal (=1) ?

	MOV	R0,#PJ_CmdGagal
	LCALL	RMT_CekSisaTx
	JC	__LPRQ				; tempat jawaban cukup (=0) ?
	MOV	A,#KJ_TakDikenal
	SJMP	LPR_HapusCmd

_LPR_CekPjgJwb:
	MOV	R6,DPL
	RL	A
	MOV	R1,A
	MOV	DPTR,#DTBL_RC_Pjg
	INC	A
	MOVC	A,@A+DPTR			; pjg_jawab
	CJNE	A,#PJ_CmdGagal,$+3		; A < 3 (C=1) ?
	ADDC	A,#0				; cadangan CmdGagal
	MOV	R0,A
	LCALL	RMT_CekSisaTx
	JC	__LPRQ				; tempat jawaban cukup (=0) ?
;_LPR_CekPjgCmd:
	MOV	A,R1
	MOVC	A,@A+DPTR			; PjgCmd seharusnya
	CJNE	A,B,_LPR_PjgSalah		; pjg sesuai ?
;_LPR_PjgParam:
	ADD	A,#-2
	JZ	LPR_ProsesCmd			; ada param (<>0) ?
	INC	R6
	INC	R6
	MOV	DPL,R6
	MOV	DPH,#HIGH V8_CMD_RxCBuf
	CJNE	A,#7,$+3
	JNC	__RB_XDATA			; param_cmd di R2..R7 (=1) ?
	MOV	B,A
	MOV	R0,#AR2
__RB_IData:
	MOVX	A,@DPTR
	MOV	@R0,A
	INC	DPL
	INC	R0
	DJNZ	B,__RB_IData
	SJMP	LPR_ProsesCmd
__RB_XDATA:
	MOV	R0,A
	MOV	R6,#LOW  V8_RMT_Param
	MOV	R7,#HIGH V8_RMT_Param
	LCALL	XInPageCpy

EXTRN	CODE	(JmpWOffset)
LPR_ProsesCmd:
	MOV	A,R1
	MOV	DPTR,#JTBL_RC
	LCALL	JmpWOffset			; RET: A=StatusOperasi

;M: A=KodeGagal (jika <> 0)
LPR_HapusCmd:
	MOV	B,A
	MOV	DPL,D_CMD_RxPtr_B
	MOV	DPH,#HIGH V8_CMD_RxCBuf
	MOVX	A,@DPTR				; = PjgCmd
	MOV	R1,A
	INC	DPL
	MOVX	A,@DPTR				; = KodeCmd
	MOV	R0,A
	INC	DPL
	MOVX	A,@DPTR				; = #id_cmd
	XCH	A,R1
	INC	A
	ADD	A,D_CMD_RxPtr_B
	MOV	D_CMD_RxPtr_B,A		; buang yg telah diproses

	MOV	A,B
	JZ	LPR_JawabCmd
;_LPR_CmdGagal:
	XCH	A,R0				; R0 <- kode_gagal
	;ORL	A,#80H
	XCH	A,R1				; R1 <- KodeCmd
	MOV	R2,A				; R2 <- #id_cmd
	MOV	A,#PJ_CmdGagal
	SJMP	RMT_TulisTx

_LPR_PjgSalah:
	;JZ	_LPR_VarParam
	MOV	A,#KJ_PjgCacat
	SJMP	LPR_HapusCmd

LPR_JawabCmd:
	MOV	A,R0
	RL	A
	MOV	DPTR,#DTBL_RC_Pjg+1
	MOVC	A,@A+DPTR

;M: A=PjgJwb, R0=KodeJwb, R1=ID
;   jika A < 7 : ParamJwb ada di R2..R7
;   else : ParamJwb ada di XRAM_Param
RMT_TulisTx:
	MOV	DPL,D_RMT_TxPtr_K
	MOV	DPH,#HIGH V8_RMT_TxCBuf
	MOVX	@DPTR,A				; = pjg_jwb
	INC	DPL
	ADD	A,#-2
	XCH	A,R0
	MOVX	@DPTR,A				; kode_jwb = KodeCmd !
	INC	DPL
	MOV	A,R1
	MOVX	@DPTR,A				; ID
	INC	DPL
	CJNE	R0,#7,$+3
	JC	__RT_IData			; param_jwb di R2..R7 (=1) ?
	MOV	R6,DPL
	MOV	R7,DPH
	MOV	DPTR,#V8_RMT_Param
	LCALL	XInPageCpy
	MOV	D_RMT_TxPtr_K,R6

__RT_CekTidur:
	JBC	F_RMT_TxTidur,__RT_AktifkanTI
	LJMP	LPR_Lagi
	;RET					; sebaiknya fungsi ret ?
__RT_AktifkanTI:
	SETB	TI				; bangunkan
	LJMP	LPR_Lagi

__RT_IData:
	MOV	A,R0
	JZ	__RTTx
	MOV	B,A
	MOV	R0,#AR2
__RTID:	MOV	A,@R0
	MOVX	@DPTR,A
	INC	DPL
	INC	R0
	DJNZ	B,__RTID
__RTTx:	MOV	D_RMT_TxPtr_K,DPL
	SJMP	__RT_CekTidur

RMT_CekSisaTx:
	MOV	A,D_RMT_TxPtr_K
	CPL	A
	ADD	A,D_RMT_TxPtr_B
	SETB	C			; 1-byte @PjgCmd
	SUBB	A,R0
	RET

;--------------------------------------------------
;!!! Ini hanya contoh, tidak semua difungsikan !!!!
;--------------------------------------------------
JTBL_RC:
	DW	RC_Ditolak		; #0, tidak difungsikan
	DW	RC_KonfigRMT
	DW	RC_StatusTRM
	DW	RC_SifatSimpulKEP
	DW	RC_NamaSimpulKEP
	DW	RC_MasukanKEP
	DW	RC_RstOtoKEP		; membuat semua dianggap berubah
	DW	RC_KeluaranKEP
	DW	JMB_Buka
	DW	JMB_Tutup
	DW	RC_StatusJMB
	CMD_DataJMB	EQU	($-JTBL_RC)/2
	DW	RC_JMBTakAktif

C_RMT_JmlCmd	EQU	($-JTBL_RC)/2

DTBL_RC_Pjg:
	DB	PJ_Minimum, PJ_CmdGagal
	DB	PC_KonfigRMT, PJ_KonfigRMT
	DB	PC_StatusTRM, PJ_StatusTRM
	DB	PC_SifatSimpulKEP, PJ_SifatSimpulKEP
	DB	PC_NamaSimpulKEP, PJ_NamaSimpulKEP
	DB	PC_MasukanKEP, PJ_MasukanKEP
	DB	PC_RstOtoKEP, PJ_RstOtoKEP
	DB	PC_KeluaranKEP, PJ_KeluaranKEP
	DB	PC_BukaJMB, PJ_BukaJMB
	DB	PC_TutupJMB, PJ_TutupJMB
	DB	PC_StatusJMB, PJ_StatusJMB
	DB	PC_JMBTakAktif, PJ_JMBTakAktif

PC_KonfigRMT		EQU	2+1
PJ_KonfigRMT		EQU	2
RC_KonfigRMT:
	MOV	A,R2
	MOV	DPTR,#NV_RMT_Modus
	MOVX	@DPTR,A
	CLR	A
	RET		; Konfig diUpdate setelah hubungan di/terputus

PC_StatusTRM		EQU	2
PJ_StatusTRM		EQU	2+1
RC_StatusTRM:

$INCLUDE(PANTAU.DEF)

PC_SifatSimpulKEP	EQU	2+2+1
PJ_SifatSimpulKEP	EQU	2
RC_SifatSimpulKEP:


PC_NamaSimpulKEP	EQU	2+2+C_KP_PjgNama
PJ_NamaSimpulKEP	EQU	2
RC_NamaSimpulKEP:
	CLR	A
	RET

PC_MasukanKEP	EQU	2+1
PJ_MasukanKEP	EQU	2+1+1
RC_MasukanKEP:
	MOV	DPL,R2
	MOV	DPH,#high V8_KP_Status
	MOVX	A,@DPTR				; hasil polling !
	MOV	R3,A
	CLR	A
	RET

PC_RstOtoKEP	EQU	2
PJ_RstOtoKEP	EQU	2
RC_RstOtoKEP:
	CLR	A
	MOV	DPL,A				; = # kartu
	CPL	A
	MOV	DPH,#high V8_KP_Perubahan
__RROP:	MOVX	@DPTR,A
	DJNZ	DPL,__RROP
	CLR	A
	;MOV	DPTR,#V_RMT_NomKEP
	;MOVX	@DPTR,A
	MOV	D_RMT_NomKEP,A
	RET

PC_KeluaranKEP		EQU	2+1+1
PJ_KeluaranKEP		EQU	2
RC_KeluaranKEP:

PC_BukaJMB		EQU	2+2
PJ_BukaJMB		EQU	2
EXTRN	CODE	(JMB_Buka)

PC_TutupJMB		EQU	2
PJ_TutupJMB		EQU	2
EXTRN	CODE	(JMB_Tutup)

PC_StatusJMB		EQU	2
PJ_StatusJMB		EQU	2
RC_StatusJMB:
	CLR	A
	RET

PC_JMBTakAktif	EQU	2
PJ_JMBTakAktif	EQU	3

RC_JMBTakAktif:
RC_Ditolak:
	MOV	A,#KJ_DiTolak
	RET

;_LPR_ParamCacat:
;	MOV	A,#KS_ParamCacat
;	RET


	END
;======================

	CLR	C
	MOV	A,D_PRR_PtrK			; isi = (256+k-B) MOD 256
	SUBB	A,D_CMD_RxPtr_B		; A <- isi
	ADD	A,#1+C_RMT_RtsOff		; A <- (255-sisa) + 1 + ambang
	MOV	P_RMT_Rts,C			; sisa \< ambang (C=1) -> off
	ADD	A,#-C_RMT_RtsOff		; A <- isi+1
	JZ	_RRI_FrameLebih			; 0 = 256, maks isi = 255


;RTI_InitModem:					; <- disini rts = on !
;	MOV	A,D_RMT_TxPtr_B
;	CJNE	A,D_RMT_TxPtr_K,_RTIT_Jemput
;	MOV	DPTR,#NV_RMT_Modus
;	MOVX	A,@DPTR
;	JNB	ACC.FP_RMT_InitModem,_RTI_BukaAkses
;	MOV	D_RTI_JMP,#CJT_CekModem
;	SETB	P_RMT_RTS			; rts -> off
;RTI_CekModem:
;	MOV	DPTR,#HW_PPI_PA
;	MOVX	A,@DPTR
;	JB	ACC.FP_RMT_CD,_RTI_selesai
;	SETB	F_RMT_CekCD
;	CLR	P_RMT_RTS			; rts -> on
;_RTI_BukaAkses:
;	SETB	REN				; mampukan akses
;	SJMP	RTI_TutupFr1

;MgrRemote:
;----- F: Memeriksa inisialiasi UART dan awal keaktifan akses remote
;	JB	REN,RWD_CekRTS			; akses sudah dibuka (=1) ?
;	JNB	TR_RMT,RemoteInit		; ada permintaan init (=0) ?
;	;JNB	P_RMT_RTS,__RAQ
;	JB	ES,__RAQ
;	JNB	TI,__RAQ
;	;-MOV	DPTR,#HW_PPI_Ctrl
;	;-MOV	A,#0 or 2*FP_RMT_dtr
;	;-MOVX	@DPTR,A				; dtr -> on
;	MOV	DPTR,#HW_PPI_PA
;	MOVX	A,@DPTR
;	JB	ACC.FP_RMT_DSR,__RAQ
;	CLR	P_RMT_RTS			; rts -> on
;	SETB	ES				; <- TxISR dijalankan (REN=0)
;__RAQ:	RET

	JNB	IP_EU,__ROSQ			; JMB aktif (=1) ?
	JNB	TR_EU,__ROSQ			; JMB aktif (=1) ?
	JNB	F_JMB_DsrOff,__ROS2
	JNB	F_JMB_RTS,__ROSQ
	SETB	F_JMB_TxTout
	MOV	A,D_JMB_TxPtr_B
	CJNE	A,D_JMB_TxPtr_K,__ROS1
	CLR	F_JMB_TxTOut
__ROS1:	SETB	P_JMB_RST
	CLR	TR_EU
	MOV	D_JMB_TxPtr_K,A		; <- agar RMT_RTS bisa aktif
__ROS2:	MOV	A,BA_JMB_Status
	ANL	A,#FM_JMB_Status
	JZ	__ROSQ				; ada laporan status (<>0) ?
	MOV	R2,A
	MOV	R0,#PJ_OtoJMB			; = 3
	LCALL	RMT_CekSisaTx
	JC	__ROSQ				; cukup tempat (=0) ?
	MOV	A,R2
	CPL	A
	ANL	BA_JMB_Status,A			; hapus yg telah dijemput
	MOV	R1,D_JMB_NomKartu
	MOV	A,#KJ_OtoJMB
	XCH	A,R0
	LCALL	RMT_TulisTx
__ROSQ:	;RET

;======================
ISRRemote:
	PUSH	PSW
	PUSH	ACC
	PUSH	DPL
	PUSH	DPH
	JNB	RI,__Ke_RRI_Selesai
	MOV	A,D_RMT_TxPtr_K
	CPL	A
	ADD	A,D_JMB_TxPtr_B		; A <- sisa sebelum ditulis
	JZ	?3
	;-ADD	A,#1+C_RMT_RtsOff
	;-MOV	P_RMT_Rts,C
	CJNE	A,#1+C_RMT_RtsOff,?1
	SETB	P_RMT_Rts			; RTS <- off
?1:	MOV	DPL,D_RMT_TXB
	MOV	DPH,#HIGH XRBUF_RMT
	MOV	A,SBUF
	MOVX	@DPTR,A
?3:	CLR	RI
	JNB	TI,?
	SETB	VTI
?4:

	JBC	F_RMT_TxTidur,__PB_AktifkanTI	;; dan memang tidur ?
