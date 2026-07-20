# Auto a Control Remoto - PIC16F887 (Ensamblador / ASM)

Este repositorio contiene el proyecto final para la asignatura **Electrónica Digital II** de la **Facultad de Ciencias Exactas, Físicas y Naturales (FCEFyN)** de la **Universidad Nacional de Córdoba (UNC)**.

Consiste en el diseño, programación e implementación en hardware de un vehículo a control remoto guiado por Bluetooth utilizando el microcontrolador **PIC16F887** de Microchip, programado íntegramente en lenguaje ensamblador (**Assembly / MPASM**).

---

## 🏛️ Institución
* **Universidad:** Universidad Nacional de Córdoba (UNC)
* **Facultad:** Facultad de Ciencias Exactas, Físicas y Naturales (FCEFyN)
* **Asignatura:** Electrónica Digital II
---

## 📌 Características Principales

* **Control de Motores DC:** Manejo de dirección y tracción mediante puente H **L293D**.
* **Modulación por Ancho de Pulso (PWM):** Control de velocidad (100% y 50%) mediante los módulos **CCP1** y **CCP2** configurados sobre el **Timer2**.
* **Comunicación Serie (USART):** Recepción de comandos en tiempo real vía módulo Bluetooth **HC-05** a 9600 baudios.
* **Manejo de Interrupciones:** Procesamiento por interrupción de recepción serie (`RCIF`) para una respuesta inmediata.
* **Rutina Kick-Start:** Inyección de pulso de potencia máxima (100% durante 10 ms) al iniciar marcha en modo 50% de velocidad para vencer la inercia mecánica del motor desde cero.
* **Modo de Bajo Consumo (`SLEEP`):** Al recibir la orden de parada, el sistema apaga los motores y entra en modo de reposo de ultra bajo consumo, despertando automáticamente ante un nuevo comando UART.

---

## 📐 Esquemático de Conexión

```
   +-----------------------------------------------------------------------+
   |                                                                       |
   |   +-------------------+              +----------------------------+   |
   |   |   Módulo HC-05    |              |   PIC16F887                |   |
   |   |                   |              |                            |   |
   |   |   TXD ------------+------------->| RC7/RX/DT (Pin 26)         |   |
   |   |   RXD <-----------+--------------| RC6/TX/CK (Pin 25)         |   |
   |   +-------------------+              |                            |   |
   |                                      | RC1/CCP2 -----> L293D EN2  |   |
   |   +-------------------+              | RC2/CCP1 -----> L293D EN1  |   |
   |   | Baterías (10.5V)  |              |                            |   |
   |   |        |          |              | RD0..RD3 ------> L293D INs |   |
   |   |        v          |              +----------------------------+   |
   |   |  [ Reg. LM7805 ]  |                                               |
   |   |        |          |              +----------------------------+   |
   |   +--------+----------+              |     Puente H L293D         |   |
   |            | (5V)                    |                            |   |
   |            +------------------------>| VSS (5V)                   |   |
   |            +------------------------>| VS (10.5V de Baterías)     |   |
   |                                      | OUT1/OUT2 ----> Motor 1    |   |
   |                                      | OUT3/OUT4 ----> Motor 2    |   |
   |                                      +----------------------------+   |
   +-----------------------------------------------------------------------+
```

---

## 🛠️ Componentes de Hardware

* **Microcontrolador:** Microchip PIC16F887.
* **Módulo Bluetooth:** HC-05 (Configurado a 9600 baudios).
* **Controlador de Potencia:** Integrado L293D (Puente H cuádruple).
* **Actuadores:** 2 Motores DC con reductora integrados en un chasis robótico.
* **Alimentación:**
  * 3x Baterías de Litio 3.7V / 3.5V en serie ($\sim 10.5	ext{ V}$) para alimentación directa de motores (Terminal `VS` del L293D).
  * Regulador de voltaje **LM7805** para entregar 5V estables al PIC y al módulo HC-05.
