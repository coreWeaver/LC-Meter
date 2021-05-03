'--------------------------------------------------------------------------------------------------------
'                         LC Meter Firmware
'      June 2020 - coreWeaver / ioCONNECTED
'--------------------------------------------------------------------------------------------------------


' Copyright <2020> <coreWeaver / ioCONNECTED>

' Permission is hereby granted, free of charge,
' to any person obtaining a copy of this software and associated documentation files (the "Software"),
' to deal in the Software without restriction, including without limitation the rights to use,
' copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
' and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

' The above copyright notice and this permission notice shall be included in all copies or
' substantial portions of the Software.

' The Software Is Provided "AS IS" , Without Warranty Of Any Kind , Express Or Implied ,
' Including But Not Limited To The Warranties Of Merchantability , Fitness For A Particular Purpose
' And Noninfringement. In No Event Shall The Authors Or Copyright Holders Be Liable For Any Claim ,
' Damages Or Other Liability , Whether In An Action Of Contract , Tort Or Otherwise , Arising From ,
' Out Of Or In Connection With The Software Or The Use Or Other Dealings In The Software.

'--------------------------------------------------------------------------------------------------------
'--------------------------------------------------------------------------------------------------------



$regfile = "m328pdef.dat"
$crystal = 8000000
$baud = 19200
$hwstack = 256
$swstack = 256
$framesize = 256


' UART Config
Config Com1 = 19200 , Synchrone = 0 , Parity = None , Stopbits = 1 , Databits = 8 , Clockpol = 0
Open "com1:" For Binary As #1
Config Serialin0 = Buffered , Size = 30 , Bytematch = All

' Use ADC's Channel_5 to measure VBAT
Config Adc = Single , Prescaler = Auto , Reference = Avcc
Start Adc

'using watchdog for SW RST
Config Watchdog = 128                                       'ovf after 128ms and resets the uC

' Timers Usage:
' Timer0 is used to count the incoming pulses on T0 (PD4)
' Timer1 is used to generate a 1sec time interval for frequency measurement
' Timer2 is used to raise a flag (Ok_to_read_Vbat) every 4 seconds


' Frequency Counter from 4 Hz to 5 MHz

' Timer1 Config (1 Second time interval)
On Timer1 Timer1_routine
Tccr1a = &B00000000
Tccr1b = &B00000101                                         ' Prescaller 1024

Timsk2 = &B00000001                                         ' Interrupt for Timer 2 active
Timsk1 = &B00000001                                         ' Interrupt for Timer 1 active
Timsk0 = &B00000001                                         ' Interrupt for Timer 0 active

Sreg = &B10000000                                           ' Global Interrupts on

Timer1 = 57644
' this value was found by using a resonator (4MHz)
' and adjusting the value of timer1 to match the 4000000 Hz output


' Timer0 Config
On Timer0 Timer0_routine
Tccr0 = &B00000111                                          ' Count external Signals on Rising Edge


' Timer2 Config (read and display the battery voltage every 4 seconds)
On Timer2 Timer2_routine
Tccr2a = &B00000000
Tccr2b = &B00000101                                         ' Prescaller 1024
Timer2 = 178                                                ' OVF each 10 ms
' count 4 seconds in INT routine then raise Ok_to_read_vbat Flag


Enable Interrupts

$lib "glcd-Nokia3310.lib"

' LCD Rst & Cs1 are not used
Config Graphlcd = 128x64sed , Rst = Portd.3 , A0 = Portb.4 , Si = Portb.3 , Sclk = Portb.5

'Const Negative_lcd = 1                                      ' Invert screen
Const Rotate_lcd = 0

' LEDs
Config Portd.5 = Output
Blue_led Alias Portd.5
Reset Blue_led

Config Portd.6 = Output
Red_led Alias Portd.6
Reset Red_led

' Keys
Config Pinb.1 = Input
Key1 Alias Pinb.1
Portb.1 = 1


Config Pind.2 = Input
Key2 Alias Pind.2
Portd.2 = 1

' Reed Relay (adds Calibration Capacitor)
Config Portb.2 = Output
Calibrate Alias Portb.2
Set Calibrate                                               ' disconnect Ccal

