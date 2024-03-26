; Copyright (C) 2024 Robin Sergeant
;
; CP/M utility to patch the disk parameter table for an 8" B: drive
;
; New XLT and DPB tables for this drive are installed into memory that
; is normally reserved for drive D: CSV and ALV buffers.  Therefore,
; drive D: should not be used after running this program!
;
; This has been tested with "Release 1.1/M 56K CP/M vers 2.2C" using an
; emulator, and should work with other releases provided the ALV buffers
; are large enough (>= 26 bytes).
;
; To use on a real RM 380Z the FD-1771 square wave clock frequency would
; also need to be changed somehow (it must be 2 MHz for 8" drive timing)

BDOS:       equ 0x0005
FN_PRINT:   equ 9

DPH_LEN:    equ 16
XLT_LEN:    equ 26  ; 26 sectors
DPB_LEN:    equ 15
XLT_OFFSET: equ 0
DPB_OFFSET: equ 10
CSV_OFFSET: equ 12
ALV_OFFSET: equ 14
CSV_INDEX:  equ (3 * DPH_LEN) + CSV_OFFSET
ALV_INDEX:  equ (3 * DPH_LEN) + ALV_OFFSET
XLT_INDEX:  equ (1 * DPH_LEN) + XLT_OFFSET
DPB_INDEX:  equ (1 * DPH_LEN) + DPB_OFFSET

org 0x100

        ld hl, (0x0001)             ; fetch address of WBOOT jump vector
        ld bc, 24                   ; add 24 to get address of SELDSK jump vector
        add hl, bc
        ld bc, cont                 ; push return address to stack
        push bc
        ld c, 0                     ; call SELDSK for drive 0
        jp (hl)
cont:   push hl
        pop ix                      ; ix now points to start of disk parameter table

        ld e, (ix + ALV_INDEX)      ; load drive D: ALV buffer address into de
        ld d, (ix + ALV_INDEX+1)
        ld (ix + XLT_INDEX), e      ; now use this address as the drive B: XLT
        ld (ix + XLT_INDEX+1), d
        ld hl, xlt_data             ; copy new sector translation table
        ld bc, XLT_LEN
        ldir

        ld e, (ix + CSV_INDEX)      ; load drive D: CSV buffer address into de
        ld d, (ix + CSV_INDEX+1)
        ld (ix + DPB_INDEX), e      ; now use this as the drive B: DPB
        ld (ix + DPB_INDEX+1), d
        ld hl, dpb_data             ; copy new DPB data
        ld bc, DPB_LEN
        ldir        

        ld de, msg                  ; all done!
        ld c, FN_PRINT
        call BDOS

        ret

msg:        defm "8 inch disk parameters installed for B:$"

xlt_data:   defb 1, 7, 13, 19, 25
            defb 5, 11, 17, 23
            defb 3, 9, 15, 21
            defb 2, 8, 14, 20, 26
            defb 6, 12, 18, 24
            defb 4, 10, 16, 22

dpb_data:   defb 0x1A, 0x00, 0x03, 0x07, 0x00, 0xF2, 0x00, 0x3F, 0x00, 0xC0, 0x00, 0x10, 0x00, 0x02, 0x00
