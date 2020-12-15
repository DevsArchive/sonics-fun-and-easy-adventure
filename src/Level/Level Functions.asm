; =========================================================================================================================================================
; Sonic's Fun And Easy Adventure
; By Ralakimus/Novedicus 2017
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; General level functions
; =========================================================================================================================================================
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Load level data
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_LoadData:
		; --- Initialize the start position and camera ---

		lea	Level_SizeStartPos,a3		; Get size and start position data
		move.w	r_Level.w,d0			; Get level ID
		ror.b	#1,d0				; Turn into offset
		lsr.w	#4,d0				; ''
		lea	(a3,d0.w),a3			; Get pointer to the correct pointers

		clr.l	r_Dest_Min_Cam.w		; Set target minimum camera values
		clr.l	r_Min_Cam.w			; Set minimum camera values
		move.l	(a3),r_Dest_Max_Cam.w		; Set target maximum camera values
		move.l	(a3)+,r_Max_Cam.w		; Set maximum camera values

		move.w	#(224/2)-16,r_Cam_Y_Dist.w	; Set camera Y distance

		lea	r_Obj_Player.w,a0		; Player object
		move.w	(a3)+,d1			; Get starting X position
		move.w	d1,oX(a0)			; Set the player's X position
		move.w	(a3),d0				; Get starting Y position
		move.w	d0,oY(a0)			; Set the player's Y position

		tst.b	r_Start_Fall.w			; Should we start the level by falling?
		beq.s	.InitCam			; If not, branch
		bset	#2,(r_Obj_Player+oFlags).w
		moveq	#$72,d1				; Reset Sonic's X position
		move.w	d1,oX(a0)			; ''
		moveq	#-32,d0				; Reset Sonic's Y position
		move.w	d0,oY(a0)			; ''

.InitCam:
		tst.b	r_Last_Chkpoint.w		; Has a checkpoint been hit?
		beq.s	.SetCam				; If not, branch
		bsr.w	Level_LoadSavedInfo		; Load data
		move.w	oX(a0),d1			; Get X position
		move.w	oY(a0),d0			; Get Y position

.SetCam:
		subi.w	#320/2,d1			; Get camera's X position
		bge.s	.ChkMaxX			; If it doesn't go beyond the left boundary, branch
		moveq	#0,d1				; Cap it

.ChkMaxX:
		move.w	r_Max_Cam_X.w,d2		; Get max camera X position
		cmp.w	d2,d1				; Have we gone beyond it?
		bcs.s	.SetCamX			; If not, branch
		move.w	d2,d1				; Cap it

.SetCamX:	
		move.w	d1,r_Cam_X.w			; Set the camera's X position

		subi.w	#(224/2)-16,d0			; Get camera's Y position
		bge.s	.ChkMaxY			; If it doesn't go beyond the upper boundary, branch
		moveq	#0,d0				; Cap it

.ChkMaxY:
		move.w	r_Max_Cam_Y.w,d2		; Get max camera Y position
		cmp.w	d2,d0				; Have we gone beyond it?
		blt.s	.SetCamY			; If not, branch
		move.w	d2,d0				; Cap it

.SetCamY:	
		move.w	d0,r_Cam_Y.w			; Set the camera's Y position

		; --- Load level data ---

		lea	Level_DataPointers,a3		; Level data pointers
		move.w	r_Level.w,d0			; Get level ID
		ror.b	#1,d0				; Turn into offset
		lsr.w	#2,d0				; ''
		lea	(a3,d0.w),a3			; Get pointer to the correct pointers

		movea.l	(a3)+,a0			; Get chunk data pointer
		lea	r_Chunks,a1			; Decompress into chunk table
		jsr	KosDec.w			; ''

		movea.l	(a3)+,a0			; Get block data pointer
		lea	r_Blocks.w,a1			; Decompress into block table
		jsr	KosDec.w			; ''

		movea.l	(a3)+,a1			; Get tile data pointer
		moveq	#0,d2				; Store in the beginning of VRAM
		jsr	QueueKosMData.w			; Queue for decompression

		movea.l	(a3)+,a0			; Get palette data pointer
		move.w	(a0)+,d0			; Size of palette data
		jsr	LoadTargetPal.w			; Load the palette

		movea.l	(a3)+,a0			; Get layout pointer
		lea	r_Layout.w,a1			; Decompress into layout buffer
		jsr	KosDec.w			; ''

		move.l	(a3)+,r_Obj_Pos_Addr.w		; Set object position data pointer
		move.l	(a3)+,r_Ring_Pos_Addr.w		; Set ring position data pointer
		movea.l	(a3)+,a3			; Get collision data pointers
		move.l	(a3)+,d0			; Get collision data address
		move.l	d0,r_Col_Addr.w			; Set collision address to primary
		move.l	d0,r_1st_Col.w			; Set primary collision data pointer
		addq.l	#1,d0				; Increment address for secondary collision
		move.l	d0,r_2nd_Col.w			; Set secondary collision data pointer
		lea	r_Angle_Vals.w,a1		; Collision pointers
		move.l	(a3)+,(a1)+			; Set angle value array pointer
		move.l	(a3)+,(a1)+			; Set normal hiehgt map array pointer
		move.l	(a3)+,(a1)			; Set rotated hiehgt map array pointer

		lea	Level_PLCs,a3			; Get PLC list pointer
		move.w	r_Level.w,d0			; Get level ID
		ror.b	#1,d0				; Turn into offset
		lsr.w	#5,d0				; ''
		movea.l	(a3,d0.w),a3			; Get pointer to the correct pointers
		jmp	LoadKosMQueue.w			; Load the PLCs
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Update the water surface
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_UpdateWaterSurface:
		tst.b	r_Water_Flag.w			; Does the level have water?
		beq.s	.End				; If not, branch
		move.w	r_Cam_X.w,d1			; Get camera X position
		btst	#0,(r_Lvl_Frames+1).w		; Are we on an odd frame?
		beq.s	.SetXPos			; If not, branch
		addi.w	#$20,d1				; Shift X position

.SetXPos:
		move.w	d1,d0				; Copy X postion
		addi.w	#$60,d0				; Add surface #1's X position
		move.w	d0,(r_Obj_Surface1+oX).w	; Set it
		addi.w	#$120,d1			; Add surface #2's X position
		move.w	d1,(r_Obj_Surface2+oX).w	; Set it

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle water height
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_WaterHeight:
		tst.b	r_Water_Flag.w			; Does the level have water?
		beq.s	.End				; If not, branch
		bsr.w	Level_MoveWater			; Move the water when appropriate
		clr.b	r_Water_Fullscr.w		; Clear water fullscreen flag

		moveq	#1,d1				; Water movement speed
		move.w	r_Dest_Wat_Lvl.w,d0		; Get destination water level
		sub.w	r_Water_Lvl.w,d0		; Is the current water level at that destination?
		beq.s	.ChkOnScr			; If so, branch
		bcc.s	.MoveDown			; If it needs to go down, branch
		neg.w	d1				; Go up

.MoveDown:
		add.w	d1,r_Water_Lvl.w		; Move water

.ChkOnScr:
		move.w	r_Water_Lvl.w,d0		; Get water height
		sub.w	r_Cam_Y.w,d0			; Get camera's Y position
		beq.s	.Fullscreen			; If they are the same, branch
		bcc.s	.ChkBottom			; If the water height is below the top of the camera, branch
		
.Fullscreen:
		st	r_Water_Fullscr.w		; Set water fullscreen flag
		st	r_HInt_Cnt.w			; Set H-INT counter to be offscreen
		rts

.ChkBottom:
		cmpi.w	#224-1,d0			; Is the water below the camera?
		blo.s	.SetCounter			; If not, branch
		moveq	#-1,d0				; Set H-INT counter to be offscreen

.SetCounter:
		move.b	d0,r_HInt_Cnt.w			; Set H-INT counter

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_MoveWater:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Do level palette cycling
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_PalCycle:
		lea	Level_PalCycRouts,a0		; Palette cycle routines
		move.w	r_Level.w,d0			; Get level ID
		ror.b	#1,d0				; Turn into offset
		lsr.w	#5,d0				; ''
		movea.l	(a0,d0.w),a0			; Get correct routine pointer
		jmp	(a0)				; Jump to it
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Do level art animation
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_AnimateArt:
		lea	Level_AniArtRouts,a0		; Animated art routines
		move.w	r_Level.w,d0			; Get level ID
		ror.b	#1,d0				; Turn into offset
		lsr.w	#5,d0				; ''
		movea.l	(a0,d0.w),a0			; Get correct routine pointer
		jmp	(a0)				; Jump to it
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Do dynamic events
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_DynEvents:
		lea	Level_DynEvenRouts,a0		; Dynamic events routines
		move.w	r_Level.w,d0			; Get level ID
		ror.b	#1,d0				; Turn into offset
		lsr.w	#5,d0				; ''
		movea.l	(a0,d0.w),a0			; Get correct routine pointer
		jmp	(a0)				; Jump to it
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle the camera
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_HandleCamera:
		lea	r_Obj_Player.w,a0		; Get player object
		
		tst.b	r_Cam_Lock_X.w			; Is the camera locked horizontally?
		bne.s	.ChkY				; If so, branch
		lea	r_Cam_X.w,a1			; Get foreground level variables
		bsr.s	Level_MoveCameraX		; Move the camera horiozntally
		
