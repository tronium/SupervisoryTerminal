;03:17am 04-07-1999 Pengefisiensian Pemanggilan MUbahkfgKEP
;00:50am 08-03-1999 Pemulihan bunyi STetap bergantung pada konfig
$INCLUDE(PANTAU.DEF)
$INCLUDE(STDIO.DEF)
$INCLUDE(OS.DEF)

C_MKS_ChrOffset	EQU	7EH	; Pada LCD = '->' (panah kanan)

EXTRN	CODE	(LCD_Cls, LCD_SetXY, LCD_TulisXStr, LCD_TlsXYXStr)
EXTRN	CODE	(LCD_KursorGaris, LCD_KdpXYCStr, LCD_KedipXStr)
EXTRN	CODE	(LCD_TlsNCObj, LCD_TlsNCXObj)
EXTRN	CODE	(JmlBitAktif, StrDes4D, DuaPangkatN, SwapPtr16, SwapIStack)
EXTRN	CODE	(MgrTugas_OSP, XStrTambahChr, __VADD_DPTR_A)
EXTRN	CODE	(KP_StrNomorNama, KP_UbahDigit)
EXTRN	XDATA	(NV8_KP_Baca, NV8_KP_Alarm, V8_KP_Status, V8_KP_Keaktifan)
EXTRN	BIT	(F_LCD_FlipKedip, F_LCD_PosKedip, F_PS_SUlang, F_PS_Aktif)
EXTRN	BIT	(F_KP_AdaBerubah, F_KP_Alarm)	;, F_KP_NotasiDes)
;EXTRN	DATA	(D_LCD_FlipKedip)

PUBLIC	MKepSNyata, MKepSKeaktifan
PUBLIC	DTBL_MKS_BitTersisa

ISTACK			SEGMENT	DATA
			RSEG	ISTACK
RS_MKS_Dasar_3L		EQU	0		; RS = reg semu
RS_MKS_Dasar_8H		EQU	1
RS_MKS_Offset		EQU	2		; = RS_MKK_Opsi
RT_MKS_Digit		EQU	3
RT_MKS_SegSumber	EQU	4
RT_MKS_Alarm_3L		EQU	5
RT_MKS_Alarm_8H		EQU	6

;RT_MKS_PUSHOffset	EQU	RT_MKS_Alarm_3L	; temporer

C_MKS_JmlRT		EQU	4
C_MKS_JmlRS		EQU	3

SegV16			SEGMENT	XDATA
			RSEG	SegV16

RN_MKS:			DS	C_MKS_JmlRS	; RN = reg nyata
CA_MKS_RNAwal		EQU	RN_MKS

C_MKS_PjgIsiStatus	EQU	25		; tanpa chr offset

SegV_Umum		SEGMENT	XDATA
			RSEG	SegV_Umum
;Pointer SegV_Umum
PU_MKS_IsiNomSimpul	EQU	$
PU_MKS_IsiStatus	EQU	PU_MKS_IsiNomSimpul+5+C_KP_PjgNama+1
PU_MKS_IsiJmlAlarm	EQU	PU_MKS_IsiStatus+C_MKS_PjgIsiStatus+1+1
PU_MKS_IsiJmlHidup	EQU	PU_MKS_IsiJmlAlarm+4+1
PU_MKS_IsiAdaAlarm	EQU	PU_MKS_IsiJmlHidup+4+1

V_BufUmum1:	DS	256
V_BufUmum2:	DS	256

;PUBLIC	V_BufUmum1, V_BufUmum2


SegC_MKStatus		SEGMENT	CODE
			RSEG	SegC_MKStatus

XY_MKS_JdlNomSimpul	EQU	0
XY_MKS_IsiNomSimpul	EQU	XY_MKS_JdlNomSimpul+3
XY_MKS_IsiStatus	EQU	40H
XY_MKS_JdlJmlAlarm	EQU	40H+27
XY_MKS_IsiJmlAlarm	EQU	XY_MKS_JdlJmlAlarm+2
XY_MKS_JdlJmlHidup	EQU	40H+34
XY_MKS_IsiJmlHidup	EQU	XY_MKS_JdlJmlHidup+2

