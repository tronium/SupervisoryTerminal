;RUTIN PEMBANGKIT SUARA 'BEEP'
;REV:
; - Tidak ada PUSH/POP (stack), sekaligus hemat sk
; - ACC disimpan-SWAP di PriodeA
; - Sangat mudah dikonversikan untuk penggunaan jenis tabel suara yg berbeda
; - Suara tetap tidak dapat diubah
; - Suara diajukan menggunakan DPTR
  

$INCLUDE(PEWAKTU.DEF)
$INCLUDE(SCH.DEF)
$INCLUDE(STDIO.DEF)


PUBLIC	PembangkitSuara
PUBLIC	F_PS_Aktif, F_PS_SUlang
;PUBLIC	F_PS_SAntri
;PUBLIC	PS_SetSUlang, PS_SuaraBebas
PUBLIC	PS_TimpaAntriSuara1, PS_AntriSuara1, PS_TimpaSuara

SegB_PS			SEGMENT	BIT
			RSEG	SegB_PS

F_PS_Aktif:		DBIT	1
F_PS_SAntri:		DBIT	1
F_PS_SUlang:		DBIT	1

SegD_PS			SEGMENT	DATA
			RSEG	SegD_PS

D_PS_1anDurasi:		DS	1
D_PS_DurasiNada:	DS	1
D_PS_PriodeA:		DS	1
D_PS_PriodeB:		DS	1
D_PS_SemiPriode:	DS	1
D_PS_IndexTbl:		DS	1
D_PS_SAktif_DPL:	DS	1
D_PS_SAktif_DPH:	DS	1
D_PS_SAntri_DPL:	DS	1
D_PS_SAntri_DPH:	DS	1
;D_PS_SUlang_DPL:	DS	1
;D_PS_SUlang_DPH:	DS	1

SegC_PsIsr	SEGMENT	CODE
		RSEG	SegC_PsIsr

PembangkitSuara:
	;JNB	F_PS_Aktif,_ps_qx

;dari sini hingga caller-RET = 60? (yang lama=65) sk max
_PS_CekDurasiNada:
	DJNZ	D_PS_1anDurasi,_PS_CekSemipriode	; jika F_PS_Aktif=0
	MOV	D_PS_1anDurasi,#C_PS_DC1anDurasi	;; PriodeA harus 0
	JNB	F_PS_Aktif,_ps_qx			;; jika <> 0 -> bunyi
	DJNZ	D_PS_DurasiNada,_PS_CekSemipriode
;_PS_JemputCekNada:
	MOV	D_PS_PriodeA,A		; simpan ACC
	XCH	A,DPL
	XCH	A,D_PS_SAktif_DPH		; simpan DPTR (H/L terbalik)
	XCH	A,DPH				;; sekaligus jemput PtrAktif
	XCH	A,D_PS_SAktif_DPL
	XCH	A,DPL
	MOV	A,D_PS_IndexTbl
	MOVC	A,@A+DPTR			; [3n+0]=priode_rendah
	JNZ	_PS_NadaBaru			; habis (priode_rendah=0) ?
;_PS_CekSuara:
	JBC	F_PS_SAntri,_PS_SAntri
	JB	F_PS_SUlang,_PS_SUlang
	CLR	F_PS_Aktif
	INC	D_PS_DurasiNada			; = 1
	;INC	D_PS_1anDurasi			; = 1
	;MOV	D_PS_1anDurasi,D_PS_DurasiNada			; = 1
	;MOV	A,#1
	;MOV	D_PS_DurasiNada,A
	;MOV	D_PS_1anDurasi,A
	;CLR	A
	SJMP	_PS_SwapPtr16			; <- PriodeA = 0
_PS_SUlang:
	;MOV	DPL,D_PS_SUlang_DPL
	;MOV	DPH,D_PS_SUlang_DPH
	MOV	DPTR,#CS_Tetap
	SJMP	_PS_SuaraBaru
_PS_SAntri:
	MOV	DPL,D_PS_SAntri_DPL
	MOV	DPH,D_PS_SAntri_DPH
_PS_SuaraBaru:
	;CLR	A
	MOV	D_PS_IndexTbl,A 		; = 0
	MOVC	A,@A+DPTR			;[0]=priode_rendah
