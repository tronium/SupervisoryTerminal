;00:19am 04-01-1999 Modifikasi Sistem Antrian

$INCLUDE(OS.DEF)
$INCLUDE(STDIO.DEF)
$INCLUDE(SCH.DEF)

EXTRN	CODE	(SwapIStack, SwapPtr16, CStrCpy)
EXTRN	CODE	(LOG_CekCariEntry, LOG_StrWaktu, LOG_StrSumberPlus)
EXTRN	CODE	(LOG_CariEntryLagi)
EXTRN	CODE	(LOG_MajuPtrB)
EXTRN	DATA	(D_LOG_Buf_B, D_LOG_Buf_K)
EXTRN	XDATA	(HW_PPI_PA, HW_PPI_PB, HW_PPI_PC, HW_PPI_Ctrl)
EXTRN	NUMBER	(Str_KopCetak)

PUBLIC	PrinterISR, IRQ_PRN, VIE_PRN
PUBLIC	MgrPrinter, PRN_Init
PUBLIC	F_PRN_WDT, D_PRN_WDT


;---------
CT_PRN_TOut		EQU	2		; satuan detik
;CT_PRN_TInit		EQU	5		; detik
C_PRN_PjgBaris		EQU	56		; jml baris perhalaman

C_PRN_PjgKolomCtk	EQU	60
C_PRN_JmlBarisKop	EQU	3		; teks + garis

SegD_Prn	SEGMENT	DATA
			RSEG	SegD_Prn

D_PRN_WDT:		DS	1	; pewaktu timeout
D_PRN_PtrK:		DS	1
D_PRN_PtrB:		DS	1

EXTRN	BIT	(F_LOG_Dicetak, F_LOG_IzinTimpa, F_LOG_TakTerekam)

SegB_Prn		SEGMENT	BIT
			RSEG	SegB_Prn

F_PRN_WDT:		DBIT	1
F_PRN_ButuhAck:		DBIT	1
VIE_PRN:		DBIT	1

SegV8			SEGMENT	XDATA
			RSEG	SegV8
V8_PRN_Buf:		DS	256

ISTACK			SEGMENT	DATA

RS_PRN_PosBaris		EQU	0		; posisi baris kepala printer
RS_PRN_PtrAntri_K	EQU	1
RS_PRN_PtrAntri_B	EQU	2
RS_PRN_TugasAktif	EQU	3
RS_PRN_Param0		EQU	4
RS_PRN_Param1		EQU	5
RS_PRN_Param2		EQU	6
RS_PRN_Param3		EQU	7

C_PRN_JmlRS		EQU	8
C_PRN_JmlRT		EQU	0
C_PRN_JmlRN		EQU	C_PRN_JmlRS

;RT_PG_CchWkt		EQU	0
C_PG_JmlRT		EQU	0

SegV16			SEGMENT	XDATA
			RSEG	SegV16
CA_PRN_RNAwal		EQU	$
RN_PRN_PosBaris:	DS	1
RN_PRN_PtrAntri_K:	DS	1
RN_PRN_PtrAntri_B:	DS	1
RN_PRN_TugasAktif:	DS	1
RN_PRN_Param0:		DS	1
RN_PRN_Param1:		DS	1
RN_PRN_Param2:		DS	1
RN_PRN_Param3:		DS	1

; & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & &

		CSEG	AT	IVec_Printer
		CLR	IE_PRN			; anti bug
		RETI
		;LJMP	PrinterISR

SegC_MgrPrn	SEGMENT	CODE
	RSEG	SegC_MgrPrn

MgrPrinter:
	JNB	VIE_PRN,__MP_RET		; pencetakan dimampukan (=1) ?
	JNB	F_PRN_ButuhAck,SpoolerCetak	; sudah selesai dicetak (=0) ?
	JBC	IRQ_PRN,PrinterISR
	JNB	F_PRN_WDT,__MP_RET		; sudah timeout (=1) ?
	LJMP	PrinterGagal
__MP_RET:
	RET

; & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & &

PrinterISR:
	;PUSH	PSW
	;PUSH	ACC
	;PUSH	DPL
	;PUSH	DPH
;_PISR_antrian:
	MOV	A,D_PRN_PtrB
	CJNE	A,D_PRN_PtrK,_PISR_Jemput	; B=k -> kosong
	CLR	F_PRN_ButuhAck
	SJMP	_PISR_QPop