.ChkY:
		tst.b	r_Cam_Lock_Y.w			; Is the camera locked vertically?
		bne.s	.ChkMaxY			; If not, branch
		lea	r_Cam_Y.w,a1			; Get foreground level variables
		move.w	r_Cam_Y_Dist.w,d3		; Get camera Y distance
		bsr.w	Level_MoveCameraY		; Move the camera vertically

.ChkMaxY:
		moveq	#2,d1				; Target camera scroll speed
		move.w	r_Dest_Max_Y.w,d0		; Get distance between target and actual target max camera Y position
		sub.w	r_Max_Cam_Y.w,d0		; ''
		beq.s	.End				; If it's 0, branch
		bcc.s	.MoveDown			; If it's positive, branch
		move.w	r_Cam_Y.w,d0			; Get current camera Y position
		cmp.w	r_Dest_Max_Y.w,d0		; Is it past the boundary?
		bls.s	.ScrollUp			; If not, branch
		move.w	d0,r_Max_Cam_Y.w		; Set max camera Y position
		andi.w	#$FFFE,r_Max_Cam_Y.w		; Keep it a multiple of 2

.ScrollUp:
		sub.w	d1,r_Max_Cam_Y.w		; Scroll up
		st	r_Cam_Max_Chg.w			; Indicate that the max Y boundary is changing


.End:
		rts

.MoveDown:
		move.w	r_Cam_Y.w,d0			; Get current camera Y position
		addq.w	#8,d0				; ''
		cmp.w	r_Max_Cam_Y.w,d0		; Is it past the boundary?
		bcs.s	.ScrollDown			; If not, branch
		btst	#1,(r_Obj_Player+oStatus).w	; Is the player in the air?
		beq.s	.ScrollDown			; If not, branch
		add.w	d1,d1				; Scroll down faster
		add.w	d1,d1				; ''

.ScrollDown:
		add.w	d1,r_Max_Cam_Y.w		; Scroll down
		st	r_Cam_Max_Chg.w			; Indicate that the max Y boundary is changing
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_MoveCameraX:
		move.w	oX(a0),d0			; Get the player's X position
		sub.w	(a1),d0				; Get distance from the camera's X position
		sub.w	r_Cam_X_Center.w,d0		; Subtract center
		blt.s	.MoveLeft			; If we are going left, branch
		bge.s	.MoveRight			; If we are going right, branch
		rts

.MoveLeft:
		cmpi.w	#-16,d0				; Is the camera moving more than 16 pixels per frame?
		bgt.s	.ChkLeftBound			; If not, branch
		move.w	#-16,d0				; Keep the camera from moving too fast

.ChkLeftBound:
		add.w	(a1),d0				; Add back the camera's X position
		cmp.w	r_Min_Cam_X.w,d0		; Have we gone past the left boundary?
		bgt.s	.SetCamX			; If not, branch
		move.w	r_Min_Cam_X.w,d0		; Cap at the left boundary
		bra.s	.SetCamX			; Continue

.MoveRight:
		cmpi.w	#16,d0				; Is the camera moving more than 16 pixels per frame?
		blo.s	.ChkRightBound			; If not, branch
		move.w	#16,d0				; Keep the camera from moving too fast

.ChkRightBound:
		add.w	(a1),d0				; Add back the camera's X position
		cmp.w	r_Max_Cam_X.w,d0		; Has the camera gone beyond the right boundary?
		blt.s	.SetCamX			; If not, branch
		move.w	r_Max_Cam_X.w,d0		; Cap at the right boundary

.SetCamX:
		move.w	d0,(a1)				; Set the new camera X position
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_MoveCameraY:
		moveq	#0,d1
		move.w	oY(a0),d0			; Get the player's Y position
		sub.w	(a1),d0				; Get distance from the camera's Y position

		btst	#2,oStatus(a0)			; Is the player rolling?
		beq.s	.NoRoll				; If not, branch
		subq.w	#5,d0				; Move up some

.NoRoll:
		btst	#1,oStatus(a0)			; Is the player in the air?
		beq.s	.ChkBoundCross_Ground		; If not, branch

.ChkBoundCross_Air:
		addi.w	#$20,d0				; You have 32 pixels above and below to move without disturbing the camera
		sub.w	d3,d0				; Subtract camera Y distance
		bcs.s	.ScrollFast			; If the player is above the boundary, branch
		subi.w	#$40,d0				; Subtract 64
		bcc.s	.ScrollFast			; If the player is below the boundary, branch

		tst.b	r_Cam_Max_Chg.w			; Is the max Y boundary changing?
		bne.s	.ScrollMaxYChange		; If so, branch
		bra.s	.NoScroll			; Continue

.ChkBoundCross_Ground:
		sub.w	d3,d0				; Subtract camera Y distance
		bne.s	.DecideScrollType		; If the player moved, branch
		tst.b	r_Cam_Max_Chg.w			; Is the max Y boundary changing?
		bne.s	.ScrollMaxYChange		; If so, branch

.NoScroll:
		rts		

.DecideScrollType:
		cmpi.w	#(224/2)-16,d3			; Is the camera Y distance normal?
		bne.s	.ScrollSlow			; If not, branch

		move.w	oGVel(a0),d1			; Get the players' ground velocity
		bpl.s	.Positive			; If it's positive, branch
		neg.w	d1				; Force it to be positive

.Positive:
		cmpi.w	#$800,d1			; Is the player travelling very fast?
		bhs.s	.ScrollFast			; If so, branch

.ScrollMedium:
		move.w	#6<<8,d1			; Cap camera movement at 6 if going too fast
		cmpi.w	#6,d0				; Is the player going down too fast?
		bgt.s	.ScrollDownMax			; If so, branch
		cmpi.w	#-6,d0				; Is the player going up too fast?
		blt.s	.ScrollUpMax			; If so, branch
		bra.s	.ScrollUpOrDown			; Continue

.ScrollSlow:
		move.w	#2<<8,d1			; Cap camera movement at 2 if going too fast
		cmpi.w	#2,d0				; Is the player going down too fast?
		bgt.s	.ScrollDownMax			; If so, branch
		cmpi.w	#-2,d0				; Is the player going up too fast?
		blt.s	.ScrollUpMax			; If so, branch
		bra.s	.ScrollUpOrDown			; Continue

.ScrollFast:
		move.w	#16<<8,d1			; Cap camera movement at 16 if going too fast
		cmpi.w	#16,d0				; Is the player going down too fast?
		bgt.s	.ScrollDownMax			; If so, branch
		cmpi.w	#-16,d0				; Is the player going up too fast?
		blt.s	.ScrollUpMax			; If so, branch
		bra.s	.ScrollUpOrDown			; Continue

.ScrollMaxYChange:
		moveq	#0,d0				; Distance for the camera to move = 0
		move.b	d0,r_Cam_Max_Chg.w		; Clear the max Y boundary changing flag
		
.ScrollUpOrDown:
		moveq	#0,d1
		move.w	d0,d1				; Get position difference
		add.w	(a1),d1				; Add old camera Y position
		tst.w	d0				; Is the camera to scroll down?
		bpl.s	.ScrollDown			; If so, branch
		bra.w	.ScrollUp			; Scroll up

.ScrollUpMax:
		neg.w	d1				; Make the value negative, since we are going up
		ext.l	d1
		asl.l	#8,d1				; Move into upper word tp lie up with the actual value for the Y position
		add.l	(a1),d1				; Add the camera's Y position
		swap	d1				; Get the actual Y position

.ScrollUp:
		cmp.w	r_Min_Cam_Y.w,d1		; Has the camera gone beyond the upper boundary?
		bgt.s	.DoScroll			; If not, branch
		move.w	r_Min_Cam_Y.w,d1		; Cap at upper boundary
		bra.s	.DoScroll			; Continue

.ScrollDownMax:
		ext.l	d1
		asl.l	#8,d1				; Move into upper word tp lie up with the actual value for the Y position
		add.l	(a1),d1				; Add the camera's Y position
		swap	d1				; Get the actual Y position

.ScrollDown:
		cmp.w	r_Max_Cam_Y.w,d1		; Has the camera gone beyond the lower boundary?
		blt.s	.DoScroll			; If not, branch
		move.w	r_Max_Cam_Y.w,d1		; Cap at lower boundary

