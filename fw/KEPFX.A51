; master : KEPBIOS.A51

PUBLIC	KP_EfekSuara

EXTRN	BIT	(F_PS_Aktif, F_PS_SUlang)
EXTRN	CODE	(PS_AntriSuara1, PS_TimpaAntriSuara1)
EXTRN	BIT	(F_KP_Bertambah, F_KP_Berkurang, F_KP_Alarm)
EXTRN	BIT	(F_KP_SuaraTetap, F_KP_SuaraBeda)
EXTRN	NUMBER	(CS_Tambah, CS_Kurang)

SegC_KPPlus	SEGMENT	CODE
		RSEG	SegC_KPPlus

KP_EfekSuara:
	JBC	F_KP_Bertambah,_KPFx_Bertambah
	JBC	F_KP_Berkurang,_KPFx_Berkurang
_KPFx_qx:
	RET

_KPFx_Bertambah:
	JNB	F_KP_SuaraBeda,_KPFx_STetap
	MOV	DPTR,#CS_Tambah
	LCALL	PS_TimpaAntriSuara1
_KPFx_STetap:
	JBC	F_KP_Berkurang,__KPFx_ST2	; cegah 'overlap'
__KPFx_ST1:
	JNB	F_KP_SuaraTetap,_KPFx_qx
	SETB	F_PS_SUlang			; aktifkan Suara Ulang
	SETB	F_PS_Aktif
	RET

__KPFx_ST2:
	JB	F_KP_Alarm,__KPFx_ST1		; masih ada yg akan berkurang ?
	SETB	F_KP_Berkurang
	RET

	PUBLIC	KPFx_UpdateSTetap
KPFx_UpdateSTetap:
	CLR	F_PS_SUlang			; matikan dahulu

	PUBLIC	KPFx_CekSTetap
KPFx_CekSTetap:
	JB	F_KP_Alarm,__KPFx_ST1
	RET

_KPFx_berkurang:
	JNB	F_KP_Alarm,_KPFx_Tutup
	JNB	F_KP_SuaraBeda,_KPFx_qx
	MOV	DPTR,#CS_Kurang
	LJMP	PS_AntriSuara1

_KPFx_Tutup:
	CLR	F_PS_SUlang
	JNB	F_KP_SuaraBeda,_KPFx_qx
	MOV	DPTR,#CS_Kurang
	LJMP	PS_TimpaAntriSuara1


	END

;	MOV	DPTR,#OTBL_KP_SuaraBeda
;	MOV	DPTR,#OTBL_KP_SuaraBeda
;	MOV	DPTR,#OTBL_KP_SuaraBeda

;C_KP_JmlSBeda	EQU	2
;C_KP_JmlSTetap	EQU	4

OTBL_KP_SuaraBeda:
	dw	$
	dw	$
OTBL_KP_SuaraTetap:
	DW	$
	DW	$
	DW	$
	DW	$


;	SJMP	_KPFx_qx
;	JNB	F_KP_SuaraTetap,_KPFx_STutup
;_KPFx_STutup:

;SegNV16			SEGMENT	XDATA
;			RSEG	SegNV16
;NV_PS_STetap:	DS	1
;NV_PS_STambah:	DS	1
;NV_PS_SKurang:	DS	1

;CD_PS_STetap	EQU	1		;??
;CD_PS_STambah	EQU	2		;??
;CD_PS_SKurang	EQU	3		;??

;KP_RstNVSuara:
;	MOV	A,#CD_PS_STetap
;	MOV	DPTR,#NV_PS_STetap
;	MOVX	@DPTR,A
;	MOV	A,#CD_PS_STambah
;	MOV	DPTR,#NV_PS_STambah
;	MOVX	@DPTR,A
;	MOV	A,#CD_PS_SKurang
;	MOV	DPTR,#NV_PS_SKurang
;	MOVX	@DPTR,A
;	RET

