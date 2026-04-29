        CPU     8080
        ORG     5200H

; ============================================================
; TRS-80 MODEL I MINI-BEAST - FIRST PORT BUILD, RELOCATED 5200H
; CONSOLIDATED BUILD WITH:
;   - EXTENDED TO 6 BEAST SLOTS
;   - MOVE/PUSH
;   - PULL + SINGLE FRONT PUSH
;   - 2 BEASTS WITH DIAGONAL / STUCK AI
;   - TITLE / LEGEND
;   - RIGHT-SIDE BRAIDED ATTRACT PANEL
; ============================================================

VBASE           EQU     03C00H   ; TRS-80 Model I video RAM
; TIMERLO is now RAM variable near the end of the file
; KBUFCHAR removed: direct TRS-80 keyboard matrix scan

PLAYERCHR       EQU     06FH    ; lower-case o for player (TRS-80 screen code)
BEASTCHR        EQU     07EH    ; chosen TRS-80 symbol from character chart for beast
BLOCKCHR        EQU     0FFH    ; solid TRS-80 block; must be preserved by PLOT_BC
TREECHR         EQU     040H    ; @ / tree marker
SPACECHR        EQU     020H    ; SPACE
; Arena border is stored as POLY/VTI 2x3 semigraphic patterns
; and converted through PLOT_ART_BC for TRS-80 display.
; Bit layout follows POLY/VTI: 20 04 / 10 02 / 08 01.
; These are single-pixel-thin lines, not movable BLOCKCHR.
BORDERCHR       EQU     000H    ; unused filler / empty
BORDERTOPCHR    EQU     036H
BORDERLEFTCHR   EQU     038H
BORDERRIGHTCHR  EQU     007H
BORDERBOTCHR    EQU     01BH
BORDERTLCHR     EQU     03EH    ; top border + left border corner
BORDERTRCHR     EQU     037H    ; top border + right border corner
BORDERBLCHR     EQU     03BH    ; bottom border + left border corner
BORDERBRCHR     EQU     01FH    ; bottom border + right border corner
;VBARCHR         EQU     0FCH    ; |
OMICRONCHR      EQU     02AH    ; egg marker: ASCII *
INFANTCHR       EQU     025H    ; infant marker: ASCII %

KEY_A           EQU     0C1H
KEY_D           EQU     0C4H
KEY_S           EQU     0D3H
KEY_W           EQU     0D7H

KEY_I           EQU     0C9H
KEY_J           EQU     0CAH
KEY_K           EQU     0CBH
KEY_L           EQU     0CCH

PLAYERDLY       EQU     02H     ; player repeat throttle; BEAST/global pacing unchanged
GAMEDELAY       EQU     0400H   ; global loop throttle; tune 0200H fast, 0800H slow

PLAY_L          EQU     5
PLAY_R          EQU     58
PLAY_T          EQU     2
PLAY_B          EQU     13

PLAY_RP1        EQU     59
PLAY_BP1        EQU     14

BORDER_L        EQU     4
BORDER_R        EQU     59
BORDER_T        EQU     1
BORDER_B        EQU     14

BORDER_RP1      EQU     60
BORDER_BP1      EQU     15

MAXBEAST        EQU     8
NUMBEAST        EQU     4       ; max beasts allowed at round start / egg slots
MINBEAST        EQU     2

; ============================================================
; ENTRY
; ============================================================

START:
        LXI     SP,7FF0H      ; explicit stack for debugger/raw-load launch
        CALL    CLEAR_SCREEN
        CALL    ATTRACT_START

        LDA     RNGSTATE
        XRI     05AH
        STA     RNGSTATE

        XRA     A
        STA     ROUNDNO

        CALL    RESET_GAME

MAINLOOP:
        CALL    GAME_DELAY
        CALL    FRAME_TICK

        CALL    UPDATE_EGGS
        CALL    UPDATE_SMASH_FLASH

        LDA     ROUNDWIN
        ORA     A
        JZ      ROUNDOK
        XRA     A
        STA     ROUNDWIN
        CALL    SHOW_WIN_FLASH
        LDA     ROUNDNO
        INR     A
        STA     ROUNDNO
        LDA     ATTRSTYLE
        XRI     01H
        STA     ATTRSTYLE
        CALL    RESET_GAME
ROUNDOK:
        ; Edge-triggered player input:
        ; - new key press moves immediately
        ; - held key repeats through PLYTMR
        ; - key release clears LASTKEY/PLYTMR for precise tap control
        CALL    GETKEY
        MOV     E,A             ; current key code, or 0 if none

        LDA     LASTKEY
        CMP     E
        JNZ     NEW_KEY

        ; Same key held: wait for repeat timer to expire.
        LDA     PLYTMR
        ORA     A
        JZ      DO_MOVE
        DCR     A
        STA     PLYTMR
        JMP     NOKEY

NEW_KEY:
        MOV     A,E
        STA     LASTKEY
        XRA     A
        STA     PLYTMR          ; immediate response on a fresh press

DO_MOVE:
        MOV     A,E
        ORA     A
        JZ      KEY_RELEASE

        CALL    STIR_RNG_PLAYER
        MVI     A,PLAYERDLY
        STA     PLYTMR

        MOV     A,E
        CPI     KEY_A
        CZ      MOVE_LEFT
        CPI     KEY_D
        CZ      MOVE_RIGHT
        CPI     KEY_W
        CZ      MOVE_UP
        CPI     KEY_S
        CZ      MOVE_DOWN

        CPI     KEY_J
        CZ      PULL_LEFT
        CPI     KEY_L
        CZ      PULL_RIGHT
        CPI     KEY_I
        CZ      PULL_UP
        CPI     KEY_K
        CZ      PULL_DOWN

        JMP     NOKEY

KEY_RELEASE:
        XRA     A
        STA     LASTKEY
        STA     PLYTMR

NOKEY:
        CALL    UPDATE_ALL_BEASTS
        JMP     MAINLOOP

; ============================================================
; TRS-80 TITLE / ATTRACT START SCREEN
; ============================================================

ATTRACT_START:
        CALL    CLEAR_SCREEN
        CALL    ATTRACT_TEXT
        XRA     A
        STA     HEADPOS
        MVI     A,28
        STA     TAILPOS
ATTR_LOOP:
        CALL    FRAME_TICK_FAST
        CALL    ATTRACT_SNAKE
        CALL    ANY_KEY
        ORA     A
        JZ      ATTR_LOOP
        RET

ATTRACT_TEXT:
        MVI     B,6
        MVI     C,25
        LXI     H,ATTRTXT1
        CALL    PUTSTR_BC
        MVI     B,7
        MVI     C,23
        LXI     H,ATTRTXT2
        CALL    PUTSTR_BC
        RET

ATTRTXT1:       DB      'PRESS ANY KEY',0
ATTRTXT2:       DB      'TO START THE GAME',0

PUTSTR_BC:
        MOV     A,M
        ORA     A
        RZ
        ANI     07FH            ; force text strings to ASCII/display codes
        PUSH    H
        CALL    PLOT_BC
        POP     H
        INX     H
        INR     C
        JMP     PUTSTR_BC

ANY_KEY:
        LDA     03801H
        ORA     A
        JNZ     AK_YES
        LDA     03802H
        ORA     A
        JNZ     AK_YES
        LDA     03804H
        ORA     A
        JNZ     AK_YES
        LDA     03808H
        ORA     A
        JNZ     AK_YES
        LDA     03810H
        ORA     A
        JNZ     AK_YES
        LDA     03820H
        ORA     A
        JNZ     AK_YES
        LDA     03840H
        ORA     A
        JNZ     AK_YES
        LDA     03880H
        ORA     A
        RZ
AK_YES:
        MVI     A,1
        RET

ATTRACT_SNAKE:
        LDA     HEADPOS
        CALL    POS_TO_BC
        MVI     A,0BFH
        CALL    PLOT_BC

        LDA     TAILPOS
        CALL    POS_TO_BC
        MVI     A,SPACECHR
        CALL    PLOT_BC

        LDA     HEADPOS
        INR     A
        CPI     72
        JC      AS_HOK
        XRA     A
AS_HOK:
        STA     HEADPOS

        LDA     TAILPOS
        INR     A
        CPI     72
        JC      AS_TOK
        XRA     A
AS_TOK:
        STA     TAILPOS
        CALL    DELAY_ATTRACT
        RET

; left=18 right=46 top=4 bottom=12
POS_TO_BC:
        CPI     29
        JC      PT_TOP
        CPI     37
        JC      PT_RIGHT
        CPI     65
        JC      PT_BOTTOM
        JMP     PT_LEFT
PT_TOP:
        MVI     B,4
        ADI     18
        MOV     C,A
        RET
PT_RIGHT:
        SUI     29
        ADI     5
        MOV     B,A
        MVI     C,46
        RET
PT_BOTTOM:
        SUI     37
        MOV     E,A
        MVI     A,45
        SUB     E
        MOV     C,A
        MVI     B,12
        RET
PT_LEFT:
        SUI     65
        MOV     E,A
        MVI     A,11
        SUB     E
        MOV     B,A
        MVI     C,18
        RET

DELAY_ATTRACT:
        LXI     D,02200H
DA_LOOP:
        DCX     D
        MOV     A,D
        ORA     E
        JNZ     DA_LOOP
        RET

; Global pacing delay for the no-DOS/no-Expansion-Interface build.
; This slows beasts, eggs, player repeat timers, and visual effects together
; so the per-actor counters behave more like the original 60 Hz POLY-88 build.
GAME_DELAY:
        LXI     B,GAMEDELAY
GD_LOOP:
        DCX     B
        MOV     A,B
        ORA     C
        JNZ     GD_LOOP
        RET

; Stir player/key timing into RNG. Called when a nonzero movement key is accepted.
; Does not replace RAND8; it just perturbs RNGSTATE with human timing.
STIR_RNG_PLAYER:
        LDA     MOVECTR
        INR     A
        STA     MOVECTR
        MOV     B,A

        LDA     RNGSTATE
        XRA     B
        MOV     B,A

        LDA     TICKLO
        XRA     B
        MOV     B,A

        LDA     PX
        XRA     B
        MOV     B,A

        LDA     PY
        XRA     B
        RLC
        ADI     037H
        STA     RNGSTATE
        RET

FRAME_TICK_FAST:
        LDA     TICKLO
        INR     A
        STA     TICKLO
        LDA     RNGSTATE
        MOV     B,A
        LDA     TICKLO
        XRA     B
        RLC
        ADI     037H
        STA     RNGSTATE
        RET

FRAME_TICK:
        CALL    FRAME_TICK_FAST
        LDA     TICKLO
        STA     TIMERLO
        RET

; ============================================================
; RESET / CAPTURE
; ============================================================

RESET_GAME:
        CALL    CLEAR_SCREEN

        XRA     A
        STA     ATTRPHASE
        STA     ROUNDWIN
        STA     SMASHTMR
        STA     LEFTPANELMODE
        STA     PLYTMR
        STA     LASTKEY
        STA     DEATHCHR
        STA     E1STATE
        STA     E2STATE
        STA     E3STATE
        STA     E4STATE
        STA     E5STATE
        STA     E6STATE

        CALL    CLEAR_ALL_BEAST_STATE
        CALL    INIT_BEAST_COUNT

        CALL    RANDOM_BLOCK_COUNT
        STA     BLOCKCOUNT
        CALL    RANDOM_TREE_COUNT
        STA     TREECOUNT

        CALL    DRAW_ROUND
        CALL    DRAW_TITLE
        CALL    DRAW_LEGEND
        CALL    DRAW_BORDER
        CALL    DRAW_UI
        CALL    DRAW_ATTRACT_PANEL

        CALL    PLACE_RANDOM_BLOCKS
        CALL    PLACE_RANDOM_TREES
        CALL    PLACE_INITIAL_BEASTS

        ; Stage eggs before the 3..2..1 countdown so the
        ; whole round layout is already decided when play begins.
        CALL    SPAWN_EGG1
        CALL    SPAWN_EGG2
        CALL    SPAWN_EGG3
        CALL    SPAWN_EGG4
        CALL    SPAWN_EGG5
        CALL    SPAWN_EGG6

        CALL    PLACE_PLAYER
        CALL    ROUND_START_COUNTDOWN
        RET