_PS_NadaBaru:
;--- ini untuk penggunaan tabel_suara berpriode=1/F langsung

	MOV	D_PS_PriodeB,PSW
	CLR	C
	RRC	A
	MOV	D_PS_DurasiNada,A		; tempat sementara
	ADDC	A,#0
	XCH	A,D_PS_PriodeB
	MOV	PSW,A

;--- ini untuk penggunaan tabel_suara berpriode= 1/(H+L)
;	MOV	D_PS_PriodeB,A
;	INC	D_PS_IndexTbl			; [3n+1]=priode_tinggi
;	MOV	A,D_PS_IndexTbl
;	MOVC	A,@A+DPTR
;	MOV	D_PS_DurasiNada,A		; tempat sementara

;-- ini berlaku untuk keduanya
	INC	D_PS_IndexTbl			; [3n+2]=durasi_nada
	MOV	A,D_PS_IndexTbl
	MOVC	A,@A+DPTR
	XCH	A,D_PS_DurasiNada		; A <- PriodeA !
	INC	D_PS_IndexTbl			; berikutnya: [3n+3]=3[n+1]
_PS_SwapPtr16:
	XCH	A,DPL
	XCH	A,D_PS_SAktif_DPL		; simpan Ptr16 sekaligus jemput
	XCH	A,DPH				;; DPTR asli (H/L terbalik)
	XCH	A,D_PS_SAktif_DPH
	XCH	A,DPL
	;CLR	P_Spkr				; konsistensi semipriode ?
	SJMP	_PS_CekPriode

_PS_CekSemipriode:
	DJNZ	D_PS_Semipriode,_ps_qx
	XCH	A,D_PS_PriodeA			; <- sekaligus simpan ACC
_PS_CekPriode:
	JZ	_PS_qp				; diam (SemiPriode=0) ?
	XCH	A,D_PS_PriodeB			; <- saling tukar
	MOV	D_PS_SemiPriode,A
	cpl	P_Spkr				; Toggle Speaker
_PS_qp:	XCH	A,D_PS_PriodeA			; <- sekaligus pulihkan ACC
_Ps_qx:	;RET

SegC_PbIsr	SEGMENT	CODE
		RSEG	SegC_PbIsr
		DS	0

;	MOV	D_PS_SemiPriode,A		;simpan ACC
;_PS_CekPriode:
;	MOV	A,D_PS_PriodeA
;	JZ	_PS_qp				;diam (priode_tinggi=0) ?
;	JNB	P_Spkr,_PS_ToggleSpkr		;0-ke-1 atau 1-ke-0 ?
;	MOV	A,D_PS_PriodeB
;_PS_ToggleSpkr:
;	cpl	P_Spkr				;toggle speaker
;_ps_qp:
;	XCH	A,D_PS_SemiPriode		;sekaligus pulihkan ACC
;_Ps_qx:
;	RET

;EXTRN	CODE	(RST_Peringatan)

SegC_PsInit	SEGMENT	CODE
		RSEG	SegC_PsInit

;--------
; LAYANAN
;--------

;PUBLIC	PS_Reset
;PS_Reset:
;	CLR	F_PS_Aktif
;	CLR	F_PS_SAntri
;	CLR	F_PS_SUlang
;	MOV	D_PS_SAktif_DPL,#low  NTBL_SuaraMati
;	MOV	D_PS_SAktif_DPH,#high NTBL_SuaraMati
;	CLR	A
;	MOV	D_PS_IndexTbl,A
;	INC	A
;	MOV	D_PS_1anDurasi,A
;	MOV	D_PS_DurasiNada,A
;	RET
;
;PUBLIC	PS_Init
;PS_Init:
;	LCALL	PS_Reset
;PS_CekHW:
;	CLR	P_Spkr
;	JB	P_Spkr,_psch_gagal
;	SETB	P_Spkr
;	JB	P_Spkr,PS_CekNV
;_psch_gagal:
;	;--LCALL	RST_Peringatan
;	;--DB	'Keluaran Speaker Gagal !',EOS
;PS_CekNV:
;	MOV	A,#CS_Tetap
;
;;-------------------------------------------------------------------------
;; Mengubah suara_ulang tanpa mengubah status keaktifannya
;;-------------------------------------------------------------------------
;PS_SetSUlang:
;	MOV	DPTR,#OTBL_suara
;	SETB	C
;	JBC	F_PS_SUlang,$+3+1		;cegah pengaktifkan
;	CLR	C
;	RL	A
;	MOV	D_PS_SUlang_DPH,A
;	MOVC	A,@A+DPTR			;=DPH
;	XCH	A,D_PS_SUlang_DPH
;	INC	A
;	MOVC	A,@A+DPTR			;=DPL
;	MOV	D_PS_SUlang_DPL,A
;	MOV	F_PS_SUlang,C			;pulihkan status
;	SETB	F_PS_Aktif			;bunyikan jika ada
;	RET

