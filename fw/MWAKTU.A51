;REV: Bagian langsung dari MenuUtama

CM_MW_Thn	EQU	2		; Nomor Opsi
;C_MW_ChrThn	EQU	4		; Jml Karakter
;XY_MW_Info	EQU	0H
XY_MW_Waktu	EQU	40H
C_RTC_ThnAwal	EQU	1998
C_RTC_ThnAkhir	EQU	2099

$INCLUDE(SCH.DEF)
$INCLUDE(STDIO.DEF)

EXTRN	BIT	(F_LCD_FlipKedip, F_MT_Redraw, F_LCD_PosKedip)
EXTRN	CODE	(LCD_SetXY)
EXTRN	CODE	(LCD_TlsXYXChr, LCD_TulisXStr)
EXTRN	CODE	(LCD_KedipXChr, LCD_RstKdpOn, LCD_RstKdpOff, LCD_FlipKedip)
EXTRN	CODE	(MgrTugas_OSP, TgsLtrBelakang)
EXTRN	CODE	(RTC_StrWaktu, StrWaktu, PCF_SimpanWaktu)
EXTRN	CODE	(PanjangHari)
EXTRN	DATA	(D_RTC_Tgl, D_RTC_Bln, D_RTC_Thn)
EXTRN	DATA	(D_RTC_Jam, D_RTC_Mnt,D_RTC_Dtk)
EXTRN	BIT	(IE_PB, IE_RTC)

PUBLIC	MWaktu

SegV_Umum	SEGMENT	XDATA
		RSEG	SegV_Umum
		DS	0

ISTACK		SEGMENT	DATA
		RSEG	ISTACK
		DS	0
RT_MW_Opsi	EQU	1
RT_MW_Tgl	EQU	2		; urutan disesuaikan dgn tampilan !
RT_MW_Bln	EQU	3
RT_MW_Thn	EQU	4
RT_MW_Jam	EQU	5
RT_MW_Mnt	EQU	6
RT_MW_Dtk	EQU	7

CA_MW_Dasar	EQU	RT_MW_Opsi
CA_MW_Opsi0	EQU	RT_MW_Tgl
;RB_MW_PUSH	EQU	R2		; = RT_MW_Opsi jika ada redraw

C_MW_1stOpsi	EQU	0		; = Tgl	; pilihan pertama-kali jalan

SegC_MWaktu	SEGMENT	CODE
		RSEG	SegC_MWaktu
MWaktu:
	JB	PSW.1,_MW_Redraw2
	MOV	ISTACK+RT_MW_Opsi,#C_MW_1stOpsi
	;MOV	RB_MW_PUSH,#C_MW_1stOpsi
	;CLR	IE_RTC				; lumpuhkan RTC_ISR
	MOV	ISTACK+RT_MW_Dtk,D_RTC_Dtk
	MOV	ISTACK+RT_MW_Mnt,D_RTC_Mnt
	MOV	ISTACK+RT_MW_Jam,D_RTC_Jam
	MOV	ISTACK+RT_MW_Tgl,D_RTC_Tgl
	MOV	ISTACK+RT_MW_Bln,D_RTC_Bln
	MOV	ISTACK+RT_MW_Thn,D_RTC_Thn
	;SETB	IE_RTC

RB_Dtk	EQU	R2
RB_Mnt	EQU	R3
RB_Jam	EQU	R4
RB_Tgl	EQU	R5
RB_Bln	EQU	R6
RB_Thn	EQU	R7
RB_MW_U1	EQU	R1
RB_Cch0	EQU	R0

_MW_Redraw2:
	;MOV	ISTACK+RT_MW_Opsi,RB_MW_PUSH
	SETB	F_LCD_PosKedip
_MW_Update:
	MOV	RB_Dtk,ISTACK+RT_MW_Dtk
	MOV	RB_Mnt,ISTACK+RT_MW_Mnt
	MOV	RB_Jam,ISTACK+RT_MW_Jam
	MOV	RB_Tgl,ISTACK+RT_MW_Tgl
	MOV	RB_Bln,ISTACK+RT_MW_Bln
	MOV	RB_Thn,ISTACK+RT_MW_Thn
	MOV	DPTR,#SegV_Umum
	LCALL	StrWaktu
_MW_Cetak:
	SETB	F_LCD_FlipKedip
_MW_CtkKdp:
	MOV	RB_MW_U1,ISTACK+RT_MW_Opsi	; = RT_MW_Pos
	MOV	A,#4				; = Nama Hari, termasuk spasi !
	ADD	A,RB_MW_U1
	ADD	A,RB_MW_U1
	ADD	A,RB_MW_U1				; = antar opsi berjarak 3 chr
	CJNE	RB_MW_U1,#CM_MW_Thn+1,$+3
	JC	_MW_Normal			; sesudah thn (CF=0) ?
	ADD	A,#4-2				; = pergeseran sudah thn

_MW_Normal:
	MOV	RB_CCh0,A				; = jml norm sebelum chr_kdp
	MOV	A,#XY_MW_Waktu
	MOV	DPTR,#SegV_Umum
	LCALL	LCD_TlsXYXChr
	MOV	RB_CCh0,#2				; selain tahun = 2 chr
	CJNE	RB_MW_U1,#CM_MW_Thn,_MW_Kedip
	MOV	RB_CCh0,#4				; tahun = 4 chr
_MW_Kedip:
	LCALL	LCD_KedipXChr
	LCALL	LCD_TulisXStr
_MW_MT:
	LCALL	MgrTugas_OSP			; berbagi tugas
	SJMP	_MW_Redraw
	SJMP	_MW_CekKedip			; idle
	SJMP	_MW_TArah			; #0..3
	SJMP	_MW_Ttdk			; #4