PLAYER_CAPTURED:
        JMP     PLAYER_KILLED

PLAYER_KILLED:
        MVI     A,2
        STA     LEFTPANELMODE
        LXI     H,DEADGRX
        CALL    DRAW_BOTH_EVENT_PANELS
        CALL    HOLD_EVENT_GRAPHIC
        JMP     ADVANCE_ROUND

PLAYER_POISONED:
        MVI     A,2
        STA     LEFTPANELMODE
        LXI     H,POISONGRX
        CALL    DRAW_BOTH_EVENT_PANELS
        CALL    HOLD_EVENT_GRAPHIC
        JMP     ADVANCE_ROUND

ADVANCE_ROUND:
        LDA     ROUNDNO
        INR     A
        STA     ROUNDNO
        LDA     ATTRSTYLE
        XRI     01H
        STA     ATTRSTYLE
        CALL    RESET_GAME
        RET

; ============================================================
; KEYBOARD
; ============================================================

GETKEY:
        ; TRS-80 Model I direct keyboard matrix scan.
        ; Returns original KEY_* constants expected by BEAST.
        LDA     03801H          ; A-G row
        ANI     02H             ; A
        JNZ     GK_A
        LDA     03801H
        ANI     10H             ; D
        JNZ     GK_D

        LDA     03804H          ; P-W row
        ANI     080H            ; W
        JNZ     GK_W
        LDA     03804H
        ANI     08H             ; S
        JNZ     GK_S

        LDA     03802H          ; H-O row
        ANI     02H             ; I
        JNZ     GK_I
        LDA     03802H
        ANI     04H             ; J
        JNZ     GK_J
        LDA     03802H
        ANI     08H             ; K
        JNZ     GK_K
        LDA     03802H
        ANI     10H             ; L
        JNZ     GK_L

        XRA     A
        RET
GK_A:   MVI     A,KEY_A
        RET
GK_D:   MVI     A,KEY_D
        RET
GK_W:   MVI     A,KEY_W
        RET
GK_S:   MVI     A,KEY_S
        RET
GK_I:   MVI     A,KEY_I
        RET
GK_J:   MVI     A,KEY_J
        RET
GK_K:   MVI     A,KEY_K
        RET
GK_L:   MVI     A,KEY_L
        RET

; ============================================================
; BEAST TIMERS / COUNT / PLACEMENT
; FIRST PASS REFACTOR: table-driven for slot/state management
; while movement dispatch still uses the 6 existing MOVE_BEASTn
; routines are now bypassed by a generic slot mover.
; NUMBEAST remains the round-start cap / egg-slot count, while MAXBEAST
; is the total beast slot pool available for hatching.
; ============================================================

UPDATE_ALL_BEASTS:
        XRA     A
        STA     SLOTIDX
UAB_LOOP:
        LDA     SLOTIDX
        MOV     B,A
        MVI     A,MAXBEAST
        CMP     B
        JZ      UAB_DONE
        MOV     A,B
        CALL    UPDATE_ONE_BEAST
        LDA     SLOTIDX
        INR     A
        STA     SLOTIDX
        JMP     UAB_LOOP
UAB_DONE:
        RET

UPDATE_ONE_BEAST:
        STA     CURSLOT
        CALL    GET_SLOT_ALIVE_PTR
        MOV     A,M
        ORA     A
        RZ

        LDA     CURSLOT
        CALL    GET_SLOT_DLO_PTR
        MOV     A,M
        ORA     A
        JNZ     UOB_DECLO

        LDA     CURSLOT
        CALL    GET_SLOT_DHI_PTR
        MOV     A,M
        ORA     A
        JZ      UOB_FIRE
        DCR     A
        MOV     M,A

        LDA     CURSLOT
        CALL    GET_SLOT_DLO_PTR
        MVI     M,0FFH
        RET

UOB_DECLO:
        DCR     A
        MOV     M,A
        RET

UOB_FIRE:
        LDA     CURSLOT
        CALL    RESET_BEAST_DELAY_SLOT
        LDA     CURSLOT
        CALL    MOVE_BEAST_SLOT
        RET

RESET_BEAST_DELAY_SLOT:
        STA     CURSLOT
RBDS1:
        CALL    RAND8
        CPI     121
        JNC     RBDS1
        MOV     B,A

        LDA     CURSLOT
        CALL    GET_SLOT_DHI_PTR
        MVI     M,0

        MOV     A,B
        ADI     60
        JNC     RBDS2
        PUSH    PSW
        LDA     CURSLOT
        CALL    GET_SLOT_DHI_PTR
        MVI     M,1
        POP     PSW
RBDS2:
        MOV     B,A
        LDA     CURSLOT
        CALL    GET_SLOT_DLO_PTR
        MOV     M,B
        RET

INIT_BEAST_COUNT:
        LDA     BEASTLIMIT
        CPI     MINBEAST
        JNC     IBC_MIN_OK
        MVI     A,MINBEAST
IBC_MIN_OK:
        CPI     NUMBEAST+1
        JC      IBC_MAX_OK
        MVI     A,NUMBEAST
IBC_MAX_OK:
        STA     BEASTLIMIT
        SUI     1
        STA     LIMITTMP
IBC_RAND:
        CALL    RAND8
        MOV     B,A
        LDA     LIMITTMP
        CMP     B
        JC      IBC_RAND
        JZ      IBC_RAND
        MOV     A,B
        ADI     2
        STA     CURBEASTS
        RET

CLEAR_ALL_BEAST_STATE:
        XRA     A
        STA     SLOTIDX
CABS_LOOP:
        LDA     SLOTIDX
        MOV     B,A
        MVI     A,MAXBEAST
        CMP     B
        JZ      CABS_DONE

        MOV     A,B
        CALL    GET_SLOT_X_PTR
        MVI     M,0
        MOV     A,B
        CALL    GET_SLOT_Y_PTR
        MVI     M,0
        MOV     A,B
        CALL    GET_SLOT_ALIVE_PTR
        MVI     M,0
        MOV     A,B
        CALL    GET_SLOT_SMART_PTR
        MVI     M,0
        MOV     A,B
        CALL    GET_SLOT_DLO_PTR
        MVI     M,0
        MOV     A,B
        CALL    GET_SLOT_DHI_PTR
        MVI     M,0
        MOV     A,B
        CALL    GET_SLOT_STUCK_PTR
        MVI     M,0

        LDA     SLOTIDX
        INR     A
        STA     SLOTIDX
        JMP     CABS_LOOP
CABS_DONE:
        RET

PLACE_INITIAL_BEASTS:
        XRA     A
        STA     SLOTIDX
PIB_LOOP:
        LDA     SLOTIDX
        MOV     B,A
        LDA     CURBEASTS
        CMP     B
        JZ      PIB_DONE
        MOV     A,B
        CALL    PLACE_BEAST_SLOT
        LDA     SLOTIDX
        INR     A
        STA     SLOTIDX
        JMP     PIB_LOOP
PIB_DONE:
        RET

PLACE_BEAST_SLOT:
        STA     CURSLOT
PBS1:
        CALL    RAND_BEAST_COL
        STA     TMPCOL
        MOV     C,A
        CALL    RAND_PLAY_ROW
        STA     TMPROW
        MOV     B,A
        CALL    PEEK_BC
        CPI     SPACECHR
        JNZ     PBS1
        MVI     A,BEASTCHR
        CALL    PLOT_BC

        LDA     CURSLOT
        CALL    GET_SLOT_X_PTR
        LDA     TMPCOL
        MOV     M,A
        LDA     CURSLOT
        CALL    GET_SLOT_Y_PTR
        LDA     TMPROW
        MOV     M,A
        LDA     CURSLOT
        CALL    GET_SLOT_ALIVE_PTR
        MVI     M,1
        LDA     CURSLOT
        CALL    GET_SLOT_STUCK_PTR
        MVI     M,0
        CALL    RAND8
        ANI     0FH
        CPI     06H
        JC      PBS_SET_DUMB
PBS_SET_SMART:
        MVI     B,1
        JMP     PBS_SMART_DONE
PBS_SET_DUMB:
        MVI     B,0
PBS_SMART_DONE:
        LDA     CURSLOT
        CALL    GET_SLOT_SMART_PTR
        MOV     M,B
        LDA     CURSLOT
        CALL    RESET_BEAST_DELAY_SLOT
        RET

MOVE_BEAST_SLOT:
        STA     CURSLOT

        LDA     CURSLOT
        CALL    GET_SLOT_Y_PTR
        MOV     A,M
        STA     CURRY

        LDA     CURSLOT
        CALL    GET_SLOT_X_PTR
        MOV     A,M
        STA     CURRX

        LDA     CURSLOT
        CALL    GET_SLOT_STUCK_PTR
        MOV     A,M
        STA     CURSTK

        LDA     CURSLOT
        CALL    GET_SLOT_SMART_PTR
        MOV     A,M
        STA     CURSMART

        CALL    CHECK_WAKE_BEAST_SLOT
        CALL    MOVE_BEAST_GENERIC
        STA     MOVESLOTRES

        LDA     CURSLOT
        CALL    GET_SLOT_STUCK_PTR
        LDA     CURSTK
        MOV     M,A

        LDA     MOVESLOTRES
        CPI     2
        JNZ     MBS_NOTCAP
        MVI     A,BEASTCHR
        CALL    STORE_DEATH_A_AT_BC
        JMP     PLAYER_KILLED
MBS_NOTCAP:
        CPI     1
        RNZ

        MOV     A,B
        STA     TMPROW
        MOV     A,C
        STA     TMPCOL

        LDA     CURSLOT
        CALL    GET_SLOT_Y_PTR
        LDA     TMPROW
        MOV     M,A

        LDA     CURSLOT
        CALL    GET_SLOT_X_PTR
        LDA     TMPCOL
        MOV     M,A
        RET

CHECK_WAKE_BEAST_SLOT:
        LDA     CURSMART
        ORA     A
        RNZ

        ; if abs(PY-CURRY) >= 3, not near
        LDA     PY
        MOV     D,A
        LDA     CURRY
        SUB     D
        JP      CWBS_ROWPOS
        CMA
        INR     A
CWBS_ROWPOS:
        CPI     03H
        RNC

        ; if abs(PX-CURRX) >= 3, not near
        LDA     PX
        MOV     D,A
        LDA     CURRX
        SUB     D
        JP      CWBS_COLPOS
        CMA
        INR     A
CWBS_COLPOS:
        CPI     03H
        RNC

        ; near enough: wake permanently
        LDA     CURSLOT
        CALL    GET_SLOT_SMART_PTR
        MVI     M,1
        MVI     A,1
        STA     CURSMART
        RET

GET_SLOT_X_PTR:
        LXI     H,BEASTX
        JMP     ADD_INDEX_TO_HL
GET_SLOT_Y_PTR:
        LXI     H,BEASTY
        JMP     ADD_INDEX_TO_HL
GET_SLOT_ALIVE_PTR:
        LXI     H,BEASTALIVE
        JMP     ADD_INDEX_TO_HL
GET_SLOT_SMART_PTR:
        LXI     H,BEASTSMART
        JMP     ADD_INDEX_TO_HL
GET_SLOT_DLO_PTR:
        LXI     H,BEASTDLO
        JMP     ADD_INDEX_TO_HL
GET_SLOT_DHI_PTR:
        LXI     H,BEASTDHI
        JMP     ADD_INDEX_TO_HL
GET_SLOT_STUCK_PTR:
        LXI     H,BEASTSTUCK
        JMP     ADD_INDEX_TO_HL

ADD_INDEX_TO_HL:
        MOV     E,A
        MVI     D,0
        DAD     D
        RET

; ============================================================
; RANDOM PLACEMENT
; ============================================================

PLACE_RANDOM_BLOCKS:
        LDA     BLOCKCOUNT
        MOV     D,A
PRB1:
        CALL    RAND_PLAY_COL
        MOV     C,A
        CALL    RAND_PLAY_ROW
        MOV     B,A
        CALL    PEEK_BC
        CPI     SPACECHR
        JNZ     PRB1
        MVI     A,BLOCKCHR
        CALL    PLOT_BC
        DCR     D
        JNZ     PRB1
        RET

PLACE_RANDOM_TREES:
        LDA     TREECOUNT
        MOV     D,A
