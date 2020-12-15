; =========================================================================================================================================================
; Sonic's Fun And Easy Adventure
; By Ralakimus/Novedicus 2017
; =========================================================================================================================================================
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Includes
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
		include	"_INCLUDE_/Configuration.asm"	; User configuration
		include	"../include/Shared.asm"		; MegaDrive includes
		include	"_ERROR_/debugger.asm"		; Debugger macro set
		include	"../amps/code/macro.asm"	; AMPS macros
		include	"../amps/code/smps2asm.asm"	; AMPS SMPS2ASM
		include	"_INCLUDE_/Shared.asm"		; User includes
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Header
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
		include	"_INCLUDE_/Header.asm"
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Function libraries
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
		include	"_LIB_/VDP.asm"			; VDP functions
		include	"_LIB_/Joypad.asm"		; Joypad functions
		include	"_LIB_/Interrupt.asm"		; Interrupt functions
		include	"_LIB_/Decompression.asm"	; Decompression functions
		include	"_LIB_/Math.asm"		; Math functions
		include	"_LIB_/Object.asm"		; Object functions
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
GameInit:
		intsOff					; Disable interrupts
		
		clrRAM	RAM_START, RAM_END		; Clear RAM
		
		bsr.w	InitDMAQueue			; Initialize the DMA queue
		bsr.w	InitVDP				; Initialize the VDP
		jsr	LoadDualPCM			; Load Dual PCM
		
		move.b	HW_VERSION,d0			; Get hardware version
		andi.b	#$C0,d0				; Just get region bits
		move.b	d0,r_HW_Version.w		; Store in RAM

		move.w	#$4EF9,d0			; JMP opcode
		move.w	d0,r_VInt_Jmp.w			; Set the "JMP" command for V-INT
		move.w	d0,r_HInt_Jmp.w			; Set the "JMP" command for H-INT
		move.l	#VInt_Standard,r_VInt_Addr.w	; Set the V-INT pointer to the standard V-INT routine
		move.l	#HInt_Water,r_HInt_Addr.w	; Set the H-INT pointer to the standard V-INT routine

		clr.w	r_DMA_Queue.w			; Set stop token at the beginning of the DMA queue
		move.w	#r_DMA_Queue,r_DMA_Slot.w	; Reset the DMA queue slot

		move.b	#gTitle,r_Game_Mode.w		; Set game mode to "title"
		bra.w	TitleScreen			; Go to the title screen
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Go to the correct game mode
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
GotoGameMode:
		moveq	#0,d0
		move.b	r_Game_Mode.w,d0		; Get game mode ID
		movea.l	.GameModes(pc,d0.w),a0		; Get pointer
		jmp	(a0)				; Jump to it
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.GameModes:
		dc.l	TitleScreen			; Title screen
		dc.l	Level				; Level mode
		dc.l	Ending				; Ending
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Check for pausing
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
CheckPause:
		tst.b	r_Pause_Flag.w			; Is the game already paused?
		bne.s	.SetPause			; If so, branch
		btst	#7,r_P1_Press.w			; Has the start button been pressed?
		beq.s	.End				; If not, branch

.SetPause:
		st	r_Pause_Flag.w			; Pause the game
		AMPS_MUSPAUSE				; Pause the music

.PauseLoop:
		move.b	#vGeneral,r_VINT_Rout.w		; General V-INT routine
		bsr.w	VSync_Routine			; V-SYNC
		btst	#7,r_P1_Press.w			; Has the start button been pressed?
		beq.s	.PauseLoop			; If not, branch

		AMPS_MUSUNPAUSE				; Unpause the music
		clr.b	r_Pause_Flag.w			; Unpause the game

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Interrupts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
VInt_Standard:
		intsOff					; Turn interrupts off
		push.l	d0-a6				; Save registers
		
		lea	VDP_CTRL,a6			; VDP control port
		lea	-4(a6),a5			; VDP data port

.WaitForVBLANK:
		move.w	(a6),d0				; Get VDP status
		andi.w	#8,d0				; Are we in a VBLANK period?
		beq.s	.WaitForVBLANK			; If not, wait

		btst	#6,r_HW_Version.w		; Is this a PAL system?
		beq.s	.SetVScroll			; If not, branch
		move.w	#$700,d0			; Do a delay
		dbf	d0,*				; ''

.SetVScroll:
		dma68k	r_VScroll,0,$50,VSRAM		; Load VScroll buffer into VSRAM

		tst.b	r_VINT_Rout.w			; Is the game lagging?
		beq.w	VInt_Lag_Main			; If so, branch
		clr.b	r_Lag_Count.w			; Clear lag frame counter

		moveq	#0,d0
		move.b	r_VINT_Rout.w,d0		; Get V-INT routine ID
		clr.b	r_VINT_Rout.w			; Clear V-INT routine ID
		st	r_HInt_Flag.w			; Allow the H-INT to run
		move.w	VInt_Routines(pc,d0.w),d0	; Get V-INT routine offset
		jsr	VInt_Routines(pc,d0.w)		; Jump to the routine

