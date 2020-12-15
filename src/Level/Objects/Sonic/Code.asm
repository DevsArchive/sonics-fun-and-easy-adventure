; =========================================================================================================================================================
; Sonic's Fun And Easy Adventure
; By Ralakimus/Novedicus 2017
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Sonic object
; =========================================================================================================================================================
TOP_SPD		EQU	$600				; Top speed
ACC_SPD		EQU	$C				; Acceleration
DEC_SPD		EQU	$80				; Deceleration
JUMP_HEIGHT	EQU	$680				; Jump height
MIN_JMP_HEIGHT	EQU	$400				; Minimum jump height
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
		rsset	oLvlSSTs
oInitColH	rs.b	1				; Initial collision height
oInitColW	rs.b	1				; Initial collision width
oTopSolid	rs.b	1				; Top solid bit
oLRBSolid	rs.b	1				; LRB solid bit
oTopSpd		rs.w	1				; Top speed
oAcc		rs.w	1				; Acceleration
oDec		rs.w	1				; Deceleration
oFlipDir	rs.w	0				; Flip direction
oGVel		rs.w	1				; Ground velocity
oInteract	rs.w	1				; Interacted object space pointer
oAirTimer	rs.b	1				; Air timer
oMoveLock	rs.b	1				; Move lock timer
oJumping	rs.b	1				; Jumping flag
oAngle		rs.b	1				; Angle
oInvulTime	rs.b	1				; Invulnerability timer
oDeathTimer	rs.b	1				; Death timer
oScrlDelay	rs.b	1				; Look up and down scroll delay counter
oDashFlag	rs.b	1				; Dash flags
oDashTimer	rs.b	1				; Dash timer
oFlipAngle	rs.b	1				; Flip angle about the X axis
oFlipTurned	rs.b	1				; Inverted flip flag
oFlipRemain	rs.b	1				; Remaining flips to do
oFlipSpeed	rs.b	1				; Flip speed
oBallMode	rs.b	1				; Ball mode flag
oHangAniTime	rs.b	1				; Hang animation timer
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic:
		moveq	#0,d0
		move.b	oRoutine(a0),d0			; Get routine ID
		move.w	.Index(pc,d0.w),d0		; Get routine pointer
		jmp	.Index(pc,d0.w)			; Jump to it
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.Index:
		dc.w	ObjSonic_Init-.Index		; Initialization
		dc.w	ObjSonic_Main-.Index		; Main
		dc.w	ObjSonic_Hurt-.Index		; Hurt
		dc.w	ObjSonic_Dead-.Index		; Dead
		dc.w	ObjSonic_Gone-.Index		; Gone
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Initialization routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Init:
		addq.b	#2,oRoutine(a0)			; Next routine
		
		move.b	#9,oColW(a0)			; Collision width
		move.b	#$13,oColH(a0)			; Collision height
		move.b	oColW(a0),oInitColW(a0)		; Set initial collision width
		move.b	oColH(a0),oInitColH(a0)		; Set initial collision height
		move.l	#Map_ObjSonic,oMap(a0)		; Mappings
		move.w	#$780,oVRAM(a0)			; Sprite tile properties
		move.w	#r_Spr_Input+$100,oPrio(a0)	; Priority
		move.b	#$18,oDrawW(a0)			; Sprite width
		move.b	#$18,oDrawH(a0)			; Sprite height
		move.b	#4,oRender(a0)			; Render flags

		move.b	#$C,oTopSolid(a0)		; Top solid bit
		move.b	#$D,oLRBSolid(a0)		; LRB solid bit
		move.b	#$1E,oAirTimer(a0)		; Set air timer
		st	oPrevDPLC(a0)			; Reset saved DPLC frame
		clr.b	oFlipRemain(a0)			; No flips remaining
		move.b	#4,oFlipSpeed(a0)		; Flip speed
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Main routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Main:
		tst.b	r_Move_Cheat.w
		beq.s	.NoPlacementEnter
		btst	#4,r_P1_Press.w			; Has the B button been pressed?
		beq.s	.NoPlacementEnter		; If not, branch
		move.b	#1,r_Debug_Mode.w		; Enable debug placement mode
		move.l	#DebugPlacement,oAddr(a0)	; Set to debug placement mode
		jmp	DisplayObject.w			; Display Sonic's sprite

.NoPlacementEnter:
		btst	#2,oFlags(a0)			; Are the controls locked?
		bne.s	.Update				; If so, branch
		move.w	r_P1_Data.w,r_Ctrl.w		; Set the player's control data

.Update:
		btst	#1,oStatus(a0)
		bne.s	.NotOnGround
		tst.b	r_Boss_Defeat.w
		bne.w	ObjSonic_Seizure

.NotOnGround:
		bsr.w	ObjSonic_Water			; Handle Sonic in water
		bsr.w	ObjSonic_GetPhysics		; Update Sonic's physics
		bsr.w	ObjSonic_DoModes		; Do modes
		bsr.w	ObjSonic_LvlBound		; Handle level boundaries
		jsr	Player_DoObjCollision		; Do object collision
		
		bsr.w	ObjSonic_Animate		; Animate sprite
		bsr.w	ObjSonic_Display		; Display sprite
		bra.w	ObjSonic_LoadDPLCs		; Load DPLCs
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle the extended camera
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_ExtendedCam:
		move.w	r_Cam_X_Center.w,d1		; Get camera X center
		move.w	oGVel(a0),d0			; Get ground velocity
		bpl.s	.PosGVel			; Get absolute value
		neg.w	d0				; ''

.PosGVel:
		cmpi.w	#$600,d0			; Is Sonic going at 6 pixels/frame?
		bcs.s	.ResetXShift			; If not, branch
		tst.w	oGVel(a0)			; Is Sonic moving right?
		bpl.s	.MoveRight			; If so, branch
		addq.w	#2,d1				; Move right
		cmpi.w	#$E0,d1				; Cap it
		bcs.s	.SetShift			; ''
		move.w	#$E0,d1				; ''
		bra.s	.SetShift			; Continue

.MoveRight:
		subq.w	#2,d1				; Move left
		cmpi.w	#$60,d1				; Cap it
		bcc.s	.SetShift			; ''
		move.w	#$60,d1				; ''
		bra.s	.SetShift			; Continue

.ResetXShift:
		cmpi.w	#$A0,d1				; Are we already back at the center?
		beq.s	.SetShift			; If so, branch
		bcc.s	.ReduceShift			; If we have to go back left, branch
		addq.w	#2,d1				; Move back right
		bra.s	.SetShift			; Continue

.ReduceShift:
		subq.w	#2,d1				; Move back left

.SetShift:
		move.w	d1,r_Cam_X_Center.w		; Set camera X center
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Update Sonic's physics
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_GetPhysics:
		moveq	#0,d0
		btst	#6,oStatus(a0)			; Is Sonic underwater?
		beq.s	.GetOffset			; If not, branch
		moveq	#8,d0				; Set the underwater bit

.GetOffset:
		lea	ObjSonic_Physics(pc,d0.w),a1	; Get pointer to correct physics values
		move.l	(a1)+,oTopSpd(a0)		; Set top speed and acceleration
		move.w	(a1),oDec(a0)			; Set deceleration
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Physics values
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; FORMAT:
;	dc.w	TOP SPEED, ACCELERATION, DECELERATION, 0
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Physics:
		dc.w	TOP_SPD,     ACC_SPD,     DEC_SPD,     0; Normal
		dc.w	TOP_SPD/2,   ACC_SPD/2,   DEC_SPD/2,   0; Underwater
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle Sonic in the water
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Water:
	tst.b	r_Water_Flag.w			; Is there water in the level?
	bne.s	.HandleWater			; If so, branch

.End:
	rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.HandleWater:
		move.w	r_Water_Lvl.w,d0		; Get water height
		cmp.w	oY(a0),d0			; Is Lover in the water?
		bge.s	.NotInWater			; If not, branch

		bset	#6,oStatus(a0)			; Set the "in water" flag
		bne.s	.End				; If Lover is already in the water, branch

		asr.w	oXVel(a0)			; Make Lover move slower
		asr.w	oYVel(a0)
		asr.w	oYVel(a0)
		beq.s	.End				; If a splash doesn't need to be created, branch

		playSnd	#sSplash, 2			; Play splash sound
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.NotInWater:
		bclr	#6,oStatus(a0)			; Clear "in water" flag
		beq.s	.End				; If Lover was already out of the water, branch

		cmpi.b	#8,oRoutine(a0)			; Is Lover falling back from getting hurt?
		beq.s	.ChkSplash			; If so, branch
		asl	oYVel(a0)			; Make Lover move faster vertically

.ChkSplash:
		tst.w	oYVel(a0)			; Does a splash need to be created?
		beq.s	.End				; If not, branch

		cmpi.w	#-$1000,oYVel(a0)		; Is Lover moving more than -$10 pixels per frame?
		bgt.s	.PlaySplashSnd			; If not, branch
		move.w	#-$1000,oYVel(a0)		; Cap the speed

.PlaySplashSnd:
		playSnd	#sSplash, 2			; Play splash sound
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Do Sonic's modes
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_DoModes:
		btst	#0,oFlags(a0)			; Is running Sonic's mode disabled?
		bne.s	.NoMode				; If so, branch
		
		moveq	#0,d0
		move.b	oStatus(a0),d0			; Get status
		andi.w	#6,d0				; Only get mode bits
		move.w	ObjSonic_Modes(pc,d0.w),d0	; Get offset
		jsr	ObjSonic_Modes(pc,d0.w)		; Jump to the right routine

		bsr.w	ObjSonic_ExtendedCam		; Handle extended camera
		bsr.w	ObjSonic_ChkBounce		; Check for bouncy floor collision
		bsr.w	ObjSonic_ChkHang		; Check for hanging
		bra.w	ObjSonic_ChkElectric		; Check for electricity

.NoMode:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Sonic's modes
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Modes:
		dc.w	ObjSonic_MdGround-ObjSonic_Modes; Ground
		dc.w	ObjSonic_MdAir-ObjSonic_Modes	; Air
		dc.w	ObjSonic_MdRoll-ObjSonic_Modes	; Roll
		dc.w	ObjSonic_MdJump-ObjSonic_Modes	; Jumping
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Ground mode
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_MdGround:
		bsr.w	ObjSonic_Peelout		; Handle the peelout
		bsr.w	ObjSonic_Spindash		; Handle the spindash
		bsr.w	ObjSonic_ChkJump		; Check for jumping
		bsr.w	ObjSonic_ChkRoll		; Check for rolling
		bsr.w	ObjSonic_MoveGround		; Do movement on the ground
		jsr	ObjectMove.w			; Allow movement
		jsr	Player_AnglePos			; Update position and angle along the ground
		
		bsr.w	ObjSonic_SlopePush		; Affect Sonic's speed on a slope
		bsr.w	ObjSonic_FallOffSlope		; Check if Sonic is going to fall off the slope
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Misc. updates
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_MiscUpdates:
		tst.b	oMoveLock(a0)			; Is the move lock timer finished?
		beq.s	.NoMoveLock			; If so, branch
		subq.b	#1,oMoveLock(a0)		; Decrement the timer