.DoScroll:
		swap	d1				; Put Y coordinate in the higher word
		move.l	d1,(a1)				; Set Y position
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Level ring manager
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_RingsManager:
		moveq	#0,d0
		move.b	r_Ring_Man_Rout.w,d0		; Get routine
		move.w	.Routines(pc,d0.w),d0		; Get offset
		jmp	.Routines(pc,d0.w)		; Jump to the right routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.Routines:
		dc.w	Level_RingsManager_Init-.Routines
		dc.w	Level_RingsManager_Main-.Routines
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Ring manager initialization
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_RingsManager_Init:
		addq.b	#2,r_Ring_Man_Rout.w		; The next time the manager is run, only go to the main routine
		
		bsr.w	Level_RingsManager_Setup	; Prepare the tables and load the ring data

		; Set up the addresses to use in the current location of the level

		; Start at the left side of the screen
		; We get the location of the first ring that shows up at the left side of the screen in the data and store that

		movea.l	r_Ring_Load_L.w,a1		; Get current ring data address for the left side of the screen
		lea	r_Ring_Stat.w,a2		; Ring status table
		move.w	r_Cam_X.w,d4			; Get camera's X position
		subq.w	#8,d4				; Check 8 pixels to the left of it
		bhi.s	.CheckLeftSide			; Branch if not beyond 0
		moveq	#1,d4				; Cap left side to 1
		bra.s	.CheckLeftSide			; Start checking

.NextLeftRing:
		addq.w	#4,a1				; Next ring in ring data
		addq.w	#2,a2				; Next ring in status table

.CheckLeftSide:
		cmp.w	(a1),d4				; Is this ring located to the right of the left boundary?
		bhi.s	.NextLeftRing			; If not, get the next ring
		move.l	a1,r_Ring_Load_L.w		; Store starting ring data address
		move.w	a2,r_Ring_Stat_Ptr.w		; Store ring status address

		; Now the right side of the screen
		; We get the location of the first ring that goes beyond the right side of the screen in the data and store that

		addi.w	#320+16,d4			; Right boundary
		bra.s	.CheckRightSide			; Start checking

.NextRightRing:
		addq.w	#4,a1				; Next ring in ring data

.CheckRightSide:
		cmp.w	(a1),d4				; Is this ring located to the right of the right boundary?
		bhi.s	.NextRightRing			; If not, get the next ring
		move.l	a1,r_Ring_Load_R.w		; Store ending ring data address
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Ring manager main routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_RingsManager_Main:
		bsr.w	Level_RingsManager_DoCollect	; Handle ring collection

		movea.l	r_Ring_Load_L.w,a1		; Get the current starting address for the ring data
		movea.w	r_Ring_Stat_Ptr.w,a2		; Get the current starting address for the status table
		
		; Get the new starting addresses for ring data
		; This is done by getting to a point from the current starting address where there's a ring onscreen
		; and then going back to get the very first ring that's on screen

		move.w	r_Cam_X.w,d4			; Get camera's X position
		subq.w	#8,d4				; Check 8 pixels to the left of it
		bhi.s	.CheckNewLeftSide		; Branch if not beyond 0
		moveq	#1,d4				; Cap left side to 1
		bra.s	.CheckNewLeftSide		; Start checking

.NextNewLeftRing:
		addq.w	#4,a1				; Next ring in ring data
		addq.w	#2,a2				; Next ring in status table

.CheckNewLeftSide:
		cmp.w	(a1),d4				; Is this ring located to the right of the left boundary?
		bhi.s	.NextNewLeftRing		; If not, get the next ring
		bra.s	.CheckNewLeftSide2		; Start checking

.NextNewLeftRing2:
		subq.w	#4,a1				; Previous ring in ring data
		subq.w	#2,a2				; Previous ring in status table

.CheckNewLeftSide2:
		cmp.w	-4(a1),d4			; Is this ring located to the left of the left boundary?
		bls.s	.NextNewLeftRing2		; If not, get the next ring
		move.l	a1,r_Ring_Load_L.w		; Store starting ring data address
		move.w	a2,r_Ring_Stat_Ptr.w		; Store ring status address

		; Now get the new ending addresses for ring data
		; This is done by getting to a point from the current starting address where there's a ring at the right of the left boundary
		; and then going back to get the very first ring that's on screen on the left side

		movea.l	r_Ring_Load_R.w,a1		; Get the current ending address for the ring data

		addi.w	#320+16,d4			; Right boundary
		bra.s	.CheckNewRightSide		; Start checking

.NextNewRightRing:
		addq.w	#4,a1				; Next ring in ring data

.CheckNewRightSide:
		cmp.w	(a1),d4				; Is this ring located to the right of the right boundary?
		bhi.s	.NextNewRightRing		; If not, get the next ring
		bra.s	.CheckNewRightSide2		; Start checking

.NextNewRightRing2:
		subq.w	#4,a1				; Previous ring in ring data

.CheckNewRightSide2:
		cmp.w	-4(a1),d4			; Is this ring located to the left of the right boundary?
		bls.s	.NextNewRightRing2		; If not, get the next ring
		move.l	a1,r_Ring_Load_R.w		; Store ending ring data address
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle ring collection
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_RingsManager_DoCollect:
		lea	r_Ring_Col.w,a2			; Ring collection table
		move.w	(a2)+,d1			; Get consumed ring count
		subq.w	#1,d1				; Sutbract 1
		bcs.s	.End				; If there are no consumed rings to handle, branch

.Loop:
		move.w	(a2)+,d0			; Get ring status address
		beq.s	.Loop				; If 0, get the next ring
		movea.w	d0,a1				; Save in a1
		subq.b	#1,(a1)				; Decrement timer
		bne.s	.Next				; If nonzero, branch
		move.b	#6,(a1)				; Reset timer
		addq.b	#1,1(a1)			; Increment frame
							; Is it the last frame?
		cmpi.b	#(CMap_Ring_Sparkle_Last-CMap_Ring)/8,1(a1)
		bne.s	.Next				; If not, branch
		move.w	#-1,(a1)			; Set timer and frame to -1
		clr.w	-2(a2)				; Set address in collection table to 0
		subq.w	#1,r_Ring_Col_Cnt.w		; Decrement collection table count

.Next:
		dbf	d1,.Loop			; Loop

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Set up the tables and load ring data
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_RingsManager_Setup:
		; Clear tables
		clrRAM	r_Ring_Stat
		clrRAM	r_Ring_Col

		movea.l	r_Ring_Pos_Addr.w,a1		; Get ring data pointer
		move.l	a1,r_Ring_Load_L.w		; Store address
		addq.w	#4,a1				; Increment address by 4
		moveq	#0,d5				; Initialize the ring counter
		move.w	#$1FE,d0			; Max number of ring

.GetRingCount:
		tst.l	(a1)+				; Have all the ring been counted?
		bmi.s	.Exit				; If so, branch
		addq.w	#1,d5				; Increment ring counter
		dbf	d0,.GetRingCount		; Loop

.Exit:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Render ring sprites
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_RenderRings:
		movea.l	r_Ring_Load_L.w,a0		; Get starting address of ring data
		move.l	r_Ring_Load_R.w,d2		; Get ending address of ring data
		sub.l	a0,d2				; Get length of the data to read
		beq.s	.End				; If zero length, branch
		movea.w	r_Ring_Stat_Ptr.w,a4		; Get starting address of status table
		lea	CMap_Ring(pc),a1		; Get mappings pointer
		move.w	#224+16,d5			; Get bottom screen boundary
		
.Loop:
		tst.w	(a4)+				; Is this ring collected?
		bmi.s	.Next				; If so, branch
		move.w	2(a0),d1			; Get Y position
		sub.w	cY(a3),d1			; Subtract camera's Y position to get screen position
		addq.w	#8,d1				; Add 8
		cmp.w	d5,d1				; Is it below the bottom of the screen?
		bhs.s	.Next				; If so, branch
		addi.w	#120,d1				; Add 120 to move it within screen space
		move.w	(a0),d0				; Get X position
		sub.w	cX(a3),d0			; Subtract camera's X position to get screen position
		addi.w	#128,d0				; Add 128 to move it within screen space
		moveq	#0,d6
		move.b	-1(a4),d6			; Get frame

.Draw:
		lsl.w	#3,d6				; Turn frame ID into offset
		lea	(a1,d6.w),a2			; Get address of frame map data
		add.w	(a2)+,d1			; Add Y offset
		move.w	d1,(a6)+			; Save Y position
		move.w	(a2)+,d6			; Get sprite size
		move.b	d6,(a6)				; Save it
		addq.w	#2,a6				; Skip link value
		move.w	(a2)+,(a6)+			; Save base tile ID and properites
		add.w	(a2)+,d0			; Add X offset
		move.w	d0,(a6)+			; Save X position
		subq.w	#1,d7				; Decrement the number of sprites left available

.Next:
		addq.w	#4,a0				; Next ring in ring data
		subq.w	#4,d2				; Decrement the ring count
		bne.s	.Loop				; If there are still rings to check, loop

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Custom mappings format.
; Differences include...
;	No offset table (each sprite assumed to be 8 bytes)
;	No 'sprite pieces per frame' value (hardcoded to 1)
;	Sign-extended Y-pos value
;	Sign-extended sprite size value
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
CMap_Ring:
		; Main ring frame
		dc.w	$FFF8
		dc.w	$0005
		dc.w	$0000+$26BC
		dc.w	$FFF8