VInt_FinishUpdates:
		jsr	UpdateAMPS			; Run the AMPS driver

VInt_End:
		addq.l	#1,r_Frame_Cnt.w		; Increment frame count
		bsr.w	RandomNumber			; Generate a random number
		
		pop.l	d0-a6				; Restore registers
		intsOn					; Turn interrupts on
		lagOn					; Turn on the lag-o-meter
		rte
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; V-INT routines
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
VInt_Routines:
		dc.w	VInt_Lag-VInt_Routines		; Lag routine
		dc.w	VInt_General-VInt_Routines	; General routine
		dc.w	VInt_Level-VInt_Routines	; Level routine
		dc.w	VInt_LevelLoad-VInt_Routines	; Level load routine
		dc.w	VInt_FMV-VInt_Routines		; FMV routine
		dc.w	VInt_Title-VInt_Routines	; Title screen routine
		dc.w	VInt_Fade-VInt_Routines		; Fade routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; V-INT lag routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
VInt_Lag:
		addq.w	#4,sp				; Don't return to caller

VInt_Lag_Main:
		tst.b	r_Water_Fullscr.w		; Is water fullscreen?
		bne.s	.WaterPal			; If so, branch
		dma68k	r_Palette,0,$80,CRAM		; Load palette into CRAM
		bra.s	.Cont				; Continue

.WaterPal:
		dma68k	r_Water_Pal,0,$80,CRAM		; Load water palette into CRAM

.Cont:	
		move.w	r_HInt_Reg.w,(a6)		; Set H-INT counter

		addq.b	#1,r_Lag_Count.w		; Increment lag counter
		bra.w	VInt_FinishUpdates		; Go update SMPS
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; V-INT general routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
VInt_General:
		bsr.w	VInt_Update			; Do updates
		bra.w	SetKosBookmark			; Set Kosinski decompression bookmark
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; V-INT level load routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
VInt_LevelLoad:
		bsr.w	ReadJoypads			; Read joypads

		tst.b	r_Water_Fullscr.w		; Is water fullscreen?
		bne.s	.WaterPal			; If so, branch
		dma68k	r_Palette,0,$80,CRAM		; Load palette into CRAM
		bra.s	.Cont				; Continue

.WaterPal:
		dma68k	r_Water_Pal,0,$80,CRAM		; Load water palette into CRAM

.Cont:
		move.w	r_HInt_Reg.w,(a6)		; Set H-INT counter
		
		dma68k	r_Sprites,$F800,$280,VRAM	; Load sprite table into VRAM
		dma68k	r_HScroll,$FC00,$380,VRAM	; Load H-Scroll table into VRAM
		bsr.w	ProcessDMAQueue			; Process DMA queue
		
		bra.w	SetKosBookmark			; Set Kosinski decompression bookmark
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; V-INT level routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
VInt_Level:
		lea	r_FG_Cam.w,a1			; Foreground level drawing variables
		lea	r_FG_Col_Buf.w,a3		; Foreground column plane buffer
		lea	r_FG_Row_Buf.w,a4		; Foreground row plane buffer
		jsr	VInt_DrawLevel			; Update the foreground plane
		lea	r_BG_Cam.w,a1			; Background level drawing variables
		lea	r_BG_Col_Buf.w,a3		; Background column plane buffer
		lea	r_BG_Row_Buf.w,a4		; Background row plane buffer
		jsr	VInt_DrawLevel			; Update the background plane

		bsr.w	ReadJoypads			; Read joypads

		tst.b	r_Water_Fullscr.w		; Is water fullscreen?
		bne.s	.WaterPal			; If so, branch
		dma68k	r_Palette,0,$80,CRAM		; Load palette into CRAM
		bra.s	.Cont				; Continue

.WaterPal:
		dma68k	r_Water_Pal,0,$80,CRAM		; Load water palette into CRAM

.Cont:
		move.w	r_HInt_Reg.w,(a6)		; Set H-INT counter

		dma68k	r_Sprites,$F800,$280,VRAM	; Load sprite table into VRAM
		dma68k	r_HScroll,$FC00,$380,VRAM	; Load H-Scroll table into VRAM
		bsr.w	ProcessDMAQueue			; Process DMA queue
		
		cmpi.b	#92,r_HInt_Cnt.w		; Would V-INT be unable to do updates in the next frame?
		bhs.s	.DoUpdates			; If not, branch
		st	r_HInt_Updates.W		; Set updates in H-INT flag
		addq.w	#4,sp				; Skip SMPS update routine afterwards
		bsr.w	SetKosBookmark			; Set Kosinski decompression bookmark
		bra.w	VInt_End			; Continue

.DoUpdates:
		jsr	Level_UpdateHUD			; Update the HUD
		bra.w	SetKosBookmark			; Set Kosinski decompression bookmark
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; V-INT FMV update routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
VInt_FMV:
		bsr.w	ReadJoypads			; Read joypads

		dma68k	r_Palette,0,$80,CRAM		; Load palette into CRAM
		
		tst.b	r_FMV_Load.w			; Should we load new data?
		beq.s	.End				; If not, branch
		tst.b	r_FMV_Plane.w			; Are we on plane 1?
		beq.s	.Plane0				; If not, branch
		dma68k	r_Buffer,$A000,$1000,VRAM	; Load map buffer into VRAM
		bra.s	.LoadArt			; Continue

