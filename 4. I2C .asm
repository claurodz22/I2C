
; Código para emulación del protocolo I2C en el microprocesador 8085
; Utilizando los pines SID y SOD y las instrucciones RIM y SIM

; Definir las direcciones de memoria para las variables
.DEFINE
	SDA_DATA  01H    			; Variable para el dato en SDA
	SCL_PIN 00H    			; Variable para el pin de reloj SCL

; Direcciones y datos de ejemplo
	SLAVE_ADDR 		AEH   	; Dirección del dispositivo esclavo (7 bits) + Bit R/W
	MEMORY_ADDR 	5BH    	; Dirección de memoria (8 bits)
	DATA_TO_SEND 	9FH    	; Dato a enviar (8 bits)
	READ_WRITE 		00H    	; Variable para el bit de Lectura/Escritura

; Inicio del programa principal

.org 3000H

MAIN:           
	MVI A, 00H       			; 0 para escribir, 1 para leer
	MOV READ_WRITE, A
	CALL I2C_START    		; Generar señal de inicio
 	CALL SEND_SLAVE_ADDR 		; Enviar dirección del esclavo + Bit escritura / lectura
	MOV A,B				; B almacena el bit de escritura / lectura
	CPI 00H				; 00 H = escribir
	JZ ESCRIBIR				; salta a la subrutina de escribir
	CPI 01H				; 01 H = leer
	JZ LEER				; salta a la subrutina leer

; En caso de que el bit READ_WRITE = 00H
ESCRIBIR:
	CALL SEND_MEMORY_ADDR 		; Enviar dirección de memoria
	CALL SEND_DATA    		; Enviar datos
	CALL I2C_STOP     		; Generar señal de parada
	HLT               		; Detener el programa

; En caso de que el bit READ_WRITE = 01H
LEER:
	CALL SEND_MEMORY_ADDR 		; Enviar dirección de memoria
	CALL I2C_START    		; Bit de inicio repetido
	CALL SEND_SLAVE_ADDR 		; Enviar dirección del esclavo + Bit escritura / lectura
	; HLT
	CALL READ_DATA    		; Leer datos
	CALL I2C_STOP     		; Generar señal de parada
	HLT              			; Detener el programa


.org 1000H

; Subrutina para generar una señal de inicio (START)
; Configuración inicial / Inicialización
I2C_START:          
	MVI A, 00H    			; Inicializar A
	OUT SCL_PIN       		; Inicializar el pin SCL
	CALL SCL_HIGH    			; Asegurar SCL está en alto
	MVI A, C0H   			; Asegurar SDA está en alto
	SIM               		; 
	MVI A, 40H    			; Bajar SDA (Inicio)
	SIM
	CALL SCL_LOW      		; Bajar SCL
	RET

; Subrutina para generar una señal de parada (STOP)
I2C_STOP:     
	CALL SCL_HIGH     		; Subir SCL
	MVI A, 40H				; Asegurar SDA está en bajo
	SIM
	MVI A, C0H				; Asegurar SDA está en alto
	SIM	
	CALL SCL_LOW      		; Asegurar SCL está en bajo
	MVI A, 00H        		; Bajar SDA
	RET

; Subrutina para generar un pulso de reloj en SCL
PULSE_SCL:      
	CALL SCL_HIGH     		; Subir SCL
	CALL SCL_LOW      		; Bajar SCL
	RET

SCL_HIGH:       
     MVI A, 01H
     OUT SCL_PIN       			; SCL en alto
     NOP
     NOP
     NOP
     RET

SCL_LOW:        
	MVI A, 00H
      OUT SCL_PIN       		; SCL en bajo
      NOP
      NOP
      NOP
      RET

; Subrutina para enviar un bit
SEND_BIT:
   	MOV A, SDA_DATA     		; Cargar el dato a enviar desde SDA_DATA   
	RRC
	MOV SDA_DATA, A
	ANI 80H
	ORI 40H
   	SIM                 		; Colocar el bit en SOD    
	CALL PULSE_SCL      		; Generar un pulso de reloj en SCL
	MOV A, SDA_DATA     		; Actualizar SDA_DATA con el último valor enviado
	OUT SDA_DATA       		; Colocar el bit en el puerto de salida SDA
	RET

