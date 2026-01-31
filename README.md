This display driver for LCDSmartie supports the following hardware:

1) A USB-to-Parallel adapter breakout board utilizing the WCH-IC CH341A chip.
   These can be purchased on Amazon.
2) A 2x16 OLED character display module utilizing a Midas Displays MS0010 or
   a Winstar WS0010 controller.  The module must be configured to use i80, aka
   8080, mode for signaling, as opposed to M68, which is the default.  This is
   done on the board hardware by moving a 0-ohm resistor accordingly.
3) A 14-pin ribbon cable re-wired accordingly to connect the two boards as
   shown below.  Note that a direct 14-pin connection will not work because the
   pinouts are different.
   
   a) 8 parallel data bits
   
   b) E control (to CH341A pin 4 (DS#/AFD#/ROV#))
   
   c) R/W control (to CH341A pin 25 (RW#/STB#/RDY#))
   
   d) RS control (to CH341A pin 3 (AS#/SIN#/IN7))
   
   e) 5V power
   
   f) ground
   