' Measure Mode
' double relay
' SET   (Normally Open)  >> C Mode
' RESET (Normally Close) >> L Mode
Config Portb.0 = Output
Measure_mode Alias Portb.0
Reset Measure_mode

Dim Overflowed As Long
Dim Pulses As Long
Dim I As Byte , J As Byte , K As Byte
Dim Tim2var As Integer

Const Pi = 3.141592653589793
Const 2pi = 6.283185307179586
Const Ccal = 0.000000001006                                 ' Farads or 1006 [pF]

Const Milli = 0.001
Const Micro = 0.000001
Const Nano = 0.000000001
Const Pico = 0.000000000001

Const Cr = &H0D
Const Lf = &H0A



Dim F1 As Single                                            ' Oscillator's base freq. (Ccal, C_det & L_det disconnected)
Dim F2 As Single                                            ' Calibration freq. (Ccal connected, C_det & L_det disconnected)
Dim F3 As Single                                            ' Ccal disconnected, C_det connected, L_det disconnected
Dim F4 As Single                                            ' Ccal disconnected, C_det disconnected, L_det disconnected

Dim Dvar1 As Single
Dim Dvar2 As Single

Dim Svar1 As Single

Dim C_measured As Single
Dim L_measured As Single

Dim Scaled_val As Single
Dim New_str_value As String * 20

Dim Adcval As Word
Dim Vbat As Single
Dim Vbat_str As String * 5

Dim X As Byte

Dim Lbat_pic As Bit
Reset Lbat_pic

Dim Ok_to_read_vbat As Bit
Reset Ok_to_read_vbat

Dim A As Byte
Dim Rx_buffer As String * 30 , Rx_string As String * 30
Dim Full_buffer As Bit , Rx_flag As Bit
Reset Full_buffer : Reset Rx_flag

Declare Sub Read_vbat
Declare Sub Calibration
Declare Sub Measure_c
Declare Sub Measure_l
Declare Sub Convert(value As Single)

' Initialize LCD
Initlcd
Glcdcmd 33 : Glcdcmd 200                                    ' Normal Contrast
Cls

' select Capacity Mode
Set Measure_mode

Print "LC-Meter.ioConnected.OK"

Setfont Newfont6x8
Showpic 1 , 1 , Splash
Waitms 1000
Cls
Lcdat 3 , 10 , "ioConnected"
Lcdat 4 , 52 , "2020"
Waitms 2000

Print "Ready"
Waitms 500

Call Calibration
Print
Print

Do
   If Ok_to_read_vbat = 1 Then Call Read_vbat
   If Key1 = 0 Then
      Print "Measuring Capacitance >>>>"
      Waitms 500
      If Key2 = 0 Then
         Call Calibration
      Else
         Call Measure_c
      End If
   End If


   If Key2 = 0 Then
      Print "Measuring Inductance >>>>"
      Waitms 500
      If Key1 = 0 Then
         Call Calibration
      Else
         Call Measure_l
      End If
   End If

   If Rx_flag = 1 Then
      Select Case Rx_string
         Case "rst!":
            Start Watchdog
      End Select
   End If



Loop
End



$include "newfont6x8.font"
$include "font12x16dig.font"
Splash:
$bgf "splash_s.bgf"
Battery100:
$bgf "b100.bgf"
Battery75:
$bgf "b75.bgf"
Battery50:
$bgf "b50.bgf"
Batterylow1:
$bgf "blow1.bgf"
Batterylow2:
$bgf "blow2.bgf"
Inductor:
$bgf "ind_s.bgf"
Capacitor:
$bgf "cap_s.bgf"

Serial0bytereceived:
   Pushall
   If Ischarwaiting() > 0 Then
      A = Inkey()
      If A <> 10 And A <> 13 Then
         Rx_buffer = Rx_buffer + Chr(a)
      End If
      If Len(rx_buffer) >= 20 Then Set Full_buffer
   End If
   If A = 10 Or Full_buffer = 1 Then
      Reset Full_buffer
      Set Rx_flag
      Rx_string = Rx_buffer
      Rx_buffer = ""
   End If
   Popall
Return

