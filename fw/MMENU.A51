;REV:
; Rutin Info dijalankan, dengan mem-PUSH @Table (F0=status opsi)
; Rutin Enter dijalankan, dengan mem-PUSH @Redraw (F0=status klik)
; Rutin Escape (F0=klik) dan Redraw (F0=0) dijalankan tanpa menggubah stack
; RegOpsi berada pada SegD_umum[CA_MMu_DOpsi] *OBSOLETE
; 02:51am 03-31-1999 CO_Mmu_DOpsi mengizinkan MenuTmp
; 18:07pm 04-01-1999 Permintaan Upper-Redraw ada di PSW.1 (F1)
; 21:38pm 04-06-1999 RegOpsi ada di puncak stack

$INCLUDE(STDIO.DEF)
$INCLUDE(OS.DEF)
$INCLUDE(SCH.DEF)

EXTRN	CODE	(LCD_Cls, LCD_SetXY, LCD_TulisChr, LCD_TulisCStr)
EXTRN	CODE	(LCD_GsrKsrKanan)
EXTRN	BIT	(F_MT_Redraw, F_PT_AdaTombol)
EXTRN	CODE	(TgsLtrBelakang, PT_AmbilTombol)
EXTRN	CODE	(SwapPtr16, XPtrCOde)

PUBLIC	MultiMenu_OSP, MMenu_TdkCls_ODP
PUBLIC	MgrMenu_OSP
;PUBLIC	MMenuCStr_OSP
;PUBLIC	MgrMenuIdle_OSP

PUBLIC	N_MMu_MenuTmp, N_MMu_OpsiMan

;, MultiMenu_ODP:, 
;, MMenuCStr_ODP
;MgrMenu_ODP:
;MgrMenuIdle_ODP

C_MMu_Aktif_Ki	EQU	'['
C_MMu_Aktif_Ka	EQU	']'
C_MMu_Opsi_Ki	EQU	'|'
C_MMu_Opsi_Ka	EQU	'|'

CO_MMu_JmlOpsi	EQU	0
CO_MMu_XYAwal	EQU	1
CO_MMu_PtrOpsi	EQU	2
CO_MMu_Escape	EQU	CO_MMu_PtrOpsi + 2
CO_MMu_Redraw	EQU	CO_MMu_Escape + 2
CO_MMu_MultiPtr	EQU	CO_MMu_Redraw + 2


;MMTBL_Contoh:
;	DB	3, XY_Awal
;	dw	MMu_Utama_Esc
;	dw	MMu_Utama_redrw
;	dw	MMu_Utama_Info0		; Info[n]=[MultiPtr+2n], n=#opsi aktif
;	dw	MMu_Utama_Info1
;	dw	MMu_Utama_Info2
;	dw	MMu_Konfigurasi		; Enter[n]=[MultiPtr+2n+2m], m=jml opsi
;	dw	MMu_Status
;	dw	MMu_Rekaman
;	DB	'Konfigurasi',EOS	; Str[0]=[MultiPtr+4m]
;	DB	'Status',EOS
;	DB	'Rekaman',EOS

N_MMu_MenuTmp	EQU	0FFH		; = CO_MMu_DOpsi[hi] <- jika temporer..
N_MMu_OpsiMan	EQU	0FFH		; = CO_MMu_DOpsi[lo] <- jika manual
					; jika tdk -> CO_MMu_DOpsi[lo] = isi

;RPOpsi		EQU	R0		; didefenisikan di OS.DEF
RTMnu		EQU	R1

SegC_MMenu	SEGMENT	CODE
		RSEG	SegC_MMenu

;---------------------------------
; Rutin Penampil MultiMenu (OOP)
; M: DPTR/ISTK = TabelMenu[0]
; R: f, A, B, RPOpsi, RTMnu
;---------------------------------

; M: @PTR16 = CString yang ingin dicetak, dan diikuti dengan Tabel MultiMenu
;MMenuCStr_OSP:
;	POP	DPH
;	POP	DPL