_PISR_Jemput:
	MOV	DPL,A
	MOV	DPH,#HIGH V8_PRN_Buf
	MOVX	A,@DPTR
	INC	D_PRN_PtrB			; B=B+1

	MOV	DPTR,#HW_PPI_PB
	MOVX	@DPTR,A				; kirim chr ke PB

;_PISR_Strobe:
	MOV	DPTR,#HW_PPI_Ctrl
	MOV	A,#0 or (2*FP_PRN_stobe)
	MOVX	@DPTR,A				; aktifkan !STROBE (reset PC.4)
	MOV	A,#1 or (2*FP_PRN_stobe)
	MOVX	@DPTR,A				; nonaktifkan !STROBE (set)
	MOV	D_PRN_WDT,#CT_PRN_TOut		; reset cacahan
	CLR	F_PRN_WDT
	;SETB	F_PRN_ButuhAck			; sudah 1 

_PISR_QPop:
	;POP	DPH
	;POP	DPL
	;POP	ACC
	;POP	PSW
	;RETI
	RET

; & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & &

SpoolerCetak:
	SETB	C
	LCALL	_PRN_SwapReg

	MOV	A,ISTACK+RS_PRN_TugasAktif
	MOV	DPTR,#JTBL_TgsCtk
	JMP	@A+DPTR

JTBL_TgsCtk:
	CP_PRN_IdleCek		EQU	$-JTBL_TgsCtk
	SJMP	PRN_IdleCek

	CP_PRN_CekCtkLog	EQU	$-JTBL_TgsCtk
	SJMP	PRN_CekCtkLog

	CP_PRN_CtkLogLagi	EQU	$-JTBL_TgsCtk
	SJMP	PRN_CtkLogLagi

	CP_PRN_CtkKop		EQU	$-JTBL_TgsCtk
	;SJMP	PRN_CtkKop

; tugas baru / baris = 0 -> Cetak Kop
PRN_CtkKop:
	MOV	DPTR,#Str_KopCetak
	MOV	XPL,#LOW  V8_PRN_Buf
	MOV	XPH,#HIGH V8_PRN_Buf
	LCALL	CStrCpy
	LCALL	SwapPtr16

	MOV	A,#'-'
	MOV	R0,#C_PRN_PjgKolomCtk
___GarisKop:
	MOVX	@DPTR,A
	INC	DPL
	DJNZ	R0,___GarisKop

	MOV	A,#C_PRN_JmlBarisKop
	XCH	A,ISTACK+RS_PRN_PosBaris	; = tugas yg digantikan
	MOV	ISTACK+RS_PRN_TugasAktif,A
	MOV	A,#CR
	LJMP	_PRN_IsiByte

PRN_IdleCek:
	MOV	A,ISTACK+RS_PRN_PtrAntri_B
	CJNE	A,ISTACK+RS_PRN_PtrAntri_K,_PRN_JemputAntrian
	JNB	F_LOG_Dicetak,PRN_Tidur		; tdk ada tugas -> tidur

	MOV	ISTACK+RS_PRN_TugasAktif,#CP_PRN_CekCtkLog
	CLR	F_LOG_IzinTimpa
	CLR	F_LOG_TakTerekam

;;_PRN_TugasBaru:
	MOV	A,#CP_PRN_CtkKop
	XCH	A,ISTACK+RS_PRN_TugasAktif	; tugas baru = halaman baru
	MOV	ISTACK+RS_PRN_PosBaris,A

	LCALL	PRN_BacaStatus
	JZ	PRN_CtkKop			; printer siap (=0) ?
	SETB	F_PRN_ButuhAck
	SETB	F_PRN_WDT			; nyatakan gagal
	SJMP	_PRN_SwapReg_Ret

PRN_Tidur:
	CLR	VIE_PRN
	SETB	F_LOG_IzinTimpa
	SJMP	_PRN_SwapReg_Ret		; jika dibangunkan -> tgs = #0


_PRN_JemputAntrian:
	;...DICADANGKAN
	;JNB	F_LOG_Dicetak,$+5
	;CLR	F_LOG_IzinTimpa
	 MOV	ISTACK+RS_PRN_PtrAntri_K,A
	;...
	;SJMP	_PRN_TugasBaru
	SJMP	_PRN_SwapReg_Ret