Timer1_routine:
   'Timer1 = 57898
   'Timer1 = 57880
   'Timer1 = 57870
   Timer1 = 57644
   Overflowed = Overflowed * 255
   Pulses = Overflowed + Timer0
   Overflowed = 0
   Timer0 = 0
Return

Timer0_routine:
   Incr Overflowed
Return

Timer2_routine:
   Timer2 = 178                                             ' OVF every 10mS
   Incr Tim2var
   If Tim2var >= 400 Then
      Tim2var = 0
      Ok_to_read_vbat = 1
   End If
Return


Sub Read_vbat
   Ok_to_read_vbat = 0
   Adcval = Getadc(5)
   Vbat = Adcval * 4.92
   ' Vbat is measured through a voltage divider (R1=R2)
   Vbat = Vbat * 2.01                                       ' R2's measured resistance is slightly smaller
   ' show in Volts
   Vbat = Vbat / 1000
   Vbat_str = Fusing(vbat , "#.&&")

   'Print : Print "Battery Voltage= " ; Vbat_str ; " [V]"

   Select Case Vbat
      Case Is > 8.3 : Showpic 72 , 1 , Battery100
      Case 7.8 To 8.3 : Showpic 72 , 1 , Battery75
      Case 7.2 To 7.8 : Showpic 72 , 1 , Battery50
      Case Is < 7.2 :
         Toggle Lbat_pic
         If Lbat_pic = 0 Then
            Showpic 72 , 1 , Batterylow2
         Else
            Showpic 72 , 1 , Batterylow1
            Print "Battery low !"
         End If
   End Select

End Sub

Sub Calibration
   Ok_to_read_vbat = 0
   Cls
   Print "Calibration"
   Print "make sure to remove any L or C from the Measuring Terminals"
   Print
   Print "please wait ..."
   Lcdat 2 , 1 , "Calibration" ;
   Lcdat 3 , 1 , "please wait .." ;
   Waitms 400
   Lcdat 5 , 1 , "Æ"
   Print "^"
   Reset Red_led
   Reset Blue_led

   ' prepare to measure the Frequency without Calibration Capacity
   Set Calibrate                                            ' disconnect Ccal

   Lcdat 5 , 1 , "Æ"
   Print "^"
   I = 0
   J = 0
   K = 0
   For I = 1 To 6
      'Print I
      Incr J
      Waitms 500
      X = I * 6
      X = X + 1
      Lcdat 5 , X , "Æ"
      Print "^"
      If J = 2 Then
         Incr K
         J = 0
         Print "F1= " ; Pulses ; " [Hz] (base frequency)"
         If K = 3 Then
            F1 = Pulses
            Print "F1= " ; F1 ; " [Hz] (base frequency)"
            ' now prepare to measure the Frequency with added Calibration Capacitance
            Reset Calibrate                                 ' connect Ccal
         End If
      End If
   Next

   Lcdat 5 , 43 , "Æ"
   Print "^"
   Waitms 500
   Lcdat 5 , 49 , "Æ"
   Print "^"

   J = 0
   K = 0
   For I = 9 To 14
      'Print I
      Incr J
      Waitms 500
      X = I * 6
      X = X + 1
      Lcdat 5 , X , "Æ"
      Print "^"
      If J = 2 Then
         Incr K
         J = 0
         Print "F2= " ; Pulses ; " [Hz] (calibration frequency)"
         If K = 3 Then
            K = 0
            F2 = Pulses
            Print "F2= " ; F2 ; " [Hz] (calibration frequency)"
         End If
      End If
   Next
   Cls
   Lcdat 2 , 1 , "Calibration"
   Lcdat 3 , 1 , "complete !"
   Print "Calibration complete !"
   Waitms 2000
   Cls
   Lcdat 5 , 1 , "L-Mode  C-Mode"
   Print "C Done !"
   Print
   Print

End Sub

