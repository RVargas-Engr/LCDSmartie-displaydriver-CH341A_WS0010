## LCDSmartie Display Driver for CH341A + WS0010/MS0010 OLED 2x16 Module

### Intended Hardware Configuration

1) #### A WCH-IC CH341A chip to provide USB-to-parallel conversion.
   Simple breakout boards that provide this functionality can be purchased from Amazon
   as well as from a few other vendors.  This driver uses the CH341A parallel "MEM"
   signaling mode, which is compatible with the "i80" signaling mode of the OLED module.
   Power, ground, the 3 control signals, and the 8 data signals are output from the
   board to the OLED module.
2) #### A 2x16 OLED character display module powered by a Midas Displays MS0010 or Winstar WS0010 controller.
   Compatible modules include, but are not limited to, the Midas Displays MCOB21605B1V-EWP and
   the Crystalfontz CFAL1602C-W modules, which both seem to be rebrands of the same EH1602C board.  The module
   must be reconfigured to use "i80" signaling mode, also referred to as "8080" mode, as opposed to "M68",
   which is the default.  This reconfiguration done on the board itself by de-soldering a 0-ohm resistor used
   as the jumper that configures "M68" mode and then re-soldering it at the jumper location that configures
   "i80" mode.  An image file has been included in this repository that shows where the jumper is located on
   the back of the module.
3) #### A 14-pin ribbon cable wired to connect the two boards as shown below.
   Note that OLED modules containing a 2x7 header, include the 2 modules documented above, are not pin-for-pin
   compatible with the CH341A breakout board found on Amazon, so connection using an unmodified 14-pin ribbon
   cable will not work.  The following hookups are needed for a general purpose connection.
   - 8 parallel data bits, D0 through D7.
   - OLED   E control pin to CH341A pin  4 (DS#/AFD#/ROV#).
   - OLED R/W control pin to CH341A pin 25 (RW#/STB#/RDY#).
   - OLED  RS control pin to CH341A pin  3 (AS#/SIN#/IN7).
   - 5V Power.
   - Ground.
   