C_MKS_JmlObjJdl		EQU	3
XYS_MKS_Judul:
	DB	XY_MKS_JdlNomSimpul,'#S:',EOS
	DB	XY_MKS_JdlJmlAlarm,'A=',EOS
	DB	XY_MKS_JdlJmlHidup,'H=',EOS

C_MKS_JmlObjIsi		EQU	3
XYS_MKS_Isi:
	DB	XY_MKS_IsiStatus,EOS
	DB	XY_MKS_IsiJmlAlarm,EOS
	DB	XY_MKS_IsiJmlHidup,EOS

XY_MKSN_AdaAlarm	EQU	22
Str_MKS_AdaAlarm:
	DB	'#A:',EOS

C_PosLSD	EQU	3

MKepSNyata:
	SETB	C
	LCALL	_MKS_SwapReg
	MOV	ISTACK+RT_MKS_SegSumber,#HIGH V8_KP_Status
	SJMP	MKP_Status
MKepSKeaktifan:
	SETB	C
	LCALL	_MKS_SwapReg
	MOV	ISTACK+RT_MKS_SegSumber,#HIGH V8_KP_Keaktifan
MKP_Status:
	MOV	ISTACK+RT_MKS_Digit,#C_PosLSD
	;MOV	ISTACK+RT_MKK_Sifat,#10	; = sifat 'baca'
;--
	;CPL	F_KP_NotasiDes
;--
_MKS_Redraw:
	LCALL	LCD_Cls
	MOV	R0,#C_MKS_JmlObjJdl
	MOV	DPTR,#XYS_MKS_Judul
	LCALL	LCD_TlsNCObj			; Cetak judul. Digabung saja ?
	LCALL	LCD_KursorGaris
	SETB	F_LCD_FlipKedip			; supaya CekAlarm tak ditunda
	CLR	F_LCD_PosKedip
	LCALL	MKS_NomSimpul
_MKS_CtkNomNam:
	MOV	DPTR,#PU_MKS_IsiNomSimpul
	LCALL	KP_StrNomorNama		; <- S = 9 (maks)
	MOV	A,#XY_MKS_IsiNomSimpul
	MOV	DPTR,#PU_MKS_IsiNomSimpul
	LCALL	LCD_TlsXYXStr			; <- S: 6

_MKS_UpdateStatus:
	;LCALL	_MKS_CtkStatus
	;_MKS_CtkStatus:				; tot stack = 14 (maks)
	;;CLR	F_KP_AdaBerubah
	MOV	R0,#C_MKS_PjgIsiStatus
	MOV	R2,ISTACK+RS_MKS_Dasar_3L
	MOV	R3,ISTACK+RS_MKS_Dasar_8H
	MOV	R7,ISTACK+RT_MKS_SegSumber
	MOV	DPTR,#PU_MKS_IsiStatus
	LCALL	MKS_StrStatusNBit		; <- stack: 4
	MOV	A,ISTACK+RS_MKS_Offset
	MOV	DPTR,#PU_MKS_IsiStatus
	LCALL	__VADD_DPTR_A			; RET: DPTR <- DPTR+offset
	MOV	R0,#C_MKS_ChrOffset
	LCALL	XStrTambahChr
	MOV	R1,ISTACK+RT_MKS_SegSumber
	MOV	R6,#LOW PU_MKS_IsiJmlAlarm
	MOV	R7,#HIGH PU_MKS_IsiJmlAlarm
	LCALL	MKS_StrJmlAktif			; <- stack: 12
	MOV	R6,#LOW PU_MKS_IsiStatus
	MOV	R7,#HIGH PU_MKS_IsiStatus
	MOV	DPTR,#XYS_MKS_Isi
	MOV	R0,#C_MKS_JmlObjIsi
	LCALL	LCD_TlsNCXObj			; <- stack: 9 (ada cr = 11)
	;MOV	A,ISTACK+RT_MKS_SegSumber
	;CJNE	A,#HIGH V8_KP_Keaktifan,_MKS_PosKsr
	;;NOP	;totalarm
	;;
	SJMP	_MKS_PosKsr

