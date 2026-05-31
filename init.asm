; init.asm
; 
; The general idea behind this code came from conversations with
; Christian Krenner, author of Space Chase for CBM-II. 
; 
; It's a really clever way of initializing code that runs in
; an execution bank other than 15 on CBM-II machines.
;
; Take a look at start.bas to see how it works:
;
;   bload "init.prg", b15, p1024   ; $0400 in bank 15
;   bload "init.prg", b1,  p1024   ; $0400 in bank 1 (same code, both banks)
;   bload "game.prg", b1,  p2048   ; $0800 in bank 1
;   sys 1024                        ; enter at $0400, executing in bank 15
;
; Why init is loaded into bank 15 and bank 1:
;   The moment we write the execution-bank register ($00), the very next
;   instruction fetch comes from the new bank. So the instruction that flips
;   $00 to bank 1 and every instruction after it until we JMP into the game
;   must exist at the identical address in bank 1 too. Loading init into
;   both banks guarantees the switch-over code is valid on both sides.

* = $0400

; kernal entry points (called only while exec-bank = 15)
GFXON   = $E24D          ; enable graphics mode
CHROUT  = $FFD2          ; kernal char out (used by our LCHROT wrapper)
SCNKEY  = $FF9F          ; kernal keyboard scan (used by our LSCNKY wrapper)
GETIN   = $FFE4          ; kernal GET

KEYDOWN = $06FD          ; last-key debounce byte (bank 1 RAM)
GAME    = $0800          ; entry point of the game body in bank 1

; START runs first, executing in BANK 15 due to SYS1024 from the BASIC 
; loader. 
START   JSR GFXON
        LDA #$01
        SEI              ; prevent IRQ between the bank flip and the game
                         ; installing its own handler, or we execute in a
                         ; half-switched state and die.
        STA $00          ; set execution bank to 1
        STA $01          ; set indirection bank to 1
        JMP GAME         ; enter the game body in bank 1
        BRK

; The 'L' routines below were written as bank 15 kernal call wrappers.
; They allow bank 15 kernal routines to be called from code executing
; in bank 1 using a dedicate wrapper routine for each kernal call.
; 
; Note that there's a much better way of handling this, but I wrote
; these before I knew that. If you look at the comments in init_b15.asm,
; you'll see that I stole the kernal IRQ handling code from Commodore's
; Accounts Payable software. Accounts Payable also had a more elegant
; and generic cross-bank kernal routine solution. I didn't use it for
; Space Invaders since I'm only making three kernal calls, but if you're
; reading this code, know that there's a better implementation than what
; you see here.
; 
; LSCNKY - local wrapper for the kernal SCNKY routine
; The game calls this from bank 1. It briefly switches execution to bank 15,
; calls the kernal SCNKEY, debounces against KEYDOWN, switches back to bank 1.
; Returns A = key (or $FF if same as last / none), with a fresh key stored in
; KEYDOWN. I originally wrote this for the CBM-II clock program.
LSCNKY  PHP 
        LDX #$0F
        SEI
        STX $00          ; exec -> 15 (this routine exists in bank 15 too)
        STX $01
        JSR SCNKEY
        CMP KEYDOWN
        BNE NEWKEY
        LDA #$FF         ; same key as last scan -> report "nothing new"
        LDX #$01
        STX $00          ; exec -> back to 1
        LDX #$0F
        STX $01 
        PLP              ; restore caller's I-flag
        RTS
NEWKEY  STA KEYDOWN
        LDX #$01
        STX $00          ; exec -> back to 1
        LDX #$0F
        STX $01          ; restore steady-state ind=15
        PLP              ; restore caller's I-flag
        RTS

; LCHROT - local wrapper for the kernal CHROT routine
; Switches to bank 15, sets row height ($CA) calls CHROUT,
; switches back. The game's string printer will route through this.
; This code was also taken from my CBM-II clock program
LCHROT  PHP              ; save I-flag
        LDX #$0F
        SEI
        STX $00          ; exec -> 15
        STX $01
        LDX #$16         ; explicit row height
        STX $CA
        JSR CHROUT
        LDX #$01
        STX $00          ; exec -> back to 1
        LDX #$0F
        STX $01          ; indirect -> to 15
        PLP              ; restore caller's I-flag
        RTS