.NoMoveLock:
		jsr	sub_F846
		tst.w	d1
		bmi.w	ObjSonic_GetKilled
		jsr	Player_ChkLeftWallDist		; Check for left wall collision
		tst.w	d1				; Has Sonic entered the wall?
		bpl.s	.ChkRight			; If not, branch
		sub.w	d1,oX(a0)			; Fix Sonic's X position

.ChkRight:
		jsr	Player_ChkRightWallDist		; Check for right wall collision
		tst.w	d1				; Has Sonic entered the wall?
		bpl.s	.End				; If not, branch
		add.w	d1,oX(a0)			; Fix Sonic's X position
		
.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Air and jump modes
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_MdJump:
ObjSonic_MdAir:
		clr.w	oInteract(a0)			; Sonic cannot be interacting with objects while in midair
		bclr	#cStandBit,oStatus(a0)		; ''
		
		btst	#3,oFlags(a0)			; Is Sonic hanging?
		beq.s	.DoModes			; If not, branch
		bsr.w	ObjSonic_Hang			; Hang
		bra.s	.DoCol				; Continue

.DoModes:
		bsr.w	ObjSonic_JumpHeight		; Handle jump height
		bsr.w	ObjSonic_MoveAir		; Do movement
		jsr	ObjectMoveAndFall.w		; Allow movement
		cmpi.w	#$1000,oYVel(a0)		; Is Sonic moving down too fasr?
		ble.s	.NoCap				; If not, branch
		move.w	#$1000,oYVel(a0)		; Cap the downward speed

.NoCap:
		bsr.w	ObjSonic_JumpAngle		; Reset Sonic's angle in mid air

.DoCol:
		btst	#6,oStatus(a0)
		beq.s	.NoWater
		subi.w	#$28,oYVel(a0)

.NoWater:
		jsr	Player_ChkCollision		; Check for level collision
		bra.s	ObjSonic_MiscUpdates
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Roll mode
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_MdRoll:
		tst.b	oBallMode(a0)			; Are we in ball mode?
		bne.s	.NoJump				; If so, branch
		bsr.w	ObjSonic_ChkJump		; Check for jumping

.NoJump:
		bsr.w	ObjSonic_RollSlopePush		; Push Sonic on a slope while rolling
		bsr.w	ObjSonic_MoveRoll		; Do movement
		jsr	ObjectMove.w			; Allow movement
		jsr	Player_AnglePos			; Update position and angle along the ground

		bsr.w	ObjSonic_FallOffSlope		; Check if Sonic is going to fall off the slope
		bra.w	ObjSonic_MiscUpdates		; Do misc. updates
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Do movement on the ground
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_MoveGround:
		move.w	oTopSpd(a0),d6			; Get top speed
		move.w	oAcc(a0),d5			; Get acceleration
		move.w	oDec(a0),d4			; Get deceleration

		tst.b	oMoveLock(a0)			; Is the move lock timer active?
		bne.w	.ResetScr			; If so, branch

		btst	#2,r_Ctrl_Hold.w		; Is left held?
		beq.s	.NotLeft			; If so, branch
		bsr.w	ObjSonic_MoveLeft		; Move left

.NotLeft:
		btst	#3,r_Ctrl_Hold.w		; Is right held?
		beq.s	.NotRight			; If so, branch
		bsr.w	ObjSonic_MoveRight		; Move right

.NotRight:
		move.b	oAngle(a0),d0			; Get angle
		addi.b	#$20,d0				; Shift it
		andi.b	#$C0,d0				; Get quadrant
		bne.w	.ResetScr			; If Sonic is not on the floor, branch
		tst.w	oGVel(a0)			; Has Sonic already been halted?
		bne.w	.ResetScr			; If not, branch

		bclr	#5,oStatus(a0)			; Stop pushing
		move.b	#5,oAni(a0)			; Set to ducking animation

		btst	#cStandBit,oStatus(a0)		; Is Sonic standing on an object?
		beq.w	.ChkBalance			; If not, branch
		movea.w	oInteract(a0),a1		; Get interacted object
		tst.b	oStatus(a1)			; Is Sonic standing on it?
		bmi.s	.ChkLookUp			; If not, branch
		moveq	#0,d1
		move.b	oColW(a1),d1			; Get width of object
		move.w	d1,d2				; Copy it
		add.w	d2,d2				; Double the copy
		subq.w	#4,d2				; Subtract 4 from the copy
		add.w	oX(a0),d1			; Add Sonic's X position
		sub.w	oX(a1),d1			; Subtract the object's X position
		cmpi.w	#4,d1				; Is Sonic balancing on the left side of it?
		blt.s	.BalanceOnObjLeft		; If so, branch
		cmp.w	d2,d1				; Is Sonic balacning on the right side of it?
		bge.s	.BalanceOnObjRight		; If so, branch
		bra.s	.ChkLookUp			; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.ChkBalance:
		jsr	Player_ChkFloorDist		; Get floor distance
		cmpi.w	#$C,d1				; Is Sonic balancing?
		blt.s	.ChkLookUp			; If not, branch
		cmpi.b	#3,oNextTilt(a0)		; Is Sonic balancing on the right side?
		bne.s	.ChkLeftBalance			; If not, branch

.BalanceOnObjRight:
		bclr	#0,oStatus(a0)			; Face right
		bra.s	.SetBalanceAnim			; Set the animation

.ChkLeftBalance:
		cmpi.b	#3,oTilt(a0)			; Is Sonic balancing on the left side?
		bne.s	.ChkLookUp			; If not, branch

.BalanceOnObjLeft:
		bset	#0,oStatus(a0)			; Face left

.SetBalanceAnim:
		move.b	#6,oAni(a0)			; Set balancing animation
		bra.s	.ResetScr			; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.ChkLookUp:
		btst	#0,r_Ctrl_Hold.w		; Is the up button being held?
		beq.s	.ChkDown			; If not, branch
		move.b	#7,oAni(a0)			; Set to looking up animation
		
		addq.b	#1,oScrlDelay(a0)		; Increment scroll delay counter
		cmpi.b	#$78,oScrlDelay(a0)		; Has it reached $78?
		blo.s	.ResetScrPart2			; If not, branch
		move.b	#$78,oScrlDelay(a0)		; Cap at $78
		cmpi.w	#200,r_Cam_Y_Dist.w		; Has the camera finished scrolling?
		beq.s	.UpdateSpdOnGround		; If so, branch
		addq.w	#2,r_Cam_Y_Dist.w		; Scroll the camera
		bra.s	.UpdateSpdOnGround		; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.ChkDown:
		btst	#1,r_Ctrl_Hold.w		; Is the down button being held?
		beq.s	.ResetScr			; If not, branch
		move.b	#8,oAni(a0)			; Set to ducking animation
		
		addq.b	#1,oScrlDelay(a0)		; Increment scroll delay counter
		cmpi.b	#$78,oScrlDelay(a0)		; Has it reached $78?
		blo.s	.ResetScrPart2			; If not, branch
		move.b	#$78,oScrlDelay(a0)		; Cap at $78
		cmpi.w	#8,r_Cam_Y_Dist.w		; Has the camera finished scrolling?
		beq.s	.UpdateSpdOnGround		; If so, branch
		subq.w	#2,r_Cam_Y_Dist.w		; Scroll the camera
		bra.s	.UpdateSpdOnGround		; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.ResetScr:
		clr.b	oScrlDelay(a0)			; Reset scroll delay counter

.ResetScrPart2:
		cmpi.w	#(224/2)-16,r_Cam_Y_Dist.w	; Is the camera centered vertically?
		beq.s	.UpdateSpdOnGround		; If so, branch
		bhs.s	.ScrollUp			; If it's below the center, branch
		addq.w	#4,r_Cam_Y_Dist.w		; Scroll the camera up

.ScrollUp:
		subq.w	#2,r_Cam_Y_Dist.w		; Scroll the camera down
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.UpdateSpdOnGround:
		move.b	r_Ctrl_Hold.w,d0		; Get held buttons
		andi.b	#$C,d0				; Are left or right held?
		bne.s	.ApplySpeed			; If so, branch

		move.w	oGVel(a0),d0			; Get current ground velocity
		beq.s	.ApplySpeed			; If it's already 0, branch
		bmi.s	.SettleLeft			; Settle left if going left

.SettleRight:
		sub.w	d5,d0				; Slow down
		bpl.s	.SetSpeed			; If it's not done, branch
		moveq	#0,d0				; Stop the movement
		bra.s	.SetSpeed			; Continue

.SettleLeft:
		add.w	d5,d0				; Slow down
		bmi.s	.SetSpeed			; If it's not done, branch
		moveq	#0,d0				; Stop the movement

.SetSpeed:
		move.w	d0,oGVel(a0)			; Set ground velocity

.ApplySpeed:
		move.b	oAngle(a0),d0			; Get angle
		jsr	CalcSine.w			; Get the sine and cosine
		muls.w	oGVel(a0),d1			; Multiply cosine with ground velocity
		muls.w	oGVel(a0),d0			; Multiply sine with ground velocity
		asr.l	#8,d1				; Shift the values over
		asr.l	#8,d0				; ''
		move.w	d1,oXVel(a0)			; Set the X velocity
		move.w	d0,oYVel(a0)			; Set the Y velocity

ObjSonic_CheckWalls:
		move.b	oAngle(a0),d0			; Get angle
		andi.b	#$3F,d0				; Is Sonic on an angle?
		beq.s	.Skip				; If not, branch
		move.b	oAngle(a0),d0			; Get angle
		addi.b	#$40,d0				; Is Sonic on an upwards wall or ceiling?
		bmi.s	.End				; If so, branch
		
.Skip:
		moveq	#$40,d1				; If going left, make the modifier $40
		tst.w	oGVel(a0)			; Check speed
		beq.s	.End				; Branch if not moving
		bmi.s	.CheckPush			; Branch if going left
		neg.w	d1				; Negate the modifier

