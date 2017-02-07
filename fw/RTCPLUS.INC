;C_RTC_HariAwal	set	4	; 1 Jan 1998 = Kamis (=4)
C_RTC_HariAwal	EQU	(6+((365*C_RTC_ThnAwal)+((C_RTC_ThnAwal+3)/4))) MOD 7
;C_RTC_ThnAwal	set	1998

SpasiTgl	EQU	'/'	;atau '-'
;C_PjgStrHari	EQU	4

$INCLUDE(STDIO.DEF)

EXTRN	CODE	(SwapPtr16, CStrCpy)

PUBLIC	RTC_StrWaktu, StrWaktu, HariPerbulan, PanjangHari
PUBLIC	ChrDes2Dig
PUBLIC	ChrJam, ChrTgl, ChrHariTgl
;ChrWaktu:
;PUBLIC	C_PjgStrHari

;TglKeHari:
;StrHari:

SegC_RTCPLUS	SEGMENT	CODE
		RSEG	SegC_RTCPLUS

;---------------------------------------------------
; F: Mendapatkan str waktu (tgl & jam) dari RTC
; M: DPTR tempat str
; R: Semua
;---------------------------------------------------
RTC_StrWaktu:
	CLR	IE_RTC
	MOV	RDtk,D_RTC_Dtk
	MOV	RMnt,D_RTC_Mnt
	MOV	RJam,D_RTC_Jam
	MOV	RTgl,D_RTC_Tgl
	MOV	RBln,D_RTC_Bln
	MOV	RThn,D_RTC_Thn
	SETB	IE_RTC
StrWaktu:
	LCALL	ChrHariTgl
	MOV	A,RJam
	MOV	RTgl,A
	MOV	A,RMnt
	MOV	RBln,A
	MOV	A,RDtk
	MOV	RThn,A
	LCALL	ChrJam
	MOV	A,#EOS
	MOVX	@DPTR,A
	RET

;----------------------------------------------
; rutin untuk mendapatkan tanggal diakhir bulan
; masukan  : RBln= bulan, RThn = tahun
; keluaran : ACC = jml tgl yang dimaksud
;----------------------------------------------

HariPerbulan:
	MOV	A,RThn			; = tahun
PanjangHari:
	ADD	A,#C_RTC_ThnAwal MOD 4
	RRC	A
	ORL	C,ACC.0			; tahun_kabisat MOD 4 = 0 -> CY=0
	MOV	A,RBln
TanggalMaks:
	ANL	A,#00001101B		; A <- 0000-XX0XB
	JNZ	__TM1			; bulan 2 (=0) ?
	;SUBB	A,#-29			; kabisat = 29, non kabisat = 28
	;CLR	C
	CPL	C
	ADDC	A,#28
	RET
__TM1:	JNB	ACC.3,__TM2		; A = 0000-1XXXB (bulan 8..12) ?
	CPL	ACC.0			; jika ya: ganjil <-> genap
__TM2:	ANL	A,#1
	ADD	A,#30			; bulan ganjil = 31, genap = 30
	RET

;-----------------------------------------------------
; subrutin untuk menghasilkan chr waktu pada XRAM
; M:	RTgl=jam/tgl, RBln=mnt/bln, RThn=dtk/thn
;	DPTR=tujuan
; K:	[tujuan]= hasil, DPTR= xram berikutnya
; R:	flag, ACC, B, R6, R7
;-----------------------------------------------------
;ChrWaktu:
;	MOV	A,#' '			; spasi terlebih dahulu !
;	MOVX	@DPTR,A
;	INC	DPTR
ChrHariTgl:
	LCALL	TglKeHari
ChrTgl:
	MOV	A,RThn
	MOV	B,#100
	ADD	A,#C_RTC_ThnAwal MOD 100
	JNC	_abad1
	ADD	A,#56				;255+k = (2*100) + [(k-1)+56]
	DIV	AB
	ADD	A,#2 + (C_RTC_ThnAwal / 100)
	SJMP	_abad2
_abad1:	DIV	AB
	ADD	A,#C_RTC_ThnAwal / 100