PRT1:
        CALL    RAND_PLAY_COL
        MOV     C,A
        CALL    RAND_PLAY_ROW
        MOV     B,A
        CALL    PEEK_BC
        CPI     SPACECHR
        JNZ     PRT1
        MVI     A,TREECHR
        CALL    PLOT_BC
        DCR     D
        JNZ     PRT1
        RET

PLACE_PLAYER:
PPL1:
        CALL    RAND_PLAYER_COL
        STA     PX
        MOV     C,A
        CALL    RAND_PLAY_ROW
        STA     PY
        MOV     B,A
        CALL    PEEK_BC
        CPI     SPACECHR
        JNZ     PPL1
        RET

; ============================================================
; PLAYER MOVE / PUSH
; ============================================================

MOVE_LEFT:
        MVI     A,0FFH
        STA     DX
        MVI     A,00H
        STA     DY
        JMP     DO_PLAYER_MOVE

MOVE_RIGHT:
        MVI     A,01H
        STA     DX
        MVI     A,00H
        STA     DY
        JMP     DO_PLAYER_MOVE

MOVE_UP:
        MVI     A,00H
        STA     DX
        MVI     A,0FFH
        STA     DY
        JMP     DO_PLAYER_MOVE

MOVE_DOWN:
        MVI     A,00H
        STA     DX
        MVI     A,01H
        STA     DY

DO_PLAYER_MOVE:
        LDA     PY
        MOV     B,A
        LDA     PX
        MOV     C,A
        CALL    STEP_BC
        RC

        CALL    PEEK_BC
        CPI     SPACECHR
        JZ      DPM_EMPTY

        CPI     BEASTCHR
        JZ      DPM_HIT_BEAST

        CPI     OMICRONCHR
        JZ      DPM_HIT_POISON

        CPI     INFANTCHR
        JZ      DPM_HIT_POISON

        CPI     BLOCKCHR
        JZ      DPM_PUSH

        RET

DPM_HIT_BEAST:
        CALL    STORE_DEATH_A_AT_BC
        JMP     PLAYER_KILLED

DPM_HIT_POISON:
        CALL    STORE_DEATH_A_AT_BC
        JMP     PLAYER_POISONED

DPM_EMPTY:
        LDA     PY
        MOV     B,A
        LDA     PX
        MOV     C,A
        MVI     A,SPACECHR
        CALL    PLOT_BC

        LDA     PY
        MOV     B,A
        LDA     PX
        MOV     C,A
        CALL    STEP_BC
        MOV     A,B
        STA     PY
        MOV     A,C
        STA     PX
        MVI     A,PLAYERCHR
        CALL    PLOT_BC
        RET

DPM_PUSH:
        CALL    PUSH_CHAIN
        ORA     A
        RZ

        LDA     PY
        MOV     B,A
        LDA     PX
        MOV     C,A
        MVI     A,SPACECHR
        CALL    PLOT_BC

        LDA     PY
        MOV     B,A
        LDA     PX
        MOV     C,A
        CALL    STEP_BC
        MOV     A,B
        STA     PY
        MOV     A,C
        STA     PX
        MVI     A,PLAYERCHR
        CALL    PLOT_BC
        RET

; ============================================================
; PULL MODE (IJKL)
; ALLOWS:
;   - MOVE INTO EMPTY SPACE
;   - OR PUSH ONE BLOCK AHEAD IF SPACE BEYOND IS EMPTY
;   - AND THEN PULL ONE BLOCK FROM BEHIND INTO OLD PLAYER SPACE
; ============================================================

PULL_LEFT:
        MVI     A,0FFH
        STA     DX
        MVI     A,00H
        STA     DY
        CALL    DO_PULL_MOVE
        RET

PULL_RIGHT:
        MVI     A,01H
        STA     DX
        MVI     A,00H
        STA     DY
        CALL    DO_PULL_MOVE
        RET

PULL_UP:
        MVI     A,00H
        STA     DX
        MVI     A,0FFH
        STA     DY
        CALL    DO_PULL_MOVE
        RET

PULL_DOWN:
        MVI     A,00H
        STA     DX
        MVI     A,01H
        STA     DY
        CALL    DO_PULL_MOVE
        RET

DO_PULL_MOVE:
        ; SAVE OLD PLAYER POS
        LDA     PX
        STA     OLDPX
        LDA     PY
        STA     OLDPY

        ; EXAMINE FRONT CELL
        LDA     OLDPY
        MOV     B,A
        LDA     OLDPX
        MOV     C,A
        CALL    STEP_BC
        RC
        MOV     A,B
        STA     FRONTROW
        MOV     A,C
        STA     FRONTCOL

        CALL    PEEK_BC
        CPI     SPACECHR
        JZ      PULL_EMPTY_FRONT

        CPI     BEASTCHR
        JZ      PULL_HIT_BEAST
        CPI     OMICRONCHR
        JZ      PULL_HIT_POISON
        CPI     INFANTCHR
        JZ      PULL_HIT_POISON

        CPI     BLOCKCHR
        JNZ     PULL_FAIL
        JMP     PULL_FRONT_BLOCK

PULL_HIT_BEAST:
        CALL    STORE_DEATH_A_AT_BC
        JMP     PLAYER_KILLED

PULL_HIT_POISON:
        CALL    STORE_DEATH_A_AT_BC
        JMP     PLAYER_POISONED

PULL_FRONT_BLOCK:
        ; FRONT HAS ONE BLOCK. TRY SPACE BEYOND.
        LDA     FRONTROW
        MOV     B,A
        LDA     FRONTCOL
        MOV     C,A
        CALL    STEP_BC
        RC
        MOV     A,B
        STA     BEYONDROW
        MOV     A,C
        STA     BEYONDCOL
        CALL    PEEK_BC
        CPI     SPACECHR
        JZ      PULL_CAN_PUSH
        CPI     OMICRONCHR
        JZ      PULL_SOFT_CRUSH
        CPI     INFANTCHR
        JZ      PULL_LIVING_CRUSH
        CPI     BEASTCHR
        JZ      PULL_LIVING_CRUSH
        JMP     PULL_FAIL

PULL_SOFT_CRUSH:
        CALL    KILL_ENTITY_AT_BC
        JMP     PULL_CAN_PUSH

PULL_LIVING_CRUSH:
        MOV     A,B
        STA     KILLROW
        MOV     A,C
        STA     KILLCOL
        CALL    STEP_BC
        JC      PULL_LIVING_PINNED
        CALL    PEEK_BC
        CPI     BLOCKCHR
        JZ      PULL_LIVING_PINNED
        CPI     TREECHR
        JZ      PULL_LIVING_PINNED
        JMP     PULL_FAIL
PULL_LIVING_PINNED:
        LDA     KILLROW
        MOV     B,A
        LDA     KILLCOL
        MOV     C,A
        CALL    KILL_ENTITY_AT_BC

PULL_CAN_PUSH:
        MVI     A,1
        STA     FRONTPUSH
        JMP     PULL_GO

PULL_EMPTY_FRONT:
        XRA     A
        STA     FRONTPUSH

PULL_GO:
        ; ERASE OLD PLAYER
        LDA     OLDPY
        MOV     B,A
        LDA     OLDPX
        MOV     C,A
        MVI     A,SPACECHR
        CALL    PLOT_BC

        ; IF FRONT PUSH, DRAW BLOCK AT BEYOND
        LDA     FRONTPUSH
        ORA     A
        JZ      PULL_NOBLOCKAHEAD

        LDA     BEYONDROW
        MOV     B,A
        LDA     BEYONDCOL
        MOV     C,A
        MVI     A,BLOCKCHR
        CALL    PLOT_BC

PULL_NOBLOCKAHEAD:
        ; MOVE PLAYER INTO FRONT CELL
        LDA     FRONTROW
        STA     PY
        LDA     FRONTCOL
        STA     PX
        MOV     C,A
        LDA     PY
        MOV     B,A
        MVI     A,PLAYERCHR
        CALL    PLOT_BC

        ; CHECK BEHIND OLD PLAYER POSITION
        LDA     OLDPY
        MOV     B,A
        LDA     OLDPX
        MOV     C,A
        CALL    STEP_BACK_BC

        ; Safety: rear cell must be inside playable arena.
        ; Prevents border/panel graphics from ever being pulled as blocks.
        MOV     A,C
        CPI     PLAY_L
        RC
        CPI     PLAY_RP1
        RNC
        MOV     A,B
        CPI     PLAY_T
        RC
        CPI     PLAY_BP1
        RNC

        CALL    PEEK_BC
        CPI     BLOCKCHR
        RNZ

        ; if any beast adjacent to rear block, do not pull it
        CALL    BLOCK_HAS_ADJ_BEAST
        ORA     A
        RNZ

        ; ERASE REAR BLOCK
        LDA     OLDPY
        MOV     B,A
        LDA     OLDPX
        MOV     C,A
        CALL    STEP_BACK_BC
        MVI     A,SPACECHR
        CALL    PLOT_BC

        ; MOVE REAR BLOCK INTO OLD PLAYER POSITION
        LDA     OLDPY
        MOV     B,A
        LDA     OLDPX
        MOV     C,A
        MVI     A,BLOCKCHR
        CALL    PLOT_BC
        RET

PULL_FAIL:
        RET

; ============================================================
; PUSH CHAIN OF BLOCKS
; Adjacent target block is one step from player in DX/DY.
; Returns A=1 success, A=0 fail.
; ============================================================

PUSH_CHAIN:
        LDA     PY
        MOV     B,A
        LDA     PX
        MOV     C,A
        CALL    STEP_BC
        MOV     A,B
        STA     FIRSTROW
        MOV     A,C
        STA     FIRSTCOL

        MOV     A,B
        STA     SCANROW
        MOV     A,C
        STA     SCANCOL

PCS1:
        LDA     SCANROW
        MOV     B,A
        LDA     SCANCOL
        MOV     C,A
        CALL    STEP_BC
        JC      PCFAIL
        MOV     A,B
        STA     SCANROW
        MOV     A,C
        STA     SCANCOL
        CALL    PEEK_BC
        CPI     BLOCKCHR
        JZ      PCS1

        CPI     SPACECHR
        JZ      PCTARGET_OK

        CPI     OMICRONCHR
        JZ      PCTARGET_SOFT

        CPI     INFANTCHR
        JZ      PCTARGET_LIVING

        CPI     BEASTCHR
        JZ      PCTARGET_LIVING

        JMP     PCFAIL

PCTARGET_SOFT:
        CALL    KILL_ENTITY_AT_BC
        JMP     PCTARGET_OK

PCTARGET_LIVING:
        MOV     A,B
        STA     KILLROW
        MOV     A,C
        STA     KILLCOL

        CALL    STEP_BC
        JC      PCTARGET_LIVING_CRUSH

        CALL    PEEK_BC
        CPI     BLOCKCHR
        JZ      PCTARGET_LIVING_CRUSH
        CPI     TREECHR
        JZ      PCTARGET_LIVING_CRUSH
        JMP     PCFAIL

PCTARGET_LIVING_CRUSH:
        LDA     KILLROW
        MOV     B,A
        LDA     KILLCOL
        MOV     C,A
        CALL    KILL_ENTITY_AT_BC

PCTARGET_OK:
        MOV     A,B
        STA     DESTROW
        MOV     A,C
        STA     DESTCOL

PCSHIFT:
        LDA     DESTROW
        MOV     B,A
        LDA     DESTCOL
        MOV     C,A
        CALL    STEP_BACK_BC
        MOV     A,B
        STA     SRCROW
        MOV     A,C
        STA     SRCCOL

        LDA     DESTROW
        MOV     B,A
        LDA     DESTCOL
        MOV     C,A
        MVI     A,BLOCKCHR
        CALL    PLOT_BC

        LDA     SRCROW
        MOV     B,A
        LDA     FIRSTROW
        CMP     B
        JNZ     PCMORE
        LDA     SRCCOL
        MOV     B,A
        LDA     FIRSTCOL
        CMP     B
        JNZ     PCMORE

        LDA     FIRSTROW
        MOV     B,A
        LDA     FIRSTCOL
        MOV     C,A
        MVI     A,SPACECHR
        CALL    PLOT_BC
        MVI     A,1
        RET

