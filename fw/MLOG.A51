;REV:
; - Sumber dideteksi berdasarkan subentry perubahan (jika 0 -> nonkep)
; - Perubahan buff membuat lihat = muda
; - Baru masuk = muda

$INCLUDE(STDIO.DEF)
$INCLUDE(OS.DEF)

EXTRN	CODE	(JmlBitAktif, ChrDes12bNZ)
EXTRN	CODE	(MgrTugas_OSP, LCD_Cls, LCD_TlsCstrIni)
EXTRN	CODE	(LCD_SetXY, LCD_TulisChr, LCD_TulisXStr)
EXTRN	CODE	(LCD_KursorBlok)

EXTRN	CODE	(LOG_BacaBeda, LOG_MajuPtr, LOG_MundurPtr)
EXTRN	CODE	(LOG_CekCariEntry, LOG_CariEntryLagi)
EXTRN	CODE	(LOG_StrWaktuPlus, LOG_StrSumber)
;EXTRN	BIT	(F_LOG_TakTerekam)
EXTRN	DATA	(D_LOG_Buf_k, D_LOG_Buf_B)
;V_LOG_Buf
;D_LOG_TakTerekam_lo, D_LOG_TakTerekam_hi

PUBLIC	MenuLog

ISTACK			SEGMENT	DATA
			RSEG	ISTACK
			DS	0
RT_MLOG_BitLihat	EQU	0
RT_MLOG_PtrLihat	EQU	1
RT_MLOG_PosLihat_Lo	EQU	2
RT_MLOG_PosLihat_Hi	EQU	3
RT_MLOG_PtrJml_B	EQU	4		; ptr terakhir (yg dipalang)
RT_MLOG_PtrJml_K	EQU	5
RT_MLOG_Jml_lo		EQU	6
RT_MLOG_Jml_hi		EQU	7

C_MLOG_JmlRT		EQU	8

SegV_Umum	SEGMENT	XDATA
		RSEG	SegV_Umum
		DS	0

PU_MLOG_IsiWaktu	EQU	5+5

SegC_MLOG	SEGMENT	CODE
		RSEG	SegC_MLOG

MenuLog:
	;SETB	C
	;LCALL	_MLOG_SwapDt
_MLOG_Redraw:
	CLR	A
	MOV	ISTACK+RT_MLOG_Jml_Lo,A
	MOV	ISTACK+RT_MLOG_Jml_Hi,A
	MOV	A,D_LOG_Buf_B		; Tangkap harga buntut...
	MOV	ISTACK+RT_MLOG_PtrJml_B,A	; agar perubahannya terdeteksi
	MOV	ISTACK+RT_MLOG_PtrJml_K,A	; init: k=B
	CJNE	A,D_LOG_Buf_K,MLOG_TambahBaru	; B<>k -> berisi
_MLOG_Kosong:
	LCALL	LCD_TlsCstrIni
	DB	FF,'= 0 =',EOS
	SJMP	_MLOG_MT

_MLOG_Idle:
	MOV	A,ISTACK+RT_MLOG_PtrJml_B
	CJNE	A,D_LOG_Buf_B,_MLOG_Redraw	; buntut berubah ?, Y-> reset
	MOV	A,ISTACK+RT_MLOG_PtrJml_K
	CJNE	A,D_LOG_Buf_K,MLOG_TambahBaru	; kepala berubah ?, Y-> tambah
_MLOG_MT:
	LCALL	MgrTugas_OSP
	SJMP	_MLOG_Redraw			; Redraw
	SJMP	_MLOG_Idle
	SJMP	MLOG_TArah
;_MLOG_Ttdk:
	SJMP	_MLOG_Q
_MLOG_Tya:
	JNB	F0,_MLOG_Idle
	JB	F_LOG_Dicetak,_MLOG_Idle	; hapus log jika cetak=0
	MOV	D_LOG_Buf_B,D_LOG_Buf_K		; b+=b-=k+=k- jika b-=k-
	SJMP	_MLOG_Idle			; cetak jika ada perubahan
						; abaikan jika b-=k-
EXTRN	BIT	(F_LOG_Dicetak)

_MLOG_Q:
	RET
	;CLR	C
;_MLOG_SwapDt:
	;MOV	RCcS,#0
	;MOV	RCcT,#C_MLOG_JmlRT
	;LJMP	SwapIStack

EXTRN	CODE	(SwapIStack)

;M: A=ISTACK+RT_MLOG_PtrJml_K
MLOG_TambahBaru:
	LCALL	LOG_BacaBeda			; RET: A = BIT-BIT yang berubah
	LCALL	JmlBitAktif
	JNZ	__tbj2				; Sumber dari kep (<> 0) ?
	INC	A				; non kep = 1 Entry
