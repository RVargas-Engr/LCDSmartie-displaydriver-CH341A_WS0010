This display driver for LCDSmartie supports the following hardware configuration:

1) A USB-to-Parallel adapter breakout board utilizing the WCH-IC CH341A chip.
   These can be purchased on Amazon.
2) A 2x16 OLED character display module utilizing a Midas Displays MS0010 or
   a Winstar WS0010 (or compatible) controller.  For example, the Midas Displays
   MCOB21605B1V-EWP and the Crystalfontz CFAL1602C-W modules both work, as they both
   seem to be rebrands of the same EH1602C board.  The module must be reconfigured to
   use i80 signaling mode, also referred to as 8080 mode, as opposed to M68, which
   is the default.  This is done on the board hardware by moving a 0-ohm resistor accordingly.
3) A 14-pin ribbon cable re-wired accordingly to connect the two boards as
   shown below.  Note that a direct 14-pin connection will not work because the
   pinouts are different.
   - 8 parallel data bits, D0 through D7.
   - E control pin on OLED to CH341A pin 4 (DS#/AFD#/ROV#).
   - R/W control pin on OLED to CH341A pin 25 (RW#/STB#/RDY#).
   - RS control pin to CH341A pin 3 (AS#/SIN#/IN7).
   - 5V Power.
   - Ground.
   
