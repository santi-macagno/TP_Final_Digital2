LIST      P=16F887
        #include <p16f887.inc>
	
        CBLOCK 0x20	;declaracion de variables
W_TEMP			;temporales	
STATUS_TEMP		;para guardar contexto
PCLATH_TEMP		;al final de la ISR
TEMP			;guardado temporal del dato del puerto serie
MODO_VEL		;0 = 100%, 1 = 50%
R0			; 
R1			;ambos para un retardo
FLAG_SLEEP		;check para hacer un sleep
        ENDC


;================= vector de reset ==================
        ORG 0x0000
        MOVLW   HIGH(INICIO)
        MOVWF   PCLATH
        GOTO    INICIO

        ORG 0x0004
        GOTO    ISR


;====================================================
;                      inicio del programa
;====================================================
INICIO
        ; Puertos digitales
        BANKSEL ANSEL
        CLRF    ANSEL
        CLRF    ANSELH

        ; Puertos
        BANKSEL TRISD
        CLRF    TRISD          ; salidas a motores

        BANKSEL TRISC
        BSF     TRISC,7        ; RX
        BCF     TRISC,6        ; TX
        BCF     TRISC,2        ; CCP1 ENA1
        BCF     TRISC,1        ; CCP2 ENA2

;================= USART ===================
        BANKSEL SPBRG	       ;
        MOVLW   .25	       ; seteo velocidad del baudrate
        MOVWF   SPBRG	       ; a 9600 baudios

        BANKSEL TXSTA	       ; BRGH=1, TXEN=1
        MOVLW   b'00100100'    ; modo alta velocidad, 8 bits
        MOVWF   TXSTA	       ; transmision habilitada

        BANKSEL BAUDCTL	       ; limpio todo BAUDCTL
        CLRF    BAUDCTL	       ; 

        BANKSEL RCSTA	       ; SPEN=1, CREN=1
        MOVLW   b'10010000'    ; habilito UART, habilito RX
        MOVWF   RCSTA	       ; recepcion continua

        BANKSEL PIE1
        BSF     PIE1, RCIE     ; Habilito interrupcion RX

        BANKSEL INTCON
        MOVLW   b'11000000'    ; GIE=1, PEIE=1
        MOVWF   INTCON	       ; interrupciones globales y perifericas

;================= PWM ===================
        BANKSEL CCP1CON
        MOVLW   b'00001100'    ; modo PWM
        MOVWF   CCP1CON

        BANKSEL CCP2CON
        MOVLW   b'00001100'    ; modo PWM
        MOVWF   CCP2CON

        BANKSEL PR2
        MOVLW   0x9B           ; periodo PWM
        MOVWF   PR2	       

        BANKSEL CCPR1L
        MOVLW   0xFF           ; duty inicial 100%
        MOVWF   CCPR1L
        
        MOVLW   0xFF
        MOVWF   CCPR2L

        BANKSEL T2CON
        MOVLW   b'00000100'    ; TMR2 ON, prescaler 1
        MOVWF   T2CON

        BANKSEL MODO_VEL
        CLRF    MODO_VEL       ; modo 100%

BUCLE

        BANKSEL FLAG_SLEEP
        MOVF    FLAG_SLEEP, W
        BTFSS   STATUS, Z        ; veo valor del flag para ahcer o no un sleep
        GOTO    DORMIR

        GOTO    BUCLE
	
DORMIR	
	CLRF FLAG_SLEEP         ; limpio flag
        SLEEP                   ; ahora duermo
        NOP                     ; 
	
	GOTO BUCLE
	

;====================================================
;                    INTERRUPCIÓN
;====================================================
ISR
        MOVWF   W_TEMP		;guardo el contexto
        SWAPF   STATUS, W	;	=
        MOVWF   STATUS_TEMP	;	=
        MOVF    PCLATH, W	;guardo el contexto
        MOVWF   PCLATH_TEMP	;	=
        CLRF    PCLATH		;	=

        BANKSEL PIR1
        BTFSS   PIR1, RCIF	;chequeo de interrupcion
        GOTO    EXIT_ISR	;veo si es por el puerto serie

        BANKSEL RCSTA		;chequeo de overrun
        BTFSC   RCSTA, OERR	;se verifica que no haya llegado 
        GOTO    LIMPIAR_OERR	;otro byte antes de leer el anterior

        BANKSEL RCREG		;lectura del byte recibido
        MOVF    RCREG, W	;se lo guarda en la variable temp
        MOVWF   TEMP


;================= decodificacion ===================
        MOVLW   '5'
        XORWF   TEMP, W		;en esta subrutina chequeo que valor
        BTFSC   STATUS, Z	;es el que llego y de ahi voy a la accion
        GOTO    GIROS		;que se debe ejecutar
				;
	MOVLW   '1'		;lo que se hace es hacer un xor con cada valor
        XORWF   TEMP, W		;y verificar si hay un cero en la bandera z
        BTFSC   STATUS, Z	;si es cero es por que el valor era igual y se
        GOTO    ADELANTE	;se verifica que se pulso algo correcto
				;sino simplemente sale de la ISR
        MOVLW   '2'		;
        XORWF   TEMP, W		;   1 avanza
        BTFSC   STATUS, Z	;   3 retrocede
        GOTO    DERECHA		;   2 dobla a la derecha
				;   4 dobla a la izquierda
        MOVLW   '3'		;   5 giro sobre su propio eje
        XORWF   TEMP, W		;   0 detiene el los motores
        BTFSC   STATUS, Z	;   A y B seleccionan la velocidad
        GOTO    ATRAS

        MOVLW   '4'
        XORWF   TEMP, W
        BTFSC   STATUS, Z
        GOTO    IZQUIERDA

        MOVLW   '0'
        XORWF   TEMP, W
        BTFSC   STATUS, Z
        GOTO    APAGAR

        MOVLW   'A'
        XORWF   TEMP, W
        BTFSC   STATUS, Z
        GOTO    VELOCIDAD_100

        MOVLW   'B'
        XORWF   TEMP, W
        BTFSC   STATUS, Z
        GOTO    VELOCIDAD_50
	



        GOTO    EXIT_ISR