__tbj2:	ADD	A,ISTACK+RT_MLOG_Jml_Lo
	MOV	ISTACK+RT_MLOG_Jml_Lo,A
	JNC	__tbj3
	INC	ISTACK+RT_MLOG_Jml_Hi			; hanya 16-BIT
__tbj3:	MOV	A,ISTACK+RT_MLOG_PtrJml_K
	LCALL	LOG_MajuPtr
	MOV	ISTACK+RT_MLOG_PtrJml_K,A
	CJNE	A,D_LOG_Buf_K,MLOG_TambahBaru	; BUG: B bergerak -> diulang !
;_MLOG_RstPosBit:
	SJMP	MLOG_EntriAkhir

; semua dibawah ini berdasarkan nilai beku
MLOG_TArah:
	MOV	A,ISTACK+RT_MLOG_PtrJml_B		; -> berdasarkan nilai beku
	CJNE	A,ISTACK+RT_MLOG_PtrJml_K,_MLOG_JTArah	; B=k -> kosong
__Ke_MLOG_MT:
	SJMP	_MLOG_MT
_MLOG_JTArah:
	MOV	A,RTmbl
	ADD	A,RTmbl				; = A*2
	MOV	DPTR,#$+3+1
	JMP	@A+DPTR
	SJMP	MLOG_EntryNaik
	SJMP	MLOG_EntryTurun
	SJMP	MLOG_EntryAwal			; paling tua
;	SJMP	MLOG_EntriAkhir

MLOG_EntriAkhir:
	MOV	ISTACK+RT_MLOG_PosLihat_Lo,ISTACK+RT_MLOG_Jml_Lo; =jml total
	MOV	ISTACK+RT_MLOG_PosLihat_Hi,ISTACK+RT_MLOG_Jml_Hi
	MOV	A,ISTACK+RT_MLOG_PtrJml_K
	LCALL	LOG_MundurPtr
	MOV	ISTACK+RT_MLOG_PtrLihat,A
	MOV	ISTACK+RT_MLOG_BitLihat,#7		; = super muda
	CLR	F0				; turun = tua
	SJMP	_MLOG_CekGeser

MLOG_EntryAwal:
	MOV	ISTACK+RT_MLOG_PosLihat_Lo,#1		; PosLihat dimulai dari #1
	CLR	A
	MOV	ISTACK+RT_MLOG_PosLihat_Hi,A
	MOV	ISTACK+RT_MLOG_BitLihat,A			; = super tua
;	MOV	A,ISTACK+RT_MLOG_PtrJml_B
	MOV	ISTACK+RT_MLOG_PtrLihat,ISTACK+RT_MLOG_PtrJml_B
	SETB	F0				; naik ke muda jika tak ada
_MLOG_CekGeser:
	MOV	R2,ISTACK+RT_MLOG_BitLihat
	MOV	R3,ISTACK+RT_MLOG_PtrLihat
	LCALL	LOG_CekCariEntry			; cek dan geser
;_MLOG_CtkBaru:
	SJMP	_MLOG_TampilLihat

MLOG_EntryTurun:
	MOV	A,ISTACK+RT_MLOG_PosLihat_Lo
	CJNE	A,#1,_MLOG_ETurun		; Lo-1 <> 0 -> turunkan
	MOV	A,ISTACK+RT_MLOG_PosLihat_Hi
	JZ	__Ke_MLOG_MT			; Hi=0,Lo=1 -> Sudah di Awal
_MLOG_ETurun:
	MOV	A,ISTACK+RT_MLOG_PosLihat_Lo		; = sebelum dikurangi
	DEC	ISTACK+RT_MLOG_PosLihat_Lo
	JNZ	_MLOG_CariTua
	DEC	ISTACK+RT_MLOG_PosLihat_Hi
_MLOG_CariTua:
	CLR	F0				; turun = tua
	SJMP	_MLOG_CariGeser

MLOG_EntryNaik:
	MOV	A,ISTACK+RT_MLOG_PosLihat_Lo
	CJNE	A,ISTACK+RT_MLOG_JML_Lo,_MLOG_EN	; Pos_Lo <> Jml_Lo -> naikkan
	MOV	A,ISTACK+RT_MLOG_PosLihat_Hi
	CJNE	A,ISTACK+RT_MLOG_JML_Hi,_MLOG_EN	; Pos_Hi <> Jml_Hi -> naikkan
	SJMP	__Ke_MLOG_MT
_MLOG_EN:
	INC	ISTACK+RT_MLOG_PosLihat_Lo
	MOV	A,ISTACK+RT_MLOG_PosLihat_Lo		; = sesudah ditambah
	JNZ	_MLOG_CariMuda
	INC	ISTACK+RT_MLOG_PosLihat_Hi
_MLOG_CariMuda:
	SETB	F0				; naik = muda
_MLOG_CariGeser:
	MOV	R2,ISTACK+RT_MLOG_BitLihat
	MOV	R3,ISTACK+RT_MLOG_PtrLihat
	LCALL	LOG_CariEntryLagi