_MKS_MatikanBunyi:
	CLR	F_PS_SUlang			; matikan bunyi
_MKS_Idle:
;_MKS_CekUpdate:
	JBC	F_KP_AdaBerubah,_MKS_UpdateStatus
;_MKS_CekKdp:
	MOV	A,ISTACK+RT_MKS_SegSumber
	CJNE	A,#HIGH V8_KP_Status,_MKS_MT
	JNB	F_LCD_FlipKedip,_MKS_MT
	JB	F_LCD_PosKedip,_MKSN_CtkAlarm	; = hapus
MKSN_CekAlarm:					; bergantian tampil perkedip
	;JNB	F_KP_Alarm,_MSKN_AlarmTdkAda
	JNB	F_KP_Alarm,_MKS_MT
	MOV	A,ISTACK+RT_MKS_Alarm_3L	; BUG: Pertama jalan -> acak
	MOV	DPL,ISTACK+RT_MKS_Alarm_8H
	MOV	R6,#0				; jenis = alarm
	MOV	R7,#HIGH V8_KP_Status		; sumber = nyata
	SETB	C				; arah = naik
	LCALL	MKS_CariAktif
	MOV	A,DPL
	MOV	ISTACK+RT_MKS_Alarm_8H,A	; 8H berikutnya
	JC	_MKSN_DapatAlarm
	MOV	ISTACK+RT_MKS_Alarm_3L,#7	; tak ada sisa: 8H=8H+1, BIT 0
_MSKN_AlarmTdkAda:
;	MOV	D_LCD_FlipKedip,#2		; Tunda pencarian...
;	CLR	F_LCD_FlipKedip			; selama 1..2x Tcuplik PT
	SJMP	_MKS_MT
_MKSN_DapatAlarm:
	MOV	R3,A
	MOV	ISTACK+RT_MKS_Alarm_3L,R2	; berikutnya -> 3L+1
	MOV	DPTR,#PU_MKS_IsiAdaAlarm
	LCALL	KP_StrNomorNama		; <- A=8H, R2=3L, S: 12
_MKSN_CtkAlarm:
	MOV	DPTR,#Str_MKS_AdaAlarm
	MOV	A,#XY_MKSN_AdaAlarm
	LCALL	LCD_KdpXYCStr
	MOV	DPTR,#PU_MKS_IsiAdaAlarm
	LCALL	LCD_KedipXStr
_MKS_PosKsr:
	MOV	A,ISTACK+RT_MKS_Digit
	ADD	A,#XY_MKS_IsiNomSimpul
	LCALL	LCD_SetXY
_MKS_MT:
	LCALL	MgrTugas_OSP
	AJMP	_MKS_Redraw
	SJMP	_MKS_Idle
	SJMP	_MKS_TArah
	SJMP	_MKS_TTidak
;	SJMP	_MKS_TYa
;_MKS_TYa:
	JNB	F0,_MKS_UbahKfg
_MKS_T2Ya:
	MOV	A,ISTACK+RT_MKS_SegSumber
	CJNE	A,#HIGH V8_KP_Keaktifan,_MKS_MatikanBunyi
	MOV	DPH,A
	CLR	A
	MOV	DPL,A
_MKS_RstKeaktifan:
	MOVX	@DPTR,A
	DJNZ	DPL,_MKS_RstKeaktifan
	AJMP	_MKS_UpdateStatus

_MKS_UbahKfg:
	LCALL	MKS_NomSimpul
	LCALL	_MKS_RegUbahKfg
	AJMP	_MKS_Redraw

_MKS_RegUbahKfg:
	SETB	C
	LCALL	_MLKP_SwapReg
	MOV	ISTACK+RS_MKS_Dasar_3L,R2
	MOV	ISTACK+RS_MKS_Dasar_8H,R3
	LCALL	MubahKfgKEP
	LJMP	_MLKP_SwapReg_Ret

EXTRN	CODE	(MubahKfgKEP,_MLKP_SwapReg, _MLKP_SwapReg_Ret)