;====================================================
;           subrutinas de velocidad 
;====================================================
APLICAR_VEL_ACTUAL
        BANKSEL MODO_VEL
        MOVF    MODO_VEL, W
        BTFSC   STATUS, Z
        GOTO    APLICAR_100     ; si MODO_VEL = 0 ? 100%


APLICAR_50
        BANKSEL CCPR1L		;velocidad al 50%
        MOVLW   0x4E		;se logra haciendo un PWM con 
        MOVWF   CCPR1L		;duty cicle del 50%

        MOVLW   0x4E
        MOVWF   CCPR2L
        RETURN

APLICAR_100
        BANKSEL CCPR1L		;idem velocidad al 50%
        MOVLW   0xFF		;pero duty cicle del 100%
        MOVWF   CCPR1L

        MOVLW   0xFF
        MOVWF   CCPR2L
        RETURN


;====================================================
;               subrutinas de movimiento
;====================================================

ADELANTE
        BANKSEL PORTD
        MOVLW   b'01000111'
        MOVWF   PORTD

        CALL    APLICAR_VEL_ACTUAL
        CALL    KICK_START
        GOTO    EXIT_ISR

DERECHA
        BANKSEL PORTD
        MOVLW   b'01000011'
        MOVWF   PORTD

        CALL    APLICAR_VEL_ACTUAL
        CALL    KICK_START
        GOTO    EXIT_ISR

ATRAS
        BANKSEL PORTD
        MOVLW   b'00101011'
        MOVWF   PORTD

        CALL    APLICAR_VEL_ACTUAL
        CALL    KICK_START
        GOTO    EXIT_ISR

IZQUIERDA
        BANKSEL PORTD
        MOVLW   b'00000111'
        MOVWF   PORTD

        CALL    APLICAR_VEL_ACTUAL
        CALL    KICK_START
        GOTO    EXIT_ISR

GIROS
        BANKSEL PORTD
        MOVLW   b'00100111'
        MOVWF   PORTD

        CALL    APLICAR_VEL_ACTUAL
        CALL    KICK_START
        GOTO    EXIT_ISR
	
APAGAR
       ; duty = 0 (motores apagados)
        BANKSEL CCPR1L
        CLRF    CCPR1L
        CLRF    CCPR2L

        ; direccion apagada
        BANKSEL PORTD
        CLRF    PORTD

        ; marco flag para dormir
        BANKSEL FLAG_SLEEP
        MOVLW   1
        MOVWF   FLAG_SLEEP

        GOTO EXIT_ISR


;====================================================
;        cambio permanente de velocidad con A/B
;====================================================

VELOCIDAD_100
        BANKSEL MODO_VEL
        CLRF    MODO_VEL       ; guardo modo 100%

        BANKSEL CCP1CON
        MOVLW   b'00111100'    ; PWM + DC1B bits altos 
        MOVWF   CCP1CON
        BANKSEL CCP2CON
        MOVLW   b'00111100'
        MOVWF   CCP2CON

        BANKSEL CCPR1L
        MOVLW   0xFF
        MOVWF   CCPR1L

        MOVLW   0xFF
        MOVWF   CCPR2L

        GOTO    EXIT_ISR


VELOCIDAD_50
        BANKSEL MODO_VEL
        MOVLW   1
        MOVWF   MODO_VEL       ; guardo modo 50%

        BANKSEL CCP1CON
        MOVLW   b'00001100'    ; PWM normal
        MOVWF   CCP1CON

        BANKSEL CCP2CON
        MOVLW   b'00001100'
        MOVWF   CCP2CON

        BANKSEL CCPR1L
        MOVLW   0x4E         ; ~50%
        MOVWF   CCPR1L

        MOVLW   0x4E
        MOVWF   CCPR2L

        GOTO    EXIT_ISR


;====================================================
;                kickstart
;====================================================

KICK_START
        BANKSEL MODO_VEL	;esta subrutina chequea que no este en el modo	
        MOVF    MODO_VEL, W	;100% de velocidad
        BTFSC   STATUS, Z       ;si no lo esta pone el modo 100 durante 10MS
        RETURN			;para que los motores puedan romper la inercia
				;y despues pone la velocidad baja otra vez
	
        CALL    VELOCIDAD_100
        CALL    DELAY
        CALL    VELOCIDAD_50
        RETURN


;====================================================
;                      delay de 10 MS
;====================================================
DELAY
        MOVLW   d'20'        
        MOVWF   R0

D10_LOOP
        MOVLW   d'200'       
        MOVWF   R1

D10_LOOP2
        NOP                  
        NOP                  
        DECFSZ  R1, F        
        GOTO    D10_LOOP2    
                             

        DECFSZ  R0, F
        GOTO    D10_LOOP

        RETURN


;====================================================
;                 limpieza de OERR
;====================================================
LIMPIAR_OERR
        BCF     RCSTA, CREN
        BSF     RCSTA, CREN
        GOTO    EXIT_ISR


;====================================================
;               salida de ISR
;====================================================
EXIT_ISR
        MOVF    PCLATH_TEMP, W	    ;se recupera el 
        MOVWF   PCLATH		    ;contexto
        SWAPF   STATUS_TEMP, W
        MOVWF   STATUS
        SWAPF   W_TEMP, F
        SWAPF   W_TEMP, W
        RETFIE

        END