;MMenuCStr_ODP:
;	LCALL	LCD_Cls
;	LCALL	LCD_TulisCStr		; RET: @DPTR = Tabel MMenu
;	SJMP	MMenu_TdkCls_ODP

; M: @DPTR = Tabel
MultiMenu_OSP:
	POP	DPH
	POP	DPL
;MultiMenu_ODP:
	LCALL	LCD_Cls

MMenu_TdkCls_ODP:
	MOV	A,#CO_MMu_PtrOpsi
	LCALL	XPtrCode				; Ret: A=XPH
	CJNE	A,#N_MMu_MenuTmp,__MMu_JemputXOpsi	; DOpsi ada di XRam ?
	MOV	A,XPL
	CJNE	A,#N_MMu_OpsiMan,__MMu_PosOpsi		; DOpsi manual ?
	SJMP	__MMu_PtrOpsi				; <- Ya
__MMu_JemputXOpsi:
	LCALL	SwapPtr16
	MOVX	A,@DPTR
	LCALL	SwapPtr16
__MMu_PosOpsi:
	PUSH	ACC
__MMu_PtrOpsi:
	MOV	RPOpsi,SP

_MMu_CtkOpsi:
	MOV	A,#CO_MMu_JmlOpsi
	MOVC	A,@A+DPTR
	RL	A
	RL	A				; opsi maks = 64 !
	ADD	A,#CO_MMu_MultiPtr
	MOV	RTMnu,A				; RTMnu= str_menu[0]
	MOV	A,#CO_MMu_XYAwal
	MOVC	A,@A+DPTR
	LCALL	LCD_SetXY
	MOV	B,#0				; # opsi yang dicetak (-1)

_MMu_StatusOpsi:
	MOV	A,@RPOpsi
	CJNE	A,B,_MMu_Tidak_ki		; opsi terpilih ?
	MOV	A,#C_MMu_Aktif_Ki
	SJMP	_MMu_Status_ki
_MMu_Tidak_ki:
	MOV	A,#C_MMu_Opsi_Ki
_MMu_Status_ki:
	LCALL	LCD_TulisChr
_MMu_ctk_str:
	MOV	A,RTMnu
	MOVC	A,@A+DPTR
	INC	RTMnu				; max str < (255-10) !!!
	CJNE	A,#EOS,_MMu_ctk_chr
	MOV	A,@RPOpsi
	CJNE	A,B,_MMu_Tidak_ka		; opsi terpilih ?
	MOV	A,#C_MMu_Aktif_Ka
	SJMP	_MMu_Status_ka
_MMu_ctk_chr:
	LCALL	LCD_TulisChr
	SJMP	_MMu_ctk_str

_MMu_Tidak_ka:
	MOV	A,#C_MMu_Opsi_Ka
_MMu_Status_ka:
	LCALL	LCD_TulisChr
	LCALL	LCD_GsrKsrKanan
	INC	B				; B <- # opsi yang telah dicetak
	MOV	A,#CO_MMu_JmlOpsi
	MOVC	A,@A+DPTR
	CJNE	A,B,_MMu_StatusOpsi
	JB	PSW.1,_MMu_TYa			; jalankan submenu (=1) ?
						;; PSW.1 & F0 tidak ubah
	AJMP	_MMu_Info

;----------------------------------------------------------
; Rutin Penghubung TgsLtrDepan (Menu) dengan TgsLtrBelakang
; M: DPTR = tabel_menu[0]
; R: A, B, RPOpsi, RTMnu
;----------------------------------------------------------

EXTRN	CODE	(TLB_WajibJalan)
EXTRN	BIT	(IE_KP)

	PUBLIC	MgrPopMenu_OSP
MgrPopMenu_OSP:
	JB	IE_KP,MgrMenu_OSP
	CLR	P_Watchdog
	LCALL	TLB_WajibJalan
	SJMP	_MMu_CekTLB

;MgrMenu_ODP:
;	PUSH	DPL
;	PUSH	DPH