CMap_Ring_Sparkle:
		; Ring sparkle frame 1
		dc.w	$FFF8
		dc.w	$0005
		dc.w	$0000+$26B8
		dc.w	$FFF8
		; Ring sparkle frame 2
		dc.w	$FFF8
		dc.w	$0005
		dc.w	($0000+$26B8)|$1800
		dc.w	$FFF8
		; Ring sparkle frame 3
		dc.w	$FFF8
		dc.w	$0005
		dc.w	($0000+$26B8)|$800
		dc.w	$FFF8
		; Ring sparkle frame 4
		dc.w	$FFF8
		dc.w	$0005
		dc.w	($0000+$26B8)|$1000
		dc.w	$FFF8
CMap_Ring_Sparkle_Last:
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Do ring collision for the player
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Player_RingCollision:
		cmpi.b	#105,oInvulTime(a0)		; Is the player able to collect rings while hurt?
		bhs.w	.End				; If it hasn't been long enough, branch
		movea.l	r_Ring_Load_L.w,a1		; Get starting address of ring data
		movea.l	r_Ring_Load_R.w,a2		; Get starting address of status table
		cmpa.l	a1,a2				; Are there any rings to test collision with?
		beq.w	.End				; If not, branch
		movea.w	r_Ring_Stat_Ptr.w,a4
		move.w	oX(a0),d2			; Player's X position
		move.w	oY(a0),d3			; Player's Y position
		subq.w	#8,d2				; Subtract 8 from X
		moveq	#0,d5
		move.b	oColH(a0),d5			; Player's collision height
		subq.b	#3,d5				; Subtract 3 from collision height
		sub.w	d5,d3				; Subtract from Y
		move.w	#6,d1
		move.w	#$C,d6
		move.w	#$10,d4				; Width
		add.w	d5,d5				; Double the height

.NextRing:
		tst.w	(a4)				; Is the current ring already consumed?
		bne.s	.GetNext			; If so, get the next ring
		move.w	(a1),d0				; Get ring's X position
		sub.w	d1,d0				; Subtract the player's X from the ring's X
		sub.w	d2,d0				; Check collision
		bcc.s	.ChkCol
		add.w	d6,d0
		bcs.s	.ChkCol2
		bra.w	.GetNext			; If no collision, get the next ring

.ChkCol:
		cmp.w	d4,d0				; Check collision
		bhi.w	.GetNext			; If no collision, get the next ring

.ChkCol2:
		move.w	2(a1),d0			; Do Y collision check
		sub.w	d1,d0
		sub.w	d3,d0
		bcc.s	.ChkCol3
		add.w	d6,d0
		bcs.s	.Collect
		bra.w	.GetNext			; If no collision, get the next ring

.ChkCol3:
		cmp.w	d5,d0
		bhi.w	.GetNext			; If no collision, get the next ring

.Collect:
							; Consume the ring
		move.w	#(6<<8)|((CMap_Ring_Sparkle-CMap_Ring)/8),(a4)
		bsr.s	CollectRing			; Collect it
		lea	r_Ring_Col_List.w,a3		; Get collection list

.Consume:
		tst.w	(a3)+				; Has this slot been used up?
		bne.s	.Consume			; If not, get the next one
		move.w	a4,-(a3)			; Save the status table RAM address for the current ring
		addq.w	#1,r_Ring_Col_Cnt.w		; Add to the number of rings consumed

.GetNext:
		addq.w	#4,a1				; Next ring in ring data
		addq.w	#2,a4				; Next ring in status table
		cmpa.l	a1,a2				; Have we reached the end?
		bne.w	.NextRing			; If not, loop

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Collect a ring
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
CollectRing:
		addq.w	#1,r_Rings.w			; Incremment ring count
		st	r_Update_Rings.w		; Update ring counter in HUD
		playSnd	#sRing, 2			; Play ring sound
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Render the HUD
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_RenderHUD:
		moveq	#0,d6				; Clear render flags
		moveq	#1*2,d4				; Standard frame
		tst.w	r_Rings.w			; Do we have 0 rings?
		bne.s	.Not0Rings			; If not, branch
		btst	#3,(r_Lvl_Frames+1).w		; Can the timer blink?
		bne.s	.Not0Rings			; If not, branch
		moveq	#0*2,d4				; Set frame to blink the timer

.Not0Rings:
		move.w	#$8680,d5			; Tile properties
		
		move.w	#16+128,d0			; X position
		move.w	#8+128,d1			; Y position
		lea	Map_HUD(pc),a1			; Mappings
		adda.w	(a1,d4.w),a1			; Get address of frame
		move.w	(a1)+,d4			; Get number of sprites in the frame
		subq.w	#1,d4				; Subtract 1 from sprite count
		jmp	DrawSprite.w			; Draw the HUD frame
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; HUD mappings
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Map_HUD:	include	"Level/Objects/HUD/Mappings.asm"
		even
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Update the HUD
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	a5.l	- VDP data port
;	a6.l	- VDP control port
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	Nothing
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_UpdateHUD:
		tst.b	r_Update_Rings.w		; Does the ring counter need to be updated?
		beq.s	.End				; If not, branch
		bmi.s	.DontZero			; If the flag is negative, branch
		bsr.w	Level_HUDResetRings		; Reset the ring counter

.DontZero:
		clr.b	r_Update_Rings.w		; Clear update value
		vdpCmd	move.l,$D140,VRAM,WRITE,d0	; Set VDP command
		moveq	#0,d1
		move.w	r_Rings.w,d1			; Ring count
		bra.s	.UpdateRings			; Update the rings counter

.End
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.UpdateRings:
		moveq	#0,d4				; Reset the "draw digit" flag
		lea	HUDMod_100,a2			; Start with the 100s digit
		moveq	#3-1,d6				; Number of digits to draw
		lea	ArtUnc_HUDNumbers(pc),a1	; HUD numbers
		
.LoadDigit_Loop:
		moveq	#0,d2				; Reset the digit
		move.l	(a2)+,d3			; Get the number that's used to calculute what the current digit is
		
.GetDigit:
		sub.l	d3,d1				; Subtract
		bcs.s	.InitDrawDigit			; If it's gone below 0, branch
		addq.w	#1,d2				; Increment digit
		bra.s	.GetDigit			; Loop until the digit is corret

.InitDrawDigit:
		add.l	d3,d1				; Add back
		tst.w	d2				; Is the digit 0?
		beq.s	.DrawDigit			; If so, branch
		st	d4				; Set the "draw digit" flag

.DrawDigit:
		tst.b	d4				; Should we draw the digit?
		beq.s	.NextDigit			; If not, branch
		lsl.w	#6,d2				; Multiply the digit by $40
		move.l	d0,(a6)				; Set the VDP command
		lea	(a1,d2.w),a3			; Get address of the digit art
		rept	16
			move.l	(a3)+,(a5)		; Load the digit art
		endr
		
.NextDigit:
		addi.l	#$400000,d0			; Next digit
		dbf	d6,.LoadDigit_Loop		; Loop
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
HUDMod_100:	dc.l	100
HUDMod_10:	dc.l	10
HUDMod_1:	dc.l	1
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Initialize the HUD
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_InitHUD:
		lea	VDP_CTRL,a6			; VDP data port
		lea	-4(a6),a5			; VDP control port
		
Level_HUDResetRings:
		vdpCmd	move.l,$D140,VRAM,WRITE,(a6)	; Set VDP command
		lea	HUD_RingsBase(pc),a2		; Tile base
		move.w	#3-1,d2				; Length

		lea	ArtUnc_HUDNumbers(pc),a1	; HUD numbers art

.LoadTiles:
		move.b	(a2)+,d0			; Get digit
		ext.w	d0
		lsl.w	#6,d0				; Turn into offset
		lea	(a1,d0.w),a3			; Get address of digit art

		rept	8*2
			move.l	(a3)+,(a5)		; Load art
		endr

		dbf	d2,.LoadTiles			; Loop

		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
HUD_RingsBase:
		dc.b	$A, $A, 0			; Ring count
		even
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; HUD art
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ArtUnc_HUDNumbers:
		incbin	"Level/Objects/HUD/Art - HUD Numbers.unc.bin"
		dcb.l	16, 0
		even
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Animate the level art
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; LEVEL ANIMATION SCRIPTS
;
; The AniArt_DoAnimate subroutine uses these scripts to reload certain tiles,
; thus animating them. All the relevant art must be uncompressed, because
; otherwise the subroutine would spend so much time waiting for the art to be
; decompressed that the VBLANK window would close before all the animating was done.
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
;	zoneanimdecl -1, ArtUnc_Flowers1, ArtTile_ArtUnc_Flowers1, 6, 2
;		-1			Global frame duration. If -1, then each frame will use its own duration, instead
;		ArtUnc_Flowers1		Source address
;		ArtTile_ArtUnc_Flowers1	Destination VRAM address
;		6			Number of frames
;		2			Number of tiles to load into VRAM for each frame
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
;	dc.b   0,$7F			Start of the script proper
;		0			Tile ID of first tile in ArtUnc_Flowers1 to transfer
;		$7F			Frame duration. Only here if global duration is -1
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
AniArt_DoAnimate:
		lea	r_Anim_Cnts.w,a3		; Level art animation counters
		move.w	(a2)+,d6			; Get number of scripts in list
		bpl.s	.ListNotEmpty			; If there are any, continue
		rts

