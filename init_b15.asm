; bank-15-resident IRQ handling code
;
; This code was stolen verbatim from Commodore's Accounts Payable application
; (B15.prg, which loaded to $03BC). It's relocated by $0100 to $04BC here
; to match our Space Invaders address space.
;
; The problem it solves:
; 
; The CBM-II's 6509 has separate execution and indirection bank registers
; ($00 and $01). Space Invaders runs in bank 1, but the kernal IRQ handler
; lives in bank 15 ROM. When an IRQ fires, the CPU fetches the IRQ vector
; from $FFFE in whichever bank is currently executing.
; So if the execution bank register is $01 when the IRQ hits, the
; CPU reads $FFFE from bank 1 (RAM) instead of bank 15 (kernal ROM).
;
; That means we can't just let the kernal handle IRQs normally. We have to:
;   1. Catch the IRQ in bank 1.
;   2. Flip exec to bank 15.
;   3. Hand off to the kernal's real IRQ handler.
;   4. When the kernal RTIs, flip exec back to bank 1.
;   5. Return to the interrupted game code in bank 1.
;
; How it works:
;
; init.asm (bank 1) and init_b15.asm (this file, bank 15) load
; different bytes at the same address ($04BC-$04EF). Whichever bank
; exec is currently set to, the CPU sees the corresponding code.
;
;   - IRQ fires while exec=1.
;   - CPU reads $FFFE in bank 1, which we set to point to IRQENTRY ($0510)
;     in bank 1 (init.asm).
;   - IRQENTRY saves registers to the bank-1 stack, then JMPs to $04D0.
;   - Bank 1's $04D0 contains "STX $00" with X=$0F preloaded. This sets
;     the execution bank register to 15.
;   - The very next instruction fetch is from bank 15's $04D2, which (this
;     file) contains "JSR $04DA" which then modifies the return
;     address on the stack so the eventual kernal RTI lands on $04D5
;     (in bank 15), where code waits to flip the execution bank register
;     back to bank 1.
;   - The $04DA stack adjust code ends with JMP ($FFFE), now reading bank
;     15's $FFFE - the real kernal IRQ vector. At this point, the Kernal 
;     code runs normally in bank 15.
;   - When the kernal has completed its work, it will RTI. Because the
;     stack was intentionally modified, control lands at $04D5 in bank
;     15, which does "LDA $04BE / STA $00" to flip the execution bank
;     register back to bank 1. $04BE contains the destination execution
;     bank register, so in bank 15 $04BE is $01, while in bank 1, 
;     $04BE is 15.
;   - The kernal interrupt has been serviced and  we're back to
;     executing Space Invaders in bank 1.
;

; $04BE, as described above, is the execution bank destination.
; This code is loaded to bank 15, so the destination execution bank
; is $01. The $00 bytes are padding so the code's footprint matches
; the bank 1 code exactly.
* = $04BC
       .byte $00,$00,$01,$00     ; $04BE = $01 (the bank-1 selector for b15->b1)

* = $04C0
        PLA                       ; pull return addr
        JSR $04CB                 ; the call body
        PHA 
        SEI 
        LDA $04BE                 ; read bank slot (=$01 in b15)
        STA $00                   ; set execution bank register
* = $04CB
        CLI
        JMP ($04BC)               ; indirect through bank slot
                                  ; in bank 1, $04BC holds the call target
                                  ; in bank 15, never reached this way
* = $04CF
        RTS

; The bank-1 side's STX $00 (at $04D0) just executed,
; setting exec to 15. The very next fetch is from bank-15 $04D2.
; This is the RTS for the cross-bank call, not the IRQ
* = $04D0
        CLI                       ; AP $03D0
        RTS                       ; AP $03D1

; Bank 15 IRQ entry. 
; $04D0 in bank 1 was STX $00, which set the execution bank to $0F.
; the next PC address would be $04D2, so this code running in bank 15.
* = $04D2
        JSR $04DA                 ; call stack modification routine
        LDA $04BE                 ; bank slot (=$01 in b15)
        STA $00                   ; set execution bank to $01
                                  ; next fetch from bank 1 at $04DA

; Modify the stack to redirect kernal RTI.
; Reached only via JSR from $04D2. The JSR pushed return = $04D4 (RTS would
; pop to $04D5). This adjusts the pushed return so when kernal RTIs,
; it lands at $04D5 (the LDA $04BE that switches exec back to 1).
* = $04DA
        TAY
        PLA                       ; pull return-lo ($D4)
        TAX 
        INX                       ; $D4+1 = $D5
        TXA
        PHA                       ; push $D5
        TYA 
        PHA                       ; push original Y
        JMP ($FFFE)               ; jump to kernal IRQ in bank-15 ROM