MgrMenu_OSP:
	LCALL	TgsLtrBelakang

_MMu_CekTLB:
;MgrMenuIdle_OSP:
	POP	DPH
	POP	DPL

;MgrMenuIdle_ODP:
	;CLR	P_Watchdog
	ANL	PSW,#NOT 100010B		; F0 (PSW.5) + PSW.1 = 0
	MOV	RPOpsi,SP
	JBC	F_MT_Redraw,_MMu_Redraw
	JNB	F_PT_AdaTombol,_MMu_Idle
	LCALL	PT_AmbilTombol			; ;<- PSW.1 = 0
	;CLR	PSW.1
	CJNE	A,#4,_MMu_TArah			; Tmbl = TTdk ?

;F: JMP ke @Escape langsung
;_MMu_TTidak:
	;*MOV	RTMnu,#CO_MMu_Escape		; = [escape]
	MOV	RPOpsi,#CO_MMu_Escape		; = [escape]
	SJMP	_MMu_SimpanOpsi			; PSW.1 = 0, F0 = Status Klik
						; CY = 0 !
_MMu_TArah:
	JNC	_MMu_TYa			; Tmbl > TTdk (C=0) ?
	MOV	RTMnu,A
	MOV	A,#CO_MMu_JmlOpsi
	MOVC	A,@A+DPTR
	DEC	A
	MOV	B,A
	MOV	A,@RPOpsi
	CJNE	RTMnu,#2,_MMu_TKanan		; Tmbl <> TKiri ?
;_MMu_TKiri:
	JZ	_MMu_Idle			; sudah di awal (=0) ?
	JB	F0,__MMu_UjungKiri
	DEC	@RPOpsi				; = geser kiri
	AJMP	_MMu_CtkOpsi
__MMu_UjungKiri:
	MOV	@RPOpsi,#0			; = ke awal (ujung kiri)
	AJMP	_MMu_CtkOpsi

__MMu_UjungKanan:
	MOV	@RPOpsi,B			; = ke ujung kanan
	AJMP	_MMu_CtkOpsi
__MMu_GsrKanan:
	JB	F0,__MMu_UjungKanan
	INC	@RPOpsi				; = geser kanan
	AJMP	_MMu_CtkOpsi
_MMu_TKanan:
	JC	_MMu_Idle			; Tmbl < TKiri (C=1) ?
	CJNE	A,B,__MMu_GsrKanan
	SJMP	_MMu_Idle			; sudah di ujung kanan, abaikan

_MMu_Redraw:
	;*MOV	RTMnu,#CO_MMu_Redraw
	MOV	RPOpsi,#CO_MMu_Redraw
	CLR	C				; PSW.1 = 0, F0 = 0
	SJMP	_MMu_SimpanOpsi

_MMu_TYa:
	SETB	C				; Tmbl: PSW.1 = 0, F0 = Klik

; CY: 0=RET[RTMnu] ; 1=CALL[@Enter]
_MMu_SimpanOpsi:
	MOV	AC,C				; simpan CY -> AC !
	MOV	A,#CO_MMu_PtrOpsi
	LCALL	XPtrCode				; Ret: A=XPH
	CJNE	A,#N_MMu_MenuTmp,__MMu_SimpanXOpsi	; menu temporer ?
	;*MOV	A,@RPOpsi
	POP	ACC
	CJNE	XPL,#N_MMu_OpsiMan,__MMu_BuangStk	; diisi manual ?
	PUSH	ACC
	SJMP	__MMu_ArahKeluar			; <- Ya, tetap distack
__MMu_SimpanXOpsi:
	;*MOV	A,@RPOpsi
	POP	ACC
	LCALL	SwapPtr16
	MOVX	@DPTR,A
	LCALL	SwapPtr16
__MMu_BuangStk:
	;*DEC	SP
__MMu_ArahKeluar:
	;*XCH	A,RTMnu				; RTMnu <- PosOpsi, A <- @RET
	XCH	A,RPOpsi			; RPOpsi <- PosOpsi, A <- @RET
	JNB	AC,__MMu_JmpByPush

