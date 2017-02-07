;REV:
; - Sumber dideteksi berdasarkan subentry perubahan (jika 0 -> nonkep)
; - Perubahan buff membuat lihat = muda
; - Baru masuk = muda
; - Ptr entry di R2 dan R3

$INCLUDE(PANTAU.DEF)
$INCLUDE(STDIO.DEF)


EXTRN	DATA	(D_RTC_tgl, D_RTC_bln, D_RTC_thn)
EXTRN	DATA	(D_RTC_jam, D_RTC_mnt, D_RTC_dtk)
EXTRN	BIT	(IE_RTC)
EXTRN	CODE	(DuaPangkatN, JmlBitAktif)
EXTRN	CODE	(SwapPtr16, ChrHariTgl, ChrJam)
EXTRN	CODE	(CStrCpy)
EXTRN	NUMBER	(DTBL_MKS_BitTersisa)
EXTRN	XDATA	(NV8_KP_Alarm)
EXTRN	CODE	(KP_StrNomorNama)

PUBLIC	D_LOG_Buf_K, D_LOG_Buf_B, V_LOG_Buf
PUBLIC	F_LOG_TakTerekam, F_LOG_IzinTimpa
PUBLIC	LOG_BacaBeda, LOG_MajuPtr, LOG_MundurPtr
PUBLIC	LOG_CariEntryLagi, LOG_CekCariEntry
;PUBLIC	LOG_GeserPtr
PUBLIC	LOG_MajuPtrK, LOG_MajuPtrB
PUBLIC	LOG_NonKEP
PUBLIC	LOG_WaktuSekarang
PUBLIC	LOG_StrWaktuPlus, LOG_StrSumber
;PUBLIC	LOG_DPTR:
PUBLIC	LOG_StrWaktu, LOG_StrSumberPlus


SegB_LOG		SEGMENT	BIT
			RSEG	SegB_LOG
;-F_LOG_Dicetak:		DBIT	1	; ada di KEPBIOS
F_LOG_TakTerekam:	DBIT	1
F_LOG_IzinTimpa:	DBIT	1

SegD_LOG		SEGMENT	DATA
			RSEG	SegD_LOG
D_LOG_Buf_B:		DS	1
D_LOG_Buf_K:		DS	1

SegV16_LOG	SEGMENT	XDATA
		RSEG	SegV16_LOG
V_LOG_Buf:	DS	C_LOG_PjgEntry*C_LOG_JmlEntry

SegC_LOG	SEGMENT	CODE
		RSEG	SegC_LOG


;F: Mencari 1 Entry log berikutnya pada arah yang ditentukan F0
;M: F0: 0=tua/turun, 1=muda/naik, R3=PtrEntry(8), R2=PtrSubEntry(3)
;K: R2, R3 , A = Sumber (BIT)
;R: B
LOG_CariEntryLagi:
	LCALL	__LCE_BacaBeda
	JZ	__LCE_GsrByte			; dari non KEP (A=0) ?
__LCE_GsrBit:					; <- geser PtrBit
	MOV	A,R2
	;ANL	A,#7
	JNB	F0,__LCE_CekGsrBit		; Turun (F0=0) ?
	ADD	A,#2
__LCE_CekGsrBit:
	DEC	A
	JNB	ACC.3,__LCE_CekSmbr		; Carry 3-BIT LSB
__LCE_GsrByte:					; <- geser PtrByte
	MOV	A,R3
	LCALL	LOG_GeserPtr
	MOV	R3,A
	CLR	A
	JB	F0,__LCE_CekSmbr		; Naik (F0=1) ?
	MOV	A,#7
__LCE_CekSmbr:
	MOV	R2,A