.CheckPush:
		move.b	oAngle(a0),d0			; Get angle
		add.b	d1,d0				; Add modifier
		push.w	d0				; Save it
		jsr	Player_CalcRoomInFront		; Calculate the distance in front of Sonic
		pop.w	d0				; Restore angle
		tst.w	d1				; Is Sonic pushing into anything?
		bpl.s	.End				; If not, branch
		asl.w	#8,d1				; Shift distance inside the collision
		addi.b	#$20,d0				; Add $20 to the angle
		andi.b	#$C0,d0				; Is Sonic pushing on a ceiling?
		beq.s	.PushCeiling			; If so, branch
		cmpi.b	#$40,d0				; Is Sonic pushing on a right wall?
		beq.s	.PushRightWall			; If so, branch
		cmpi.b	#$80,d0				; Is Sonic pushing on a floor?
		beq.s	.PushFloor			; If so, branch
		add.w	d1,oXVel(a0)			; Push out to the right
		clr.w	oGVel(a0)			; Stop moving
		btst	#0,oStatus(a0)			; Is Sonic facing right?
		bne.s	.End				; If not, branch
		bset	#5,oStatus(a0)			; Start pushing
		rts

.PushFloor:
		sub.w	d1,oYVel(a0)			; Push out upwards
		rts

.PushRightWall:
		sub.w	d1,oXVel(a0)			; Push out to the left
		clr.w	oGVel(a0)			; Stop moving
		btst	#0,oStatus(a0)			; Is Sonic facing left?
		beq.s	.End				; If not, branch
		bset	#5,oStatus(a0)			; Start pushing
		rts

.PushCeiling:
		add.w	d1,oYVel(a0)			; Push out downwards

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Move left on the ground
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_MoveLeft:
		move.w	oGVel(a0),d0			; Get current speed
		beq.s	.SetFlip			; If not moving yet, branch
		bpl.s	.Skid				; If moving right, check for skidding

.SetFlip:
		bset	#0,oStatus(a0)			; Set flip flag
		bne.s	.MoveLeft			; If it was already set, branch
		bclr	#5,oStatus(a0)			; Stop pushing
		move.b	#1,oPrevAni(a0)			; Reset the animation

.MoveLeft:
		sub.w	d5,d0				; Subtract acceleration
		move.w	d6,d1				; Get top speed
		neg.w	d1				; Negate it
		cmp.w	d1,d0				; Is Sonic moving faster than the top speed?
		bgt.s	.SetSpeed			; If not, branch
		add.w	d5,d0				; Add acceleration back
		cmp.w	d1,d0				; Is Sonic still moving faster than the top speed?
		ble.s	.SetSpeed			; If not, branch
		move.w	d1,d0				; Cap at the top speed

.SetSpeed:
		move.w	d0,oGVel(a0)			; Set speed
		clr.b	oAni(a0)			; Set animation to moving

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.Skid:
		sub.w	d4,d0				; Subtract deceleration
		moveq	#0,d1				; The speed in which Sonic stops skidding

.Compare:
		cmp.w	d1,d0				; Has Sonic gotten to that speed yet?
		bge.s	.SetSkidSpeed			; If not branch
		moveq	#-$80,d0			; Set speed to -$80

.SetSkidSpeed:
		move.w	d0,oGVel(a0)			; Set speed
		move.b	oAngle(a0),d0			; Get angle
		addi.b	#$20,d0				; Shift it
		andi.b	#$C0,d0				; Is Sonic on a slope?
		bne.s	.End				; If so, branch
		cmpi.w	#$400,d0			; Is Sonic's speed at least 4 pixels per frame?
		blt.s	.End				; If not, branch
		move.b	#$D,oAni(a0)			; Set animation to skidding
		bclr	#0,oStatus(a0)			; Clear flip flag
		playSnd	#sSkid, 2			; Play skid sound
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Move right on the ground
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_MoveRight:
		move.w	oGVel(a0),d0			; Get current speed
		bmi.s	.Skid				; If it's negative, skid
		bclr	#0,oStatus(a0)			; Clear flip flag
		beq.s	.MoveRight			; Branch if it was already cleared
		bclr	#5,oStatus(a0)			; Stop pushing
		move.b	#1,oPrevAni(a0)			; Reset the animation

.MoveRight:
		add.w	d5,d0				; Add acceleration
		cmp.w	d6,d0				; Has Sonic reached the top speed?
		blt.s	.SetSpeed			; If not, branch
		sub.w	d5,d0				; Subtract acceleration back
		cmp.w	d6,d0				; Is Sonic still going at the top speed?
		bge.s	.SetSpeed			; If not, branch
		move.w	d6,d0				; Cap at top speed

.SetSpeed:
		move.w	d0,oGVel(a0)			; Set speed
		clr.b	oAni(a0)			; Set animation to moving

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.Skid:
		add.w	d4,d0				; Add deceleration
		moveq	#0,d1				; The speed in which Sonic stops skidding

.Compare:
		cmp.w	d1,d0				; Has Sonic gotten to that speed yet?
		ble.s	.SetSkidSpeed			; If not, branch
		move.w	#$80,d0				; Set speed to $80

.SetSkidSpeed:
		move.w	d0,oGVel(a0)			; Set speed
		move.b	oAngle(a0),d0			; Get angle
		addi.b	#$20,d0				; Shift it
		andi.b	#$C0,d0				; Is Sonic on a slope?
		bne.s	.End				; If so, branch
		cmpi.w	#-$400,d0			; Is Sonic's speed at least -4 pixels per frame?
		bgt.s	.End				; If not, branch
		move.b	#$D,oAni(a0)			; Set animation to skidding
		bset	#0,oStatus(a0)			; Set flip flag
		playSnd	#sSkid, 2			; Play skid sound
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Do movement while rolling
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_MoveRoll:
		move.w	oTopSpd(a0),d6			; Get top speed
		asl.w	#1,d6				; ''
		move.w	oAcc(a0),d5			; Get acceleration
		asr.w	#1,d5				; ''
		move.w	oDec(a0),d4			; Get deceleration
		asr.w	#2,d4				; ''

		tst.b	oMoveLock(a0)			; Is the move lock timer active?
		bne.w	.UpdateSpd			; If so, branch

		btst	#2,r_Ctrl_Hold.w		; Is left being held?
		beq.s	.ChkRight			; If not, branch
		bsr.w	ObjSonic_RollLeft		; Handle left movement

.ChkRight:
		btst	#3,r_Ctrl_Hold.w		; Is right being held?
		beq.s	.Decelerate			; If not, branch
		bsr.w	ObjSonic_RollRight		; Handle right movement

.Decelerate:
		move.w	oGVel(a0),d0			; Get ground velocity
		beq.s	.ChkStop			; If Sonic isn't moving, branch
		bmi.s	.DecLeft			; If Sonic is moving left, branch

		sub.w	d5,d0				; Decelerate
		bcc.s	.SetGVel			; If Sonic hasn't stopped yet, branch
		moveq	#0,d0				; Cap at 0

.SetGVel:
		move.w	d0,oGVel(a0)			; Set ground velocity
		bra.s	.ChkStop			; Continue

.DecLeft:
		add.w	d5,d0				; Decelerate
		bcc.s	.SetGVel2			; If Sonic hasn't stopped yet, branch
		moveq	#0,d0				; Cap at 0

.SetGVel2:
		move.w	d0,oGVel(a0)			; Set ground velocity

.ChkStop:
		tst.w	oGVel(a0)			; Is Sonic still moving?
		bne.s	.UpdateSpd			; If so, branch
		
		tst.b	oBallMode(a0)			; Are we in ball mode?
		bne.s	.KeepRoll			; If so, branch
		bclr	#2,oStatus(a0)			; Stop rolling
		move.b	oInitColH(a0),oColH(a0)		; Reset collision height
		move.b	oInitColW(a0),oColW(a0)		; Reset collision width
		move.b	#5,oAni(a0)			; Use standing animation
		subq.w	#5,oY(a0)			; Align Sonic with the ground
		bra.s	.UpdateSpd			; Continue

.KeepRoll:
		move.w	#$400,oGVel(a0)			; Speed up again
		btst	#0,oStatus(a0)			; Are we facing right?
		beq.s	.UpdateSpd			; If so, branch
		neg.w	oGVel(a0)			; Go the other way

.UpdateSpd:
		move.b	oAngle(a0),d0			; Get angle
		jsr	CalcSine.w			; Get sine and cosine
		muls.w	oGVel(a0),d0			; Multiply sine with ground velocity
		asr.l	#8,d0				; Shift over
		move.w	d0,oYVel(a0)			; Set Y velocity
		muls.w	oGVel(a0),d1			; Multiply cosine with ground velocity
		asr.l	#8,d1				; Shift over

		cmpi.w	#$1000,d1			; Is the speed > $10 pixels per frame?
		ble.s	.ChkLeftSpd			; If not, branch
		move.w	#$1000,d1			; Cap the speed

.ChkLeftSpd:
		cmpi.w	#-$1000,d1			; Is the speed < -$10 pixels per frame?
		bge.s	.SetXVel			; If not, branch
		move.w	#-$1000,d1			; Cap the speed

.SetXVel:
		move.w	d1,oXVel(a0)			; Set X velocity
		bra.w	ObjSonic_CheckWalls		; Check wall collision
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle left movement for rolling
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_RollLeft:
		move.w	oGVel(a0),d0			; Get ground velocity
		beq.s	.SetLeft			; If Sonic isn't moving, branch
		bpl.s	.Dec				; If Sonic is moving right, branch

.SetLeft:
		bset	#0,oStatus(a0)			; Face left
		move.b	#2,oAni(a0)			; Use rolling animation
		rts

.Dec:
		sub.w	d4,d0				; Decelerate
		bcc.s	.SetGVel			; If Sonic hasn't stopped yet, branch
		move.w	#-$80,d0			; Set new speed

.SetGVel:
		move.w	d0,oGVel(a0)			; Set ground velocity
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle left movement for rolling
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_RollRight:
		move.w	oGVel(a0),d0			; Get ground velocity
		bmi.s	.Dec				; If Sonic is moving left, branch
		bclr	#0,oStatus(a0)			; Face right
		move.b	#2,oAni(a0)			; Use rolling animation
		rts

.Dec:
		add.w	d4,d0				; Decelerate
		bcc.s	.SetGVel			; If Sonic hasn't stopped yet, branch
		move.w	#$80,d0				; Set new speed

