# LC-Meter
Open Source LC-Meter. All documentation included.




This LC Meter Project is open source. All the documentation both hardware and software is provided without any warranty.
If you build one I would be glad to get a picture of your finished device. 
Subscribe to my Youtube channel and post your comments and questions about this project in the comment section of the series.

The video series is a full tutorial on how it works, how to build it and how to test it.
You can watch it here: https://www.youtube.com/watch?v=KhJiE4gL5T4   (part 1)


About this project:

This design is based on Neil Hecht's idea. It uses an oscillator (LM311) to generate a frequency which can be modified by adding a capacitance or an inductance on the measuring terminals. The frequency is monitored by the microcontroller (ATMEGA328p) and all the math is then performed to extract the value of the added capacitance or inductance.
The value is then adjusted in engineering units and showed on a graphical display.

The PCB is designed using through-hole-terminal components only so it is very easy to solder. There is place for improvements in the schematic, just like I explained in the part 2 of the series (watch here: https://www.youtube.com/watch?v=jytJJjer8_M ).


This project can be improved. A second version would probably include these changes: 

	- make use of a rechargeable Li Ion battery
	- add a usb connector on board 
	- add charging circuitry for the battery
	- add UART - USB translation circuitry on board
	- add a voltage step up to boost the battery voltage to 5V
	- increase the frequency of the AVR

The LC Meter PC application was written in C# and it's very useful when a lot of measurements have to be done. It includes a catalog function for the measured components and a UART logging function for debug purposes.

The firmware for the microcontroller is written in BASCOM. The source files are present also and you can modify them or port to other language if you wish. There is a readme file in the Firmware folder with the FUSES Configuration for the AVR if you decide to use the precompiled firmware.






coreWeaver - ioCONNECTED / Mar. 2021
