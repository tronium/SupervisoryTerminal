;REV: Menggunakan HW 8-BIT-tinggi
;15:23pm 03-30-1999 Pakai XYZ dan HapusChr

$INCLUDE(SCH.DEF)
$INCLUDE(STDIO.DEF)

	PUBLIC	XYZ
XYZ	EQU	0FFH			; kursor: bertahan di XY yg sama


		XSEG	AT HW_LCD_Dasar
HW_LCD_TulisIR:	DS	256		; DPH=*00b, DPL diabaikan
HW_LCD_BacaIR:	DS	256		; *01b
HW_LCD_TulisDR:	DS	256		; *10b
HW_LCD_BacaDR:	DS	256		; *11b


SegC_LCD	SEGMENT	CODE	INBLOCK
		RSEG	SegC_LCD

	PUBLIC	LCD_Cls
LCD_Cls:
	MOV	A,#1			; cls+home
	ACALL	_LCD_TulisIR

	;PUBLIC	LCD_KursorOff
;LCD_KursorOff:
	MOV	A,#1100b
	SJMP	_LCD_TulisIR

	PUBLIC	LCD_KursorBlok
LCD_KursorBlok:
	MOV	A,#1101b		; blok berkedip saja
	SJMP	_LCD_TulisIR

	PUBLIC	LCD_KursorGaris
LCD_KursorGaris:
	MOV	A,#1110b		; garis_bawah saja
	SJMP	_LCD_TulisIR

;LCD_KsrBlokGaris:
;	MOV	A,#1111b		; garis_bawah dan blok kedip
;	SJMP	_LCD_TulisIR

	PUBLIC	LCD_GsrKsrKanan
LCD_GsrKsrKanan:			; tidak memperhatikan ukuran LCD
	MOV	A,#10100b
	SJMP	_LCD_TulisIR

;LCD_GsrKsrKiri:			; tidak memperhatikan ukuran LCD
;	MOV	A,#10000b
;	SJMP	_LCD_TulisIR

	PUBLIC	LCD_SetXY
LCD_SetXY:
	CJNE	A,#XYZ,LCD_SetADDRam
	RET

;LCD_SetACGRam:
;	SETB	ACC.6
;	CLR	ACC.7
;	SJMP	_LCD_TulisIR

	PUBLIC	LCD_TulisChr
LCD_TulisChr:
	CJNE	A,#FF,__ltc_CekEOL	; FormFeed -> ClearScreen
	SJMP	LCD_Cls
__ltc_CekEOL:
	CJNE	A,#CR,_LCD_TulisDR
	;SJMP	_LCD_BarisBaru

	;PUBLIC	_LCD_BarisBaru
_LCD_BarisBaru:
	PUSH	DPH
	MOV	DPH,#HIGH HW_LCD_BacaIR	; = *01b
	MOVX	A,@DPTR
	POP	DPH

;bagian ini hanya berlaku untuk LCD dengan 2 baris
	ANL	A,#01000000b
	CPL	ACC.6			; kolom 0, baris berikutnya
	;SJMP	LCD_SetADDRam

	;PUBLIC	LCD_SetADDRam
LCD_SetADDRam:
	SETB	ACC.7			; menetapkan alamat DDRAM
	;SJMP	_LCD_TulisIR

_LCD_TulisIR:				; total stack = 4 byte !
	PUSH	DPH
	MOV	DPH,#HIGH HW_LCD_BacaIR	; = *01b
	PUSH	ACC
__lti_cekBF:
	MOVX	A,@DPTR
	JB	ACC.7,__lti_cekBF	; tunggu hingga BF=0
	DEC	DPH			; *00b=tulis IR
	POP	ACC
	MOVX	@DPTR,A
	POP	DPH
	RET

	PUBLIC	LCD_HapusChr
LCD_HapusChr:
	CJNE	A,#CR,_LCD_TplSpasi
	SJMP	_LCD_BarisBaru
_LCD_TplSpasi:
	MOV	A,#' '
	;SJMP	_LCD_TulisDR

_LCD_TulisDR:
	PUSH	DPH
	MOV	DPH,#HIGH HW_LCD_BacaIR	; = *01b
	PUSH	ACC
__ltd_cekBF:
	MOVX	A,@DPTR
	JB	ACC.7,__ltd_cekBF	; tunggu hingga BF=0
	INC	DPH			; *10b=tulis DR
	POP	ACC
	MOVX	@DPTR,A
	POP	DPH
	RET

;LCD_BacaIR:
;	PUSH	DPH
;	MOV	DPH,#HIGH HW_LCD_BacaIR	; = *01b
;	MOVX	A,@DPTR
;	CLR	ACC.7
;	POP	DPH
;	RET

;LCD_BacaChr:				;= _LCD_BacaDR
;	PUSH	DPH
;	MOV	DPH,#HIGH HW_LCD_BacaIR	; = *01b
;__lbd_cekBF:
;	MOVX	A,@DPTR
;	JB	ACC.7,__lbd_cekBF	;tunggu hingga BF=0
;	MOV	DPH,#HIGH HW_LCD_BacaDR	; = *11b
;	MOVX	A,@DPTR
;	POP	DPH
;	;PUSH	ACC
;	;ACALL	LCD_GsrKsrKiri
;	;POP	ACC
;	RET

;--------------------------------
; Penginisialisasi Modul LCD
; tundaan dihitung dgn asumsi EA=0
; K: A<>0=gagal
;--------------------------------

	PUBLIC	LCD_Init
LCD_Init:
	MOV	DPH,#HIGH HW_LCD_TulisIR	; = *00b
	MOV	R2,#3
_LCD_InitLebar:
	MOV	A,R2
	ADD	A,#TBL_LCD_TundaInit - $ - 4
	MOVC	A,@A+PC
__LIL_Tundaan:
	MOV	R3,#45
	DJNZ	R3,$			; 45*2sk
	DJNZ	ACC,__LIL_Tundaan	; @loop == 93sk == 101us, (11M0592)
	MOV	A,#110000b		; fungsi: DL=8-BIT
	MOVX	@DPTR,A
	DJNZ	R2,_LCD_InitLebar

	MOV	DPH,#HIGH HW_LCD_BacaIR	; = *01b
	MOV	R2,#4
_LCD_InitCek:
	MOV	R3,#18
	DJNZ	R3,$			; 18*2sk, @loop==37sk==40us (11M0592)
	MOVX	A,@DPTR
	JB	ACC.7,__lic_gagal	; harus 'siap' sebelum menulis
	MOV	A,R2
	ADD	A,#TBL_LCD_Konfig - $ - 4
	MOVC	A,@A+PC
	DEC	DPH			; *00b=tulis IR
	MOVX	@DPTR,A
	INC	DPH			; = *01b
	MOVX	A,@DPTR
	JNB	ACC.7,__lic_gagal	; harus 'sibuk' setelah menulis
	DJNZ	R2,_LCD_InitCek		;; EA=0 !
__lic_gagal:
	MOV	A,R2			; jika sukes A=0
	RET

TBL_LCD_TundaInit:
; urutan dibalik
	DB	41			; terakhir = 4,1ms
	DB	1			; = 100us
	DB	150			; pertama = 15ms

TBL_LCD_Konfig:
; urutan dibalik
	DB	110b		; masukan: I/D=(+),S(hift dsp)=tdk
	DB	1100b		; on/off: D(isplay)=on
	DB	1000b		; on/off: D(isplay)=C(ursor)=B(link)=off
	DB	111100b		; fungsi: DL=8-bit, N=2-baris, F=5x8-dot

	END
