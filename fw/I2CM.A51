;REV:
; - Minimalisasi kode
; - layanan PLUS
; CATATAN MCS-51 TIPE CHMOS: AGAK DILARANG MEMBACA STATUS PIN-MASUKAN YANG
; DIPERASIKAN TANPA EXT-PULLUP, SECARA LANGSUNG TANPA MENYEGARKAN STATUS
; PIN-LATCH (1-0-1), karena jika _pernah_ dibuat 0, walaupun telah kembali
; menjadi 1, internal pull-up utama telah tidak aktif (semi-float)
;(22:41pm 04-05-1999)

;--------------------------------
;subrutin induk mengakses bus I2C
;--------------------------------

$INCLUDE(SCH.DEF)

SegC_I2CM	SEGMENT	CODE	INPAGE
		RSEG	SegC_I2CM

; F: Inisialisasi modus_baca/modus_tulis (beralamat)
; M:	A: alamat_hamba, B: alamat_kata
; K:	CY: 0=sukses; 1=gagal(lihat F0)
;	F0: 1=gagal start; 0=gagal kirim byte (NACK)

	PUBLIC	I2CM_TxInitKata

I2CM_TxInitKata:
	CLR	ACC.0			; A=alamat_hamba, modus_tulis
	ACALL	I2CM_TxStart
	JC	__i2cm_tik_qe
	XCH	A,B
	ACALL	I2CM_TxByte		; tulis alamat_kata
	XCH	A,B
__i2cm_tik_qe:
__i2cm_rik_qe:
	RET

; F: Inisialisasi modus_baca_beralamat

	PUBLIC	I2CM_RxInitKata

I2CM_RxInitKata:
	ACALL	I2CM_TxInitKata
	JC	__i2cm_rik_qe
	SETB	I2C_SCL			; = 1 untuk memungkinkan START

; F: Inisialisasi modus_baca_langsung

	;PUBLIC	I2CM_RxInitLangsung

;I2CM_RxInitLangsung:
	SETB	ACC.0			; A=alamat_hamba, modus_baca

;----------------------------------------------------
; F: Mengirim START dan mengirim A (alamat_hamba)

I2CM_TxStart:
	JNB	I2C_SCL,__i2cm_bs_qe	; gagal jika SCL_I=0
	JNB	I2C_SDA,__i2cm_bs_qe	; gagal jika SDA_I=0
	 ; TSetup_ST >/ 4.7 us
	 CLR	I2C_SDA			; START: SCL_O=1, SDA_O <- 1-ke-0
	 ; THold_ST >/ 4 us
	NOP
	CLR	F0			; anggap sukses
	JB	I2C_SCL,_i2cm_TxAlamatHamba; gagal jika (ada yg membuat) SCL=0
	SETB	I2C_SDA
__i2cm_bs_qe:
	SETB	C			; = gagal
	SETB	F0
	RET

_i2cm_TxAlamatHamba:
	 CLR	I2C_SCL

;-----------------------------------------------
; F: Mengirim/tulis byte kepada hamba
; M:	A: byte yang dikirim
; K:	CY: ACK(=0)/NACK(=1) dari hamba_penerima
;-----------------------------------------------

	PUBLIC	I2CM_TxByte

I2CM_TxByte:
	PUSH	ACC
	SETB	C			; penanda cacah pergeseran (8 bit)
	RLC	A			; pertama kali: CY <- MSB, A=xxxx-xxx1
_i2cm_TxBit:				; <- disini SCL harus (sudah) rendah
	 MOV	I2C_SDA,C
	 ; TSetup_DT >/ 250 ns, T_Rise \< 1 us; T_Fall \< 0.3 us
;_i2cm_DetakTx:
	NOP	; perlu (TSetup_DT) ?
	 SETB	I2C_SCL
	 ; TH_SCL >/ 4 us, T_Rise \< 1 us
	SJMP	$+2
	CLR	C
	RLC	A			; terakhir kali: CY <- 1, A=0000-0000
	 CLR	I2C_SCL
	 ; TL_SCL >/ 4.7 us, T_Fall \< 0.3 us
	JNZ	_i2cm_TxBit