.SetGVel:
		move.w	d0,oGVel(a0)			; Set ground velocity
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Do movement in the air
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_MoveAir:
		move.w	oTopSpd(a0),d6			; Get top speed
		move.w	oAcc(a0),d5			; Get accleration
		add.w	d5,d5				; Double it
		move.w	oXVel(a0),d0			; Get X velocity

		btst	#2,r_Ctrl_Hold.w		; Is left being held?
		beq.s	.NotLeft			; If not, branch
		bset	#0,oStatus(a0)			; Face left
		sub.w	d5,d0				; Subtract acceleration
		move.w	d6,d1				; Get top speed
		neg.w	d1				; Negate it
		cmp.w	d1,d0				; Has Sonic reached the top speed?
		bgt.s	.NotLeft			; If not, branch
		add.w	d5,d0				; Add acceleration back
		cmp.w	d1,d0				; Is Sonic still at top speed?
		ble.s	.NotLeft			; If not, branch
		move.w	d1,d0				; Cap at top speed	

.NotLeft:
		btst	#3,r_Ctrl_Hold.w		; Is right being held?
		beq.s	.NotRight			; If not, branch
		bclr	#0,oStatus(a0)			; Face right
		add.w	d5,d0				; Add acceleration
		cmp.w	d6,d0				; Has Sonic reached the top speed?
		blt.s	.NotRight			; If not, branch
		sub.w	d5,d0				; Subtract acceleration back
		cmp.w	d6,d0				; Is Sonic still at top speed?
		bge.s	.NotRight			; If not, branch
		move.w	d6,d0				; Cap at top speed

.NotRight:
		move.w	d0,oXVel(a0)			; Set X velocity

.ResetScr
		cmpi.w	#(224/2)-16,r_Cam_Y_Dist.w	; Is the camera centered vertically?
		beq.s	.DecelerateAtPeak		; If so, branch
		bhs.s	.ScrollUp			; If it's below the center, branch
		addq.w	#4,r_Cam_Y_Dist.w		; Scroll the camera up

.ScrollUp:
		subq.w	#2,r_Cam_Y_Dist.w		; Scroll the camera down

.DecelerateAtPeak:
		cmpi.w	#-$400,oYVel(a0)		; Is Sonic at least going -4 pixels per frame up?
		bcs.s	.End				; If not, branch
		move.w	oXVel(a0),d0			; Get X velocity
		move.w	d0,d1				; Save it
		asr.w	#5,d1				; Turn it into the acceleration
		beq.s	.End				; If it's 0, branch
		bmi.s	.DecLeft			; If it's negative, branch

.DecRight:
		sub.w	d1,d0				; Subtract accleration
		bcc.s	.DecSetSpeed			; If it's not negative, branch
		moveq	#0,d0				; Cap at 0
		bra.s	.DecSetSpeed			; Continue

.DecLeft:
		sub.w	d1,d0				; Subtract acceleration
		bcs.s	.DecSetSpeed			; If it's not positive, branch
		moveq	#0,d0				; Cap at 0

.DecSetSpeed:
		move.w	d0,oXVel(a0)			; Set thhe X velocity

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle level boundaries
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_LvlBound:
		tst.w	oYVel(a0)
		bpl.s	.XBound
		move.w	oY(a0),d1
		addi.w	#$10,d1
		move.w	r_Min_Cam_Y.w,d0		; Get upper boundary position
		cmp.w	d1,d0				; Has Sonic touched the upper boundary?
		ble.s	.XBound				; If so, branch
		move.w	d0,oY(a0)
		clr.w	oYVel(a0)
		clr.w	oGVel(a0)

.XBound:
		move.l	oX(a0),d1			; Get X position
		move.w	oXVel(a0),d0			; Get X velocity
		ext.l	d0
		asl.l	#8,d0				; Shift it
		add.l	d0,d1				; Add to X position
		swap	d1				; Get actual X position
		move.w	r_Min_Cam_X.w,d0		; Get left boundary position
		addi.w	#$10,d0				; ''
		cmp.w	d1,d0				; Has Sonic touched the left boundary?
		bgt.s	.TouchedSide			; If so, branch
		move.w	r_Max_Cam_X.w,d0		; Get max camera X position
		addi.w	#320-24,d0			; Get right boundary position
		cmp.w	d1,d0				; Has Sonic touched the right boundary?
		ble.s	.TouchedSide			; If so, branch

.ChkBottom:
		move.w	r_Max_Cam_Y.w,d0		; Get max camera Y position
		addi.w	#224,d0				; Get bottom boundary position
		cmp.w	oY(a0),d0			; Has Sonic touched the bottom boundary?
		blt.s	.TouchedBottom			; If so, branch
		rts

.TouchedBottom:
		move.w	r_Dest_Max_Y.w,d0		; Get target max camera Y position
		move.w	r_Max_Cam_Y.w,d1		; Get current max camera Y position
		cmp.w	d0,d1				; Are they the same?
		blt.s	.NoKill				; If not, branch
		bra.w	ObjSonic_GetKilled		; Get Sonic killed

.NoKill:
		rts

.TouchedSide:
		clr.w	oXVel(a0)			; Stop X movement
		move.w	d0,oX(a0)			; Move Sonic out of the boundary
		clr.w	oX+2(a0)			; Clear the subpixel of the X position
		clr.w	oGVel(a0)			; Stop ground movement
		bra.s	.ChkBottom			; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle peelout
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Peelout:
		tst.b	oDashFlag(a0)			; Is Sonic doing the peelout?
		beq.s	.ChkUp				; If not, branch
		bmi.s	.ChkLaunch			; If so, branch
		rts

.ChkUp:
		cmpi.b	#7,oAni(a0)			; Is Sonic looking up?
		bne.w	.End				; If not, branch
		move.b	r_Ctrl_Press.w,d0		; Get controller bits
		andi.b	#$70,d0				; Are A, B, or C pressed?
		beq.w	.End				; If not, branch
		
		clr.b	oAni(a0)			; Set to peelout charge animation
		clr.b	oDashTimer(a0)			; Reset the dash timer
		move.w	#$C,oGVel(a0)			; Reset ground velocity
		btst	#0,oStatus(a0)			; Is Sonic facing left?
		beq.s	.SetAni				; If so, branch
		neg.w	oGVel(a0)			; Go the other way

.SetAni:
		playSnd	#sCharge, 2			; Play charge sound
		
		addq.l	#4,sp				; Don't return to caller
		st	oDashFlag(a0)			; Set the peelout flag
		jmp	Player_AnglePos			; Update position and angle along the ground
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.ChkLaunch:
		btst	#0,r_Ctrl_Hold.w		; Is up being held?
		bne.w	.Charge				; If so, branch
		clr.b	oDashFlag(a0)			; Clear the dash flag

		cmpi.b	#30,oDashTimer(a0)		; Has Sonic charged up enough?
		bne.s	.StopSound			; If not, branch

		clr.b	oAni(a0)			; Reset animation
		move.w	#$C00,oGVel(a0)			; Set ground velocity
		btst	#6,oStatus(a0)
		beq.s	.NoWater
		lsr.w	oGVel(a0)

.NoWater:
		btst	#0,oStatus(a0)			; Is Sonic facing left?
		beq.s	.FinishDash			; If not, branch
		neg.w	oGVel(a0)			; Go the other way

.FinishDash:
		playSnd	#sChargeRelease, 2		; Play charge release sound
		
		bra.s	.DoUpdates			; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.Charge:
		cmpi.b	#30,oDashTimer(a0)		; Has Sonic charged enough?
		beq.s	.DoUpdates			; If so, branch
		addq.b	#1,oDashTimer(a0)		; Increment the timer
		addi.w	#$66,oGVel(a0)			; Increment ground velocity to handle animation and extended camera
		btst	#0,oStatus(a0)			; Is Sonic facing left?
		beq.s	.DoUpdates			; If so, branch
		subi.w	#$66*2,oGVel(a0)		; Go the other way
		bra.s	.DoUpdates			; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.StopSound:
		clr.w	oGVel(a0)			; Stop ground movement
		
		playSnd	#sChargeStop, 2			; Play charge stop sound
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.DoUpdates:
		addq.l	#4,sp				; Don't return to caller
		cmpi.w	#(224/2)-16,r_Cam_Y_Dist.w	; Is the camera centered vertically?
		beq.s	.FinishUpdates			; If so, branch
		bhs.s	.ScrollUp			; If it's below the center, branch
		addq.w	#4,r_Cam_Y_Dist.w		; Scroll the camera up

.ScrollUp:
		subq.w	#2,r_Cam_Y_Dist.w		; Scroll the camera down

.FinishUpdates:
		jmp	Player_AnglePos			; Update position and angle along the ground

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle spindash
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Spindash:
		tst.b	oDashFlag(a0)			; Is Sonic doing the spindash?
		beq.s	.ChkDown			; If not, branch
		bpl.s	.ChkLaunch			; If so, branch
		rts

.ChkDown:
		cmpi.b	#8,oAni(a0)			; Is Sonic ducking?
		bne.w	.End				; If not, branch
		move.b	r_Ctrl_Press.w,d0		; Get controller bits
		andi.b	#$70,d0				; Are A, B, or C pressed?
		beq.w	.End				; If not, branch
		
		clr.b	oDashTimer(a0)			; Reset the dash timer
		move.w	#$C,oGVel(a0)			; Reset ground velocity
		btst	#0,oStatus(a0)			; Is Sonic facing left?
		beq.s	.SetAni				; If so, branch
		neg.w	oGVel(a0)			; Go the other way

.SetAni:
		move.b	#$E,oColH(a0)			; Reduce Sonic's hitbox
		move.b	#7,oColW(a0)			; ''
		addq.w	#5,oY(a0)			; Align Sonic to the ground
		move.b	#2,oAni(a0)			; Set to spin animation

		playSnd	#sCharge, 2			; Play charge sound
		
		addq.l	#4,sp				; Don't return to caller
		move.b	#1,oDashFlag(a0)		; Set the spindash flag
		jmp	Player_AnglePos			; Update position and angle along the ground
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.ChkLaunch:
		btst	#1,r_Ctrl_Hold.w		; Is down being held?
		bne.w	.Charge				; If so, branch
		clr.b	oDashFlag(a0)			; Clear the dash flag

		cmpi.b	#45,oDashTimer(a0)		; Has Sonic charged up enough?
		bne.s	.StopSound			; If not, branch

		bset	#2,oStatus(a0)			; Set the roll flag
		move.w	#$C00,oGVel(a0)			; Set ground velocity
		btst	#6,oStatus(a0)
		beq.s	.NoWater
		lsr.w	oGVel(a0)

.NoWater:
		btst	#0,oStatus(a0)			; Is Sonic facing left?
		beq.s	.FinishDash			; If not, branch
		neg.w	oGVel(a0)			; Go the other way