PCMORE:
        LDA     SRCROW
        STA     DESTROW
        LDA     SRCCOL
        STA     DESTCOL
        JMP     PCSHIFT

PCFAIL:
        XRA     A
        RET

; ============================================================
; ENTITY KILL / ROUND WIN
; ============================================================

KILL_ENTITY_AT_BC:
        PUSH    B
        CALL    KILL_BEAST_AT_BC
        POP     B

        PUSH    B
        CALL    KILL_EGG_AT_BC
        POP     B

        MVI     A,SPACECHR
        CALL    PLOT_BC
        RET

KILL_BEAST_AT_BC:
        MOV     A,B
        STA     KILLROW
        MOV     A,C
        STA     KILLCOL
        XRA     A
        STA     SLOTIDX
KBC_LOOP:
        LDA     SLOTIDX
        MOV     B,A
        MVI     A,MAXBEAST
        CMP     B
        JZ      KBC_DONE

        MOV     A,B
        CALL    GET_SLOT_ALIVE_PTR
        MOV     A,M
        ORA     A
        JZ      KBC_NEXT

        MOV     A,B
        CALL    GET_SLOT_Y_PTR
        MOV     A,M
        MOV     E,A
        LDA     KILLROW
        CMP     E
        JNZ     KBC_NEXT

        MOV     A,B
        CALL    GET_SLOT_X_PTR
        MOV     A,M
        MOV     E,A
        LDA     KILLCOL
        CMP     E
        JNZ     KBC_NEXT

        MOV     A,B
        CALL    GET_SLOT_ALIVE_PTR
        MVI     M,0

        CALL    SHOW_SMASH_FLASH
        CALL    CHECK_ROUND_CLEAR
        RET

KBC_NEXT:
        LDA     SLOTIDX
        INR     A
        STA     SLOTIDX
        JMP     KBC_LOOP
KBC_DONE:
        RET

KILL_EGG_AT_BC:
        XRA     A
        STA     EGGIDX

KEC_LOOP:
        LDA     EGGIDX
        CPI     6
        JNC     KEC_DONE

        LDA     EGGIDX
        CALL    GET_EGG_STATE_PTR
        MOV     A,M
        ORA     A
        JZ      KEC_NEXT

        LDA     EGGIDX
        CALL    GET_EGG_Y_PTR
        MOV     A,M
        CMP     B
        JNZ     KEC_NEXT

        LDA     EGGIDX
        CALL    GET_EGG_X_PTR
        MOV     A,M
        CMP     C
        JNZ     KEC_NEXT

        LDA     EGGIDX
        CALL    GET_EGG_STATE_PTR
        XRA     A
        MOV     M,A
        CALL    SHOW_SMASH_FLASH
        CALL    CHECK_ROUND_CLEAR
        RET

KEC_NEXT:
        LDA     EGGIDX
        INR     A
        STA     EGGIDX
        JMP     KEC_LOOP

KEC_DONE:
        RET

GET_EGG_STATE_PTR:
        LXI     H,EGGSTATETAB
        JMP     GET_EGG_PTR_FROM_TABLE

GET_EGG_X_PTR:
        LXI     H,EGGXTAB
        JMP     GET_EGG_PTR_FROM_TABLE

GET_EGG_Y_PTR:
        LXI     H,EGGYTAB

GET_EGG_PTR_FROM_TABLE:
        ADD     A
        MOV     E,A
        MVI     D,0
        DAD     D
        MOV     E,M
        INX     H
        MOV     D,M
        XCHG
        RET

CHECK_ROUND_CLEAR:
        XRA     A
        STA     SLOTIDX
CRC_LOOP:
        LDA     SLOTIDX
        MOV     B,A
        MVI     A,MAXBEAST
        CMP     B
        JZ      CRC_CLEAR
        MOV     A,B
        CALL    GET_SLOT_ALIVE_PTR
        MOV     A,M
        ORA     A
        JNZ     CRCRET
        LDA     SLOTIDX
        INR     A
        STA     SLOTIDX
        JMP     CRC_LOOP

CRC_CLEAR:
        MVI     A,1
        STA     ROUNDWIN
CRCRET:
        RET

; ============================================================
; EGG / INFANT SYSTEM
;   state 0=none 1=egg 2=infant
; ============================================================

SPAWN_EGG1:
        XRA     A
        STA     EGGIDX
        JMP     SPAWN_EGG_COMMON

SPAWN_EGG2:
        MVI     A,1
        STA     EGGIDX
        JMP     SPAWN_EGG_COMMON

SPAWN_EGG3:
        MVI     A,2
        STA     EGGIDX
        JMP     SPAWN_EGG_COMMON

SPAWN_EGG4:
        MVI     A,3
        STA     EGGIDX
        JMP     SPAWN_EGG_COMMON

SPAWN_EGG5:
        MVI     A,4
        STA     EGGIDX
        JMP     SPAWN_EGG_COMMON

SPAWN_EGG6:
        MVI     A,5
        STA     EGGIDX

SPAWN_EGG_COMMON:
        LDA     EGGIDX
        CALL    GET_SLOT_ALIVE_PTR
        MOV     A,M
        ORA     A
        RZ

        LDA     EGGIDX
        CALL    GET_SLOT_X_PTR
        MOV     A,M
        STA     ANCHX

        LDA     EGGIDX
        CALL    GET_SLOT_Y_PTR
        MOV     A,M
        STA     ANCHY

        CALL    FIND_EGG_NEAR_ANCHOR
        JNC     SEC_FOUND
        CALL    FIND_EGG_ANYWHERE
        RC

SEC_FOUND:
        MOV     A,C
        PUSH    B
        MOV     B,A
        LDA     EGGIDX
        CALL    GET_EGG_X_PTR
        MOV     M,B
        POP     B

        MOV     A,B
        PUSH    B
        MOV     B,A
        LDA     EGGIDX
        CALL    GET_EGG_Y_PTR
        MOV     M,B
        POP     B

        MVI     A,OMICRONCHR
        CALL    PLOT_BC

        LDA     EGGIDX
        CALL    GET_EGG_STATE_PTR
        MVI     M,1

        CALL    RANDOM_EGG_DELAY
        MOV     D,B
        LDA     EGGIDX
        CALL    GET_EGG_TLO_PTR
        MOV     M,A
        LDA     EGGIDX
        CALL    GET_EGG_THI_PTR
        MOV     M,D

        LDA     EGGIDX
        CPI     1
        JZ      SEC_ADD200
        CPI     2
        JZ      SEC_ADD400
        RET

SEC_ADD200:
        LDA     EGGIDX
        CALL    GET_EGG_TLO_PTR
        MOV     A,M
        ADI     0C8H
        MOV     M,A
        LDA     EGGIDX
        CALL    GET_EGG_THI_PTR
        MOV     A,M
        ACI     00H
        MOV     M,A
        RET

SEC_ADD400:
        LDA     EGGIDX
        CALL    GET_EGG_TLO_PTR
        MOV     A,M
        ADI     090H
        MOV     M,A
        LDA     EGGIDX
        CALL    GET_EGG_THI_PTR
        MOV     A,M
        ACI     01H
        MOV     M,A
        RET

UPDATE_EGGS:
        XRA     A
        STA     EGGIDX

UE_LOOP:
        LDA     EGGIDX
        CPI     6
        JNC     UE_DONE
        CALL    UPDATE_ONE_EGG
        LDA     EGGIDX
        INR     A
        STA     EGGIDX
        JMP     UE_LOOP

UE_DONE:
        RET

UPDATE_ONE_EGG:
        LDA     EGGIDX
        CALL    GET_EGG_STATE_PTR
        MOV     A,M
        ORA     A
        RZ

        CALL    DEC_EGG_TIMER

UOE_POSTDEC:
        RNZ

        LDA     EGGIDX
        CALL    GET_EGG_STATE_PTR
        MOV     A,M
        CPI     1
        JZ      UOE_TO_INFANT
        CPI     2
        JZ      UOE_TO_BEAST
        RET

UOE_TO_INFANT:
        LDA     EGGIDX
        CALL    GET_EGG_Y_PTR
        MOV     B,M
        LDA     EGGIDX
        CALL    GET_EGG_X_PTR
        MOV     C,M
        MVI     A,INFANTCHR
        CALL    PLOT_BC

        LDA     EGGIDX
        CALL    GET_EGG_STATE_PTR
        MVI     M,2

        CALL    RANDOM_INFANT_DELAY
        MOV     D,B
        LDA     EGGIDX
        CALL    GET_EGG_TLO_PTR
        MOV     M,A
        LDA     EGGIDX
        CALL    GET_EGG_THI_PTR
        MOV     M,D
        RET

UOE_TO_BEAST:
        CALL    FIND_FREE_BEAST_SLOT
        JC      UOE_RETRY

        LDA     EGGIDX
        CALL    GET_EGG_Y_PTR
        MOV     B,M
        LDA     EGGIDX
        CALL    GET_EGG_X_PTR
        MOV     C,M
        MVI     A,BEASTCHR
        CALL    PLOT_BC
        CALL    WRITE_FREE_BEAST_FROM_BC

        LDA     EGGIDX
        CALL    GET_EGG_STATE_PTR
        XRA     A
        MOV     M,A

        CALL    RESET_DELAY_FOR_FREE_BEAST
        RET

UOE_RETRY:
        MOV     D,B
        LDA     EGGIDX
        CALL    GET_EGG_TLO_PTR
        MOV     M,A
        LDA     EGGIDX
        CALL    GET_EGG_THI_PTR
        MOV     M,D
        RET

GET_EGG_TLO_PTR:
        LXI     H,EGGTLOTAB
        JMP     GET_EGG_PTR_FROM_TABLE

GET_EGG_THI_PTR:
        LXI     H,EGGTHITAB
        JMP     GET_EGG_PTR_FROM_TABLE

DEC_EGG_TIMER:
        LDA     EGGIDX
        CALL    GET_EGG_TLO_PTR
        MOV     A,M
        ORA     A
        JNZ     DET_DECLO

        LDA     EGGIDX
        CALL    GET_EGG_THI_PTR
        MOV     A,M
        ORA     A
        RZ
        DCR     A
        MOV     M,A

        LDA     EGGIDX
        CALL    GET_EGG_TLO_PTR
        MVI     M,0FFH
        MVI     A,1
        ORA     A
        RET

DET_DECLO:
        DCR     A
        MOV     M,A
        MVI     A,1
        ORA     A
        RET

FIND_FREE_BEAST_SLOT:
        XRA     A
        STA     SLOTIDX
FFBS_LOOP:
        LDA     SLOTIDX
        MOV     B,A
        MVI     A,MAXBEAST
        CMP     B
        JZ      FFBS_NONE
        MOV     A,B
        CALL    GET_SLOT_ALIVE_PTR
        MOV     A,M
        ORA     A
        JZ      FFBS_FOUND
        LDA     SLOTIDX
        INR     A
        STA     SLOTIDX
        JMP     FFBS_LOOP
FFBS_FOUND:
        LDA     SLOTIDX
        STA     FREEBSLOT
        ORA     A
        RET
FFBS_NONE:
        STC
        RET

WRITE_FREE_BEAST_FROM_BC:
        LDA     FREEBSLOT
        STA     CURSLOT
        CALL    GET_SLOT_X_PTR
        MOV     M,C
        LDA     CURSLOT
        CALL    GET_SLOT_Y_PTR
        MOV     M,B
        LDA     CURSLOT
        CALL    GET_SLOT_ALIVE_PTR
        MVI     M,1
        LDA     CURSLOT
        CALL    GET_SLOT_STUCK_PTR
        MVI     M,0
        CALL    RAND8
        ANI     0FH
        CPI     06H
        JC      WFB_SET_DUMB
WFB_SET_SMART:
        MVI     B,1
        JMP     WFB_SMART_DONE
WFB_SET_DUMB:
        MVI     B,0
WFB_SMART_DONE:
        LDA     CURSLOT
        CALL    GET_SLOT_SMART_PTR
        MOV     M,B
        RET

RESET_DELAY_FOR_FREE_BEAST:
        LDA     FREEBSLOT
        JMP     RESET_BEAST_DELAY_SLOT

FIND_EGG_NEAR_ANCHOR:
        MVI     D,32