;_i2cm_ack_srx:
	SETB	I2C_SDA			; buat SDA=1 untuk menerima ACK/NACK
	NOP
	 SETB	I2C_SCL
	NOP
	POP	ACC
	 MOV	C,I2C_SDA	; CY <- status ACK(0)/NACK(1) dari S-RX
	 CLR	I2C_SCL		; SCL <- 0 (Bus masih dikuasai; SDA=1)
	RET

; M:	A: byte terakhir yang dikirim/tulis
; K:	CY: 0=sukses; 1=gagal(lihat F0)
;	F0: 1=gagal stop; 0=gagal kirim byte(NACK)

	PUBLIC	I2CM_TxByteAkhir

I2CM_TxByteAkhir:
	CLR	F0			; jika gagal -> F0=0
	ACALL	I2CM_TxByte
	JC	__i2cm_tba_qe

_i2cm_BitStop:
	SETB	F0			; jika gagal -> F0=1
	CLR	I2C_SDA			; SDA <- 0
	 SETB	I2C_SCL		; SCL <- 1
	 ; TSetup_SP >/ 4 us, T_Rise \< 1 us
	SETB	C			; anggap gagal
	JNB	I2C_SCL,__i2cm_bp_x	; gagal jika SCL=0
	CLR	C
	 SETB	I2C_SDA		; STOP: SCL=1, SDA <- transisi 0-ke-1
	;NOP
	;	ORL	C,/I2C_SDA	; gagal (=1) jika SDA=0
					; ret: SCL=SDA=1
__i2cm_tba_qe:
	RET

;-------------------------------
	PUBLIC	I2CM_TxStop

I2CM_TxStop:
	 CLR	I2C_SCL			; SCL_O <- 0
	SJMP	_i2cm_BitStop

;-------------------------------

	PUBLIC	I2CM_RxByteAkhir

I2CM_RxByteAkhir:
	SETB	F0				; = NACK
	SJMP	_i2cm_RxByte

	PUBLIC	I2CM_RxByte

I2CM_RxByte:
	CLR	F0				; = ACK

;-----------------------------------------------
; F: Menerima/baca byte dari hamba
; M:	F0: 0=berlanjut/ACK, 1=NACK+STOP
; K:	A: byte yang diterima
;	CY: 0=sukses; 1=gagal buat stop (F0=1)
;-----------------------------------------------

_i2cm_RxByte:
	MOV	A,#1			; ACC.0 penanda bit ke-8
_i2cm_DetakRx:				; <- disini SCL_O=0, SDA_O=1
	 SETB	I2C_SCL
	 ; TH_SCL >/ 4 us, T_Rise \< 1 us
;_i2cm_RxBit:
	 MOV	C,I2C_SDA
	RLC	A			; msb yang pertama !
	JC	_i2cm_ack_mtx		; sudah 8 bit (CY=1) ?
	 CLR	I2C_SCL
	 ; TL_SCL >/ 4.7 us, T_Fall \< 0.3 us
	SJMP	$+2
	SJMP	_i2cm_DetakRx
_i2cm_ack_mtx:
	 CLR	I2C_SCL
	ANL	C,F0
	 MOV	I2C_SDA,C		; CY = ACK(0)/NACK(1) dari M-TX
	 ; TSetup_DT >/ 250 ns
	NOP	; perlu (TSetup_DT) ?
	 SETB	I2C_SCL
	SJMP	$+2
;_i2cm_rb_q:
	JC	I2CM_TxStop		; CY=1 : byte terakhir yang dibaca
	 CLR	I2C_SCL			; SCL_O <- 0 (Bus masih dikuasai)
__i2cm_bp_x:
	SETB	I2C_SDA			; buat SDA_O=1 agar bisa menerima
	RET

	END