_abad2:	XCH	A,RThn
	PUSH	ACC
	PUSH	B
	MOV	B,#SpasiTgl
	LCALL	_StrSubWaktu
	POP	ACC
	LCALL	ChrDes2Dig		; <- thn dig satuan & puluhan
	POP	ACC
	MOV	RThn,A
	RET

ChrJam:
	MOV	B,#':'			; spasi subjam
_StrSubWaktu:
	MOV	A,#' '			; spasi terlebih dahulu !
	MOVX	@DPTR,A
	INC	DPTR
;_ChrJamTgl:
	MOV	A,RTgl			;jam/tgl
	LCALL	ChrDes2Dig
	MOV	A,RBln			;mnt/bln
	LCALL	_ChrSpasi
	MOV	A,RThn			;dtk/thn
;	LCALL	_ChrSpasi
;	MOV	A,#EOS
;	MOVX	@DPTR,A
;	RET
_ChrSpasi:
	XCH	A,B
	MOVX	@DPTR,A			; = karakter pemisah
	INC	DPTR
	XCH	A,B
ChrDes2Dig:
	PUSH	B
	MOV	B,#10
	DIV	AB
	ADD	A,#'0'
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,B
	ADD	A,#'0'
	MOVX	@DPTR,A
	INC	DPTR
	POP	B
	RET

;-------------------------------------------------------------
; Subrutin untuk mendapatkan nama hari suatu tanggal
; masukan tahun merupakan tahun_relatif terhadap tahun_awal
; berlaku untuk 256 tahun jika syarat th_kabisat hanya habis dibagi 4
; M: RTgl = tanggal, RBln = bulan, RThn = tahun (0=thn_awal)
;    DPTR = @[Tujuan]
; R: A, B, R_T2H
;-------------------------------------------------------------
R_T2H	EQU	R0

TglKeHari:
	MOV	A,RBln			; 1 = Januari
	ADD	A,#DTBL_HariDasar - $ - 4
	MOVC	A,@A+PC			; tbl: tgl=0, bln B-1, thn 0 (th_awal)
	ADD	A,RTgl			; A <- delta tanpa pengaruh tahun
	MOV	R_T2H,A

	MOV	A,RThn
	ADD	A,#C_RTC_ThnAwal MOD 4
	ANL	A,#11B
	JNZ	__TH1			; thn kabisat (=0) ?
	MOV	A,RBln
	ADD	A,#-3
	JNC	__TH1			; bln 3..12 (CY=1) ?
	INC	R_T2H			; <- delta _setelah_ tgl 29, bln 2

__TH1:	MOV	A,RThn
	ADD	A,#(C_RTC_ThnAwal + 3) MOD 4
	RRC	A			; 9-BIT !
	CLR	C
	RRC	A			; = jml th_kabisat yg _telah_ dilewati
	ADD	A,R_T2H			;; pergeseran 2-hari terjadi _setelah_
					;; thn kabisat dilewati
	ADD	A,RThn
	JNC	__TH2
	ADD	A,#256 MOD 7		; (A+256) MOD 7 = A+(256 MOD 7)
__TH2:	MOV	B,#7
	DIV	AB			; B <- A MOD 7

;; mentransfer 3 chr nama hari
	MOV	A,#3
	MUL	AB
	ADD	A,#STBL_NamaHari - __TH4
	MOV	R_T2H,A
	MOV	B,#3
__TH3:	MOV	A,R_T2H
	INC	R_T2H
	MOVC	A,@A+PC
__TH4:	MOVX	@DPTR,A
	INC	DPTR
	DJNZ	B,__TH3
	RET

HR	EQU	C_RTC_HariAwal + 6	; = C_RTC_HariAwal - 1
DTBL_HariDasar:
	DB	HR+0,HR+3,HR+3,HR+6,HR+1,HR+4,HR+6,HR+2,HR+5,HR+0,HR+3,HR+5
		; #hari pada tgl 0 (nol), bln B(-1), thn 0 (dianggap bukan kbst)
		;; relatif terhadap bln 1

STBL_NamaHari:
	DB	'MinSenSelRabKamJumSab'	; hari (0=minggu, 6=sabtu)