FEN1:
        CALL    RAND8
        ANI     07H
        STA     OFFX
        CALL    RAND8
        ANI     07H
        STA     OFFY

        ; build candidate C from ANCHX +/- (0..3)
        LDA     ANCHX
        MOV     C,A
        LDA     OFFX
        ANI     03H
        MOV     E,A
        LDA     OFFX
        ANI     04H
        JZ      FENPX
        MOV     A,C
        SUB     E
        MOV     C,A
        JMP     FENY
FENPX:
        MOV     A,C
        ADD     E
        MOV     C,A

FENY:
        LDA     ANCHY
        MOV     B,A
        LDA     OFFY
        ANI     03H
        MOV     E,A
        LDA     OFFY
        ANI     04H
        JZ      FENPY
        MOV     A,B
        SUB     E
        MOV     B,A
        JMP     FENCHECK
FENPY:
        MOV     A,B
        ADD     E
        MOV     B,A

FENCHECK:
        MOV     A,C
        CPI     PLAY_L
        JC      FENNEXT
        CPI     PLAY_RP1
        JNC     FENNEXT
        MOV     A,B
        CPI     PLAY_T
        JC      FENNEXT
        CPI     PLAY_BP1
        JNC     FENNEXT

        ; do not place on or adjacent to anchor beast
        LDA     ANCHY
        SUB     B
        JNC     FENABSY
        CMA
        INR     A
FENABSY:
        CPI     2
        JNC     FENSPACE
        LDA     ANCHX
        SUB     C
        JNC     FENABSX
        CMA
        INR     A
FENABSX:
        CPI     2
        JC      FENNEXT

FENSPACE:
        CALL    PEEK_BC
        CPI     SPACECHR
        JNZ     FENNEXT
        ORA     A
        RET

FENNEXT:
        DCR     D
        JNZ     FEN1
        STC
        RET


FIND_EGG_ANYWHERE:
        MVI     D,64
FEA1:
        CALL    RAND_PLAY_COL
        MOV     C,A
        CALL    RAND_PLAY_ROW
        MOV     B,A
        CALL    PEEK_BC
        CPI     SPACECHR
        JZ      FEAOK
        DCR     D
        JNZ     FEA1
        STC
        RET
FEAOK:
        ORA     A
        RET

RANDOM_EGG_DELAY:
RED1:
        CALL    RAND8
        CPI     180
        JNC     RED1
        MOV     E,A
        MVI     B,06H        ; base = 06D6h = 1750
        MVI     A,0D6H
        ADD     E            ; 1750..1929
        JNC     RED2
        INR     B
RED2:
        RET

RANDOM_INFANT_DELAY:
RID1:
        CALL    RAND8
        CPI     90
        JNC     RID1
        MOV     E,A
        MVI     B,03H        ; base = 03E8h = 1000
        MVI     A,0E8H
        ADD     E            ; 1000..1089
        JNC     RID2
        INR     B
RID2:
        RET

RANDOM_RETRY_DELAY:
RRD1:
        CALL    RAND8
        CPI     121
        JNC     RRD1
        MOV     E,A
        MVI     B,0
        MVI     A,60
        ADD     E
        JNC     RRD2
        INR     B
RRD2:
        RET

; ============================================================
; PULL SAFETY
; ============================================================

BLOCK_HAS_ADJ_BEAST:
        ; preserve caller movement vector because LOAD_ADJ_DELTA reuses DX/DY
        LDA     DX
        STA     SAVEDX
        LDA     DY
        STA     SAVEDY

        MOV     A,B
        STA     CHKROW
        MOV     A,C
        STA     CHKCOL

        XRA     A
        STA     ADJINDEX
        MVI     A,8
        STA     ADJCOUNT

BHAB_LOOP:
        LDA     ADJINDEX
        CALL    LOAD_ADJ_DELTA

        LDA     CHKROW
        MOV     B,A
        LDA     CHKCOL
        MOV     C,A
        CALL    STEP_BC
        JC      BHAB_NEXT

        CALL    PEEK_BC
        CPI     BEASTCHR
        JZ      BHAB_YES

BHAB_NEXT:
        LDA     ADJINDEX
        INR     A
        ANI     07H
        STA     ADJINDEX

        LDA     ADJCOUNT
        DCR     A
        STA     ADJCOUNT
        JNZ     BHAB_LOOP

        ; restore caller movement vector
        LDA     SAVEDX
        STA     DX
        LDA     SAVEDY
        STA     DY
        XRA     A
        RET

BHAB_YES:
        ; restore caller movement vector
        LDA     SAVEDX
        STA     DX
        LDA     SAVEDY
        STA     DY
        MVI     A,1
        RET

; ============================================================
; BEAST MOVEMENT
; RETURNS FROM GENERIC:
;   A=0 NO MOVE
;   A=1 MOVED
;   A=2 CAPTURE
; ============================================================

MOVE_BEAST_GENERIC:
        ; COMPUTE PREFERRED DX
        LDA     PX
        MOV     D,A
        LDA     CURRX
        CMP     D
        JZ      MBGDX0
        JC      MBGDXP
        MVI     A,0FFH
        STA     PREFDX
        JMP     MBGDY

MBGDXP:
        MVI     A,01H
        STA     PREFDX
        JMP     MBGDY

MBGDX0:
        XRA     A
        STA     PREFDX

MBGDY:
        ; COMPUTE PREFERRED DY
        LDA     PY
        MOV     D,A
        LDA     CURRY
        CMP     D
        JZ      MBGDY0
        JC      MBGDYP
        MVI     A,0FFH
        STA     PREFDY
        JMP     MBGTRY

MBGDYP:
        MVI     A,01H
        STA     PREFDY
        JMP     MBGTRY

MBGDY0:
        XRA     A
        STA     PREFDY

MBGTRY:
        ; SMART BEASTS: if diagonal and at least one cardinal move are both legal,
        ; randomly choose between diagonal and cardinal pursuit.
        LDA     CURSMART
        ORA     A
        JZ      MBGCARD
        LDA     PREFDX
        ORA     A
        JZ      MBGCARD
        LDA     PREFDY
        ORA     A
        JZ      MBGCARD

        ; Probe diagonal
        LDA     PREFDX
        STA     DX
        LDA     PREFDY
        STA     DY
        CALL    CAN_BEAST_STEP
        STA     DIAGSTAT

        ; Probe horizontal
        LDA     PREFDX
        STA     DX
        XRA     A
        STA     DY
        CALL    CAN_BEAST_STEP
        STA     HORZSTAT

        ; Probe vertical
        XRA     A
        STA     DX
        LDA     PREFDY
        STA     DY
        CALL    CAN_BEAST_STEP
        STA     VERTSTAT

        ; If diagonal legal and any cardinal legal, choose randomly.
        LDA     DIAGSTAT
        ORA     A
        JZ      MBGCARD
        LDA     HORZSTAT
        ORA     A
        JNZ     MBGCHOOSE
        LDA     VERTSTAT
        ORA     A
        JZ      MBGCARD

MBGCHOOSE:
        CALL    RAND8
        ANI     01H
        JZ      MBGDIAGGO

        ; Cardinal branch: pick between available horizontal/vertical.
        LDA     HORZSTAT
        ORA     A
        JZ      MBGVERTGO
        LDA     VERTSTAT
        ORA     A
        JZ      MBGHORZGO
        CALL    RAND8
        ANI     01H
        JZ      MBGHORZGO
        JMP     MBGVERTGO

MBGDIAGGO:
        LDA     PREFDX
        STA     DX
        LDA     PREFDY
        STA     DY
        CALL    TRY_BEAST_STEP
        CPI     2
        RZ
        CPI     1
        JZ      MBGMOVED
        JMP     MBGCARD

MBGHORZGO:
        LDA     PREFDX
        STA     DX
        XRA     A
        STA     DY
        CALL    TRY_BEAST_STEP
        CPI     2
        RZ
        CPI     1
        JZ      MBGMOVED
        JMP     MBGCARD

MBGVERTGO:
        LDA     PREFDY
        STA     DY
        XRA     A
        STA     DX
        CALL    TRY_BEAST_STEP
        CPI     2
        RZ
        CPI     1
        JZ      MBGMOVED
        JMP     MBGCARD

MBGCARD:
        ; TRY HORIZONTAL
        LDA     PREFDX
        ORA     A
        JZ      MBGVERTONLY
        STA     DX
        XRA     A
        STA     DY
        CALL    TRY_BEAST_STEP
        CPI     2
        RZ
        CPI     1
        JZ      MBGMOVED

MBGVERTONLY:
        ; TRY VERTICAL
        LDA     PREFDY
        ORA     A
        JZ      MBGSTUCK
        STA     DY
        XRA     A
        STA     DX
        CALL    TRY_BEAST_STEP
        CPI     2
        RZ
        CPI     1
        JZ      MBGMOVED

MBGSTUCK:
        ; INCREMENT STUCK COUNTER
        LDA     CURSTK
        INR     A
        STA     CURSTK

        CPI     3
        JC      MBGNOMOVE

        ; 50% CHANCE TO TRY RANDOM ADJACENT
        CALL    RAND8
        ANI     01H
        JZ      MBGNOMOVE

        CALL    TRY_RANDOM_ADJACENT
        CPI     2
        RZ
        CPI     1
        JZ      MBGMOVED

MBGNOMOVE:
        XRA     A
        RET

MBGMOVED:
        XRA     A
        STA     CURSTK
        MVI     A,1
        RET

; ============================================================
; PROBE BEAST STEP WITHOUT MOVING
; USES DX,DY
; RETURNS A=0 blocked, A=1 legal empty move, A=2 capture
; ============================================================

CAN_BEAST_STEP:
        LDA     CURRY
        MOV     B,A
        LDA     CURRX
        MOV     C,A
        CALL    STEP_BC
        JC      CBSFAIL

        CALL    OTHER_BEAST_AT_BC
        ORA     A
        JNZ     CBSFAIL

CBSCELL:
        CALL    PEEK_BC
        CPI     PLAYERCHR
        JZ      CBSCAP
        CPI     SPACECHR
        JZ      CBSOK

CBSFAIL:
        XRA     A
        RET

CBSOK:
        MVI     A,1
        RET

CBSCAP:
        MVI     A,2
        RET
; ============================================================
; TRY RANDOM ADJACENT
; RETURNS A=0/1/2
; ============================================================

TRY_RANDOM_ADJACENT:
        CALL    RAND8
        ANI     07H
        STA     ADJINDEX
        MVI     A,8
        STA     ADJCOUNT

TRALP:
        LDA     ADJINDEX
        CALL    LOAD_ADJ_DELTA

        CALL    TRY_BEAST_STEP
        CPI     2
        RZ
        CPI     1
        RZ

        LDA     ADJINDEX
        INR     A
        ANI     07H
        STA     ADJINDEX

        LDA     ADJCOUNT
        DCR     A
        STA     ADJCOUNT
        JNZ     TRALP

        XRA     A
        RET

; A = 0..7
; LOADS DX,DY FROM TABLES
LOAD_ADJ_DELTA:
        MOV     E,A
        MVI     D,0

        LXI     H,ADJDXTAB
        DAD     D
        MOV     A,M
        STA     DX

        MOV     A,E
        MOV     E,A
        MVI     D,0
        LXI     H,ADJDYTAB
        DAD     D
        MOV     A,M
        STA     DY
        RET

; ============================================================
; TRY BEAST STEP
; USES DX,DY
; RETURNS:
;   A=0 FAIL, BC RESTORED TO ORIGINAL
;   A=1 MOVED, BC = NEW POSITION
;   A=2 CAPTURE
; ============================================================

TRY_BEAST_STEP:
        LDA     CURRY
        MOV     B,A
        LDA     CURRX
        MOV     C,A

        PUSH    B
        CALL    STEP_BC
        JC      TBSFAIL_RESTORE

        MOV     A,B
        STA     TMPROW
        MOV     A,C
        STA     TMPCOL

        CALL    OTHER_BEAST_AT_BC
        ORA     A
        JNZ     TBSFAIL_RESTORE

        CALL    PEEK_BC
        CPI     PLAYERCHR
        JZ      TBSCAPTURE
        CPI     SPACECHR
        JNZ     TBSFAIL_RESTORE

        ; ERASE OLD
        LDA     CURRY
        MOV     B,A
        LDA     CURRX
        MOV     C,A
        MVI     A,SPACECHR
        CALL    PLOT_BC

        ; DRAW NEW
        LDA     TMPROW
        MOV     B,A
        LDA     TMPCOL
        MOV     C,A
        MVI     A,BEASTCHR
        CALL    PLOT_BC

        POP     D
        MVI     A,1
        RET