; LGETIN - local wrapper for kernal GETIN routine
; Switches to bank 15, calls kernal GETIN, switches back. Returns A = key code
; (0 if no key).
LGETIN  PHP              ; save I-flag
        LDX #$0F
        SEI
        STX $00          ; exec -> 15
        STX $01
        JSR GETIN        ; kernal GETIN; needs the kernal IRQ to be filling the buffer
        TAX              ; stash key in X (bank-switch below clobbers A's flags)
        LDA #$01
        STA $00          ; exec -> back to 1
        LDA #$0F
        STA $01          ; indirect -> to 15s
        PLP              ; restore caller's I-flag
        TXA              ; A = key code (0 = none); sets Z for caller BEQ/BNE
        RTS

; BANK15 / BANK1 - indirection-bank-only helpers (DO NOT touch exec bank).
; These are what the game uses around every screen / I/O (zp),Y access.
BANK15  PHA
        LDA #$0F
        STA $01          ; indirection bank -> 15 ; exec unchanged
        PLA
        RTS

BANK1   PHA
        LDA #$01
        STA $01          ; indirection bank -> 1  ; exec unchanged
        PLA
        RTS

; Adopted directly from Commodore Accounts Payable's IRQ handling
; (taken from MASMEN.prg and B15.prg on the Accounts Payable disk).
;
; The bank-1 side lives here in init.asm.
; The bank-15 side is in init_b15.asm, BLOADed into bank 15 ONLY,

; bank-switch data slot. In bank 1, the literal byte at $04BE
; is $0F (because the instruction is LDA #$0F). The bank-15 overlay puts
; $01 at $04BE instead. The byte at $04BE is what the cross-bank code
; reads to switch execution banks.
* = $04BC
        LDA #$0F         ; in bank 1, this makes $04BE = $0F
        STA $00          ; this code itself is never executed; data only


; in bank 1, the exec-switch into bank 15.
; Reached only from $0510 (IRQENTRY) which JMPs here with X=$0F.
; STX $00 flips exec to 15, then the next fetch comes from bank-15 $04D2
; which is the B15-resident JSR $04DA + JMP ($FFFE) sequence
* = $04D0
        STX $00          ; exec -> 15; next fetch from bank-15 $04D2
        JMP $0510        ; (in bank 1, would re-enter IRQENTRY; unreachable
                         ; after the exec flip but assembler-valid filler)

; in bank 1, the post-IRQ code
; Reached after kernal RTI
;
; Accounts Payable's design saved A/X/Y/$01 to ZP $9C-$9F. That
; works when handlers don't CLI or cause nested IRQs. Our game's L19A8 calls
; L0510 which does SEI/CLI. A nested IRQ then overwrites the ZP-saved state.
; So we save state to the stack instead so each IRQ invocation has
; its own stack frame.
;
; To support Space Invaders "handler long-jumps out" pattern (L19A8 ends with
; JMP L0490 and never returns), we push a CLEANUP return address before
; JMP ($0090). If the handler RTSes it lands at CLEANUP. If the handler
; long-jumps out, the stack bytes are never cleaned up. 
* = $04DA
        ; Push CLEANUP-1 as a fake return address so JMP ($0090) acts as JSR.
        LDA #>(CLEANUP-1)
        PHA
        LDA #<(CLEANUP-1)
        PHA
        JMP ($0090)      ; dispatch game's selected per-frame handler

CLEANUP
        PLA              ; pull saved $01
        STA $01
        PLA              ; pull saved Y
        TAY
        PLA              ; pull saved X
        TAX
        PLA              ; pull saved A
        RTI              ; pull hw status + PC from underneath, return to caller

* = $0510
IRQENTRY
        ; Push A/X/Y/$01 onto stack
        PHA              ; A
        TXA
        PHA              ; X
        TYA
        PHA              ; Y
        LDA $01
        PHA              ; $01
        LDA #$0F
        STA $01          ; ind=15 for kernal IRQ's bank-15 work
        ; A holds $0F now. The bank-15 twiddle uses A (via TAY/PHA) as the
        ; "fake status" pushed into the kernal-RTI frame. $0F has D=1 set
        ; (decimal mode) which would poison subsequent ADC/SBC ops. Use a
        ; safe-status value instead: $24 = I=1 (mask set), D=0, others clear.
        LDA #$24
        LDX #$0F
        JMP $04D0        ; head to the bank-flip point (STX $00 -> exec=15)