;F: Mencari 1 Entry log _dimulai_ dari (8H,3L) kearah yang ditentukan F0
;M: F0: 0=tua/turun, 1=muda/naik, R3=PtrEntry(8), R2=PtrSubEntry(3)
;K: R2, R3 , A = Sumber (BIT)
;R: B
LOG_CekCariEntry:
	LCALL	__LCE_BacaBeda
	JZ	__LCE_RET			; 0 -> ada dari non kep
	MOV	B,A
	MOV	A,R2
	LCALL	DuaPangkatN
	ANL	A,B
	JZ	__LCE_GsrBit			; 0 -> tidak ada perubahan
__LCE_RET:
	RET					; A <> 0, Log dari Kep

;F: Mencatat waktu aktif pada LOG
;M: DPTR=@LOG[Waktu]
;R: A, C
;K: DPTR=@LOG[Beda]
LOG_WaktuSekarang:
	SETB	C
	JBC	IE_RTC,__LWS	;lumpuhkan intr. RTC
	CLR	C
__LWS:	MOV	A,D_RTC_jam
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,D_RTC_mnt
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,D_RTC_dtk
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,D_RTC_tgl
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,D_RTC_bln
	MOVX	@DPTR,A
	INC	DPTR
	MOV	A,D_RTC_thn
	MOV	IE_RTC,C		;pulihkan intr. RTC
	MOVX	@DPTR,A
	INC	DPTR
	RET

;F: Mendapatkan StrWaktu dari suatu LogEntry
;M: R3=PtrEntry, DPTR=@XRAM
;K: DPTR=@EOS
;R: A, B, R5=jam, R6=mnt, R7=dtk
LOG_StrWaktuPlus:
	MOV	A,#' '				; diawali spasi !
	MOVX	@DPTR,A
	INC	DPTR
LOG_StrWaktu:
	MOV	A,#OE_LOG_Tgl
	LCALL	LOG_Baca3Byte
	LCALL	ChrHariTgl
	MOV	A,#OE_LOG_Jam
	LCALL	LOG_Baca3Byte
	LCALL	ChrJam
	MOV	A,#EOS
	MOVX	@DPTR,A
	RET

;F: Mendapatkan Str Sumber (bukan waktu) dari suatu LogEntry
;M: R2=(SubEntryKEP), R3=PtrEntry, DPTR=@XRAM
;K: DPTR=@EOS
;R: Semua Reg8
LOG_StrSumberPlus:
	MOV	A,#' '				; diawali spasi !
	MOVX	@DPTR,A
	INC	DPTR
LOG_StrSumber:
	LCALL	_LOG_BacaEntryKEP
	LCALL	SwapPtr16
	CJNE	R5,#0,__LSS_KP			; R5 = Sumber
;__LSS_NonKEP:
	MOV	DPTR,#Str_LSS_NonKEP		; untuk saat ini hanya 1 jenis
	LCALL	CStrCpy				; ...yaitu waktu 'PowerOn'
	LJMP	SwapPtr16			; EOS diberikan oleh CStrCpy

__LSS_KP:
	MOV	A,R2
	LCALL	DuaPangkatN
	XCH	A,R5				; R5 <- PosBit
	;ANL	A,R5
	;JZ	__LSS_NonKEP			; adakah SubEntry dimaksud ?
;__LSS_ChrAlarm:
	MOV	R3,DPH
	MOV	DPH,#HIGH NV8_KP_Alarm		; DPL = NomKEP
	MOVX	A,@DPTR
	ANL	A,R5				; R5 = PosBit
	JZ	__LSS_ChrAktif			; 0 = non alarm
	MOV	A,#2
__LSS_ChrAktif:
	XCH	A,R5
	ANL	A,R3				; R3 = Status
	JNZ	__LSS_ChrHasil			; 0  = tak aktif
	INC	R5
__LSS_ChrHasil:
	MOV	R3,DPL
	MOV	DPTR,#Str_LSS_Judul
	LCALL	CStrCpy			; judul kode
	MOV	A,R5
	ADD	A,#Chr_LSS_Status - $ - 3
	MOVC	A,@A+PC
	LCALL	SwapPtr16
	MOVX	@DPTR,A
	INC	DPTR
	LCALL	SwapPtr16
	LCALL	CStrCpy			; judul NomSimpul
	LCALL	SwapPtr16
	LJMP	KP_StrNomorNama	; R3=8H, R2=3L