;-----------------------------------------------------------------------------
; Mengaktifkan dan membunyikan suara_ulang dengan menghilangkan antrian lain
;-----------------------------------------------------------------------------
;PS_SUlangTimpaSemua:
;	CLR	F_PS_SAntri

;---------------------------------------------------------------------------
; Mengaktifkankan dan membunyikan suara_ulang (saja)
;---------------------------------------------------------------------------
;PS_SUlangTimpaAktif:
;	CLR	F_PS_Aktif
;	MOV	D_PS_SAktif_DPL,D_PS_SUlang_DPL
;	MOV	D_PS_SAktif_DPH,D_PS_SUlang_DPH
;	SETB	F_PS_SUlang
;	SJMP	_PS_PaksaSuaraBaru

;---------------------------------------------------------------------------
; Mengaktifkan suara_ulang dan menghilangkan antrian lain
;---------------------------------------------------------------------------
;PS_SUlangTimpaAntri:
;	CLR	F_PS_SAntri

;-------------------------------------------------------------------------
; Mengaktifkan suara_ulang
;-------------------------------------------------------------------------
;PS_AntriSUlang:
;	SETB	F_PS_SUlang
;	SETB	F_PS_Aktif
;	RET

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

;-----------------------------------------------------------------------------
; Membunyikan langsung suara_baru (DPTR) dengan menimpa suara yang sedang aktif
; tanpa mengubah antrian
;-----------------------------------------------------------------------------
;PS_SuaraBebas:					; tabel didefenisikan pemakai
;	CLR	F_PS_Aktif
;	MOV	D_PS_SAktif_DPL,DPL
;	MOV	D_PS_SAktif_DPH,DPH
;	SJMP	_PS_PaksaSuaraBaru

;-----------------------------------------------------------------------------
; Membunyikan langsung suara_baru (A) dengan menimpa suara yang sedang aktif
; tanpa mengubah antrian
;-----------------------------------------------------------------------------

EXTRN	CODE	(PT_Reset)

PUBLIC	Eksklamasi

Eksklamasi:
	LCALL	PT_Reset
	MOV	DPTR,#CS_Eksklamasi
PS_TimpaSuara:
	CLR	F_PS_Aktif
	MOV	D_PS_SAktif_DPH,DPH
	MOV	D_PS_SAktif_DPL,DPL
_PS_PaksaSuaraBaru:
	CLR	A
	MOV	D_PS_IndexTbl,A
	INC	A
	MOV	D_PS_1anDurasi,A
	MOV	D_PS_DurasiNada,A
	SETB	F_PS_Aktif
	RET

;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
;!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

;-----------------------------------------------------------------------------
; Membunyikan dengan mendesak (geser ?) antrian suara1 (jika ada). CF = hasil
;-----------------------------------------------------------------------------
;PS_DesakSuara1:
;	JBC	F_PS_SAntri,_ps_desak_s1
;	SETB	C
;	RET
;_ps_desak_s1:
;	CLR	C
;	CLR	F_PS_Aktif
;	MOV	D_PS_SAktif_DPL,D_PS_SAntri_DPL
;	MOV	D_PS_SAktif_DPH,D_PS_SAntri_DPH
;	SJMP	_PS_PaksaSuaraBaru

;PS_DesakSemuaSuara1:
;	JNB	F_PS_SAntri,PS_TimpaSuara	;taksabar...
;PS_DesakAntriSuara1:
;	LCALL	PS_DesakSuara1			;sabar...

;--------------------------------------------------------------------------
; Mendaftarkan suara_baru pada antrian suara1, batal jika penuh. CF = hasil
;--------------------------------------------------------------------------
PS_AntriSuara1:
	CLR	C
	JNB	F_PS_SAntri,_ps_antri_s1
	SETB	C
	RET