.FinishDash:
		playSnd	#sChargeRelease, 2		; Play charge release sound
		
		bra.s	.DoUpdates			; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.Charge:
		cmpi.b	#45,oDashTimer(a0)		; Has Sonic charged enough?
		beq.s	.DoUpdates			; If so, branch
		addq.b	#1,oDashTimer(a0)		; Increment the timer
		addi.w	#$46,oGVel(a0)			; Increment ground velocity to handle animation and extended camera
		btst	#0,oStatus(a0)			; Is Sonic facing left?
		beq.s	.DoUpdates			; If so, branch
		subi.w	#$46*2,oGVel(a0)		; Go the other way
		bra.s	.DoUpdates			; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.StopSound:
		clr.w	oGVel(a0)			; Stop ground movement
		move.b	oInitColH(a0),oColH(a0)		; Reset collision height
		move.b	oInitColW(a0),oColW(a0)		; Reset collision width
		subq.w	#5,oY(a0)			; Align Sonic with the ground

		playSnd	#sChargeStop, 2			; Play charge stop sound
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.DoUpdates:
		addq.l	#4,sp				; Don't return to caller
		cmpi.w	#(224/2)-16,r_Cam_Y_Dist.w	; Is the camera centered vertically?
		beq.s	.FinishUpdates			; If so, branch
		bhs.s	.ScrollUp			; If it's below the center, branch
		addq.w	#4,r_Cam_Y_Dist.w		; Scroll the camera up

.ScrollUp:
		subq.w	#2,r_Cam_Y_Dist.w		; Scroll the camera down

.FinishUpdates:
		jmp	Player_AnglePos			; Update position and angle along the ground

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Check for jumping
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_ChkJump:
		move.b	r_Ctrl_Press.w,d0		; Get pressed buttons
		andi.b	#$70,d0				; Are A, B, or C pressed?
		tst.b	r_Move_Cheat.w
		beq.s	.NoDebug
		andi.b	#$60,d0				; Are A or C pressed?

.NoDebug:
		tst.b	d0
		beq.w	.End				; If not, branch
		
		moveq	#0,d0
		move.b	oAngle(a0),d0			; Get angle
		addi.b	#$80,d0				; Shift it to check the ceiling
		jsr	Player_CalcRoomOverHead		; Get room over Sonic's head
		cmpi.w	#6,d1				; Is it at least 6 pixels?
		blt.w	.End				; If not, branch

		move.w	#JUMP_HEIGHT,d2			; Standard jump height
		btst	#6,oStatus(a0)
		beq.s	.NoWater
		subi.w	#$300,d2

.NoWater:
		moveq	#0,d0
		move.b	oAngle(a0),d0			; Get angle
		subi.b	#$40,d0				; Shift it
		jsr	CalcSine.w			; Get the sine and cosine
		muls.w	d2,d1				; Mutliply cosine with jump height
		muls.w	d2,d0				; Mutliply sine with jump height
		asr.l	#8,d1				; Shift the values over
		asr.l	#8,d0				; ''
		add.w	d1,oXVel(a0)			; Add to X velocity
		add.w	d0,oYVel(a0)			; Add to Y velocity
		ori.b	#6,oStatus(a0)			; Set "in air" and roll flags
		bclr	#5,oStatus(a0)			; Clear "pushing" flag
		addq.w	#4,sp				; Do not return to collaer
		st	oJumping(a0)			; Set the jumping flag
		playSnd	#sLeap, 2			; Play jump sound
		move.b	#$E,oColH(a0)			; Reduce Sonic's hitbox
		move.b	#7,oColW(a0)			; ''
		addq.w	#5,oY(a0)			; Align Sonic to the ground
		move.b	#2,oAni(a0)			; Set jumping animation

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle variable jumping
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_JumpHeight:
		tst.b	oJumping(a0)			; Is Sonic jumping?
		beq.s	.UpVelCap			; If not, branch

		move.w	#-MIN_JMP_HEIGHT,d1		; Standard minimum height
		cmp.w	oYVel(a0),d1			; Is Sonic jumping at least hte minimum height?
		ble.s	.End				; If not, branch
		move.b	r_Ctrl_Hold.w,d0		; Get held buttons
		andi.b	#$70,d0				; Are A, B, or C pressed?
		tst.b	r_Move_Cheat.w
		beq.s	.NoDebug
		andi.b	#$60,d0				; Are A or C pressed?

.NoDebug:
		tst.b	d0
		bne.s	.End				; If not, branch
		move.w	d1,oYVel(a0)			; Set to minimum height

.End:
		rts

.UpVelCap:
		tst.b	oBallMode(a0)			; Are we in ball mode?
		bne.s	.End				; If so, branch
		cmpi.w	#-$FC0,oYVel(a0)		; Cap Y velocity at -$FC0 when going up
		bge.s	.End				; ''
		move.w	#-$FC0,oYVel(a0)		; ''
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Gradually reset Sonic's angle in mid air
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_JumpAngle:
		move.b	oAngle(a0),d0			; Get angle
		beq.s	ObjSonic_JumpFlip		; If it's already reset, branch
		bpl.s	.Decrease			; If it's positive, branch

.Increase:
		addq.b	#2,d0				; Increase angle
		bmi.s	.SetAngle			; If it's not reset, branch
		moveq	#0,d0				; Reset the angle
		bra.s	.SetAngle

.Decrease:
		subq.b	#2,d0				; Decrease angle
		bpl.s	.SetAngle			; If it's not reset, branch
		moveq	#0,d0				; Reset the angle

.SetAngle:
		move.b	d0,oAngle(a0)			; Set the new angle
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Update Sonic's angle while he's tumbling in the air
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_JumpFlip:
		move.b	oFlipAngle(a0),d0		; Get flip angle
		beq.s	.End				; If it's 0, branch
		tst.w	oFlipDir(a0)			; Is Sonic flipping left?
		bmi.s	.FlipLeft			; IF so, branch

.FlipRight:
		move.b	oFlipSpeed(a0),d1		; Get flip speed
		add.b	d1,d0				; Add to angle
		bcc.s	.FlipSet			; If it hasn't wrapped over, branch
		subq.b	#1,oFlipRemain(a0)		; Decrement flips remaining
		bcc.s	.FlipSet			; If there are still some left
		clr.b	oFlipRemain(a0)			; Clear flips remaining
		moveq	#0,d0				; Reset angle
		bra.s	.FlipSet			; Continue

.FlipLeft:
		tst.b	oFlipTurned(a0)			; Is the flipping inverted?
		bne.s	.FlipRight			; If so, branch
		move.b	oFlipSpeed(a0),d1		; Get flip speed
		sub.b	d1,d0				; Subtract from angle
		bcc.s	.FlipSet			; If it hasn't wrapped over, branch
		subq.b	#1,oFlipRemain(a0)		; Decrement flips remaining
		bcc.s	.FlipSet			; If there are still some left
		clr.b	oFlipRemain(a0)			; Clear flips remaining
		moveq	#0,d0				; Reset angle

.FlipSet:
		move.b	d0,oFlipAngle(a0)		; Update the angle

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Check for rolling
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_ChkRoll:
		move.w	oGVel(a0),d0			; Get ground velocity
		bpl.s	.ChkSpd				; Get absolute value
		neg.w	d0				; ''

.ChkSpd:
		cmpi.w	#$80,d0				; Is Sonic going fast enough?
		bcs.s	.NoRoll				; If not, branch
		move.b	r_Ctrl_Hold.w,d0		; Get held buttons
		andi.b	#$C,d0				; Are left or right held?
		bne.s	.NoRoll				; If not, branch
		btst	#1,r_Ctrl_Hold.w		; Is down being held?
		bne.s	ObjSonic_DoRoll			; If so, branch

.NoRoll:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Make Sonic roll
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_DoRoll:
		btst	#2,oStatus(a0)			; Is Sonic already rolling?
		bne.s	.End				; If so, branch
		bset	#2,oStatus(a0)			; Set roll flag
		
		move.b	#$E,oColH(a0)			; Reduce Sonic's hitbox
		move.b	#7,oColW(a0)			; ''
		addq.w	#5,oY(a0)			; Align Sonic to the ground
		move.b	#2,oAni(a0)			; Set rolling animation

		tst.w	oGVel(a0)			; Is Sonic moving already?
		bne.s	.End				; IF not, branch
		move.w	#$200,oGVel(a0)			; Set speed

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Slow Sonic down as he goes up a slope or speed him up when he does down one
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_SlopePush:
		move.b	oAngle(a0),d0			; Get angle
		addi.b	#$60,d0				; Shift it
		cmpi.b	#$C0,d0				; Is Sonic on a steep slope or ceiling?
		bcc.s	.End				; If not, branch
		move.b	oAngle(a0),d0			; Get angle
		jsr	CalcSine.w			; Get the sine of it
		muls.w	#$20,d0				; Multiple it by $20
		asr.l	#8,d0				; Shift it
		tst.w	oGVel(a0)			; Check speed
		beq.s	.End				; If Sonic is not moving, branch
		add.w	d0,oGVel(a0)			; Add to ground velocity

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Check if Sonic is to fall off a slope
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_FallOffSlope:
		tst.b	oMoveLock(a0)			; Is the move lock timer, active?
		bne.s	.End				; If so, branch
		move.b	oAngle(a0),d0			; Get angle
		addi.b	#$20,d0				; Shift it
		andi.b	#$C0,d0				; Get quadrant
		beq.s	.End				; If Sonic is on the floor, branch
		move.w	oGVel(a0),d0			; Get speed
		bpl.s	.ChkSpeed			; If it's already positive, branch
		neg.w	d0				; Force it to be positive

.ChkSpeed:
		cmpi.w	#$280,d0			; Is Sonic going at least 2.5 pixels per frame?
		bcc.s	.End				; If so, branch
		clr.w	oGVel(a0)			; Stop movement
		bset	#1,oStatus(a0)			; Set "in air" flag
		move.b	#$1E,oMoveLock(a0)		; Set move lock timer

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Affect Sonic's speed on slopes while rolling
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_RollSlopePush:
		move.b	oAngle(a0),d0			; Get angle
		addi.b	#$60,d0				; ''
		cmpi.b	#$C0,d0				; Is Sonic on a steep enough slope?
		bcc.s	.End				; If not, branch

		move.b	oAngle(a0),d0			; Get angle
		jsr	CalcSine.w			; Get sine
		muls.w	#$50,d0				; Multiply sine by $50
		asr.l	#8,d0				; Shift over
		
		tst.w	oGVel(a0)			; Is Sonic moving right?
		bmi.s	.PushLeft			; If not, branch
		tst.w	d0				; Is the push speed positive?
		bpl.s	.Push				; If so, branch
		asr.l	#2,d0				; Shift over more