_MKS_TTidak:

EXTRN	CODE	(KPFx_CekSTetap)
	LCALL	KPFx_CekSTetap		; pastikan bunyi jika masih ada alarm

_MKS_SwapReg_Ret:
	CLR	C

_MKS_SwapReg:
	MOV	RCcS,#C_MKS_JmlRS
	MOV	RCcT,#C_MKS_JmlRT
	MOV	DPTR,#CA_MKS_RNAwal
	LJMP	SwapIStack			; ...dan keluar

_MKS_TArah:
	LCALL	MKS_NomSimpul
	MOV	A,ISTACK+RT_MKS_Digit
	LCALL	KP_UbahDigit
	JB	F0,_MKS_NomBaru
	MOV	ISTACK+RT_MKS_Digit,A
	SJMP	_MKS_PosKsr
_MKS_NomBaru:
	LCALL	MKS_GeserOffset
;_MKS_DasarStatus:
	LJMP	_MKS_CtkNomNam

C_PT_TBwh	EQU	1
;F: Menyesuaikan offset terhadap pergeseran
;M: R0=tombol atas/bawah, R2=3L+, R3=8H+
;K: C:1=masih dalam range
;R: R4
;S: 2
MKS_GeserOffset:
	MOV	A,R2
	CLR	C
	SUBB	A,ISTACK+RS_MKS_Dasar_3L
	ANL	A,#7
	MOV	R4,A
	MOV	A,R3
	SUBB	A,ISTACK+RS_MKS_Dasar_8H
	CJNE	A,#20H,$+3			; Periksa status 3/12-BIT MSB
	JNC	__MGO4				; Ada yg aktif (C=0) -> diluar
	ANL	A,#1FH
	SWAP	A
	RR	A
	ORL	A,R4				; A <- offset maju 8-BIT
	CJNE	A,#C_MKS_PjgIsiStatus,$+3
	JC	__MGO3				; didalam range (C=1) ?
__MGO1:	MOV	A,#(-(C_MKS_PjgIsiStatus-1)) OR 0F8H	; agar carry di C
	ADD	A,R2
	ANL	A,#7
	MOV	ISTACK+RS_MKS_Dasar_3L,A
	MOV	A,#LOW ((-(C_MKS_PjgIsiStatus-1))/8)
	ADDC	A,R3
	MOV	ISTACK+RS_MKS_Dasar_8H,A
	MOV	A,#C_MKS_PjgIsiStatus-1		; = ujung
__MGO2:	CLR	C
__MGO3:	MOV	ISTACK+RS_MKS_Offset,A	; = offset maju
	RET
__MGO4:	CJNE	R0,#C_PT_TBwh,__MGO1		; Tmbl <> C_PT_TBwh -> ujung
	MOV	ISTACK+RS_MKS_Dasar_3L,R2
	MOV	ISTACK+RS_MKS_Dasar_8H,R3
	CLR	A				; = awal
	SJMP	__MGO2

MKS_NomSimpul:
;K: R2=3L, A=R3=8H
	MOV	A,ISTACK+RS_MKS_Dasar_3L
	;ANL	A,#7
	ADD	A,ISTACK+RS_MKS_Offset
	MOV	R2,A
	ANL	A,#7
	XCH	A,R2
	RRC	A				; offset = 0..255
	RR	A				; = 3x RR A
	RR	A
	ANL	A,#3FH				; = 6 BIT dengan carry
	ADD	A,ISTACK+RS_MKS_Dasar_8H
	MOV	R3,A				; A=R2=8H
	RET

;F: Mendapatkan Str Status sejumlah (R0) Simpul
;M: R2=No BIT Awal, R3=No Kartu Awal, R7=SegSumber, R0=JmlChr, DPTR=@XRam
;K: Disesuaikan: R2=PosBit, R3, R4, R5, R6 dan DPTR
;R: A, R0=0, R1
MKS_StrStatusNBit:				; tot stack = 4
	MOV	A,R2
	LCALL	DuaPangkatN
	MOV	R2,A
	SJMP	_MKS_BacaStatus
