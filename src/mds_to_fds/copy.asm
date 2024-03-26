; Copyright (C) 2024 Robin Sergeant
;
; CP/M utility to copy system tracks from 5.25" A: drive to 8" B:drive.
;
; Patch for FDS systems when all data is in memory (at 0x1000) by setting a 
; breakpoint at the indicated location (see BREAKPOINT comment in src below).
; Mame debugger commands for patching are given here.
;
; do b@0x1f49 = 'F'
; do b@0x1f4b = 0xFF
;
; This terminates the boot message after the 2nd row to make room for a new
; 15 byte DPB table, and replaces "/M" with "/F" in the message.
;
; do b@0x103B = #27
; do b@0x1f96 = #27
;
; This makes the cold and warm boot loaders switch tracks after reading
; 26 sectors, rather than 16.
;
; do b@0x1ebd = 0xCC
; do b@0x1ecd = 0xCC
; do b@0x1edd = 0xCC
; do b@0x1eed = 0xCC
;
; This changes the DPB location from 0xDB83 to 0xDBCC in the disk parameter
; table (necessary because the XLT table for 8" drives is larger and so
; overwrites part of the original DPB which follows it in memory).
;
; load {path_to_files}/xlt.bin,1ef3
; load {path_to_files}/dpb.bin,1f4c
;
; This installs the new XLT and DPB data (bin files in zip).
;

BDOS:       equ 0x0005
FN_PRINT:   equ 9
FN_OUT:     equ 2

org 0x100

        ld hl, (0x0001)             ; fetch address of WBOOT jump vector
        ld bc, 24                   ; add 24 to get address of SELDSK jump vector
        add hl, bc
        ld (seldsk), hl             ; then add 3 to get address of SETTRK etc.
        ld bc, 3
        add hl, bc
        ld (settrk), hl
        add hl, bc
        ld (setsec), hl
        add hl, bc
        ld (setdma), hl
        add hl, bc
        ld (read), hl
        add hl, bc
        ld (write), hl

        ld de, read_msg
        ld c, FN_PRINT
        call BDOS

        ld c, 0                     ; call SELDSK for drive A:
        ld hl, (seldsk)
        call bios        

        ld a, 36                    ; 36 sectors need to be copied
        ld (sectors_left), a

loopr:  ld bc, (dma_buffer)         ; set DMA buffer
        ld hl, (setdma)
        call bios

        ld bc, (current_track)      ; set current track
        ld hl, (settrk)
        call bios

        ld bc, (current_sector)     ; set current sector
        ld hl, (setsec)
        call bios

        ld hl, (read)               ; read 128 byte sector from disk
        call bios

        ld e, '.'                   ; show a progress dot
        ld c, FN_OUT
        call BDOS

        ld hl, (dma_buffer)         ; move buffer forward 128 bytes
        ld bc, 128
        add hl, bc
        ld (dma_buffer), hl

        ld hl, current_sector       ; sector = sector + 1
        inc (hl)
        ld a, 17                    ; check for track rollover (16 sectors per track)
        cp (hl)
        jr nz, nextr
        ld (hl), 1                  ; rollover (reset sector count and increase track count)
        ld hl, current_track
        inc (hl)
nextr:  ld hl, sectors_left         ; check if there are any more sectors to read
        dec (hl)
        jr nz, loopr        

        ld de, write_msg            ; all data is now in memory
        ld c, FN_PRINT
        call BDOS                   ; set BREAKPOINT here to patch

        ld c, 1                     ; call SELDSK for drive B:
        ld hl, (seldsk)
        call bios        

        ld a, 36                    ; 36 sectors need to be copied
        ld (sectors_left), a

        xor a                       ; reset track, sector and buffer positions
        ld (current_track), a
        inc a
        ld (current_sector), a
        ld hl, 0x1000
        ld (dma_buffer), hl

loopw:  ld bc, (dma_buffer)         ; now repeat the loop to write back the data
        ld hl, (setdma)
        call bios

        ld bc, (current_track)
        ld hl, (settrk)
        call bios

        ld bc, (current_sector)
        ld hl, (setsec)
        call bios

        ld hl, (write)              ; write 128 byte sector from disk
        call bios

        ld e, '.'
        ld c, FN_OUT
        call BDOS

        ld hl, (dma_buffer)
        ld bc, 128
        add hl, bc
        ld (dma_buffer), hl

        ld hl, current_sector
        inc (hl)
        ld a, 27                    ; check for track rollover (now 26 sectors per track)
        cp (hl)
        jr nz, nextw
        ld (hl), 1
        ld hl, current_track
        inc (hl)
nextw:  ld hl, sectors_left         ; check if there are any more sectors to write
        dec (hl)
        jr nz, loopw

        ld de, done_msg             ; all done!
        ld c, FN_PRINT
        call BDOS

        ret

bios:   jp (hl)

seldsk:         defw 0x0000
settrk:         defw 0x0000
setsec:         defw 0x0000
setdma:         defw 0x0000
read:           defw 0x0000
write:          defw 0x0000

current_track:  defw 0x0000
current_sector: defw 0x0001
dma_buffer:     defw 0x1000
sectors_left:   defb 0

read_msg:       defm "Reading system tracks from A:$"
write_msg:      defm 13,"Writing system tracks to B:$"
done_msg:       defm 13,"System tracks successfully copied$"