.ListNotEmpty:
.Loop:
		subq.b	#1,(a3)				; Tick down frame duration
		bcc.s	.NextScript			; If frame isn't over, move on to next script

.NextFrame:
		moveq	#0,d0
		move.b	1(a3),d0			; Get current frame
		cmp.b	6(a2),d0			; Have we processed the last frame in the script?
		blo.s	.NotLastFrame			; If not, branch
		moveq	#0,d0				; If so, reset to first frame
		move.b	d0,1(a3)			; ''

.NotLastFrame:
		addq.b	#1,1(a3)			; Consider this frame processed; set counter to next frame
		move.b	(a2),(a3)			; Set frame duration to global duration value
		bpl.s	.GlobalDuration
		add.w	d0,d0				; If script uses per-frame durations, use those instead
		move.b	9(a2,d0.w),(a3)			; Set frame duration to current frame's duration value

.GlobalDuration:
		move.b	8(a2,d0.w),d0			; Get tile ID
		lsl.w	#5,d0				; Turn it into an offset
		move.w	4(a2),d2			; Get VRAM destination address
		move.l	(a2),d1				; Get ROM source address
		andi.l	#$FFFFFF,d1			; ''
		add.l	d0,d1				; Offset into art, to get the address of new frame
		moveq	#0,d3
		move.b	7(a2),d3			; Get size of art to be transferred 
		lsl.w	#4,d3				; Turn it into actual size (in words)
		jsr	QueueDMATransfer.w		; Queue a DMA transfer

.NextScript:
		move.b	6(a2),d0			; Get total size of frame data
		tst.b	(a2)				; Is per-frame duration data present?
		bpl.s	.GlobalDuration2		; If not, keep the current size; it's correct
		add.b	d0,d0				; Double size to account for the additional frame duration data

.GlobalDuration2:
		addq.b	#1,d0
		andi.w	#$FE,d0				; Round to next even address, if it isn't already
		lea	8(a2,d0.w),a2			; Advance to next script in list
		addq.w	#2,a3				; Advance to next script's slot in a3 (usually Anim_Counters)
		dbf	d6,.Loop			; Loop
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Set an object as solid and check for collision
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNING SOLID OBJECT COLLISION BIT FORMAT (For oStatus):
;	XXPXSXAX
;	X	- Unused
;	P	- Pushing flag
;	S	- Standing on flag
;	A	- In air flag (for the player)
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNING SOLID OBJECT COLLISION BIT FORMAT (For d6):
;	XXXTXBXS
;	X	- Unused
;	T	- Touch top flag
;	B	- Touch bottom flag
;	S	- Touch side flag
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	d1.w	- Object width
;	d2.w	- Object height / 2 (when jumping)
;	d3.w	- Object height / 2 (when walking)
;	d4.w	- Object x-axis position
;	a0.l	- Object space pointer
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	See object collision return values above
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SolidObject:
		moveq	#0,d6				; Clear collision flag register
		lea	r_Obj_Player.w,a1		; Set player object RAM
		btst	#cStandBit,oStatus(a0)		; Is the player standing on the current object?
		beq.w	SolidObject_ChkColOnScr		; If not, branch
		move.w	d1,d2				; Copy object width
		add.w	d2,d2				; Double it
		btst	#1,oStatus(a1)			; Is the player in midair?
		bne.s	.NotOnTop			; If so, branch
		move.w	oX(a1),d0			; Get player's X position
		sub.w	oX(a0),d0			; Subtract the current object's X position
		add.w	d1,d0				; Add width
		bmi.s	.NotOnTop			; If not colliding, branch
		cmp.w	d2,d0				; Compare with the width
		bcs.s	.IsOnTop			; If not colliding, branch

.NotOnTop:
		bclr	#cStandBit,oStatus(a1)		; Clear the standing on object bit for the player
		bset	#1,oStatus(a1)			; Make the player be in midair
		bclr	#cStandBit,oStatus(a0)		; Clear the player standing on this object bit
		clr.w	oInteract(a1)			; Clear the player's interact object pointer
		moveq	#0,d4				; Set collision status to 0
		rts

.IsOnTop:
		move.w	d4,d2				; Copy X position to d2
		bsr.w	Player_MoveOnPtfm		; Move the player on top of the current object
		moveq	#0,d4				; Set collision status to 0
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Set an object as solid and check for collision (even if off screen)
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	d1.w	- Object width
;	d2.w	- Object height / 2 (when jumping)
;	d3.w	- Object height / 2 (when walking)
;	d4.w	- Object x-axis position
;	a0.l	- Object space pointer
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	See object collision return values above
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SolidObject_Always:
		moveq	#0,d6				; Clear collision flag register
		lea	r_Obj_Player.w,a1		; Set player object RAM
		btst	#cStandBit,oStatus(a0)		; Is the player standing on the current object?
		beq.w	SolidObject_ChkCollision	; If not, branch
		move.w	d1,d2				; Copy object width
		add.w	d2,d2				; Double it
		btst	#1,oStatus(a1)			; Is the player in midair?
		bne.s	.NotOnTop			; If so, branch
		move.w	oX(a1),d0			; Get player's X position
		sub.w	oX(a0),d0			; Subtract the current object's X position
		add.w	d1,d0				; Add width
		bmi.s	.NotOnTop			; If not colliding, branch
		cmp.w	d2,d0				; Compare with the width
		bcs.s	.IsOnTop			; If not colliding, branch

.NotOnTop:
		bclr	#cStandBit,oStatus(a1)		; Clear the standing on object bit for the player
		bset	#1,oStatus(a1)			; Make the player be in midair
		bclr	#cStandBit,oStatus(a0)		; Clear the player standing on this object bit
		clr.w	oInteract(a1)			; Clear the player's interact object pointer
		moveq	#0,d4				; Set collision status to 0
		rts

.IsOnTop:
		move.w	d4,d2				; Copy X position to d2
		bsr.w	Player_MoveOnPtfm		; Move the player on top of the current object
		moveq	#0,d4				; Set collision status to 0
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Set an object as a solid slope and check for collision
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	d1.w	- Object width
;	d2.w	- Object height / 2 (when jumping)
;	d3.w	- Object height / 2 (when walking)
;	d4.w	- Object x-axis position
;	a0.l	- Object space pointer
;	a2.l	- Slope height data pointer
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	See object collision return values above
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SlopedSolid:
		moveq	#0,d6				; Clear collision flag register
		lea	r_Obj_Player.w,a1		; Set player object RAM
		btst	#cStandBit,oStatus(a0)		; Is the player standing on the current object?
		beq.w	SlopedSolid_ChkCollision	; If not, branch
		move.w	d1,d2				; Copy object width
		add.w	d2,d2				; Double it
		btst	#1,oStatus(a1)			; Is the player in midair?
		bne.s	.NotOnTop			; If so, branch
		move.w	oX(a1),d0			; Get player's X position
		sub.w	oX(a0),d0			; Subtract the current object's X position
		add.w	d1,d0				; Add width
		bmi.s	.NotOnTop			; If not colliding, branch
		cmp.w	d2,d0				; Compare with the width
		bcs.s	.IsOnTop			; If not colliding, branch

.NotOnTop:
		bclr	#cStandBit,oStatus(a1)		; Clear the standing on object bit for the player
		bset	#1,oStatus(a1)			; Make the player be in midair
		bclr	#cStandBit,oStatus(a0)		; Clear the player standing on this object bit
		clr.w	oInteract(a1)			; Clear the player's interact object pointer
		moveq	#0,d4				; Set collision status to 0
		rts

.IsOnTop:
		move.w	d4,d2				; Copy X position to d2
		bsr.w	Player_MoveOnSlope		; Move the player on top of the current object
		moveq	#0,d4				; Set collision status to 0
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SlopedSolid_ChkCollision:
		move.w	oX(a1),d0			; Get player's X position
		sub.w	oX(a0),d0			; Subtract current object's X position
		add.w	d1,d0				; Add width to it
		bmi.w	SolidObject_TestClearPush	; If not colliding, branch
		move.w	d1,d3				; Copy width to d3
		add.w	d3,d3				; Double it
		cmp.w	d3,d0				; Compare to the X position
		bhi.w	SolidObject_TestClearPush	; If not colliding, branch
		move.w	d0,d5				; Copy the X position to d5
		btst	#0,oRender(a0)			; Is the object X-flipped?
		beq.s	.NoFlip				; If not, branch
		not.w	d5				; Logical notation on d5
		add.w	d3,d5				; Add width