MKS_StrStatusNBitLagi:
_MKS_BitBerikutnya:
	MOV	A,R2
	ADD	A,R2
	MOV	R2,A
	JNC	_MKS_ChrStt1Bit			; = 0 juga
_MKS_KartuBerikutnya:
	INC	R2				; = BIT lsb
	INC	R3				; nom kartu berikutnya
_MKS_BacaStatus:
	PUSH	DPL
	PUSH	DPH
	MOV	DPL,R3				; nom kartu
	MOV	DPH,R7				; seg sumber
	MOVX	A,@DPTR				; hasil polling, bukan langsung
	MOV	R4,A				; R4 = status
	MOV	DPH,#HIGH NV8_KP_Alarm
	MOVX	A,@DPTR
	MOV	R5,A				; R5 = modus alarm
	MOV	DPH,#HIGH NV8_KP_Baca
	MOVX	A,@DPTR
	MOV	R6,A				; R6 = modus baca
	POP	DPH
	POP	DPL
_MKS_ChrStt1Bit:
	MOV	A,R2
	ANL	A,R6
	JNZ	_MKS_ChrStatus			; 0 = tak dibaca
	MOV	A,#C_MKS_ChrAbai
	SJMP	_MKS_SimpanChr
_MKS_ChrStatus:
	MOV	R1,#__almt1 - __almt0
	ANL	A,R4
	JNZ	_MKS_ChrAlarm			; 0 = tak aktif
	MOV	A,R2
	INC	R1
_MKS_ChrAlarm:
	ANL	A,R5
	JZ	_MKS_ChrHasil			; 0 = non alarm
	INC	R1
	INC	R1
_MKS_ChrHasil:
	MOV	A,R1
	MOVC	A,@A+PC
__almt0	SET	$
_MKS_SimpanChr:
	MOVX	@DPTR,A
	INC	DPTR
	DJNZ	R0,_MKS_BitBerikutnya
	MOV	A,#EOS
	MOVX	@DPTR,A
	RET
__almt1	SET	$
	DB	'HmAn'		; Hidup, Mati, Alarm dan Normal
C_MKS_ChrAbai	EQU	'*'

;F: Mendapatkan Str Jumlah Alarm dan NonAlarm yang sedang/pernah aktif
;M: R1=Seg Sumber, (R6,R7)=@XRam
;R: R0=4, R2, R3, R4, R5
;K: DPTR=@EOS
;I: JmlBitAktif, StrDes4D
MKS_StrJmlAktif:
	CLR	A
	MOV	R2,A
	MOV	R3,A
	MOV	R4,A
	MOV	R5,A
	MOV	DPL,A
_MKS_HitungJml:
	MOV	DPH,R1				; = seg sumber
	MOVX	A,@DPTR
	MOV	R0,A
	MOV	DPH,#HIGH NV8_KP_Alarm
	MOVX	A,@DPTR
	ANL	A,R0
	LCALL	JmlBitAktif			; <- stack: 3
	ADD	A,R2
	MOV	R2,A				; Alarm_L
	JNC	$+2+1
	INC	R3				; Alarm_H
	MOVX	A,@DPTR
	CPL	A				; Hidup = Non Alarm
	ANL	A,R0
	LCALL	JmlBitAktif
	ADD	A,R4				; Hidup_L
	MOV	R4,A
	JNC	___MHJ
	INC	R5				; Hidup_H
___MHJ:	DJNZ	DPL,_MKS_HitungJml
	MOV	DPL,R6
	MOV	DPH,R7
	LCALL	StrDes4D			; Ttl Alarm
	INC	DPTR				; @EOS+1
	MOV	A,R4
	MOV	R2,A
	MOV	A,R5
	MOV	R3,A
	LJMP	StrDes4D			; Ttl NonAlarm (Hidup)