; Subrutina para leer un bit desde
; el SID. Es decir, el esclavo le envía un dato
; de 8 bits al dispositivo maestro. 
READ_BIT:
	CALL PULSE_SCL      		; Generar un pulso de reloj en SCL
	MVI D, 08H				; Limpia la señal del acumulador
	
	RIM					; bit 0
	SUB D					; Limpia bit 3 del acumulador
	RRC					; Desplaza bit a la derecha
	MOV B,A                       ; Almacenar bit obtenido / resultado en el registro B

	RIM					; bit 1
	SUB D							 
	ADD B					
	RRC							  
	MOV B,A				

	RIM;					; bit 2
	SUB D	 
	ADD B	 
	RRC		 
	MOV B,A

	RIM					; bit 3
	SUB D					
	ADD B 				
	RRC					
	MOV B,A				

	RIM					; bit 4
	SUB D	
	ADD B	 
	RRC		  
	MOV B,A

	RIM					; bit 5
	SUB D	
	ADD B	 
	RRC	  
	MOV B,A

	RIM					; bit 6
	SUB D	
	ADD B	 
	RRC		  
	MOV B,A

	RIM			            ; bit 7
	SUB D	
	ADD B	 		  
	MOV B,A
	MOV A,B
	RET					; se regresa

; Subrutina para enviar un byte
SEND_BYTE:
	MVI E, 08H            		; Enviar 8 bits
	MOV A, SDA_DATA     		; Cargar el dato a enviar desde SDA_DATA
	MOV READ_WRITE, A             ; Copiar el byte completo al registro D
	RAR                 		; Rotar el bit hacia la derecha (el primer bit ahora es el LSB)
	MOV A, READ_WRITE             ; Mover el byte modificado al acumulador A
	ANI 01H              		; Máscara para aislar el primer bit (LSB)
	MOV READ_WRITE, A             ; Almacenar el bit de escritura/lectura en el registro D

; Subrutina para enviar bit por bit
; hasta que el REG E = 00H
SEND_LOOP:
	RAR                 		; Rotar el bit hacia la derecha
	CALL SEND_BIT       		; Enviar un bit
	DCR E
	JNZ SEND_LOOP  		      ; Repetir hasta que se envíen 8 bits
	CALL READ_ACK       		; Leer el bit de ACK/NACK
	RET

; Subrutina para leer un byte
READ_BYTE:      
	MVI A, 00H        		; Inicializar A

; Subrutina para leer un bit
; hasta que el reg. E = 00H
READ_LOOP:      
	CALL READ_BIT     		; Leer un bit
	MVI E, 01H
	DCR E
	JNZ READ_LOOP     		; Repetir hasta que se lean 8 bits
	CALL SEND_ACK     		; Enviar un bit de ACK/NACK
	RET

; Subrutina para leer ACK/NACK
READ_ACK:
	CALL SCL_HIGH
	MVI A,00H
	RIM       
	ANI 80H
	RRC
	RRC
	RRC
	RRC 
	RRC
	RRC
	RRC
	CPI 00H          			; Comparar con 0 (ACK)
	JZ ACK_RECEIVED   		; Si es 0, es ACK
	CALL REINTENTOS_CONTEO
	JMP NACK_RECEIVED 		; Si no es 0, es NACK

REINTENTOS_CONTEO:
	MVI D, 04H				; Nmro de reintentos
	RET

ACK_RECEIVED:   				; Código para manejar ACK
	NOP               		; Realizar acciones necesarias para ACK
	CALL SCL_LOW
	RET

NACK_RECEIVED:  				; Código para manejar NACK
	CALL SCL_LOW
	DCR D
	JNZ SEND_BYTE
	JZ I2C_STOP
	RET

; Subrutina para enviar ACK
SEND_ACK:       
	MVI A, 00H       			; Preparar ACK
	MOV SDA_DATA, A
	CALL SEND_BIT    		      ; Enviar ACK
	RET

; Subrutina para enviar NACK
SEND_NACK:      
	MVI A, 01H        		; Preparar NACK
	MOV SDA_DATA, A
	CALL SEND_BIT     		; Enviar NACK
	RET

; Subrutina para enviar la dirección del esclavo y el bit R/W
SEND_SLAVE_ADDR:
	MVI A, SLAVE_ADDR
      MOV B, A
      MVI A, READ_WRITE
      RLC
      ORA B
      MOV SDA_DATA, A
      CALL SEND_BYTE
      RET

; Subrutina para enviar la dirección de memoria + el bit de escritura / lectura 
; al dispositivo esclavo
SEND_MEMORY_ADDR:
	MVI A, MEMORY_ADDR
	MOV SDA_DATA, A
	CALL SEND_BYTE
	RET

; Subrutina para enviar datos al dispositivo esclavo
SEND_DATA:
	MVI A, DATA_TO_SEND
	MOV SDA_DATA, A
	CALL SEND_BYTE
	RET

; Subrutina para leer datos del dispositivo esclavo
READ_DATA:
	CALL READ_BYTE
	MOV A, SDA_DATA   		; Guardar el dato leído
	CALL SEND_NACK
	RET