TBSCAPTURE:
        POP     B
        MVI     A,2
        RET

TBSFAIL_RESTORE:
        POP     B
        XRA     A
        RET

OTHER_BEAST_AT_BC:
        MOV     A,B
        STA     TMPROW
        MOV     A,C
        STA     TMPCOL
        XRA     A
        STA     OTHSLOTIDX
OBC_LOOP:
        LDA     OTHSLOTIDX
        MOV     E,A
        MVI     A,MAXBEAST
        CMP     E
        JZ      OBC_NO

        LDA     CURSLOT
        CMP     E
        JZ      OBC_NEXT

        MOV     A,E
        CALL    GET_SLOT_ALIVE_PTR
        MOV     A,M
        ORA     A
        JZ      OBC_NEXT

        MOV     A,E
        CALL    GET_SLOT_Y_PTR
        MOV     A,M
        MOV     D,A
        LDA     TMPROW
        CMP     D
        JNZ     OBC_NEXT

        MOV     A,E
        CALL    GET_SLOT_X_PTR
        MOV     A,M
        MOV     D,A
        LDA     TMPCOL
        CMP     D
        JNZ     OBC_NEXT

        MVI     A,1
        RET

OBC_NEXT:
        LDA     OTHSLOTIDX
        INR     A
        STA     OTHSLOTIDX
        JMP     OBC_LOOP

OBC_NO:
        XRA     A
        RET

; ============================================================
; STEP HELPERS
; STEP_BC uses DX,DY and enforces playfield bounds.
; CY=1 on failure, else B,C updated.
; STEP_BACK_BC applies inverse of DX,DY (no bounds check).
; ============================================================

STEP_BC:
        ; X
        LDA     DX
        ORA     A
        JZ      SBY
        CPI     0FFH
        JZ      SBXNEG

        INR     C
        MOV     A,C
        CPI     PLAY_RP1
        JNC     SBFAIL
        JMP     SBY

SBXNEG:
        MOV     A,C
        CPI     PLAY_L
        JZ      SBFAIL
        JC      SBFAIL
        DCR     C

SBY:
        LDA     DY
        ORA     A
        JZ      SBOK
        CPI     0FFH
        JZ      SBYNEG

        INR     B
        MOV     A,B
        CPI     PLAY_BP1
        JNC     SBFAIL
        JMP     SBOK

SBYNEG:
        MOV     A,B
        CPI     PLAY_T
        JZ      SBFAIL
        JC      SBFAIL
        DCR     B

SBOK:
        ORA     A
        RET

SBFAIL:
        STC
        RET

STEP_BACK_BC:
        LDA     DX
        CPI     01H
        JZ      SBBXNEG
        CPI     0FFH
        JZ      SBBXPOS
        JMP     SBBY

SBBXNEG:
        DCR     C
        JMP     SBBY

SBBXPOS:
        INR     C

SBBY:
        LDA     DY
        CPI     01H
        JZ      SBBYNEG
        CPI     0FFH
        JZ      SBBYPOS
        RET

SBBYNEG:
        DCR     B
        RET

SBBYPOS:
        INR     B
        RET

; ============================================================
; ATTRACT PANEL
; COLUMNS 61 AND 62, ROWS 2..13
; BRAIDED SEMIGRAPHICS WITH PHASE + STYLE VARIATION
; ============================================================

; ============================================================
; ATTRACT PANEL
; 4 HAND-AUTHORED FRAMES
; FULL HEIGHT, COLS 60..63, ROWS 0..15
; ============================================================

; ============================================================
; ATTRACT PANEL
; 4 HAND-AUTHORED FRAMES
; FULL HEIGHT, COLS 60..63, ROWS 0..15
; ============================================================


DRAW_LEFT_PANEL_FROM_HL:
        MVI     B,0
DLP_ROW:
        MVI     C,0
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,1
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,2
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,3
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        INR     B
        MOV     A,B
        CPI     16
        JC      DLP_ROW
        RET

DRAW_RIGHT_PANEL_FROM_HL:
        MVI     B,0
DRP_ROW:
        MVI     C,60
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,61
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,62
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,63
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        INR     B
        MOV     A,B
        CPI     16
        JC      DRP_ROW
        RET

CLEAR_LEFT_PANEL:
        MVI     B,0
CLP_ROW:
        MVI     C,0
        MVI     A,SPACECHR
        CALL    PLOT_BC
        INR     C
        CALL    PLOT_BC
        INR     C
        CALL    PLOT_BC
        INR     C
        CALL    PLOT_BC

        INR     B
        MOV     A,B
        CPI     16
        JC      CLP_ROW
        RET

DRAW_BOTH_EVENT_PANELS:
        SHLD    EVENTPTR
        CALL    DRAW_LEFT_PANEL_FROM_HL
        LHLD    EVENTPTR
        CALL    DRAW_RIGHT_PANEL_FROM_HL
        RET

WAIT_N_TICKS:
        ; Software timing stand-in for the POLY-88 60Hz counter.
        ; B = approximate count. This is deliberately simple for first port.
        MOV     D,B
WNT_OUTER:
        LXI     H,0700H
WNT_INNER:
        DCX     H
        MOV     A,H
        ORA     L
        JNZ     WNT_INNER
        CALL    FRAME_TICK_FAST
        DCR     D
        JNZ     WNT_OUTER
        RET

STORE_DEATH_A_AT_BC:
        STA     DEATHCHR
        MOV     A,C
        STA     DEATHX
        MOV     A,B
        STA     DEATHY
        RET

DRAW_DEATH_SOURCE:
        LDA     DEATHY
        MOV     B,A
        LDA     DEATHX
        MOV     C,A
        LDA     DEATHCHR
        CALL    PLOT_BC
        RET

ERASE_DEATH_SOURCE:
        LDA     DEATHY
        MOV     B,A
        LDA     DEATHX
        MOV     C,A
        MVI     A,SPACECHR
        CALL    PLOT_BC
        RET

HOLD_EVENT_GRAPHIC:
        LDA     DEATHCHR
        ORA     A
        JZ      HEG_PLAIN

        MVI     A,16
        STA     HOLDCTR
HEG_LOOP:
        CALL    DRAW_DEATH_SOURCE
        MVI     B,4
        CALL    WAIT_N_TICKS
        CALL    ERASE_DEATH_SOURCE
        MVI     B,4
        CALL    WAIT_N_TICKS
        LDA     HOLDCTR
        DCR     A
        STA     HOLDCTR
        JNZ     HEG_LOOP
        RET

HEG_PLAIN:
        MVI     B,128
        CALL    WAIT_N_TICKS
        RET

SHOW_SMASH_FLASH:
        LXI     H,SMASHGRX
        CALL    DRAW_LEFT_PANEL_FROM_HL
        MVI     A,1
        STA     LEFTPANELMODE
        MVI     A,17
        STA     SMASHTMR
        RET


DRAW_COUNTDOWN_DIGIT:
        ; A already holds display code for digit
        MOV     D,A
        LDA     PY
        MOV     B,A
        LDA     PX
        MOV     C,A
        MOV     A,D
        CALL    PLOT_BC
        RET

ROUND_START_COUNTDOWN:
        ; 3 flashes 3 times, same total duration as 2 and 1
        MVI     A,033H
        CALL    DRAW_COUNTDOWN_DIGIT
        MVI     B,6
        CALL    WAIT_N_TICKS
        CALL    CLEAR_COUNTDOWN_DIGIT
        MVI     B,6
        CALL    WAIT_N_TICKS
        MVI     A,033H
        CALL    DRAW_COUNTDOWN_DIGIT
        MVI     B,6
        CALL    WAIT_N_TICKS
        CALL    CLEAR_COUNTDOWN_DIGIT
        MVI     B,6
        CALL    WAIT_N_TICKS
        MVI     A,033H
        CALL    DRAW_COUNTDOWN_DIGIT
        MVI     B,6
        CALL    WAIT_N_TICKS

        ; 2 flashes 2 times, same total duration
        MVI     A,032H
        CALL    DRAW_COUNTDOWN_DIGIT
        MVI     B,8
        CALL    WAIT_N_TICKS
        CALL    CLEAR_COUNTDOWN_DIGIT
        MVI     B,8
        CALL    WAIT_N_TICKS
        MVI     A,032H
        CALL    DRAW_COUNTDOWN_DIGIT
        MVI     B,8
        CALL    WAIT_N_TICKS

        ; 1 shows once for same total duration
        MVI     A,031H
        CALL    DRAW_COUNTDOWN_DIGIT
        MVI     B,24
        CALL    WAIT_N_TICKS

        LDA     PY
        MOV     B,A
        LDA     PX
        MOV     C,A
        MVI     A,PLAYERCHR
        CALL    PLOT_BC
        RET

CLEAR_COUNTDOWN_DIGIT:
        LDA     PY
        MOV     B,A
        LDA     PX
        MOV     C,A
        MVI     A,SPACECHR
        CALL    PLOT_BC
        RET

UPDATE_SMASH_FLASH:
        LDA     LEFTPANELMODE
        CPI     1
        RNZ
        LDA     SMASHTMR
        ORA     A
        RZ
        DCR     A
        STA     SMASHTMR
        RNZ
        CALL    CLEAR_LEFT_PANEL
        XRA     A
        STA     LEFTPANELMODE
        RET

DRAW_WINLEFT_FROM_HL:
        MVI     B,0
DWL_ROW:
        MVI     C,0
        MOV     A,M
        PUSH    H
        LDA     WININVFLAG
        ORA     A
        POP     H
        MOV     A,M
        JZ      DWL_P0
        XRI     3FH
DWL_P0:
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,1
        PUSH    H
        LDA     WININVFLAG
        ORA     A
        POP     H
        MOV     A,M
        JZ      DWL_P1
        XRI     3FH
DWL_P1:
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,2
        PUSH    H
        LDA     WININVFLAG
        ORA     A
        POP     H
        MOV     A,M
        JZ      DWL_P2
        XRI     3FH
DWL_P2:
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,3
        PUSH    H
        LDA     WININVFLAG
        ORA     A
        POP     H
        MOV     A,M
        JZ      DWL_P3
        XRI     3FH
DWL_P3:
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        INR     B
        MOV     A,B
        CPI     16
        JC      DWL_ROW
        RET

DRAW_WINRIGHT_FROM_HL:
        MVI     B,0
DWR_ROW:
        MVI     C,60
        PUSH    H
        LDA     WININVFLAG
        ORA     A
        POP     H
        MOV     A,M
        JZ      DWR_P0
        XRI     3FH
DWR_P0:
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,61
        PUSH    H
        LDA     WININVFLAG
        ORA     A
        POP     H
        MOV     A,M
        JZ      DWR_P1
        XRI     3FH
DWR_P1:
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,62
        PUSH    H
        LDA     WININVFLAG
        ORA     A
        POP     H
        MOV     A,M
        JZ      DWR_P2
        XRI     3FH
DWR_P2:
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,63
        PUSH    H
        LDA     WININVFLAG
        ORA     A
        POP     H
        MOV     A,M
        JZ      DWR_P3
        XRI     3FH
DWR_P3:
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        INR     B
        MOV     A,B
        CPI     16
        JC      DWR_ROW
        RET

DRAW_WIN_PANELS:
        LXI     H,WINLEFTGRX
        CALL    DRAW_WINLEFT_FROM_HL
        LXI     H,WINRIGHTGRX
        CALL    DRAW_WINRIGHT_FROM_HL
        RET