_MLOG_TampilLihat:
	MOV	ISTACK+RT_MLOG_BitLihat,R2
	MOV	ISTACK+RT_MLOG_PtrLihat,R3
	MOV	DPTR,#SegV_Umum+PU_MLOG_IsiWaktu
	LCALL	LOG_StrWaktuPlus
	MOV	A,#cr
	MOVX	@DPTR,A
	INC	DPTR
	MOV	R2,ISTACK+RT_MLOG_BitLihat
	MOV	R3,ISTACK+RT_MLOG_PtrLihat
	LCALL	LOG_StrSumber			; bukan waktu
	MOV	R2,ISTACK+RT_MLOG_PosLihat_Lo
	MOV	R3,ISTACK+RT_MLOG_PosLihat_Hi
	MOV	DPTR,#SegV_Umum
	LCALL	ChrDes12bNZ			; non zero leading
	MOV	A,R0				; jml chr
	PUSH	ACC
	MOV	A,#'/'
	MOVX	@DPTR,A
	INC	DPTR
	MOV	R2,ISTACK+RT_MLOG_Jml_lo
	MOV	R3,ISTACK+RT_MLOG_Jml_hi
	LCALL	ChrDes12bNZ			; non zero leading
	MOV	A,D_LOG_Buf_K
	LCALL	LOG_MajuPtr
	CJNE	A,D_LOG_Buf_B,__MTL		; penuh (b=k+1) ?
	MOV	A,#'P'
	MOVX	@DPTR,A
	INC	DPTR
__MTL:	MOV	A,#EOS
	MOVX	@DPTR,A
;_MLOG_Redraw:
	LCALL	LCD_Cls
	MOV	DPTR,#SegV_Umum
	LCALL	LCD_TulisXStr
	MOV	DPTR,#SegV_Umum+PU_MLOG_IsiWaktu
	LCALL	LCD_TulisXStr
	POP	ACC
	DEC	A
	LCALL	LCD_SetXY
	LCALL	LCD_KursorBlok
	LJMP	_MLOG_MT			; berbagi tugas

	END

'_123456789_123456789_123456789_123456789'
'No 2345/2334+: Sen 12-23-1990 12-12-12'
'K=M #S=1234 ABCDEFGHIJ'

'2345/2334: Sen 12-23-1990 12-12-12'
'2345/2334+65578: Sen 12-23-1990 12-12-12'
'2345 (2334+41234) K=M #S=1234 ABCDEFGHIJ'
'Sen 12-23-1990 12-12-12'
'*** Terminal Diaktifkan'
'*** Akses Remote Dibuka'
'K=R Akses Remote Ditutup'
'K=J Jembatan dibuka
'12231990 121212'
'K=P Tak Tercatat = 256'
'_123456789_123456789_123456789_123456789_123456789_123456789_123456789_123456789'


;===============================
	MOV	R0,#ISTACK
	MOV	B,#C_MLOG_JmlRS
	MOV	DPTR,#CA_MLOG_RNAwal
	LCALL	JemputSReg
;2	MOV	R0,#ISTACK
;3	MOV	B,#C_MLOG_JmlRS
;3	MOV	DPTR,#CA_MLOG_RNAwal
;3=11	LJMP	SimpanSReg

LOG_MajuPtrK:
	MOV	A,D_LOG_Buf_k
	INC	A
	CJNE	A,#C_LOG_JmlEntry,_lmjpk
	CLR	A
_lmjpk:	MOV	D_LOG_Buf_k,A
	RET
LOG_MajuPtrB:
	MOV	A,D_LOG_Buf_B
	INC	A
	CJNE	A,#C_LOG_JmlEntry,_lmjpb
	CLR	A
_lmjpb:	MOV	D_LOG_Buf_B,A
	RET
;====================================================
LOG_cek_log:
	RET

;Hapus: 1. Dicetak
;	2. Dibaca
;	3. Dicetak dan dibaca
;Tampil: 1. Baru
;	 2. Baru dan Lama

;---------------------------
; masukan : DPL = # log
; keluaran: R2 - R7 = waktu
;---------------------------

;LOG_jam:
;LOG_tgl:
;LOG_status:
LOG_3byte:
	MOV	DPL,R2
	MOVX	A,@DPTR
	MOV	R3,A
	INC	DPH
	MOVX	A,@DPTR
	MOV	R4,A
	INC	DPH
	MOVX	A,@DPTR
	MOV	R5,A
	INC	DPH
	RET


	MOV	DPH,#HIGH V_LOG_Buf
	MOVX	A,@DPTR
	MOV	R5,A
	INC	DPH
	MOVX	A,@DPTR
	MOV	R6,A
	INC	DPH
	MOVX	A,@DPTR
	MOV	R7,A
	INC	DPH		; mengacu kepada #JMB
	RET