;-------------------------------------------------------------------------
; Menimpa antrian suara1 dengan suara_baru
;-------------------------------------------------------------------------
PS_TimpaAntriSuara1:
	CLR	F_PS_SAntri
_ps_antri_s1:
	MOV	D_PS_SAntri_DPL,DPL
	MOV	D_PS_SAntri_DPH,DPH
	SETB	F_PS_SAntri
	SETB	F_PS_Aktif
	RET

;-------------------------------------------------------------------------
; Membunyikan langsung suara_baru dan menghilangkan antrian suara1
;-------------------------------------------------------------------------
;PS_TimpaSemuaSuara1:
;	CLR	F_PS_SAntri
;	SJMP	PS_TimpaSuara

PUBLIC	CS_TrmSiap, CS_Tambah, CS_Kurang, CS_Printer	;CS_Eksklamasi,CS_Tetap

;---------------------------------------------------------------------
;format tabel suara:
;
;[2n+0]	= priode_rendah (0 = habis)
;[2n+1]	= priode_tinggi (0 = diam)
;[2n+2]	= durasi_nada
;
;priode_nada =  F_detak_dasar / F_yang_diinginkan,
;durasi_nada = durasi_yang_dinginkan / satuan_durasi
; n = nomor nada, 0 < n < 256/3
;---------------------------------------------------------------------

; tabel berpriode tunggal
CS_TrmSiap:
	DB	2,10, 3,10, 4,10, 5,10, 6,10, 7,10, 8,10, 9,10, 10,10
	DB	11,10, 10,10, 9,10, 8,10, 7,10, 6,10, 5,10, 4,10, 3,10, 0
CS_Tetap:
	DB	5,100, 10,100, 1,100, 0
CS_Tambah:
	DB	1,2, 11,4, 10,4, 9,4, 8,4, 7,4, 6,4, 5,4, 4,4, 3,4, 2,4, 1,2, 0
CS_Kurang:
	DB	1,2, 2,4, 3,4, 4,4, 5,4, 6,4, 7,4, 8,4, 9,4, 10,4, 11,4, 1,2, 0
CS_Printer:
	DB	10,50, 1,50, 20,50, 1,50, 30,50, 0
CS_Eksklamasi:
	DB	20, 50, 0

	END

;PUBLIC	CS_TrmGagal, CS_Tombol
;CS_TrmGagal:
;	DB	16,100, 8,100, 16,100, 1,100, 0
;CS_Tombol:	; bunyi klik tombol
;	DB	1,2, 2,2, 1,2, 0
;NTBL_SuaraMati:
;	DB	0


; tabel berpriode ganda
NTBL_suara0:
	DB	10,10,200,0
NTBL_suara1:
	DB	5,5,100,10,10,100,'x',0,100,0
NTBL_suara7:
	DB	16,16,100,8,8,100,16,16,100,'x',0,100,0
NTBL_suara2:
	DB	'x',0,2,1,1,2,1,1,2,1,1,2,1,1,2,'x',0,2,0
NTBL_suara3:
	DB	1,1,10,1,2,10,2,2,10,2,3,10,3,3,10,3,4,10,4,4,10,4,5,10,5,5,10
	DB	5,6,10,6,6,10,6,7,10,7,7,10,6,7,10,6,6,10,5,6,10,5,5,10
	DB	4,5,10,4,4,10,3,4,10,3,3,10,2,3,10,2,2,10,1,2,10,1,1,10,0
NTBL_suara4:
	DB	10,10,50,'x',0,50,20,20,50,'x',0,50,30,30,50,0
NTBL_suara5:
	DB	'x',0,2,5,5,4,4,5,4,4,4,4,3,4,4,3,3,4,2,5,4,2,2,4,2,1,4,1,1,4,0
NTBL_suara6:
	DB	'x',0,2,1,1,4,1,2,4,2,2,4,2,3,4,3,3,4,3,4,4,4,4,4,4,5,4,5,5,4,0
	DB	1,1,2,1,2,2,1,3,2,1,4,2
	DB	1,5,2,1,6,2,1,7,2,1,8,2
	DB	2,8,2,3,8,2,4,8,2,5,8,2
	DB	6,8,2,7,8,2,8,8,2,'x',8,2,0