; sekali diaktifkan, terus mencetak hingga log=kosong
; pemeriksaan pernah/tidaknya 'tdk_terekam' belum dilakukan
PRN_CekCtkLog:
	MOV	A,D_LOG_Buf_B
	CJNE	A,D_LOG_Buf_K,_PRN_CtkLog	; ada isi (B<>K) ?
	JNB	F_LOG_Dicetak,_PRN_CtkLogSelesai
	MOV	A,ISTACK+RS_PRN_PtrAntri_B
	CJNE	A,ISTACK+RS_PRN_PtrAntri_K,_PRN_TugasSelesai
	SJMP	_PRN_SwapReg_Ret

_PRN_CtkLogSelesai:
	SETB	F_LOG_IzinTimpa
_PRN_TugasSelesai:
	MOV	DPTR,#V8_PRN_Buf
	CLR	A
	SJMP	_PRN_GantiTugas

PRN_CtkLogLagi:
	MOV	R3,D_LOG_Buf_B			; = Log_B-
	MOV	R2,ISTACK+RS_PRN_Param0		; = SubEntry _sebelumnya_
	SETB	F0				; arah maju
	LCALL	LOG_CariEntryLagi		; geser ke SubEntry selanjutnya
	MOV	A,R3				; = Log_B+
	CJNE	A,D_LOG_Buf_B,__PCLL		; bergeser (<>) ?
	SJMP	_PRN_StrSumber

__PCLL:	MOV	D_LOG_Buf_B,A
	CJNE	A,D_LOG_Buf_K,_PRN_CtkEntry	; masih berisi (<>) ?
	MOV	ISTACK+RS_PRN_TugasAktif,#CP_PRN_CekCtkLog
	SJMP	_PRN_SwapReg_Ret

_PRN_CtkLog:
	MOV	ISTACK+RS_PRN_TugasAktif,#CP_PRN_CtkLogLagi
	MOV	R3,A				; = D_LOG_Buf_B
	MOV	R2,#0
	SETB	F0				; arah maju
	LCALL	LOG_CekCariEntry		; cek, geser jika salah posisi

_PRN_CtkEntry:
	MOV	DPTR,#V8_PRN_Buf
	LCALL	LOG_StrWaktu
	MOV	ISTACK+RS_PRN_Param1,DPL
_PRN_StrSumber:
	MOV	ISTACK+RS_PRN_Param0,R2
	MOV	DPH,#HIGH V8_PRN_Buf
	MOV	DPL,ISTACK+RS_PRN_Param1
	LCALL	LOG_StrSumberPlus

	MOV	A,#CR
	MOVX	@DPTR,A
	INC	DPL
	INC	ISTACK+RS_PRN_PosBaris		; PosBrs _setelah_ dicetak
	MOV	A,ISTACK+RS_PRN_PosBaris
	CJNE	A,#C_PRN_PjgBaris,_PRN_IsiPtr
	MOV	A,#CP_PRN_CtkKop

_PRN_GantiTugas:
	XCH	A,ISTACK+RS_PRN_TugasAktif	; gantikan tugas
	MOV	ISTACK+RS_PRN_PosBaris,A	; = tugas yg digantikan
	MOV	A,#FF
_PRN_IsiByte:
	MOVX	@DPTR,A
	INC	DPL
_PRN_IsiPtr:
	;CLR	IE_PRN
	MOV	D_PRN_PtrB,#0
	MOV	D_PRN_PtrK,DPL
	;SETB	IE_PRN

	SETB	F_PRN_ButuhAck			; harus direset oleh ISR
	SETB	IRQ_PRN				; = aktifkan ISR
	; WDT direset oleh isr

_PRN_SwapReg_Ret:
	CLR	C
_PRN_SwapReg:
	MOV	RCcS,#C_PRN_JmlRS
	MOV	RCCt,#C_PRN_JmlRT
	MOV	DPTR,#CA_PRN_RNAwal
	LJMP	SwapIStack

; & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & &

PRN_Init:
	SETB	IT_PRN				; penyulut = tebing turun
	;CLR	IP_PRN				; prioritas rendah
	CLR	IRQ_PRN
	SETB	VIE_PRN
	RET

PRN_BacaStatus:
	MOV	DPTR,#HW_PPI_PC
	MOVX	A,@DPTR
	XRL	A,#FM_PRN_Terbalik		; 'gangguan' -> aktif tinggi
	ANL	A,#FM_PRN_status		; = 0Fh
	RET


; & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & & &

EXTRN	CODE	(MMenu_TdkCls_ODP, MgrPopMenu_OSP, LCD_TulisCStr)
EXTRN	CODE	(PT_Reset)
EXTRN	CODE	(LCD_TlsCStrIni)

