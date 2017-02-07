;REV:
;DENGAN KLIK GANDA
;04:22am 03-19-1999 Timeout Klik Ganda berlaku 2x -> OnTOut dan OffTOut
;05:15am 03-30-1999 status klik ganda ada buf[lsb], tmb=buf[1..7]
;---------------------------------------------------------
;respon penekanan:
;    Suatu tombol yang ditekan (tombol_lama) akan diabaikan
;    jika ada tombol yang lain ditekan (tombol_baru) dan
;    tetap diabaikan walaupun tombol_baru telah dilepas
;----------------------------------------------------------

C_PT_Ya		EQU	5
PUBLIC	C_PT_Ya

$INCLUDE(SCH.DEF)
$INCLUDE(PEWAKTU.DEF)

PUBLIC	PapanTombol, PT_Reset, PT_AmbilTombol ;PT_Init
;PT_BacaTombol, PT_TungguTombol
PUBLIC	F_PT_AdaTombol, D_PT_TombolBuf;, F_PT_KlikGanda
PUBLIC	IRQ_PT, IE_PT, D_PT_DCCuplik

SegB_PT		SEGMENT	BIT
		RSEG	SegB_PT

IRQ_PT:			DBIT	1
IE_PT:			DBIT	1
F_PT_CekGandaA:		DBIT	1
F_PT_CekGandaB:		DBIT	1
F_PT_AdaTombol:		DBIT	1

;F_PT_KlikGanda:		DBIT	1
F_PT_KlikGanda		BIT	F0

SegD_PT		SEGMENT	DATA
		RSEG	SegD_PT

D_PT_DCCuplik:		DS	1
D_PT_TombolBuf:		DS	1

USING	0
D_PT_TOut		EQU	1
D_PT_CuplikLama		EQU	2	;status mentah
D_PT_StatusLama		EQU	3	;status jadi
D_PT_Terpilih		EQU	4
D_PT_Diproses		EQU	R0	;register temporer

CA_PT_AwalRS	EQU	D_PT_TOut
C_PT_JmlRN	EQU	4

SegV16		SEGMENT	XDATA
		RSEG	SegV16

V_PT_Reg:	DS	C_PT_JmlRN

SegC_PT	SEGMENT	CODE
	RSEG	SegC_PT

;------------
; RUTIN DASAR
;------------
PapanTombol:
;;	DJNZ	D_PT_DCCuplik,__PT_JMP_ke_END
;;	MOV	D_PT_DCCuplik,#C_PT_DCCuplik
;	PUSH	PSW
;	PUSH	ACC
;	MOV	A,D_PT_Diproses
;	PUSH	ACC
;	PUSH	DPL
;	PUSH	DPH

;;EXTRN	CODE	(SwapIXData)
	LCALL	_PT_POPQ
;_PT_cuplik:
	MOV	DPTR,#HW_PT_Dasar OR FM_PT_X0
	MOVX	A,@DPTR
	ORL	A,#00011111b
	SWAP	A				;A.2=0,2; A.1=0,1; A.0=0,0
	MOV	D_PT_Diproses,A
	MOV	DPTR,#HW_PT_Dasar OR FM_PT_X1
	MOVX	A,@DPTR
	ORL	A,#00011111b			;A.7=1,2; A.6=1,1; A.5=1,0
	ANL	A,D_PT_Diproses
	CPL	A				;jadikan aktif-tinggi
	RR	A				;hasil pada BIT 6,5,4;2,1,0

;_PT_debouncing:
	ORL	D_PT_CuplikLama,A		;ditekan = C_baru.OR.C_lama
	XCH	A,D_PT_CuplikLama		;C_baru -> C_lama, A = s_baru

;_PT_CekBaruDitekan:
	XRL	D_PT_StatusLama,A		;berbeda = s_lama.XOR.s_baru
	ANL	D_PT_StatusLama,A		;baru_ditekan = berbeda.AND.s_baru
	XCH	A,D_PT_StatusLama		;s_baru -> s_lama, A = t_baru
	JZ	_PT_CekPengulangan		;#0 = tidak ada baru_ditekan