.Push:
		add.w	d0,oGVel(a0)			; Add push speed
		rts

.PushLeft:
		tst.w	d0				; Is the push speed negative?
		bmi.s	.Push2				; If so, branch
		asr.l	#2,d0				; Shift over more

.Push2:
		add.w	d0,oGVel(a0)			; Add push speed

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Check for bouncy floor collision
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_ChkBounce:
		tst.b	r_Floor_Active.w		; Is the floor active?
		beq.w	.End				; If so, branch

		btst	#1,oStatus(a0)			; Is Sonic in the air?
		beq.s	.ChkDown			; If not, branch

		tst.w	oYVel(a0)			; Is Sonic falling?
		beq.w	.ChkBounceUp			; If not, branch
		bmi.w	.ChkBounceUp			; ''

.ChkDown:
		move.w	oY(a0),d2			; Get Y of left sensor
		move.b	oColH(a0),d0			; ''
		ext.w	d0				; ''
		add.w	d0,d2				; ''
		addq.w	#2,d2				; ''
		move.w	oX(a0),d3			; Get X of left sensor
		move.b	oColW(a0),d0			; ''
		ext.w	d0				; ''
		sub.w	d0,d3				; ''
		jsr	Level_FindBlock			; Get the block located there
		move.w	(a1),d0				; ''
		andi.w	#$3FF,d0			; ''
		cmpi.w	#$80,d0				; Is the block the bouncy floor?
		beq.s	.Bounce				; If so, branch

		move.w	oY(a0),d2			; Get Y of right sensor
		move.b	oColH(a0),d0			; ''
		ext.w	d0				; ''
		add.w	d0,d2				; ''
		addq.w	#2,d2				; ''
		move.w	oX(a0),d3			; Get X of right sensor
		move.b	oColW(a0),d0			; ''
		ext.w	d0				; ''
		add.w	d0,d3				; ''
		jsr	Level_FindBlock			; Get the block located there
		move.w	(a1),d0				; ''
		andi.w	#$3FF,d0			; ''
		cmpi.w	#$80,d0				; Is the block the bouncy floor?
		bne.s	.End				; If not, branch

.Bounce:
		move.w	#-$1600,oYVel(a0)		; Bounce Sonic up
		bset	#1,oStatus(a0)			; Set in air flag
		clr.b	oJumping(a0)			; Clear jump flag
		clr.b	oDashTimer(a0)			; Reset dash timer
		clr.b	oDashFlag(a0)			; Reset dash flag

		playSnd	#sFloorBounce, 2		; Play the floor bounce sound

		btst	#2,oStatus(a0)			; Is Sonic already rolling?
		bne.s	.End				; If so, branch
		bset	#2,oStatus(a0)			; Set roll flag
		move.b	#$E,oColH(a0)			; Reduce Sonic's hitbox
		move.b	#7,oColW(a0)			; ''
		addq.w	#5,oY(a0)			; Align Sonic to the ground
		move.b	#2,oAni(a0)			; Set rolling animation

.End:
		rts

.ChkBounceUp:
		move.w	oY(a0),d2			; Get Y of left sensor
		move.b	oColH(a0),d0			; ''
		ext.w	d0				; ''
		sub.w	d0,d2				; ''
		subq.w	#2,d2				; ''
		move.w	oX(a0),d3			; Get X of left sensor
		move.b	oColW(a0),d0			; ''
		ext.w	d0				; ''
		sub.w	d0,d3				; ''
		jsr	Level_FindBlock			; Get the block located there
		move.w	(a1),d0				; ''
		andi.w	#$3FF,d0			; ''
		cmpi.w	#$80,d0				; Is the block the bouncy floor?
		beq.s	.BounceUp			; If so, branch

		move.w	oY(a0),d2			; Get Y of right sensor
		move.b	oColH(a0),d0			; ''
		ext.w	d0				; ''
		sub.w	d0,d2				; ''
		subq.w	#2,d2				; ''
		move.w	oX(a0),d3			; Get X of right sensor
		move.b	oColW(a0),d0			; ''
		ext.w	d0				; ''
		add.w	d0,d3				; ''
		jsr	Level_FindBlock			; Get the block located there
		move.w	(a1),d0				; ''
		andi.w	#$3FF,d0			; ''
		cmpi.w	#$80,d0				; Is the block the bouncy floor?
		bne.s	.End				; If not, branch

.BounceUp:
		addq.l	#4,sp				; Don't return to caller
		
		move.w	#$1600,oYVel(a0)		; Bounce Sonic up
		bset	#1,oStatus(a0)			; Set in air flag
		clr.b	oJumping(a0)			; Clear jump flag
		clr.b	oDashTimer(a0)			; Reset dash timer
		clr.b	oDashFlag(a0)			; Reset dash flag

		playSnd	#sFloorBounce, 2		; Play the floor bounce sound

		btst	#2,oStatus(a0)			; Is Sonic already rolling?
		bne.s	.End2				; If so, branch
		bset	#2,oStatus(a0)			; Set roll flag
		move.b	#$E,oColH(a0)			; Reduce Sonic's hitbox
		move.b	#7,oColW(a0)			; ''
		addq.w	#5,oY(a0)			; Align Sonic to the ground
		move.b	#2,oAni(a0)			; Set rolling animation

.End2:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Check for bars to hang on to
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_ChkHang:
		btst	#3,oFlags(a0)			; Are we already hanging?
		bne.s	.End				; If so, branch

		move.w	oX(a0),d3			; X position
		move.w	oY(a0),d2			; Y position
		subi.w	#$18,d2				; ''
		jsr	Level_FindBlock			; Get the block located there
		move.w	(a1),d0				; ''
		andi.w	#$3FF,d0			; ''
		cmpi.w	#$81,d0				; Is the block the bar?
		bne.s	.End				; If not, branch

		bclr	#2,oStatus(a0)			; Clear roll flag
		clr.l	oXVel(a0)			; Stop movement
		clr.w	oGVel(a0)			; ''
		bset	#3,oFlags(a0)			; Set hanging flag
		move.b	#$A,oAni(a0)			; Set hanging animation
		move.b	#7,oHangAniTime(a0)		; Animation timer
		move.w	oY(a0),d0			; Align with bar
		subi.w	#$18,d0				; ''
		andi.w	#$FFF0,d0			; ''
		addi.w	#$18,d0				; ''
		move.w	d0,oY(a0)			; ''
		clr.b	oAngle(a0)			; Reset angle
		bclr	#1,oRender(a0)			; ''

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Hang onto the bars
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Hang:
		move.w	oX(a0),d3			; X position
		move.w	oY(a0),d2			; Y position
		subi.w	#$18,d2				; ''
		jsr	Level_FindBlock			; Get the block located there
		move.w	(a1),d0				; ''
		andi.w	#$3FF,d0			; ''
		cmpi.w	#$81,d0				; Is the block the bar?
		bne.s	.FallOff			; If not, branch
		move.b	r_Ctrl_Press.w,d0		; Get control press bits
		andi.b	#$70,d0				; Are we jumping off?
		beq.s	.MoveX				; If not, branch

.FallOff:
		bclr	#3,oFlags(a0)			; Stop hanging
		addi.w	#$10,oY(a0)			; Fall off
		move.b	oInitColH(a0),oColH(a0)		; Reset collision height
		move.b	oInitColW(a0),oColW(a0)		; Reset collision width
		rts

.MoveX:
		moveq	#2,d0				; X speed
		btst	#2,r_Ctrl_Hold.w		; Are we going left?
		beq.s	.ChkRight			; If not, branch
		neg.w	d0				; Go the other way
		bset	#0,oStatus(a0)			; Face to the left
		bset	#0,oRender(a0)			; ''
		bra.s	.DoMove				; Continue

.ChkRight:
		btst	#3,r_Ctrl_Hold.w		; Are we going left?
		beq.s	.ResetScr			; If not, branch
		bclr	#0,oStatus(a0)			; Face to the right
		bclr	#0,oRender(a0)			; ''

.DoMove:
		add.w	d0,oX(a0)			; Move
		subq.b	#1,oHangAniTime(a0)		; Decrement animation timer
		bpl.s	.ResetScr			; If it hasn't run out, branch
		move.b	#7,oHangAniTime(a0)		; Reset timer
		addq.b	#1,oAniFrame(a0)		; Increment animation frame
		cmpi.b	#4,oAniFrame(a0)		; Have we reached the last one?
		bcs.s	.ResetScr			; If not, branch
		clr.b	oAniFrame(a0)			; Reset animation frame

.ResetScr:
		clr.b	oScrlDelay(a0)			; Reset scroll delay counter
		cmpi.w	#(224/2)-16,r_Cam_Y_Dist.w	; Is the camera centered vertically?
		beq.s	.End				; If so, branch
		bhs.s	.ScrollUp			; If it's below the center, branch
		addq.w	#4,r_Cam_Y_Dist.w		; Scroll the camera up

.ScrollUp:
		subq.w	#2,r_Cam_Y_Dist.w		; Scroll the camera down

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Check for electricity
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_ChkElectric:
		move.w	oX(a0),d3			; X position
		move.w	oY(a0),d2			; Y position
		jsr	Level_FindBlock			; Get the block located there
		move.w	(a1),d0				; ''
		andi.w	#$3FF,d0			; ''

		lea	.Blocks(pc),a1			; BLocks to check
		moveq	#2,d6				; ''

.ChkBlocks:
		cmp.w	(a1)+,d0			; have we touched this block?
		beq.s	ObjSonic_GetHurt		; If so, branch
		dbf	d6,.ChkBlocks			; Loop
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.Blocks:	dc.w	$82, $83, $84
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Get Sonic hurt
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_GetHurt:
		tst.b	oInvulTime(a0)			; Are we invulnerable?
		bne.w	.End				; If so, branch
		tst.w	r_Rings.w			; Does Sonic have any rings?
		beq.w	ObjSonic_GetKilled		; If not, branch
		jsr	FindFreeObj.w
		bne.s	.Hurt
		move.l	#ObjRingLoss,oAddr(a1)
		move.w	oX(a0),oX(a1)
		move.w	oY(a0),oY(a1)