SHOW_WIN_FLASH:
        XRA     A
        STA     WININVFLAG
        CALL    DRAW_WIN_PANELS
        MVI     B,4
        CALL    WAIT_N_TICKS

        MVI     A,1
        STA     WININVFLAG
        CALL    DRAW_WIN_PANELS
        MVI     B,5
        CALL    WAIT_N_TICKS

        XRA     A
        STA     WININVFLAG
        CALL    DRAW_WIN_PANELS
        MVI     B,7
        CALL    WAIT_N_TICKS

        MVI     A,1
        STA     WININVFLAG
        CALL    DRAW_WIN_PANELS
        MVI     B,10
        CALL    WAIT_N_TICKS

        XRA     A
        STA     WININVFLAG
        CALL    DRAW_WIN_PANELS
        MVI     B,14
        CALL    WAIT_N_TICKS

        XRA     A
        STA     WININVFLAG
        CALL    DRAW_WIN_PANELS
        MVI     B,19
        CALL    WAIT_N_TICKS

        XRA     A
        STA     WININVFLAG
        CALL    DRAW_WIN_PANELS
        MVI     B,25
        CALL    WAIT_N_TICKS

        RET

UPDATE_ATTRACT:
        RET


DRAW_ATTRACT_PANEL:
        LDA     ATTRSTYLE
        ORA     A
        JZ      DAP_USE1
        LXI     H,ATTRSTATIC2
        JMP     DAP_START
DAP_USE1:
        LXI     H,ATTRSTATIC
DAP_START:
        MVI     B,0

DAP_ROW:
        MVI     C,60
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,61
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,62
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        MVI     C,63
        MOV     A,M
        PUSH    H
        CALL    PLOT_ART_BC
        POP     H
        INX     H

        INR     B
        MOV     A,B
        CPI     16
        JNZ     DAP_ROW
        RET

; ============================================================
; SCREEN HELPERS
; ============================================================


; Plot semigraphic art table byte in POLY/VTI 00H-3FH format.
; This lets the TRS-80 build keep the same .DB art tables as the POLY-88 build.
; B=row, C=col, A=POLY semigraphic byte 00H-3FH.
PLOT_ART_BC:
        CALL    MAP_POLY_SEMI_TO_TRS
        PUSH    PSW
        CALL    GETADDR_BC
        POP     PSW
        MOV     M,A
        RET

; A = POLY/VTI 2x3 semigraphic 00H-3FH
; Returns A = inverted TRS-80 Model I semigraphic screen code C0H-FFH.
; Test mapping assumes:
;   POLY bit layout: 20 04 / 10 02 / 08 01
;   TRS bit layout:  01 02 / 04 08 / 10 20
MAP_POLY_SEMI_TO_TRS:
        ANI     03FH
        MOV     E,A
        MVI     D,0
        LXI     H,POLY_TO_TRS_SEMI
        DAD     D
        MOV     A,M
        RET

POLY_TO_TRS_SEMI:
        DB      0FFH,0DFH,0F7H,0D7H,0FDH,0DDH,0F5H,0D5H
        DB      0EFH,0CFH,0E7H,0C7H,0EDH,0CDH,0E5H,0C5H
        DB      0FBH,0DBH,0F3H,0D3H,0F9H,0D9H,0F1H,0D1H
        DB      0EBH,0CBH,0E3H,0C3H,0E9H,0C9H,0E1H,0C1H
        DB      0FEH,0DEH,0F6H,0D6H,0FCH,0DCH,0F4H,0D4H
        DB      0EEH,0CEH,0E6H,0C6H,0ECH,0CCH,0E4H,0C4H
        DB      0FAH,0DAH,0F2H,0D2H,0F8H,0D8H,0F0H,0D0H
        DB      0EAH,0CAH,0E2H,0C2H,0E8H,0C8H,0E0H,0C0H

PLOT_BC:
        PUSH    PSW
        CALL    GETADDR_BC
        POP     PSW
        CALL    TRS80_CHARMAP
        MOV     M,A
        RET

; Translate old POLY/VTI-ish display codes to TRS-80 Model I.
; Normal PLOT_BC must preserve direct TRS-80 screen codes.
; POLY 2x3 art bytes are converted only by PLOT_ART_BC, not here.
; - 00H-7FH are treated as direct TRS-80 text/symbol codes
; - 80H-FFH are treated as direct TRS-80 graphics/symbol codes
; This is important because BLOCKCHR = FFH is a real solid block.
TRS80_CHARMAP:
        RET

PEEK_BC:
        PUSH    H
        CALL    GETADDR_BC
        MOV     A,M
        POP     H
        RET

GETADDR_BC:
        PUSH    D
        LXI     H,ROWTAB
        MOV     A,B
        ADD     A
        MOV     E,A
        MVI     D,0
        DAD     D
        MOV     E,M
        INX     H
        MOV     D,M
        XCHG
        MOV     E,C
        MVI     D,0
        DAD     D
        POP     D
        RET

CLEAR_SCREEN:
        LXI     H,VBASE
        MVI     A,SPACECHR
        MVI     B,4
CLSOUT:
        MVI     C,0
CLSIN:
        MOV     M,A
        INX     H
        DCR     C
        JNZ     CLSIN
        DCR     B
        JNZ     CLSOUT
        RET

DRAW_BORDER:
        ; TOP -- draw only between the vertical border columns.
        ; This keeps the original POLY border glyphs but removes
        ; the one-cell overhang at the arena corners.
        MVI     B,BORDER_T
        MVI     C,BORDER_L
DBTOP:
        MVI     A,BORDERTOPCHR
        CALL    PLOT_ART_BC
        INR     C
        MOV     A,C
        CPI     BORDER_RP1
        JNZ     DBTOP

        ; BOTTOM -- same extents as TOP.
        MVI     B,BORDER_B
        MVI     C,BORDER_L
DBBOT:
        MVI     A,BORDERBOTCHR
        CALL    PLOT_ART_BC
        INR     C
        MOV     A,C
        CPI     BORDER_RP1
        JNZ     DBBOT

        ; LEFT (skip corner rows)
        MVI     C,BORDER_L
        MVI     B,PLAY_T
DBLEFT:
        MVI     A,BORDERLEFTCHR
        CALL    PLOT_ART_BC
        INR     B
        MOV     A,B
        CPI     PLAY_BP1
        JNZ     DBLEFT

        ; RIGHT (skip corner rows)
        MVI     C,BORDER_R
        MVI     B,PLAY_T
DBRIGHT:
        MVI     A,BORDERRIGHTCHR
        CALL    PLOT_ART_BC
        INR     B
        MOV     A,B
        CPI     PLAY_BP1
        JNZ     DBRIGHT

        ; CORNERS LAST
        MVI     B,BORDER_T
        MVI     C,BORDER_L
        MVI     A,BORDERTLCHR
        CALL    PLOT_ART_BC

        MVI     B,BORDER_T
        MVI     C,BORDER_R
        MVI     A,BORDERTRCHR
        CALL    PLOT_ART_BC

        MVI     B,BORDER_B
        MVI     C,BORDER_L
        MVI     A,BORDERBLCHR
        CALL    PLOT_ART_BC

        MVI     B,BORDER_B
        MVI     C,BORDER_R
        MVI     A,BORDERBRCHR
        CALL    PLOT_ART_BC
        RET

DRAW_ROUND:
        MVI     B,0
        MVI     C,4
        LXI     H,ROUNDTXT
        CALL    PUTSTR_BC

        ; 3 DIGITS
        LDA     ROUNDNO
        STA     TMPVAL
        XRA     A
        STA     HUNDS
        STA     TENS

DRH100:
        LDA     TMPVAL
        CPI     100
        JC      DRT10
        SUI     100
        STA     TMPVAL
        LDA     HUNDS
        INR     A
        STA     HUNDS
        JMP     DRH100

DRT10:
        LDA     TMPVAL
        CPI     10
        JC      DRONES
        SUI     10
        STA     TMPVAL
        LDA     TENS
        INR     A
        STA     TENS
        JMP     DRT10

DRONES:
        LDA     HUNDS
        ORA     A
        JZ      DRHBL
        ADI     030H
        CALL    PLOT_BC
        JMP     DRTENS

DRHBL:
        MVI     A,SPACECHR
        CALL    PLOT_BC

DRTENS:
        INR     C
        LDA     HUNDS
        ORA     A
        JNZ     DRTSHW
        LDA     TENS
        ORA     A
        JZ      DRTBL

DRTSHW:
        LDA     TENS
        ADI     030H
        CALL    PLOT_BC
        JMP     DRLAST

DRTBL:
        MVI     A,SPACECHR
        CALL    PLOT_BC

DRLAST:
        INR     C
        LDA     TMPVAL
        ADI     030H
        CALL    PLOT_BC
        RET

DRAW_TITLE:
        RET

DRAW_LEGEND:
        MVI     B,0
        MVI     C,22

        ; PLAYER
        MVI     A,PLAYERCHR
        CALL    PLOT_BC
        INR     C
        MVI     A,SPACECHR
        CALL    PLOT_BC
        INR     C
        LXI     H,LEGTXT_PLAYER
        CALL    PUTSTR_BC
        MVI     C,31

        ; BEAST
        MVI     A,BEASTCHR
        CALL    PLOT_BC
        INR     C
        MVI     A,SPACECHR
        CALL    PLOT_BC
        INR     C
        LXI     H,LEGTXT_BEAST
        CALL    PUTSTR_BC
        MVI     C,39

        ; TREE
        MVI     A,TREECHR
        CALL    PLOT_BC
        INR     C
        MVI     A,SPACECHR
        CALL    PLOT_BC
        INR     C
        LXI     H,LEGTXT_TREE
        CALL    PUTSTR_BC
        MVI     C,46

        ; BLOCK
        MVI     A,BLOCKCHR
        CALL    PLOT_BC
        INR     C
        MVI     A,SPACECHR
        CALL    PLOT_BC
        INR     C
        LXI     H,LEGTXT_BLOCK
        CALL    PUTSTR_BC
        MVI     C,54

        ; EGG
        MVI     A,OMICRONCHR
        CALL    PLOT_BC
        INR     C
        MVI     A,SPACECHR
        CALL    PLOT_BC
        INR     C
        LXI     H,LEGTXT_EGGS
        CALL    PUTSTR_BC
        RET

LEGTXT_PLAYER:  DB      'PLAYER',0
LEGTXT_BEAST:   DB      'BEAST',0
LEGTXT_TREE:    DB      'TREE',0
LEGTXT_BLOCK:   DB      'BLOCK',0
LEGTXT_EGGS:    DB      'EGG',0
DRAW_UI:
        MVI     B,15

        ; WASD: MOVE
        MVI     C,4
        LXI     H,CTRLTXT_WASD
        CALL    PUTSTR_BC

        ; IJKL: PULL
        MVI     C,17
        LXI     H,CTRLTXT_IJKL
        CALL    PUTSTR_BC

        ; Plain TRS-80 credit: beast by Xiphod - APRIL 2026
        MVI     C,31
        LXI     H,CREDITTXT
        CALL    PUTSTR_BC
        RET

ROUNDTXT:
        DB      'ROUND: ',0
CTRLTXT_WASD:
        DB      'WASD: MOVE',0
CTRLTXT_IJKL:
        DB      'IJKL: PULL',0
CREDITTXT:
        DB      'beast by Xiphod - APRIL 2026',0
; ============================================================
; RNG
; ============================================================

RAND8:
        CALL    FRAME_TICK_FAST
        LDA     RNGSTATE
        MOV     B,A
        LDA     TICKLO
        XRA     B
        RRC
        XRA     B
        ADI     037H
        STA     RNGSTATE
        RET

RAND_PLAY_COL:
RPC1:
        CALL    RAND8
        ANI     03FH
        CPI     54
        JNC     RPC1
        ADI     PLAY_L
        RET

RAND_PLAY_ROW:
RPR1:
        CALL    RAND8
        ANI     00FH
        CPI     12
        JNC     RPR1
        ADI     PLAY_T
        RET

RAND_PLAYER_COL:
RPLC1:
        CALL    RAND8
        ANI     01FH
        CPI     20
        JNC     RPLC1
        ADI     7
        RET

RAND_BEAST_COL:
        ; expected right-side spawn columns: 38..56 inclusive
RBEC1:
        CALL    RAND8
        ANI     01FH
        CPI     19
        JNC     RBEC1
        ADI     38
        RET

RANDOM_BLOCK_COUNT:
RBCC1:
        CALL    RAND8
        ANI     07H
        CPI     07H
        JNC     RBCC1
        ADI     18
        RET

RANDOM_TREE_COUNT:
RTCC1:
        CALL    RAND8
        ANI     07H
        CPI     07H
        JNC     RTCC1
        ADI     8
        RET