* **Prototipado:** 2x Protoboard de 400 puntos y cableado diverso.

---

## 🎛️ Decodificación de Comandos Bluetooth (ASCII)

Los comandos enviados vía Bluetooth desde una aplicación móvil son decodificados mediante comparación XOR en la Rutina de Servicio de Interrupción (ISR):

| Comando ASCII | Acción Ejecutada | Descripción |
| :---: | :--- | :--- |
| **`'1'`** | Avanzar | Sentido directo en ambos motores |
| **`'2'`** | Girar Derecha | Giro suave a la derecha |
| **`'3'`** | Retroceder | Inversión de marcha en ambos motores |
| **`'4'`** | Girar Izquierda | Giro suave a la izquierda |
| **`'5'`** | Giro sobre Eje | Motores en sentidos opuestos |
| **`'0'`** | Detener y Reposo | Apaga motores y activa la instrucción `SLEEP` |
| **`'A'`** | Velocidad 100% | Duty Cycle al máximo (`CCPR1L/CCPR2L = 0xFF`) |
| **`'B'`** | Velocidad 50% | Duty Cycle al 50% (`CCPR1L/CCPR2L = 0x4E`) con Kick-Start |

---

## ⚙️ Cálculos y Configuración de Periféricos

### 1. Módulo USART (Baud Rate)
Para una frecuencia de oscilador $F_{OSC} = 4	ext{ MHz}$ y una velocidad requerida de $9600	ext{ baudios}$ en modo asíncrono de alta velocidad (`BRGH = 1`):

$$X = rac{F_{OSC}}{	ext{Desired BaudRate} 	imes 16} - 1 = rac{4	ext{ MHz}}{9600 	imes 16} - 1 = 25.04  pprox 25$$

* **Valor asignado:** `SPBRG = 25`
* **Baud Rate Real:**
  $$	ext{BaudRate}_{	ext{Real}} = rac{4	ext{ MHz}}{16 	imes (25 + 1)} = 9615.38	ext{ baudios}$$
* **Porcentaje de Error:**
  $$	ext{Error} = rac{9615.38 - 9600}{9600} 	imes 100 = 0.16\%$$

### 2. Módulo PWM (Timer2)
Con $F_{OSC} = 4	ext{ MHz}$ ($T_{OSC} = 0.25\ \mu	ext{s}$) y Prescaler $= 1$:

$$	ext{PWM Period} = (PR2 + 1) 	imes 4 	imes T_{OSC} 	imes 	ext{Prescaler}$$
$$	ext{PWM Period} = (155 + 1) 	imes 4 	imes 0.25\ \mu	ext{s} 	imes 1 = 156\ \mu	ext{s} \quad (f  pprox 6.41	ext{ kHz})$$

* **Registros de Ciclo de Trabajo (Duty Cycle):**
  * **100% Duty Cycle:** `CCPR1L = 0xFF` (255)
  * **50% Duty Cycle:** `CCPR1L = 0x4E` (78)

---

## 🔋 Lógica del Modo de Bajo Consumo (`SLEEP`)

Al recibir el comando `'0'`, el microcontrolador detiene los generadores PWM y la lógica de los puertos. Se establece una **bandera interna** que indica al flujo principal que debe ingresar en modo de reposo una vez finalizada la atención de la interrupción. De esta forma, se ejecuta la instrucción `SLEEP` desde el bucle principal de manera limpia, reduciendo el consumo eléctrico al mínimo hasta que una nueva interrupción por recepción serie (`RCIF`) despierta al PIC.

---

## 💻 Requisitos para Compilar el Proyecto

* **IDE:** MPLAB X IDE (v5.xx o superior).
* **Compilador / Ensamblador:** MPASM / PIC-AS (XC8 Assembly).
* **Programador / Depurador:** PICkit 3 / PICkit 4.