Sub Measure_c
   Ok_to_read_vbat = 1
   Cls
   Lcdat 1 , 1 , "Capacitance"
   Showpic 14 , 10 , Capacitor
   Waitms 2000
   Set Blue_led

   Set Measure_mode                                         ' select Capacitance Mode
   Set Calibrate                                            ' disconnect Ccal

   For I = 1 To 4
      Waitms 250
   Next
   I = 0

   Do
      F3 = Pulses
      Print "F3= " ; F3 ; " [Hz] (frequency for C_det)"

      Dvar1 = F1 / F3
      Dvar1 = Dvar1 * Dvar1
      Dvar1 = Dvar1 - 1

      Dvar2 = F1 / F2
      Dvar2 = Dvar2 * Dvar2
      Dvar2 = Dvar2 - 1

      Dvar1 = Dvar1 / Dvar2
      C_measured = Dvar1
      C_measured = C_measured * Ccal
      Call Convert(c_measured)
      If New_str_value <> "Error !" Then
         New_str_value = "C= " + New_str_value
         New_str_value = New_str_value + "F]"
      End If
      Print New_str_value
      Lcdat 4 , 1 , "               "
      Lcdat 4 , 1 , New_str_value
      Incr I

      Waitms 1000
   Loop Until I > 4
   Reset Blue_led
   Lcdat 5 , 1 , "L-Mode  C-Mode"
   Print "CM Done !"
End Sub

Sub Measure_l
   Ok_to_read_vbat = 1
   Cls
   Lcdat 1 , 1 , "Inductance "
   Showpic 14 , 12 , Inductor
   Waitms 2000
   Set Red_led

   Reset Measure_mode                                       ' select Inductance Mode
   Set Calibrate                                            ' disconnect Ccal

   For I = 1 To 4
      Waitms 250
   Next
   I = 0

   Do
      F4 = Pulses
      Print "F4= " ; F4 ; " [Hz] (frequency for L_det)"

      Dvar1 = F1 / F4
      Dvar1 = Dvar1 * Dvar1
      Dvar1 = Dvar1 - 1

      Dvar2 = F1 / F2
      Dvar2 = Dvar2 * Dvar2
      Dvar2 = Dvar2 - 1

      Dvar1 = Dvar1 * Dvar2

      Svar1 = F1
      Svar1 = 2pi * Svar1
      Svar1 = 1 / Svar1
      Svar1 = Svar1 ^ 2

      L_measured = Dvar1
      L_measured = L_measured / Ccal
      L_measured = L_measured * Svar1
      Call Convert(l_measured)
      If New_str_value <> "Error !" Then
         New_str_value = "L= " + New_str_value
         New_str_value = New_str_value + "H]"
      End If
      Print New_str_value
      Lcdat 4 , 1 , "               "
      Lcdat 4 , 1 , New_str_value
      Incr I

      Waitms 1000
   Loop Until I > 4
   Reset Red_led
   Lcdat 5 , 1 , "L-Mode  C-Mode"
   Print "LM Done !"
End Sub

Sub Convert(value As Single)
   New_str_value = ""
   If Value > 0 Then
      If Value < Nano Then
         Scaled_val = Value * 1000000000000
         New_str_value = Fusing(scaled_val , "#.&&")
         New_str_value = New_str_value + " [p"
      Else
         If Value < Micro Then
            Scaled_val = Value * 1000000000
            New_str_value = Fusing(scaled_val , "#.&&")
            New_str_value = New_str_value + " [n"
         Else
            If Value < Milli Then
               Scaled_val = Value * 1000000
               New_str_value = Fusing(scaled_val , "#.&&")
               New_str_value = New_str_value + " [u"
            Else
               If Value < 1 Then
                  New_str_value = Fusing(scaled_val , "#.&&&")
                  New_str_value = New_str_value + " [m"
               Else
                  If Value < 10 Then
                     New_str_value = Fusing(scaled_val , "#.&")
                     New_str_value = New_str_value + " ["
                  Else
                     New_str_value = "Error !"
                  End If
               End If
            End If
         End If
      End If
   Else
      New_str_value = "Error !"
   End If
End Sub



' "glcd-Nokia3310.lib" must be copied in the bascom library folder.

' Don't forget to set the fusebits of the microcontroller.


' Fusebits : FF
' Fusebits High : D9
' Fusebits Extended : FF



' coreWeaver / ioCONNECTED
' last updated - May 3rd, 2021