;_PT_PrioritasTombol:
	XRL	D_PT_StatusLama,A		;jika t_baru > 1, terdaftar...
	ORL	D_PT_CuplikLama,A		;pada pencuplikan berikutnya
	MOV	D_PT_Diproses,A			;simpan tombol_baru
	ANL	A,#0111b*16
	JZ	_PT_prio_nr			;prioritas sesuai nibel
;_PT_prio_nt:
	SWAP	A				;jadikan nibel rendah
	ADD	A,#DTBL_PT_prioritas - $ - 4
	MOVC	A,@A+pc
	SWAP	A				;pulihkan ke nibel tinggi
	SJMP	_PT_KlikKe1
_PT_prio_nr:
	MOV	A,D_PT_Diproses
	ANL	A,#0111b			;indeks_tabel = 3 BIT
	ADD	A,#DTBL_PT_prioritas - $ - 4
	MOVC	A,@A+pc
	SJMP	_PT_KlikKe1

DTBL_PT_prioritas:
	DB	001b	;001, prioritas sesuai posisi BIT
	DB	010b	;010
	DB	010b	;011
	DB	100b	;100
	DB	100b	;101
	DB	100b	;110
	DB	100b	;111

_PT_KlikKe1:
	ORL	D_PT_StatusLama,A		; = tombol_lama
	XCH	A,D_PT_Terpilih
	MOV	D_PT_TOut,#C_PT_DCGanda		; timeout 'On'
	JB	F_PT_CekGandaA,_PT_KlikKe2
	SETB	F_PT_CekGandaA
	SETB	F_PT_CekGandaB
	SJMP	_PT_POPQ
_PT_KlikKe2:
	CJNE	A,D_PT_Terpilih,_PT_KlikTunggal
	XRL	D_PT_Terpilih,A			; =0, selanjutnya diabaikan
	CLR	F_PT_CekGandaA
	;CLR	F_PT_CekGandaB			; tidak berbahaya
	SETB	F_PT_KlikGanda
	;SETB	C
	SJMP	_PT_KodeTombol

_PT_CekPengulangan:
	MOV	A,D_PT_Terpilih
	;JZ	_PT_POPQ
	ANL	A,D_PT_StatusLama		;ingat : s_baru <-> s_lama !
	JNZ	_PT_UlangTombol			;masih = s_baru.AND.tepilih
;_PT_CekKlik1:
	JBC	F_PT_CekGandaB,_PT_TungguKe2
	DJNZ	D_PT_TOut,_PT_POPQ
	JNB	F_PT_CekGandaA,_PT_POPQ
	CLR	F_PT_CekGandaA
	XCH	A,D_PT_Terpilih
	SJMP	_PT_KlikTunggal
_PT_TungguKe2:
	MOV	D_PT_TOut,#C_PT_DCGanda		; timeout 'Off'
	SJMP	_PT_POPQ

_PT_TundaUlang:
	;CLR	F_PT_CekGandaB			; tidak berbahaya
	MOV	D_PT_TOut,#C_PT_DCTunda
	SJMP	_PT_KlikTunggal
_PT_UlangTombol:
	DJNZ	D_PT_TOut,_PT_POPQ
	JBC	F_PT_CekGandaA,_PT_TundaUlang
	MOV	D_PT_TOut,#C_PT_DCUlang
_PT_KlikTunggal:
	;CLR	C
	CLR	F_PT_KlikGanda
_PT_KodeTombol:
;	JB	F_PT_AdaTombol,_PT_POPQ		;batal jika belum diolah
	;MOV	F_PT_KlikGanda,C
	MOV	D_PT_Diproses,A			;simpan sementara
	ANL	A,#0111b*16
	JZ	_PT_Kode_nr
_PT_Kode_nt:
	SWAP	A
	ADD	A,#DTBL_PT_Kode - $ - 4
	MOVC	A,@A+pc
	INC	A				;hasil_Kode=ganjil
	SJMP	_PT_IsiTombolBuf
_PT_Kode_nr:
	MOV	A,D_PT_Diproses			; jemput kembali
	ADD	A,#DTBL_PT_Kode - $ - 4
	MOVC	A,@A+pc
	SJMP	_PT_IsiTombolBuf		;hasil_Kode=genap