.Hurt:
		move.b	#4,oRoutine(a0)			; Set to hurt routine
		jsr	Player_ResetOnFloor_Part2	; Reset Sonic like he would touching the ground
		clr.b	oScrlDelay(a0)			; Reset scroll delay counter
		bclr	#0,oFlags(a0)			; Allow modes
		bclr	#3,oFlags(a0)			; Stop hanging
		bset	#1,oStatus(a0)			; Set the "in air" flag
		move.b	#$1A,oAni(a0)			; Set to hurt animation
		move.b	#$78,oInvulTime(a0)		; Set invulnerable timer

		move.w	#-$400,oYVel(a0)		; Make Sonic bounce away
		move.w	#-$200,oXVel(a0)		; ''
		btst	#6,oStatus(a0)			; Is Sonic underwater?
		beq.s	.ChkReverse			; If not, branch
		move.w	#-$200,oYVel(a0)		; Make Sonic bounce away slower
		move.w	#-$100,oXVel(a0)

.ChkReverse:
		move.w	oX(a0),d0			; Get X position
		cmp.w	oX(a2),d0			; Is Sonic left of the object that hurt him?
		bcs.s	.ChkSnd				; If so, branch
		neg.w	oXVel(a0)			; Make Sonic bounce the other way if on the right side

.ChkSnd:
		clr.w	oGVel(a0)			; Reset ground velocity
		
		cmpi.l	#ObjSpike,oAddr(a2)		; Did Sonic hit a spike?
		beq.s	.End				; If not, branch
		playSnd	#sHurt, 2			; Play hurt sound

.End:
		moveq	#-1,d0				; Set return status
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Hurt routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Hurt:
		tst.b	r_Move_Cheat.w
		beq.s	.NoPlacementEnter
		btst	#4,r_P1_Press.w			; Has the B button been pressed?
		beq.s	.NoPlacementEnter		; If not, branch
		move.b	#1,r_Debug_Mode.w		; Enable debug placement mode
		move.l	#DebugPlacement,oAddr(a0)	; Set to debug placement mode
		jmp	DisplayObject.w			; Display Sonic's sprite
		
.NoPlacementEnter:
		jsr	ObjectMove.w			; Allow movement
		addi.w	#$30,oYVel(a0)			; Apply gravity
		btst	#6,oStatus(a0)			; Is Sonic underwater?
		beq.s	.NotWater			; If not, branch
		subi.w	#$20,oYVel(a0)			; Reduce gravity underwater

.NotWater:
		move.b	#$1A,oAni(a0)			; Force the hurt animation
		bsr.s	.ChkStop			; Check if Sonic has hit the ground or the bottom boundary
		
		cmpi.w	#(224/2)-16,r_Cam_Y_Dist.w	; Is the camera centered vertically?
		beq.s	.Cont				; If so, branch
		bhs.s	.ScrollUp			; If it's below the center, branch
		addq.w	#4,r_Cam_Y_Dist.w		; Scroll the camera up

.ScrollUp:
		subq.w	#2,r_Cam_Y_Dist.w		; Scroll the camera down

.Cont:
		bsr.w	ObjSonic_LvlBound		; Handle level boundaries
		bsr.w	ObjSonic_Animate		; Animate sprite
		bsr.w	ObjSonic_LoadDPLCs		; Load DPLCs
		jmp	DisplayObject.w			; Display Sonic's sprite
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.ChkStop:
		move.w	r_Max_Cam_Y.w,d0		; Get bottom boundary
		addi.w	#224,d0				; ''
		cmp.w	oY(a0),d0			; Has Sonic hit it?
		blt.s	ObjSonic_GetKilled		; If so, branch

		jsr	Player_ChkCollision		; Check for level collision
		btst	#1,oStatus(a0)			; Is Sonic still in midair?
		bne.s	.End				; If so, branch

		moveq	#0,d0
		move.w	d0,oYVel(a0)			; Stop Sonic's movement
		move.w	d0,oXVel(a0)			; ''
		move.w	d0,oGVel(a0)			; ''
		move.b	d0,oFlags(a0)			; Allow Sonic to move
		move.b	d0,oAni(a0)			; Reset animation
		move.b	#2,oRoutine(a0)			; Set back to main routine
		
.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Get Sonic killed
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_GetKilled:
		move.b	#6,oRoutine(a0)			; Set to the death routine
		jsr	Player_ResetOnFloor_Part2	; Reset Sonic like he would touching the ground
		clr.b	oScrlDelay(a0)			; Reset scroll delay counter
		bset	#1,oStatus(a0)			; Set the "in air" flag
		move.b	#$18,oAni(a0)			; Set to death animation

		move.w	#-$700,oYVel(a0)		; Make Sonic bounce up
		clr.w	oXVel(a0)			; Lock Sonic horizontally
		clr.w	oGVel(a0)			; ''
		move.w	#$FFFF,r_Cam_Locked.w		; Lock the camera

		cmpi.l	#ObjSpike,oAddr(a2)		; Did Sonic hit a spike?
		beq.s	.End				; If not, branch
		playSnd	#sDeath,2			; Play death sound

.End:
		moveq	#-1,d0				; Set return status
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Death routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Dead:
		tst.b	r_Move_Cheat.w
		beq.s	.NoPlacementEnter
		btst	#4,r_P1_Press.w			; Has the B button been pressed?
		beq.s	.NoPlacementEnter		; If not, branch
		move.b	#1,r_Debug_Mode.w		; Enable debug placement mode
		move.l	#DebugPlacement,oAddr(a0)	; Set to debug placement mode
		jmp	DisplayObject.w			; Display Sonic's sprite

.NoPlacementEnter:
		move.b	#$18,oAni(a0)			; Force the death animation
		ori.w	#$8000,oVRAM(a0)		; Force high priority
		bsr.s	Sonic_ChkBound			; Check for when Sonic goes off screen
		jsr	ObjectMoveAndFall.w		; Allow movement
		bsr.w	ObjSonic_Animate		; Animate sprite
		bsr.w	ObjSonic_LoadDPLCs		; Load DPLCs
		jmp	DisplayObject.w			; Display Sonic's sprite
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Sonic_ChkBound:
		move.w	r_Max_Cam_Y.w,d0		; Get bottom boundary
		addi.w	#$100,d0			; ''
		cmp.w	oY(a0),d0			; Has Sonic hit it?
		bge.s	.End				; If not, branch

		move.b	#8,oRoutine(a0)			; Go to gone routine
		move.b	#60,oDeathTimer(a0)		; Set death timer to 1 second

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Wait for level reload or game/time over
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Gone:
		subq.b	#1,oDeathTimer(a0)		; Decrement the death counter
		bne.s	.End				; If it hasn't run out, branch
		tst.b	r_Boss_Defeat.w
		bne.s	.Seizure
		st	r_Lvl_Reload.w			; Reload the level
		rts

.Seizure:
		move.b	#gEnd,r_Game_Mode.w

.End:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Have a seizure
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Seizure:
		subq.b	#1,oDeathTimer(a0)
		bpl.s	.Anim
		bsr.w	ObjSonic_GetKilled

.Anim:
		move.b	#$B,oAni(a0)
		bsr.s	ObjSonic_Animate		; Animate sprite
		bsr.s	ObjSonic_Display		; Display sprite
		bra.s	ObjSonic_LoadDPLCs		; Load DPLCs
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Display Sonic's sprite
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Display:
		move.b	oInvulTime(a0),d0		; Get invulnerability timer
		beq.s	.Display			; If it's 0, branch
		subq.b	#1,oInvulTime(a0)		; Decrement invulnerability timer
		lsr.w	#3,d0				; Can Sonic's sprite be displayed?
		bcs.s	.Display			; If so, branch
		rts

.Display:
		jmp	DisplayObject.w			; Display
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Load Sonic's DPLCs
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_LoadDPLCs:
		lea	DPLC_ObjSonic,a2		; DPLCs
		move.w	#$F000,d4			; VRAM location
		move.l	#ArtUnc_Sonic,d6		; Art
		jmp	LoadObjDPLCs.w			; Load DPLCs
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Animate Sonic's sprite
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ObjSonic_Animate:
		lea	Ani_ObjSonic,a1			; Animation script
		moveq	#0,d0
		move.b	oAni(a0),d0			; Get animation ID
		cmp.b	oPrevAni(a0),d0			; Has it changed?
		beq.s	.Run				; If not, branch
		move.b	d0,oPrevAni(a0)			; Save the new ID
		clr.b	oAniFrame(a0)			; Reset animation
		clr.b	oAniTimer(a0)			; Reset animation timer
		bclr	#5,oStatus(a0)			; Clear "pushing" flag

.Run:
		add.w	d0,d0				; Turn ID into offset
		adda.w	(a1,d0.w),a1			; Get pointer to current animation script
		move.b	(a1),d0				; Get first byte
		bmi.s	.WalkRunAnim			; If this is a special animation, branch
		move.b	oStatus(a0),d1			; Get status
		andi.b	#1,d1				; Only get horizontal flip bit
		andi.b	#$FC,oRender(a0)		; Mask out flip bits in render flags
		or.b	d1,oRender(a0)			; Set flip bits
		subq.b	#1,oAniTimer(a0)		; Decrement animation timer
		bpl.s	.Wait				; If it hasn't run out, branch
		move.b	d0,oAniTimer(a0)		; Set new animation timer
		
.GetFrame:
		moveq	#0,d1
		move.b	oAniFrame(a0),d1		; Get current value in the script
		move.b	1(a1,d1.w),d0			; ''
		cmpi.b	#$FD,d0				; Is it a command value?
		bhs.s	.CmdReset			; If so, branch

.Next:
		move.b	d0,oFrame(a0)			; Set mapping frame ID
		addq.b	#1,oAniFrame(a0)		; Advance into the animation script

.Wait:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.CmdReset:
		addq.b	#1,d0				; Is this flag $FF (reset)?
		bne.s	.CmdJump			; If not, branch
		clr.b	oAniFrame(a0)			; Reset animation
		move.b	1(a1),d0			; Get first frame ID
		bra.s	.Next				; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.CmdJump:
		addq.b	#1,d0				; Is this flag $FE (jump)?
		bne.s	.CmdSetAnim			; If not, branch
		move.b	2(a1,d1.w),d0			; Get jump offset
		sub.b	d0,oAniFrame(a0)		; Go back
		sub.b	d0,d1				; ''
		move.b	1(a1,d1.w),d0			; Get new frame ID
		bra.s	.Next				; Continue
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.CmdSetAnim:
		addq.b	#1,d0				; Is this flag $FD (set animation ID)?
		bne.s	.CmdEnd				; If not, branch
		move.b	2(a1,d1.w),oAni(a0)		; Set new animation ID
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.CmdEnd:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.WalkRunAnim:
		subq.b	#1,oAniTimer(a0)		; Decrement animation timer
		bpl.s	.Wait				; If it hasn't run out, branch
		addq.b	#1,d0				; Is the animation walking/running?
		bne.w	.RollAnim			; If not, branch

		moveq	#0,d0
		move.b	oFlipAngle(a0),d0		; Is Sonic tumbling in the air?
		bne.w	.TumbleAnim			; If so, branch

		moveq	#0,d1				; Intial flip bits
		move.b	oAngle(a0),d0			; Get angle
		bmi.s	.ChkStatus			; If it's negative, branch
		beq.s	.ChkStatus			; If it's zero, branch
		subq.b	#1,d0				; Decrement angle if it's positive

