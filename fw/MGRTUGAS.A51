$INCLUDE(SCH.DEF)
$INCLUDE(OS.DEF)

JO_MgT_Redraw	EQU	0	; jump offset
JO_MgT_Idle	EQU	2
JO_MgT_TArah	EQU	4
JO_MgT_TTdk	EQU	6
JO_MgT_TYa	EQU	8

SegB_MTugas	SEGMENT	BIT
		RSEG	SegB_MTugas

		PUBLIC	F_MT_Redraw
F_MT_Redraw:	DBIT	1


SegC_MTugas	SEGMENT	CODE
		RSEG	SegC_MTugas

;-------------------------------------------------------------
; Rutin Penghubung TgsLtrDepan (NonMenu) dengan TgsLtrBelakang
; M: DPTR/ISTK = TabelReturn[0]
;-------------------------------------------------------------

EXTRN	BIT	(F_PT_AdaTombol)
EXTRN	CODE	(PT_AmbilTombol)

;MgrTugas_ODP:
;	PUSH	DPL
;	PUSH	DPH

	PUBLIC	MgrTugas_OSP
MgrTugas_OSP:
	LCALL	TgsLtrBelakang
	POP	DPH
	POP	DPL
	ANL	PSW,#NOT 100010B		; F0 + PSW.1 = 0
	JBC	F_MT_Redraw,_MgT_Redraw
	JB	F_PT_AdaTombol,_MgT_AdaTombol
;_Mgt_Idle:
	MOV	A,#JO_MgT_Idle
	JMP	@A+DPTR
_MgT_Redraw:
	;LCALL	LCD_Cls
	ANL	PSW,#NOT 100010B		; F0 + PSW.1 = 0
	MOV	A,#JO_MgT_Redraw
	JMP	@A+DPTR
_MgT_AdaTombol:
	LCALL	PT_AmbilTombol
	;CLR	PSW.1
	MOV	RTmbl,A			; Simpan !
	INC	A
	MOVC	A,@A+PC
	JMP	@A+DPTR
	DB	JO_MgT_TArah, JO_MgT_TArah, JO_MgT_TArah, JO_MgT_TArah	; 0..3
	DB	JO_MgT_TTdk, JO_MgT_TYa					; 4..5


SegC_TugasLB	SEGMENT	CODE
		RSEG	SegC_TugasLB

EXTRN	CODE	(KP_EfekSuara, MgrPrinter, MgrRemote)

	PUBLIC	TgsLtrBelakang
TgsLtrBelakang:
	CLR	P_Watchdog
	;JNB	IE_KP,TLB_IrqPolling	; terminal sudah siap (=1) ?
	LCALL	KP_EfekSuara
	LCALL	MgrRemote

;TLB_IrqPolling:
	LCALL	MgrPrinter

EXTRN	BIT	(IRQ_RTC, IE_RTC)
EXTRN	CODE	(RealTimeClock)

	PUBLIC	TLB_WajibJalan
TLB_WajibJalan:

	PUBLIC	TB_CekIrqRTC
TB_CekIrqRTC:
	JNB	IRQ_RTC,TB_CekIrqPT
	JNB	IE_RTC,TB_CekIrqPT
	CLR	IRQ_RTC
	;CLR	IE_RTC
	LCALL	RealTimeClock
	;SETB	IE_RTC

EXTRN	BIT	(IRQ_PT, IE_PT)
EXTRN	CODE	(PapanTombol)

TB_CekIrqPT:
	JNB	IRQ_PT,_TB_Selesai
	JNB	IE_PT,_TB_Selesai
	CLR	IRQ_PT
	;CLR	IE_PT
	LCALL	PapanTombol
	;SETB	IE_PT

_TB_Selesai:
	;ANL	PSW,#NOT 100010B	; F0 + PSW.1 = 0
	RET

	END

;EndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEnd

;EndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEndEnd



CF_MT_TipeRet	EQU	0
CF_MT_OtoTmbl	EQU	1
CF_MT_KlikGanda	EQU	2
_?JmpRet	EQU	0
_?PushRet	EQU	1 SHL CF_MT_TipeRet
_?OtoTmbl	EQU	1 SHL CF_MT_OtoTmbl
_?KlikGanda	EQU	1 SHL CF_MT_KlikGanda

C_MT_JRet_0Klik	EQU	_?JmpRet
C_MT_PRet_0Klik	EQU	_?PushRet
C_MT_JRet_1Klik	EQU	_?JmpRet  + _?OtoTmbl
C_MT_PRet_1Klik	EQU	_?PushRet + _?OtoTmbl
C_MT_JRet_2Klik	EQU	_?JmpRet  + _?OtoTmbl + _?KlikGanda
C_MT_PRet_2Klik	EQU	_?PushRet + _?OtoTmbl + _?KlikGanda

CO_MT_Idle	EQU	1	; offset
CO_MT_Redrw	EQU	3
CO_MT_Tmbl	EQU	5
C_MT_JmlTmbl	EQU	6

PUBLIC	MultiTugas_DPTR, MultiTugas_Sptr
PUBLIC	C_MT_JRet_0Klik, C_MT_JRet_1Klik, C_MT_JRet_2Klik
PUBLIC	C_MT_PRet_0Klik, C_MT_PRet_1Klik, C_MT_PRet_2Klik

MultiTugas_DPTR:
	PUSH	DPL
	PUSH	DPH
MultiTugas_Sptr:
	LCALL	TgsLtrBelakang
	POP	DPH
	POP	DPL
	CLR	A
	MOVC	A,@A+DPTR
	JBC	F_MT_Redraw,_Mt_Redrw
	JNB	ACC.CF_MT_OtoTmbl,_Mt_Idle	; Baca tombol ?
	JB	F_PT_AdaTombol,_Mt_AdaTombol
_Mt_Idle:
	MOV	C,ACC.CF_MT_TipeRet	; Tipe Return
	MOV	A,#CO_MT_Idle		; = [almt_idle]
	JC	_Mt_PushRet1
	JMP	@A+DPTR
_Mt_Redrw:
	MOV	B,A
;;;	LCALL	LCD_Cls
;	MOV	C,ACC.CF_MT_TipeRet	; Tipe Return
	MOV	C,B.CF_MT_TipeRet	; Tipe Return
	MOV	A,#CO_MT_Redrw	; = [almt_redrw]
	JC	_Mt_PushRet1
	JMP	@A+DPTR
_Mt_AdaTombol:
	MOV	R1,A
	LCALL	PT_AmbilTombol
	MOV	R0,A			; Simpan !
	RL	A
	ADD	A,#CO_MT_Tmbl		; = [idx_tombol]
	XCH	A,R1
;	JB	ACC.CF_MT_OtoTmbl,_Mt_OtoTmbl	; ada tabel tombol ?
;	MOV	R1,#CO_MT_Tmbl	; = [almt_tombol]
;	SJMP	_Mt_JmpRet
;_Mt_OtoTmbl:
	JNB	ACC.CF_MT_KlikGanda,_Mt_JmpRet	; mendukung klik ganda ?
	JNB	F0,_Mt_JmpRet
	XCH	A,R1
	ADD	A,#2*C_MT_JmlTmbl
	XCH	A,R1
_Mt_JmpRet:
	MOV	C,ACC.CF_MT_TipeRet	; Tipe Return
	MOV	A,R1
	JC	_Mt_PushRet2
	JMP	@A+DPTR

_Mt_PushRet1:
	MOV	R1,A
_Mt_PushRet2:
	INC	A
	MOVC	A,@A+DPTR			;lo
	PUSH	ACC
	MOV	A,R1
	MOVC	A,@A+DPTR			;hi
	PUSH	ACC
	RET