;F: Mencari Alarm/NonAlarm yang sedang/pernah aktif (pada 256 kartu + sisa BIT)
;M: C=Arah(1=naik) A=3L (sebelumnya), DPL=8H
;   R6=Komplemen yang dicari {Alarm(0H)/NonAlarm(0FFH)}, R7=SegSumber
;K: C=Dapat(1)/Takdapat(0), DPL=8H, jika dapat: R2=3L
;R: F0, A, R0, (DPH, R2 jika tidak ada)
;S: 2+2
MKS_CariAktif:
	MOV	F0,C
	ADDC	A,#DTBL_MKS_BitTersisa - $ - 3 - 1
	MOVC	A,@A+PC
	JB	F0,_MKS_CekSisa
	CPL	A
_MKS_CekSisa:
	;JZ	_MKS_CariByte0
	MOV	R2,A				; = sisa BIT untuk dilanjutkan
	MOV	DPH,R7
	MOVX	A,@DPTR
	ANL	A,R2
	MOV	R0,#1				; 1 kartu sisa
	LCALL	_MKS_CariByte4
	JC	_MKS_CBA_RET
;_MKS_CariByte0:
	MOV	R0,#0				; limit=256 kep
_MKS_CariByte1:
	JNB	F0,_MKS_CariByte2
	DEC	DPL
	SJMP	_MKS_CariByte3
	DB	11111111B
DTBL_MKS_BitTersisa:
	DB	11111110B			; = sisa BIT arah naik
	DB	11111100B
	DB	11111000B
	DB	11110000B
	DB	11100000B
	DB	11000000B
	DB	10000000B
	DB	0
_MKS_CariByte2:
	INC	DPL				; 8H+1, BIT 0
_MKS_CariByte3:
	MOV	DPH,R7				; seg sumber
	MOVX	A,@DPTR
_MKS_CariByte4:
	MOV	R2,A
	MOV	DPH,#HIGH NV8_KP_Alarm
	MOVX	A,@DPTR
	XRL	A,R6				; tipe yang dicari
	ANL	A,R2
	JNZ	_MKS_DapatByte
	DJNZ	R0,_MKS_CariByte1
	CLR	C
	RET
_MKS_DapatByte:
	CLR	C			; BUG: infinitif loop jika MCS rusak
	JNB	F0,_MKS_CariBitMsb1
	MOV	R2,#0FFH
_MKS_CariBitLsb:
	INC	R2			; = 3L
	RRC	A			; prioritas : lsb
	JNC	_MKS_CariBitLsb
	RET
_MKS_CariBitMsb1:
	MOV	R2,#8H
_MKS_CariBitMsb2:
	DEC	R2			; = 3L
	RLC	A			; prioritas : msb
	JNC	_MKS_CariBitMsb2
_MKS_CBA_RET:
	RET

	END

;////////////////////////////////////////////////////////////////////
;ENDEND
CONTOH TAMPILAN:
	DB	'#S=2045 TakBernama    #A:2345 ABCDEFGHIJ'
	DB	'0AN01*10NA-0123456789-012  A=0000 H=0000'
	DB	'0123-------0123456789-123
		'_123456789_123456789_123456789_123456789'

'#S:2045 TakBernama    #A:2345 ABCDEFGHIJ'
'0AN01*10NA-0123456789-0124 A=0000 H=0000'
'0123-------0123456789-123'
'12-0123456789-0123456789-'
'-0123456789-0123456789-01'
'#S=2045 TakBernama       Total A > 65535'

	DB	'No: 2045 (TakBernama)      A=0000 M=0000'
	DB	'0AN01*10NA-0123456789 #A:2345 ABCDEFGHIJ'

	DB	'[#2045-#1089] #=TakBernama A=0000 H=0000'
	DB	'01234567-01234567-012 #A:2345 ABCDEFGHIJ'
	DB	'0AN01*10NA 0:1234 A:2345=1234 TakBernama'
	DB	'23456789-0123456789-0'
	DB	'7-01234567-01234567-0 #A:2345 ABCDEFGHIJ'
	DB	'#=1234 ABCDEFGHIJ ['
	DB	'Dasar: 12-23-23 00:00:00 A=2345 1=2334'

	DB	'_123456789_123456789_123456789_123456789'
	DB	'MEM a9-332,35 #139 (Coba 13) : A'