.NoFlip:
		lsr.w	#1,d5				; Divide by 2
		move.b	(a2,d5.w),d3			; Get height of this segment
		sub.b	(a2),d3				; Subtract first bytes from the value
		ext.w	d3				; Sign extend to word
		move.w	oY(a0),d5			; Get the current object's Y position
		sub.w	d3,d5				; Subtract the height from the Y position
		move.b	oColH(a1),d3			; Get the player's collision height
		ext.w	d3				; Sign extend to word
		add.w	d3,d2				; Add collision height to the object height
		move.w	oY(a1),d3			; Get the player's Y position
		sub.w	d5,d3				; Subtract d5
		addq.w	#4,d3				; Add 4
		add.w	d2,d3				; Add height and collision height
		bmi.w	SolidObject_TestClearPush	; If not colliding, branch
		move.w	d2,d4				; Copy height and collision height
		add.w	d4,d4				; Double it
		cmp.w	d4,d3				; Compare to Y position
		bcc.w	SolidObject_TestClearPush	; If not colliding, branch
		bra.w	SolidObject_ChkBounds		; If anything else, we are colliding
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SolidObject_ChkColOnScr:
		tst.b	oRender(a0)			; Is the object on screen?
		bpl.w	SolidObject_TestClearPush	; If not, branch

SolidObject_ChkCollision:
		move.w	oX(a1),d0			; Get player's X position
		sub.w	oX(a0),d0			; Subtract the current object's X position
		add.w	d1,d0				; Add width
		move.w	d1,d3				; Copy width
		add.w	d3,d3				; Double it
		cmp.w	d3,d0				; Compare with the X position
		bhi.w	SolidObject_TestClearPush	; If not colliding, branch
		
		move.b	oInitColH(a1),d4		; Get the player's default collision height
		ext.w	d4				; Sign extend to word
		add.w	d2,d4				; Add height
		move.b	oColH(a1),d3			; Get the player's collision height
		ext.w	d3				; Sign extend to word
		add.w	d3,d2				; Add to height
		move.w	oY(a1),d3			; Get player's Y position
		sub.w	oY(a0),d3			; Subtract the current object's Y position
		addq.w	#4,d3				; Add 4
		add.w	d2,d3				; Add height
		andi.w	#$FFF,d3			; Keep in range
		add.w	d2,d4				; Add height
		cmp.w	d4,d3				; Compare with the Y position
		bcc.w	SolidObject_TestClearPush	; If not colliding, branch
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SolidObject_ChkBounds:
		tst.b	oFlags(a1)			; Is the player being carried by another object?
		bmi.w	SolidObject_TestClearPush	; If so, branch
		cmpi.b	#6,oRoutine(a1)			; Is the player dead?
		bcc.w	SolidObject_End			; If so, branch
		tst.b	r_Debug_Mode.w			; Is debug mode active?
		bne.w	SolidObject_End			; If so, branch

		move.w	d0,d5				; Copy X offset
		cmp.w	d0,d1				; Check against the "middle" of the object
		bcc.s	.IsLeft				; If the player is left of the middle, branch
		add.w	d1,d1				; Double collision width
		sub.w	d1,d0				; Subtract from X offset
		move.w	d0,d5				; Copy X offset
		neg.w	d5				; Negate offset

.IsLeft:
		move.w	d3,d1				; Copy Y offset
		cmp.w	d3,d2				; Check against the "middle" of the object
		bcc.s	.IsAbove			; If the player is above of the middle, branch
		subq.w	#4,d3				; Subtract 4 from the collision height
		sub.w	d4,d3				; Subtract height from the collision height
		move.w	d3,d1				; Copy Y offset
		neg.w	d1				; Negate offset

.IsAbove:
		cmp.w	d1,d5
		bhi.w	SolidObject_UpDown		; Branch if we are in the object less vertically than horizontally(?)
		cmpi.w	#4,d1
		bls.w	SolidObject_UpDown		; I assume this ensures the corners are not solid until some point
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SolidObject_Sides:
		tst.w	d0
		beq.s	.AlignPlayer			; Branch if we are in the middle of the object?
		bmi.s	.ChkRight			; Branch if we are right of the object
		tst.w	oXVel(a1)			; Is the player moving left?
		bmi.s	.AlignPlayer			; If so, branch
		bra.s	.ClearGroundVel			; If else player is moving right, branch

.ChkRight:
		tst.w	oXVel(a1)
		bpl.s	.AlignPlayer			; Branch if player is moving right

.ClearGroundVel:
		clr.w	oGVel(a1)			; Stop the player from moving
		clr.w	oXVel(a1)			; Clear the player's X velocity

.AlignPlayer:
		sub.w	d0,oX(a1)			; Align player to the side of the object
		btst	#1,oStatus(a1)			; Is the player in midair?
		bne.s	.InAir				; If so, branch
		bset	#cPushBit,oStatus(a0)		; Set the pushing bit
		bset	#cPushBit,oStatus(a1)		; Set the player's pushing bit
		bset	#cTouchSideBit,d6		; Set "touch side" flag
		moveq	#1,d4				; Set collision status to 1
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.InAir:
		bsr.s	SolidObject_ClearPush		; Clear pushing bits
		bset	#cTouchSideBit,d6		; Set "touch side" flag
		moveq	#1,d4				; Set collision status to 1
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SolidObject_TestClearPush:
		btst	#cPushBit,oStatus(a0)		; Is the player pushing this object?
		beq.s	SolidObject_End			; If not, branch
		cmpi.b	#2,oAni(a1)			; Is the player jumping/rolling?
		beq.s	SolidObject_ClearPush		; If so, branch
		cmpi.b	#$17,oAni(a1)			; Is the player in using the drowning animation
		beq.s	SolidObject_ClearPush		; If so, branch
		cmpi.b	#$1A,oAni(a1)			; Is the player in using the hurt animation
		beq.s	SolidObject_ClearPush		; If so, branch
		move.w	#1,oAni(a1)			; Make the player use the walking animation

SolidObject_ClearPush:
		bclr	#cPushBit,oStatus(a0)		; Clear the pushing bit
		bclr	#cPushBit,oStatus(a1)		; Clear the player's pushing bit

SolidObject_End:
		moveq	#0,d4				; Set collision status to 0
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SolidObject_UpDown:
		tst.w	d3				; Is the player below the middle of the object?
		bmi.s	SolidObject_Below		; If so, branch
		cmpi.w	#$10,d3				; Is the player 16 pixels or less above the middle of the object?
		bcs.s	SolidObject_Above		; If so, branch
		bra.s	SolidObject_TestClearPush	; If not, the player is not colliding
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SolidObject_Below:
		tst.w	oYVel(a1)			; Is the player moving vertically?
		beq.s	.CheckCrush			; If so, branch
		bpl.s	.SetY				; If the player's moving down, branch
		tst.w	d3				; Is the player above the middle of the object?
		bpl.s	.SetY				; If so, branch
		clr.w	oYVel(a1)			; Clear the player's Y velocity

.SetY:
		sub.w	d3,oY(a1)			; Push the player below the object
		bset	#cTouchBtmBit,d6		; Set "touch bottom" flag
		moveq	#-2,d4				; Set the collision status to -2
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.CheckCrush:
		btst	#1,oStatus(a1)			; Is the player in midair?
		bne.s	.SetY				; If so, branch
		move.w	d0,d4				; Get x offset
		bpl.s	.NoNeg				; If it's positive branch
		neg.w	d4				; Negate it (absolute value)

.NoNeg:
		cmpi.w	#$10,d4				; Is the player near the edge of object collision?
		blo.w	SolidObject_Sides		; If so, branch
		
		push.l	a0				; Store the current object's address
		movea.l	a1,a0				; Replace with the player's address
		jsr	ObjSonic_GetKilled		; Kill the player
		pop.l	a0				; Restore the current object's address
		bset	#cTouchBtmBit,d6		; Set "touch bottom" flag
		moveq	#-2,d4				; Set collision status to -2
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SolidObject_Above:
		subq.w	#4,d3				; Get the sub Y offset
		
		; This next bit ensures the player does not collide with the top when next to the walls
		; recalculates object width.

		moveq	#0,d1
		move.b	oColW(a0),d1			; Get the current object's width
		move.w	d1,d2				; Copy it
		add.w	d2,d2				; Double it
		
		add.w	oX(a1),d1			; Add the player's X position
		sub.w	oX(a0),d1			; Subtract the current object's X position
		bmi.s	.NoCollision			; If the player is not colliding, branch
		
		cmp.w	d2,d1				; Is the plauer colliding from the right?
		bcc.s	.NoCollision			; If the player is not colliding, branch
		
		subq.w	#1,oY(a1)			; Subtract 1 from the player's Y position
		sub.w	d3,oY(a1)			; Move the player above the object
		tst.w	oYVel(a1)			; Is the player moving up?
		bmi.s	.NoCollision			; If so, branch
		bsr.w	RideObject_SetRide		; Allow the player to stand on top (and set the "ride" bit)
		bset	#cTouchTopBit,d6		; Set "touch top" flag
		moveq	#-1,d4				; Set collision status to -1
		rts