EVENTPTR:        DW      0
SMASHTMR:        DB      0
LEFTPANELMODE:   DB      0
DEATHX:          DB      0
DEATHY:          DB      0
DEATHCHR:        DB      0
HOLDCTR:         DB      0
WININVFLAG:      DB      0
EGGIDX:          DB      0

EGGSTATETAB:
        DW      E1STATE,E2STATE,E3STATE,E4STATE,E5STATE,E6STATE
EGGXTAB:
        DW      E1X,E2X,E3X,E4X,E5X,E6X
EGGYTAB:
        DW      E1Y,E2Y,E3Y,E4Y,E5Y,E6Y
EGGTLOTAB:
        DW      E1TLO,E2TLO,E3TLO,E4TLO,E5TLO,E6TLO
EGGTHITAB:
        DW      E1THI,E2THI,E3THI,E4THI,E5THI,E6THI

; ============================================================
; TABLES
; ============================================================

; Adjacent move tables for beast unstick (8 directions)
ADJDXTAB:
        DB      0FFH,00H,01H,0FFH,01H,0FFH,00H,01H
ADJDYTAB:
        DB      0FFH,0FFH,0FFH,00H,00H,01H,01H,01H

; Semigraphics braid patterns.
; 0x7F = blank graphics char
; Lower values light selected 2x3 cells.


ROWTAB:
        DW      VBASE+0*64
        DW      VBASE+1*64
        DW      VBASE+2*64
        DW      VBASE+3*64
        DW      VBASE+4*64
        DW      VBASE+5*64
        DW      VBASE+6*64
        DW      VBASE+7*64
        DW      VBASE+8*64
        DW      VBASE+9*64
        DW      VBASE+10*64
        DW      VBASE+11*64
        DW      VBASE+12*64
        DW      VBASE+13*64
        DW      VBASE+14*64
        DW      VBASE+15*64

WINLEFTGRX:
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      00H,3FH,3FH,00H
        DB      19H,08H,01H,0BH
        DB      3FH,39H,0FH,3FH
        DB      34H,24H,24H,26H
        DB      00H,3FH,3FH,00H
        DB      08H,24H,24H,01H
        DB      36H,3FH,3FH,36H
        DB      00H,3FH,3FH,00H
        DB      08H,24H,24H,01H
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH

WINRIGHTGRX:
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      24H,3FH,3FH,24H
        DB      00H,3CH,27H,00H
        DB      19H,09H,09H,0BH
        DB      3EH,36H,36H,37H
        DB      3BH,18H,03H,1FH
        DB      39H,09H,09H,0FH
        DB      36H,37H,3FH,36H
        DB      00H,08H,26H,00H
        DB      09H,3FH,1BH,09H
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH

ATTRSTATIC:
        DB      3FH,3FH,3FH,3FH
        DB      3CH,2DH,2CH,27H
        DB      38H,3AH,15H,07H
        DB      38H,32H,14H,07H
        DB      3CH,2DH,2DH,27H
        DB      38H,3AH,00H,07H
        DB      39H,2DH,2DH,0FH
        DB      38H,1AH,13H,07H
        DB      38H,3CH,27H,07H
        DB      3AH,12H,12H,17H
        DB      38H,3DH,2DH,07H
        DB      38H,12H,16H,07H
        DB      3CH,2DH,2DH,27H
        DB      38H,27H,3CH,07H
        DB      38H,06H,30H,07H
        DB      3FH,3FH,3FH,3FH

ATTRSTATIC2:
        DB      3FH,3FH,3FH,3FH
        DB      03H,12H,13H,18H
        DB      07H,05H,2AH,38H
        DB      07H,0DH,2BH,38H
        DB      03H,12H,12H,18H
        DB      07H,05H,3FH,38H
        DB      06H,12H,12H,30H
        DB      07H,25H,2CH,38H
        DB      07H,03H,18H,38H
        DB      05H,2DH,2DH,28H
        DB      07H,02H,12H,38H
        DB      07H,2DH,29H,38H
        DB      03H,12H,12H,18H
        DB      07H,18H,03H,38H
        DB      07H,39H,0FH,38H
        DB      1BH,1BH,1BH,1BH

SMASHGRX:
        DB      3FH,3FH,3FH,3FH
        DB      3EH,36H,36H,3FH
        DB      39H,2DH,2CH,3FH
        DB      3BH,1BH,1BH,3FH
        DB      3CH,2CH,2CH,3FH
        DB      38H,3BH,38H,3FH
        DB      3FH,3FH,3FH,3FH
        DB      38H,1BH,18H,3FH
        DB      38H,1BH,18H,3FH
        DB      3FH,3FH,3FH,3FH
        DB      38H,12H,12H,3FH
        DB      3DH,2DH,29H,3FH
        DB      3EH,3FH,3EH,3FH
        DB      38H,2DH,28H,3FH
        DB      3BH,3FH,3BH,3FH
        DB      3FH,3FH,3FH,3FH

DEADGRX:
        DB      01H,09H,08H,00H
        DB      07H,3EH,37H,18H
        DB      07H,39H,0FH,38H
        DB      06H,36H,34H,00H
        DB      03H,1BH,1BH,00H
        DB      07H,3BH,1BH,00H
        DB      07H,3BH,1BH,00H
        DB      01H,09H,09H,00H
        DB      07H,3CH,3FH,00H
        DB      07H,3EH,3FH,00H
        DB      04H,20H,24H,00H
        DB      07H,3FH,3BH,08H
        DB      07H,38H,07H,38H
        DB      07H,3FH,3EH,20H
        DB      00H,00H,00H,00H
        DB      00H,00H,00H,00H

POISONGRX:
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      35H,2DH,2DH,37H
        DB      07H,0FH,0FH,07H
        DB      15H,22H,25H,17H
        DB      39H,2DH,29H,3FH
        DB      15H,2DH,2DH,17H
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
        DB      3FH,3FH,3FH,3FH
; ============================================================
; STATE
; ============================================================

LASTTICK:       DB      0
TIMERLO:        DB      0       ; RAM shadow tick for old code paths
TICKLO:         DB      0       ; software low tick
TICKHI:         DB      0
RNGSTATE:       DB      05AH
MOVECTR:        DB      0       ; player/key movement entropy counter
HEADPOS:        DB      0
TAILPOS:        DB      0
ROUNDNO:        DB      0
ROUNDWIN:       DB      0
BLOCKCOUNT:     DB      0
TREECOUNT:      DB      0

PX:             DB      0
PY:             DB      0
OLDPX:          DB      0
OLDPY:          DB      0

FRONTROW:       DB      0
FRONTCOL:       DB      0
BEYONDROW:      DB      0
BEYONDCOL:      DB      0
FRONTPUSH:      DB      0

BEASTLIMIT:     DB      NUMBEAST
CURBEASTS:      DB      0
SLOTIDX:        DB      0
OTHSLOTIDX:     DB      0
CURSLOT:        DB      0
MOVESLOTRES:    DB      0
LIMITTMP:       DB      0

BEASTX:         DB      0,0,0,0,0,0,0,0,0,0,0,0
BEASTY:         DB      0,0,0,0,0,0,0,0,0,0,0,0
BEASTALIVE:     DB      0,0,0,0,0,0,0,0,0,0,0,0
BEASTSMART:     DB      0,0,0,0,0,0,0,0,0,0,0,0
BEASTDLO:       DB      0,0,0,0,0,0,0,0,0,0,0,0
BEASTDHI:       DB      0,0,0,0,0,0,0,0,0,0,0,0
BEASTSTUCK:     DB      0,0,0,0,0,0,0,0,0,0,0,0

B1X             EQU     BEASTX+0
B2X             EQU     BEASTX+1
B3X             EQU     BEASTX+2
B4X             EQU     BEASTX+3
B5X             EQU     BEASTX+4
B6X             EQU     BEASTX+5
B1Y             EQU     BEASTY+0
B2Y             EQU     BEASTY+1
B3Y             EQU     BEASTY+2
B4Y             EQU     BEASTY+3
B5Y             EQU     BEASTY+4
B6Y             EQU     BEASTY+5
B1ALIVE         EQU     BEASTALIVE+0
B2ALIVE         EQU     BEASTALIVE+1
B3ALIVE         EQU     BEASTALIVE+2
B4ALIVE         EQU     BEASTALIVE+3
B5ALIVE         EQU     BEASTALIVE+4
B6ALIVE         EQU     BEASTALIVE+5
B1SMART         EQU     BEASTSMART+0
B2SMART         EQU     BEASTSMART+1
B3SMART         EQU     BEASTSMART+2
B4SMART         EQU     BEASTSMART+3
B5SMART         EQU     BEASTSMART+4
B6SMART         EQU     BEASTSMART+5
B1DLO           EQU     BEASTDLO+0
B2DLO           EQU     BEASTDLO+1
B3DLO           EQU     BEASTDLO+2
B4DLO           EQU     BEASTDLO+3
B5DLO           EQU     BEASTDLO+4
B6DLO           EQU     BEASTDLO+5
B1DHI           EQU     BEASTDHI+0
B2DHI           EQU     BEASTDHI+1
B3DHI           EQU     BEASTDHI+2
B4DHI           EQU     BEASTDHI+3
B5DHI           EQU     BEASTDHI+4
B6DHI           EQU     BEASTDHI+5
B1STUCK         EQU     BEASTSTUCK+0
B2STUCK         EQU     BEASTSTUCK+1
B3STUCK         EQU     BEASTSTUCK+2
B4STUCK         EQU     BEASTSTUCK+3
B5STUCK         EQU     BEASTSTUCK+4
B6STUCK         EQU     BEASTSTUCK+5

CURSTK:         DB      0
CURSMART:       DB      0

PLYTMR:         DB      0
LASTKEY:        DB      0

DX:             DB      0
DY:             DB      0
PREFDX:         DB      0
PREFDY:         DB      0

FIRSTROW:       DB      0
FIRSTCOL:       DB      0
SCANROW:        DB      0
SCANCOL:        DB      0
DESTROW:        DB      0
DESTCOL:        DB      0
SRCROW:         DB      0
SRCCOL:         DB      0

CURRY:          DB      0
CURRX:          DB      0
OTHRY:          DB      0
OTHRX:          DB      0
OTHRY2:         DB      0
OTHRX2:         DB      0
OTHRY3:         DB      0
OTHRX3:         DB      0
OTHRY4:         DB      0
OTHRX4:         DB      0
OTHRY5:         DB      0
OTHRX5:         DB      0
TMPROW:         DB      0
TMPCOL:         DB      0

ADJINDEX:       DB      0
ADJCOUNT:       DB      0
DIAGSTAT:       DB      0
HORZSTAT:       DB      0
VERTSTAT:       DB      0
SAVEDX:         DB      0
SAVEDY:         DB      0
CHKROW:         DB      0
CHKCOL:         DB      0
KILLROW:        DB      0
KILLCOL:        DB      0

E1X:            DB      0
E1Y:            DB      0
E1STATE:        DB      0
E1TLO:          DB      0
E1THI:          DB      0

E2X:            DB      0
E2Y:            DB      0
E2STATE:        DB      0
E2TLO:          DB      0
E2THI:          DB      0

E3X:            DB      0
E3Y:            DB      0
E3STATE:        DB      0
E3TLO:          DB      0
E3THI:          DB      0
E4X:            DB      0
E4Y:            DB      0
E4STATE:        DB      0
E4TLO:          DB      0
E4THI:          DB      0
E5X:            DB      0
E5Y:            DB      0
E5STATE:        DB      0
E5TLO:          DB      0
E5THI:          DB      0
E6X:            DB      0
E6Y:            DB      0
E6STATE:        DB      0
E6TLO:          DB      0
E6THI:          DB      0

FREEBSLOT:      DB      0
ANCHX:          DB      0
ANCHY:          DB      0
OFFX:           DB      0
OFFY:           DB      0

ATTRPHASE:      DB      0
ATTRSTYLE:      DB      0

TMPVAL:         DB      0
HUNDS:          DB      0
TENS:           DB      0

BEASTRES1:      DB      0
BEASTRES2:      DB      0
BEASTRES3:      DB      0
BEASTRES4:      DB      0
BEASTRES5:      DB      0
BEASTRES6:      DB      0



        END     START
