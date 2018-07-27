#include "p12f675.inc" ; generic constants for this uC
; __CONFIG _FOSC_INTRCIO & _WDTE_OFF & _PWRTE_OFF & _MCLRE_OFF & _BOREN_OFF & _CP_OFF & _CPD_OFF
; H'3FFC' & H'3FF7' & H'3FFF' & H'3FDF' & H'3FBF' & H'3FFF' & H'3FFF' = H'3F94'
; I don't use watchdog timer, prefer mclr as a i/o-pin and don't protect memory
  __CONFIG H'0184' ; debugging, so eliminating inc-file misses with magic number
; this one extracted from data sheet + pickit 2 programmer software    
; servo reverser - read a pwm input duration, output inverted signal
; input is 1500us pulse +/- 600us
; output is 1500 + (0 - (input-1500)) ; 1500us is center
; shortening above formula: output = 3000-input (raw duration measurement in us)

tmr1start macro ; Macro start timer1
  bsf T1CON, TMR1ON
  endm  

tmr1stop macro ; Macro stop timer1
  bcf T1CON, TMR1ON
  endm  
  
clrovf macro ; clear timer1 overflow flag
  bcf PIR1, TMR1IF
  endm

bank0 macro ; select bank 0
  bcf STATUS, RP0
  endm

bank1 macro ; select bank 1
  bsf STATUS, RP0
  endm
  
INPUT	EQU GP3 ; select your favourite pins
OUTPUT	EQU GP4

BANDWIDTH EQU .1300  ; >1000, probably no more than 1300
PULSE_CENTER EQU .1500
PULSE_MINIMUM EQU PULSE_CENTER - BANDWIDTH/2
PULSE_MAXIMUM EQU PULSE_CENTER + BANDWIDTH/2
 
ANSELBITS EQU .0 ; not using A/D
T1CONBITS EQU b'00000100' ; no prescaler for timer1, and don't start
CMCONBITS EQU b'00000111' ; not using comparator
TRISBITS  EQU 0x3f ^(1 << OUTPUT) ; all inputs, except OUT-pin *
OPTIONBITS = b'00000110' ; 1:128 prescaler for TMR0 for pulse period timekeeping
; * Inputs are high impedance, and will be a small load in case of an unintended short


  cblock 0x20	; up to 64 bytes free for variables
    tempStatus  ; isr holder for status register
    tempW       ; isr holder for W
  endc

  org 0x00     ; reset vector
  goto init
  org 0x04     ; isr vector
  goto isr

 
; pseudo code:
; 1 - config mcu (__CONFIG over)

init ; one time setup of the uC and peripheralse. Note fuses at beginning of file
  bank0 ; bank0
  clrf INTCON ; no interrupts

  bank1 ; initialization in bank1
  movlw TRISBITS
  movwf TRISIO    ; GPIO input/output select
  movlw ANSELBITS
  movwf ANSEL     ; analog / digital pin select
  movlw OPTIONBITS
  movwf OPTION_REG ; uC options
  call 0x3ff ; retrieve calibration value for this specific chip
  movwf OSCCAL ; set osccal value for the internal oscillator

  bank0 ; initialization in bank0
  movlw CMCONBITS
  movwf CMCON     ; comparator ( switch off, we are running on batteries )
  movlw T1CONBITS
  movwf T1CON     ; timer1 initial setup (no prescaler, don't start)

; init app-variables ? 

main
  tmr1stop
  clrf TMR1L ; prepare to measure pulse length
  clrf TMR1H ; by zeroing out the timer regs
  clrovf ; clear timer1 overflow (interrupt) flag
  
; 2 - wait for positive pulse change on input
waitForLow  
  btfsc GPIO, INPUT
  goto waitForLow
waitForHigh
  btfss GPIO, INPUT
  goto waitForHigh
  
; 3 - start timer, waitfor downpulse, on timeout goto 2
  tmr1start ; timer1 is now running
waitForEnd
  btfsc GPIO, INPUT  ; wait for low input
  goto waitForEnd    ; repeat while high
  tmr1stop  ; stop timer, so we can look at both bytes
  btfsc PIR1, TMR1IF ; timer overflow - 65ms in vain?
  goto main ; sadly, yes - timer value invalid, even if within range and is discarded
  
; debug - skip range check ? : goto calcNew
  
; 4 - if !(pulse between MINIMUM and MAXIMUM) goto 2
  movlw HIGH(PULSE_MINIMUM) ; high byte
  subwf TMR1H, W            ; compare high bytes
  btfss STATUS, Z           ; if equal, check low bytes instead
  goto comp16minimum
  movlw LOW(PULSE_MINIMUM)
  subwf TMR1L, W
comp16minimum   ; carry (!borrow) must be set for pulse>=MIN
  btfss STATUS, C
  goto main     ; abort, to low pulse value

  movfw TMR1H   ; reverse order, so we can check >= , load TMR value first
  sublw HIGH(PULSE_MAXIMUM) ; subtract high(timer) from high(pulse_max)
  btfss STATUS, Z           ; check for equality
  goto comp16maximum
  movfw TMR1L               ; high bytes equal, check low bytes instead
  sublw LOW(PULSE_MAXIMUM)
comp16maximum
  btfss STATUS, C           ; if carry is set, no borrow occured i.e. max>=pulse
  goto main                 ; alas, no. try again

calcNew  
; 5 - calc new output pulse
  ; the timer is set at 0 minus the pulse width so we can count up to 0
  ; the measured PULSE is 1500 +/- 600 (us). The inverted/reversed pulse is
  ; subtracting the centre value (1500) we get a +/- 600 VALUE
  ; the new pulse value NVALUE = -VALUE (reverse direction with sign)
  ; the new pulse is NPULSE = 1500 + NVALUE
  ; the new TMR value NTMR = 0 - NPULSE.
  ; for a 16-bit timer, 0 is equivalent to 0x10000 = .65536 (discarding bit 16)
  ; so .. TMR = .65536 - (NPULSE)
  ; .. = .65536 - (.1500 + NVALUE)
  ; .. = .65536 - (.1500 + (-(PULSE - .1500))
  ; .. = .65536 - (.1500 - (PULSE - .1500))
  ; .. = .65536 - (.1500 - PULSE + .1500)
  ; .. = .65535 - (.1500 + .1500 - PULSE)
  ; .. = .65536 - .3000 + PULSE
  ; .. = .62536 + PULSE .. so we just add .62536 to whatever is in TMR1 (PULSE)
  movlw LOW(.62536)
  addwf TMR1L, f
  btfsc STATUS, C
  incf TMR1H, f
  movlw HIGH(.62536)
  addwf TMR1H, f
  
; 6 - output new pulse
  clrovf ; clear overflow interrupt flag
  tmr1start ; start the timer
  bsf GPIO, OUTPUT  ; set high output
waitForOverflow 
  btfss PIR1, TMR1IF    ; overflowed yet ?
  goto waitForOverflow ; no, wait some more
  bcf GPIO, OUTPUT ; send low output
  
; 7 - goto 2, repeat the whole thing
  goto main ; loop is done, do it again.

isr

  ; save registers (recipe from Microchip documentation)
  movwf tempW
  swapf STATUS, W
  bcf STATUS, RP0
  movwf tempStatus

  ; do what is needed - be quick about it
  clrf PIR1 ; clear all interrupt flags
  
  ; get registers back
  swapf tempStatus, W
  movwf STATUS
  swapf tempW, F
  swapf tempW, W

  retfie
  
  end