Chr_LSS_Status:
	DB	'HmAn'		; Hidup, Mati, Alarm dan Normal
Str_LSS_Judul:
	DB	'K:',EOS,' #S=',EOS
Str_LSS_NonKEP:
	DB	'K:- Terminal Diaktifkan',EOS

;F: Membaca sumber
__LCE_BacaBeda:
	MOV	A,R3
LOG_BacaBeda:
	MOV	DPH,#OE_LOG_Sumber
	LCALL	LOG_DPTR
	MOVX	A,@DPTR				; = BIT-BIT yang berubah
	RET

_LOG_BacaEntryKEP:
	MOV	A,#OE_LOG_Sumber
LOG_Baca3Byte:
	MOV	R6,DPL
	XCH	A,DPH
	MOV	R7,A
	MOV	A,R3
	LCALL	LOG_Dptr
	MOVX	A,@DPTR
	MOV	R5,A
	INC	DPTR
	MOVX	A,@DPTR
	XCH	A,R6
	PUSH	ACC
	INC	DPTR
	MOVX	A,@DPTR
	XCH	A,R7
	MOV	DPH,A
	POP	DPL
	RET

;F: Menuliskan WaktuSekarang dan KodeSumber pada LogBuf
;M: R2->Entry[8], R3->Entry[9]
;R: A, B, DPTR
LOG_NonKEP:
	MOV	A,D_LOG_Buf_K
	MOV	DPH,#0
	LCALL	LOG_DPTR
	LCALL	LOG_WaktuSekarang
	CLR	A
	MOVX	@DPTR,A				; <- sumber: NonKep
	INC	DPTR
	MOV	A,R2
	MOVX	@DPTR,A				; <- Entry[8]
	INC	DPTR
	MOV	A,R3
	MOVX	@DPTR,A				; <- Entry[9]
LOG_MajuPtrK:					; mengeser posisi tulis
	MOV	A,D_LOG_Buf_K
	LCALL	LOG_MajuPtr
	MOV	D_LOG_Buf_K,A
	RET

LOG_MajuPtrB:					; menghapus, setelah dibaca
	MOV	A,D_LOG_Buf_B
	LCALL	LOG_MajuPtr
	MOV	D_LOG_Buf_B,A
	RET


;;M: R3=PtrEntry(8) A=OffsetEntry
;LOG_Ptr16:
;	MOV	DPH,A
;	MOV	A,R3

;F: Mendapatkan Ptr16 dari LOG
;M: A=PtrEntry(8) DPH=OffsetEntry
;K: DPTR=Ptr16
;R: (A=OfsEntry?)
LOG_DPTR:
	XCH	A,B			; (PUSH B)
	MOV	DPL,A
	MOV	A,#C_LOG_PjgEntry
	MUL	AB
	ADD	A,DPH
	JNC	$+2+2
	INC	B

	ADD	A,#LOW V_LOG_Buf
	XCH	A,DPL
	XCH	A,B			; (POP B)
	ADDC	A,#HIGH V_LOG_Buf
	XCH	A,DPH
	;MOVX	A,@DPTR
	RET


;F: Untuk ptr8 bebas
;M: F0: 0=Mundur, 1=Maju
LOG_GeserPtr:
	JNB	F0,LOG_MundurPtr
LOG_MajuPtr:
	INC	A
	CJNE	A,#C_LOG_JmlEntry,_lmjp
	CLR	A
_lmjp:	RET

LOG_MundurPtr:
	DEC	A
	CJNE	A,#0FFH,_lmdp
	MOV	A,#C_LOG_JmlEntry-1
_lmdp:	RET

	END