.NoCollision:
		moveq	#0,d4				; Set collision status to 0
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Set an object as a platform and check for collision
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	d1.w	- Object's width
;	d2.w	- Object's width*2 (only for Platform_ChkBridgeCol)
;	d3.w	- Object's height
;	d4.w	- Object x-axis position
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	See object collision return values above (side and bottom collision doesn't apply here)
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
PlatformObject:
		moveq	#0,d6				; Clear collision flag register
		lea	r_Obj_Player.w,a1		; Get the player RAM
		btst	#cStandBit,oStatus(a0)		; Is the player standing on the object?
		beq.w	Platform_ChkCollision		; If not, branch
		move.w	d1,d2				; Copy the object's width
		add.w	d2,d2				; Double it
		btst	#1,oStatus(a1)			; Is the player in midair?
		bne.s	.NotOnTop			; If so, branch
		move.w	oX(a1),d0			; Get the player's X position
		sub.w	oX(a0),d0			; Subtract the object's X position
		add.w	d1,d0				; Add width
		bmi.s	.NotOnTop			; If the player is not colliding, branch
		cmp.w	d2,d0				; Compare with the width
		blo.s	.OnTop				; If the player is not colliding, branch

.NotOnTop:
		bclr	#cStandBit,oStatus(a1)		; Clear the player's standing on object bit
		bset	#1,oStatus(a1)			; Make the player be in midair
		bclr	#cStandBit,oStatus(a0)		; Clear the player standing on this object bit
		clr.w	oInteract(a1)			; Clear the player's interact object pointer
		moveq	#0,d4				; Set the collision status to 0
		rts

.OnTop:
		move.w	d4,d2				; Copy X position
		bsr.w	Player_MoveOnPtfm		; Make the player stand on top of this object
		moveq	#0,d4				; Set the collision status to 0
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Platform_ChkBridgeCol:
		tst.w	oYVel(a1)			; Is the player moving up?
		bmi.w	PlatformObject_End		; If so, branch
		move.w	oX(a1),d0			; Get the player's X position
		sub.w	oX(a0),d0			; Subtract the object's X position
		add.w	d1,d0				; Add width
		bmi.w	PlatformObject_End		; If the player is not colliding, branch
		cmp.w	d2,d0				; Compare with width
		bcc.w	PlatformObject_End		; If the player is not colliding, branch
		bra.s	Platform_ChkCol_Cont		; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Platform_ChkCollision:
		tst.w	oYVel(a1)			; Is the player moving up?
		bmi.w	PlatformObject_End		; If so, branch
		move.w	oX(a1),d0			; Get the player's X position
		sub.w	oX(a0),d0			; Subtract the object's X position
		add.w	d1,d0				; Add width
		bmi.w	PlatformObject_End		; If the player is not colliding, branch
		add.w	d1,d1				; Double width
		cmp.w	d1,d0				; Compare with width
		bcc.w	PlatformObject_End		; If the player is not colliding, branch

Platform_ChkCol_Cont:
		move.w	oY(a0),d0			; Get the object's Y position
		sub.w	d3,d0				; Subtract the height from it

PlatformObject_ChkYRange:
		move.w	oY(a1),d2			; Get the player's Y position
		move.b	oColH(a1),d1			; Get the player's collision height
		ext.w	d1				; Sign extend it
		add.w	d2,d1				; Add the Y position to the collision height
		addq.w	#4,d1				; Add 4
		sub.w	d1,d0				; Subract the result from the Y position
		bhi.w	PlatformObject_End		; If it's greater than 0, branch
		cmpi.w	#-$10,d0			; Is the result less than -16?
		bcs.w	PlatformObject_End		; If so, branch
		tst.b	r_Debug_Mode.w			; Is debug mode active?
		bne.w	PlatformObject_End		; If so, branch
		tst.b	oFlags(a1)			; Is the player being carried by another object?
		bmi.w	PlatformObject_End		; If so, branch
		cmpi.b	#6,oRoutine(a1)			; Is the player dead?
		bcc.w	PlatformObject_End		; If so, branch
		add.w	d0,d2				; Add the previous result to the Y position
		addq.w	#3,d2				; Add 3
		move.w	d2,oY(a1)			; Add to the player's Y position
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Set the player on top of the object
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Object space pointer
;	a1.l	- Player object space pointer
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	Nothing
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
RideObject_SetRide:
		btst	#cStandBit,oStatus(a1)		; Is the player standing on the object?
		beq.s	.IsStanding			; If not, branch
		movea.w	oInteract(a1),a3		; Get the object the player is standing on
		bclr	#cStandBit,oStatus(a3)		; Clear its standing on object bit
		clr.w	oInteract(a1)			; Clear the player's interact object pointer

.IsStanding:
		move.w	a0,oInteract(a1)		; Set it as the object the player is standing on
		clr.b	oAngle(a1)			; Clear the player's angle
		clr.w	oYVel(a1)			; Clear the player's Y velocity
		move.w	oXVel(a1),oGVel(a1)		; Set the player's X velocity as its ground velocity
		bset	#cStandBit,oStatus(a1)		; Set the player's standing on object bit
		bset	#cStandBit,oStatus(a0)		; Set the player standing on this object bir
		bclr	#1,oStatus(a1)			; Clear the player's in midair bit
		beq.s	PlatformObject_End		; If it was already clear, branch
		move.l	a0,-(sp)			; Store the current object's address
		movea.l	a1,a0				; Replace it with the player's address
		bsr.w	Player_ResetOnFloor		; Reset the player's variables to make it touch the floor
		movea.l	(sp)+,a0			; Restore the current object's address

PlatformObject_End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Set an object as a solid slope and check for collision
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	d1.w	- Object width
;	d3.w	- Object height
;	d4.w	- Object x-axis position
;	a0.l	- Object space pointer
;	a2.l	- Slope height data pointer
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	See object collision return values above (side and bottom collision doesn't apply here)
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SlopedPlatform:
		moveq	#0,d6				; Clear collision flag register
		lea	r_Obj_Player.w,a1		; Get the player RAM
		btst	#cStandBit,oStatus(a0)		; Is the player standing on the object?
		beq.w	SlopedPlarform_ChkCol		; If not branch
		move.w	d1,d2				; Copy the object's width
		add.w	d2,d2				; Double it
		btst	#1,oStatus(a1)			; Is the player in midair?
		bne.s	.NotOnTop			; If so, branch
		move.w	oX(a1),d0			; Get the player's X position
		sub.w	oX(a0),d0			; Subtract the object's X position
		add.w	d1,d0				; Add width
		bmi.s	.NotOnTop			; If the player is not colliding, branch
		cmp.w	d2,d0				; Compare with the width
		blo.s	.OnTop				; If the player is not colliding, branch

.NotOnTop:
		bclr	#cStandBit,oStatus(a1)		; Clear the player's standing on object bit
		bset	#1,oStatus(a1)			; Make the player be in midair
		bclr	#cStandBit,oStatus(a0)		; Clear the player standing on this object bit
		clr.w	oInteract(a1)			; Clear the player's interact object pointer
		moveq	#0,d4				; Set the collision status to 0
		rts

.OnTop:
		move.w	d4,d2				; Copy X position
		bsr.w	Player_MoveOnSlope		; Make the player stand on top of this object
		moveq	#0,d4				; Set the collision status to 0
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
SlopedPlarform_ChkCol:
		tst.w	oYVel(a1)			; Is the player moving up?
		bmi.w	PlatformObject_End		; If so, branch
		move.w	oX(a1),d0			; Get the player's X position
		sub.w	oX(a0),d0			; Subtract the object's X position
		add.w	d1,d0				; Add width
		bmi.w	PlatformObject_End		; If the player is not colliding, branch
		add.w	d1,d1				; Double width
		cmp.w	d1,d0				; Compare with width
		bcc.w	PlatformObject_End		; If the player is not colliding, branch
		btst	#0,oRender(a0)			; Is the object X flipped?
		beq.s	.NoXFlip			; If not, skip
		not.w	d0				; Logical notation
		add.w	d1,d0				; Add width

.NoXFlip:
		lsr.w	#1,d0				; Divide by 2 (by shifting right once)
		move.b	(a2,d0.w),d3			; Get height of the next segment
		ext.w	d3				; Sign extend to word
		move.w	oY(a0),d0			; Get the current object's Y position
		sub.w	d3,d0				; Subtract the height from the Y position
		bra.w	PlatformObject_ChkYRange	; Check the Y range
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Move the player along a platform/solid object
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	d2.w	- X position of the platform
;	d3.w	- Height of the platform
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	Nothing
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Player_MoveOnPtfm:
		move.w	oY(a0),d0			; Get the current object's Y position
		sub.w	d3,d0				; Subtract height
		tst.b	oFlags(a1)			; Is the player being carried by another object?
		bmi.s	.End				; If so, branch
		cmpi.b	#6,oRoutine(a1)			; Is the player dead?
		bcc.s	.End				; If so, branch
		tst.b	r_Debug_Mode.w			; Is debug mode active?
		bne.s	.End				; If so, branch
		moveq	#0,d1
		move.b	oColH(a1),d1			; Get the player's collision height
		sub.w	d1,d0				; Subtract from the Y position
		move.w	d0,oY(a1)			; Set as the player's Y position
		sub.w	oX(a0),d2			; Subtract the current object's X position from the suggest X position
		sub.w	d2,oX(a1)			; Subtract the difference from the X position of the player
		;tst.b	(Shield_Flag).w			; Does the player have a shield?
		;beq.s	.End				; If not branch
		;move.w	d0,(Object_Space_7+oY).w	; Apply to the shield's Y position
		;sub.w	d2,(Object_Space_7+oX).w	; Apply to the shield's X position

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Move the player along a sloped platform/solid object
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	d3.w	- Height of the platform
;	d4.w	- X position of the platform
;	a2.l	- Slope height data pointer
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	Nothing
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Player_MoveOnSlope:
		btst	#cStandBit,oStatus(a1)		; Is the player standing on the object?
		beq.s	.End				; If not, branch
		move.w	oX(a1),d0			; Get the player's X position
		sub.w	oX(a0),d0			; Subtract the current object's X position
		add.w	d1,d0				; Add width
		lsr.w	#1,d0				; Divide by 2 (by shifting right once)
		btst	#0,oRender(a0)			; Is the object X flipped?
		beq.s	.NoXFlip			; If not, branch
		not.w	d0				; Logical notation on d0
		add.w	d1,d0				; Add width

.NoXFlip:
		move.b	(a2,d0.w),d1			; Get Y offset
		ext.w	d1				; Sign extend to word
		move.w	oY(a0),d0			; Get current object's Y position
		sub.w	d1,d0				; Subtract the Y offset
		moveq	#0,d1
		move.b	oColH(a1),d1			; Get the player's collision height
		sub.w	d1,d0				; Subtract from the Y position
		move.w	d0,oY(a1)			; Set as the player's Y position
		sub.w	oX(a0),d2			; Subtract the current object's X position from the suggest X position
		sub.w	d2,oX(a1)			; Subtract the difference from the X position of the player

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Do object collision for the player object
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Player_DoObjCollision:
		jsr	Player_RingCollision		; Do ring collision
		
		move.w	oX(a0),d2			; Get X position
		move.w	oY(a0),d3			; Get Y position
		subq.w	#8,d2				; Get left sensor X
		moveq	#0,d5
		move.b	oColH(a0),d5			; Get collision height
		subq.b	#3,d5				; Subtract 3
		sub.w	d5,d3				; Get left sensor Y
		move.w	#$10,d4				; Get right sensor delta X
		add.w	d5,d5				; Get right sensor delta Y

		lea	r_Col_List.w,a4			; Get collision response list
		move.w	(a4)+,d6			; Get count
		beq.s	.End				; If there are no objects to test, branch

.ObjLoop:
		movea.w	(a4)+,a1			; Get object
		move.b	oColType(a1),d0			; Does touching it do anything?
		bne.s	.ChkPosition			; If so, branch

.NextObj:
		subq.w	#2,d6				; Decrement count
		bne.s	.ObjLoop			; Branch if there are still objects to check
		moveq	#0,d0				; Reset d0

.End:
		clr.w	r_Col_List.w			; Clear the collision response list count
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.ChkPosition:
		moveq	#0,d1
		move.b	oColW(a1),d1			; Get object width
		move.w	oX(a1),d0			; Get object X position
		sub.w	d1,d0				; Get left side of object
		sub.w	d2,d0				; Is the player right of the left side of the object?
		bcc.s	.ChkRightSide			; If so, branch
		add.w	d1,d1				; Get right side delta X
		add.w	d1,d0				; Is the player right of the right side of the object?
		bcs.s	.ChkHeight			; If not, branch
		bra.s	.NextObj			; The player isn't touching the object horizontally; check the next object

.ChkRightSide:
		cmp.w	d4,d0				; Is the player inside the object horizontally?
		bhi.s	.NextObj			; If not, branch

.ChkHeight:
		moveq	#0,d1
		move.b	oColH(a1),d1			; Get object height
		move.w	oY(a1),d0			; Get object Y position
		sub.w	d1,d0				; Get top of object
		sub.w	d3,d0				; Is the player below the top of the object?
		bcc.s	.ChkBottom			; If so, branch
		add.w	d1,d1				; Get bottom delta Y
		add.w	d0,d1				; Is the player below the bottom of the object?
		bcs.s	.ChkType			; If not, branch
		bra.s	.NextObj			; The player isn't touching the object vertically; check the next object

.ChkBottom:
		cmp.w	d5,d0				; Is the player inside the object vertically?
		bhi.s	.NextObj			; If not, branch

.ChkType:
		moveq	#0,d0
		move.b	oColType(a1),d0			; Get collision type
		jmp	.CollisionTypes-2(pc,d0.w)	; Go to the appropriate routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.CollisionTypes:
		bra.s	.Enemy				; Enemy
		bra.s	.Indestructable			; Indestructable
		bra.s	.Monitor			; Monitor
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.Enemy:
		cmpi.b	#2,oAni(a0)			; Are we rolling?
		bne.w	.ChkHurt			; If not, branch

.ChkBoss:
		tst.b	oHitCnt(a1)			; Do we have a hit count?
		beq.s	.Kill				; If not, branch
		neg.w	oXVel(a0)			; Bounce backwards
		neg.w	oYVel(a0)			; ''
		clr.b	oColType(a1)			; Indicate that we have hit the boss
		subq.b	#1,oHitCnt(a1)			; Decrement hit count
		bne.s	.BossEnd			; If it hasn't reached 0, branch
		bset	#7,oStatus(a1)			; Set the "killed" flag

.BossEnd:
		rts

.Kill:
		bset	#7,oStatus(a1)			; Set the "killed" flag
		move.l	#ObjExplosion,oAddr(a1)		; Change into an explosion
		clr.b	oColType(a1)			; Indicate that we have hit the boss
		clr.b	oRoutine(a1)			; Reset the routine ID
		tst.w	oYVel(a0)			; Are we going up?
		bmi.s	.MoveDown			; If so, branch
		move.w	oY(a0),d0			; Are we below the object?
		cmp.w	oY(a1),d0			; ''
		bhs.s	.MoveUp				; If so, branch
		neg.w	oYVel(a0)			; Bounce up
		rts

.MoveDown:
		addi.w	#$100,oYVel(a0)			; Move down
		rts

.MoveUp:
		subi.w	#$100,oYVel(a0)			; Move up
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.Indestructable:
		bra.s	.ChkHurt			; Get hurt
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.Monitor:
		move.w	oYVel(a0),d0			; Get Y velocity
		bpl.s	.ChkDestroy			; If it's falling or staying still, branch
		move.w	oY(a0),d0			; Get player's Y position
		subi.w	#$10,d0				; Subtract 16
		cmp.w	oY(a1),d0			; Is the plyaer hitting the bottom of the object?
		blo.s	.MonitorEnd			; If not, branch
		move.w	#-$180,oYVel(a1)		; Bounce the monitor up
		tst.b	oMonFall(a1)			; Is it already falling?
		bne.s	.MonitorEnd			; If so, branch
		st	oMonFall(a1)			; Set the fall flag
		rts

.ChkDestroy:
		cmpi.b	#2,oAni(a0)			; Are we rolling?
		bne.s	.MonitorEnd			; If not, branch
		neg.w	oYVel(a0)			; Bounce up
		move.l	#ObjMonitor_BreakOpen,oAddr(a1)	; Set to destroyed routine
		
.MonitorEnd:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.ChkHurt:
		tst.w	oInvulTime(a0)			; Are we invulnerable?
		bne.s	.NoHurt				; If so, branch
		movea.l	a1,a2				; Copy harmful object's pointer
		jmp	ObjSonic_GetHurt		; Get hurts

.NoHurt:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Add a new entry to the collision response list
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
AddToColResponse:
		lea	r_Col_List.w,a1			; Get collision response list
		cmpi.w	#$7E,(a1)			; Is it full?
		bhs.s	.End				; If so, branch
		addq.w	#2,(a1)				; Add a new entry
		adda.w	(a1),a1				; Get entry pointer
		move.w	a0,(a1)				; Store entry

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Save some info in a level (mainly for checkpoints)
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Object space pointer
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	Nothing
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_SaveInfo:
		move.w	oX(a0),r_Saved_X_Pos.w		; Save X position
		move.w	oY(a0),r_Saved_Y_Pos.w		; Save Y position
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Load some info in a level (mainly for checkpoints)
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; PARAMETERS:
;	a0.l	- Object space pointer
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; RETURNS:
;	Nothing
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Level_LoadSavedInfo:
		move.w	r_Saved_X_Pos.w,oX(a0)		; Load X position
		move.w	r_Saved_Y_Pos.w,oY(a0)		; Load Y position
		rts
; =========================================================================================================================================================