;	SJMP	_MW_Tya				; #5
_MW_Tya:
;	MOV	A,ISTACK+RT_MW_Tanda
;	JZ	_MW_Ttdk
	PUSH	PSW				; simpan status klik
	CLR	IE_PB				; lumpuhkan intr RTC + KP
	;PUSH	IE
	;ANL	IE,#NOT HanyaSUART		; lumpuhkan ISR yg membaca wkt
	MOV	D_RTC_Dtk,ISTACK+RT_MW_Dtk
	MOV	D_RTC_Mnt,ISTACK+RT_MW_Mnt
	MOV	D_RTC_Jam,ISTACK+RT_MW_Jam
	MOV	D_RTC_Tgl,ISTACK+RT_MW_Tgl
	MOV	D_RTC_Bln,ISTACK+RT_MW_Bln
	MOV	D_RTC_Thn,ISTACK+RT_MW_Thn
	;POP	IE
	SETB	IE_PB
_MW_cari1:
	LCALL	TgsLtrBelakang
	JNB	P_IRQ_RTC,_MW_cari1		; loop jika belum 1
_MW_cari0:
	LCALL	TgsLtrBelakang
	JBC	F_MT_Redraw,_MW_cari1		; jika ditimpa -> ulang
	JB	P_IRQ_RTC,_MW_cari0		; loop jika belum 0
_MW_simpan:
	LCALL	PCF_SimpanWaktu
	JNC	_MW_QP
;;;;;;;;;;;;;
_MW_QP:
	POP	PSW
	;CLR	F0
_MW_Ttdk:
	RET

_MW_Redraw:
	;MOV	RB_MW_PUSH,ISTACK+RT_MW_Opsi
	;SETB	F_MT_Redraw
	SETB	PSW.1				; = redraw 'upper' menu
	;SETB	F0				; semua tingkat
	RET

_MW_CekKedip:
	JB	F_LCD_FlipKedip,_MW_CtkKdp	; kedip berguling (=1) ?
	SJMP	_MW_MT

_MW_TArah:
	MOV	A,ISTACK+RT_MW_Opsi		; No Opsi
	ADD	A,#ISTACK+CA_MW_Opsi0	; A <- @Reg
	XCH	A,R0				; @Reg <-> Tombol
	CJNE	A,#2,$+3		; TAtas(+1) = 0, Tbawah(-1) = 1 (C=1)
	JC	_MW_NilaiUbah		; Tkiri(-1) = 2, Tkanan(+1) = 3 (C=0)
	MOV	R0,#ISTACK+RT_MW_Opsi	; R0 = @No_Opsi !
	CPL	A
_MW_NilaiUbah:
	RRC	A			; C: Ganjil(-1)=1, Genap(+1)=0
	SUBB	A,ACC			; <- Gj: A=-1,C=1; Gn: A=0,C=0
	CPL	C			; Gj: A=-1, C=0; Gn: A=0, C=1
_MW_UbahNilai:
	DEC	ISTACK+RT_MW_Bln		; buat bln = 0..11
	ADDC	A,@R0
	MOV	@R0,A			; @Reg <- Nilai_baru sementara
;_MW_CekNilai:
	MOV	A,R0			; @Reg
;+
	CLR	C
	SUBB	A,#$ + 3 - TBL_MW_NilaiMaks + ISTACK + CA_MW_Dasar
	;ADD	A,#TBL_MW_NilaiMaks - $ - 3 - ISTACK - CA_MW_Dasar
;+
	MOVC	A,@A+PC			; A <- Nilai_maks
	CJNE	@R0,#0FFH,__MCN1	; = -1 (juga untuk maks = +0FFH) ?
	MOV	@R0,A			; = (berguling dari min ke) nilai maks
	SJMP	__MCN3


TBL_MW_NilaiMaks:	; urutan disesuaikan dengan RT (juga tampilan)
	DB	5			; Opsi = 0..5 (tgl s/d dtk)
	DB	0FFH,11, C_RTC_ThnAkhir-C_RTC_ThnAwal	; Tgl(semu), Bln-1, Thn
	DB	23, 59, 59		; Jam, Mnt, Dtk

__MCN1:	MOV	B,A			; B <- nilai maks
	MOV	A,@R0
	CJNE	A,B,__MCN2
	SETB	C
__MCN2:	JC	__MCN3			; C=1: nilai_baru < nilai_maks
	MOV	@R0,#0			; = (berguling dari maks ke) nilai min
__MCN3:	INC	ISTACK+RT_MW_Bln		; kembalikan bln = 1..12
	CJNE	R0,#ISTACK+RT_MW_Opsi,_MW_CekTgl
	SETB	F_LCD_PosKedip
	LJMP	_MW_Cetak

_MW_CekTgl:
	CJNE	R0,#ISTACK+RT_MW_Jam,$+3
	JNC	_MW_DiUpdate
	MOV	A,ISTACK+RT_MW_Thn			; = tahun
	MOV	RB_Bln,ISTACK+RT_MW_Bln		; = bulan
	LCALL	PanjangHari		; RET CF = 0
	SUBB	A,ISTACK+RT_MW_Tgl
	XCH	A,ISTACK+RT_MW_Tgl
	JNC	__MCT0			; tgl_maks - tgl_baru >/ 0 (C=0)?
	MOV	A,#1			; jika ya -> tgl_baru = 1
__MCT0:	JZ	_MW_DiUpdate
	XCH	A,ISTACK+RT_MW_Tgl
_MW_DiUpdate:
	CLR	F_LCD_PosKedip
	LJMP	_MW_Update

	END