.ChkStatus:
		move.b	oStatus(a0),d2			; Get status
		andi.b	#1,d2				; Is Sonic mirrored horizontally?
		bne.s	.ChkFlip			; If so, branch
		not.b	d0				; Reverse angle

.ChkFlip:
		addi.b	#$10,d0				; Shift angle
		bpl.s	.SetFlags			; If it's positive, branch
		moveq	#3,d1				; Flags to flip Sonic's sprite

.SetFlags:
		andi.b	#$FC,oRender(a0)		; Mask out flip bits
		eor.b	d1,d2				; Flip
		or.b	d2,oRender(a0)			; Set in render flags

		btst	#5,oStatus(a0)			; Is Sonic pushing?
		bne.w	.DoPushAnim			; If so, branch

		lsr.b	#4,d0				; Divide angle by $10
		andi.b	#6,d0				; Get angle section

		move.w	oGVel(a0),d2			; Get Sonic's speed
		bpl.s	.GetAnim			; If it's already positive, branch
		neg.w	d2				; Force it to be positive

.GetAnim:
		lea	SonicAni_Sprint,a1		; Sprinting animation
		tst.b	d0
		bne.s	.ChkRun
		cmpi.w	#$C00,d2			; Is Sonic sprinting?
		bcc.s	.SkipWalk			; If so, branch
		
.ChkRun:
		lea	SonicAni_Run,a1			; Running animation
		cmpi.w	#$600,d2			; Is Sonic running?
		bcc.s	.SkipWalk			; If so, branch
		lea	SonicAni_Walk,a1		; Walking animation
		move.b	d0,d1				; Multiply angle section ID by 3
		lsr.b	#1,d1				; ''
		add.b	d1,d0				; ''

.SkipWalk:
		add.b	d0,d0				; Double the offset
		move.b	d0,d3				; Copy the oofset
		neg.w	d2				; Get animation speed
		addi.w	#$800,d2			; ''
		bpl.s	.SetTimer			; ''
		moveq	#0,d2				; ''

.SetTimer:
		lsr.w	#8,d2				; ''
		move.b	d2,oAniTimer(a0)		; Set timer
		bsr.w	.GetFrame			; Get the next frame
		add.b	d3,oFrame(a0)			; Add angle offset
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.TumbleAnim:
		move.b	oFlipAngle(a0),d0		; Get flip angle
		moveq	#0,d1
		move.b	oStatus(a0),d2			; Get status
		andi.b	#1,d2				; Are we are facing left?
		bne.s	.TumbleLeft			; If so, branch

		andi.b	#$FC,oRender(a0)		; Clear flip bits
		addi.b	#$B,d0				; Get map frame
		divu.w	#$16,d0				; ''
		addi.b	#$68,d0				; ''
		move.b	d0,oFrame(a0)			; Set map frame
		clr.b	oAniTimer(a0)			; Reset animation timer
		rts

.TumbleLeft:
		andi.b	#$FC,oRender(a0)		; Clear flip bits
		tst.b	oFlipTurned(a0)			; Is flipping inverted?
		beq.s	.NotInverted			; If not, branch
		ori.b	#1,oRender(a0)			; Face left
		addi.b	#$B,d0				; Get map frame
		bra.s	.SetLeftFrame			; Continue

.NotInverted:
		ori.b	#3,oRender(a0)			; Face left and be upside down
		neg.b	d0				; Get map frame
		addi.b	#$8F,d0				; ''

.SetLeftFrame:
		divu.w	#$16,d0				; Continue getting map frame
		addi.b	#$68,d0				; ''
		move.b	d0,oFrame(a0)			; Set map frame
		clr.b	oAniTimer(a0)			; Reset animation timer
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.RollAnim:
		addq.b	#1,d0				; Is the animation rolling?
		bne.s	.PushAnim			; If not, branch

		move.w	oGVel(a0),d2			; Get Sonic's speed
		bpl.s	.GetAnim2			; If it's already negative, branch
		neg.w	d2				; Force it to be negative

.GetAnim2:
		lea	SonicAni_Roll2,a1		; Use fast animation
		cmpi.w	#$600,d2			; Is Sonic rolling fast enough?
		bcc.s	.PrepareTimer			; If so, branch
		lea	SonicAni_Roll,a1		; Use slower animation

.PrepareTimer:
		neg.w	d2				; Get animation speed
		addi.w	#$400,d2			; ''
		bpl.s	.SetTimer2			; ''
		moveq	#0,d2				; ''

.SetTimer2:
		lsr.w	#8,d2				; ''
		move.b	d2,oAniTimer(a0)		; Set timer
		
		move.b	oStatus(a0),d1			; Get status
		andi.b	#1,d1				; Get horizontal flip flag only
		andi.b	#$FC,oRender(a0)		; Clear flip bits in render flags
		or.b	d1,oRender(a0)			; Set new flip bits

		bra.w	.GetFrame			; Get the next frame
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.PushAnim:
		addq.b	#1,d0				; Is the animation rolling?
		bne.s	.HangAnim			; If not, branch

.DoPushAnim:
		move.w	oGVel(a0),d2			; Get Sonic's speed
		bmi.s	.GetAnim3			; If it's already negative, branch
		neg.w	d2				; Force it to be negative

.GetAnim3:
		addi.w	#$800,d2			; Get animation speed
		bpl.s	.SetTimer3			; ''
		moveq	#0,d2				; ''

.SetTimer3:
		lsr.w	#6,d2				; ''
		move.b	d2,oAniTimer(a0)		; Set timer
		lea	SonicAni_Push,a1		; Pushing animation
		bra.w	.GetFrame			; Get the next frame
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.HangAnim:
		moveq	#0,d1
		move.b	oAniFrame(a0),d1		; Get animation frame
		move.b	1(a1,d1.w),oFrame(a0)		; Set map frame
		clr.b	oAniTimer(a0)			; Clear animation timer
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Handle debug placement mode
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
DebugPlacement:
		moveq	#0,d0
		move.b	r_Debug_Mode.w,d0		; Get debug placement mode routine
		andi.w	#2,d0				; Only allow 0, 2, 4, and 6
		move.w	.Routines(pc,d0.w),d0		; Get offset
		jmp	.Routines(pc,d0.w)		; Go to the correct routine
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
.Routines:
		dc.w	Debug_Init-.Routines		; Initialization
		dc.w	Debug_Main-.Routines		; Main
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Debug_Init:
		addq.b	#2,r_Debug_Mode.w		; Next routine
		clr.b	oFrame(a0)			; Reset mapping frame
		clr.b	oAni(a0)			; Reset animation
		clr.w	oGVel(a0)			; Reset ground velocity
		clr.w	r_Cam_Locked.w			; Unlock the camera
		clr.b	oBallMode(a0)			; Reset ball mode
		clr.b	oAngle(a0)			; Reset angle
		move.b	#2,oRoutine(a0)			; Set routine to main

		move.w	oInteract(a0),d0		; Get object interacted with last
		beq.s	.NoInteract			; If there is none, branch
		movea.w	d0,a1
		bclr	#3,oStatus(a1)			; Clear flags
		bclr	#5,oStatus(a1)			; ''
		clr.w	oInteract(a0)			; No more interaction

.NoInteract:
		clr.b	oFlags(a0)			; Reset flags
		clr.b	oStatus(a0)			; Reset status
		andi.b	#$FC,oRender(a0)		; Mask out flip bits in render flags
		move.b	#1,oFrame(a0)			; Display the standing frame
		bsr.w	ObjSonic_LoadDPLCs		; Load DPLCs
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Debug_Main:
		bsr.w	ObjSonic_ExtendedCam		; Handle extended camera
		bsr.s	Debug_Control			; Control
		jmp	DisplayObject.w			; Display
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Debug_Control:
		moveq	#6,d0				; Speed
		btst	#0,r_P1_Hold.w			; Is up being held?
		beq.s	.NoUp				; If not, branch
		sub.w	d0,oY(a0)			; Move up

.NoUp:
		btst	#1,r_P1_Hold.w			; Is down being held?
		beq.s	.NoDown				; If not, branch
		add.w	d0,oY(a0)			; Move down
		
.NoDown:
		btst	#2,r_P1_Hold.w			; Is left being held?
		beq.s	.NoLeft				; If not, branch
		sub.w	d0,oX(a0)			; Move left
		
.NoLeft:
		btst	#3,r_P1_Hold.w			; Is right being held?
		beq.s	.NoRight			; If not, branch
		add.w	d0,oX(a0)			; Move right
		
.NoRight:
		btst	#4,r_P1_Press.w			; Has the B button been pressed?
		beq.s	.ChkWrap			; If not, branch
		moveq	#0,d0
		move.b	d0,r_Debug_Mode.w		; Disable debug placement mode
		move.w	d0,oX+2(a0)			; Reset X subpixel
		move.w	d0,oY+2(a0)			; Reset Y subpixel
		move.w	d0,oXVel(a0)			; Reset X velocity
		move.w	d0,oYVel(a0)			; Reset Y velocity
		move.w	d0,oGVel(a0)			; Reset ground velocity
		andi.b	#1,oStatus(a0)			; Reset status
		bset	#1,oStatus(a0)			; Set "in air" flag
		move.l	#ObjSonic,oAddr(a0)		; Use normal Sonic object
		move.b	oInitColH(a0),oColH(a0)		; Reset collision height
		move.b	oInitColW(a0),oColW(a0)		; Reset collision width

.ChkWrap:
		rts
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
ArtUnc_Sonic:
		incbin	"Level/Objects/Sonic/Art.unc.bin"
		even
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Map_ObjSonic:
		include	"Level/Objects/Sonic/Mappings.asm"
		even
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
DPLC_ObjSonic:
		include	"Level/Objects/Sonic/DPLCs.asm"
		even
; ---------------------------------------------------------------------------------------------------------------------------------------------------------
Ani_ObjSonic:
		include	"Level/Objects/Sonic/Animations.asm"
		even
; =========================================================================================================================================================