DTBL_PT_Kode:
	DB	0	;001
	DB	2	;010
	DB	'?'	;011		;tidak mungkin lebih dari 1 BIT aktif
	DB	4	;100
	; Bawah=0, Atas=1, Kiri=2, Kanan=3, Tidak=4, Ya=5

_PT_IsiTombolBuf:
	MOV	C,F_PT_KlikGanda
	RLC	A
	MOV	D_PT_TombolBuf,A
	SETB	F_PT_AdaTombol		;tandai

;====== layanan modus suara alarm =========
;	JNB	F_KP_SuaraTetap,_PT_POPQ
;	CLR	F_PS_SUlang
;==========================================

_PT_POPQ:
	MOV	A,#C_PT_JmlRN
	MOV	R0,#CA_PT_AwalRS
	MOV	DPTR,#V_PT_Reg
	;LJMP	SwapIXData
;Hanya menguntungkan untuk n >/ 2 (untuk N=2 hemat 2 byte)
;M: R0=@IDATA, DPTR=@XRAM, B=Jml
;SwapIXData:
	;PUSH	B
	MOV	B,A
__SIXD:	MOVX	A,@DPTR
	XCH	A,@R0
	MOVX	@DPTR,A
	INC	R0
	INC	DPTR
	DJNZ	B,__SIXD
	;POP	B
	RET


;	POP	DPH
;	POP	DPL
;	POP	ACC
;	MOV	D_PT_Diproses,A
;	POP	ACC
;	POP	PSW
;	RET

;-------------
; INISIALISASI
;-------------

;PT_Init:
;	;CLR	IE_PT
;	;CLR	F_PT_CekGandaA
;	;CLR	F_PT_CekGandaB
;	;CLR	F_PT_AdaTombol
;	;MOV	D_PT_CuplikLama,#0
;	;MOV	D_PT_StatusLama,#0
;	;MOV	D_PT_Terpilih,#0
;	MOV	D_PT_StatusLama,#0FFH		;Abaikan Semua
;	LCALL	PapanTombol
;	MOV	A,D_PT_CuplikLama
;	MOV	D_PT_DCCuplik,#C_PT_DCCuplik
;	CLR	IRQ_PT
;	SETB	IE_PT
;	JNZ	_pt_gagal_init
;	CLR	C
;	RET
;_pt_gagal_init:
;	SETB	C
;;	LCALL	RST_Peringatan
;;	DB	'Papan Tombol buruk !',EOS
;;	CLR	C
;	RET

;-------
;LAYANAN
;-------
PT_Reset:
	CLR	IE_PT
	LCALL	_PT_POPQ
	MOV	D_PT_Terpilih,#0
;	MOV	D_PT_CuplikLama,#0
	MOV	D_PT_StatusLama,#0FFH
	CLR	F_PT_CekGandaA
	;CLR	F_PT_CekGandaB			; tidak berbahaya
	CLR	F_PT_AdaTombol
	;CLR	IRQ_PT
	LCALL	_PT_POPQ
	SETB	IE_PT
	CLR	A
	RET

;PT_BacaTombol:
;;	cpl	P_Watchdog
;	JB	F_PT_AdaTombol,PT_AmbilTombol
;	CLR	C
;	RET

PT_AmbilTombol:
	CLR	IE_PT
	MOV	A,D_PT_TombolBuf	;jika ada, interupsi tetap aktif ?
	;MOV	C,F_PT_KlikGanda
	CLR	C
	RRC	A
	MOV	F0,C
	MOV	C,F_PT_AdaTombol
	CLR	F_PT_AdaTombol		;tak akan direset kecuali sudah diambil
	;CLR	PSW.1
	SETB	IE_PT
	RET				; A = kode tombol
					; F0 = klik
					; ;PSW.1 = 0
					; C = cek

;PT_TungguTombol:
;	LCALL	PT_BacaTombol
;	JNC	PT_TungguTombol
;	RET

	END

TugasBersama:
_CekIrqPt:
	JBC	IRQ_PT,_CekIePt
_CekIrqRtc:

_CekIePt:
	JBC	IE_PT,_IsrPT
	SETB	IRQ_PT
	SJMP	_IsrPt_Selesai
_IsrPT:	LCALL	PapanTombol
	SETB	IE_PT
_IsrPt_Selesai:
	LJMP	_CekIrqRtc