PrinterGagal:
	CLR	VIE_PRN				; cegah Reentrant
	SETB	C
	LCALL	_PG_SwapReg
	CLR	A
	PUSH	ACC
	JNB	F_LOG_Dicetak,_PG_BatalFF	; gagal mengeluarkan kertas
						;; setelah dinonaktifkan ?
_PG_SebabGagal:
	LCALL	PT_Reset
	MOV	DPTR,#CS_Printer
	LCALL	PS_TimpaSuara
	MOV	D_PRN_WDT,#CT_PG_CekPulih	; = selang antar pemeriksaan
	CLR	F_PRN_WDT

	LCALL	LCD_TlsCStrIni
	DB	FF,'Printer ',EOS
	LCALL	PRN_BacaStatus
	MOV	DPTR,#Str_PG_TakSiap		; selain kertas -> tak siap
	JB	ACC.FP_PRN_Slct,_PG_PsnGagal
	JNB	ACC.FP_PRN_PE,_PG_PsnGagal
	MOV	DPTR,#Str_PG_Kertas
_PG_PsnGagal:
	LCALL	LCD_TulisCStr
_PG_MenuGagal:
	CLR	PSW.1				; = F1
	MOV	DPTR,#MMMU_PrnGagal
	LJMP	MMenu_TdkCls_ODP
MMMU_PrnGagal:
	DB	2, 40H
	;*DB	N_MMu_MenuTmp, 0		; OpsiDef = #0 (Lanjut)
	DB	N_MMu_MenuTmp, N_MMu_OpsiMan	; pertama aktif = #0 (Lanjut)
	DW	_PG_MenuGagal			; Esc
	DW	_PG_SebabGagal			; Redraw
	DW	_PG_CekPulih, _PG_CekPulih	; Info/Idle
	DW	_PG_CekLanjut, _PG_Batal
	DB	'Lanjut',EOS,'Batal',EOS

CT_PG_CekPulih	EQU	2			; satuan detik
EXTRN	NUMBER	(N_MMu_MenuTmp, N_MMu_OpsiMan)
EXTRN	NUMBER	(CS_Printer)
EXTRN	CODE	(PS_TimpaSuara)
EXTRN	BIT	(F_MT_Redraw)

_PG_CekPulih:
	JNB	F_PRN_WDT,__PGCP		; sudah saatnya (=1) ?
	;LCALL	_PG_CekLanjut			; <- hemat kode, tetapi riskan
	LCALL	PRN_BacaStatus
	JZ	_PG_Berlalu			; sudah berlalu (=0) ?
	SETB	F_MT_Redraw			; tandai Redraw
__PGCP:
	LJMP	MgrPopMenu_OSP

_PG_CekLanjut:
	LCALL	PRN_BacaStatus
	JZ	_PG_Berlalu			; sudah berlalu (=0) ?
	RET					; <- kembali ke Redraw

EXTRN	CODE	(TRM_SimpanModusUmum)

_PG_Batal:
	CLR	F_LOG_Dicetak
	LCALL	TRM_SimpanModusUmum
_PG_BatalFF:
	SETB	F_LOG_IzinTimpa
	CLR	F_PRN_ButuhAck
	MOV	D_PRN_PtrB,D_PRN_PtrK
	MOV	DPTR,#CA_PRN_RNAwal
	CLR	A
	MOV	R0,#C_PRN_JmlRN
__PG_RstTugas:
	MOVX	@DPTR,A
	INC	DPTR
	DJNZ	R0,__PG_RstTugas
	SJMP	_PG_Kembali

_PG_Berlalu:
	;DEC	D_PRN_PtrB			; ulangi yang gagal
	SETB	IRQ_PRN				; aktifkan ISR untuk mencetak
	SETB	VIE_PRN				;; (jika ada)
	; WDT direset oleh isr
_PG_Kembali:
	;DEC	SP
	;DEC	SP
	;DEC	SP				; dibuang oleh SwapIStack
	SETB	F_MT_Redraw			; tandai Redraw
	CLR	C
_PG_SwapReg:
	MOV	RCcT,#C_PG_JmlRT
	MOV	RCcS,#0
	LJMP	SwapIStack


SegC_STR	SEGMENT	CODE
	RSEG	SegC_STR

Str_PG_TakSiap:
	DB	'Tidak Siap !',EOS
Str_PG_Kertas:
	DB	'Butuh Kertas !',EOS

	END