;F: JMP ke @Enter[n] dengan mem-PUSH @Redraw sebagai almt return
;_MMu_Enter:
	MOV	A,#CO_MMu_Redraw+1		; Lo=Redraw[1]
	MOVC	A,@A+DPTR
	PUSH	ACC
	MOV	A,#CO_MMu_Redraw		; Hi=Redraw[0]
	MOVC	A,@A+DPTR
	PUSH	ACC				; <- [Redraw] di stack

	MOV	A,#CO_MMu_JmlOpsi
	MOVC	A,@A+DPTR
	;*ADD	A,RTMnu
	ADD	A,RPOpsi
	RL	A
	ADD	A,#CO_MMu_MultiPtr		; = @Enter[n]

	SJMP	__MMu_JmpByPush
	;MOV	XPL,A
	;INC	A
	;MOVC	A,@A+DPTR			; = lo
	;XCH	A,XPL
	;MOVC	A,@A+DPTR			; = hi
	;MOV	DPH,A
	;MOV	DPL,XPL
	;LJMP	_VCALL_DPTR			; PSW.1 = redraw, F0 = Klik
;EXTRN	CODE	(_VCALL_DPTR)

_MMu_Info:
	SETB	F0				; F0=1: Opsi baru/berubah
_MMu_Idle:					; F0=0: Opsi masih yg lama
	MOV	A,@RPOpsi
	RL	A
	ADD	A,#CO_MMu_MultiPtr		; = @Info[n]
	PUSH	DPL
	PUSH	DPH				; simpan @Tabel di stack

__MMu_JmpByPush:
	;LJMP	JmpWOffset			; F0 = Status Klik / Opsi
						; F1 = Status SubRedraw

;F: JMP WORD[A+DPTR]
PUBLIC	JmpWOffset
JmpWOffset:
	MOV	R1,A
	INC	A
	MOVC	A,@A+DPTR			; = lo
	PUSH	ACC
	MOV	A,R1
	MOVC	A,@A+DPTR			; = hi
	PUSH	ACC
	RET

	END

_MMu_PopStack:
	;MOV	RTMnu,A				; simpan dahulu ofs_RET
	;MOV	A,#CO_MMu_Stack
	;MOVC	A,@A+DPTR
	;cpl	A				; = -(k+1)
	;INC	A
	;ADD	A,SP
	;MOV	SP,A				; buang stack
	;MOV	A,RTMnu

_MMu_PopStack:
	;MOV	RTMnu,A				; simpan dahulu ofs_RET
	;MOV	A,#CO_MMu_Stack
	;MOVC	A,@A+DPTR
	;cpl	A				; = -(k+1)
	;INC	A
	;ADD	A,SP
	;MOV	SP,A				; buang stack
	;MOV	A,RTMnu

_MMu_SwapReg:
	MOV	RTMnu,A				; simpan dahulu ofs_RET
	MOV	A,#CO_MMu_JmlRSwap
	MOVC	A,@A+DPTR
	JZ	_?
	MOV	B,A
	MOV	A,#CO_MMu_PtrXram
	MOVC	A,@A+DPTR
	MOV	R2,A
	MOV	A,#CO_MMu_PtrXram+1
	MOVC	A,@A+DPTR
	XCH	A,DPL
	XCH	A,R2
	XCH	A,DPH
	MOV	R3,A
	LCALL	SwapIXData
	MOV	DPL,R2
	MOV	DPH,R3
_?:
	MOV	A,#CO_MMu_PtrXram
	MOVC	A,@A+DPTR
	MOV	R2,A
	MOV	A,#CO_MMu_PtrXram+1
	MOVC	A,@A+DPTR
	XCH	A,DPL
	XCH	A,R2
	XCH	A,DPH
	MOV	R3,A
	MOV	A,@DPTR
	XCH	A,@RPOpsi
	MOVX	@DPTR,A
	MOV	DPL,R2
	MOV	DPH,R3