.Plane0:
		dma68k	r_Buffer,$C000,$1000,VRAM	; Load map buffer into VRAM
		
.LoadArt:
		bra.w	ProcessDMAQueue			; Process DMA queue

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; V-INT title screen update routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
VInt_Title:
		bsr.w	ReadJoypads			; Read joypads

		move.l	#$C0000000,VDP_CTRL		; Write palette to CRAM
		lea	r_Palette.w,a0			; ''
		moveq	#$80>>2-1,d0			; ''

.WritePal:
		move.l	(a0)+,VDP_DATA			; ''
		dbf	d0,.WritePal			; ''

		move.l	#$78000003,VDP_CTRL		; Write sprite data to VRAM
		lea	r_Sprites.w,a0			; ''
		move.w	#$280>>2-1,d0			; ''

.WriteSprs:
		move.l	(a0)+,VDP_DATA			; ''
		dbf	d0,.WriteSprs			; ''

		move.l	#$7C000003,VDP_CTRL		; Write HScroll table to VRAM
		lea	r_HScroll.w,a0			; ''
		move.w	#$380>>2-1,d0			; ''

.WriteHScrl:
		move.l	(a0)+,VDP_DATA			; ''
		dbf	d0,.WriteHScrl			; ''
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; V-INT fade routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
VInt_Fade:
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Do standard updates in V-INT
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
VInt_Update:
		bsr.w	ReadJoypads			; Read joypads

		tst.b	r_Water_Fullscr.w		; Is water fullscreen?
		bne.s	.WaterPal			; If so, branch
		dma68k	r_Palette,0,$80,CRAM		; Load palette into CRAM
		bra.s	.Cont				; Continue

.WaterPal:
		dma68k	r_Water_Pal,0,$80,CRAM		; Load water palette into CRAM

.Cont:
		move.w	r_HInt_Reg.w,(a6)		; Set H-INT counter

		dma68k	r_Sprites,$F800,$280,VRAM	; Load sprite table into VRAM
		dma68k	r_HScroll,$FC00,$380,VRAM	; Load H-Scroll table into VRAM
		bra.w	ProcessDMAQueue			; Process DMA queue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; V-INT routine that only runs the SMPS driver
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
VInt_RunSMPS:
		push.l	d0-a6				; Save registers
		
.WaitForVBLANK:
		move.w	VDP_CTRL,d0			; Get VDP status
		andi.w	#8,d0				; Are we in a VBLANK period?
		beq.s	.WaitForVBLANK			; If not, wait

		btst	#6,r_HW_Version.w		; Is this a PAL system?
		beq.s	.UpdateSMPS			; If not, branch
		move.w	#$700,d0			; Do a delay
		dbf	d0,*				; ''

.UpdateSMPS:
		jsr	UpdateAMPS			; Run the AMPS driver

		addq.l	#1,r_Frame_Cnt.w		; Increment frame count
		bsr.w	RandomNumber			; Generate a random number
		
		pop.l	d0-a6				; Restore registers
		rte
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Title screen
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
		include	"Title Screen/Main.asm"
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Level
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
		include	"Level/Main.asm"
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Ending
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
		include	"Ending/Main.asm"
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Horizontal interrupt for palette swapping (for water)
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
HInt_Water:
		intsOff					; Disable interrupts

		tst.b	r_HInt_Flag.w			; Is the H-INT allowed to run?
		beq.s	.End				; If not, branch
		clr.b	r_HInt_Flag.w			; Clear the H-INT flag

		push.l	a0-a1				; Save registers

		lea	VDP_DATA,a1			; VDP data port
		move.w	#$8AFF,4(a1)			; Don't do any more H-INT calls for the rest of the frame
		lea	r_Water_Pal.w,a0		; Water palette
		vdpCmd	move.l, 0, CRAM, WRITE, 4(a1)	; Set VDP command
		rept	32
			move.l	(a0)+,(a1)		; Tranfer palette
		endr
		pop.l	a0-a1				; Restore registers
		
		tst.b	r_HInt_Updates.w		; Do we need to do level updates in here?
		bne.s	.DoUpdates			; If so, branch

.End:
		rte

.DoUpdates:
		clr.b	r_HInt_Updates.w		; Clear the update flag
		push.l	d0-a6				; Save registers
		lea	VDP_CTRL,a6			; VDP control port
		lea	-4(a6),a5			; VDP data port
		jsr	Level_UpdateHUD			; Update the HUD
		jsr	UpdateAMPS			; Run the AMPS driver
		pop.l	d0-a6				; Restore registers
		rte
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Sound driver
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
		include	"../amps/code/68k.asm"
DualPCM:
		z80prog	0
		include	"../amps/code/Z80.asm"
DualPCM_sz:
		z80prog
; =========================================================================================================================================================